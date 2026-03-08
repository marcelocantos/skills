---
name: cv
description: Evaluate convergence gaps on active targets and recommend next work.
user-invocable: true
---

Evaluate all active targets against the current project state and
recommend what to work on next. This replaces manually cross-referencing
TODOs, git status, and memory to answer "what should I do next?"

## `/cv go` — Execute last suggested action

If the argument is `go`, skip evaluation entirely. Read the most recent
`/cv` output from this conversation (it will be earlier in the
transcript) and execute the suggested action from that output. If there
is no prior `/cv` output in the conversation, report the error
and run a normal default-tier evaluation instead.

## Evaluation tiers

`/cv` operates in three tiers. Choose the tier that matches the
decision value of the moment.

| Tier       | When to use                          | Cost        |
|------------|--------------------------------------|-------------|
| **scan**   | Mid-work check, minor checkpoint     | ~3 tool calls |
| **default**| Session start, run boundary, blockage| ~10-15 tool calls |
| **full**   | Milestone boundary, periodic audit   | Unbounded   |

- **`/cv`** (no args) → default tier.
- **`/cv scan`** → scan tier.
- **`/cv full`** → full tier.

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

## Step 0 — Load prior context

### 0a. Prior report

Check for `docs/convergence-report.md` (or the path used by the
project). If it exists, read it. Parse:

- The visible report (gap assessments, recommendation, timestamp).
- The machine-readable appendix (inside `<!-- convergence-deps ... -->`):
  per-target gap, assessment text, and list of files read.

This is the **prior state**. It informs which targets can be carried
forward and which need re-evaluation.

### 0b. Saved context

The `saved-context` section from gather output (Step 1) lists files
in the project's auto-memory directory with their first few lines.
Check it for target-relevant context:

- **`wrap-draft.md`** — left by `/wrap` Step 0 if a previous wrap was
  interrupted (usually by context exhaustion). **If this file exists,
  read it immediately** — it contains the last session's work summary,
  target progress, in-flight work, and key decisions that didn't make
  it into targets or MEMORY.md. Surface it prominently at the top of
  the report under a "Recovered from interrupted wrap" heading. After
  incorporating its content into the evaluation, delete the file.
- **`stash-context.md`** — left by `/stash` before a `/clear`. Contains
  a session snapshot with progress, decisions, and next steps. If the
  headings suggest target-relevant content, read the full file. Don't
  remove it — `/pop` owns its lifecycle.
- **Other `*.md` files** — topic-specific notes. Only read further if
  headings overlap with active targets.
- **`MEMORY.md`** — already loaded into conversation context by the
  system. No explicit read needed, but be aware it may contain
  target-relevant notes.

This is best-effort — skim what gather provides, deep-read only if
something looks relevant. If nothing overlaps, move on.

## Step 1 — Gather

Execute `~/.claude/skills/target/gather.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`, just invoke the path as the
command). Parse the output sections: `targets-file`, `delivery`,
`git-state`, `changed-files`.

If no targets file exists, report this and suggest running `/target` to
create one. Stop here.

### Staleness triage

If a prior report exists, cross-reference `changed-files` against
each target's recorded file list from the appendix:

- **No overlap**: target is **fresh** — carry forward the prior gap
  assessment without re-investigation.
- **Overlap**: target is **stale** — must be re-evaluated this run.
- **No prior entry** (new target): treat as stale.

For **scan tier**, all targets use prior assessments; only flag stale
ones as "potentially affected." For **default tier**, re-evaluate
stale targets among the top 2-3 by weight; carry forward the rest.
For **full tier**, ignore the prior report and re-evaluate everything.

## Step 1.5 — Rank targets

Run `python3 ~/.claude/skills/cv/rank.py <targets-path>` (where
`<targets-path>` is the path from Step 1's `targets-file` output). Parse
its output. Use the ranking to:

- Flag blocked targets in the gap report.
- Use effective weight (not declared weight) when sorting and
  recommending targets.
- Never recommend a blocked target — recommend the highest effective
  weight unblocked target instead.

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

Recommend which target to work on next. Use the ranking from
`rank.py` — recommend the first unblocked target (highest effective
weight). Never recommend a blocked target.

Among equal effective weights, prefer the target with the smaller
gap — closing it is cheaper. Effective weight < 1 means cost exceeds
value — flag it for retirement or reframing, don't recommend working
on it.

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

### Movement since last report

If a prior report exists, show what changed since last evaluation
before the gap report:

```
## Movement

- 🎯T1: significant → close (tests added)
- 🎯T3: not started → significant (initial implementation merged)
- 🎯T5: (unchanged)
```

Targets that didn't move get a single "(unchanged)" line — don't
repeat their full assessment. This lets the user focus on what's new.

### Persist the report

**Write the file before presenting the report.** Then present the
full report as conversational output — the file persistence and the
conversational display serve different purposes.

The file has two parts:

1. **The visible report** — standing invariants, movement, gap report,
   recommendation, suggested action.

2. **The machine-readable appendix** — an HTML comment at the end:

```markdown
<!-- convergence-deps
evaluated: 2026-03-04T14:30:00Z
sha: abc1234

🎯T1:
  gap: significant
  assessment: "Core rendering rework not started, orientation events close."
  read:
    - src/game/carousel.cpp
    - src/game/carousel.h
    - src/platform/orientation.cpp

🎯T2:
  gap: close
  assessment: "CI workflow exists, one flaky test remaining."
  read:
    - .github/workflows/ci.yml
    - tests/test_auth.py
-->
```

The `read:` list records every file the agent actually opened (via
Read, Grep match, or Glob result) while evaluating that target. This
is best-effort — it won't capture absence-based judgments or broad
directory scans, but it gives the next run a starting point for
staleness triage. When the changed-files from gather overlap with a
target's read list, that's a strong signal to re-evaluate. When they
don't overlap, it's a reasonable (not guaranteed) signal to carry
forward.

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

`/cv go` inherits this: if the suggested action is "run `/push`",
then `go` invokes `/push`, which checks the project's gates (including
manual gates that require user approval).

## Step 7 — Auto-execute

**Step 7 is not optional.** After presenting the report, check the
conditions below. If they hold, execute immediately — do not ask the
user. If any condition fails, state **which one** and **why** so the
user can see exactly what blocked auto-execution.

### Conditions (all must hold)

1. **Unblocked candidate(s) exist** — at least one unblocked target
   with a suggested action.
2. **No standing invariant violations** — tests pass and CI is green.
   If CI state is unknown (not checked, no CI configured), treat it
   as passing — do not block on uncertainty.
3. **No action crosses a delivery boundary** — if a suggested action
   is "run `/push`", "run `/release`", or "run `/republish-skills`",
   that specific action is not auto-executed (present it and let the
   user initiate). Other non-delivery actions in the same run are
   still eligible.
4. **Not scan tier** — scan is intentionally lightweight; don't attach
   execution to it.

### Single target

When there is one top-ranked unblocked target (or a tie broken by
smaller gap), say:

```
Clear next step — executing now.
```

Then proceed with the suggested action as if the user had typed `go`.

### Parallel execution

When there are **2+ unblocked targets** at the top of the ranking
(same effective weight, or close enough that both are clearly worth
doing), and they don't depend on each other:

1. **Check context budget** — if context compression has already
   occurred or the conversation is long, don't fan out. Pick the
   top one and execute solo.
2. **Fan out team agents** with `isolation: "worktree"` — one agent
   per target, using the model guidance from the Teams directive in
   CLAUDE.md (opus for complex work, sonnet for well-scoped coding).
3. Say:

```
N independent targets ready — fanning out.
- 🎯T1 "Name" → agent 1 (worktree)
- 🎯T3 "Name" → agent 2 (worktree)
```

If any target's action crosses a delivery boundary, exclude it from
the fan-out and present it separately.

### When blocked

If any condition fails, present the suggestion without executing and
state the blocker:

```
Auto-execute blocked: [condition N — reason].
Type **go** to execute manually.
```
