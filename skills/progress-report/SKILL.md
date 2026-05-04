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
Phase 3 (Update README and publish):

## Phase 3: Update README and publish

The `progress-reports` repo declares `pr-workflow: skip` in its
`## Gates` section and has no branch protection on `master`. Publication
is a direct push — no feature branch, no PR, no merge step.

Follow guide section 6 for the README updates, then publish:

1. Replace the `## The Journey So Far` section with the rewritten
   narrative from the approved draft.
2. Add a collapsible entry under `## Reports` (newest first).
3. Add a row to the `## Metrics` table (newest first).
4. Stage the new report, updated README, achievements, charts, and cache
   together in a single commit on `master`.
5. Push: `git push`.

## Error handling

- If a repo's `.git` directory is missing or corrupt, skip it and note the issue.
- If `git log` produces no output for a repo in the period, exclude it silently.
- If the user rejects the draft, revise and re-present — do not commit until approved.
- Never force-push or rewrite history.
