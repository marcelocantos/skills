---
name: converge
description: Evaluate convergence gaps on active targets and recommend next work.
user-invocable: true
---

Evaluate all active targets against the current project state and
recommend what to work on next. This replaces manually cross-referencing
TODOs, git status, and memory to answer "what should I do next?"

## `/converge go` — Execute last suggested action

If the argument is `go`, skip evaluation entirely. Read the most recent
`/converge` output from this conversation (it will be earlier in the
transcript) and execute the suggested action from that output. If there
is no prior `/converge` output in the conversation, report the error
and run a normal default-tier evaluation instead.

## Evaluation tiers

`/converge` operates in three tiers. Choose the tier that matches the
decision value of the moment.

| Tier       | When to use                          | Cost        |
|------------|--------------------------------------|-------------|
| **scan**   | Mid-work check, minor checkpoint     | ~3 tool calls |
| **default**| Session start, run boundary, blockage| ~10-15 tool calls |
| **full**   | Milestone boundary, periodic audit   | Unbounded   |

- **`/converge`** (no args) → default tier.
- **`/converge scan`** → scan tier.
- **`/converge full`** → full tier.

### Scan tier

Read targets.md, report status fields as-is. Check the `changed-files`
section from gather output — if changed files overlap with any target's
domain (inferred from acceptance criteria keywords or path hints), flag
those targets as "potentially affected." No codebase investigation.
This is fast and cheap.

### Default tier

Fully evaluate the **top 2-3 targets by priority** (the ones most
likely to be recommended). For remaining targets, use status fields plus
change-hint overlap to estimate gap. Produce the full report format.

### Full tier

Investigate every active target against the codebase. Run greps, check
CI, read code. Use this at milestone boundaries or when targets have
been accumulating without evaluation.

## Step 1 — Gather

Execute `~/.claude/skills/target/gather.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`, just invoke the path as the
command). Parse the output sections: `targets-file`, `delivery`,
`git-state`, `changed-files`.

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

**Skip to Step 4 for scan tier** — report status fields as-is with
change hints.

For default tier, select the top 2-3 targets by priority for deep
evaluation. For full tier, evaluate all.

For each target being evaluated (leaf targets first, then roll up to
parents):

### 3a. Direct evaluation

Read the acceptance criteria and classify the evaluation cost:

- **grep-checkable**: Criteria that reference absence/presence of
  patterns in code (e.g., "no printf in non-vendor code"). Run the
  grep directly.
- **ci-checkable**: Criteria that reference build/test/CI state. Use
  cached results from the `git-state` gather section. Don't make
  additional API calls.
- **review-required**: Criteria that require architectural judgement
  across multiple files (e.g., "all platform differences behind
  src/platform/ interfaces"). Only evaluate in full tier or when this
  specific target is the recommendation.

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

2. **Standing invariants**: Check once globally (not per-target), using
   cached data from the gather output:
   - Tests pass? (Check recent CI or offer to run tests.)
   - CI green? (Check via `gh` if available.)
   Report any invariant violations at the top of the gap report.

## Step 4 — Produce the report

### Standing invariants

If any invariant is violated, show it first:
```
Standing invariants:
- Tests: FAILING (3 failures in test_foo.py)
- CI: last run failed (PR #12)
```

If all pass, show briefly: "Standing invariants: all green."

### Gap report

Sort targets by weight (descending). Always use the 🎯T*N* prefix when
referring to targets — in headings, inline references, and conversation
with the user. For each:

```
### 🎯T1 <Target name>  [priority]
Gap: <achieved / close / significant / not started>
<1-2 sentence assessment of what's met and what's not>
```

For targets not deeply evaluated (default tier, lower-priority targets),
show status field with change-hint annotation:

```
### 🎯T3 <Target name>  [medium]  (status only)
Status: converging
Changed files overlap: src/logging/* — may be affected
```

For targets with sub-targets, show the rollup then indent children:

```
### 🎯T1 <Parent target>  [high]
Gap: converging (2/3 sub-targets achieved)

  [check] 🎯T1.1 <Child 1> — achieved
  [ ] 🎯T1.2 <Child 2> — significant: <brief note>
  [check] 🎯T1.3 <Child 3> — achieved
```

For targets with implied delivery gaps, append:
```
  Implied: not yet delivered (PR #12 open, CI pending)
```

### Recommendation

Recommend which target to work on next. The heuristic: **highest
weight with the most actionable gap**. Weight already encodes value/cost,
so the ranking is effectively WSJF (Weighted Shortest Job First). Among
equal weights, prefer the target with the smaller gap — closing it is
cheaper. A target that gates others gets effective weight promotion:
if target A blocks target B, A's effective weight is at least B's.
Weight < 1 means cost exceeds value — flag it for retirement or
reframing, don't recommend working on it.

```
## Recommendation

Work on: **🎯T<N> <target name>**
Reason: <why this is the highest-leverage next step>
```

### Suggested action

A concrete next step to close the recommended target's gap. Not a full
plan — just the first actionable thing to do.

```
## Suggested action

<Concrete instruction, e.g. "Run `grep -r printf src/` to identify
remaining printf calls, then replace with SPDLOG_* macros.">

Type **go** to execute the suggested action.
```

## Step 5 — Staleness check

If any target's recorded status doesn't match the gap assessment (e.g.,
status says "identified" but the gap assessment shows "close"), offer to
update it:

```
Stale targets detected:
- 🎯T1 "<target name>": status is "identified" but gap is "close" — update to "converging"?
```

If the user confirms, update the targets file. After updating, record
the current git SHA in the `last-evaluated` comment at the top of the
targets file.

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

## Gate enforcement

Suggested actions must never bypass delivery gates. When a suggested
action crosses a delivery boundary:

- **Merge** → suggest running `/push` (which enforces pre-merge gates).
- **Release** → suggest running `/release` (which enforces pre-release
  gates).
- **Skill publish** → suggest running `/republish-skills`.
- **Never** suggest raw `git push`, `git merge`, `gh pr merge`, or
  `gh release create` as a suggested action.

`/converge go` inherits this: if the suggested action is "run `/push`",
then `go` invokes `/push`, which checks the project's gates (including
manual gates that require user approval).
