---
name: hygiene
description: Declare and drift-validate a repo's steady-state hygiene posture (tests, security scans, code quality, governance, …) and aggregate coverage across the fleet. Use to check a repo's hygiene.yaml against reality, onboard a repo, or answer "is X covered in repo Z?" / "which repos lack X?".
user-invocable: true
---

# hygiene

A well-run codebase is one where every steady-state quality property is
**declared** as intent, **drift-validated** against reality so rot fails
loudly, and **fleet-aggregatable** so "which repos lack X?" is one query.
This skill is the tooling for that. bullseye tracks aspirational state
("achieve X"); hygiene tracks steady-state ("we maintain X").

Each repo declares its posture in a root `hygiene.yaml`. The validator
resolves every declared item against the repo's actual CI jobs, Makefile
targets, files, GitHub settings, and scanners — and fails on drift.

## Invocation

Both scripts are `uv`-run (pyyaml dep is inline); invoke the path directly
(do **not** wrap in `bash`/`python`):

- **`/hygiene`** — validate the current repo. Run from the repo root:
  ```
  ~/.claude/skills/hygiene/hygiene_check.py
  ```
  Add `--json` for machine output, or pass a path to a specific
  `hygiene.yaml`. Exit 1 ⇒ drift. Relay the report.

- **`/hygiene fleet`** — coverage matrix + gap rollup across `~/work`:
  ```
  ~/.claude/skills/hygiene/hygiene_portfolio.py
  ```
  `--root DIR` to scope elsewhere, `--json` for machine output.

- **`/hygiene init`** (or any repo lacking `hygiene.yaml`) — author one.
  Survey the repo's reality first (`.github/workflows/*.yml`, Makefile,
  LICENSE, scanners), then write `hygiene.yaml` per the schema below,
  grounding every `evidence` pointer in something that actually exists.
  Run the validator and iterate until it reflects the truth (gaps declared
  as `planned`/`skipped`, not hidden). Set each dimension's `floors` entry to
  the held tier it actually reaches, and park gaps above the floor in the
  `aspires` band — `/hygiene` will tell you if a floor overstates reality.

## hygiene.yaml schema

```yaml
schema_version: 1
repo: <name>
aspires: 3       # gap horizon: unmet items with tier <= aspires are reported
floors:          # PER-DIMENSION held-tier ratchet; a dim below floor => DRIFT
  correctness: 2
  security: 2
  quality: 2
  docs: 0        # 0 = no validated hygiene in this dimension yet (honest)
  # … one entry per dimension you commit to; omitted dims default to floor 0
tiers:           # the shared ladder (labels)
  1: baseline    # LICENSE + README + .gitignore; tests build & run
  2: maintained  # full matrix, examples run, lint/format, release + governance
  3: hardened    # formal specs, security scanning, SBOM/signing, fuzzing, perf
items:
  - id: <dim>.<slug>      # e.g. security.secret-scan
    dim: <dimension>      # see list below
    desc: <one-line intent>
    state: enforced       # enforced | present | manual | planned | skipped
    cadence: continuous   # continuous | per-release | periodic:<dur> | once-must-hold
    enforce: blocking     # blocking | warning | informational  (intent only)
    tier: 2               # tier at which this item is required, WITHIN its dimension
    reason: <text>        # REQUIRED for state: skipped or planned
    evidence: {<kind>: <value>}
```

**Held tier is per dimension.** For each dimension the validator derives the
held tier = the highest *T* such that every item in that dimension with
`tier <= T` is satisfied. A repo's posture is the **vector** of per-dimension
held tiers (the matrix headline), not a single score — repos have orthogonal
strengths (e.g. one strong on correctness, another on code quality). Put a
dimension's *gaps* (unmet `planned` items) at a tier **above** its floor, in
the `aspires` band; a gap parked at or below the floor reads as drift.

**Dimensions:** `correctness`, `security`, `quality`, `deps`, `release`,
`governance`, `build`, `docs`, `perf`, `vcs`, `agent`.

**`evidence` — one key, machine-checkable** (this is what makes drift
mechanical rather than prose):

| kind | resolves true when |
|---|---|
| `ci_job: wf.yml#jobid` (or `…#jobid:MatrixName`) | the job (matrix entry) exists |
| `ci_step: {workflow, name}` | a step with that name exists |
| `make_target: <name>` | a Makefile rule with that target exists |
| `file: {path, matches?}` | the file exists (+ optional content regex) |
| `gh_setting: {key, equals}` | `gh api repos/:owner/:repo .key` == equals |
| `scanner: {tool, config?, invoked?}` | config present **and** tool invoked in CI |
| `command: <argv>` | the command runs and exits 0 |
| `manual: {last_verified}` | attestation (no automated backing) |
| `absent: <evidence>` | the nested evidence does **not** resolve |

## Three principles that make this more than a checklist

1. **Negative space is first-class.** A deliberate gap (`state: skipped`)
   carries a required `reason` and an `absent:` evidence pointer the
   validator checks — so if a skipped thing silently starts running, the
   skip fails. `planned` marks a not-yet-closed gap honestly.
2. **Cadence + intent recorded.** Every item declares how often it should
   hold (`cadence`) and how loud its absence is meant to be (`enforce`).
   `enforce` is intent-only metadata — it documents severity but does **not**
   affect held tiers (an earlier blocking-only rule made tiers depend on
   author discretion; that was dropped).
3. **Per-dimension tiers + a ratchet.** Posture is a vector of per-dimension
   held tiers, not one number — repos have orthogonal strengths. `floors`
   pins the held tier each dimension must keep; if reality drops below a
   floor (a capability regressed, or a gap was parked too low), the check
   fails. That is the drift detector.

## Notes

- The validator is repo-agnostic (`check_repo(root)`), which is how the
  fleet aggregator reuses it. Could graduate to a bullseye-sibling MCP if
  cross-tool calls become useful.
- `gh_setting` evidence needs an authenticated `gh`; `command` evidence
  runs in the repo root — keep declared commands cheap and side-effect-free.
- Related: `/entropy-audit` (architecture, redundancy, SDLC-drift) invokes
  this skill in full mode. `/hygiene` stays a fast independent validator
  and must not invoke entropy-audit.
