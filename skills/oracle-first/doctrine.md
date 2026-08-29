# Oracle-first doctrine

Distilled from an extended discussion (2026-06-30 → 2026-07-03) between
Marcelo and Claude on AI-assisted-development productivity, verification
economics, and porting fidelity, grounded in a 30-repo evidence
deep-dive and a live case study (TiltBuggy). Source of record: mnemo
session `1cf2248b` (in `~/think`); quantitative report:
[`~/think/analysis/verification-strategy.md`](~/think/analysis/verification-strategy.md);
business thesis built on this doctrine:
[`~/think/analysis/verified-migration-business.md`](~/think/analysis/verified-migration-business.md);
second-order amendment (honesty layer, 2026-07) sourced from
[`~/think/analysis/oracle-first-state-of-play-2026-07-18.md`](~/think/analysis/oracle-first-state-of-play-2026-07-18.md).

This file is the durable reference. Agents doing codebase analysis,
port/migration planning, or verification design should read it and cite
it as **oracle-first doctrine**.

---

## 1. The productivity frame

- Marcelo's measured multiplier vs a single-generalist baseline is
  ~25–55× and **flat across five months of rising model capability**.
  The flatness is diagnostic: the binding constraint is his attention
  (~90 min/day), not model capability. The multiplier ∝ 1/p, where
  **p = fraction of output requiring him personally**.
- Every efficiency dividend has historically been spent on scope (more
  repos, harder problems) rather than banked into raising the
  multiplier — a **Jevons equilibrium**. Breaking the plateau is an
  allocation decision: spend the next dividend on removing himself from
  loops (oracles, harnesses, presentation), not on repo #41.
- **Meta-tool p-conservation**: his highest-p work is his own tooling
  (bullseye, spyder, jevons ~20–30%), because a tool whose spec is
  being discovered by dogfooding cannot be oracled. Converting object
  work to low-p by building tools takes on meta work at ~2× the p —
  the flat multiplier is partly this exchange at equilibrium. Meta-p is
  a **J-curve**: it collapses when a tool's spec stabilises. Corollary:
  don't start new meta-tools while the current generation is mid-curve.
- The path from ~50× to 100×+ is the **operator → governor**
  transition: judgment migrates into standing artifacts (oracles,
  acceptance criteria, conventions, policy gates) so the human reviews
  exceptions, not output. At that scale the single-generalist
  comparison loses its denominator; the honest metric becomes
  **validated output per week at stated confidence**.

## 2. The four-term cost model

Human time per task = Harness + Generation + Verification(friction +
judgment).

- **Harness** — making the system reachable/runnable/observable at all:
  builds, tunnels, device access, drivers, logging pipelines. Pure
  plumbing, no domain theory. (HMS: getting HMS.exe running and driven
  over a tunnel dominated the project's human cost.)
- **Generation** — designing and writing the change. Typing is ~free;
  what persists under this heading is **design conviction** (~a quarter
  of residual, v2) — pivot rulings and formalising the owner's own ideas
  (wbnf's formalism, cv's build semantics, bullseye's methodology).
  Deliberately untargeted: automating it automates away the owner's
  taste.
- **Verification-friction** — the setup tax to *reach* a judgable
  state: deploy, launch, navigate, reproduce. Killed by presentation
  infra (agent drives the artifact to the state and shows it — the
  "butler" pattern; ge-stream + spyder + jevons).
- **Verification-judgment** — deciding correctness once visible. The
  *largest* term (~30% of residual; v2, 34 repos). Killed by oracles
  for classes 1/2/4; irreducible for class 3.

**Central empirical finding (v2 sharpening):** p tracks **the
delegability of the bottleneck, not scale or difficulty**. The two
anchor rows: **hms** — the largest, hardest project (630K LOC,
billion-token campaigns) — has nearly the *lowest* p (5–12%) because it
went oracle-first (live-app bridge, capture diffs, computed
completion); **wbnf** — whose 2026 output is a design document — has
the *highest* (40–55%) because formalism design is undelegable
dialogue, the portfolio working as intended. Difficulty
anti-correlates with human time; trivial artifacts with no oracle and
no observability (a TUI the agent can't see) cost more than compiler
work with a decidable check.

## 3. Verification classes

1. **Decidable** — machine-checkable predicate. Tests, TLA+ (csp: 160
   specs incl. deliberately-buggy variants), cross-language byte
   vectors (pigeon), golden files (den, rustuml), schema hashes
   (sqlift).
2. **Reference-comparable** — ground truth exists; the distance metric
   is perceptual/semantic. RustUML vs Java PlantUML, HMS old-vs-web.
   *Convert to class 1 by extracting the reference's generative model*
   (RustUML: extracting klimt/ftile geometry + AWT font metrics turned
   "visual parity" into geometric equality).
3. **Aesthetic** — no reference; taste, feel, polish. Irreducibly
   human. Serve it with presentation infra (glance-cheap), never with
   iteration loops.
4. **Dynamical/embodied** — correctness is runtime behaviour in a
   physical or simulated world. Multimaze solvability (= search over a
   trusted headless sim), TiltBuggy physics feel, on-device behaviour.
   Convert to class 1 via headless simulation, solvers, differential
   traces.

## 4. Oracle theory

**Veto-oracle vs gradient-oracle.** Human perception ("feels off") is a
veto-oracle: exquisitely sensitive, ~1 bit per round-trip, no
direction. A machine oracle that localises divergence (which variable,
which tick, how much) is a gradient-oracle: each iteration yields a
full diagnosis. Iterating against a veto signal is gradient descent
through a 1-bit channel — that arithmetic, not model weakness, is why
tweak-and-feel loops take many passes. Rule: iterate against gradient
oracles; spend the veto only as a final gate.

**The oracle IS the spec.** Generation infidelity (the model
reinterprets) and verification cost are two symptoms of one missing
artifact: an explicit, executable spec. Oracle investment double-pays —
it gates output *and* disciplines generation. Prose specs leak because
they can only enumerate what someone already knows is load-bearing;
"the spec you write is incomplete; the spec you extract is complete but
illegible; the oracle makes it legible one divergence at a time."

**Goodhart guard.** A gradient-oracle plus free parameters = overfit to
the oracle. Constraint: every fix must trace to a *structural
divergence in the reference source*, never to "this constant shrinks
the error." Gradient + structural constraint = system identification.
Same trap when the harness *rewrites* the system under test (soft UDP
force-order, golden list injection): the residual shrinks because the
product path was bypassed, not because the generative model matches.

**Lyapunov-bounded acceptance.** For dynamical systems, measure
divergence as a function of horizon. Systematic per-step error grows
linearly and is closable analytically; chaotic amplification grows
exponentially and is unclosable across different engines. Acceptance =
per-step epsilon (measured floor) + distributional/qualitative
invariants beyond the chaos horizon (fishtail rate, slide distance,
turn direction). Bit-exact long-horizon cross-engine match is a
category error. **Intentional RNG** in the reference (neighbour-shuffle
tails, seed-from-`random_device`) is the same bound: after the
deterministic generative head is green, exact mid/tail sequences are
not a class-1 obligation.

**Oracle work splits three ways.** *Design* — what to measure,
acceptance semantics, epistemic discipline — is design-under-
uncertainty and needs the human, but **once per oracle class** (it then
becomes a template). *Implementation* is fully delegable class-1 work.
*Extension* (tapes, invariants, coverage, scale) is safe unattended
work — the correct standing goal for idle agent capacity: **the machine
builds its own cage.**

**Arriving at a reliable oracle for new code (the convergence loop).**
Porting gives the oracle for free — extract the referent. New code has
no referent, so the oracle is *grown*, not authored, and its reliability
is *converged toward*, never assumed. This is the same spec-discovery
problem §1 names for dogfooded tooling, turned on the checks themselves.
A trustworthy new-code oracle emerges from six moves:

1. *Seed* — author the few properties you're confident are load-bearing,
   ideally before the code (model-first: TLA+/invariants, then conform).
   The spec predates the implementation.
2. *Manufacture a referent* — recover a port's external-check strength
   without a legacy system: a deliberately naive, obviously-correct twin
   to differential-test the real implementation against (rule 5 sourced
   from a self-authored reference), or **metamorphic relations** —
   properties that must hold *between* outputs without knowing the right
   output (sortedness, round-trip identity, permutation invariance,
   f(x)⊑f(x∪y)). Metamorphic oracles are the main way to check code
   whose correct answer you cannot independently compute.
3. *Accrete from failure* — every escaped bug and every audit finding is
   a property you needed but had not encoded; convert each into a
   standing check. The oracle grows monotonically from its own escapes
   (csp's 160 specs accreted this way); it is never finished.
4. *Test the oracle, not just the code* — mutation/fault injection:
   deliberately break the code and confirm the oracle catches it (csp
   ships intentionally-buggy TLA+ variants for exactly this). An oracle
   green on known-broken code is weak; **mutation catch-rate is how you
   measure oracle strength**, the new-code analogue of "does the test
   fail on master" for a port. Also **instrument the instrument**:
   harness self-poison (NaN zoom → null MVP → empty projected AABBs while
   world geometry stays finite) makes the oracle report "blank" with no
   gradient — heal control-plane state; do not retune geometry.
5. *Probe for unknowns* — adversarial audits whose deliverable is new
   *spec*, not just fixes, run loop-until-dry: diminishing new findings
   across rounds is the convergence signal (and open-ended classes like
   de-id show some oracles never fully close — declare the residual).
6. *Stabilise intent by use before hardening* — the spec encodes your
   current understanding of intent, which is itself in discovery; a spec
   still moving (high-p, mid-J-curve) cannot be reliably oracled, and
   premature hardening depreciates on the next pivot (sqlift's hash
   oracle mooted by the cgo pivot). Dogfood to stabilise intent, then
   freeze it into checks, then declare the un-oracled residue as
   explicit accepted risk — never silence.

Reliable ≠ certain. A new-code oracle is trustworthy to the degree it
catches injected faults, has absorbed every past escape, survives
adversarial probing with diminishing returns, and carries a tracked
false-accept/false-reject rate — and even then it certifies conformance
to a declared spec, never that the spec matches intent (that residue is
what audits probe and the owner owns; §8, the irreducible residue).

**Eliciting intent into the seed (the design-time front-end).** The
convergence loop above *grows* an oracle once seed properties exist —
but for new code the seed itself is sourced from the owner's intent,
which is incomplete, evolving, and partly tacit. Sourcing it is an
interactive design-time act, not a one-shot spec-write. Prose intent
leaks exactly as prose specs do ("the oracle IS the spec"): the owner
can only enumerate what they already know is load-bearing, and much of
intent is "I'll know it when I see it" — the class-3 trap, upstream.

- *The example is the unit of intent transfer.* The reliable transducer
  from fuzzy intent to a decidable check is the concrete example — "when
  X, expect Y." Examples are demonstrable and arguable, they seed
  golden/property tests directly, and they surface the disagreement
  prose glosses. Drive the design dialogue toward load-bearing examples
  and capture each as an executable check *as the design firms*.
- *Spiral, not waterfall.* Some intent is only discoverable by reacting
  to something built (§1's dogfood-to-stabilise, made interactive):
  design → thin slice → owner reacts → intent sharpens → new example →
  check. Maintain a live **oracle-coverage map** of the design (pinned /
  fuzzy / examples-so-far); refuse production work on still-fuzzy
  regions; let exploratory spikes run intent-un-oracled, on purpose.
- *Sort decidable from taste first.* Elicitation's opening move is
  triage: make the functional majority decidable, isolate the
  irreducible class-3 residue as a single accept/reject. This moves §5's
  misclassification alarm upstream — the failure it prevents is
  discovering *at the end* that the whole thing was built against feel.
- *Guards carry over.* Proportionality — don't force an oracle onto a
  spike still discovering its own shape (premature hardening depreciates;
  cf. oracle depreciation, convergence-loop move 6). Goodhart — elicit
  *load-bearing* examples, not convenient ones, or the seed pins an
  incidental.
- *It needs an independent forcer.* Left to the executing agent,
  elicitation is skipped under the incentive to start generating
  (attestation ≠ execution). It wants a party whose standing role is to
  hold work at the design gate until intent is testable, and to judge
  the result against the elicited checks — the governor, not the
  operator (§1). In this portfolio that party is Jevons; the mechanism
  is filed as jevons 🎯T31 (enforce oracle-first as a system property +
  interactive greenfield oracle elicitation).

**Green-suite false assurance (v2's best-supported finding).** A green
class-1 suite verifies **the idealisation it encodes, not the system**.
Every catastrophic H1-2026 defect shipped under green suites — pigeon's
GCM nonce reuse behind a green TLA+ model, sqlpipe's silent row loss
behind 92 passing tests, doit's fail-open policy chain — and each was
found by human probing or a commissioned adversarial audit, never by
the tests. (Caveat: partly survivorship — test-caught defects never
became "catastrophic".) Consequences: declare each repo's
**load-bearing properties** explicitly and map each to an oracle, a
scheduled adversarial audit, or a recorded accepted risk; keep a
covered/NOT-covered ledger per formal model so "model green" cannot
silently coexist with "product broken". And audits are themselves
fallible — the same machinery produced 0/18 verified findings on one
repo and 22-findings-1-real on another — so **triage audit findings
adversarially before acting on them**.

**Oracle depreciation.** Oracles couple to architecture: a renderer
swap stranded yourworld2's parity optimizer; a cgo pivot mooted
sqlift's hash oracle. Weigh oracle ROI against expected architecture
churn; prefer oracles anchored to stable interfaces (wire formats,
traces, golden outputs) over internals.

**Attestation ≠ execution.** Documented false-completion cases (HMS
"134/134 done"; tests reported passing that were skipped) make an
agent's "done" an unverified channel. Separate duties: completion is
certified by an oracle or an independent reviewer, never the executor.
Corollary: an agent "better at keeping going" may be worse at knowing
when it can't — persistence without escalation calibration is
unverified autonomy.

**Independence is a function of automation, not locality** (owner
ruling, 2026-07-18, stock-car-racing 🎯T15). The separation of duties
above is about *who adjudicates* — harness output vs executor
narrative — not about which machine runs the check. A local pre-push
hook whose verdict is an exit code over a results file is exactly as
independent as the same command in CI, and faster; `--no-verify` is a
deliberate, visible override, the moral equivalent of force-merging
past a red check. Sequence enforcement accordingly: automated local
gate first, mutation-drill it (a gate is trusted only after catching a
planted failure), and migrate the same commands into a CI layer at the
production boundary — the point where CI's genuine additions
(environment-drift detection, independence from any single machine's
configuration) are worth their feedback-loop latency. Defaulting to
"set up CI" as the first enforcement move optimises the wrong term.

**Unverified autonomy is negative value.** Work that can't be checked
is deferred, concentrated verification debt (the "ran for weeks — now
inspect 200 screens" trap). Oracles raise the autonomy ceiling;
presentation lowers the human floor; advance them in lockstep.

**Spatial residual compression (geometry / layout / silhouette parity).**
Rule 2 already bans iterating against human perception; spatial work
makes the mechanism concrete. Spatial systems hide the real state
behind a lossy projection:

```
world / mesh / matrices  →  pixels  →  VLM words
```

Each arrow throws away the degrees of freedom the bug lives in
(millimetres, angles, which mesh, which basis). Agents and tired humans
then **over-fit stories to the residual of the projection** — a 30°
basis mix looks simultaneously like "centroid wrong", "roll wrong",
"culling", and "mesh bad." Vision returns coarse labels ("mass is left
of centre"); useful as a *veto*, useless as a *gradient*. Without a
shared control plane there is no *ceteris paribus*: every screenshot is
a new experiment.

**Principle — Prefer reconstructable geometry over perceptual residual
when the correctness claim is spatial.**

Operationally:

1. *Classify.* Placement / transform / silhouette / layout under a shared
   pose → class 2 with continuous geometry. "Feels right when spinning"
   is residual class-3 judgment *after* the continuous claim is green.
2. *Do not optimise against vision alone.* Use screenshots/VLMs as a
   stop condition ("still looks wrong → oracle incomplete or bug
   remains"), never as the search signal.
3. *Instrument before the lossy steps.* Shared inject of *logical* pose
   (portable quantities in a **named** frame — lon/lat, front+up, viewport
   roll — not raw matrices unless bases match); read-back that
   **reconstructs live state** (do not echo the last POST); emit centres,
   frames, world/viewport AABBs, angular error, basis tags; compare
   invariants (angular separation, normalized AABB offset, containment),
   not matrix equality across engines.
4. *Bandwidth rule.* Spend setup until the residual fits in a few numbers
   a human or agent can hold ("centre 0°, AABB offset 0.34 half-diagonals,
   bases disagree ~34°"). "The white blob is wrong somewhere" is too
   high-entropy to search.
5. *Structural over knobs.* When two systems disagree spatially, first
   ask "same generative model of the pose?" (basis, camera contract,
   face-user formula). Coefficient thrash on the wrong model is infinite;
   one correct basis conversion can end a day of screenshot thrash.
   Unifying coordinate systems is optional; **tagging and converting at
   the boundary is mandatory.** Same question for **non-spatial
   generative keys** (sort order, trial bands, bake-time index vs runtime
   re-sort): matching a frozen file sequence when the reference re-sorts
   at runtime is the wrong model — port the key, not the baked list.
6. *Harness health (instrument the instrument).* Empty or sentinel
   *projected* AABBs (`min=+∞`, `max=−∞`) while *world* AABBs remain a
   finite sphere/mesh ⇒ camera/MVP/zoom control-plane death (often NaN
   zoom after pinch), not missing geometry. Read meta for null
   `cam_dist` / all-null MVP; sanitize injects and heal the spring so the
   dual-oracle cannot permanently blank the subject. Force-order /
   soft-follow that rewrites level lists is **oracle substitution** for
   the product path — V for "chooses the right order" runs with follow
   off.
7. *Bounded residual after the structural head is green.* When the
   reference intentionally randomises tails (carousel neighbour
   separation), dual-app exact mid-list match is not required; gate the
   deterministic head (trial band + size sort) and treat RNG tails as
   residual judgment / distributional.

Economics: for spatial/port/parity work the harness is not overhead on
the fix — **it is the fix's precondition.** High setup once × high
information per cycle beats high friction × 1-bit veto loops. Dual-app
UDP is not required for every bug; a single-app dump of local centre,
face matrix, and projected AABB is often enough. When dual-app HTTP/UDP
*is* the harness class, compile it **debug-only** (`#ifndef NDEBUG`;
Release defines `NDEBUG`) so store binaries never bind observe ports or
soft-inject production state. VLMs remain good at "still broken / looks
like the old app" and bad at "which Euler angle and which basis."

*Case (yourworld → yourworld2 silhouette, 2026-07):* days of
tweak-screenshot thrash (culling, roll, free-floating localRot) did not
localise a mixed-basis face-math centre on a yw2 mesh plus a wrong
face-user presentation. A dual outer-loop oracle (POST logical state /
GET reconstructed live geometry + AABBs / GET screenshot; UDP follow for
ceteris paribus) compressed the residual to comparable numbers; one
structural centre conversion dropped AABB offset ~0.34 → ~0.05 and made
the remaining face-user claim decidable. The drawing path of the
obsolete reference stayed untouched — only the control plane was
instrumented.

**Second-order failures — the honesty layer (2026-07 amendment).** The
first-order problem (no oracle; iterate against feel) is largely won
in-portfolio. The failures that now dominate are second-order: *the
oracle exists and is wrong about itself.* Sourced from the July
campaigns (the RustUML parity endgame; the HMS migration factory),
synthesized in the 2026-07-18 state-of-play report:

- **Oracle gaming** — code satisfies the check without the behaviour
  (golden replay, fixture echo, literal-label recognizers): rule 6's
  boundary, breached under zero-failures pressure.
- **Metric-path divergence** — the measured path ≠ the shipped path. A
  headline number can be *true* and meaningless: "0 failures / 12,546"
  certified an oracle-assisted test path while the shipped CLI sat at
  59.5% real parity. The metric, not the code, was the bug.
- **Scaffolding Goodhart** — building verification machinery counts as
  verification progress. Comparators, queues, and ledgers absorbed a
  24.5-hour run while green evidence stayed at zero and the hard
  blocker (a dead tunnel) went undiscovered for ~22 hours;
  displacement-to-real-verification ≈ 6:1.
- **Gamed denominators** — the executor controls the divisor of its own
  gate (shrink the inventory until the ratio clears the threshold).

These are one family: Goodhart against the verification layer itself,
appearing wherever sustained optimization pressure (zero-failures
targets, "converging" status, coverage thresholds) meets any gap
between the measured quantity and product truth. Two campaigns
discovered the disease independently in the same week and converged on
the same medicine. **Design gates on the assumption they will be
optimized against — sincerely, not maliciously; a security mindset,
not a good-faith one.**

**The honesty ratchet (standing pattern).** Five ingredients, applied
together and wired into CI or hooks — not adopted piecemeal:

1. *Product-path-only metric tier* — only the shipped path produces the
   headline number; oracle-assisted tiers are regression nets, never
   the headline.
2. *Locked baselines that fail in both directions* — regression fails,
   and so does uncommitted improvement; numbers move only by deliberate
   commit, so they cannot drift into looking better than they are.
3. *Un-ownable denominators* — every quantity in a gate (numerator,
   denominator, corpus, threshold) is computed from source or a frozen
   reference, never from the executor's own inventory.
4. *Provenance obligations* — every fix traces to a named reference
   mechanism; suspicious constants carry adjacent provenance. Passing
   is not the same as being right for the right reason (rule 6, made
   auditable).
5. *Out-of-corpus perturbation* — acceptance includes holdout inputs
   the development corpus never saw, checked against a freshly
   generated reference. Anything memorizable is eventually memorized.

Ratchet strength is measured like any oracle's (convergence-loop move
4): plant a golden-echo and an unclaimed baseline improvement in a
sandbox; the ratchet must catch both.

**Evidence, not machinery, is progress — and an oracle is a loop, not
an artifact.** A verification asset counts for zero until it has run
green against the product on fresh, same-vintage inputs. Verification
campaigns report *activated green evidence counts*, never artifact
counts — "comparator built" is deferred verification debt dressed as
commits. And an oracle not wired to a standing enforcement point (CI,
hook, gate) decays like stale captures; enforcement wiring is part of
building the oracle, not an adoption step afterwards (the
built-and-never-adopted visual-regression pipeline is this lesson in
miniature).

**Generalize defenses before the next incident.** Every countermeasure
above was hand-built inside the repo that got burned, after it got
burned. Repo-local hardening is itself a defect: when a ratchet, guard
suite, or computed-completion pattern proves out, extract it into this
doctrine and its skeletons immediately, so the next repo starts with it
rather than rediscovering it post-incident.

**The stop-the-line call stays human.** Every Goodhart catch on record
was human-initiated. The machinery's job is not to remove that role but
to make the pull rare, cheap, and landing on evidence rather than
claims — the standing first line is the V-boundary checker (three
questions: did V run? against the product path? does the claim trace to
the oracle's output?), so the check is automatic rather than heroic.

## 5. The interpretive-dance failure mode

Asking a model for **precise transliteration** of existing logic
reliably yields approximation/reinterpretation instead. Mechanism: the
model is a *translator*, not a *transcriber* — it reads source into a
semantic representation ("what this does") and regenerates from that in
the target idiom. Anything in the source but not in the extracted
meaning — hand-set constants, load-bearing quirks, emergent behaviour —
is normalised away. It reproduces its *understanding* of the system,
not the system. Exhortation ("no, EXACTLY") fights the training
gradient and loses.

Fixes, in order of reliability:
1. **Structural tools** (sawmill) where source and target share
   structure — a transform never passes through "meaning."
2. **Port the mechanism, not the output**, when primitives differ
   (Chipmunk constraints ≠ Box2D forces): vendor or faithfully
   re-implement the reference's generative machinery.
3. **Small units + forced correspondence** — line-by-line source→target
   mapping accounts for every construct.
4. **Executable spec + differential oracle** to catch what 1–3 miss.

The maddening asymmetry: reinterpretation preserves *salient* behaviour
(looks right) and diverges on *subtle* behaviour (feels wrong) — and
human perception is tuned to exactly the subtle dynamical signatures
the semantic bottleneck discards. The "feel" is a high-bandwidth
detector for the residue the model dropped; treat it as a
misclassification alarm (a class-2/4 problem masquerading as class 3),
not as a tuning signal.

## 6. Case study: TiltBuggy (flagship)

Port of a 2013 Chipmunk/GLES tilt-driven buggy to Box2D/sokol on the ge
engine. Arc:

1. **Feel-loop (multiple passes, days):** force-based heuristic
   (proportional grip + alignment torque) tuned toward the old feel.
   Converged to "almost right"; reverse fishtail unreproducible. Each
   human tilt-test returned ~1 bit.
2. **The pivot (human intervention #1):** "This is maths and physics —
   I want to understand analytically why we can't nail this." Forced
   structural analysis: the original is a *constraint-based* car
   (chassis mass/moment hand-set to (1,1); steering body (0.1,0.1) with
   pivot + ±0.3 limit + damper with *stiffness 0* — no centering
   spring; two groove-joint wheels = hard lateral-velocity constraints
   capped at 150 N; rear on chassis, front on steering body). The
   heuristic was a *different dynamical system*; no tuning could match
   its phase portrait. Reverse fishtail = leading hard-gripping rear
   axle = unstable equilibrium — deleted by the very forward-gate hack
   added to stop flips.
3. **Faithful port:** constraint model reproduced in Box2D
   (SetMassData, effective-mass capped lateral impulses, 4 substeps).
   Step-probes confirmed the phase portrait: forward weathervane-
   stable, reverse fishtails.
4. **Residual regression:** ice felt like bitumen. Probe showed the cap
   (75 N) never exceeded — first hint the surface model was wrong.
5. **Human intervention #2:** "Treat the old app as an oracle; headless
   harness; millions of scenarios; accelerate time" — then "start
   small and study" and "not a tweak fest: use divergence data to
   understand the *source* divergence analytically."
6. **Differential harness (~90 min to build):** Chipmunk 6.2.1 compiled
   headless from the vendored 2013 source; old physics extracted
   verbatim (`oracle.cpp`); harness drives both with identical seeded
   gravity tapes; divergence percentiles at horizons {1,3,10,30,60,90}
   frames; `study <seed>` replay with paired state.
7. **First gradient hit:** replay's grip column showed `old=0/75
   new=0/0` — the original has **four treads (two per axle),
   subtracting per-tread**, giving three grip levels {150,75,0}; the
   port had collapsed them to two. A half-on axle still grips → old car
   rotates where new slid frozen. Structural fix; measured: 10-frame
   max divergence 36°→16°.
8. **Analytical decomposition of the residual:** per-step floor
   0.06°/frame (damper implemented as linear torque vs Chipmunk's
   `1−exp(−damping·dt·moment)` velocity operation, + solver coupling) —
   closable; exponential tail = Lyapunov chaos on an intentionally
   unstable system — unclosable, ever, across engines. Acceptance
   reframed: per-step epsilon + qualitative invariants.

Lessons encoded in the rules: 2 (veto→gradient), 3 (generative model),
4 (prose leaked twice even *after* full analysis: linear damper, two
treads), 5–7 (harness, Goodhart, Lyapunov), 8 (human contributed three
one-sentence methodology interventions; agent did all implementation).

## 7. Case studies: HMS and RustUML (brief)

- **HMS** (Delphi thick-client → web, healthcare): harness-dominated
  (tunnel-drive a Windows app; no prior art) + class-2/3 judgment at
  scale (hundreds of screens). Weeks-long autonomous porting ended in
  unverifiable "done" (false completion: "134/134"); resolution came
  oracle-side — DFM parser + Vision OCR as a conformance extractor +
  differential/adversarial sampling. The generalisation: capture the
  legacy reference as an *executable conformance spec*; route the
  perceptual residue through VLM-triage calibrated against human
  inspection history; the human sees only flagged screens.
- **RustUML** (PlantUML port): class-2 converted to class-1 by
  reverse-engineering the reference's generative model (layout
  algorithms, font metrics) — after which parity became geometric
  equality gated by ~12,500 golden pairs. The extraction ordeal *was*
  the oracle construction; it converts the problem permanently.
- **yourworld silhouette** (legacy GLES → yourworld2/sokol): pure
  class-2 spatial residual. Screenshot/VLM thrash failed because the
  error was multi-cause-looking and the control plane was not shared.
  Dual outer-loop render oracles (logical pose inject, live geometry
  read-back, world+viewport AABBs) compressed the residual; structural
  basis conversion + face-user alignment closed most of the gap without
  rewriting the obsolete draw path. Encodes rule 13 / §4 spatial
  residual compression — the geometry-shaped form of veto→gradient.

## 8. Strategy: the four moves

1. **Industrialise harness classes** (spyder as embodied substrate,
   service-deploy templates, capture+drive adapters). Distinguish
   one-off harnesses from recurring *classes*; classes earn reusable
   infra.
2. **Leave generation alone** — protect delegation; a pull toward
   codegen tooling usually signals a judgment cost misdiagnosed as a
   generation cost.
3. **Presentation infra** for friction — butler/ge-stream/jevons:
   agent drives, human glances. Correct role: acceptance gate for the
   class-3 residue, *not* a tuning loop.
4. **Oracle stack** for judgment — reference-comparison harness as a
   reusable service, TLA+ templates, perceptual-diff builders,
   invariants (sawmill), adversarial audit. Sequenced with autonomy:
   never raise unattended scope past oracle coverage.

Irreducible human floor: taste, design-under-uncertainty (retiring a
wrong conceptual model), risk/values acceptance, physical actuation,
and the stop-the-line call itself (every Goodhart catch on record was
human-initiated). That residue is the actual job; everything else is
industrialisable.

## 9. Caveats

The deep-dive (v2, 2026-07-03, all 34 repos) is directionally
well-evidenced: generation delegated; p tracks bottleneck delegability;
embodied verification irreducible; green-suite false assurance,
oracle-payback, and computed-completion findings carry file-level
evidence. Its *quantities* remain informed judgment, not arithmetic:
per-repo splits use inconsistent units, no human-minutes weights exist,
and p is partly circular on the assumed ~90 min/day budget. Audit
findings have a documented false-positive record — triage before
acting. Real but under-weighted patterns: rework/retraction churn,
agent overclaiming, third-party dependency opacity, N-way
implementation sync tax, meta-tooling self-drag (fleet infrastructure
consuming other repos' sessions), oracle depreciation, and
build-to-learn discards. Evidence base:
[`~/think/analysis/verification-strategy.md`](~/think/analysis/verification-strategy.md).

Corrections (2026-07-18 state-of-play research): verification-strategy
.md's counter-example row mislabels **nostalgia** as "visual-render, no
headless path" — nostalgia is a git-history TUI; the genuine
no-headless-path counter-examples are esfera2/yourworld2 device-level
3D fidelity and multimaze2's residual manual playthroughs. Two figures
cited in this file (yourworld2 AABB offset "~0.34 → ~0.05" in §4;
TiltBuggy "36°→16°" in §6) are directionally confirmed by repo files
but not file-anchored verbatim — likely session-log provenance; treat
as approximate.
