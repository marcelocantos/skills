# /progress-report Worker — Weekly Progress Report

End-to-end logic for generating a weekly progress report for Marcelo Cantos. Scans all repos for git activity, writes the report draft, and returns it. Phase 3 (commit and push) is handled by the root session after user approval.

## Context

- **Report repo**: `~/work/github.com/marcelocantos/progress-reports`
- **Repos root**: `~/work/github.com/`
- **Organisations**: `squz`, `marcelocantos`, `arr-ai`, `anz-bank`
- **Guide**: `docs/guide.md` in the report repo — read it in full before starting

## Progress reporting

Before starting each phase, emit a progress heading **on its own line
followed by a blank line**, then proceed to tool calls. Use `##` for
major phases and `###` for sub-steps. Examples:

```
## Determining the period

## Phase 1 — Data gathering

### Scanning marcelocantos repos

### Scanning squz repos

## Phase 2 — Writing the report
```

Do not put any other text on the same line or immediately after the
heading — the blank line is required. These headings are picked up by
the Agent framework and forwarded to the root session as progress
notifications.

## Determining the period

The period ends on the most recent Sunday. If today is Sunday, confirm with the user that no more work will be done today before including it as the end date.

To find the start date:

1. Find the most recent `reports/weekly-report-*.md` file in the report repo.
2. Extract the end date from its title (the date after the `…`).
3. The new period starts the day after that end date.

If the start date is after the end date (i.e. the previous report already covers through this Sunday or later), the period is empty — ask the user for guidance.

If no previous report exists, ask the user for the start date.

Confirm the period with the user before proceeding.

## Phase 1: Data gathering

**Start by running the companion gathering script** with the period start date:

```
~/.claude/skills/progress-report/gather.sh "<YYYY-MM-DD start date>"
```

(It is already `chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command.)

This script scans all repos under `~/work/` for commits since the given date, collecting per-repo commit logs and diff stats. Parse its output to identify active repos and key metrics.

Then follow guide sections 1.1–1.5 and section 4 (authorship). Use `~/work/github.com/` as the scan root.

For each active repo, read commit diffs to understand the substance of the changes. Use parallel subagents where possible (e.g. one per organisation or per repo) for the deeper analysis.

Present a summary of active repos, commit counts, and key themes before proceeding.

## Phase 2: Write the report

Follow guide sections 2, 3, and 4 to write `reports/weekly-report-<YYYY-MM-DD>.md` (date = last day of period) in the report repo.

Read the previous report first to understand what projects have already been introduced and avoid re-explaining them (guide section 5).

### Daily activity chart

Generate the daily activity SVG chart from the `# daily_active_repos` section of the `gather.sh` output. Extract those lines and pipe them to the chart script:

```sh
echo "<daily_active_repos lines>" | ~/.claude/skills/progress-report/daily-chart.py \
    -o ~/work/github.com/marcelocantos/progress-reports/reports/daily-activity-<YYYY-MM-DD>.svg
```

Embed the chart in the report's Metrics section (after Testing, before Ideas & Innovations) per guide section 3.7.

### Timeline chart

Regenerate the full-history timeline chart and per-week charts (guide section 6, step 3):

```sh
~/.claude/skills/progress-report/timeline-chart.py \
    --since 2026-01-19 \
    --cache ~/work/github.com/marcelocantos/progress-reports/data/daily-repos.yaml \
    --weekly-dir ~/work/github.com/marcelocantos/progress-reports/reports/ \
    -o ~/work/github.com/marcelocantos/progress-reports/reports/timeline.svg
```

This updates the top-level timeline in the README, regenerates the per-week chart for the current report, and updates the cache. Commit the updated cache alongside the charts.

### Achievements update

After writing the report, review `docs/achievements.md` against this
week's work. If any achievement from this period deserves a spot in the
top 50 (by meatiness — impact × difficulty), insert it at the
appropriate rank and drop the lowest entry to keep the list at 50. If an
existing entry was extended this week (e.g. more releases, broader
scope), update its description. Use the same format: super short bullet
(5–10 words), 1–5 🥩 ranking. The meatiness column links to the weekly
report where the achievement is most prominently described — use
`[🥩...](../reports/weekly-report-<YYYY-MM-DD>.md)`. When adding or
updating entries, set the link to the current report if this week is
where the achievement is biggest.

Include the updated `docs/achievements.md` in the draft output so the
user can review changes alongside the report.

Return the full draft report text as your result.
