---
name: oracle-first
description: Verification-economics method for AI-assisted work. Use when porting or migrating legacy code, replicating an existing system's behaviour ("match the old app exactly"), doing visual/physics/feel parity work, authoring the correctness spec for new code (property tests, invariants, TLA+), designing acceptance criteria for a target, planning verification for a codebase analysis, or when repeated tweak-and-check against human judgment isn't converging.
user-invocable: true
---

# Oracle-first

Method for deciding where verification effort goes before generation
effort. Full theory, evidence, and case studies:
[`doctrine.md`](~/.claude/skills/oracle-first/doctrine.md). Read it when
planning a port/migration or a verification strategy; the rules below
suffice for quick classification.

## Two oracle modes — read this first

"Oracle" is the *test-oracle* sense: anything that adjudicates
correctness — assertion, invariant, property test, type check, TLA+
model, golden file, differential comparison. **Not** "external source of
truth." Most work here is new code, not porting; the two modes differ in
what the oracle can promise:

- **Port / replicate** — asks *"does this match what exists?"* The
  reference is external ground truth; strong guarantee. Extract it into
  a runnable check (rules 3–7). Classes 2/4.
- **New code** — asks *"does this conform to what I declared?"* You
  *author* the spec as executable checks (property tests, TLA+,
  load-bearing properties — csp, doit, sqlpipe are all new systems with
  no referent). The guarantee is only as sound as the declaration: a
  green suite proves the invariant you wrote holds, not that it was the
  *right* invariant (rule 11). So **audits, not oracles, guard intent** —
  an adversarial pass probes whether the encoded spec matches reality,
  the one thing the oracle cannot check about itself. Design validity
  stays human (the irreducible residue); an oracle certifies that the
  code obeys the model, never that the model is right.

## Invocation

Three ways in, one contract:

- **`/oracle-first <task>`** — task mode: apply the method to that piece
  of work (e.g. `/oracle-first port the buggy physics to box2d`).
- **Inline mention** — the user says "oracle-first" while assigning work
  ("Port X. Take the oracle-first approach."): same as task mode; load
  this skill and apply the contract below to the assigned task.
- **`/oracle-first`** (bare) — context mode: run the codebase/planning
  analysis at the bottom of this file against the current repo or the
  work in flight. Also the course-correct when already caught in a
  tweak-and-check loop: stop iterating, classify, build the oracle.

### Task-mode contract

Before generating anything, produce a short **oracle plan** (≤10 lines):

1. **Classification** — the task's dominant cost term and verification
   class.
2. **The oracle** — what existing machine check gates this work; if none
   and judgment is the dominant term, what to extract or build *first*
   (reference extraction, differential harness, golden corpus, headless
   sim + solver) — oracle construction precedes iteration on the
   artifact.
3. **The loop** — what signal iteration will run against. Never a human
   perceptual signal (rule 2).
4. **The residue** — what will still need the human's judgment, and
   when (ideally once, at the end, as an accept/reject gate).

Then do the work under that plan, and carry it into any subagent
prompts when fanning out. Proportionality: for a small class-1 change
already under tests, the plan collapses to one line ("class 1,
existing suite gates it, proceeding") — the plan is a classification
act, not a ceremony.

## The cost model

Human time per task = **Harness + Generation + Verification**, where
Verification = **friction** (reaching a judgable state) + **judgment**
(the correctness call itself). Generation is near-free with agents; the
other three terms dominate. Classify every hard task by its dominant
term — the fix differs per term:

| Dominant term | Fix |
|---|---|
| Harness (can't reach/run/observe the system) | Build/reuse a harness *class* (device access, tunnel-drive, headless build), not a one-off |
| Verification-friction (setup tax before judging) | Presentation infra: agent drives to the judgable state, human glances |
| Verification-judgment (deciding correctness) | Build an oracle (below); human judgment only for the class-3 residue |

## Verification classes

1. **Decidable** — machine-checkable predicate (tests, TLA+, byte
   vectors, golden files). Cheap once built.
2. **Reference-comparable** — ground truth exists but comparison is
   perceptual/semantic (visual parity, port fidelity). Convert to
   class 1 by extracting the reference into an executable oracle.
3. **Aesthetic** — no reference; human taste. Irreducible; minimise its
   cost, don't try to automate it away.
4. **Dynamical/embodied** — correctness is runtime behaviour (physics
   feel, device behaviour, solvability). Convert to class 1 via
   headless simulation + search/differential traces.

## Rules

1. **Classify before working.** State the task's dominant cost term and
   verification class. Misclassification (treating a class-2/4 problem
   as class-3 "feel") wastes days.
2. **Never iterate against a human perceptual signal.** "Feels off" is
   a veto-oracle: high sensitivity, ~1 bit per round-trip, zero
   direction. Iterate against analysis or a machine oracle; spend human
   perception only as a final accept/reject gate.
3. **"Replicate X exactly" → port the generative model, not the
   output.** Approximating with different primitives then tuning toward
   the reference is an unsatisfiable spec — different equations, different
   phase portrait; no coefficient bridges them. Extract the reference's
   actual mechanism (constraints, algorithms, hand-set constants) and
   reproduce *that*.
4. **The spec must be executable.** Prose specs leak — they can only
   state what someone already knows is load-bearing. Extract the
   reference into a runnable oracle (`oracle.cpp`, conformance suite,
   golden corpus); generate against it. Two-step with a prose
   intermediate relocates the reinterpretation, it doesn't remove it.
5. **Differential harness pattern** (when a reference is runnable — or
   can be *manufactured*: a deliberately-naive obviously-correct twin,
   or metamorphic relations, per doctrine §4's new-code convergence
   loop): compile both reference and new headless; drive with identical
   seeded input tapes; diff paired state traces per tick; report
   divergence percentiles **as a function of horizon**; provide a
   `study <seed>` replay mode showing paired state side by side.
   Time-accelerated, no device, no UI.
6. **Goodhart guard.** Every fix must trace to a structural divergence
   in the reference source — never tune a constant merely because it
   shrinks the oracle's error. Gradient + structural constraint =
   system identification; gradient alone = curve fit.
7. **Chaotic/dynamical systems: bounded acceptance.** Divergence-vs-
   horizon separates systematic per-step error (linear; closable
   analytically) from Lyapunov amplification (exponential; unclosable
   across engines). Gate on per-step epsilon + distributional/
   qualitative invariants at long horizons. Bit-exact long-horizon match
   across different engines is impossible — don't chase it.
8. **Oracle work splits three ways.** *Design* (what to measure,
   acceptance semantics, discipline) needs the human — but once per
   oracle class, not per project. *Implementation* is fully delegable.
   *Extension* (more tapes, invariants, scenarios, coverage) is safe
   unattended work — the correct standing goal for idle agents.
9. **Attestation ≠ execution.** An agent's "done" is an unverified
   channel (documented false-completion cases). Completion claims are
   validated by an oracle or an independent reviewing agent, never by
   the agent that did the work.
10. **Unverified autonomy is negative value.** Long unattended runs
    without an oracle don't reduce the human's verification burden —
    they concentrate and defer it. Raise autonomy only as far as the
    oracle coverage that gates it.
11. **A green suite verifies the idealisation it encodes, not the
    system.** Every catastrophic 2026 defect shipped under green
    class-1 suites (nonce reuse behind a green TLA+ model; silent row
    loss behind 92 passing tests; a fail-open security chain). Declare
    each repo's load-bearing properties explicitly; map each to an
    oracle, a scheduled adversarial audit, or a recorded accepted risk;
    and triage audit findings adversarially before acting — the audit
    machinery has a documented false-positive record.
12. **For new code, you grow the oracle; you don't author it once.**
    With no external referent, a trustworthy spec is *converged*, not
    declared — the same discovery problem the doctrine names for
    unstable-spec tooling (J-curve), applied to the checks themselves:
    - **Seed** the few properties you're confident are load-bearing,
      ideally before the code (TLA+/invariants first, then conform).
    - **Manufacture a referent** where you can, so "new code" borrows a
      port's strength: a naive, obviously-correct twin to differential-
      test against (rule 5, self-authored reference), or **metamorphic
      relations** — properties that must hold *between* outputs without
      knowing the right output (f(x) vs f(permuted x)).
    - **Accrete from failure** — every bug and every audit finding
      becomes a newly-encoded property. The oracle grows monotonically
      from escapes; it is never finished.
    - **Test the oracle, not just the code** — inject faults / mutate
      the code and confirm the oracle catches them (csp ships
      intentionally-buggy TLA+ variants). An oracle green on known-broken
      code is weak; mutation catch-rate is how you *measure* oracle
      strength.
    - **Probe for unknowns** — adversarial audits whose output is new
      *spec*, run loop-until-dry; diminishing new findings is the
      convergence signal.
    - **Stabilise intent by use before hardening** — dogfood first; a
      spec still in discovery can't be reliably oracled, and premature
      hardening depreciates on the next pivot. Then **declare the
      residual** un-oracled surface as explicit accepted risk, never
      silence.
    Reliable ≠ certain: the oracle is trustworthy to the degree it
    catches injected faults, has absorbed every past escape, survives
    adversarial probing with diminishing returns, and has a tracked
    false-accept rate.

## When analysing a codebase or planning

Produce, as part of the analysis:
- **Cost-term decomposition** — where will human time actually go?
- **Oracle inventory** — what machine-checkable ground truth exists;
  what's missing for the dominant judgment costs.
- **Harness classes required** — reuse before building; one-off vs
  recurring.
- **Acceptance criteria per target, split by verification class** —
  never bundle decidable checks with perceptual sign-off in one
  criterion (the target inherits the p of its most-perceptual clause).
- **Conclude with a graph recommendation.** Land the analysis in the
  target graph — don't leave it as prose. Translate the cost-term,
  oracle-inventory, and class findings into concrete target changes,
  and — in most cases — converge on a *single choke-point target* (the
  oracle foundation: injectable seams, manufactured referent, seeded
  invariants, a declared per-target oracle map) that embodies them,
  wired as a blocker of the targets whose verification it gates. Prefer
  one embodying target over scattering oracle obligations across many
  nodes; per-target acceptance refinements then ride each target's own
  work-PR, driven by the choke-point's oracle map. This is the
  new-code analogue of rule 12's "seed the properties before the code":
  the graph edit *is* the seeding act.

## Skill improvement

After applying this skill to a real port/verification problem, reflect:
did a new oracle pattern, failure mode, or cost-term emerge that
doctrine.md doesn't cover? Propose additions with user consent.
