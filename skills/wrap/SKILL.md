---
name: wrap
description: Pre-clear housekeeping — update targets, capture learnings, prepare for next /cv cycle.
user-invocable: true
---

Prepare target state for a clean `/clear`. This is the closing half
of the `/clear` → `/cv` cycle: update targets so the next session's
`/cv` starts from accurate state.

## Dual-write (bullseye)

When the bullseye MCP server is available (check if `bullseye_update`
is in the tool list), mirror all target mutations to bullseye:

- **Status changes**: call `bullseye_update(cwd, id, status)`.
- **New targets**: call `bullseye_add(cwd, ...)` with full target data.
- **Retirements**: call `bullseye_retire(cwd, id)`.
- **Reframings**: call `bullseye_update(cwd, id, name, acceptance, ...)`.
- **Weight changes**: call `bullseye_update(cwd, id, value, cost)`.

If bullseye is not available, proceed with markdown-only.

The `cwd` parameter should be the project's working directory.

## Steps

### 0. Safety net (write-first)

**This step must complete before anything else.** Context exhaustion
is the most common `/wrap` failure mode — the agent runs out of
context mid-analysis and nothing gets persisted.

Immediately write `wrap-draft.md` to the project's auto-memory
directory. No analysis, no user confirmation — just dump what you
know right now from conversation context. Keep it under 60 lines.

```markdown
# Wrap draft (YYYY-MM-DD)

## Work completed
- <bullet list of what was done>

## Target progress
- 🎯TN: <status change or reframing>

## In-flight work
- <uncommitted changes, partially implemented features>

## Key decisions
- <architectural choices, trade-offs, user preferences>

## Learnings
- <debugging insights, gotchas, non-obvious discoveries>

## Raw references
Files read or modified this session (with line ranges where relevant):
- `src/Foo.cpp:120-180` — <what was found/changed>
- `ge/tools/ios/main.mm` — <what was found/changed>

URLs discussed:
- <any URLs shared by user or fetched during session>

Transcript excerpts (key quotes from user decisions):
- "<verbatim user quote about a decision>" (re: <topic>)
```

The **Raw references** section is critical — it gives a fresh session
cheap pointers to reconstruct context without re-reading the full
transcript. Include:

- **File paths with line ranges** for files that were read, modified,
  or central to discussion. Annotate briefly what was found/changed.
- **URLs** shared by the user or fetched during the session (docs,
  gists, external references, chat transcripts).
- **Transcript excerpts** — short verbatim quotes of key user
  decisions or preferences that shaped the work direction. These are
  the hardest to reconstruct and the most valuable to preserve.

This file is a **safety net** — if context runs out during later
steps, the next session can recover from it. If `/wrap` completes
normally, it gets cleaned up in Step 6.

### 1. Scan the session

Review the conversation for:

- **Work completed** — what was built, fixed, merged, or shipped.
- **Target progress** — which active targets moved closer to (or
  achieved) their desired state.
- **New targets discovered** — quality issues, missing capabilities,
  or inconsistencies surfaced during work.
- **Reframings** — targets that turned out to be wrong, incomplete,
  or pointing at the wrong thing (per the convergence model: update
  the target, not just the plan).
- **User requests** — explicit asks to change priorities, weights,
  scope, or retire targets.
- **Blockers found** — dependencies, external constraints, or
  technical obstacles that affect future work.
- **Learnings** — debugging insights, architectural decisions, or
  gotchas that would be hard to reconstruct.

### 2. Propose target updates

Apply the changes directly — don't ask for confirmation. Present a
summary of what was written, grouped by type:

```
## Target updates applied

**Status changes:**
- 🎯T1 "Target name": identified → converging (acceptance criteria X met)
- 🎯T3 "Target name": converging → achieved

**New targets:**
- 🎯T5 "New target name": <desired state> (discovered while working on 🎯T1)

**Reframings:**
- 🎯T2: was "X", should be "Y" because <reason>

**Weight changes:**
- 🎯T4: weight 3 → 5 (user requested higher priority)

**Retirements:**
- 🎯T6: no longer relevant because <reason>

**No changes:** 🎯T7, 🎯T8
```

### 3. Write target updates

Apply changes to `docs/targets.md` (or the project's configured
targets path). Move achieved targets to the `## Achieved` section.
Add new targets to `## Active`.

### 4. Save residual context

Check whether the session produced insights that don't belong in
`targets.md` but would help future sessions:

- **Debugging insights** — root causes, non-obvious failure modes.
- **Architectural decisions** — trade-offs made, alternatives rejected.
- **External state** — things learned about APIs, services, or
  dependencies that aren't captured in code or targets.

If so, write or update topic files in the auto-memory directory
(not `stash-context.md` — that's `/stash`'s domain). Keep entries
concise.

### 5. Update MEMORY.md

Write a `## Last session` section at the **top** of `MEMORY.md` in
the project's auto-memory directory (create the file if it doesn't
exist). This section is automatically loaded into every new
conversation, so it survives `/clear` without any explicit action.

Replace any existing `## Last session` section — there should only
ever be one. Keep it concise (aim for under 20 lines) to avoid
bloating the always-loaded context. Include:

- **What happened** — 1-2 sentence summary of the session.
- **Targets affected** — which targets changed and how (reference
  the target updates from Step 3).
- **In-flight work** — anything started but not finished, with
  enough context to resume.
- **Key context** — blockers, gotchas, or decisions that the next
  session needs to know immediately (not buried in a topic file).

```markdown
## Last session
**Date**: YYYY-MM-DD

Summary of what happened.

**Targets**: 🎯T1 achieved, 🎯T3 converging (details).

**In-flight**: Description of unfinished work if any.

**Context**: Key things the next session needs to know.
```

If Step 4 created topic files, reference them here:
`See also: memory/debugging.md`

### 6. Clean up and report

Clean up `wrap-draft.md` by executing
`~/.claude/skills/wrap/cleanup.sh <auto-memory-directory>`
(pass the directory you wrote `wrap-draft.md` into in Step 0). The proper files
(targets, MEMORY.md, topic files) now contain everything.

Output:

```
Ready to clear.
- N target(s) updated, M new, K achieved, J retired
- MEMORY.md updated (will persist after /clear)
- [Context saved to memory/topic.md] (if applicable)
- Safety net cleaned up ✓
```

## Notes

- `/wrap` writes a `## Last session` section to `MEMORY.md`, which
  the system auto-loads into every conversation. This gives the next
  session immediate awareness of what just happened. `/stash` is
  still available for deeper context preservation if needed, but
  `/wrap` covers the common case.
- `/wrap` does **not** run `/cv` — it prepares state so the next
  `/cv` is accurate. Don't evaluate gaps here; just record what
  happened.
- If there are no changes to make, say so briefly and confirm the
  user is ready to clear.
- **Interrupted wrap recovery**: If `wrap-draft.md` exists in the
  auto-memory directory at the start of a new session, it means a
  previous `/wrap` was interrupted (likely by context exhaustion).
  `/cv` and `/waw` check for this file and surface its contents.
