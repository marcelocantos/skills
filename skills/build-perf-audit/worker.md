# /build-perf-audit Worker

Audit a build system for performance problems. Profile, identify
hotspots, match against known anti-patterns, propose or apply fixes,
and verify with before/after measurements.

## Output

A report with:
1. **Baseline** — clean build time, incremental build time, per-step breakdown
2. **Hotspots** — top 5-10 steps ranked by wall time × frequency
3. **Findings** — matched anti-patterns with severity, fix, risk, expected impact
4. **Applied changes** (if `--apply`) — what was changed, new timings, delta
5. **Leftover recommendations** — things not auto-applied, with rationale

Write the report to `docs/build-perf-YYYY-MM-DD.md`.

## Progress reporting

Emit phase headings on their own line followed by a blank line:

## Phase 0 — Discovery

## Phase 1 — Baseline

## Phase 2 — Hotspot analysis

## Phase 3 — Pattern matching

## Phase 4 — Proposal

## Phase 5 — Apply and verify

## Phase 6 — Report

## Workflow

### Phase 0 — Discovery

Identify the build system(s) in play. Look for:

| Marker | System | Pattern file |
|---|---|---|
| `Makefile`, `GNUmakefile` | make | `patterns/make.md` |
| `Cargo.toml` | cargo | `patterns/cargo.md` |
| `CMakeLists.txt` | cmake | `patterns/cmake.md` |
| `build.gradle`, `build.gradle.kts` | gradle | `patterns/gradle.md` |
| `*.xcodeproj`, `*.xcworkspace` | xcodebuild | `patterns/xcodebuild.md` |
| `go.mod` | go | `patterns/go.md` |
| `package.json` | npm/yarn/bun | `patterns/node.md` |
| `BUILD.bazel`, `WORKSPACE` | bazel | `patterns/bazel.md` |
| `Package.swift` | swiftpm | `patterns/swiftpm.md` |
| `pyproject.toml`, `setup.py` | python | `patterns/python.md` |
| `*.csproj`, `*.sln` | dotnet | `patterns/dotnet.md` |

A repo may have multiple (e.g. a CMake project wrapped in a Makefile, or
a Gradle Android app with native CMake modules). Profile the outermost
one the user actually runs unless they specify otherwise.

Also check for CI config (`.github/workflows/`, `.gitlab-ci.yml`,
`Jenkinsfile`) — CI wall time is often what the user cares about even
when they run builds locally. Note the CI job structure but don't try to
profile CI remotely; focus on the local build.

Read the relevant pattern file(s) from `~/.claude/skills/build-perf-audit/patterns/`.
If a pattern file doesn't exist for the detected system, proceed with
cross-cutting patterns only and note the gap in the report.

### Phase 1 — Baseline

Measure the build in three modes (skip any that don't apply):

1. **Clean build** — start from a clean state, full build. This is the
   worst case and the ceiling for improvement.
2. **No-op incremental** — build immediately after a successful build,
   with no file changes. Should ideally be near-zero; anything more
   than a few seconds is a red flag.
3. **One-file change incremental** — touch a single source file in a
   leaf module, rebuild. This is the common developer-loop case.

For each mode, capture:
- Total wall time
- Per-step / per-target timings if the build system exposes them
  (see pattern files for system-specific profiling flags)
- CPU utilisation (are we using all cores? `time` gives user/sys/real)

**Important**: run each measurement at least twice and take the second
run for incremental modes — the first run warms filesystem caches and
skews results. For clean builds, one run is fine; doing multiple clean
builds for averaging is rarely worth the time.

Record baseline in the report before making any changes. You will
compare against this later.

### Phase 2 — Hotspot analysis

Rank build steps by **wall time × frequency**. A step that takes 2s and
runs on every incremental build matters more than a 30s step that runs
only on clean builds.

Look for:
- **Serial bottlenecks** — single steps that dominate wall time and
  can't be parallelised because of the critical path
- **Broad triggers** — steps that run far more often than they should
  (every build instead of only when their inputs change)
- **Redundant work** — the same operation running multiple times
- **Wrong granularity** — single large target that should be split, or
  many tiny targets that should be batched

The per-system pattern files list specific profiling commands and what
their output looks like.

### Phase 3 — Pattern matching

For each hotspot, walk the pattern catalog and check detection
heuristics. Patterns are organised into two tiers:

**Cross-cutting** (apply to any build system) — see `patterns/common.md`:
- No/broken cache (ccache, sccache, build cache, Docker layers)
- Serial where parallel is safe
- Heavy tests in the hot path
- Debug info / LTO / sanitisers defaulting on in dev builds
- Overly broad file globs triggering world rebuilds
- Redundant codegen / linting passes
- Missing incremental mode (`clean` habits, CI doing `rm -rf`)
- Re-downloading dependencies on every run
- Monolithic targets that should be split

**System-specific** — see `patterns/<system>.md` for each detected
system. These include the exact profiling commands, output format, and
known traps for that ecosystem.

For each matched pattern, record:
- **Pattern name** and where it was detected (file:line)
- **Severity**: Critical (order-of-magnitude improvement possible), High
  (significant, e.g. 2x), Medium (20-50% improvement), Low (< 20%)
- **Risk**: how invasive the fix is and how likely to introduce
  correctness issues. Caching changes carry the highest risk.
- **Expected impact**: rough estimate based on measured hotspot size
- **Fix**: the specific change needed

### Phase 4 — Proposal

Present the findings to the user as a ranked list. Group by severity.
For each, show: pattern, location, expected impact, risk, proposed fix.

Ask which to apply. Default to applying **Low-risk** fixes
automatically if `--apply` was passed; always ask for Medium/High risk
regardless.

### Phase 5 — Apply and verify

For each approved fix:

1. **Apply** the change.
2. **Re-measure** in the same mode(s) as the baseline that the fix
   targets.
3. **Verify correctness** — this is the critical step. Any change that
   touches caching, dependency ordering, or build-step skipping MUST be
   verified:
   - Force a clean build and compare artifact hashes with the pre-change
     clean build (where stable), OR
   - Run the test suite and confirm it still passes, OR
   - For caching changes specifically: intentionally invalidate an
     input and confirm the cache correctly misses and rebuilds.
4. **Keep or revert** — if measurements improved and correctness checks
   pass, keep. Otherwise revert and note why in the report.

Never declare a caching change successful based on "it got faster"
alone. Faster + still correct is the bar. A silently broken cache is
worse than a slow build.

### Phase 6 — Report

Write `docs/build-perf-YYYY-MM-DD.md` with:

```
# Build performance audit — YYYY-MM-DD

## Summary
- Baseline clean: Xs → Ys (Z% improvement)
- Baseline incremental (no-op): Xs → Ys
- Baseline incremental (1 file): Xs → Ys

## Baseline
[per-step breakdown, hotspot ranking]

## Findings
[severity-grouped list of matched patterns]

## Applied
[changes made, with per-fix delta]

## Deferred
[proposed fixes not applied, with rationale]

## Method
[build system(s), profiling commands used, measurement notes]
```

Offer to commit.

If the repo uses bullseye, check whether any existing targets relate to
build performance and update them. If findings are significant and not
covered by a target, offer to create one (e.g. "🎯 CI clean build under
5 minutes").

## Rules

- **Never use destructive ops to "clean up"** — no `rm -rf build/` as a
  diagnostic; use the build system's clean command.
- **Never disable tests to make the build faster.** Moving tests off
  the hot path (out of the default target, into a separate CI job) is
  fine; deleting or skipping them is not.
- **Correctness trumps speed.** A 50% faster build with a broken cache
  is a regression, not an improvement.
- **Measure, don't guess.** Every claimed improvement must have
  before/after numbers. If you can't measure it, don't apply it.
- **Don't touch CI config speculatively.** CI changes are high-blast-
  radius (they affect everyone). Propose CI changes in the report; only
  apply with explicit user approval, never under `--apply`.
