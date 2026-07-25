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
4. Refresh the `## At a Glance` bullets at the top of the README to match
   the updated Totals row (span, commits/repos/languages, human hours,
   generalist-years + multiplier, net-lines activity signal) — see guide
   section 6. It is a scannable mirror of the Totals, not a new source of
   figures.
5. Stage the new report, updated README, achievements, charts, cache, and
   any `data/line-excludes.yaml` updates from the worker together in a
   single commit on `master`.
6. Push: `git push`.

The worker must keep `data/line-excludes.yaml` current (new repos / new
fixture-or-vendor-like bulk) — see `worker.md` and `exclude-schema.md`.

When the worker produced **multiple single-week reports** (a catch-up run
covering more than one pending week), repeat steps 2–3 once per week — one
Reports entry and one Metrics row per report, newest first — and stage every
report file and its daily-activity chart in step 5. The Journey So Far, the At a
Glance bullets, and the timeline are cumulative: apply them once (steps 1, 4, and
the timeline regen), reflecting the state after the newest week. Commit the whole
batch together (e.g. `Add weekly reports <A> and <B>`).

## Error handling

- If a repo's `.git` directory is missing or corrupt, skip it and note the issue.
- If `git log` produces no output for a repo in the period, exclude it silently.
- If the user rejects the draft, revise and re-present — do not commit until approved.
- Never force-push or rewrite history.
