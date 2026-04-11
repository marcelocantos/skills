# /cv Worker — Convergence Evaluation

Evaluate all active targets via bullseye and recommend what to work on
next. Bullseye is the sole target system — `docs/targets.yaml` is the
source of truth.

## Evaluation tiers

| Tier       | When to use                          | Cost        |
|------------|--------------------------------------|-------------|
| **scan**   | Mid-work check, minor checkpoint     | ~3 tool calls |
| **default**| Session start, run boundary, blockage| ~10-15 tool calls |
| **full**   | Milestone boundary, periodic audit   | Unbounded   |

- **`/cv`** (no args) → default tier.
- **`/cv scan`** → scan tier.
- **`/cv full`** → full tier.

## Progress reporting

Before starting each step, emit a progress heading **on its own line
followed by a blank line**, then proceed to tool calls. Use `##` for
major steps and `###` for sub-steps. These headings are picked up by
the Agent framework as progress notifications.

## Step 0 — Standing invariants

Check once globally using available data:
- Tests pass? (Run `cargo test`, `make test`, or equivalent if quick.)
- CI green? (Check via `gh` if available.)
- Clean working tree?

If any invariant is violated, the recommendation must prioritise
fixing those over any explicit target work.

## Step 0.5 — Unreleased bug fixes check

Bug fixes that exist on master but haven't shipped are a **high-priority
signal**. Users running the installed version are still hitting the bug;
shipping the fix is almost always higher leverage than starting new work.

Check for unreleased fixes. **Use local git only — do not call `gh`.**
The local repo is the source of truth for tags and commits; `gh` round-
trips to GitHub and adds seconds of latency per /cv run for no benefit.
If you suspect the local tags are stale, note it but still proceed with
what git knows.

1. Get the latest release tag: `git describe --tags --abbrev=0`.
   If the command fails (no tags exist), skip this step — the project
   has no releases yet.
2. List commits since that tag: `git log --oneline <tag>..HEAD`.
3. If no commits, skip this step — everything is released.
4. Scan the commit subjects for bug-fix markers: `fix:`, `fix(`, `bugfix`,
   `hotfix`, `revert`, "fix ", "fixes #", "correct", or similar. Also
   check for commits that touch code but not just docs/tests/CI.
5. If any bug-fix commits are found, **mark "unreleased fixes" as a
   candidate recommendation** with high priority. Carry this into
   Step 3 — it may outrank frontier target work.

Exceptions — **don't** prioritise a release when:
- The only unreleased commits are docs, comments, CI tweaks, or
  refactors with no user-visible effect.
- A release is already in flight (open release PR, pending tag, CI run
  of `release.yml` in progress).
- Frontier work is mid-flight and the next commit will be another fix —
  batching fixes into one release is usually better than releasing each
  one individually. Use judgement: if recent sessions have been actively
  committing fixes (check mnemo in Step 1.5), wait; if the fix is
  several days old and nothing is in flight, ship it.
- The project has no release mechanism at all (no `release.yml`, no
  tags, no Homebrew tap). Note it but don't recommend a release.

If unreleased fixes are found and none of the exceptions apply, the
suggested action in Step 3 should be `/release` (routed via the release
gate — never suggest `gh release create` directly).

## Step 1 — Gather targets

Call `bullseye_summary(cwd)`. This single call returns active targets
grouped by parent (with rollup counts), frontier, blocked targets,
stale targets, and WSJF ranking — replacing multiple
`bullseye_list` + `bullseye_frontier` calls.

If `bullseye_summary` is not available, fall back to calling
`bullseye_frontier(cwd)` and `bullseye_list(cwd)` separately.

If bullseye errors (no targets.yaml), check if `docs/targets.md`
exists. If so, suggest running `bullseye_import` to migrate. If
neither file exists, suggest running `bullseye_init` or `/target`.
Stop here.

For **scan tier**: just report the frontier targets and their status
as-is. Skip deeper evaluation.

## Step 1.5 — Recent activity (mnemo)

Call `mnemo_recent_activity(repo=<current_repo>, days=7)` to understand
what has been worked on recently. Use this to:

- Populate the "Movement" narrative without expensive codebase reads —
  mnemo knows which targets were touched and what changed.
- Identify which targets were likely affected by recent work, so
  per-target evaluation can focus on verifying outcomes rather than
  re-deriving history.
- Skip deep evaluation for targets that mnemo shows had no recent
  activity (report their bullseye status as-is).

If mnemo is unavailable or returns nothing, fall through to Step 2
unchanged — the evaluation still works, just costs more tool calls.

Mnemo complements bullseye: **bullseye owns target state** (what the
desired state is and how close we are), **mnemo owns session history**
(what was actually done and when). Don't use mnemo to override bullseye
status — use it to inform the gap assessment.

## Step 2 — Evaluate gaps

### Default tier

Select the top 2-3 frontier targets for deep evaluation. For the rest,
report status from bullseye_list.

### Full tier

Evaluate every active target against the codebase.

### Per-target evaluation

For each target being evaluated:

1. Call `bullseye_get(cwd, id)` for full detail.
2. Read the acceptance criteria and classify:
   - **grep-checkable**: Run the grep directly.
   - **ci-checkable**: Use cached results from Step 0.
   - **review-required**: Only in full tier or for the recommended target.
3. Classify the gap: **achieved** / **close** / **significant** / **not started**.

### Visual verification check

If a target has `visual` in its tags, it cannot be "achieved" or
"close" unless visual verification is recorded. Flag it if missing.

## Step 3 — Produce the report

### Standing invariants

```
Standing invariants: all green.
```
Or list violations first.

### Gap report

List all active targets. For each frontier target, show full
assessment. For blocked targets, show what blocks them.

```
### 🎯T1 <Target name>  [frontier]
Gap: <achieved / close / significant / not started>
<1-2 sentence assessment>

### 🎯T3 <Target name>  [blocked by T1, T2]
Status: identified
```

### Recommendation

Pick the highest-leverage next action. Priority order:

1. **Standing invariant violations** (from Step 0) — fix first.
2. **Unreleased bug fixes** (from Step 0.5) — ship them via `/release`
   unless an exception applies. Explain briefly why releasing beats
   new target work in the current state.
3. **Frontier targets** — highest-leverage unblocked target. Since
   frontier targets can be worked in parallel, the judgement is:
   what's most actionable, what unblocks the most downstream work,
   what has the smallest gap.

```
## Recommendation

Work on: **🎯T<N> <target name>**
Reason: <why this is the highest-leverage next step>
```

### Suggested action

A concrete next step — not a full plan, just the first actionable thing.

```
## Suggested action

<Concrete instruction>
```

## Step 4 — Update last_evaluated

If any target's status changed based on the evaluation, call
`bullseye_assert(cwd, id, status)` to update it. Then record the
current git SHA in the targets file's `last_evaluated` field.

## Gate enforcement

Suggested actions must never bypass delivery gates:
- **Merge** → suggest `/push`
- **Release** → suggest `/release`
- **Skill publish** → suggest `/republish-skills`
- Never suggest raw `git push`, `git merge`, or `gh release create`.

## Interaction with plans

If there's an active GSD plan, note alignment or divergence with the
recommended target. Plans are hypotheses; targets are the source of
truth.
