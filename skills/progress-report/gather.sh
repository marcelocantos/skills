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
trap 'rm -f "$tmpfile"' EXIT

total_landed=0
total_inflight=0
total_repos=0

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

    # Landed diff stats (the headline churn — what actually shipped).
    landed_stat="$(git -C "$repo_dir" log "$default_branch" --since="$SINCE_ARG" \
        "${until_args[@]}" "${author_args[@]}" --no-merges --shortstat --format="" 2>/dev/null | sum_shortstat)"
    read -r l_files l_ins l_del <<< "$landed_stat"

    # In-flight diff stats (work-in-progress churn, reported separately).
    inflight_stat="$(git -C "$repo_dir" log --all --not "$default_branch" --since="$SINCE_ARG" \
        "${until_args[@]}" "${author_args[@]}" --no-merges --shortstat --format="" 2>/dev/null | sum_shortstat)"
    read -r f_files f_ins f_del <<< "$inflight_stat"

    # Write this repo's block to the temp file.
    {
        echo "# repo: $repo_label (default branch: $default_branch)"
        echo "$landed_log"
        echo "landed: $landed_count commits, $l_files file changes, +$l_ins/-$l_del (on $default_branch)"
        if [[ "$inflight_count" -gt 0 ]]; then
            echo "in-flight: $inflight_count commits, $f_files file changes, +$f_ins/-$f_del (unmerged branches)"
        fi
        echo ""
    } >> "$tmpfile"

    total_landed=$((total_landed + landed_count))
    total_inflight=$((total_inflight + inflight_count))
    total_repos=$((total_repos + 1))

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
echo "Period: since \"$SINCE\""
if [[ -n "$AUTHOR" ]]; then
    echo "Author filter: $AUTHOR"
else
    echo "Author filter: (all authors)"
fi
echo "Note: headline metrics count landed (default-branch) commits only;"
echo "in-flight commits live on unmerged branches and are reported separately."

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
