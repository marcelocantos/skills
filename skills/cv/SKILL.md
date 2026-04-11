---
name: cv
description: Evaluate convergence gaps on active targets and recommend next work.
user-invocable: true
---

## Delegation

**DELEGATE VIA AGENT.** Spawn an Agent (subagent_type: general-purpose,
model: opus) with the prompt `"Read and execute
~/.claude/skills/cv/worker.md. Return the full report text."`.
Relay the agent's result to the user. After presenting the report,
decide whether to auto-execute the suggested action (see below).

## Auto-execute

After relaying the worker's report, check these conditions. If all
hold, execute the suggested action immediately — do not ask the user.
If any condition fails, state **which one** and **why**.

### Conditions (all must hold)

1. **Unblocked candidate(s) exist** — at least one unblocked target
   with a suggested action.
2. **No standing invariant violations** — tests pass and CI is green.
   If CI state is unknown, treat it as passing.
3. **Not scan tier** — scan is lightweight; don't attach execution.

### Single target

When there is one top-ranked unblocked target, say:

```
Clear next step — executing now.
```

Then proceed with the suggested action.

### Parallel execution

When there are **2+ unblocked targets** at the top of the ranking
that don't depend on each other, **fan out** via multiple Agent calls
— one per target, using the model guidance from the Teams directive
in CLAUDE.md.

### When blocked

Present the suggestion without executing and state the blocker:

```
Auto-execute blocked: [condition N — reason].
```
