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
  failing, validation errors, or the frontier is empty. Do not
  execute. Relay the block reason to the user and wait for direction.

- **Anything else** — unrecognised shape. Present to the user and
  ask for direction.

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
