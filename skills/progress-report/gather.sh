#!/usr/bin/env bash
#
# gather.sh — Collect git activity across all repos under ~/work/ for the
# progress-report skill.
#
# Usage:
#   gather.sh [since]
#
# Arguments:
#   since   Git-compatible date expression (default: "1 week ago")
#           Examples: "1 week ago", "2025-02-19", "2 days ago"
#
# Output:
#   Per-repo blocks with commit log and diff stats, followed by a summary.
#
# Counting model — landed vs in-flight:
#   "Landed" = commits that reached the repo's default branch (master/main).
#   "In-flight" = commits that exist only on other branches (feature branches,
#   worktree-agent-* branches) and have NOT yet merged to the default branch.
#
#   Headline numbers (commit log, diff stats, totals) report LANDED work only,
#   so the report reflects what actually shipped. In-flight work is reported
#   separately and clearly labelled as a work-in-progress signal.
#
#   Rationale: the old behaviour counted `--all` refs. That (a) folded
#   unmerged worktree-branch churn into the headline numbers, and (b) caused
#   cross-report double-representation — N dev commits counted now, plus the
#   eventual squash-merge commit counted in a future report. Splitting landed
#   from in-flight removes both distortions. A single `git log` invocation
#   already dedups by SHA, so a commit on several branches is never counted
#   twice within one run; the split is about *which* commits to attribute to
#   shipped progress.

set -euo pipefail

SINCE="${1:-1 week ago}"
# Optional exclusive upper bound. Pass the day AFTER the period's last day to
# include that whole day (git --until is by commit timestamp). Used to
# regenerate historical/back-filled weeks without bleeding in later commits.
# When empty, gathering runs through "now".
UNTIL="${2:-}"
WORK_ROOT="$HOME/work"

# Directory names skipped while scanning for repos. Beyond dependency
# vendoring (vendor, node_modules), these are build/cache outputs that can
# contain nested .git directories — Unity's Library/Temp/Builds, Xcode
# DerivedData, CocoaPods Pods. A nested .git inside a build output is never a
# real project repo; counting one corrupts both the per-repo scan and the
# daily breakdown (this bit a Unity repo's iOS build dir in a prior run).
PRUNE_DIRS=(vendor node_modules .build build Build Builds Library Temp obj Pods DerivedData)

# Global pathspecs always excluded from *line* stats (insertions/deletions/
# files changed). Commits still count if they only touch these paths.
# Per-repo extras: single fleet file in the progress-reports repo
# (data/line-excludes.yaml) — see exclude-schema.md. Override path with
# PROGRESS_LINE_EXCLUDES.
STAT_EXCLUDE_DEFAULTS=(
    ':(exclude,glob)**/vendor/**'
    ':(exclude,glob)**/node_modules/**'
)
STAT_EXCLUDE_ONLY_DEFAULTS=(
    ':(glob)**/vendor/**'
    ':(glob)**/node_modules/**'
)

PROGRESS_REPORTS_DIR="${PROGRESS_REPORTS_DIR:-$HOME/work/github.com/marcelocantos/progress-reports}"
LINE_EXCLUDES_FILE="${PROGRESS_LINE_EXCLUDES:-$PROGRESS_REPORTS_DIR/data/line-excludes.yaml}"

# Strip a YAML list-item path (quotes, inline comments, whitespace).
_yaml_list_path() {
    local pat="$1"
    pat="${pat%%#*}"
    pat="${pat#"${pat%%[![:space:]]*}"}"
    pat="${pat%"${pat##*[![:space:]]}"}"
    if [[ "$pat" == \"*\" && "$pat" == *\" ]]; then
        pat="${pat:1:${#pat}-2}"
    elif [[ "$pat" == \'*\' && "$pat" == *\' ]]; then
        pat="${pat:1:${#pat}-2}"
    fi
    printf '%s' "$pat"
}

# Parse LINE_EXCLUDES_FILE once into:
#   LINE_EXCLUDE_INDEX  — temp file of "org/repo|glob" rows
#   EXTRA_DEFAULT_GLOBS — array of extra global globs from `defaults:`
# YAML subset only (no anchors/multiline). Safe if the file is missing.
LINE_EXCLUDE_INDEX="$(mktemp)"
EXTRA_DEFAULT_GLOBS=()
# Trap set after tmpfile is created (below) so both temps are cleaned.

if [[ -f "$LINE_EXCLUDES_FILE" ]]; then
    section=""   # defaults | repos | (empty)
    cur_repo=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        if [[ "$line" =~ ^defaults:[[:space:]]*$ ]]; then
            section=defaults
            cur_repo=""
            continue
        fi
        if [[ "$line" =~ ^repos:[[:space:]]*$ ]]; then
            section=repos
            cur_repo=""
            continue
        fi
        # Other top-level key
        if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*: ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            section=""
            cur_repo=""
            continue
        fi

        # Under repos: "  org/repo:" (2-space indent, key ends with :)
        if [[ "$section" == "repos" && "$line" =~ ^[[:space:]]{2}([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+):[[:space:]]*$ ]]; then
            cur_repo="${BASH_REMATCH[1]}"
            continue
        fi

        # List item
        if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
            pat="$(_yaml_list_path "${BASH_REMATCH[1]}")"
            [[ -z "$pat" ]] && continue
            if [[ "$section" == "defaults" ]]; then
                EXTRA_DEFAULT_GLOBS+=("$pat")
            elif [[ "$section" == "repos" && -n "$cur_repo" ]]; then
                printf '%s|%s\n' "$cur_repo" "$pat" >> "$LINE_EXCLUDE_INDEX"
            fi
        fi
    done < "$LINE_EXCLUDES_FILE"
fi

# Merge hard-coded defaults + optional defaults: from the fleet file.
for g in "${EXTRA_DEFAULT_GLOBS[@]+"${EXTRA_DEFAULT_GLOBS[@]}"}"; do
    STAT_EXCLUDE_DEFAULTS+=(":(exclude,glob)${g}")
    STAT_EXCLUDE_ONLY_DEFAULTS+=(":(glob)${g}")
done

# Look up org/repo label in the fleet index. Sets REPO_EXCLUDE_* arrays.
load_repo_excludes() {
    local label="$1"
    REPO_EXCLUDE_SPECS=()
    REPO_EXCLUDE_ONLY_SPECS=()
    REPO_EXCLUDE_LABELS=()
    [[ -s "$LINE_EXCLUDE_INDEX" ]] || return 0
    local pat
    while IFS= read -r pat; do
        [[ -z "$pat" ]] && continue
        REPO_EXCLUDE_SPECS+=(":(exclude,glob)${pat}")
        REPO_EXCLUDE_ONLY_SPECS+=(":(glob)${pat}")
        REPO_EXCLUDE_LABELS+=("$pat")
    done < <(awk -F'|' -v l="$label" '$1==l {print $2}' "$LINE_EXCLUDE_INDEX")
}

# Emit each repo's .git directory under WORK_ROOT (sorted), pruning PRUNE_DIRS
# at any depth. Submodules have a .git *file* (gitlink), not a dir, so
# `-type d` already skips them; this additionally prunes nested independent
# clones living inside build outputs. Used by BOTH the main scan and the daily
# breakdown so they always see the identical repo set.
find_repos() {
    local prune=() d
    for d in "${PRUNE_DIRS[@]}"; do
        # Prepend the -o separator before every term except the first, so the
        # expression has no trailing -o (which would swallow the next predicate).
        [[ ${#prune[@]} -gt 0 ]] && prune+=(-o)
        prune+=(-name "$d")
    done
    find "$WORK_ROOT" \( "${prune[@]}" \) -prune -o -name .git -type d -print 2>/dev/null | sort
}

# git's bare-date --since/--until parsing is unreliable: an incomplete date
# like "2026-05-18" inherits the CURRENT wall-clock time-of-day, so commits
# from earlier on the start day are silently dropped — and the result varies
# with when the script runs. Expand bare YYYY-MM-DD bounds to an explicit
# local-midnight ISO-8601 timestamp so week boundaries are exact and stable.
# Relative ("1 week ago") and already-explicit timestamps pass through.
LOCAL_OFFSET="$(date +%z)"
to_local_midnight() {
    case "$1" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
            printf '%sT00:00:00%s' "$1" "$LOCAL_OFFSET" ;;
        *) printf '%s' "$1" ;;
    esac
}

# Normalised forms used for git revision-walk args. The bare SINCE/UNTIL are
# kept intact for the daily-breakdown date arithmetic further down.
SINCE_ARG="$(to_local_midnight "$SINCE")"
UNTIL_ARG=""
[[ -n "$UNTIL" ]] && UNTIL_ARG="$(to_local_midnight "$UNTIL")"

# git --until args, applied to every revision walk below when UNTIL is set.
until_args=()
if [[ -n "$UNTIL_ARG" ]]; then
    until_args=(--until="$UNTIL_ARG")
fi

# Resolve the author name from the global git config (if set).
AUTHOR="$(git config --global user.name 2>/dev/null || true)"

# Collect results into a temp file so we can count and sort.
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile" "$LINE_EXCLUDE_INDEX"' EXIT

total_landed=0
total_inflight=0
total_repos=0
total_ins=0
total_del=0
total_excl_ins=0
total_excl_del=0
repos_with_local_excludes=0

# Determine a repo's default branch. Prefers origin/HEAD, then master, then
# main, then the currently checked-out branch. Echoes the branch name.
default_branch_of() {
    local repo="$1" b
    b="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)"
    if [[ -n "$b" ]] && git -C "$repo" show-ref --verify --quiet "refs/heads/$b"; then
        echo "$b"; return
    fi
    for b in master main; do
        if git -C "$repo" show-ref --verify --quiet "refs/heads/$b"; then
            echo "$b"; return
        fi
    done
    git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || echo HEAD
}

# Sum "+ins/-del" from a stream of --shortstat lines. Echoes "files ins del".
sum_shortstat() {
    local files=0 ins=0 del=0 line fc i d
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        fc="$(echo "$line" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || true)"
        i="$(echo "$line" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true)"
        d="$(echo "$line" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || true)"
        files=$((files + ${fc:-0}))
        ins=$((ins + ${i:-0}))
        del=$((del + ${d:-0}))
    done
    echo "$files $ins $del"
}

# Find all git repos, sort alphabetically by path.
while IFS= read -r gitdir; do
    repo_dir="$(dirname "$gitdir")"

    # Build author filter if available.
    author_args=()
    if [[ -n "$AUTHOR" ]]; then
        author_args=(--author="$AUTHOR")
    fi

    default_branch="$(default_branch_of "$repo_dir")"

    # Landed: commits that reached the default branch in the period.
    landed_log="$(git -C "$repo_dir" log "$default_branch" --oneline --since="$SINCE_ARG" \
        "${until_args[@]}" "${author_args[@]}" --no-merges 2>/dev/null || true)"

    # In-flight: commits reachable from any ref but NOT from the default
    # branch (deduped by the single log walk). These have not merged yet.
    inflight_log="$(git -C "$repo_dir" log --all --not "$default_branch" --oneline --since="$SINCE_ARG" \
        "${until_args[@]}" "${author_args[@]}" --no-merges 2>/dev/null || true)"

    # Skip repos with no activity of either kind.
    [[ -z "$landed_log" && -z "$inflight_log" ]] && continue

    # Extract org/name from path.
    # Handles paths like ~/work/github.com/org/repo or ~/work/other/repo.
    rel_path="${repo_dir#"$WORK_ROOT"/}"
    if [[ "$rel_path" == */*/* ]]; then
        # Has at least host/org/repo — take the last two path components.
        repo_label="$(echo "$rel_path" | rev | cut -d/ -f1-2 | rev)"
    else
        repo_label="$rel_path"
    fi

    landed_count=0
    [[ -n "$landed_log" ]] && landed_count="$(echo "$landed_log" | wc -l | tr -d ' ')"
    inflight_count=0
    [[ -n "$inflight_log" ]] && inflight_count="$(echo "$inflight_log" | wc -l | tr -d ' ')"

    # Per-repo excludes from progress-reports data/line-excludes.yaml.
    load_repo_excludes "$repo_label"
    exclude_specs=("${STAT_EXCLUDE_DEFAULTS[@]}" "${REPO_EXCLUDE_SPECS[@]+"${REPO_EXCLUDE_SPECS[@]}"}")
    exclude_only_specs=("${STAT_EXCLUDE_ONLY_DEFAULTS[@]}" "${REPO_EXCLUDE_ONLY_SPECS[@]+"${REPO_EXCLUDE_ONLY_SPECS[@]}"}")
    if [[ ${#REPO_EXCLUDE_SPECS[@]} -gt 0 ]]; then
        repos_with_local_excludes=$((repos_with_local_excludes + 1))
    fi

    # Landed diff stats (headline churn — what shipped, minus excluded paths).
    landed_stat="$(git -C "$repo_dir" log "$default_branch" --since="$SINCE_ARG" \
        "${until_args[@]}" "${author_args[@]}" --no-merges --shortstat --format="" \
        -- . "${exclude_specs[@]}" 2>/dev/null | sum_shortstat)"
    read -r l_files l_ins l_del <<< "$landed_stat"

    # Bulk that was excluded — footnote only when non-zero.
    landed_excl_stat="$(git -C "$repo_dir" log "$default_branch" --since="$SINCE_ARG" \
        "${until_args[@]}" "${author_args[@]}" --no-merges --shortstat --format="" \
        -- "${exclude_only_specs[@]}" 2>/dev/null | sum_shortstat)"
    read -r x_files x_ins x_del <<< "$landed_excl_stat"

    # In-flight diff stats (work-in-progress churn, reported separately).
    inflight_stat="$(git -C "$repo_dir" log --all --not "$default_branch" --since="$SINCE_ARG" \
        "${until_args[@]}" "${author_args[@]}" --no-merges --shortstat --format="" \
        -- . "${exclude_specs[@]}" 2>/dev/null | sum_shortstat)"
    read -r f_files f_ins f_del <<< "$inflight_stat"

    # Write this repo's block to the temp file.
    {
        echo "# repo: $repo_label (default branch: $default_branch)"
        echo "$landed_log"
        echo "landed: $landed_count commits, $l_files file changes, +$l_ins/-$l_del (on $default_branch; excl. progress-report paths)"
        if [[ ${#REPO_EXCLUDE_LABELS[@]} -gt 0 ]]; then
            echo "exclude-config: line-excludes.yaml[$repo_label] → ${REPO_EXCLUDE_LABELS[*]}"
        fi
        if [[ "${x_ins:-0}" -gt 0 || "${x_del:-0}" -gt 0 ]]; then
            echo "landed-excluded: $x_files file changes, +$x_ins/-$x_del (defaults + line-excludes.yaml — not in headline)"
        fi
        if [[ "$inflight_count" -gt 0 ]]; then
            echo "in-flight: $inflight_count commits, $f_files file changes, +$f_ins/-$f_del (unmerged branches; excl. progress-report paths)"
        fi
        echo ""
    } >> "$tmpfile"

    total_landed=$((total_landed + landed_count))
    total_inflight=$((total_inflight + inflight_count))
    total_repos=$((total_repos + 1))
    total_ins=$((total_ins + l_ins))
    total_del=$((total_del + l_del))
    total_excl_ins=$((total_excl_ins + x_ins))
    total_excl_del=$((total_excl_del + x_del))

done < <(find_repos)

# Output collected data.
if [[ $total_repos -eq 0 ]]; then
    echo "No repos with activity since \"$SINCE\"."
    exit 0
fi

cat "$tmpfile"

# Summary.
echo "# summary"
echo "Repos with activity: $total_repos"
echo "Total landed commits: $total_landed"
echo "Total in-flight commits: $total_inflight"
echo "Total landed lines (excl. progress-report paths): +$total_ins/-$total_del"
if [[ "$total_excl_ins" -gt 0 || "$total_excl_del" -gt 0 ]]; then
    echo "Total landed lines excluded from headline: +$total_excl_ins/-$total_excl_del"
fi
echo "Repos with line-excludes.yaml entries: $repos_with_local_excludes"
echo "Line excludes file: $LINE_EXCLUDES_FILE"
echo "Period: since \"$SINCE\""
if [[ -n "$AUTHOR" ]]; then
    echo "Author filter: $AUTHOR"
else
    echo "Author filter: (all authors)"
fi
echo "Note: headline metrics count landed (default-branch) commits only;"
echo "in-flight commits live on unmerged branches and are reported separately."
echo 'Note: line stats always exclude **/vendor/** and **/node_modules/**,'
echo 'plus globs in progress-reports data/line-excludes.yaml (per org/repo).'

# Daily active repo counts.
# For each day from SINCE to today, count how many repos had at least one
# landed commit. This is a breadth metric (how many repos saw shipped work
# per day), consistent with the landed/in-flight split above.
echo ""
echo "# daily_active_repos"

# Resolve SINCE to a date. GNU date and BSD date differ; try both.
if start_epoch="$(date -j -f "%Y-%m-%d" "$SINCE" "+%s" 2>/dev/null)"; then
    date_cmd="bsd"
elif start_epoch="$(date -d "$SINCE" "+%s" 2>/dev/null)"; then
    date_cmd="gnu"
else
    # Fall back: try interpreting as a relative expression.
    if start_epoch="$(date -d "$SINCE" "+%s" 2>/dev/null)"; then
        date_cmd="gnu"
    else
        echo "# (could not parse start date for daily breakdown)"
        exit 0
    fi
fi

end_epoch="$(date "+%s")"

# When an exclusive UNTIL bound is set, cap the daily loop at the period's
# last day (UNTIL is the day after, so subtract one day).
if [[ -n "$UNTIL" ]]; then
    if [[ "$date_cmd" == "bsd" ]]; then
        until_epoch="$(date -j -f "%Y-%m-%d" "$UNTIL" "+%s" 2>/dev/null || true)"
    else
        until_epoch="$(date -d "$UNTIL" "+%s" 2>/dev/null || true)"
    fi
    if [[ -n "${until_epoch:-}" ]]; then
        capped=$(( until_epoch - 86400 ))
        [[ "$capped" -lt "$end_epoch" ]] && end_epoch="$capped"
    fi
fi

cur_epoch="$start_epoch"
while [[ "$cur_epoch" -le "$end_epoch" ]]; do
    if [[ "$date_cmd" == "bsd" ]]; then
        day_str="$(date -j -f "%s" "$cur_epoch" "+%Y-%m-%d")"
        dow="$(date -j -f "%s" "$cur_epoch" "+%a")"
        next_epoch="$(( cur_epoch + 86400 ))"
    else
        day_str="$(date -d "@$cur_epoch" "+%Y-%m-%d")"
        dow="$(date -d "@$cur_epoch" "+%a")"
        next_epoch="$(( cur_epoch + 86400 ))"
    fi

    if [[ "$date_cmd" == "bsd" ]]; then
        until_str="$(date -j -f "%s" "$next_epoch" "+%Y-%m-%d")"
    else
        until_str="$(date -d "@$next_epoch" "+%Y-%m-%d")"
    fi

    day_repos=0
    while IFS= read -r gitdir; do
        repo_dir="$(dirname "$gitdir")"
        author_args=()
        if [[ -n "$AUTHOR" ]]; then
            author_args=(--author="$AUTHOR")
        fi
        db="$(default_branch_of "$repo_dir")"
        # Guard against pipefail: a git failure (missing branch, odd gitdir)
        # must not abort the whole daily loop — fall back to 0.
        count="$(git -C "$repo_dir" log "$db" --oneline \
            --since="$(to_local_midnight "$day_str")" --until="$(to_local_midnight "$until_str")" \
            "${author_args[@]}" --no-merges 2>/dev/null | wc -l | tr -d ' ' || true)"
        count="${count:-0}"
        if [[ "$count" -gt 0 ]]; then
            day_repos=$((day_repos + 1))
        fi
    done < <(find_repos)

    echo "$dow $day_str $day_repos"
    cur_epoch="$next_epoch"
done
