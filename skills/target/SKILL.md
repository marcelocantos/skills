---
name: target
description: Manage convergence targets — desired states for the project.
user-invocable: true
---

Manage convergence targets for this project. Targets are desired states
expressed as testable properties, not tasks.

## Step 1 — Gather

Execute `~/.claude/skills/target/gather.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`, just invoke the path as the
command). This script locates the targets file (checking CLAUDE.md for a
path hint, then trying common names) and dumps its contents.

Parse the output:
- `# claude-md-hint` — any mention of a targets file in CLAUDE.md.
- `# targets-file` — either `path: <path>` followed by `---` and the
  file contents, or `(not found)`.
- `# delivery` — the project's delivery definition from CLAUDE.md, or
  a default.
- `# git-state` — branch, open PRs, and CI status for implied target
  evaluation.

## Step 1.5 — Conformance check

If a targets file was found, check that it conforms to the current spec
(standard format below). Common drift:

- `Priority:` instead of `Weight:` — convert to weight using the
  value and cost model. For leaf targets, ask the user for value.
  For interior targets, derive value from gated targets. Estimate
  cost from the codebase.
- Missing `(value V / cost C)` annotation on weight — add it.
- Missing `Estimated-cost:` field — add it.
- Missing 🎯T*N* prefix on headings — add it (assign next unused number).
- Missing `<!-- last-evaluated: ... -->` comment — add it.
- Missing `## Achieved` section — add it.

If any targets need updating, fix them silently and continue. Don't
prompt the user — conformance updates are mechanical, not decisions.

## Step 2 — Act

Behaviour depends on arguments provided after `/target`.

### If no targets file was found

- **`/target` (no args)**: Report that no targets file exists and offer
  to create `docs/targets.md`.
- **`/target <text>`**: Create `docs/targets.md` automatically and add
  the target.

### `/target` (no arguments) — Summarise

Present all active targets sorted by weight (descending). For each
target show:

- Name (the `###` heading)
- Weight
- Status (identified / converging / achieved)
- One-line gap assessment — how far is the project from this state?
  Read relevant code, check for the conditions in the acceptance
  criteria, and make a brief judgement.

For targets with sub-targets (children that have a `Parent:` field
pointing to this target), show a rollup: "converging (2/3 sub-targets
achieved)" and list children indented below.

End with a count of active targets.

### `/target <text>` — Add a new target

The text describes the desired state. From the description:

1. **Infer acceptance criteria** — how would you verify this state is
   achieved? Write concrete, testable criteria.
2. **Estimate weight** — see [Value and cost model](#value-and-cost-model)
   below. For leaf targets, present the Fibonacci value scale to the
   user and suggest a score:
   > Value? (1 = marginal, 2-3 = noticeable, 5 = meaningful,
   > 8 = significant, 13 = major, 20 = strategic)
   > I'd suggest **5** because …
   Let the user confirm or adjust. For interior targets, compute
   value from the graph — no user input needed. Estimate cost from
   the codebase and show reasoning.
3. **Set status** to `identified`.
4. **Set Discovered** to today's date.
5. **Draft the target entry** in the standard format (see below) and
   show it to the user for confirmation/refinement before writing.

If the user provides additional context (like `parent:`, `origin:`,
`gates:`), honour those.

After confirmation, append to the `## Active` section of the targets
file. If the file doesn't exist, create it with the standard structure.

### Output

Always finish by printing the absolute path to the targets file so
the user can click to open it. Example: `Targets: /Users/foo/project/docs/targets.md`

### `/target check <name>` — Evaluate a specific target

Find the target by name (fuzzy match on `###` headings). Then:

1. Read the acceptance criteria.
2. Investigate the codebase — search for the conditions described,
   run relevant checks if feasible (e.g., grep for printf if the
   target is "all diagnostic output uses spdlog macros").
3. Report the gap: what's met, what's not, what's partially met.
4. If the target has sub-targets, evaluate each and roll up.
5. Check implied targets (delivery status) if the target has code
   changes.
6. If the target appears to be achieved, offer to update its status.

### `/target retire <name>` — Move to achieved

Find the target by name. Move it from `## Active` to `## Achieved`.
Add an `Achieved: YYYY-MM-DD` line. If it has sub-targets, warn if
any are not yet achieved.

If the target has an `Estimated-cost:` field, ask the user how the
estimate compared to reality and record `Actual-cost:` alongside.
This calibrates future cost estimates.

## Target numbering

Every target gets a stable number prefixed with 🎯:

- **Top-level targets**: 🎯T1, 🎯T2, 🎯T3, … (assigned sequentially on
  creation, never reused after archival).
- **Sub-targets**: 🎯T1.1, 🎯T1.2, … (parent number + sequential suffix).
- **Deeper nesting**: 🎯T1.2.1, 🎯T1.2.2, … (recursive).

The 🎯T prefix is inseparable — no space between 🎯 and T. This keeps
the identifier atomic across line breaks.

Always use the 🎯T*N* prefix when referring to targets: in headings,
in status reports, in conversation with the user, and in cross-references
(e.g., `Parent: 🎯T1`).

## Value and cost model

Weight = value / cost. But value and cost are estimated differently.

### Value

All value originates from **user-facing outcomes** — things a human
experiences: "smooth 60 FPS gameplay," "library consumers can upgrade
without breaking," "CLI responds in under 100ms." Infrastructure,
tooling, and architecture have no direct value — they derive value
solely from the outcomes they enable.

**Leaf targets** (targets that don't gate any other target) are the
value sources. The user scores these on a modified Fibonacci scale:

| Score | Meaning |
|-------|---------|
| 1     | Nice-to-have, marginal improvement |
| 2-3   | Noticeable quality-of-life improvement |
| 5     | Meaningful capability or quality gain |
| 8     | Significant feature, users would miss it |
| 13    | Major capability, core to the product |
| 20    | Project-defining, strategic |

**Interior targets** (targets that gate other targets via `Gates:`
or `Parent:` relationships) derive value automatically:

> value = sum of values of all targets this target directly gates

The agent computes this by walking the dependency graph. No human
input needed for interior targets. If an interior target also has
direct user-facing value (rare), split the user-facing part into its
own leaf target.

### Cost

The agent estimates cost by analysing the codebase:

- Count files and functions that need to change.
- Assess complexity: new module vs. mechanical edit, cross-cutting
  vs. localised.
- Compare to completed targets with recorded actuals.

Express cost on the same Fibonacci scale, where:

| Score | Meaning |
|-------|---------|
| 1     | A few minutes, trivial change |
| 2-3   | A focused session, straightforward |
| 5     | Half a day, some investigation needed |
| 8     | A full day, multiple files/subsystems |
| 13    | Multi-day, cross-cutting changes |
| 20    | A week+, should probably decompose |

When presenting the estimate, cite the reasoning: "I estimate cost 5
— similar to 🎯T3 (actual cost 5), touches 4 files but requires a
new abstraction." The user can override.

### Calibration

When retiring a target (`/target retire`), record `Actual-cost:` next
to the original `Estimated-cost:`. Over time, this builds a
calibration history that improves future estimates. The agent should
reference completed targets with actuals when estimating new ones.

### Weight computation

```
weight = value / cost    (rounded to nearest integer, minimum 1)
```

- **Leaf targets**: weight = (human-scored value) / (agent-estimated cost)
- **Interior targets**: value = sum of child target values; cost = sum of
  child target costs. Compute the weight from these.
- **Weight < 1**: cost exceeds value — flag for retirement or reframing.
- **Collisions are fine** — equal weight means ordering doesn't matter.

**Always write the computed integer.** Never write "derived", "TBD", or
any placeholder — the Weight field must always contain a number with
the `(value V / cost C)` breakdown. For interior targets, compute from
the children and write the result.

### The `Gates:` field

Targets can declare gating relationships independently of the
parent/child hierarchy:

```markdown
- **Gates**: 🎯T4, 🎯T7
```

This means achieving this target is a prerequisite for 🎯T4 and 🎯T7.
The value of this target includes the values of 🎯T4 and 🎯T7 (and
transitively, anything they gate). `Parent:` implies a gates
relationship (parent gates children), but `Gates:` allows
cross-cutting dependencies outside the parent tree.

## Standard target format

```markdown
### 🎯T<N> <Desired state as short assertion>
- **Weight**: <integer> (value <v> / cost <c>)
- **Estimated-cost**: <fibonacci score>
- **Acceptance**: <How to verify convergence — concrete, testable>
- **Context**: <Why it matters, how discovered, what prompted it>
- **Parent**: 🎯T<N> (optional)
- **Gates**: 🎯T<N>, 🎯T<M> (optional — targets this one enables)
- **Origin**: <manual / forked-from: 🎯T<N>> (optional)
- **Status**: identified / converging / achieved
- **Discovered**: YYYY-MM-DD
```

## Standard file structure

```markdown
# Targets

<!-- last-evaluated: abc1234 -->

## Active

### 🎯T1 All tests pass on Windows
...

## Achieved

### 🎯T2 Logging uses spdlog macros everywhere
...
```

The `last-evaluated` comment records the git SHA at which `/cv`
last ran a full evaluation. The gather script uses this to compute
changed files since the last evaluation, enabling change-hint-guided
focus.

## Archival

When the `## Achieved` section grows beyond ~10 entries, move older
entries (achieved 30+ days ago) to `## Archive` at the bottom of the
file, or to a separate `docs/targets-archive.md`. The gather script
only emits `## Active` and `## Achieved` — archived targets don't
consume context on routine evaluation but remain accessible for
reference.

## Guidance

- A target is a desired **state**, not a task. Write it as an
  assertion: "All tests pass on Windows" not "Fix Windows tests."
- Acceptance criteria should be verifiable — ideally by reading code,
  running a command, or checking CI output.
- Where possible, write acceptance criteria that are grep-checkable
  ("no printf/fprintf in non-vendor code") or ci-checkable ("CI green
  on windows-latest"). This makes automated gap evaluation cheap.
  Criteria requiring architectural review are valid but are only
  deeply evaluated in `/cv full` mode or when the target is
  the active recommendation.
- Three tracking systems, one flow: **TODOs** are the inbox (low-
  friction capture), **targets** are the backlog (desired states the
  agent converges toward), **GitHub issues** are the public interface
  (collaborative, tied to CI/PRs). Items flow upward — TODOs get
  triaged into targets or issues, and the TODO file drains toward
  empty. When summarising or adding targets, check `docs/TODO.md`
  and open GitHub issues for items that are better expressed as
  desired states. Suggest promoting them and removing the original.
  Targets and issues aren't 1:1: a target might spawn multiple
  issues, and closing an issue might partially satisfy a target's
  acceptance criteria.
- When decomposing a target into sub-targets, prefer splits that
  create **independent** sub-targets over ones that create sequential
  dependencies. Independent sub-targets can be worked in parallel
  (by agent teams or concurrent sessions). There's no single right
  axis — folder structure, discipline, functional area, platform are
  all valid — but the question "can these be worked simultaneously?"
  is worth asking when choosing how to split.
