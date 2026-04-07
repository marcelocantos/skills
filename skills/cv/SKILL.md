---
name: cv
description: Evaluate convergence gaps on active targets and recommend next work.
user-invocable: true
---

**DELEGATE VIA AGENT.** Spawn an Agent (subagent_type: general-purpose,
model: opus) with the prompt `"Read and execute
~/.claude/skills/cv/worker.md. Return the full report text."`.
Relay the agent's result to the user. After presenting the report,
decide whether to auto-execute the suggested action (see below).

## Bullseye evaluation

When the bullseye MCP server is available (check if `bullseye_rank` is
in the tool list), the worker must evaluate BOTH the old markdown
system and bullseye, then produce:

1. **A synthesised recommendation** — not two separate lists, but a
   single coherent recommendation that draws on both evaluations. When
   they agree, say so briefly. When they disagree, explain why and
   make a judgement call.

2. **A bullseye scorecard** — a dedicated section at the end of the
   report, formatted exactly as:

   ```
   ## Bullseye scorecard

   **Ranking**:        <-3 to +3>
   **Blocking**:       <-3 to +3>
   **Data quality**:   <-3 to +3>
   **Overall**:        <-3 to +3>
   **Markdown rec**:   🎯T<N> <name>
   **Bullseye rec**:   🎯T<N> <name>
   **Notes**: <brief, specific assessment>
   ```

   Score semantics (-3 = much worse, 0 = equivalent, +3 = much better
   than the markdown system):
   - **Ranking**: Did bullseye's WSJF ordering make sense? Did it
     surface the right top target?
   - **Blocking**: Did bullseye's dependency/blocking analysis match
     reality? Did it correctly identify what's blocked and what's free?
   - **Data quality**: Is the targets.yaml in good shape? Missing
     targets, stale fields, missing edges?
   - **Overall**: Holistic judgement — would you trust bullseye's
     recommendation over markdown's?

   Be honest and specific in Notes. This data will be mined via mnemo
   for insights about bullseye's readiness.

Pass this instruction to the worker agent as part of its prompt.

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

