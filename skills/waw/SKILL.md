---
name: waw
description: "Where Are We?" — Context restoration after being AFK. Summarises session state, surfaces important details, and proposes continuation options.
user-invocable: true
---

The user has been away and needs to get back up to speed.

First, execute `~/.claude/skills/waw/gather.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command).
This single script collects repo name, branch, working tree state, recent
commits, stash list, diff stats, project CLAUDE.md, auto-memory files, and
GSD/planning state — all in one call with markdown heading delimiters (`# section`).

Before producing the briefing, check the auto-memory directory for
`wrap-draft.md`. If it exists, a previous `/wrap` was interrupted
(likely by context exhaustion). Read it and incorporate its contents
into the briefing — especially the "In-flight work" and "Key decisions"
sections, which represent lost context from the previous session.
Mention the interrupted wrap prominently so the user knows context
was recovered. After incorporating, clean it up by executing
`~/.claude/skills/wrap/cleanup.sh <auto-memory-directory>`.

Then produce a concise context-restoration briefing from that output, covering
the following sections. Skip any section that has nothing to report.

## 1. Summary

Include the current repository name in the heading, e.g.
"## Summary — myproject". Then one or two sentences covering what was
accomplished in this session and where things stand right now. If conversation
context has been compacted, note this and flag that details from before the
compaction boundary may be approximate.

## 2. Working tree state

Use the `status`, `diff-stat`, and `diff-cached-stat` sections from the
gather output. Report uncommitted changes briefly — file names and what
changed, not full diffs. These often represent the exact point where work
was interrupted.

## 3. Recent commits

List commits made during this session (use judgement on how far back to look).
One line each — hash and message.

## 4. Key decisions

If the session involved design discussions, trade-off decisions, or explicit
choices to do or not do something, summarise them briefly. This helps the user
remember *why* things are the way they are. Use the auto-memory and
conversation context to inform this section.

## 5. Build / test status

If the last build or test run had failures, surface them prominently — they're
likely the most urgent thing to deal with. If everything was green, say so
briefly.

## 6. Open TODOs

Invoke the `/todo` skill to surface open TODO items for the project. Include
its output as this section.

## 7. Convergence targets

If the gather output's `targets` section contains target data (not
"(not found)"), present a convergence summary:

- List active targets grouped by priority (critical → high → medium → low).
- For each target, show name, status, and a one-line gap assessment based
  on what you know from the session context and gather data.
- For targets with sub-targets, show a rollup count (e.g., "2/3 achieved").
- If any targets appear stale (status doesn't match apparent state), flag them.
- End with: "Run `/cv` for full gap analysis and recommendations."

Skip this section if no targets file exists.

## 8. Maintenance status

If `docs/audit-log.md` exists in the repo, read it and present a brief
maintenance summary. Skip this section if the file doesn't exist.

Each entry starts with `## YYYY-MM-DD — /skill-name [optional context]`.
Parse entries and report:

**Key dates** — time since last audit, last release (with version), and last
docs pass. Use "never" if no matching entry exists.

**Unresolved deferred items** — collect items from **Deferred** sections.
An item is resolved if a subsequent entry's outcome mentions addressing it,
or if a later entry for the same skill has no deferred items. Show only
unresolved items, grouped by entry date. If none, say so.

**Nudge** — if no audit in 30+ days, suggest `/audit`. If unresolved
deferred items exist, mention them. Otherwise, note the project is healthy.

## 9. What's next?

Based on the session context, infer what was likely to happen next. Present
one or more concrete continuation options for the user to pick from. Frame
these as actionable choices, not open-ended questions.
