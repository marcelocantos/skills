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
  frontier target. Say:

  ```
  Clear next step — executing now.
  ```

  Then begin work on that target, using the inline acceptance criteria
  and context from the `## Frontier` section.

- **Line starts with `**Execute now**: Work in parallel on N frontier
  targets…`** — tied top-focus targets. Fan out via parallel Agent
  calls per the Teams directive in CLAUDE.md, one agent per target,
  each agent reading its target's inline details from the frontier
  section.

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
