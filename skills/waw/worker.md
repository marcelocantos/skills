# /waw Worker — Where Are We?

The user has been away and needs to get back up to speed. Gather all
context and produce a concise context-restoration briefing.

## Progress reporting

Before starting each section, emit a progress heading **on its own line
followed by a blank line**, then proceed to tool calls. Use `##` for
major sections. Examples:

## Gathering context

## Git activity

## Target status

## Maintenance status

Do not put any other text on the same line or immediately after the
heading — the blank line is required. These headings are picked up by
the Agent framework and forwarded to the root session as progress
notifications.

## Gathering context

Execute `~/.claude/skills/waw/gather.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`, just invoke the path as the
command). This single script collects repo name, branch, working tree
state, recent commits, stash list, diff stats, project CLAUDE.md,
auto-memory files, and GSD/planning state — all in one call with
markdown heading delimiters (`# section`).

Then produce a concise context-restoration briefing from that output,
covering the following sections. Skip any section that has nothing to
report.

## Summary

Include the current repository name in the heading, e.g.
"## Summary — myproject". Call
`mnemo_recent_activity(repo=<current_repo>)` first — its output is the
primary source for the session narrative. Use it for what happened, when,
and which targets were touched. Fall back to the git log from
`gather.sh` only if mnemo returns nothing or is unavailable. Then write
one or two sentences covering what was accomplished and where things
stand right now. If conversation context has been compacted, note this
and flag that details from before the compaction boundary may be
approximate.

## Working tree state

Use the `status`, `diff-stat`, and `diff-cached-stat` sections from the
gather output. Report uncommitted changes briefly — file names and what
changed, not full diffs. These often represent the exact point where
work was interrupted.

## Git activity

List commits made during this session (use judgement on how far back to
look). One line each — hash and message.

## Key decisions

Call `mnemo_search(query="decision OR decided OR trade-off OR chose",
repo=<current_repo>, limit=10)` to surface recent decisions from session
transcripts. Combine with auto-memory for stable cross-session facts.
If the session involved design discussions, trade-off decisions, or
explicit choices to do or not do something, summarise them briefly.
This helps the user remember *why* things are the way they are.

## Build / test status

If the last build or test run had failures, surface them prominently —
they're likely the most urgent thing to deal with. If everything was
green, say so briefly.

## Open TODOs

Invoke the `/todo` skill to surface open TODO items for the project.
Include its output as this section.

## Target status

Call `bullseye_summary(cwd)` (where `cwd` is the project's working
directory). This single call returns grouped targets with rollup counts,
frontier, blocked targets, stale targets, and WSJF ranking. If
`bullseye_summary` is not available, fall back to `bullseye_list(cwd)`
and `bullseye_frontier(cwd)`.

If the bullseye MCP server is not registered (tool not found), **stop
and report**:

> **Error: bullseye MCP server is not registered.**
> Add it via `claude mcp add` or check `~/.claude.json`. /waw needs
> bullseye for the target status section.

If bullseye returns no targets (empty project), skip this section.

Relay the summary output, adding a one-line gap assessment per target
based on session context (what you know from mnemo and the conversation).
End with: "Run `/cv` for full gap analysis and recommendations."

## Maintenance status

If `docs/audit-log.md` exists in the repo, read it and present a brief
maintenance summary. Skip this section if the file doesn't exist.

Each entry starts with `## YYYY-MM-DD — /skill-name [optional context]`.
Parse entries and report:

**Key dates** — time since last audit, last release (with version), and
last docs pass. Use "never" if no matching entry exists.

**Unresolved deferred items** — collect items from **Deferred** sections.
An item is resolved if a subsequent entry's outcome mentions addressing
it, or if a later entry for the same skill has no deferred items. Show
only unresolved items, grouped by entry date. If none, say so.

**Nudge** — if unresolved deferred items exist, mention them.
Otherwise, note the project is healthy.

## What's next?

Check `mnemo_recent_activity(repo=<current_repo>)` for in-flight work
patterns — if the last session was actively working on a specific target
or feature, suggest continuing it. Combine with the working tree state
and frontier targets to infer what was likely to happen next. Present
one or more concrete continuation options for the user to pick from.
Frame these as actionable choices, not open-ended questions.

Return the full briefing as your result.
