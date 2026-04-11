#!/usr/bin/env bash
# merge.sh — Squash-merge a PR and sync local state.
#
# After a squash-merge, local master has the pre-squash commits while
# origin/master has a single squashed commit. A normal `git pull` tries
# to reconcile these and conflicts. This script handles it cleanly:
# squash-merge via gh, then hard-reset local master to origin.
#
# Usage: merge.sh <pr-number> <default-branch> <feature-branch>

set -euo pipefail

pr="$1"
default_branch="$2"
feature_branch="$3"

# 1. Squash-merge on GitHub (also deletes remote branch).
#    gh runs a post-merge `git pull --ff-only` on whatever named branch
#    we're on, which always fails in the diverging-but-already-squashed
#    case (the squash rewrote local commits into a single origin commit
#    with a different SHA). The failure is harmless — step 4 resets to
#    origin authoritatively — but gh emits a noisy
#        "! warning: not possible to fast-forward"
#    plus the full git hint block that looks like an error. Filter
#    those specific lines from stderr so the output stays clean. Other
#    gh errors still surface through set -euo pipefail.
gh pr merge "$pr" --squash --delete-branch 2> >(
    grep -Ev '^(hint:|fatal: Not possible to fast-forward|! warning: not possible to fast-forward|Disable this message)' >&2
)

# 2. Fetch the updated remote (prune stale remote-tracking refs).
git fetch origin --prune

# 3. Switch to the default branch.
git checkout "$default_branch"

# 4. Hard-reset to the squash-merged remote.
#    After a squash merge, local master has N pre-squash commits while
#    origin/master has one squashed commit. Rebase fails trying to
#    replay the originals. Reset is safe — the squash captured everything.
git reset --hard "origin/$default_branch"

# 5. Delete the local feature branch (if it still exists).
if git rev-parse --verify "$feature_branch" >/dev/null 2>&1; then
    git branch -D "$feature_branch"
fi

echo "Merged PR #$pr, synced $default_branch, cleaned up $feature_branch."
