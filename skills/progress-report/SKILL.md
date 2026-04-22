---
name: progress-report
description: Generate and publish a weekly progress report from git activity across all repos.
user-invocable: true
---

**DELEGATE VIA AGENT.** Spawn an Agent (subagent_type: general-purpose,
model: opus) with the prompt `"Read and execute
~/.claude/skills/progress-report/worker.md. Return the draft report
text."`. Relay the agent's result to the user.

The worker handles period determination, data gathering, and report
drafting. After the user approves the draft, the root session handles
Phase 3 (Update README and publish via PR):

## Phase 3: Update README and publish via PR

The `progress-reports` repo has branch protection on `master` — direct
pushes are blocked. Publication goes through a PR that is squash-merged
immediately (no CI, no approvals required) so every report has a
permanent PR record.

Follow guide section 6 for the README updates, then publish:

1. Replace the `## The Journey So Far` section with the rewritten
   narrative from the approved draft.
2. Add a collapsible entry under `## Reports` (newest first).
3. Add a row to the `## Metrics` table (newest first).
4. Create a feature branch: `git checkout -b report/weekly-<YYYY-MM-DD>`.
4. Stage the new report, updated README, achievements, charts, and cache
   together in a single commit.
5. Push the branch: `git push -u origin report/weekly-<YYYY-MM-DD>`.
6. Open a PR: `gh pr create --fill` (title and body from the commit).
7. Squash-merge immediately: `gh pr merge --squash --delete-branch`.
   This succeeds right away because the repo has 0 required approvals
   and no required status checks; the PR is retained as an audit record.
8. Switch back to `master` and pull: `git checkout master && git pull`.

## Error handling

- If a repo's `.git` directory is missing or corrupt, skip it and note the issue.
- If `git log` produces no output for a repo in the period, exclude it silently.
- If the user rejects the draft, revise and re-present — do not commit until approved.
- Never force-push or rewrite history.
