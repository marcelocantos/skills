---
name: cv
description: Evaluate convergence gaps on active targets and recommend next work.
user-invocable: true
---

## One tool, one call

The /cv skill is a thin shim over `bullseye_convergence`. Call it and
relay the full output. Everything else — standing invariants, target
gathering, frontier ordering, unreleased-fix detection, per-target
details, gap classification, recommendation — happens inside bullseye
and comes back in a single structured response.

### Default tier

```
bullseye_convergence(cwd=<project root>)
```

This runs `make bullseye` / `mk bullseye` for standing invariants,
scans git for unreleased fix commits, renders the target summary
with full frontier details inline, and computes a deterministic next
action.

### Scan tier — `/cv scan`

```
bullseye_convergence(cwd=<project root>, skip_invariants=true)
```

Skips the `make bullseye` invocation for a fast target-only snapshot.
Everything else runs. Use when you just want to see the current target
state without paying for a fresh invariants check.

### Full tier — `/cv full`

Same as default. The historical "full" distinction (exhaustive per-
target evaluation via codebase grep) is gone — bullseye's frontier
details plus the project-supplied `make bullseye` hook cover the same
ground deterministically. If you want deeper per-target scrutiny, do
it by reading the acceptance criteria inline in the `## Frontier`
section and deciding for yourself.

### Global tier — `/cv global`

Portfolio-level evaluation across all repos:

1. **Gather momentum** (optional, best-effort): call
   `mnemo_recent_activity(days=7)`. For each repo that appears in
   the activity, compute a momentum multiplier for its frontier
   targets. Heuristic: targets mentioned in recent sessions get
   `1.5×`; targets in repos with activity but not mentioned get
   `1.0×`; targets in repos with no recent activity get `0.7×`.
   If mnemo is unavailable, skip momentum (all targets default to
   `1.0×`).

2. **Run portfolio scan**:
   ```
   bullseye_portfolio(momentum=<computed multipliers>)
   ```

3. **Present results**: relay the full portfolio output, then add a
   brief summary:
   - **Top repos** (up to 3): repo name, WSJF score, top frontier
     target, and one-line reasoning for why this repo deserves
     attention now.
   - **Cross-repo edges**: if any cross-repo blockers or enablers
     exist, highlight them — these are the inter-project couplings
     that single-repo /cv can't see.
   - **Momentum report**: list repos by activity level (active /
     warming up / stale) based on the mnemo data. If mnemo was
     unavailable, note "momentum data unavailable — ranking by
     static WSJF only".

4. **Do not auto-execute.** Global mode is a read-only portfolio
   assessment. The user decides which repo to work on next. If they
   want to proceed, they should `cd` into that repo and run `/cv`
   for the repo-level evaluation with invariants.

## Relay the output verbatim

The convergence response is formatted for direct consumption. Dump it
back to the user as-is. Do **not** rewrite, summarise, or trim — the
deterministic sections (`## Invariants`, `## Unreleased fixes`,
`## Frontier`, `## Blocked targets`, `## Stale targets`,
`## Next action`) are what the user expects to see.

## Auto-execute

After relaying the output, read the `## Next action` section and
act on it mechanically:

- **Line starts with `**Execute now**: Work on 🎯T…`** — single top
  frontier target. Before starting work, emit a brief **execution
  preamble** so the user sees clearly what's about to happen, without
  having to re-scan the frontier wall:

  ```
  ### Executing 🎯T<ID> — <target name>

  **Acceptance (summarised):**
  - <each bullet, one line, paraphrased if long>

  **First step:** <one-sentence statement of the very first concrete
  action you're about to take — e.g. "explore current ingest entry
  points to scope the config surface" or "add `extra_project_dirs`
  to the config loader">
  ```

  The preamble is narration, not a decision point — do **not** stop,
  pause, or wait for confirmation. It exists purely to tell the user
  what you're doing clearly before you do it. Flow straight from the
  preamble into the first step in the same turn. Keep it tight: ≤6
  lines of acceptance summary, one line for the first step.

  Then begin work on that target, using the inline acceptance criteria
  and context from the `## Frontier` section.

- **Line starts with `**Execute now**: Work in parallel on N frontier
  targets…`** — tied top-focus targets. Emit a preamble naming each
  target in the fan-out (one line each: `🎯T<ID> — <name>`), then fan
  out via parallel Agent calls per the Teams directive in CLAUDE.md,
  one agent per target, each agent reading its target's inline details
  from the frontier section.

- **Line starts with `**Execute now**: Run /release…`** — unreleased
  fixes take precedence. Invoke the `/release` skill. Do NOT call
  `gh release create` directly; route through `/release` so its gates
  fire.

- **Line starts with `**Blocked**:`** — standing invariants are
  failing, validation errors, the frontier is empty, or the graph is
  malformed. Before reporting back to the user, attempt to **auto-fix
  mechanical issues** without asking — the user has zero patience for
  round-trip questions on issues /cv can resolve itself. See
  [Auto-fix on Blocked](#auto-fix-on-blocked) below for the catalogue
  of fixable shapes. After applying fixes, re-run convergence and act
  on the new recommendation. Only surface the block to the user if
  none of the fixable shapes apply or if a fix needs information you
  don't have.

- **Anything else** — unrecognised shape. Present to the user and
  ask for direction.

### Auto-fix on Blocked

A Blocked response is rarely a stop sign. It usually means the target
graph is in a state /cv can mechanically repair. Apply each fix
silently (a one-line note before the action is fine, but no
questions); after all applicable fixes, re-run `bullseye_convergence`
and follow the new recommendation.

**Fix 1: retire targets that describe themselves as already
achieved.** Scan the active targets in the convergence output. For
each target whose `name` ends in `✓` or whose `context` opens with
"Achieved YYYY-MM-DD", call `bullseye_retire(cwd, id)` immediately.
There is zero value in asking the user to confirm — the target's own
documentation says it's done.

**Fix 2: resolve tunnel warnings by promoting leaves to checkpoints.**
If the convergence output reports `## ⚠ Tunnel warnings`, each named
target is a work-kind leaf with no checkpoint reachable. For each
such target, decide between:
- `bullseye_put(cwd, id, showcase=true)` — when the target's
  acceptance criteria describe a user-visible result (a feature
  works, a binary runs, a check passes). This is the default fix.
- `bullseye_set_aside(cwd, id, reason=...)` — when project memory
  or the target's own context flags the work as parked / deferred /
  superseded. Use the documented rationale verbatim.

Don't ask the user to choose; pick from the target's own context and
project memory.

**Fix 3: write a missing standing-invariants hook.** If `## Invariants`
shows `⚠ **Standing-invariants hook not configured**`, write a
`Makefile` at the project root with a `bullseye:` rule wired to the
project's actual lint/test/clean-tree checks. The skeleton in the
convergence output is a starting point; tailor it to the language
(cargo / go / npm / pytest / etc.). Do **not** auto-commit the new
Makefile — a fresh untracked file will fail the `clean-tree`
invariant on the next run, which is exactly what surfaces the file
to the user for review.

**Fix 4: re-run convergence after any fix.** After applying any of
the above, call `bullseye_convergence` again and follow the new
`## Next action`. The fixes compose — retiring achieved targets may
collapse tunnels; promoting leaves to checkpoints may reveal a fan-
out worth executing. Don't stop after one fix unless the new output
says to.

If after auto-fixes the result is *still* Blocked with an
unrecognised shape, then surface to the user.

### Suppressing auto-execute

If the user invoked `/cv scan`, relay the output but **do not
execute**. Scan is a read-only lightweight check; acting on a scan
skips the invariants safety net.

If the `## Invariants` section contains `⚠ **Standing-invariants
hook not configured**`, execution is still allowed — convergence
degrades gracefully and proceeds to a frontier recommendation with a
trailing "invariants unknown" caveat. But the user should know the
safety net is missing; surface that prominently before executing.

## Missing prerequisites

If `bullseye_convergence` returns an error rather than a convergence
response, read the error and diagnose:

- **No `targets.yaml` found** — the repo isn't using bullseye yet.
  Suggest `bullseye_init` or `/target` to bootstrap, and stop.
- **Schema version too new** — bullseye binary is out of date. Tell
  the user to `brew upgrade marcelocantos/tap/bullseye`, and stop.
- **Parse error / I/O error** — the targets file is broken. Relay
  the error and stop.

In all three cases, do not attempt to continue with convergence
evaluation — the tool contract is "convergence output or error,
nothing in between", and bullseye already handles the
missing-hook and broken-but-parseable cases internally.

## Gate enforcement

The suggested action will already be gate-routed by bullseye —
e.g., unreleased fixes produce `Run /release`, not
`gh release create`. Honour whatever skill names appear in the
recommendation; never substitute raw commands for their skill
wrappers. The skill wrappers exist to enforce pre-merge, pre-release,
and pre-publish gates the agent must not bypass.
