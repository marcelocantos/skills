# Retro worker

You are producing a system retrospective from transcript evidence. Your
output is a **draft report** returned as text to the root session, plus the
same text written to `~/think/analysis/retro-<END-DATE>.md`.

You are not summarising the week's work. You are looking for defects in the
machinery that produced it: skills, tools, MCP servers, scripts, hooks,
permissions, and the instruction files themselves.

The window is given in your prompt. Substitute it into every probe in
[`probes.md`](~/.claude/skills/retro/probes.md) — read that file now; it
holds the validated SQL and the performance rules that keep probes from
scanning a 24 GB index.

## Phase 1 — Inventory (cheap, do first, run in parallel)

Establish what *exists* before measuring what gets *used*:

```
ls -d ~/.claude/skills/*/                    # skills on disk
ls ~/.claude/*.md                            # companion instruction files
claude mcp list                              # registered MCP servers
ls -lt ~/.claude/*.md ~/.claude/skills/*/*.md | head -20   # mid-window changes
ls ~/think/analysis/retro-*.md               # prior retros
```

`~/.claude` is **not** a git repo and is not tracked by yadm, so there is
no local history for instruction or skill changes — mtime and the mnemo
index are all you get. For a queryable version, mnemo indexes both:

```sql
SELECT 'skill' AS kind, file_path, updated_at FROM skills
WHERE updated_at >= datetime('now','-7 days')
UNION ALL
SELECT 'config', file_path, updated_at FROM claude_configs
WHERE updated_at >= datetime('now','-7 days')
ORDER BY updated_at DESC;
```

A finding whose fix landed mid-window is not a finding; check this list
before writing anything up.

Read the two most recent prior retros in full. Their unactioned proposals
are inputs to Phase 5, and re-deriving a finding you already made is the
main way this skill wastes tokens.

## Phase 2 — Probes

Run the full battery from `probes.md`, sections A through E. Batch
independent probes into single messages — five to six `mnemo_query` calls
at a time. Do not skip a section because an earlier one looked productive;
sections C (dead surface) and D (cost) produce the findings that never
surface any other way, precisely because nothing errors.

Write raw probe output to the scratchpad as you go
(`<scratchpad>/retro-probes.md`). You will need to quote exact counts and
session IDs later, and re-running a probe to recover a number you already
had is waste.

If a probe returns no qualifying rows, record `clean` against it. Coverage
you did not achieve must not read as coverage that came back empty.

## Phase 3 — Drill-down

A probe row is a *symptom*. A finding names a *mechanism*. Convert one to
the other by reading the actual transcript around the top rows:

- `mnemo_search` with `expand: "segment"` for a phrase from the error text;
- `mnemo_read_session` on a cited `session_id` when you need the sequence;
- `mnemo_tool_result` when the truncated `sample` column is not enough.

Drill into, at minimum: the top 3 rows of A1, every distinct signature in
A4, every hit in B3, every B1 interrupt cluster, and every broken trigger
from C3. For each, answer three questions and write the answers down:

1. **What actually happened?** The sequence, in one or two sentences.
2. **Why did the system permit it?** Name the missing or mis-worded rule,
   the missing tool, the wrong default, the absent guard. If you cannot
   name it, you do not have a finding — drop the row.
3. **What is the cheapest change that makes recurrence impossible?**
   Prefer, in order: a mechanical guard (hook, permission rule, wrapper
   script, lint) > a tool or skill change > an instruction change. Text
   that must be read and remembered is the weakest fix available, and it is
   the one that has already failed if the item is recurring.

## Phase 4 — Triage

Score each surviving finding:

```
impact = frequency × cost-per-occurrence × blast-radius
```

where cost-per-occurrence is wasted wall-clock, tokens, or user attention,
and blast-radius is 1 for a single repo, 3 for the fleet, 10 for anything
touching secrets, data loss, or a violated hard rule.

Then bucket by fix class — instruction, skill, tool/MCP, script,
permission/hook, retirement, target — because the root session routes by
that bucket. Every finding carries exactly one class; a finding that needs
two changes is two findings.

Apply the thresholds from `SKILL.md`: ≥2 occurrences across ≥2 sessions, or
one occurrence with a large blast radius. Below the bar and interesting
anyway → a single `## Watch list` line, no proposal.

Then apply the **deletion quota**: from the C-section probes, name at least
one candidate for retirement, with the evidence for and against. If nothing
qualifies, say so and show the numbers that rule it out.

## Phase 5 — Recurrence check

For every proposal, grep the prior retros for the same subject. Mark
matches `RECURRING (Nth retro)` and promote them above everything else at
the same impact score.

A recurring proposal may **not** be re-proposed in its original form. The
previous form demonstrably did not work. Escalate the fix class one step
toward mechanical enforcement — an instruction that failed twice becomes a
hook, a permission deny rule, or a check inside the skill that owns the
workflow. Say explicitly what is being escalated and why.

## Phase 6 — Report

Write to `~/think/analysis/retro-<END-DATE>.md`, and return the same text:

```markdown
# System retro — <START> to <END>

**Corpus**: N sessions (I interactive / S subagent / W worktree),
M messages, R repos. Index freshness: <mnemo_divergence gaps, or "converged">.
**Probes**: X run, Y clean, Z skipped (<reason>).

## Findings

### F1. <One-line statement of the defect> — <fix class> — impact <score>
**Evidence**: <counts>; sessions `<id>`, `<id>`.
**Mechanism**: <why the system permitted it>.
**Proposal**: <the specific change: file, and what changes in it>.
**Cost of not doing it**: <what recurs>.

### F2. …

## Retirement candidates
<the deletion quota, with evidence>

## Watch list
<sub-threshold observations, one line each>

## Not findings
<probes that came back clean, one line each — proof of coverage>
```

Ordering is by impact, `RECURRING` first within a tier. Ten findings is a
good retro; thirty is a dump that will not be actioned. If you have more
than ten above threshold, merge the ones sharing a mechanism — a single
root cause with five symptoms is one finding with five pieces of evidence.

## Rules

- **Quote, never characterise.** Counts and session IDs, not "several" or
  "often".
- **A proposal names its file.** "Tighten the worktree guidance" is not
  actionable; "add to `~/.claude/fan-out.md`: worktree agents must derive
  paths from `git rev-parse --show-toplevel`, never from a parent-supplied
  absolute path" is.
- **Shared behaviour goes to `AGENTS.md`, Claude-only mechanics to
  `CLAUDE.md`.** Never propose the same rule in both — parallel copies are
  an existing, explicitly-banned failure mode.
- **Prefer subtraction.** Before proposing new instruction text, check
  whether an existing rule already covers it and simply failed to fire.
  That is a *trigger* fix, not a new rule; adding a second rule saying the
  same thing makes both weaker.
- **Do not apply anything.** You produce the draft; the root session
  obtains consent and applies. The one exception is the report file itself.
- **Do not moralise.** Findings are defects in machinery, not failures of
  character — yours or the user's. State the mechanism and the fix.
