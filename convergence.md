# Convergence Model

Reference for the target decomposition and convergence workflow.
The key principles are in `~/.claude/CLAUDE.md` under
**Convergence targets**; this file covers the deeper mechanics.

## Core idea

A **target** is a desired state — an assertion about the project that
should become true. Work converges toward targets by closing the gap
between current state and desired state. The convergence model replaces
task-list thinking ("do X, then Y, then Z") with state-gap thinking
("the project should satisfy P; what's the shortest path from here?").

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

- **🎯 T1.1**: Orientation events from player reach the carousel code on
  the server. *(Gap: close — wire protocol already forwards
  SDL_EVENT_DISPLAY_ORIENTATION; carousel just doesn't listen yet.)*
- **🎯 T1.2**: Carousel layout adapts to orientation — vertical strip on
  the side in landscape, horizontal at bottom in portrait. *(Gap:
  significant — core rendering and input rework.)*
- **🎯 T1.3**: iPad vs iPhone distinguished so iPhones stay portrait-only.
  *(Gap: significant — no device type in protocol yet.)*
- **🎯 T1.4**: Text renders correctly in vertical carousel mode. *(Gap:
  unknown — needs design decision on rotation vs horizontal.)*
- **🎯 T1.5**: Globe viewport uses available space effectively when
  carousel is side-mounted. *(Gap: close — globe already renders 1:1
  centered square; may just work.)*

Convergence order: T1.1 first (closest to done, unblocks testing of
T1.2). Then T1.3 (needed to gate the behavior). Then T1.2 (the core
work). T1.4 and T1.5 can be resolved during or after T1.2.
