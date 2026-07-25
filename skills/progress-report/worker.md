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

Reports are **always single-week** — a strict 7-day window from Monday to
Sunday (`end − start == 6 days`). **Never emit a report spanning more than one
week.** If several weeks are outstanding, produce **one report per week**,
oldest first (see "Multiple pending weeks" below).

To find the week(s) to report:

1. Find the most recent `reports/weekly-report-*.md` file in the report repo.
2. Extract the end date from its title (the Sunday after the `…`). Call it
   `last_end`.
3. Find the most recent Sunday on or before today. If today is Sunday, confirm
   with the user that no more work will be done today before including it; call
   the result `latest_sun`.
4. The pending weeks are the Sundays strictly after `last_end` up to and
   including `latest_sun`. Each pending week is the 7-day window
   `[that Sunday − 6 days … that Sunday]` (Monday … Sunday).

- If there are **no** pending weeks (`last_end >= latest_sun`), the period is
  empty — ask the user for guidance.
- If there is **exactly one**, proceed with Phases 1–2 for that single week.
- If there are **two or more**, see "Multiple pending weeks" immediately below.

If no previous report exists, ask the user for the start date (which must be a
Monday), then treat every whole week from there to `latest_sun` as pending.

**Invariant — assert before Phase 1 of every report:** the period is exactly
7 days (`end == start + 6 days`), `start` is a Monday, and `end` is a Sunday.
If this does not hold, **stop and report the discrepancy** rather than
generating a multi-week or misaligned report.

Confirm the week(s) with the user before proceeding.

### Multiple pending weeks

When two or more weeks are outstanding, do **not** combine them into one
report. Run Phases 1 and 2 once per pending week, **oldest first**, each with
its own strict 7-day `gather.sh` window, its own daily-activity chart, and its
own report file, Reports entry, and Metrics row. Treat each week as if the
prior weeks were already published — the immediately-preceding week's report is
the "previous report" for narrative continuity, so read it before writing the
next. Generate all pending reports before returning, and present them together
in the draft output for review. The cumulative sections (Journey So Far,
totals, timeline) are rewritten **once**, reflecting the state after the last
pending week.

## Phase 1: Data gathering

**Start by running the companion gathering script** with BOTH the period start
date and an explicit exclusive end bound. The second argument is the day
**after** the period's last day (the Monday after the end Sunday). Always pass
it — omitting it makes the scan run through *now*, silently pulling in
out-of-period commits dated after the period. That defect bit a real run
(rustuml's next tranche and a large bgfx purge leaked in), so this is not
optional:

```
~/.claude/skills/progress-report/gather.sh "<start YYYY-MM-DD>" "<end-Sunday + 1 day, YYYY-MM-DD>"
```

For example, the single week ending Sunday 2026-06-28 (Monday 2026-06-22 …
Sunday 2026-06-28) → `gather.sh "2026-06-22" "2026-06-29"`.

(It is already `chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command.)

This script scans all repos under `~/work/` for commits in the half-open window
`[start, end)`, collecting per-repo commit logs and diff stats. Parse its output
to identify active repos and key metrics.

**Line stats exclude `**/vendor/**` and `**/node_modules/**`** (pathspecs in
`gather.sh`). Headline ☲ and per-repo ±lines use the `landed:` line only. When a
repo also has `landed-vendor-excluded: +N/-M`, footnote that bulk — do not fold
it into the Metrics table or the executive-summary key metrics line. Commits that
only touch vendor still count toward ℂ.

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

### "The Journey So Far" rewrite

Rewrite the `## The Journey So Far` narrative section at the top of
the report repo's `README.md` **from scratch** each iteration. Do not
read the existing section before drafting — write a fresh narrative
grounded in the current totals, this week's work, the achievements
list, and (as needed) the previous reports. The section contextualises
the cumulative body of work: total days, commits, languages, traditional
equivalent, the nature of the work, the human role, and what stands out.

Keep the tone confident, dense, British English, no emojis; feel free
to restructure, re-emphasise, or change examples. It is fine —
expected, even — for successive rewrites to converge on similar
observations; don't force artificial differences. Just start from a
blank page.

**This is an overview, not a catalogue.** The per-project enumeration
— which repos, releases, and features — lives in *Greatest Hits* and
the weekly reports. Do **not** reproduce it here. The Journey conveys
the *character and significance* of the cumulative body of work: what
kind of work it is, what makes it notable, and what the headline
numbers mean. Describe qualities — breadth, rigour, compounding
tooling, the inverted human role — and name at most one or two
projects as illustration. If a paragraph becomes "a X — **foo** — that
does Y" three times over, it has slipped into enumeration; pull back to
the general statement. A reader should finish with a *sense* of what
was achieved, then descend to Greatest Hits and the reports for
specifics.

**Length budget (sub-linear, by series length).** Even as an overview
the section may deepen as the body of work grows, but only
*sub-linearly*. Let `N` = the number of weekly reports including this
one (count `reports/weekly-report-*.md`). Hold it to: **~300 words** at
N ≤ 8; **~400** at 9–16; **~500** at 17–28; **~600** at 29–44; **~700**
at 45–72; **~800 (hard ceiling)** at 73+. The curve is logarithmic —
~100 words per doubling of the week span — so it keeps decelerating and
never runs away. Length is a ceiling, not a target: a tighter overview
is always better than a padded one.

Include the rewritten section in the draft output so the user can
review it alongside the report. After approval, Phase 3 stages the
updated README.

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
