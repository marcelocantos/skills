---
name: push
description: Push current work through a PR-based CI workflow. Creates branch and PR if needed.
user-invocable: true
---

# Push

Push the current branch through CI via a pull request. Creates a feature
branch and PR if they don't already exist.

## Steps

### 1. Preflight

- Run `git status --short --branch` and `git log --oneline -5`.
- If the working tree is dirty (uncommitted changes), **stop** and tell the
  user to commit first.
- Determine the current branch name and whether it tracks a remote.
- Identify the default branch (`master` unless the repo uses something else).

### 2. Ensure a feature branch

- If already on a non-default branch, use it as-is.
- If on the default branch with commits ahead of the remote, create a feature
  branch:
  1. Run `git log --oneline origin/master..HEAD` to see all unpushed commits.
  2. Derive a branch name from those commits — lowercase, hyphenated, max
     ~50 chars (e.g., `add-github-actions-ci`). If there's a single commit,
     use its message. If there are multiple, summarise the theme. Strip
     conventional-commit prefixes (`fix:`, `feat:`, etc.) before slugifying.
  3. Create and switch to the branch: `git checkout -b <branch>`.
- If on the default branch with **no** commits ahead, **stop** — nothing to
  push.

### 3. Push

- Push with upstream tracking:
  `git push -u origin HEAD --recurse-submodules=on-demand`
  This automatically pushes any submodule commits that the parent references
  but that haven't been pushed yet, avoiding a separate `cd <submodule> &&
  git push` step.

### 4. Create or locate PR

- Check for an existing open PR from this branch:
  `gh pr list --head <branch> --state open --json number,url --jq '.[0]'`
- If no PR exists, create one:
  - **Single commit**: use `gh pr create --fill` (commit message becomes title
    and body).
  - **Multiple commits**: use `gh pr create --title <title> --body <body>`.
    The title should summarise the theme of the commits. The body should
    contain a bullet-point list of the individual commit messages.
- Print the PR URL.

### 5. Wait for CI

- Find the latest check suite for the PR's head SHA and monitor it:
  ```
  gh pr checks <number> --watch
  ```
- If all checks pass, report success.
- If any check fails:
  1. Print the failed check names and their URLs.
  2. For each failure, fetch the log and diagnose the root cause:
     ```
     gh run view <run-id> --log-failed
     ```
  3. Present a summary of failures and proposed fixes to the user.

### 6. Iterate on failures

When the user asks to fix CI failures (or approves proposed fixes):

1. Make the fix locally.
2. Commit the fix (separate commit, not amended — unless the user requests
   amend).
3. `git push` (upstream is already set).
4. Return to step 5 — watch CI again.

Repeat until CI is green or the user decides to stop.

### 7. Gate check

Once CI is green, enforce the project's delivery gates before merging.

1. Read the project's `## Gates` section from CLAUDE.md to determine the
   profile (default: `base`).
2. Read `~/.claude/gates/base.yaml` and the profile YAML (if not base).
   Merge them: profile gates add to base; `override: [gate: skip]`
   removes specific base gates.
3. Check each `pre-merge` gate:
   - **automated**: Verify the condition (CI green, tests exist for
     changed code). Report pass/fail.
   - **routed**: These are already satisfied by being inside `/push`.
   - **manual**: Present the gate's prompt to the user and **wait for
     explicit approval**. Do not proceed until the user confirms.
4. If any gate fails, **stop**. Report which gate failed and why.
   Do not merge.

### 8. Merge

Once all gates pass:

1. Confirm with the user before merging (this may already be covered
   by a manual gate — don't double-prompt if the user just approved
   a manual gate).
2. Run the merge script:
   ```
   ~/.claude/skills/push/merge.sh <pr-number> <default-branch> <feature-branch>
   ```
   This squash-merges the PR, fetches, rebases the local default branch onto
   origin (skipping already-squashed commits while preserving any additional
   local commits like pending docs), and deletes the local feature branch.

### 9. Post-merge docs

After merge completes and local master is synced:

1. Check for uncommitted docs-only changes on local master (files
   matching `docs/**` or `*.md` in the repo root). Use
   `git status --short` and filter for these paths.
2. If there are no such changes, skip this step.
3. Commit them with a message like
   "Update docs for <context>" (e.g., "Update targets for 🎯T2 achieved").
4. Create a branch, push, and open a PR using `gh pr create --fill`.
5. Watch CI with `gh pr checks <number> --watch`.
6. If CI passes, merge immediately using the merge script — no
   additional gate check needed (docs-only changes don't warrant
   manual review gates).
7. If CI fails, report the failure and leave the PR open for the
   user to handle.

This step is automatic — don't ask the user whether to proceed.
The point is to flush pending docs updates without polluting the
main feature PR or requiring a separate manual cycle.

## Notes

- Never force-push unless the user explicitly requests it.
- Never push directly to the default branch.
- All repos use squash-only merges. The PR title becomes the sole commit message
  on the default branch.
- If `gh` is not installed or not authenticated, tell the user and stop.
