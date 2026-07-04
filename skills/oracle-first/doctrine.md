# Oracle-first doctrine

Distilled from an extended discussion (2026-06-30 → 2026-07-03) between
Marcelo and Claude on AI-assisted-development productivity, verification
economics, and porting fidelity, grounded in a 30-repo evidence
deep-dive and a live case study (TiltBuggy). Source of record: mnemo
session `1cf2248b` (in `~/think`); quantitative report:
[`~/think/analysis/verification-strategy.md`](~/think/analysis/verification-strategy.md);
business thesis built on this doctrine:
[`~/think/analysis/verified-migration-business.md`](~/think/analysis/verified-migration-business.md).

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

**Lyapunov-bounded acceptance.** For dynamical systems, measure
divergence as a function of horizon. Systematic per-step error grows
linearly and is closable analytically; chaotic amplification grows
exponentially and is unclosable across different engines. Acceptance =
per-step epsilon (measured floor) + distributional/qualitative
invariants beyond the chaos horizon (fishtail rate, slide distance,
turn direction). Bit-exact long-horizon cross-engine match is a
category error.

**Oracle work splits three ways.** *Design* — what to measure,
acceptance semantics, epistemic discipline — is design-under-
uncertainty and needs the human, but **once per oracle class** (it then
becomes a template). *Implementation* is fully delegable class-1 work.
*Extension* (tapes, invariants, coverage, scale) is safe unattended
work — the correct standing goal for idle agent capacity: **the machine
builds its own cage.**

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

**Unverified autonomy is negative value.** Work that can't be checked
is deferred, concentrated verification debt (the "ran for weeks — now
inspect 200 screens" trap). Oracles raise the autonomy ceiling;
presentation lowers the human floor; advance them in lockstep.

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
wrong conceptual model), risk/values acceptance, physical actuation.
That residue is the actual job; everything else is industrialisable.

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
