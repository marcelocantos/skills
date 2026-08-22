# Report contract

Use this structure for a durable full or comparison audit. Omit empty subsections rather than filling them with generic prose.

## Executive summary

- Snapshot: repository, branch, commit, dirty state, date.
- Scope and exclusions.
- Headline structural mechanism, not a score.
- Highest-consequence findings.
- What remains unverified.

## Dimension vector

Use `healthy`, `concern`, `critical`, or `unknown`, with a one-line evidence summary:

| Dimension | State | Evidence summary | Change from baseline |
|---|---|---|---|
| Architecture topology | | | |
| Redundancy / sources of truth | | | |
| Change amplification | | | |
| Local code quality | | | |
| Correctness / verification | | | |
| Security / dependencies | | | |
| Build / release / operations | | | |
| Documentation / governance | | | |

Do not aggregate these states into a scalar.

## Observed architecture

Describe entry points, major components, directional dependencies, public integration surfaces, cross-cutting concerns, and enforcement. Include a compact dependency diagram only when it materially clarifies the topology.

Separate:

- declared and observed rules that agree;
- observed rules inferred from code;
- contradictions;
- unknown intent requiring owner judgment.

## Findings

Use one record per actionable finding:

### ENT-NNN: Short mechanism-oriented title

- **Priority:** P0–P3
- **Dimensions:** affected vector dimensions
- **Status:** observed fact | inference | needs verification
- **Evidence:** file:line references, commands, raw metrics, relevant history
- **Mechanism:** how the shape causes drift, failure, or amplified change
- **Blast radius:** affected callers, components, data, or future changes
- **Counterevidence checked:** tests, docs, exceptions, generated ownership, compatibility constraints
- **Smallest coherent remediation:** design direction, not a sweeping rewrite
- **Verification:** check that would prove the remediation and fail on regression
- **Ratchet candidate:** CI job, command, scanner, file rule, architecture test, or manual attestation

Priorities:

- **P0:** current correctness, security, or data-integrity failure with broad or urgent impact.
- **P1:** structural mechanism causing repeated defects, major change amplification, or boundary failure.
- **P2:** localized maintainability cost with demonstrated drift or likely near-term impact.
- **P3:** observation, weak signal, accepted risk, or improvement opportunity not yet actionable.

## Healthy structure and deliberate exceptions

Record boundaries, single sources of truth, tests, architecture gates, or deliberate duplication that the audit tried and failed to invalidate. Cite the evidence.

## Hygiene posture

For full mode, include:

- whether `hygiene.yaml` exists;
- the validated per-dimension held tiers and floors;
- drift and planned/skipped gaps;
- overlap deduplicated against entropy findings;
- entropy findings suitable for future hygiene enforcement.

Do not fabricate this section when the `hygiene` skill did not run.

## Oracle coverage and residue

List each load-bearing property encountered and whether it is decided by the shipped path, an auxiliary oracle, manual/adversarial review, accepted risk, or nothing. State failed or skipped checks.

The owner-residue section must contain only questions that require architectural intent, risk acceptance, or taste. Do not hand back mechanical verification work.

## Remediation sequence

Order work by dependency and risk:

1. establish or repair the oracle/enforcement seam;
2. converge competing truths and boundary ownership;
3. remove duplication or residue only after consumers are proven migrated;
4. ratchet the accepted property in CI and, when requested, `hygiene.yaml`;
5. re-run the audit on the same definitions and compare.

Keep remediation local and incremental. Name architectural rewrites only when smaller boundary repairs cannot close the mechanism.

## Comparison appendix

For compare mode, report:

- baseline and current commit identities;
- identical scope/tool definitions or explicit differences;
- closed, new, reopened, and unchanged findings;
- metric movement from source-derived denominators;
- ratchet movement requiring deliberate acceptance;
- architecture changes that depreciated prior checks.
