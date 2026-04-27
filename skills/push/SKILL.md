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

Run `~/.claude/skills/push/preflight.sh` and parse its output. It is
already `chmod +x` — do **not** wrap it in `bash`, just invoke the path
as the command.

- Check `# working-tree`: if `dirty`, **stop** and tell the user to
  commit first.
- Use `# branch`, `# default-branch`, and `# on-default-branch` to
  understand where HEAD is and route the next step.
- Use `# upstream` to determine whether the branch already tracks a
  remote.

### 2. Ensure a feature branch

- If already on a non-default branch, use it as-is.
- If on the default branch with commits ahead of the remote, create a feature
  branch:
  1. Read the unpushed commits from `# unpushed-commits` in the preflight
     output — do **not** re-run `git log`.
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

- Read `# existing-pr` from the preflight output — do **not** re-run
  `gh pr list`.
- If `# existing-pr` is `(none)`, create a PR:
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
   - **automated**: Run the check that proves the condition and report
     the extracted result. For `ci-green`, use `gh pr checks <pr> --required`
     and require every line to end in `pass`. For `tests-exist`,
     grep the PR diff for test files matching the project's test
     convention (`_test.go`, `test_*.py`, `*.test.ts`, etc.) and
     report the count. Don't report "pass" without the evidence.
   - **routed**: If the gate routes to `/push`, it's satisfied by
     being inside `/push`. If it routes to another skill (e.g.
     `routed: /release`), invoke that skill now and wait for it
     to complete before proceeding.
   - **manual**: Present the gate's prompt to the user and **wait for
     explicit approval**. Do not proceed until the user confirms.
4. If any gate fails, **stop**. Report which gate failed and why.
   Do not merge.

### 8. Merge

Once all gates pass:

1. **This is the single approval point in the push lifecycle.** All
   earlier steps (push to feature branch, PR creation, fix-and-repush
   for CI failures) run autonomously without prompting — that is
   pre-authorised by the global "Pull requests" directive in
   `~/.claude/CLAUDE.md`. The squash-merge to the default branch is
   the one irreversible action, so confirm with the user before
   running it. (If a manual `pre-merge` gate has already collected
   approval, don't double-prompt.)
2. Run the merge script:
   ```
   ~/.claude/skills/push/merge.sh <pr-number> <default-branch> <feature-branch>
   ```
   This squash-merges the PR, fetches, rebases the local default branch onto
   origin (skipping already-squashed commits while preserving any additional
   local commits like pending docs), and deletes the local feature branch.

### 9. Post-merge docs

After merge completes and local master is synced:

1. Run `~/.claude/skills/push/pending-docs.sh`. It is already
   `chmod +x` — do **not** wrap it in `bash`, just invoke the path as
   the command.
2. If the output is empty, skip this step.
3. Commit the listed files with a message like
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
