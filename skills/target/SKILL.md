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

## Step 2 — Act

Behaviour depends on arguments provided after `/target`.

### If no targets file was found

- **`/target` (no args)**: Report that no targets file exists and offer
  to create `docs/targets.md`.
- **`/target <text>`**: Create `docs/targets.md` automatically and add
  the target.

### `/target` (no arguments) — Summarise

Present all active targets grouped by priority (critical → high →
medium → low). For each target show:

- Name (the `###` heading)
- Priority
- Status (identified / converging / achieved)
- One-line gap assessment — how far is the project from this state?
  Read relevant code, check for the conditions in the acceptance
  criteria, and make a brief judgement.

For targets with sub-targets (children that have a `Parent:` field
pointing to this target), show a rollup: "converging (2/3 sub-targets
achieved)" and list children indented below.

End with a count: "N active targets (X critical, Y high, Z medium, W
low)."

### `/target <text>` — Add a new target

The text describes the desired state. From the description:

1. **Infer acceptance criteria** — how would you verify this state is
   achieved? Write concrete, testable criteria.
2. **Infer priority** — default to `medium` unless the description
   implies urgency.
3. **Set status** to `identified`.
4. **Set Discovered** to today's date.
5. **Draft the target entry** in the standard format (see below) and
   show it to the user for confirmation/refinement before writing.

If the user provides additional context (like `parent:`, `origin:`,
`priority:`), honour those.

After confirmation, append to the `## Active` section of the targets
file. If the file doesn't exist, create it with the standard structure.

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

## Standard target format

Target headings are prefixed with a 🎯 emoji for visual scanability:

```markdown
### 🎯 <Desired state as short assertion>
- **Priority**: critical / high / medium / low
- **Acceptance**: <How to verify convergence — concrete, testable>
- **Context**: <Why it matters, how discovered, what prompted it>
- **Parent**: <parent target name> (optional)
- **Origin**: <manual / forked-from: <target name>> (optional)
- **Status**: identified / converging / achieved
- **Discovered**: YYYY-MM-DD
```

## Standard file structure

```markdown
# Targets

<!-- last-evaluated: abc1234 -->

## Active

### 🎯 All tests pass on Windows
...

## Achieved

### 🎯 Logging uses spdlog macros everywhere
...
```

The `last-evaluated` comment records the git SHA at which `/converge`
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
  deeply evaluated in `/converge full` mode or when the target is
  the active recommendation.
- When a TODO item is better expressed as a desired state, suggest
  converting it to a target.
- When decomposing a target into sub-targets, prefer splits that
  create **independent** sub-targets over ones that create sequential
  dependencies. Independent sub-targets can be worked in parallel
  (by agent teams or concurrent sessions). There's no single right
  axis — folder structure, discipline, functional area, platform are
  all valid — but the question "can these be worked simultaneously?"
  is worth asking when choosing how to split.
