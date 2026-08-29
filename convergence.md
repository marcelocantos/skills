# Convergence Model

Reference for the target decomposition and convergence workflow.
The key principles are in `~/.claude/CLAUDE.md` under
**Convergence targets**; this file covers the deeper mechanics.

## Core idea

Nothing matters unless it reaches the customer. Every target tree has
an implied root: **happy customer**. The visible targets in a project
are subtrees of that root — a target that can't trace its ancestry
back to user impact is orphaned and shouldn't exist.

A **target** is a desired state — an assertion about the project that
should become true. Work converges toward targets by closing the gap
between current state and desired state. The convergence model replaces
task-list thinking ("do X, then Y, then Z") with state-gap thinking
("the project should satisfy P; what's the shortest path from here?").

A target is achieved when the code that makes the assertion true has
landed — the same commit or PR as the fix. Do not hold it open for a
tag, a Homebrew formula, or an installed-binary check. Do not file a
sibling whose only remaining work is `/release`. Shipping existing
fixes is `/cv`'s unreleased-fixes path, not target bookkeeping.

If the symptom is still there after ship, that is a new report: reopen
or file a new target. Don't keep a shadow target around "just in case
we forget to cut the release" — we almost never re-evaluate those, and
they get shoved into the next push anyway.

Don't split implementation and retirement across separate PRs. The
merge that lands the code is the lifecycle event.

## Decomposition

Most meaningful targets are composites. A target like "the carousel
supports landscape on iPad" is too broad to converge on directly — it
bundles orientation detection, layout adaptation, input remapping, text
rendering, device detection, and more. Each of those is a sub-target
with its own gap.

### When to decompose

Decompose when a target has **multiple independent gaps** — areas where
progress on one doesn't automatically close the others. Signs:

- The target's acceptance criteria span different subsystems or files.
- You can imagine one criterion being met while others remain open.
- Different criteria require different expertise or investigation.

### When NOT to decompose

Don't decompose when:

- The target is small enough to converge on in a single focused stretch.
- The sub-targets would be trivial (decomposition adds overhead without
  clarity).
- The work is naturally serial — each step depends on the previous one,
  so decomposition doesn't enable parallel progress or independent
  assessment.

### How to decompose

1. **Read the target's desired state and acceptance criteria.**
2. **Identify the independent dimensions** — what are the distinct
   things that need to become true?
3. **Write each as a sub-target** — a desired state, not a task.
   Sub-targets go in the same `docs/targets.md` file with a `Parent:`
   field linking to the composite.
4. **Assess each sub-target's gap independently.** Some may already be
   close (e.g., "orientation events reach the server" might already be
   true if the wire protocol forwards them).
5. **Work leaf-first.** Pick the sub-target with the most actionable
   gap and converge on it. Don't plan the whole tree — the tree evolves
   as understanding grows.

### Depth

Decomposition is recursive — a sub-target can itself be composite. But
don't decompose speculatively. Go one level deep, assess, work. If a
sub-target turns out to be composite when you start working on it,
decompose then. The hierarchy emerges from engagement with the problem,
not from upfront analysis.

### Sub-targets are not PRs

Decomposition structures *assessment and sequencing*, not delivery
boundaries. A composite target and its sub-targets normally ship as
**one PR**, with each sub-target landing as a commit (or a few) on a
single branch. Do **not** map 🎯T1.1, T1.2, … to separate PRs — that
turns one feature into a sequence of human-review stalls, which is
exactly the velocity tax the "One PR per objective" HARD RULE in
`~/.claude/CLAUDE.md` forbids. Naturally-serial phases are the *classic
trap*: serial sub-targets share a branch and a PR; they don't each earn
one. Split a composite across multiple PRs only when its sub-targets are
genuinely independent *and* separately useful, or when the user says so.
The `converging` state exists for the rare target that legitimately
spans PRs — not as license to chunk one feature into many.

## Graph shapes

Decomposition is not just "split this node into N smaller nodes" —
the **shape** of the resulting subgraph matters. A target that reads
in prose as "do X, then Y, then check Z" is almost certainly hiding
a subgraph the YAML doesn't yet make explicit. Bullseye's repo
ships a named vocabulary of recurring shapes at `docs/shapes.md`:

- **diamond** — design once, two (or more) parallel branches, one
  convergence node.
- **fan-out** — one prerequisite, many independent children, no
  shared tail.
- **chain** — sequential dependency; each intermediate is itself a
  meaningful state.
- **choke-point** — many parents converge through one node, many
  children fan out below.
- **spike-then-decide** — a research target gates a fan-out of
  mutually exclusive implementation options; unchosen options retire
  with a "rejected after spike" reason.
- **contract-first** — define an interface up front; parallel
  implementations fan out against it; an integration node converges
  them.
- **migration** — prepare, cut over, keep old running, verify,
  remove old. The "keep old running" node is the one most often
  omitted.

### Agent discipline

Before committing to a single-node target whose acceptance reads as
multi-phase prose, run the catalogue against it. Ask:

1. Is there a fork inside the prose — two independent things that
   could run in parallel after one prior step? → diamond.
2. Is there one prerequisite enabling many independents with no
   shared tail? → fan-out.
3. Is there one node that everything has to roll up through? →
   choke-point.
4. Is one of the steps a "decide" that picks among options? →
   spike-then-decide.
5. Is there an interface multiple things will hang off? →
   contract-first.
6. Is there an old system that must stay alive during the switch? →
   migration.
7. Is it actually sequential, and do the intermediates have
   independent meaning? → chain.
8. Are the steps a single coherent piece of work whose
   intermediates aren't separately addressable? → leave it as one
   node.

The mistake to avoid is filing a single node whose acceptance
encodes a subgraph in prose. The graph is the artifact — if the
shape matters, draw it in the graph. Propose the decomposition (and
the corresponding `bullseye_subdivide` / `bullseye_put` call shape)
before doing the work, not after.

The discipline complements but does not replace the "When NOT to
decompose" rules above: do not invent a shape just to have one.
Shapes earn their place when each named role corresponds to a piece
of work that is itself addressable, deserves its own acceptance
criteria, or runs in parallel with a sibling.

## Acceptance criteria: split by verification class

Never bundle machine-checkable criteria with human-perceptual ones in a
single target. A target whose acceptance mixes oracle-gated clauses
(tests, CI, harness checks) with glance-gated clauses (visual sign-off,
feel, on-device confirmation) inherits the human-attention cost of its
most-perceptual clause: it cannot self-close, stop-hooks stall on the
unperformed manual steps, and the decidable majority of the work waits
on the perceptual tail.

Authoring rule: split every acceptance list into (a) **oracle-gated**
clauses an agent can verify and retire autonomously, and (b)
**glance-gated** clauses requiring human perception — as separate
sub-targets when both are substantial, with the glance-gated node
downstream of the oracle-gated one. Classify clauses using the
verification classes in the `oracle-first` skill; anything
class-1-convertible (reference-comparable, dynamical) should be
converted to a machine check before being filed as a human step.

## Convergence assessment

At decision boundaries (session start, completing a sub-target,
hitting a blocker), assess the gap:

1. **Which sub-targets are achieved?** Mark them.
2. **Which are closest to achieved?** These are the highest-leverage
   next steps — closing near-done gaps first builds momentum and
   reduces the problem surface.
3. **Which are blocked?** Identify what's blocking and whether it's
   another sub-target, an external dependency, or a decision.
4. **Roll up.** A parent target converges when all its children do.
   Update the parent's status to reflect child progress
   ("converging 3/5 sub-targets achieved").

### Watch for non-convergence

Not every target converges. During assessment, watch for:

- **Stuck targets** — the gap isn't closing across sessions despite
  work. Check the status history; if repeated attempts haven't moved
  the needle, the target may be misframed or blocked by something
  outside agent scope.
- **Oscillation** — closing one gap reopens another, or fixes to one
  target regress a sibling. This often signals a missing constraint or
  a contradiction between targets. Surface the tension rather than
  continuing to alternate.
- **Unmeasurable acceptance** — criteria too vague to evaluate. If you
  can't tell whether the gap is closing, the target needs rewriting
  before more work is justified.

When you spot these, flag them in the target's status and raise with
the user rather than continuing to push.

## Value and cost

Weight = value / cost. Value and cost are estimated differently.

### Value flows backward from the customer

This is a direct consequence of the core idea: the implied root is
"happy customer," so all value originates from **user-facing outcomes**
— things a human experiences. Infrastructure, tooling, and architecture
have no direct value; they derive value solely from the outcomes they
enable.

- **Leaf targets** (don't gate anything): scored on a Fibonacci scale
  (1, 2, 3, 5, 8, 13, 20). The question: "how much does this outcome
  matter to the user?" The human has final say, but the agent should
  actively suggest values — drawing on its understanding of user
  psychology, UX patterns, and what tends to matter to real people.
  Challenge scores that seem off; a "nice-to-have" visual tweak and
  a fix for data loss shouldn't both be 5.
- **Interior targets** (gate other targets): value is the
  criticality-weighted sum of the values of all targets they directly
  gate. Computed automatically. No human input needed.

### Criticality

Each gating relationship carries a **criticality** — a number in
(0, 1] expressing how much the gated target's value depends on the
gate being achieved. This follows the GRL (ITU-T Z.151) contribution-
link model, with edge weights interpreted as Birnbaum importance
measures from reliability engineering.

- **Criticality 1.0** (default): the gate is essential. Without it the
  gated target's value drops to zero. This is the implicit criticality
  for `Parent:` relationships and for any `Gates:` entry that omits a
  percentage.
- **Criticality 0.8**: 80% of the gated target's value depends on this
  gate. Without the gate, the gated target retains only 20% of its
  value.
- **General formula**: if gate G has criticality *c* on gated target X,
  then G derives `c × value(X)` from this relationship.

The value of an interior target is therefore:

> value(gate) = Σ criticality_i × value(gated_i)

This recurses: `value(gated_i)` is itself a criticality-weighted sum
if that target gates further targets. Criticality compounds
multiplicatively through the graph — a gate two hops from a value-20
leaf with criticalities 0.8 and 0.5 on the path derives
0.8 × 0.5 × 20 = 8 from that leaf.

**Example.** "CI is green" gates "smooth 60 FPS game" (value 13,
criticality 1.0) and "contributors can onboard quickly" (value 5,
criticality 0.6). CI's derived value = 1.0 × 13 + 0.6 × 5 = 16.
Without CI, the game can't ship (full value loss) but contributors
can still read the code and run things manually (partial value loss).

**When to use non-default criticality.** Most gates are hard
prerequisites — criticality 1.0. Use a lower criticality when:

- The gated target is **degraded but not destroyed** without the gate
  (e.g., a feature works but with worse UX).
- The gate provides **one of several paths** to the gated outcome
  (e.g., two alternative deployment strategies).
- The gate is an **optimisation** that improves the gated outcome
  without being structurally necessary.

If an interior target also has direct user-facing value (rare), split
the user-facing part into its own leaf target.

### Cost is agent-estimated

The agent estimates cost by reading the codebase: files to change,
complexity, comparison to completed targets with recorded actuals.
Cost uses the same Fibonacci scale but measures effort.

When a target is retired, actual cost is recorded alongside the
estimate. This calibrates future estimates.

### Weight

weight = value / cost (integer, minimum 1). The ranking is WSJF
(Weighted Shortest Job First): highest weight = highest-leverage work.

### Scope: portfolio vs repo

WSJF, value, and cost are **portfolio-scope** signals. They answer
"across all my repos, which one deserves attention next?" At **repo
scope** — once you've picked a repo and are evaluating its frontier —
the ordering function is different:

1. Ascending distance to the nearest observable checkpoint (reach
   something a human can look at as fast as possible).
2. Descending unblocking fanout (finishing high-fanout targets
   frees more downstream work).
3. Ascending target ID (determinism).

Do **not** frame repo-scope prioritisation in WSJF, story-points,
or SAFe terms. Those frames are much more available in training
data than "distance-to-observable + fanout" and tend to leak in by
default; resist that pull. bullseye's repo-scope tools
(`bullseye_frontier`, `bullseye_summary`, `bullseye_convergence`)
print a banner naming the ordering function and disavowing WSJF at
repo scope — if you see that banner, reason in terms of observable
distance and fanout, not value/cost ratios.

WSJF reappears at portfolio scope (`bullseye_portfolio`), where it
ranks which *repo* to work in next.

## Relationship to planning

Plans are hypotheses about how to close a gap. They serve targets.

- **Don't plan against a composite target.** Decompose first, then plan
  against a specific sub-target.
- **Don't enter plan mode until you know which sub-target you're
  closing.** Convergence assessment → decomposition (if needed) →
  sub-target selection → then plan.
- **Plans can be wrong.** If execution reveals the plan doesn't close
  the gap, update the plan — or update the target if the target was
  misframed. The target is the source of truth.

## Example

**Composite target:** "Carousel supports landscape orientation on iPad"

Decomposition:

- **🎯T1.1**: Orientation events from player reach the carousel code on
  the server. *(Gap: close — wire protocol already forwards
  SDL_EVENT_DISPLAY_ORIENTATION; carousel just doesn't listen yet.)*
- **🎯T1.2**: Carousel layout adapts to orientation — vertical strip on
  the side in landscape, horizontal at bottom in portrait. *(Gap:
  significant — core rendering and input rework.)*
- **🎯T1.3**: iPad vs iPhone distinguished so iPhones stay portrait-only.
  *(Gap: significant — no device type in protocol yet.)*
- **🎯T1.4**: Text renders correctly in vertical carousel mode. *(Gap:
  unknown — needs design decision on rotation vs horizontal.)*
- **🎯T1.5**: Globe viewport uses available space effectively when
  carousel is side-mounted. *(Gap: close — globe already renders 1:1
  centered square; may just work.)*

Convergence order: T1.1 first (closest to done, unblocks testing of
T1.2). Then T1.3 (needed to gate the behavior). Then T1.2 (the core
work). T1.4 and T1.5 can be resolved during or after T1.2.
