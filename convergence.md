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

This means delivery is not a final step bolted onto completed code —
it's intrinsic to the target. "Merged to master" is a waypoint, not a
destination. The destination is the user experiencing the change.
Targets are not achieved until their impact is delivered.

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
- **Interior targets** (gate other targets): value = sum of values of
  all targets they directly gate. Computed automatically. No human
  input needed.

This means a foundational target that enables three value-8 outcomes
has value 24 — automatically. Adding a new dependency increases the
enabler's value without re-scoring. Removing a dependency decreases it.

"CI is green" is not a user-facing outcome. "A smooth 60 FPS working
game" is. CI derives its value from the outcomes it gates.

### Cost is agent-estimated

The agent estimates cost by reading the codebase: files to change,
complexity, comparison to completed targets with recorded actuals.
Cost uses the same Fibonacci scale but measures effort.

When a target is retired, actual cost is recorded alongside the
estimate. This calibrates future estimates.

### Weight

weight = value / cost (integer, minimum 1). The ranking is WSJF
(Weighted Shortest Job First): highest weight = highest-leverage work.

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
