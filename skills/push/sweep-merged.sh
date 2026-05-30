#!/usr/bin/env bash
# sweep-merged.sh — Reconcile local branches left behind by merges that
# didn't go through merge.sh (GitHub web UI, `gh pr merge`, CI auto-merge).
#
# merge.sh already deletes the one feature branch it merges. But owned
# repos set delete_branch_on_merge=true, so ANY merge deletes the *remote*
# branch — while the *local* branch and its stale remote-tracking ref
# linger forever. Over many out-of-band merges these pile up (31 PRs in,
# we had 15 stale locals). git never auto-deletes local branches, and
# squash-merge means `git branch --merged` can't even detect them (the
# squash commit has a different SHA from the pre-squash local tip).
#
# Safe predicate — a local branch is deleted only when ALL hold:
#   1. its upstream is [gone]      (remote branch deleted, e.g. on merge)
#   2. a MERGED PR exists for it    (confirms it was merged, not just
#                                    a remote someone hand-deleted)
#   3. its tip == the merged PR's head SHA
#                                   (no commits added since the merge —
#                                    protects branches with live post-merge
#                                    work, e.g. a branch reused after its
#                                    PR landed)
#   4. it is neither the current branch nor the default branch
#
# Idempotent; no-op when nothing is stale. Read-only on anything it
# doesn't delete.
#
# Usage: sweep-merged.sh [default-branch]   (default-branch defaults to master)

set -euo pipefail

default_branch="${1:-master}"

git fetch origin --prune --quiet

current=$(git symbolic-ref --short -q HEAD || echo "")
deleted=()

while IFS= read -r refline; do
    branch=${refline%% *}
    track=${refline#* }
    [ "$track" = "[gone]" ]        || continue   # (1) upstream deleted
    [ "$branch" = "$current" ]        && continue # (4) not current
    [ "$branch" = "$default_branch" ] && continue # (4) not trunk

    # (2) a merged PR must exist for this head branch.
    merged_sha=$(gh pr list --head "$branch" --state merged \
                    --json headRefOid --jq '.[0].headRefOid // empty' \
                    2>/dev/null || echo "")
    [ -n "$merged_sha" ] || continue

    # (3) branch tip unchanged since the merge (no live post-merge work).
    tip=$(git rev-parse "$branch")
    [ "$tip" = "$merged_sha" ] || continue

    git branch -D "$branch" >/dev/null && deleted+=("$branch")
done < <(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/)

if [ ${#deleted[@]} -gt 0 ]; then
    printf 'sweep-merged: deleted %d merged branch(es): %s\n' \
        "${#deleted[@]}" "${deleted[*]}"
else
    printf 'sweep-merged: nothing stale\n'
fi
