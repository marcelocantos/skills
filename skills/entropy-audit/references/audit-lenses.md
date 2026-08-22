# Audit lenses

Use this reference to conduct the analysis. Adapt it to the repository rather than forcing every item onto every stack.

## 1. Architecture topology

Build a compact observed model:

- runtime and build entry points;
- deployable units, packages, modules, layers, and adapters;
- domain concepts and the modules that own them;
- public APIs, wire formats, database schemas, events, and plugin surfaces;
- dependency direction and forbidden or surprising edges;
- cycles and strongly connected components;
- high fan-in modules whose changes have broad blast radius;
- high fan-out modules that know too much;
- cross-cutting concerns such as auth, configuration, logging, errors, flags, and transactions;
- enforcement already present in tests, linters, build rules, or CI.

Compare the observed model with architecture docs and ADRs. Classify each important rule as enforced, convention-only, contradicted, inferred, or unknown.

Do not equate “clean architecture” with a prescribed folder layout. Look for stable responsibility ownership, directional dependencies, coherent public surfaces, local change, and explicit exceptions.

## 2. Redundancy

Inspect several kinds separately:

### Syntactic clones

Use an existing clone detector when configured or already available. Exclude generated, vendored, fixture, snapshot, and intentional protocol-copy paths. Inspect representative clones manually; clone counts alone are not findings.

### Semantic duplication

Search conceptually as well as textually for:

- validators enforcing the same rule differently;
- repeated DTOs, enums, schemas, error taxonomies, or feature definitions;
- two serialization or configuration paths for one concept;
- duplicate state derivation, caches, registries, or ownership tables;
- repeated orchestration with subtly different failure handling;
- parallel legacy/new paths after migration callers have converged;
- wrappers, factories, interfaces, or configuration switches with no live variation.

Report duplication only when at least one is true:

- instances represent one domain fact and can disagree;
- a bug fix or feature must be repeated;
- copies have already drifted;
- one established owner handles edge cases another copy misses;
- runtime state has more than one authority;
- compatibility residue has no remaining consumer.

Record deliberate duplication when coupling the instances would be worse.

## 3. Change amplification

Use history and references to locate:

- files that repeatedly change together;
- one feature requiring edits across unrelated layers;
- high-churn files with high dependency centrality or complexity;
- N-way implementations of a supposedly shared capability;
- public APIs with many unrelated consumers;
- broad configuration or feature-flag plumbing;
- schema changes that require manual synchronization;
- fragile order dependencies or global initialization.

Explain the next plausible change that would be amplified. “This is coupled” without a change scenario is weak evidence.

## 4. Local code quality

Check clarity, cohesion, error propagation, resource lifetime, concurrency, nullability, type safety, dead code, misleading comments, magic protocol values, nesting, branching, and unnecessary indirection.

Reject arbitrary universal thresholds. A long linear function can be clearer than many tiny helpers; repetition can be safer than a false abstraction. Use repository baselines, language idioms, call-site evidence, and actual defect/change mechanisms.

## 5. Correctness and verification

Inventory the properties the system relies on and map each to:

- an executable oracle on the shipped path;
- an auxiliary/instrumented oracle;
- an adversarial or manual audit;
- an explicit accepted risk;
- no known verification.

Check test distribution across unit, integration, contract, end-to-end, migration, concurrency, property, fuzz, performance, and recovery paths as applicable. Coverage percentage cannot substitute for load-bearing property coverage.

For a proposed architecture rule, identify a standing enforcement point. Prefer rules anchored to stable interfaces so they survive refactoring.

## 6. Wider SDLC

Inspect only what local or connected evidence can establish:

- dependency freshness, provenance, lockfiles, and vulnerability scanning;
- deterministic builds and generated-code verification;
- CI triggers, required gates, and matrix coverage;
- secrets, permissions, supply chain, and threat boundaries;
- performance budgets and regression checks;
- database migration, compatibility, rollout, and rollback discipline;
- observability, alerting, incident learning, and operational ownership;
- documentation accuracy and decision records;
- release provenance, signing, SBOM, and artifact retention;
- code ownership, review rules, and bus-factor risk.

Delegate declared steady-state validation to `hygiene` in full mode.

## Evidence hierarchy

Prefer, in order:

1. A repository check run against the current shipped path.
2. Source plus callers/tests demonstrating the mechanism.
3. A configured analyzer with inspectable raw output.
4. Git history showing co-change, drift, regression, or prior rationale.
5. Architecture documentation consistent with observed code.
6. Inference, labeled as inference.

Never use the audit's own finding inventory as its denominator or completion gate. Freeze accepted baselines deliberately, in both directions, and compare subsequent runs against the same definitions.

## Tool selection

Use tools already declared by the repository before generic tools. Useful categories include:

- semantic symbol/reference indexes for callers and public surfaces;
- import/dependency graph analyzers for cycles and forbidden edges;
- clone detectors such as jscpd for syntactic duplication;
- language-native linters, type checkers, dead-code tools, and coverage tools;
- architecture tests such as ArchUnit or repository-specific dependency rules;
- `git log`, blame, and co-change analysis for change amplification.

Do not install or configure a new analyzer during an audit without authorization. If an unavailable analyzer would materially improve confidence, list the exact proposed tool, question it would decide, cost, and expected residue.

## Method lineage

This workflow adapts audit practices from:

- OpenAI Codex specialist code-review skills: https://github.com/openai/codex/tree/main/.codex/skills
- Trail of Bits audit context building and differential review: https://github.com/trailofbits/skills
- GitHub `acquire-codebase-knowledge`, `doc-and-modernize`, and `refactor`: https://github.com/github/awesome-copilot/tree/main/skills
- Sentry code review, code simplification, and security review: https://github.com/getsentry/skills

The evidence, ratchet, and residue rules also follow the locally installed `oracle-first` and `hygiene` doctrines.
