# Desired-State Convergence for Agent Workflows

**Date**: 2026-03-04
**Author**: Claude (research compilation)
**Status**: Design rationale & literature review

## Abstract

This report examines the theoretical and practical foundations of a
desired-state convergence system for AI agent workflows. The system
replaces task-oriented tracking ("what have I done?") with
state-oriented convergence ("where do I want to be, and how far am I?").
We survey the intellectual lineage of this idea across infrastructure
automation, control theory, requirements engineering, AI planning, and
adaptive methodologies — then show how these threads converge into a
coherent design for agent-assisted software development.

---

## 1. The Problem: Tasks Don't Capture Intent

Traditional project tracking records *actions completed*: TODO items
checked off, commits made, branches merged. This works for
well-understood, decomposable work. It fails in three important cases:

1. **Mid-work discovery.** An agent working on a Windows port notices
   that logging is inconsistent across modules. The insight has nothing
   to do with the current task. In a task-based system, it becomes a
   bare TODO ("fix logging") stripped of the context that made it
   visible. The *why* is lost.

2. **State assessment.** When the user asks "what should I do next?",
   the answer requires cross-referencing TODO files, git status, CI
   results, and memory. No single artifact captures the distance between
   where the project *is* and where it *should be*.

3. **Goal mutation.** Work toward "all tests pass on Windows" reveals
   that the threading model is fundamentally wrong. The real goal isn't
   "tests pass" — it's "threading architecture supports Windows." A task
   list can't express that the *objective itself* has changed; it can
   only add more tasks.

The desired-state convergence system addresses all three by making
*states* the primary tracking unit — not actions.

---

## 2. Intellectual Lineage

The idea of declaring a desired state and converging toward it has deep
roots across multiple disciplines. Understanding these roots clarifies
what the system is, what it isn't, and what design principles to follow.

### 2.1 Infrastructure Automation: The Convergent Operator

The most direct ancestor is Mark Burgess's work on convergent
configuration management.

**Burgess, "Computer Immunology" (USENIX LISA '98).** Burgess
introduced *convergent operators* — idempotent operations that drive a
system toward a desired state. The key insight: you don't script a
sequence of changes; you declare what the system *should look like*, and
an operator repeatedly compares actual state to desired state and
corrects deviations. The term "convergence" here carries both meanings:
approaching the desired end-state, and the idempotence of the correction
at that end-state (applying it again changes nothing).

Burgess later formalised this into **Promise Theory** (with Jan
Bergstra), where each component *promises* to maintain a certain state
rather than being commanded. This underpins CFEngine and influenced
every subsequent configuration management tool.

**Modern incarnations.** The same pattern appears in:

- **Puppet/Chef**: Declare resources and their desired properties;
  the agent converges the system.
- **Terraform**: Declare infrastructure state in HCL; `plan` computes
  the delta; `apply` converges.
- **Kubernetes**: Declare workload specifications; controllers
  continuously reconcile actual state to desired state.

Branislav Jenco ("Desired State Systems", NDC Oslo 2021) identifies the
pattern across UI engineering (React's virtual DOM diffing),
infrastructure (Terraform), and orchestration (Kubernetes), extracting
ten common properties including declarative interfaces, stateless
wrappers over stateful systems, and the distinction between open-loop
(React — assumes no external modification) and closed-loop (Terraform,
Kubernetes — continuously verify actual state) reconciliation.

### 2.2 Control Theory: The Reconciliation Loop

The desired-state pattern is a specific instance of negative feedback
control.

**Åström and Murray, "Feedback Systems" (Princeton, 2008/2021).** The
standard textbook formalises what infrastructure tools implement:

- **Setpoint** = desired state
- **Process variable** = actual state
- **Error signal** = setpoint − process variable
- **Controller** = the logic that translates error into corrective action
- **Negative feedback** = corrective action that reduces the error

A PID controller responds to the error proportionally (P), accumulates
past errors (I), and anticipates future errors from the rate of change
(D). The `/converge` skill is analogous: it measures the gap (P),
remembers which targets have been stuck (staleness detection ≈ I), and
the "suggested action" attempts to anticipate the most efficient
correction (a lightweight D).

**Hellerstein et al., "Feedback Control of Computing Systems" (Wiley,
2004)** pioneered applying classical control theory directly to software
systems — managing response times, throughput, and utilisation by
adjusting configuration parameters through feedback loops.

**Level-triggered vs edge-triggered reconciliation.** James Bowes
("Level Triggering and Reconciliation in Kubernetes", HackerNoon)
explains a critical design choice borrowed from electrical engineering:

- **Edge-triggered** systems respond to *transitions* (events). If an
  event is missed, state diverges silently.
- **Level-triggered** systems respond to *current state*. Each
  reconciliation pass computes the full delta, making the system
  self-healing.

This is why Kubernetes controllers intentionally ignore the triggering
event and recompute full state on each pass. The convergence system
follows the same principle: `/converge` doesn't ask "what changed since
last time?" — it evaluates the full gap between current and desired
state on every run.

### 2.3 The OODA Loop

John Boyd's Observe-Orient-Decide-Act loop (1970s) is often
oversimplified but contains a key insight: the entity that can cycle
through observe→orient→decide→act faster than its environment changes
gains decisive advantage. Boyd's original diagram is far more
sophisticated than the popular cartoon — it includes multiple feedback
and feedforward loops within the Orient phase, where mental models are
updated.

The convergence system maps cleanly:

| OODA    | Convergence system          |
|---------|------------------------------|
| Observe | Gather project state         |
| Orient  | Evaluate gaps against targets |
| Decide  | Recommend highest-leverage target |
| Act     | Suggest concrete next step   |

The critical insight from Boyd: *Orient is the most important phase*.
It's where you update your mental model of reality. `/converge` spends
most of its effort here — not just listing what's undone, but assessing
distance, rollup, implied gaps, and staleness.

### 2.4 Goal-Oriented Requirements Engineering

The requirements engineering community has long studied goal-based
approaches, providing formal frameworks for goal decomposition and
reasoning.

**Van Lamsweerde, "Goal-Oriented Requirements Engineering: A Guided
Tour" (RE'01).** The KAOS framework makes goals the central organising
concept:

- Goals decompose via **AND-refinement** (all subgoals required) and
  **OR-refinement** (alternatives).
- **Obstacle analysis** systematically identifies conditions that
  prevent goal satisfaction.
- Goals are assigned to **agents** (human or software) through
  responsibility assignment.
- The ontology is explicitly state-based: objects evolve through states,
  and operations define state transitions.

The convergence system's target hierarchy directly mirrors KAOS
AND-refinement: a parent target is achieved when all sub-targets are
achieved. The "acceptance criteria" field operationalises what KAOS
calls goal satisfaction conditions.

**Yu, "i* Framework" (1995+).** The i* (iStar) framework adds an
agent-oriented perspective: actors depend on each other for goals, tasks,
and resources. By depending on others, actors can achieve goals
impossible alone — but become *vulnerable* if dependees fail. This maps
to the relationship between targets and implied targets: a feature
target depends on CI, deployment, and review — all potential points of
vulnerability.

**Holler et al., "Hierarchical Planning: Relating Task and Goal
Decomposition with Task Sharing" (IJCAI 2016)** formally bridges task
decomposition (HTN-style) with goal decomposition (GORE-style),
demonstrating that the two paradigms are complementary, not competing.

### 2.5 AI Planning: From STRIPS to HTN

Classical AI planning provides the formal foundation for goal
decomposition and the relationship between goals and plans.

**Fikes and Nilsson, "STRIPS" (1971).** The foundational automated
planning system represents the world through logical states, actions
with preconditions and effects, and searches for operator sequences
transforming initial state to goal state. STRIPS established the
paradigm: *planning is finding a path from current state to goal state
through action space*.

**Sacerdoti, "Planning in a Hierarchy of Abstraction Spaces" (AI,
1974).** Introduced ABSTRIPS — the first system to use abstraction
hierarchies in planning. Each precondition gets a "criticality" value;
higher-abstraction plans ignore low-criticality details, creating
skeletal plans refined at lower levels. This "solve at high abstraction,
refine at lower levels" strategy is the direct ancestor of HTN planning
— and of the convergence system's target hierarchy, where high-level
targets decompose into concrete sub-targets.

**Hierarchical Task Network (HTN) planning** (Erol, Hendler, Nau; AAAI
1994) formalises hierarchical decomposition:

- **Primitive tasks**: directly executable actions
- **Compound tasks**: decomposed into subtasks via **methods**
- A solution is an executable sequence obtained by recursively
  decomposing compound tasks

HTN planning is strictly more expressive than STRIPS — it can encode
undecidable problems. The convergence system avoids this complexity by
keeping hierarchy lightweight (typically 2 levels) and leaving
decomposition to human judgement rather than automated planning.

### 2.6 The Moving-Target Problem

One of the most important design considerations: goals change during
execution.

**Ishida and Korf, "Moving-Target Search" (IEEE TPAMI, 1995).** The
foundational paper on search where the goal changes during execution.
Key result: if the target's average speed is slower than the searcher's,
the searcher is guaranteed to eventually reach the target in a connected
space. This provides a theoretical basis for optimism: as long as
goals don't shift faster than work progresses, convergence is achievable.

**Bouguerra et al., "Planning When Goals Change" (Springer, 2014)**
extends MTS to general AI planning with two strategies:

- **Open Check**: can the new goal still be reached from the current
  search state?
- **Plan Follow**: does executing the current plan still bring us closer
  to the new goal?

These map directly to the convergence system's design principles: when
a target changes, first check if the current plan still converges toward
it (Plan Follow), and if not, re-evaluate from scratch (Open Check).

**Rolling Horizon Planning** (Chand, Hsu, Sethi; Annals of Operations
Research, 1998) formalises the common practice of solving optimisation
problems over a finite horizon, implementing only near-term decisions,
then re-solving with updated information. The key trade-off:
replan too often and waste resources; replan too rarely and execute
stale plans. Agile iterations, with their fixed-length sprints, are a
practical instantiation of rolling horizon planning for software.

**Agile's response.** "Responding to change over following a plan" (Agile
Manifesto, 2001). Agile methodologies are explicitly designed for moving
targets: short iterations create miniature planning-convergence cycles
where each iteration is a learning opportunity. The convergence system
adopts the same philosophy: targets are durable but mutable, plans are
disposable hypotheses.

### 2.7 AI Coding Agents: Current State

Recent work on AI coding agents reveals a tension between task-based and
goal-based planning.

**Huang et al., "Understanding the Planning of LLM Agents: A Survey"
(arXiv, 2024).** First systematic survey of LLM agent planning.
Categorises approaches into task decomposition, plan selection, external
module use, and reflection/memory. Most production systems use
task-list planning.

**SWE-agent (Yang et al., NeurIPS 2024).** Operates in a ReAct-style
loop (Thought → Action → Observation) with custom interfaces. Achieved
state-of-the-art on SWE-bench. Planning is implicit — the agent
discovers what to do through interaction, not upfront decomposition.

**Agentless (Xia et al., FSE 2025).** Challenges the assumption that
complex agents are necessary. A simple three-phase pipeline
(localise → repair → validate) with no agent loop at all proves
surprisingly competitive. This suggests that for well-scoped tasks,
structured LLM calls outperform dynamic planning.

**OpenHands/CodeAct (ICLR 2025).** Open platform for AI developers with
explicit step-oriented planning: tasks decomposed into ordered action
loops producing and validating intermediate artifacts.

The literature reveals three paradigms:

| Paradigm            | How it works                                      | Strengths                                         |
|---------------------|---------------------------------------------------|---------------------------------------------------|
| Task-list           | Planner creates ordered steps; executors carry out | Predictable, auditable, easy to monitor            |
| Goal-state          | Agent receives goal, dynamically discovers subtasks | Flexible, handles surprises, adapts to change      |
| Agentless pipeline  | Fixed phases with LLM calls, no planning loop      | Simple, fast, competitive on well-scoped tasks     |

The convergence system is explicitly **goal-state** at the tracking
level (targets are goals, not tasks) while remaining **paradigm-agnostic**
at the execution level (any of the three paradigms can converge toward
a target).

### 2.8 Gap Analysis

The practice of measuring distance between current and desired states
is well-established.

**Standard gap analysis** (business strategy) follows four steps:

1. Define current state (baseline assessment)
2. Define desired state (benchmarks, goals, standards)
3. Identify and measure the gap
4. Create an action plan to close it

The convergence system implements exactly this loop, with `/converge`
performing steps 1-3 and the "suggested action" providing step 4.

**ISO/IEC 25010 (SQuaRE)** defines software quality characteristics
with quantifiable metrics and thresholds. Organisations conduct gap
analysis by measuring products against these targets. This is
structurally identical to convergence target evaluation — the target
defines what "good" looks like, acceptance criteria define the metrics,
and gap assessment measures the distance.

**McConnell's Cone of Uncertainty** (originally Boehm, 1980s)
demonstrates that estimates have ~4× uncertainty at project inception,
narrowing as decisions are made. The cone doesn't narrow itself — you
narrow it by making decisions that remove variability. Convergence
targets serve this purpose: each target constrains the solution space,
and achieving targets progressively narrows uncertainty about the
project's final state.

---

## 3. Design Principles

The literature survey reveals several principles that the convergence
system should embody.

### 3.1 Declare State, Not Actions

**Source**: Burgess (promise theory), Kubernetes (declarative API),
KAOS (goal models).

A target says "all diagnostic output uses spdlog macros" — not
"replace printf with spdlog." The state is the source of truth; the
action to reach it is a hypothesis that may need revision. This is the
fundamental departure from TODO-based tracking.

Why this matters for agents: an agent in a fresh session can read a
target and understand what needs to be true, without needing the
history of how work has progressed. Tasks require sequencing context;
states are self-contained.

### 3.2 Level-Triggered Evaluation

**Source**: Kubernetes controllers, control theory (negative feedback).

`/converge` computes the full gap on every run. It doesn't ask "what
changed?" — it re-evaluates from scratch. This makes it robust against
missed updates, stale status, and context loss across sessions. If a
target was achieved as a side-effect of other work, the next
`/converge` run catches it without anyone explicitly noting it.

### 3.3 Hierarchy Through Composition

**Source**: ABSTRIPS (abstraction hierarchies), HTN (task decomposition),
KAOS (AND-refinement).

High-level targets decompose into sub-targets. The parent's status is
derived from its children — it's never "achieved" while any child is
outstanding. This mirrors KAOS AND-refinement and HTN compound task
decomposition.

The system keeps hierarchy lightweight (typically 2 levels) to avoid
the complexity explosion that HTN planning theory warns about. If deeper
nesting emerges, it signals the parent target is too large and should be
split.

**Decomposition and parallelism.** There is no single correct axis for
splitting a target — folder structure, discipline, functional area,
platform are all valid. But the choice has operational consequences.
Sub-targets that are independent of each other can be worked in
parallel: by agent teams, concurrent sessions, or simply interleaved
work. Sub-targets with sequential dependencies force serialisation.

This doesn't mean independence is always the right choice. Sometimes
the natural decomposition creates dependencies (you can't test platform
abstraction until the abstraction exists). But when there's a genuine
choice between decomposition axes, preferring the one that maximises
independence is worth the thought — it directly determines how much
concurrency the plan can exploit.

### 3.4 Implied Invariants

**Source**: Standing invariants in control systems, KAOS obstacle
analysis.

Some states don't need explicit declaration — they're implied by the
project type. "Tests pass" and "CI green" are standing invariants, not
targets to declare each time. "Merged to default branch" is an implied
delivery target for any feature. Making these implicit avoids
boilerplate while ensuring nothing falls through the cracks.

This is analogous to KAOS obstacle analysis: implied targets represent
*conditions that could prevent goal satisfaction* even when the explicit
target's acceptance criteria are met.

### 3.5 Targets Are Durable But Mutable; Plans Are Disposable

**Source**: Moving-target search (Ishida/Korf), rolling horizon planning,
Agile manifesto.

The literature on moving targets is clear: goals change, and that's
legitimate. The system must accommodate this without treating goal
mutation as a failure. The hierarchy is:

    reality → targets → plans

Reality (current codebase state) is fixed. Targets are durable but
mutable statements of desired state. Plans are cheap, disposable
hypotheses about how to reach targets. When any layer contradicts the
one above, the lower layer yields.

This resolves the tension between planning and adaptation: plans are
useful *as tools for organising work toward targets*, but they carry no
authority independent of the target they serve. If a target changes, the
plan may be instantly obsolete — and that's fine.

### 3.6 Convergence at Natural Checkpoints

**Source**: Rolling horizon planning, OODA loop, Agile retrospectives.

Target status should be reconciled at workflow transitions: plan
completion, session end, branch merge, CI completion. These are moments
when the user is already pausing to think — the marginal cost of
checking target state is low. The system shouldn't require manual
bookkeeping; it should surface staleness and offer updates at natural
stopping points.

### 3.7 The Gap Heuristic: Priority × Actionability

**Source**: Gap analysis (business strategy), control theory (error
signal magnitude).

When multiple targets compete for attention, the recommendation
heuristic is: **highest priority with the most actionable gap**. A
"close" gap on a high-priority target beats a "significant" gap on a
medium-priority target — finishing something important is higher
leverage than starting something less important. A "not started" target
with clear acceptance criteria beats a vague one — actionability
matters because it determines whether work invested will actually close
the gap.

---

## 4. How the System Works

### 4.1 The Target

A target has:

| Field      | Purpose                                                   |
|------------|-----------------------------------------------------------|
| Name       | Desired state as a short assertion                         |
| Acceptance | Testable conditions for verification                       |
| Context    | Why it matters, how it was discovered                      |
| Priority   | critical / high / medium / low                             |
| Status     | identified → converging → achieved → retired               |
| Parent     | Optional — the parent target this decomposes               |
| Origin     | manual, or forked-from another target                      |
| Discovered | Date of creation                                           |

The name must be a state assertion ("All diagnostic output uses spdlog
macros"), not a task ("Migrate logging to spdlog"). This isn't
pedantry — it determines how the target is evaluated. A state assertion
has a clear truth value; a task has a completion status. The former
supports gap measurement; the latter only supports done/not-done.

### 4.2 The Convergence Evaluation

`/converge` implements the reconciliation loop:

```
for each active target (leaves first, then parents):
    1. Read acceptance criteria
    2. Investigate codebase (grep, glob, read, check CI)
    3. Classify gap: achieved / close / significant / not started
    4. Roll up sub-targets to parent
    5. Check implied targets (delivery, CI, tests)
    6. Detect staleness (recorded status ≠ assessed gap)
```

The output is a gap report, a recommendation, and a suggested action.
This is the OODA loop instantiated for software development: observe
(gather), orient (evaluate gaps), decide (recommend target), act
(suggest next step).

### 4.3 Implied Targets

Certain targets are inferred rather than declared:

- **Delivery**: Any feature target implies "delivered" (merged, deployed,
  etc.). The project's CLAUDE.md declares what delivery means.
- **Standing invariants**: "Tests pass" and "CI green" are always
  implied. Violations take priority over all explicit targets — broken
  invariants block all convergence.

This draws on KAOS obstacle analysis: implied targets represent
conditions that could silently prevent goal satisfaction even when
explicit criteria are met.

### 4.4 The Target Lifecycle

```
identified → converging → achieved → retired
    ↑              ↓
    ← (target mutates, reverts to identified or splits)
```

Targets can also be:
- **Forked**: A new target spun off from work on another target.
- **Split**: A target found to be too large decomposes into sub-targets.
- **Abandoned**: A target found to be wrong or irrelevant is removed.
- **Mutated**: A target's framing or acceptance criteria change as
  understanding deepens.

All of these are legitimate lifecycle events, not failures. The moving-
target literature (Ishida/Korf, Bouguerra et al.) provides theoretical
backing: as long as targets don't shift faster than work progresses,
convergence is achievable.

### 4.5 Relationship to Tasks

Targets and tasks coexist. The distinction is structural:

| Dimension    | Task (TODO)                | Target                        |
|-------------|----------------------------|-------------------------------|
| What it is  | An action to perform       | A state to achieve            |
| Evaluation  | Done / not done            | Gap measurement (distance)    |
| Persistence | Completed and archived     | Achieved but still verifiable |
| Mutation    | Unusual (scope creep)      | Normal (understanding deepens)|
| Context     | Often minimal              | Rich (why, origin, discovery) |

Some items naturally live as tasks ("buy Rectangle Pro", "publish
decimal proposal"). Others naturally live as targets ("all tests pass on
CI", "no compiler warnings"). The system encourages recognising which
framing serves better and using the right one.

---

## 5. Comparison with Existing Approaches

### 5.1 vs. Kubernetes-style Reconciliation

The convergence system borrows Kubernetes' reconciliation pattern but
operates at a different abstraction level. Kubernetes controllers run
continuously with sub-second loops; `/converge` runs on-demand (human-
initiated or at workflow checkpoints). Kubernetes has precise state
models; targets have fuzzy acceptance criteria that require judgement.
The level-triggered principle transfers directly; the automation level
does not.

### 5.2 vs. OKRs (Objectives and Key Results)

OKRs share the "desired state" framing: an Objective is a desired state,
Key Results are measurable acceptance criteria. The convergence system
differs in:

- **Granularity**: OKRs are quarterly/annual; targets are project-level,
  potentially daily.
- **Evaluation**: OKRs are scored at period end; targets are evaluated
  continuously.
- **Mutability**: OKRs are set for a period and revisited at boundaries;
  targets can mutate at any time.
- **Agent-friendliness**: Targets include enough context for an AI agent
  in a fresh session to understand and work toward them.

### 5.3 vs. BDD/TDD (Behaviour/Test-Driven Development)

BDD's "Given-When-Then" scenarios and TDD's test-first approach both
express desired states before implementation. The convergence system
operates at a higher level: a target like "all diagnostic output uses
spdlog macros" might eventually be operationalised as a test, but it
starts as a project-level intent that guides multiple implementation
decisions. Targets are closer to BDD's "feature" level than individual
scenarios.

### 5.4 vs. GitHub Issues / Project Boards

Issues are task-oriented ("fix bug #123") with status columns
(Open → In Progress → Done). The convergence system offers gap-based
assessment instead of binary status, state-based framing that survives
context loss, and hierarchy that rolls up automatically.

---

## 6. Theoretical Concerns and Mitigations

### 6.1 Target Proliferation

**Risk**: Users create too many targets, making `/converge` output
overwhelming.

**Mitigation**: The priority system and the recommendation heuristic
naturally focus attention. Achieved targets move to a separate section.
The 2-level hierarchy limit prevents fractal decomposition. In practice,
a project should have 5-15 active targets at any time.

### 6.2 Acceptance Criteria Vagueness

**Risk**: Fuzzy acceptance criteria make gap assessment unreliable.

**Mitigation**: The system encourages concrete, testable criteria at
creation time (`/target` infers criteria and asks for confirmation).
Over time, criteria can be refined as understanding deepens — this is
a feature (target mutation), not a bug.

### 6.3 Staleness

**Risk**: Targets become stale because nobody updates them.

**Mitigation**: `/converge` detects staleness by comparing recorded
status to assessed gap. Integration points at workflow transitions
(session end, plan completion, branch merge) prompt reconciliation.
The system is designed to be self-correcting: level-triggered evaluation
means staleness is detected and surfaced, not silently accumulated.

### 6.4 Over-Engineering

**Risk**: The system adds ceremony without proportional value.

**Mitigation**: The design is deliberately lightweight: a single
markdown file, two skills, and a handful of integration points. No
databases, no APIs, no special tooling. The file format is
human-readable and manually editable. If the system stops being useful,
the file is just documentation.

---

## 7. Related Literature: Full References

### Infrastructure & Desired-State Systems

- Burgess, M. (1998). "Computer Immunology." USENIX LISA '98.
  https://usenix.org/legacy/events/lisa98/full_papers/burgess/burgess.pdf
- Burgess, M. and Bergstra, J. Promise Theory.
  https://en.wikipedia.org/wiki/Promise_theory
- Elhage, N. "The Architecture of Declarative Configuration Management."
  https://blog.nelhage.com/post/declarative-configuration-management/
- Jenco, B. (2021). "Desired State Systems." NDC Oslo.
  https://branislavjenco.github.io/desired-state-systems/
- Bowes, J. "Level Triggering and Reconciliation in Kubernetes."
  https://hackernoon.com/level-triggering-and-reconciliation-in-kubernetes-1f17fe30333d
- Downey, T. "Desired State Versus Actual State in Kubernetes."
  https://downey.io/blog/desired-state-vs-actual-state-in-kubernetes/
- Kubernetes Design Principles.
  https://github.com/kubernetes/design-proposals-archive/blob/main/architecture/principles.md

### Control Theory

- Åström, K.J. and Murray, R.M. (2008/2021). "Feedback Systems: An
  Introduction for Scientists and Engineers." Princeton University Press.
  https://www.cds.caltech.edu/~murray/books/AM08/pdf/fbs-public_24Jul2020.pdf
- Hellerstein, J.L. et al. (2004). "Feedback Control of Computing
  Systems." Wiley.
- Klein, M. (2024). "The Principle of Reconciliation." Chainguard.
  https://www.chainguard.dev/unchained/the-principle-of-reconciliation

### Requirements Engineering

- van Lamsweerde, A. (2001). "Goal-Oriented Requirements Engineering:
  A Guided Tour." RE'01.
  https://www.researchgate.net/publication/3913915
- Lapouchnian, A. "Goal-Oriented Requirements Engineering: An Overview
  of the Current Research." University of Toronto.
  https://www.cs.utoronto.ca/~alexei/pub/Lapouchnian-Depth.pdf
- Yu, E. (1995+). "i* Framework for Goal-Oriented Modeling."
  http://www.cs.toronto.edu/km/istar/
- Holler, D. et al. (2016). "Hierarchical Planning: Relating Task and
  Goal Decomposition with Task Sharing." IJCAI.
  https://www.ijcai.org/Proceedings/16/Papers/429.pdf

### AI Planning

- Fikes, R. and Nilsson, N. (1971). "STRIPS: A New Approach to the
  Application of Theorem Proving to Problem Solving."
  https://ai.stanford.edu/~nilsson/OnlinePubs-Nils/PublishedPapers/strips.pdf
- Sacerdoti, E. (1974). "Planning in a Hierarchy of Abstraction Spaces."
  Artificial Intelligence.
- Erol, K., Hendler, J., Nau, D. (1994). "HTN Planning: Complexity and
  Expressivity." AAAI.
  https://www.researchgate.net/publication/2671926
- Alechina, N. et al. (2013). "An Operational Semantics for the Goal
  Life-Cycle in BDI Agents." AAMAS.

### Moving Targets & Adaptive Planning

- Ishida, T. and Korf, R.E. (1995). "Moving-Target Search: A Real-Time
  Search for Changing Goals." IEEE TPAMI 17(6).
  https://www.researchgate.net/publication/3192412
- Bouguerra, A. et al. (2014). "Planning When Goals Change: A Moving
  Target Search Approach." Springer.
  https://inria.hal.science/hal-00992837v1/document
- Chand, S., Hsu, V.N., Sethi, S. (1998). "A Theory of Rolling Horizon
  Decision Making." Annals of Operations Research.
- Boyd, J. (1970s). OODA Loop.
  https://en.wikipedia.org/wiki/OODA_loop

### AI Coding Agents

- Huang, X. et al. (2024). "Understanding the Planning of LLM Agents:
  A Survey." arXiv:2402.02716. https://arxiv.org/abs/2402.02716
- Yang, J. et al. (2024). "SWE-agent." NeurIPS.
  https://arxiv.org/abs/2405.15793
- Xia, C.S. et al. (2025). "Agentless." FSE.
  https://arxiv.org/abs/2407.01489
- Wang, X. et al. (2025). "OpenHands/CodeAct." ICLR.
  https://arxiv.org/abs/2407.16741

### Gap Analysis & Quality

- ISO/IEC 25010:2011. "Systems and software engineering — Systems and
  software Quality Requirements and Evaluation (SQuaRE)."
- McConnell, S. (2006). "Software Estimation: Demystifying the Black
  Art." Microsoft Press.
- Boehm, B. (1981). "Software Engineering Economics." Prentice-Hall.
  (Origin of the Cone of Uncertainty.)

---

## 8. Operational Cost Analysis

A convergence system that's too expensive to run routinely fails at the
point of adoption. This section analyses the cost centres and the design
responses that keep the system practical.

### 8.1 The Cost of Full Evaluation

A naive `/converge` implementation reads acceptance criteria for every
active target and investigates the codebase — greps, globs, file reads,
CI checks. With 10 targets, this means 50+ tool calls and potentially
30k+ tokens consumed before producing output. At current API costs, a
thorough evaluation could consume more context than the work session
that follows it.

**Response: Tiered evaluation.** The system operates at three tiers:

| Tier    | Tool calls | When                                    |
|---------|------------|-----------------------------------------|
| Scan    | ~3         | Mid-work check, minor checkpoint         |
| Default | ~10-15     | Session start, run boundary, blockage    |
| Full    | Unbounded  | Milestone boundary, periodic audit       |

Scan reads targets.md and reports status fields with change hints. No
codebase investigation. Default deeply evaluates only the top 2-3
targets by priority — the ones most likely to be recommended — and
assesses the rest from status fields. Full is the original design,
used explicitly when comprehensive assessment is needed.

This is analogous to Kubernetes' informer cache vs direct API calls:
routine operations work from cached state; full reconciliation happens
on a schedule or trigger.

### 8.2 Replanning Frequency

The moving-target literature (Ishida/Korf 1995) establishes that
replanning has a cost, and the optimal strategy is not "replan
constantly" but "replan when the expected value of the new plan exceeds
the replanning cost." Bouguerra et al. (2014) formalise two strategies:

- **Open Check**: Can the new goal still be reached from the current
  state? (Cheap — just verify plan validity.)
- **Plan Follow**: Does executing the current plan still bring us closer
  to the new goal? (Moderate — assess trajectory.)

Full replanning is the expensive fallback when both checks fail.

**Response: Decision boundaries.** The system evaluates convergence at
natural decision points — session start, run completion, blockage —
not after every small change. Within a coherent stretch of work toward
a single target (a "run"), re-evaluation is suppressed. The key
distinction: `/converge` is a *decision tool*, not a monitoring tool.
You run it when you need to decide what to do, not to continuously
track progress.

Rolling horizon planning (Chand et al. 1998) provides the theoretical
backing: solve over a finite horizon, implement near-term decisions,
re-solve with updated information at the next boundary.

### 8.3 State Discovery Cost

Acceptance criteria vary enormously in evaluation cost:

| Type              | Example                                      | Cost       |
|-------------------|----------------------------------------------|------------|
| Grep-checkable    | "No printf in non-vendor code"               | 1 tool call |
| CI-checkable      | "CI green on windows-latest"                 | 0 (cached)  |
| Review-required   | "All platform differences behind interfaces" | 10+ reads   |

**Response: Cost-aware evaluation.** The system classifies criteria
by evaluation cost (inferred from the criteria text, or explicitly
tagged). Grep-checkable criteria are always evaluated — they're
essentially free. CI-checkable criteria use cached results from the
gather script (amortised across all targets). Review-required criteria
are only deeply evaluated in full tier or when the specific target is
the recommendation.

This mirrors the tiered caching in Kubernetes controllers: etcd watches
(cheap, continuous) vs API server queries (moderate, periodic) vs full
reconciliation (expensive, rare).

### 8.4 Implied Target Overhead

Checking delivery status (open PRs, CI state, merge status) for every
converging target means GitHub API calls for each evaluation.

**Response: Amortised gathering.** The gather script collects git state,
open PRs, and recent merges in a single pass. `/converge` matches
targets to PRs by branch name or PR title. One `gh pr list` covers all
implied delivery checks — O(1) in API calls regardless of target count.

### 8.5 Context Accumulation

A project running for months accumulates achieved targets. Each consumes
context on every gather, even though achieved targets rarely need
re-evaluation.

**Response: Archival rotation.** Achieved targets older than a
configurable threshold (default 30 days) rotate to an archive section
or separate file. The gather script emits only active and recently
achieved targets. Historical data remains accessible but doesn't
consume context on routine evaluation.

### 8.6 The Change-Hint Hybrid

Pure level-triggered evaluation (recompute everything from scratch) is
theoretically clean but practically expensive. Pure edge-triggered
evaluation (respond only to changes) is cheap but fragile — missed
changes cause silent state divergence.

**Response: Level-triggered with change hints.** The gather script
records the last evaluation SHA in the targets file and emits files
changed since that SHA. `/converge` uses this to prioritise which
targets to deeply evaluate: if changed files overlap with a target's
domain, evaluate it; others get a status-only pass.

This isn't edge-triggered — it still evaluates against current state,
not the change event. The change set is a *hint for where to focus*,
not the evaluation itself. This is the pragmatic middle ground between
theoretical purity and operational cost.

Theoretical support comes from Kubernetes' "level-triggered with
efficient change detection" architecture: informers watch for changes
(edge) to trigger reconciliation (level). The reconciliation always
computes full state, but the watch avoids polling.

### 8.7 The General Principle

**The convergence system should spend tokens proportional to the
decision value.** Starting a new work session? Worth a moderate
evaluation. Just finished a one-line fix? A status-field update is
plenty. Completing a major milestone? Full audit. The cheap path is
the default; the expensive path is opt-in.

This follows from control theory: a PID controller's sampling rate
should match the dynamics of the system being controlled. A thermostat
samples every few minutes; a flight controller samples milliseconds.
Software project state changes on the order of hours to days — the
evaluation frequency should match.

---

## 9. Context Windows and State Synchronization

The convergence system has a deep relationship with context windows
that goes beyond "targets.md costs N tokens to read." At its core,
the system is a context management strategy — it decides what intent
needs to survive context loss, externalizes it in a form optimized for
re-ingestion, and provides a structured re-entry point that minimizes
the cost of getting back up to speed.

### 9.1 Synchronization vs Replay

There are two approaches to recovering from a communication
interruption:

- **Journal replay**: Record what was sent, figure out what was
  missed, replay the gap. This depends on history — if the journal is
  incomplete, recovery is degraded or impossible.
- **State synchronization**: On reconnection, establish the current
  state of both ends, compute the delta, sync to consistent state,
  then resume streaming incremental updates.

This distinction, familiar from database replication and network
protocols, maps precisely onto the context window problem.

**Journal replay ≈ restoring context from conversation history.** This
is what memory files, stashed context, and transcript re-reading do —
reconstruct what happened from artifacts. It works but is inherently
lossy. Compacted messages lose detail. Stashed context captures a
snapshot, not full state. Transcripts are enormous and expensive to
re-ingest. The more history you've lost, the worse the reconstruction.

**State synchronization ≈ convergence evaluation.** `/converge` doesn't
ask "what happened since I last looked?" It asks "what is the current
state relative to the desired state?" No history required. A brand new
agent in a fresh session, with zero prior context, can run `/converge`
and know exactly where things stand and what to do next. The targets
file is the "desired state" endpoint; the codebase is the "actual state"
endpoint; `/converge` computes the delta.

**Streaming ≈ working within a session.** Once synchronized, work
proceeds incrementally — status updates, scan-tier checks, small edits.
This is the efficient steady-state, analogous to streaming replication
after an initial sync. You don't need full synchronization on every
operation.

Context loss — session end, `/clear`, compaction — is then just a
**disconnection event**. Not a failure, not an emergency. You reconnect
with a sync, not a replay. The cost of reconnection is one `/converge`
run — bounded and predictable — rather than a degraded, uncertain
reconstruction from partial history.

### 9.2 Tiered Evaluation as Reconnection Strategy

The evaluation tiers map to different degrees of context loss:

| Context state         | Reconnection          | Tier          |
|-----------------------|-----------------------|---------------|
| Total loss (new session, new agent) | Full sync   | `/converge full` |
| Partial loss (compaction, AFK)      | Delta sync  | `/converge`       |
| No loss (mid-session)               | Heartbeat   | `/converge scan`  |

Full sync evaluates everything from scratch — no assumptions about
what's been seen before. Delta sync uses change hints (files modified
since last evaluation SHA) to focus the sync on what likely changed,
analogous to knowing the approximate journal position even if you can't
replay exactly. Scan is a heartbeat — verify nothing drifted, report
cached state, keep working.

This spectrum means the system degrades gracefully with context loss.
Total amnesia costs one full `/converge` (the most expensive tier, but
bounded). Partial context loss costs a focused evaluation. Continuous
work costs almost nothing.

### 9.3 Targets as External Memory

The context window is ephemeral working memory. Targets are long-term
memory. The relationship mirrors human cognition: you can't hold
everything in working memory, so you write things down. But the *format*
of what you write down determines the cost of re-ingestion.

A TODO ("fix Windows tests") requires reconstruction to act on: which
tests? what's failing? why does it matter? what's been tried? That
reconstruction consumes context and may be impossible without the
original conversation.

A target ("all tests pass on Windows" with acceptance criteria, context,
and priority) is self-contained. An agent reads it, evaluates the gap
against the codebase, and starts working. The reconstruction cost is
near zero because there's nothing to reconstruct — the target carries
its own context.

This is why the "Context" field in the target format is not
documentation — it's part of the synchronized state. It answers "why
does this target exist?" which is needed for *evaluation*, not for
*replay*. An agent doesn't need to know the conversation that produced
the target; it needs to know why the target matters, so it can assess
the gap intelligently and make good decisions about how to close it.

### 9.4 Context Cost as a Design Constraint

Every byte of `/converge` output that enters the context window is a
byte not available for actual work. This makes context cost a first-
class design constraint, not just a performance concern.

**Acceptance criteria design affects context cost.** Grep-checkable
criteria ("no printf in non-vendor code") produce small, bounded
results — a count or a short file list. Vague criteria ("well-
structured platform abstraction") force broad file reads that fill the
window with investigation output. The guidance to prefer concrete,
testable criteria is not just about evaluation reliability — it's about
context efficiency.

**Hierarchy is attention management.** Instead of holding 15 targets in
context, you hold 3-4 top-level targets with rollup summaries. Sub-
targets only enter context when you drill into a specific area. A parent
rollup ("converging, 4/6 achieved") costs 1 line. Expanding all 6
children costs 6+. You pay only for the detail you need — the same
principle as abstraction hierarchies in ABSTRIPS (Sacerdoti 1974).

**Implied targets are free in context.** Standing invariants (tests
pass, CI green) and delivery targets (merged to master) are never
stored in targets.md — they're inferred at evaluation time. Anything
derivable doesn't need to be stored, and anything not stored doesn't
consume context.

**The gather script is a context gateway.** All project state enters
the agent's context through the gather script. This makes the context
cost of orientation predictable and controllable. Adding a section to
gather.sh has a direct, measurable impact on context consumption for
every subsequent evaluation.

### 9.5 The Deeper Point

The convergence system makes context loss routine rather than
catastrophic. In a history-dependent model — journal replay, memory
files, stashed context — losing context means losing the ability to
understand where you are. Recovery quality degrades with the amount
of history lost. In a state-synchronization model, context loss is
just a reconnection event. You re-evaluate the delta between where
you are and where you want to be, and you're back up to speed. The
cost is bounded and predictable regardless of how much history was
lost.

This reframes the entire relationship between agents and context
windows. The context window is not a container to be preserved — it's
a working space to be used and released. Intent that matters gets
externalized into targets. State that matters gets evaluated from the
codebase. History is an efficiency optimization (change hints, memory
files), not a correctness requirement.

The convergence system is, at its deepest level, a protocol for
surviving context loss with minimal re-synchronization cost.

---

## 10. Conclusion

The desired-state convergence system synthesises ideas from
configuration management (convergent operators, declarative state),
control theory (feedback loops, level-triggered reconciliation),
requirements engineering (goal decomposition, obstacle analysis), AI
planning (hierarchical decomposition, moving-target search), and
adaptive methodologies (Agile, rolling horizons, OODA).

The key insight is simple: **track where you want to be, not what you've
done**. The theoretical backing is strong — the reconciliation loop is
one of the most well-understood patterns in engineering, and goal-
oriented approaches have decades of formal foundations. The practical
design is deliberately lightweight: markdown files, two CLI skills, and
integration into existing workflow checkpoints.

The system's value scales with context loss. For a single developer
in a continuous session, tasks work fine. For AI agents that start
fresh each session, or for projects revisited after weeks, the
self-contained, state-based, continuously-evaluable nature of targets
provides dramatically better continuity than task lists.

---

## Appendix A: Why "Target" and Not "Goal"

The system uses "target" throughout — target files, the `/target`
skill, convergence targets — rather than the more common "goal." This
is a deliberate terminological choice.

### The case for "goal"

"Goal" is the established term in the academic literature that informs
this system. GORE (Goal-Oriented Requirements Engineering), KAOS, i*,
HTN planning, BDI agent architectures, and OKRs all use "goal" as
their central concept. Someone searching for the theoretical
foundations of this system will find "goal-oriented" papers, not
"target-oriented" ones.

"Goal" is also the more natural English word for "something you want
to achieve." It has broad recognition and needs no explanation.

### The case for "target"

Despite the literature alignment, "target" is the better fit for what
this system actually describes. The reasons are semantic, metaphorical,
and practical.

**Semantic precision.** A goal is aspirational and open-ended —
"improve code quality" is a goal. It invites vagueness and resists
binary evaluation. A target is something you can *hit* — it implies a
definite state you either reach or don't. "All diagnostic output uses
spdlog macros" feels like a target; "better logging" feels like a
goal. The system requires crisp, testable desired states. The word
"target" reinforces this discipline at the point of creation.

**Metaphorical fit with convergence.** The system's central metaphor
is convergence — closing the distance between current state and
desired state. You converge *on a target*, not *on a goal*. The
physical metaphor is spatial: a target is a fixed point you're
approaching, and the gap is measurable distance. Goals don't naturally
evoke distance measurement the same way. "How far are we from the
target?" is a more natural question than "how far are we from the
goal?" — the former implies a metric, the latter implies a judgement.

**Infrastructure lineage.** "Target state" is the established term in
the infrastructure automation tradition that most directly informs the
system's architecture. Kubernetes, Terraform, Puppet, and CFEngine all
speak of desired state or target state, not goal state. Since the
system borrows the reconciliation loop from this tradition, using the
same terminology creates a clear conceptual link.

**Avoids overloading.** In AI agent contexts, "goal" is severely
overloaded — it means everything from a system prompt's objective to a
user's stated intent to a node in a planning graph to an OKR. Adding
another "goal" concept to the agent's vocabulary creates ambiguity.
"Target" occupies a distinct semantic niche: it's a project-level
desired state tracked in a specific file with a specific format. There
is no confusion about what kind of target is meant.

**Unpretentious.** "Goal-oriented requirements engineering" sounds like
a methodology that requires training. "Convergence targets" sounds like
a practical tool. The system is deliberately lightweight — a markdown
file and two skills. The terminology should match the weight class.

### The bridge

The research report (sections 2.4, 2.5, 7) explicitly references the
goal-oriented literature — KAOS, i*, GORE, HTN planning, BDI agents —
and maps their concepts to the system's design. The terminological
difference doesn't create an intellectual gap; it creates a practical
distinction. Readers familiar with GORE will recognise that targets are
operationalised goals with the formalism stripped down to what an AI
agent and a markdown file can support. Readers unfamiliar with the
literature will understand "target" immediately without needing the
academic context.

The hierarchy is: goals are the theoretical concept; targets are the
operational instantiation. The system implements goals; it calls them
targets.
