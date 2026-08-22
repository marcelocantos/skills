---
name: entropy-audit
description: "Audit a whole repository or substantial code change for structural entropy: unclear top-level architecture, boundary violations, dependency cycles, redundant implementations, competing sources of truth, change amplification, dead code, needless abstraction, and broader SDLC drift. Use for deep code-quality reviews, architecture audits, technical-debt assessments, clean architecture or duplication concerns, modernization baselines, and periodic repository health reviews. By default run the entropy audit and then invoke the hygiene skill; use entropy-only to skip hygiene. Do not trigger for routine narrow PR review unless the user explicitly asks for architecture, redundancy, entropy, or repository-wide quality analysis. Use when the user runs /entropy-audit."
user-invocable: true
---

# Entropy Audit

Assess how difficult the repository is to understand, change safely, and keep coherent. Prefer evidence and enforceable invariants over aesthetic rules.

## Select the mode

- **full** (default): run the entropy audit, then invoke `hygiene` and combine the results.
- **entropy-only**: run the structural and code-quality audit without `hygiene`.
- **diff**: assess a branch, commit, or PR for newly introduced or removed entropy; run `hygiene` only when the change touches a declared hygiene mechanism or the user requests the full combination.
- **compare**: compare the current snapshot with a named prior commit or prior entropy report and distinguish improvement, regression, and unchanged residue.
- **hygiene-only**: delegate directly to the `hygiene` skill.

An invocation of `/entropy-audit` with no mode means **full**. The user does not need to name both skills. Keep the dependency one-way: `entropy-audit` invokes `hygiene`; `hygiene` remains a fast independent validator and must not invoke this skill.

## Preserve the audit boundary

- Keep production code unchanged unless the user separately asks for remediation.
- Write the audit report as the work product; do not silently install analyzers, change CI, or ratchet `hygiene.yaml`.
- Follow all applicable repository instructions and language-specific rules before analyzing or executing project commands.
- Treat generated, vendored, fixture, migration, and test code according to their actual role. Do not mix them into production-code conclusions without saying so.
- State excluded paths, failed commands, unavailable tools, and unreadable surfaces. Partial coverage must never become a whole-repository claim.

## Establish provenance and intent

1. Resolve the repository root, branch, HEAD commit, working-tree state, requested scope, and comparison baseline.
2. Read repository instructions, manifests, build files, CI definitions, architecture documents, ADRs, contributor guidance, and prior audit reports.
3. Inventory entry points, major subsystems, deployable units, data stores, generated boundaries, and public integration surfaces.
4. Separate **declared architecture** from **observed architecture**. Mark inferred intent and contradictions explicitly.
5. Read [references/audit-lenses.md](references/audit-lenses.md) before the analysis passes. Read [references/report-contract.md](references/report-contract.md) before writing findings.

## Run evidence-producing checks

Use the repository's declared commands and configured analyzers first. Then use already-available language-appropriate tools for dependency graphs, cycles, clone detection, dead code, complexity, coverage, static analysis, and git history. Do not add dependencies merely to obtain a metric.

For every executed check, record:

- exact command and tool version when available;
- scope and exclusions;
- exit status and relevant output;
- whether it exercises the shipped path or only an auxiliary/instrumented path;
- limitations that keep it from deciding the question.

Metrics are evidence locators, not verdicts. Do not treat method length, complexity, duplication percentage, coverage, or file size as a finding without tracing a concrete maintenance or correctness mechanism.

## Analyze in four structural passes

### 1. Top-level architecture

Map dependency direction, subsystem ownership, public APIs, cross-cutting concerns, cycles, high fan-in/fan-out hubs, layer leakage, and mismatches between declared and observed architecture. Evaluate the architecture the repository chose; do not impose a favorite pattern.

### 2. Redundancy and competing truths

Search for exact clones, near clones, semantic duplicates, parallel validators or schemas, repeated domain types, duplicated configuration, compatibility paths, and multiple authorities for the same state. Require evidence that the duplication can drift or multiplies change cost. Similar code serving independent concepts is not automatically a defect.

### 3. Change amplification and local quality

Use call sites and git history to find shotgun surgery, files that repeatedly change together, high-churn hubs, unstable public surfaces, dead paths, excessive indirection, needless configuration, and abstractions that obscure rather than isolate variation. Consider both under-abstraction and premature abstraction.

### 4. SDLC and verification posture

Assess correctness gates, test architecture, security, dependency health, build reproducibility, performance evidence, release safety, observability, documentation, ownership, and governance. Keep this pass concise when `hygiene` already decides the same property mechanically.

## Falsify findings before reporting them

For each candidate finding:

1. Read the complete relevant implementation, callers, tests, configuration, and applicable history.
2. Search for enforcement, generated ownership, compatibility constraints, or documented exceptions that may justify the shape.
3. State the concrete mechanism: what drifts, what changes together, which boundary is crossed, or which failure becomes more likely.
4. Identify affected users, subsystems, or future changes and estimate blast radius without inventing precision.
5. Drop findings that reduce to taste, a generic smell label, or an unsupported hypothetical.

Do not report only bad news. Record healthy boundaries, deliberate duplication, and existing enforcement that resisted the audit; these are part of the reusable baseline.

## Invoke hygiene in full mode

After the entropy passes:

1. Locate the available `hygiene` skill, read its complete `SKILL.md`, and follow its validation workflow.
2. If `hygiene.yaml` exists, validate it against repository reality and include the posture vector and drift findings.
3. If it is absent, record “hygiene posture not declared.” Do not initialize it unless the user asked to onboard or initialize hygiene.
4. Deduplicate overlap. Entropy findings explain structural mechanisms; hygiene findings decide whether declared steady-state controls still exist.
5. Propose machine-enforceable entropy findings as **ratchet candidates**. Modify `hygiene.yaml` only after explicit adoption, using a repository command, CI job, scanner, file rule, or manual attestation that actually decides the property.

If `hygiene` is unavailable, complete the entropy audit and declare the missing integration instead of simulating its result.

## Deliver the report

Use the repository's audit-report convention. Otherwise write `docs/audits/entropy-audit-YYYY-MM-DD.md` for a full or compare audit; keep a narrow diff review in chat unless the user asks for an artifact.

Follow [references/report-contract.md](references/report-contract.md). In particular:

- report a dimension vector, never a single entropy score;
- attach file-and-line evidence plus command evidence where applicable;
- distinguish observed fact, inference, and unknown;
- prioritize by consequence and change amplification, not smell counts;
- include oracle coverage, unverified residue, and ratchet candidates;
- cite the exact snapshot so a later run can compare like with like.

End with the smallest coherent remediation sequence. Do not apply it unless requested.
