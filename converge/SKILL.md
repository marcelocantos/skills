---
name: converge
description: Evaluate convergence gaps on active targets and recommend next work.
user-invocable: true
---

Evaluate all active targets against the current project state and
recommend what to work on next. This replaces manually cross-referencing
TODOs, git status, and memory to answer "what should I do next?"

## Step 1 — Gather

Execute `~/.claude/skills/target/gather.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`, just invoke the path as the
command). Parse the output sections: `targets-file`, `delivery`,
`git-state`.

If no targets file exists, report this and suggest running `/target` to
create one. Stop here.

## Step 2 — Parse targets

From the targets file content, extract all active targets (under
`## Active`). For each target, parse:

- Name (the `###` heading)
- Priority
- Acceptance criteria
- Status
- Parent (if any)
- Sub-targets (other targets whose Parent field matches this name)

Build a tree: top-level targets with their children.

## Step 3 — Evaluate gaps

For each active target (leaf targets first, then roll up to parents):

### 3a. Direct evaluation

Read the acceptance criteria and investigate the codebase to assess
the gap. This means:

- **Grep/glob for conditions** described in acceptance criteria (e.g.,
  if criteria says "no printf in non-vendor code", search for printf).
- **Check build/test state** if criteria reference them (e.g., "CI
  green" — check recent CI runs via `gh`).
- **Read relevant code** to assess structural criteria (e.g., "all
  platform differences behind src/platform/ interfaces").

Classify each target's gap as one of:

- **achieved** — all acceptance criteria met.
- **close** — most criteria met, minor remaining work.
- **significant** — substantial work remaining, but path is clear.
- **not started** — no meaningful progress toward the desired state.

### 3b. Sub-target rollup

For targets with children, derive the parent's gap from its children:
- Count achieved vs total children.
- Parent is never "achieved" while any child is outstanding.
- Report: "converging (N/M sub-targets achieved)".

### 3c. Implied target evaluation

After evaluating explicit targets, check implied gaps for any target
whose status is "converging" or "achieved" (or gap assessment suggests
code work has happened):

1. **Delivery**: Read the `delivery` section from gather output. Check
   git state — is there an open PR? Is it merged? Is CI green? If code
   is done but delivery isn't met, flag it:
   "Code achieved but not yet delivered (PR #N open, CI pending)."

2. **Standing invariants**: Check once globally (not per-target):
   - Tests pass? (Check recent CI or offer to run tests.)
   - CI green? (Check via `gh` if available.)
   Report any invariant violations at the top of the gap report.

## Step 4 — Produce the report

### Standing invariants

If any invariant is violated, show it first:
```
⚠️ Standing invariants:
- Tests: FAILING (3 failures in test_foo.py)
- CI: last run failed (PR #12)
```

If all pass, show briefly: "Standing invariants: all green."

### Gap report

Group targets by priority (critical → high → medium → low). For each:

```
### <Target name>  [priority]
Gap: <achieved / close / significant / not started>
<1-2 sentence assessment of what's met and what's not>
```

For targets with sub-targets, show the rollup then indent children:

```
### <Parent target>  [high]
Gap: converging (2/3 sub-targets achieved)

  ✅ <Child 1> — achieved
  ⬜ <Child 2> — significant: <brief note>
  ✅ <Child 3> — achieved
```

For targets with implied delivery gaps, append:
```
  ⚠️ Implied: not yet delivered (PR #12 open, CI pending)
```

### Recommendation

Based on priority and gap size, recommend which target to work on next.
The heuristic: **highest priority with the most actionable gap**. A
"close" gap on a high-priority target beats a "significant" gap on a
medium-priority target. A "not started" target with clear acceptance
criteria beats a vague one.

```
## Recommendation

Work on: **<target name>**
Reason: <why this is the highest-leverage next step>
```

### Suggested action

A concrete next step to close the recommended target's gap. Not a full
plan — just the first actionable thing to do.

```
## Suggested action

<Concrete instruction, e.g. "Run `grep -r printf src/` to identify
remaining printf calls, then replace with SPDLOG_* macros.">
```

## Step 5 — Staleness check

If any target's recorded status doesn't match the gap assessment (e.g.,
status says "identified" but the gap assessment shows "close"), offer to
update it:

```
📋 Stale targets detected:
- "<target name>": status is "identified" but gap is "close" — update to "converging"?
```

If the user confirms, update the targets file.

## Step 6 — Standing invariant violations take priority

If standing invariants are violated (tests failing, CI red), the
recommendation should prioritise fixing those over any explicit target
work — broken invariants block all convergence.

## Interaction with plans

If there's an active GSD plan (`.planning/` exists), note it:
- If the plan aligns with the recommended target, say so.
- If the plan targets different work than what convergence suggests,
  flag the divergence: "Active plan targets X, but convergence suggests
  Y is higher leverage. Consider re-evaluating."

Plans are hypotheses; targets are the source of truth. If they diverge,
trust the convergence assessment.
