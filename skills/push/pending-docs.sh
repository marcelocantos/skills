#!/usr/bin/env bash
# Scans the working tree for uncommitted doc-only files relevant to a
# post-merge docs flush. Prints one path per line; empty output means
# nothing to flush.
#
# Matches:
#   - Any file under docs/ (any depth)
#   - *.md at the repo root only (not nested)
set -euo pipefail

# Ensure we are inside a git repo.
if ! git rev-parse --git-dir &>/dev/null; then
    echo "error: not a git repository" >&2
    exit 1
fi

git status --porcelain 2>/dev/null | while IFS= read -r line; do
    # Extract path (columns 1-2 are status codes, column 3 is space)
    path="${line:3}"
    # Strip leading/trailing quotes that git uses for paths with spaces
    path="${path#\"}"
    path="${path%\"}"
    # For renames ("old -> new"), take the destination
    if [[ "$path" == *" -> "* ]]; then
        path="${path##* -> }"
    fi

    # Match docs/** (any depth)
    if [[ "$path" == docs/* ]]; then
        echo "$path"
        continue
    fi

    # Match *.md at repo root only (no slash in path)
    if [[ "$path" == *.md && "$path" != */* ]]; then
        echo "$path"
        continue
    fi
done
