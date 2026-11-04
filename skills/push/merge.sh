#!/usr/bin/env bash
# merge.sh — Squash-merge a PR and sync local state.
#
# After a squash-merge, local master has the pre-squash commits while
# origin/master has a single squashed commit. A normal `git pull` tries
# to reconcile these and conflicts. This script handles it cleanly:
# squash-merge via gh (or merge-async for GitHub stacks), then hard-reset
# local master to origin.
#
# Usage: merge.sh <pr-number> <default-branch> <feature-branch>
#
# Standing rule (2026-10-07): if the PR is part of a GitHub stack, merge
# from the top with PUT …/merge-async (squash + direct_merge) so open
# downstack PRs are included — do not walk the stack one PR at a time.

set -euo pipefail

pr="$1"
default_branch="$2"
feature_branch="$3"

owner_repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
base_ref=$(gh pr view "$pr" --json baseRefName -q .baseRefName)
head_sha=$(gh pr view "$pr" --json headRefOid -q .headRefOid)
title=$(gh pr view "$pr" --json title -q .title)

# Stacked if base is not the repo default branch (or another open PR's head).
default_remote=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
is_stack=0
if [[ "$base_ref" != "$default_remote" ]]; then
  is_stack=1
fi
# Also treat as stack if any other open PR lists this PR's head as its base.
if gh pr list --state open --json number,baseRefName --jq ".[]|select(.number!=$pr)|.baseRefName" \
    | grep -qx "$feature_branch"; then
  is_stack=1
fi

squash_merge() {
  if [[ "$is_stack" -eq 1 ]]; then
    echo "note: stacked PR — using merge-async from #$pr (includes open downstack)"
    resp=$(gh api --method PUT "repos/$owner_repo/pulls/$pr/merge-async" \
      -f merge_method=squash \
      -f merge_action=direct_merge \
      -f commit_title="$title (#$pr)" \
      -f sha="$head_sha")
    status=$(printf '%s' "$resp" | jq -r '.status')
    uuid=$(printf '%s' "$resp" | jq -r '.details.uuid // empty')
    if [[ "$status" == "merged" ]]; then
      return 0
    fi
    if [[ -z "$uuid" ]]; then
      echo "merge-async failed: $resp" >&2
      exit 1
    fi
    for _ in $(seq 1 90); do
      r=$(gh api "repos/$owner_repo/pulls/$pr/merge-async/$uuid")
      st=$(printf '%s' "$r" | jq -r '.status')
      case "$st" in
        merged) return 0 ;;
        failed) echo "merge-async failed: $r" >&2; exit 1 ;;
      esac
      sleep 2
    done
    echo "merge-async timed out for #$pr (uuid=$uuid)" >&2
    exit 1
  fi

  # Non-stacked: classic gh squash-merge.
  #    gh runs a post-merge `git pull --ff-only` on whatever named branch
  #    we're on, which always fails in the diverging-but-already-squashed
  #    case. Filter those specific lines from stderr so the output stays clean.
  gh pr merge "$pr" --squash --delete-branch 2> >(
      grep -Ev '^(hint:|fatal: Not possible to fast-forward|! warning: not possible to fast-forward|Disable this message)' >&2
  ) || true
  # If merge-async path wasn't used, ensure merged:
  state=$(gh pr view "$pr" --json state -q .state)
  if [[ "$state" != "MERGED" ]]; then
    # Retry once without stderr filter for real errors
    gh pr merge "$pr" --squash --delete-branch
  fi
}

squash_merge

# 2. Fetch the updated remote (prune stale remote-tracking refs).
git fetch origin --prune

# 3/4. Sync the default branch to the squash-merged remote.
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
