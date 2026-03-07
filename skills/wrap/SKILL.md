---
name: wrap
description: Pre-clear housekeeping — update targets, capture learnings, prepare for next /cv cycle.
user-invocable: true
---

Prepare convergence state for a clean `/clear`. This is the closing
half of the `/clear` → `/cv` cycle: update targets so the next
session's `/cv` starts from accurate state.

## Steps

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

Present a summary of proposed changes, grouped by type:

```
## Proposed target updates

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

Wait for user confirmation before writing. The user may adjust,
add, or reject individual changes. Iterate until they confirm.

### 3. Write target updates

Apply confirmed changes to `docs/targets.md` (or the project's
configured targets path). Move achieved targets to the `## Achieved`
section. Add new targets to `## Active`.

### 4. Save residual context

Check whether the session produced insights that don't belong in
`targets.md` but would help future sessions:

- **Debugging insights** — root causes, non-obvious failure modes.
- **Architectural decisions** — trade-offs made, alternatives rejected.
- **External state** — things learned about APIs, services, or
  dependencies that aren't captured in code or targets.

If so, write or update topic files in the auto-memory directory
(not `stash-context.md` — that's `/stash`'s domain). Keep entries
concise and link them from `MEMORY.md` if one exists.

If nothing warrants saving, skip this step.

### 5. Report

Output:

```
Ready to clear.
- N target(s) updated, M new, K achieved, J retired
- [Context saved to memory/topic.md] (if applicable)
```

## Notes

- `/wrap` does **not** stash conversation context — use `/stash`
  before `/clear` if you also need that. The two are complementary:
  `/wrap` maintains convergence state, `/stash` preserves session
  context.
- `/wrap` does **not** run `/cv` — it prepares state so the next
  `/cv` is accurate. Don't evaluate gaps here; just record what
  happened.
- If there are no changes to make, say so briefly and confirm the
  user is ready to clear.
