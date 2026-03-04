---
name: progress-report
description: Generate and publish a weekly progress report from git activity across all repos.
user-invocable: true
---

# Generate Weekly Progress Report

End-to-end skill for generating a weekly progress report for Marcelo Cantos. Scans all repos for git activity, writes the report, updates the README, and commits.

## Context

- **Report repo**: `~/work/github.com/marcelocantos/progress-reports`
- **Repos root**: `~/work/github.com/`
- **Organisations**: `squz`, `marcelocantos`, `arr-ai`, `anz-bank`
- **Guide**: `weekly-report-guide.md` in the report repo — read it in full before starting

## Determining the period

The period ends on the most recent Sunday. If today is Sunday, confirm with the user that no more work will be done today before including it as the end date.

To find the start date:

1. Find the most recent `weekly-report-*.md` file in the report repo.
2. Extract the end date from its title (the date after the `…`).
3. The new period starts the day after that end date.

If the start date is after the end date (i.e. the previous report already covers through this Sunday or later), the period is empty — ask the user for guidance.

If no previous report exists, ask the user for the start date.

Confirm the period with the user before proceeding.

## Workflow

### Phase 1: Data gathering

**Start by running the companion gathering script** with the period start date:

```
~/.claude/skills/progress-report/gather.sh "<YYYY-MM-DD start date>"
```

(It is already `chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command.)

This script scans all repos under `~/work/` for commits since the given date, collecting per-repo commit logs and diff stats. Parse its output to identify active repos and key metrics.

Then follow guide sections 1.1–1.5 and section 4 (authorship). Use `~/work/github.com/` as the scan root.

For each active repo, read commit diffs to understand the substance of the changes. Use parallel subagents where possible (e.g. one per organisation or per repo) for the deeper analysis.

Present a summary of active repos, commit counts, and key themes before proceeding.

### Phase 2: Write the report

Follow guide sections 2, 3, and 4 to write `weekly-report-<YYYY-MM-DD>.md` (date = last day of period) in the report repo.

Read the previous report first to understand what projects have already been introduced and avoid re-explaining them (guide section 5).

Present the draft to the user for review. Incorporate feedback before proceeding.

### Phase 3: Update README and commit

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
