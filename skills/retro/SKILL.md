---
name: retro
description: Mine the last week of session transcripts for concrete improvements to the system itself — skills, tools, MCP servers, scripts, CLAUDE.md/AGENTS.md, permissions, hooks. Produces an evidence-backed, ranked proposal list, applies the approved ones, and files targets for the rest.
user-invocable: true
---

# /retro

A retrospective on **the system**, not on the work. The question is never
"what did we build?" (that is `/progress-report`) — it is "what did the
machinery do badly, and what change to the machinery prevents it?"

Usage:

```
/retro                 # since the last retro, floor 7 days, cap 30 days
/retro 2w              # explicit window
/retro since 2026-07-01
/retro --repo mnemo    # scope to one repo
/retro --dry-run       # report only; propose nothing for application
```

## Prerequisites

The mnemo MCP server must be connected — every probe runs through
`mnemo_query`. If mnemo is unavailable, stop and report; do **not** fall
back to grepping `~/.claude/projects/**/*.jsonl` by hand (that workaround
is itself one of the anti-patterns this skill hunts for).

## Execution

**DELEGATE VIA AGENT.** Spawn one Agent (`subagent_type: general-purpose`,
`model: opus`) with the prompt `"Read and execute
~/.claude/skills/retro/worker.md. Window: <resolved window>. Return the
draft retro report text."`.

The worker owns Phases 1–5 (inventory, probes, drill-down, triage,
recurrence check) and returns a draft report. The root session owns
Phase 6 — presenting proposals, obtaining consent, and applying changes —
because applying edits to `~/.claude/**` is a decision the user makes with
the evidence in front of them.

Resolve the window before spawning:

1. `ls ~/think/analysis/retro-*.md | tail -1` → the previous retro's date.
2. Window start = that date, clamped to `[now-30d, now-7d]`. No prior
   retro → `now-7d`.
3. Pass the resolved start as an ISO date so the worker's SQL and the
   report header agree.

## Phase 6: consent and application (root session)

Present the draft's ranked findings. For each proposal the user approves,
apply it **in the same session** — a retro whose output is a document
nobody actions is a retro that cost tokens and changed nothing.

Routing by fix class:

| Fix class | Action |
|---|---|
| Instruction change (`~/.claude/AGENTS.md`, `CLAUDE.md`, companion `*.md`) | Edit directly. Shared behaviour → `AGENTS.md`; Claude-only mechanics → `CLAUDE.md`. Never both. |
| Skill change (`~/.claude/skills/**`) | Edit, then run `/republish-skills` once at the end for all skill edits together. |
| Permission / hook / env (`settings.json`) | Use the `update-config` skill. For allowlist gaps specifically, `mnemo_permissions` gives ready-made rules. |
| MCP server or CLI defect | File a bullseye target **in that server's repo** via `bullseye_put`, quoting the error signature and count. Do not fix inline unless trivial. |
| Script (new or broken) | Write it under the owning skill's directory, or `~/.local/bin` for cross-skill use. |
| Retirement (dead skill, dead pointer, dead MCP server) | Delete / unregister with consent. See the deletion quota below. |
| Anything larger | `bullseye_put` a target in the relevant repo. Never a TODO file. |

After applying, append a one-line `## Applied` section to the report file
recording what actually landed (commit SHAs where applicable), then commit
the report to `~/think`.

## The deletion quota

Every retro must evaluate **at least one retirement** and say so
explicitly in the report, even if the conclusion is "nothing to retire".
Instruction files, skills, and MCP servers all cost context on every
single session; an improvement process that only ever adds is a process
that degrades the system it is trying to improve.

Standing retirement candidates, computed by the worker's inventory probes:

- companion `*.md` files under `~/.claude/` never read in the window,
  despite a pointer in `CLAUDE.md` claiming they are mandatory;
- skills never invoked in the window;
- MCP servers registered but with zero tool calls in the window;
- instructions contradicted by observed behaviour every time they apply.

A never-fired mandatory pointer is a **two-sided** finding: either the
trigger wording is wrong (fix the trigger — see the `feedback_trigger_words`
memory) or the rule is dead weight (delete it). Decide which; do not leave
it ambiguous.

## Evidence discipline

Non-negotiable, and the worker enforces it:

- **No finding without a probe row.** Every finding cites a count and at
  least one `session_id`.
- **No proposal without a named mechanism.** "Agents seem confused about
  worktrees" is not a finding; "29 Bash calls returned `This agent is
  isolated in the worktree …` because worktree agents inherit absolute
  paths from the parent's cwd" is.
- **Frequency threshold.** A single occurrence is an anecdote. Propose an
  instruction change only at ≥2 occurrences across ≥2 sessions, or one
  occurrence with a large blast radius (data loss, secret exposure,
  >30 min of wasted wall-clock, a violated hard rule).
- **Recurrence is an escalation.** A proposal that appeared in a previous
  retro and was not actioned gets marked `RECURRING` and moves to the top;
  the fix is no longer "add a line to CLAUDE.md" (that demonstrably failed)
  but a mechanical enforcement — a hook, a permission deny rule, a wrapper
  script, or a lint.

## Error handling

- A probe that times out: narrow the window and retry once, then record it
  as `probe skipped` in the report rather than dropping it silently.
- No qualifying rows for a probe: report `clean` explicitly. Silence reads
  as coverage that did not happen.
- Never modify `~/.claude/**` without the user approving that specific
  proposal. Approval of one proposal is not approval of the batch.
