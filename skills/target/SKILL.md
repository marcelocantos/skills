---
name: target
description: Manage targets — desired states for the project.
user-invocable: true
---

Manage targets for this project via the **bullseye** MCP server.
Targets are desired states expressed as testable properties, not tasks.
The source of truth is `docs/targets.yaml`; `docs/targets.md` is an
auto-rendered view updated by bullseye after every mutation.

## Step 1 — Gather context

Call `bullseye_list(cwd)` to get all active targets. If that fails
(no `targets.yaml`), call `bullseye_init(cwd)` to create one.

Also gather git state for implied target evaluation:
- Current branch and recent commits
- Open PRs and CI status (via `gh` if available)

## Step 2 — Act

Behaviour depends on arguments provided after `/target`.

### `/target` (no arguments) — Summarise

Call `bullseye_summary(cwd)`. This returns grouped targets with rollup
counts, frontier, blocked, stale, and WSJF ranking in one call. If
`bullseye_summary` is not available, fall back to `bullseye_list(cwd)`
and `bullseye_frontier(cwd)`.

Present the summary output directly — it already includes everything
the user needs: active targets grouped by parent, frontier highlighted,
blocked targets with blockers, and WSJF ranking.

### `/target <text>` — Add a new target

The text describes the desired state. From the description:

1. **Infer acceptance criteria** — how would you verify this state is
   achieved? Write concrete, testable criteria.
2. **Estimate value and cost**. For value, present the Fibonacci scale
   to the user and suggest a score:
   > Value? (1 = marginal, 2-3 = noticeable, 5 = meaningful,
   > 8 = significant, 13 = major, 20 = strategic)
   > I'd suggest **5** because ...
   Let the user confirm or adjust. Estimate cost from the codebase
   and show reasoning.
3. **Draft the target** and show it to the user for confirmation.
4. Call `bullseye_add(cwd, name, value, cost, acceptance, context, ...)`.

If the user provides additional context (like `origin:`, `tags:`,
`depends_on:`), honour those.

### `/target check <name>` — Evaluate a specific target

Call `bullseye_get(cwd, id)` to get the target. Then:

1. Read the acceptance criteria.
2. Investigate the codebase — search for the conditions described.
3. Report the gap: what's met, what's not, what's partially met.
4. If the target appears achieved, offer to retire it.

### `/target retire <name>` — Mark achieved

Find the target by name or ID. Call `bullseye_retire(cwd, id)`.
Ask the user how the cost estimate compared to reality and pass
`actual_cost` for calibration.

## Target numbering

Bullseye assigns IDs automatically via `bullseye_add`. The convention:

- **Top-level targets**: 🎯T1, 🎯T2, 🎯T3, ...
- **Related targets**: 🎯T1.1, 🎯T1.2, ... (use dotted IDs as a
  convention for grouping; structurally these are just `depends_on`
  edges, not a parent/child hierarchy)

Always use the 🎯T*N* prefix when referring to targets.

## Guidance

- A target is a desired **state**, not a task. Write it as an
  assertion: "All tests pass on Windows" not "Fix Windows tests."
- Acceptance criteria should be verifiable — ideally by reading code,
  running a command, or checking CI output.
- Three tracking systems, one flow: **TODOs** are the inbox,
  **targets** are the backlog (desired states), **GitHub issues** are
  the public interface. Items flow upward — TODOs get triaged into
  targets or issues. Suggest promoting them.
- When decomposing, prefer splits that create **independent**
  sub-targets over sequential dependencies. Independent sub-targets
  can be worked in parallel.
