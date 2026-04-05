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
Phase 3 (Update README and commit):

## Phase 3: Update README and commit

Follow guide section 6:

1. Add a collapsible entry under `## Reports` (newest first).
2. Add a row to the `## Metrics` table (newest first).
3. Stage the new report and updated README together in a single commit.
4. Push to origin.

## Error handling

- If a repo's `.git` directory is missing or corrupt, skip it and note the issue.
- If `git log` produces no output for a repo in the period, exclude it silently.
- If the user rejects the draft, revise and re-present — do not commit until approved.
- Never force-push or rewrite history.
