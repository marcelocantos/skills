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

# 3/4. Sync the default branch to the squash-merged remote.
#
#    Normal case: check it out here and hard-reset (after a squash merge,
#    local master has N pre-squash commits while origin has one squashed
#    commit; rebase would replay the originals, reset is safe — the
#    squash captured everything).
#
#    Worktree case: when the default branch is checked out in a DIFFERENT
#    worktree (e.g. this script runs from a .claude/worktrees/* checkout
#    while the main checkout holds master), git refuses to check it out
#    here. Skipping the sync silently lets the main checkout drift
#    further behind on every merge — instead, sync it *in place* over
#    there, but only fast-forward and only if that tree is clean; any
#    local commits or dirty state make it the owner's problem, reported
#    loudly rather than touched.
owner=$(git worktree list --porcelain | awk -v b="refs/heads/$default_branch" '
    /^worktree /   { wt = substr($0, 10) }
    $0 == "branch " b { print wt; exit }')
here=$(git rev-parse --show-toplevel)

if [ -z "$owner" ] || [ "$owner" = "$here" ]; then
    git checkout "$default_branch"
    git reset --hard "origin/$default_branch"
elif [ -z "$(git -C "$owner" status --porcelain --untracked-files=no)" ] \
     && git -C "$owner" merge-base --is-ancestor "$default_branch" "origin/$default_branch"; then
    git -C "$owner" merge --ff-only "origin/$default_branch"
    echo "note: $default_branch fast-forwarded in its worktree at $owner"
else
    echo "WARNING: $default_branch is checked out at $owner but cannot be" >&2
    echo "fast-forwarded (dirty tree or local commits). Sync it there with:" >&2
    echo "    git -C $owner pull --rebase" >&2
fi

# 5. Delete the local feature branch (if it still exists).
if git rev-parse --verify "$feature_branch" >/dev/null 2>&1; then
    git branch -D "$feature_branch"
fi

echo "Merged PR #$pr, synced $default_branch, cleaned up $feature_branch."
