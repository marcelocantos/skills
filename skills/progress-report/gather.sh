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

set -euo pipefail

SINCE="${1:-1 week ago}"
WORK_ROOT="$HOME/work"

# Resolve the author name from the global git config (if set).
AUTHOR="$(git config --global user.name 2>/dev/null || true)"

# Collect results into a temp file so we can count and sort.
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

total_commits=0
total_repos=0

# Find all git repos, sort alphabetically by path.
while IFS= read -r gitdir; do
    repo_dir="$(dirname "$gitdir")"

    # Build author filter if available.
    author_args=()
    if [[ -n "$AUTHOR" ]]; then
        author_args=(--author="$AUTHOR")
    fi

    # Check for commits in the period.
    commit_log="$(git -C "$repo_dir" log --oneline --since="$SINCE" \
        "${author_args[@]}" --all 2>/dev/null || true)"

    # Skip repos with no activity.
    [[ -z "$commit_log" ]] && continue

    # Extract org/name from path.
    # Handles paths like ~/work/github.com/org/repo or ~/work/other/repo.
    # Strip the WORK_ROOT prefix and the leading host directory if present.
    rel_path="${repo_dir#"$WORK_ROOT"/}"
    # Try to extract org/name (last two components after the host).
    # e.g., github.com/marcelocantos/csp -> marcelocantos/csp
    # e.g., GodotProject -> GodotProject
    if [[ "$rel_path" == */*/* ]]; then
        # Has at least host/org/repo — take the last two path components.
        repo_label="$(echo "$rel_path" | rev | cut -d/ -f1-2 | rev)"
    else
        repo_label="$rel_path"
    fi

    commit_count="$(echo "$commit_log" | wc -l | tr -d ' ')"

    # Diff stats: files changed, insertions, deletions.
    stat_summary="$(git -C "$repo_dir" log --since="$SINCE" \
        "${author_args[@]}" --all --shortstat --format="" 2>/dev/null || true)"

    files_changed=0
    insertions=0
    deletions=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # Parse lines like: " 3 files changed, 45 insertions(+), 12 deletions(-)"
        fc="$(echo "$line" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || true)"
        ins="$(echo "$line" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true)"
        del="$(echo "$line" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || true)"
        files_changed=$((files_changed + ${fc:-0}))
        insertions=$((insertions + ${ins:-0}))
        deletions=$((deletions + ${del:-0}))
    done <<< "$stat_summary"

    # Write this repo's block to the temp file.
    {
        echo "# repo: $repo_label"
        echo "$commit_log"
        echo "$commit_count commits, $files_changed file changes, +$insertions/-$deletions"
        echo ""
    } >> "$tmpfile"

    total_commits=$((total_commits + commit_count))
    total_repos=$((total_repos + 1))

done < <(find "$WORK_ROOT" \
    \( -name vendor -o -name node_modules -o -name .build -o -name build \) -prune -o \
    -name .git -type d -print 2>/dev/null | sort)

# Output collected data.
if [[ $total_repos -eq 0 ]]; then
    echo "No repos with activity since \"$SINCE\"."
    exit 0
fi

cat "$tmpfile"

# Summary.
echo "# summary"
echo "Repos with activity: $total_repos"
echo "Total commits: $total_commits"
echo "Period: since \"$SINCE\""
if [[ -n "$AUTHOR" ]]; then
    echo "Author filter: $AUTHOR"
else
    echo "Author filter: (all authors)"
fi
