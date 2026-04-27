---
name: release
description: Publish a release — version, release notes, CI, Homebrew tap, tag, and GitHub release.
user-invocable: true
---

# Publish a Release

End-to-end skill for cutting a release of an existing project. Covers discovery, versioning, release notes, CI workflow setup, Homebrew tap, tagging, and GitHub release creation.

## Locked-in decisions

- **GitHub account**: `marcelocantos` (personal)
- **Default branch**: `master`
- **Release platforms**: macOS arm64 + Linux x86_64 + Linux arm64
- **Binaries**: Always build via CI — never build release binaries locally
- **Homebrew tap**: `marcelocantos/homebrew-tap` — uses [homebrew-releaser](https://github.com/Justintime50/homebrew-releaser) GitHub Action for automated formula generation and publishing
- **Versioning**: Semantic versioning (`vMAJOR.MINOR.PATCH`). **Always suggest minor releases** (bump MINOR, reset PATCH to 0). Patch releases are reserved for hotfixes to a specific minor release — never use them for regular forward progress. Only use major/patch when the user explicitly requests it.
- **Tag ownership**: The release tag is created **once** by `gh release create` locally. CI workflows must **never** create tags or releases — they only build artifacts and upload them to the existing release.

## Invocation

The user runs `/release`. No arguments needed — the skill discovers everything from the repo.

## Workflow

`/release` runs in **three phases**. The ideal scenario is fully unattended from start to finish — only stop and ask the user when there is a genuine reason to.

1. **Phase A — Up-front clarification.** A very quick analysis to identify any information likely to be needed from the user *given the specific context of the work being released*. If nothing is genuinely uncertain, ask nothing and move straight to Phase B. Do not invent questions; do not ask out of habit. The default is zero questions.

2. **Phase B — Unattended execution to a mergeable PR.** Run the entire prep workflow without per-phase approval gates: discovery, stability/breaking-change audit, version bump, release notes, CI setup, push, PR open, CI wait, gate check, audit-log entry. End by reporting current state, anything messy that happened during the run, and any concerns. Then **only stop for confirmation if a serious concern arose** about whether it's appropriate to complete the release (failing tests rewritten without justification, a breaking change found, a stability gap, an unresolved CI failure, a missing licence attribution, etc.). If everything is clean, proceed to Phase C without asking.

3. **Phase C — Complete the release.** Squash-merge the release PR (and the audit-log-hash follow-up PR if used), tag, run `gh release create`, monitor CI, install locally, report.

The detailed substeps below are sequenced under these three phases. Where the previous workflow asked *"Proceed to Phase N+1?"* between substeps, that question is gone — substeps run back-to-back unless something in Phase B's concerns list fires.

### Phase A: Up-front clarification

Before doing any work, do a fast scan of the repo (latest tag, commits since, working-tree state, version era, project type) and decide whether any of the following are genuinely ambiguous:

- The desired version bump differs from the default minor (only ask if there's a concrete signal — e.g., user said "patch release" earlier, or commits clearly indicate breaking changes that warrant a fork rather than a bump).
- The release scope is unclear (e.g., uncommitted WIP unrelated to the release, or a pile of unpushed commits that may or may not be part of this release).
- A pre-1.0 → 1.0 transition is plausible and the user hasn't signalled intent.
- The release-workflow risk signal (`release_workflow_touched: yes` from `discover.sh`) suggests a prerelease dry-run might be wanted.
- An MCP-server or service definition gap is suspected and the user's preference (ship anyway / block) is unclear.

If **none** of these apply, ask nothing. Proceed to Phase B silently. The whole point is that asking is the exception, not the rule.

If something does apply, ask only the specific questions that matter, in one batch. Do not enumerate the full discovery report — the user already knows what they pushed.

### Phase B: Unattended execution

Run the substeps below back-to-back without approval gates. Only halt at the **end** of Phase B if a serious concern arose.

#### B.1: Discovery

Assess the project's current release state. **Start by running the companion discovery script:**

```
~/.claude/skills/release/discover.sh
```

(It is already `chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command.)

This script gathers all Phase 1 data **and** the inputs Phases 2 and 3 need (latest tag, commits since last tag, version era, STABILITY.md existence, build system, project type, CI workflows, Homebrew tap, repo description, version macros, vendored dependency licences, working tree status) in one invocation. Do **not** separately run `git tag`, `git log <last-tag>..HEAD`, or `gh release list` — the script already emits that data. Parse its output, then verify or supplement the following items as needed:

1. **Existing releases**: The script's `# tags`, `# latest_tag`, and `# releases` sections cover this. `# latest_tag` is the most recent semver tag — use it directly for subsequent phases.

2. **Build system**: Determine how the project builds — mkfile, Makefile, go build, cargo, cmake, etc. If the project has a `mkfile`, run `mk --help-agent` to get build instructions and understand the mk syntax. mk binaries are available from https://github.com/marcelocantos/mk. Check for a distribution generation target (e.g., `make dist`, `mk dist`) that produces release artifacts (amalgamated headers, bundled files, etc.) that are checked into the repo. Note the target name for Phase 5.

3. **Project type**: Determine whether the project produces standalone binaries or is a library/tool that users consume as source. This affects whether CI binaries and Homebrew tap are relevant.

4. **CI workflows**: Check for existing `.github/workflows/` files, especially any release-related workflows.

   **Default-branch CI status** — `discover.sh` reports the conclusion of the latest completed push run on the default branch as `# default_branch_ci_status` (format: `<conclusion>\t<workflow>\t<runId>\t<url>`). Read it before doing anything else in Phase 1, because it tells you whether you're starting from a healthy baseline or from a broken one:

   - `success` — proceed normally.
   - `failure` / `cancelled` / `timed_out` / `action_required` — **stop and triage**. The next push to the default branch (whether the release-prep PR or anything else) will inherit the same failures unless you address them. Pull the failing job log (`gh run view <runId> --log-failed | tail -60`), classify what broke, and decide:
     - **Code/test failure that the release-prep PR should also fix** (e.g., a test enforcing a constraint a recent commit removed): roll the fix into the release-prep PR alongside the STABILITY/audit-log/version changes. Mention it in the PR body so the reviewer sees the test was deliberately rewritten, not silently deleted.
     - **Infrastructure failure unrelated to the code** (e.g., a deploy step's auth token expired, a flaky third-party action): name it in the Phase B report and move on — but only after confirming the failing job is genuinely orthogonal to the release artifacts. A red `test` job is not infrastructure; a red `Deploy to Fly.io` job whose `needs:` doesn't gate artifact upload usually is.
     - **Pre-existing broken-test target that CI doesn't run** (e.g., a `swift test` failure when only `go test` is wired into CI): create a follow-up bullseye target for the fix, note it in the release-prep PR's "Known issues" / "Deferred" section, and proceed. Do **not** silently delete the broken tests as part of the release-prep PR — that's scope creep and obscures the regression.
   - `skipped` / `neutral` — read the job names; usually fine, but worth a glance.
   - `(no completed CI runs on <branch>)` — first-release-of-a-new-repo case. Proceed normally; CI will be exercised by the release-prep PR.

5. **Homebrew tap**: Check if `marcelocantos/homebrew-tap` exists and whether it already has a formula for this project. Also check that the **`HOMEBREW_TAP_TOKEN` action secret is set on this repo** — `discover.sh` reports this as `homebrew_tap_token_secret` (`set` / `missing`). homebrew-releaser reads this secret to push the generated formula into the tap; when it's missing, the job fails with the unhelpful error *"You must provide all necessary environment variables."* on the first release. First-release-of-a-new-repo is the common case — resolve it now from 1Password (see Phase 4 step 2 for the `op read` + `gh secret set` commands) rather than discovering it post-tag and having to re-run the failed homebrew-releaser job by hand.

   **Tap opt-out.** Some projects deliberately skip Homebrew distribution — e.g., a package manager that replaces Homebrew can't coherently ship via a tap. Opt out by adding a `homebrew_tap: disabled` directive to the project's `CLAUDE.md` (mirrors existing directives like `delivery:` and `profile:`). `discover.sh` honours the directive and reports `# homebrew_tap` as `(disabled — CLAUDE.md declares homebrew_tap: disabled)` and `# homebrew_tap_token_secret` as `(n/a — tap disabled)`. When you see either sentinel, skip the tap checks entirely, skip Phase 4 step 2 (homebrew-releaser job), and skip Phase 5 step 9 (local `brew install` verification). Note the opt-out in the Phase B report instead.

6. **Repo description**: Check that the GitHub repo has a description set (`gh repo view --json description`). homebrew-releaser crashes on null descriptions. If missing, set one with `gh repo edit --description "..."`. Also verify the description is **accurate and up to date** — stale descriptions (e.g., referencing renamed concepts) should be updated.

7. **CLI flags audit**: If the project produces standalone binaries, check that the following flags exist and work:

   - **`--version`**: Search the codebase for how the version string is set — hardcoded strings, constants, build-time injection (e.g., `-ldflags -X`, `#define VERSION`). Report whether it exists, where the string is defined, whether it matches the latest tag, and how it gets updated. The Homebrew formula `test` block relies on this.
   - **`--help`**: Verify the binary prints usage information. Most CLI frameworks provide this automatically.
   - **`--help-agent`**: Check whether the binary can emit its agent guide (e.g., `agents-guide.md` or `AGENTS-<PROJECT>.md`) for use by coding agents. The output should be prefixed with the `--help` usage text (flags and descriptions) so agents get both CLI reference and domain guide in one call. For Go programs, embed the guide with `go:embed` and capture `flag.PrintDefaults()` into a buffer to prepend it. For other languages, equivalent embedding or a bundled string constant.

   Flag any that are missing.

8. **Agent guide**: Check whether the project has an `agents-guide.md` (or equivalent). This applies to **all project types** — both standalone binaries and libraries:

   - **Libraries**: Must have `agents-guide.md` in the project root (or co-located with dist files if the library distributes as `dist/`). The guide should cover: what it does, how to include it, key API surface, common patterns, and gotchas. Flag if missing.
   - **Standalone binaries**: Should also have `agents-guide.md` as the source for `--help-agent` output (checked in step 7 above). If `--help-agent` exists but there's no standalone `agents-guide.md`, that's acceptable. If neither exists, flag both.

   Also verify that the README mentions the agent guide for discoverability (e.g., "If you use an agentic coding tool, include `agents-guide.md` in your project context").

   **Gotcha staleness check**: If the agent guide contains a "Gotchas" section (or equivalent list of known caveats), read each gotcha against the commits in this release. A release that *fixes* a behaviour previously described as a gotcha leaves a stale entry behind — future agents reading the guide will work around a problem that no longer exists, or worse, re-introduce it defensively. Look especially for commits whose messages mention parity fixes, removed workarounds, or "no longer needed" language. For each stale gotcha, either delete it, or rewrite it to reflect the new behaviour (e.g., a "was a hazard, now fixed" note if the historical context is useful). Flag any you find as a release-PR change rather than silently merging release notes over a stale guide.

   **MCP servers** (detected by MCP dependencies in the manifest, a `serve` subcommand, or "MCP" in the project description): The agents-guide and README must include complete installation instructions. The agents-guide must explicitly frame installation as a **multi-step process** and state that installation is not complete until all steps succeed — agents that see only `brew install` will stop there.

   Required steps (all must be documented):

   - Binary install command (e.g., `brew install marcelocantos/tap/<project>`)
   - **Service start command** (e.g., `brew services start <project>`) — if the server runs as a persistent daemon, a Homebrew service definition is required (see Phase 4 step 3). Flag if the project listens on a port but has no service definition.
   - Claude Code one-liner: `claude mcp add --scope user --transport http <name> http://localhost:<port>/mcp` (global install to `~/.claude.json`)
   - Generic MCP client JSON config block for other tools
   - Explicit note that the agent session must be restarted after registration
   - **Verification steps** — how to confirm the server is running:
     - Pre-restart: `lsof -iTCP:<port> -sTCP:LISTEN` to confirm the process is listening. Include an explicit warning **not to use `curl`** — MCP endpoints only respond to POST requests with a JSON-RPC body, so a plain GET or empty POST returns nothing, which agents misread as "server not ready" and enter unnecessary diagnostic loops.
     - Post-restart: call a lightweight MCP tool (e.g., a stats or ping tool) to confirm end-to-end integration.

   These instructions must be specific and exact — not vague pointers. Agents that lack precise commands will improvise incorrect paths (wrong config files, wrong scope flags, wrong binary names, plain HTTP health checks). Flag any missing or imprecise steps.

9. **README**: Check that a `README.md` (or `README`) exists in the repo root and covers the essentials: what the project is, how to install or build it, how to use it, and a licence mention. A missing README is a blocker — every public release needs one. Flag if missing or if key sections (install/build, usage) are absent.

   **Content freshness**: Compare the README's feature/syntax documentation against the current codebase (CLAUDE.md syntax section, agent guide, or equivalent authoritative source). Flag any features present in the agent guide or CLAUDE.md that are missing from the README. New features being released should be documented in the README before tagging.

   **Quick start for agent-installed tools**: If the project is an MCP server or agent tool, the README should include a "Quick start" section with a copy-pasteable prompt that users can give their agent (e.g., *"Install X from &lt;repo URL&gt; — brew install, start the service, register it as an MCP server, and restart the session. Follow the agents-guide.md in the repo."*). This is distinct from the agents-guide (which the agent reads) — it's for the human who wants to say "install this" without spelling out every step. A fenced code block is ideal since GitHub renders a copy button on them. Flag if missing.

10. **Third-party licence attribution**: Scan the project for vendored or bundled third-party code — check `vendor/`, `third_party/`, `extern/`, or similar directories, and any headers/sources copied into the project. For each dependency found:
   - Identify its licence (MIT, BSD, Apache 2.0, etc.)
   - Check whether the project includes proper attribution (a NOTICES, THIRD_PARTY, or equivalent file listing each dependency with its licence text or a reference to it)
   - Flag any missing attributions. These must be resolved before release — distributing code without required attribution is a licence violation.

   This check applies to all dependency types: vendored submodules, copied header-only libraries, embedded source files, and generated/bundled code.

11. **Language bindings / wrappers**: Check for language-specific bindings or wrappers in the repo (e.g., `go/`, `python/`, `wasm/`, or similar directories). If found, verify their test suites cover the features being released. Flag any new features that lack binding-level tests. Bindings that lag behind the core implementation should be updated before tagging.

12. **Working tree**: Verify the working tree is clean and up to date with the remote. If there are uncommitted changes or unpushed commits, flag them before proceeding. If the changes are unrelated WIP, the standard resolution is: `git stash push -u -m "WIP: ..."`, proceed with the release, then `git stash pop` at the end. Always restore the stash after the release completes.

    **Ahead-N handling** — when `discover.sh` reports `unpushed` ≥ 1 on the default branch (not a feature branch), the choice between "fast-forward push then PR for release-prep" vs "single bundled PR" depends on the repo's merge strategy. Read `# merge_strategy` from the discover.sh output:

    - **`merge-commit-allowed`** — fast-forward push the unpushed commits to origin first, then open the release PR containing only the release-prep commit(s). The unpushed commits' atomic history survives on master verbatim. Do this automatically; don't ask the user.
    - **`squash-only`** (the common case for owned repos under the global `~/.claude/CLAUDE.md` policy) — bundle the unpushed commits AND the release-prep commits into a single feature branch, open one PR, squash-merge to master. The squash collapses the per-commit history on master, but the per-commit detail is preserved on GitHub forever via the PR's commit list. Do not push to master directly; the global "always PR-flow" directive applies. Do this automatically; don't ask the user. Note the squash collapse in the Phase B report.
    - **`rebase-allowed`** (without merge-commit) — same as `squash-only`. Rebase-merge would preserve atomic history on master, but for the release skill's purposes the bundled PR is cleaner.
    - **`(gh api failed)` or `(gh not available...)`** — assume `squash-only` and proceed with the bundled PR. This is the safer default.

    If the fast-forward path is selected but **not practical** (origin has commits not in local master, i.e. `git push` would require a merge or rebase), fall back to the bundled PR. Note the collapse in the Phase B report.

    Do not use the two-PR variant (squash unpushed in one PR, release prep in another) under any merge strategy — same history loss as the bundled PR with double the CI churn, no upside.

    Resolve this before committing any release-prep changes so Phases 4–5 have a clean working tree to operate on.

13. **Release-workflow risk signal**: Read `# release_workflow_touched` and `# release_workflow_triggers` from the discover.sh output.

    When `release_workflow_touched` is `yes`, this release changes code paths that *only* run end-to-end when a real release is published — PR CI never exercises them. Prior incidents under this exact pattern required multiple tag-delete-and-retag cycles (mnemo v0.22.0 shipped after three iterations: MSYS path conversion, Inno Setup relative-path resolution, `[UninstallRun]` flag restriction — none of which could be caught without a real release event).

    In that case, **suggest a prerelease dry-run** before the real tag. One line in the Phase 1 summary, name the specific triggers so the user can judge the risk:

    > *"This release touches release-workflow logic (triggers: `release.yml`, `new-matrix-leg`, …) that hasn't run end-to-end yet. Consider cutting `v<X.Y.Z>-rc.1` as a prerelease via `gh release create --prerelease` first to validate before the real tag. Proceed with real tag anyway, or do rc.1 first?"*

    When `release_workflow_touched` is `no`, **say nothing** about prereleases — don't add noise to routine releases. The whole point of this check is that it only fires when there's a signal.

    If the user opts for a prerelease, run the whole Phase B/C flow against `v<X.Y.Z>-rc.1` with the `--prerelease` flag on `gh release create`. If the resulting release.yml run is green, delete the prerelease tag and re-run Phase C for the real tag. If red, iterate on the fix exactly as you would for the real release — but the real tag is never burned in the process.

Proceed straight to B.2 — no approval prompt.

#### B.2: Stability tracking (pre-1.0 projects only)

**Skip this substep** if discover.sh's `# version_era` reports `post-1.0`.

For pre-1.0 projects, create or update a `STABILITY.md` file in the repo root. This document tracks the project's readiness for a 1.0 release — the point at which backwards compatibility becomes a binding commitment.

**Key framing**: Once 1.0 ships, breaking changes require a major version bump. The purpose of this document is to ensure the project reaches 1.0 with an interaction surface (API, CLI, configuration, file formats, etc.) that is unlikely to need breaking changes in the foreseeable future.

**Document structure**:

1. **Stability commitment** — A brief statement that 1.0 represents a backwards-compatibility contract. After 1.0, breaking changes to the public API, CLI interface, configuration format, or wire/file formats require a major version bump. The pre-1.0 period exists to get these right.

2. **Interaction surface catalogue** — An exhaustive, diffable snapshot of every public-facing surface. This serves two purposes: pre-1.0, it tracks what needs to stabilise; post-1.0, it becomes the canonical baseline for the Phase 1.6 breaking change audit.

   For each surface category (API functions/types, CLI flags/subcommands, config file schemas, wire/file/output formats, etc.), list every public item concretely — function signatures, type definitions, flag names with their types and defaults, format schemas. This is not a prose description; it is a structured catalogue that can be mechanically diffed between releases.

   Pre-1.0, annotate each item with a stability assessment:
   - **Stable**: Unlikely to change. Design is settled and well-tested.
   - **Needs review**: Functional but may benefit from refinement before locking in.
   - **Fluid**: Actively evolving or known to need rework. Would be costly to freeze now.

   Be specific — name the functions, types, flags, or formats. Don't just say "the API is fluid"; say which parts and why.

   Post-1.0, drop the stability annotations (everything is implicitly stable — that's what 1.0 means) and maintain the catalogue purely as a surface snapshot. On each release, update it to reflect additions. Removals or signature changes should not appear — they would be caught by the Phase 1.6 audit.

3. **Gaps and prerequisites** — Concrete items that must be addressed before 1.0:
   - Missing features that users will expect from a stable release
   - Documentation gaps (undocumented public API, missing examples)
   - Known design issues that would require breaking changes to fix later
   - Dependency or packaging concerns (licensing, attribution, install targets)
   - Test coverage gaps in critical paths

4. **Out of scope for 1.0** — Features or changes explicitly deferred to post-1.0. This prevents scope creep and sets expectations.

**When creating** the document for the first time, perform a thorough audit of the codebase (read the public headers/API, CLI entry points, documentation, and tests) to populate each section. For large API surfaces (many public headers, dozens of combinators/functions), use parallel research agents to audit different surface areas concurrently — this phase can be context-intensive. Present the draft to the user for review.

**When updating** an existing `STABILITY.md` (pre-1.0), review each section against the current release's changes. Move completed items out, add newly discovered gaps, and update stability assessments. If items have moved from "Fluid" to "Stable", note that. Update the surface catalogue to match the current codebase. Present the diff to the user.

**Post-1.0 maintenance**: `STABILITY.md` survives into the post-1.0 era. The stability commitment and gap sections can be removed (they've served their purpose), but the **interaction surface catalogue must be maintained** on every release. It becomes the authoritative baseline for the Phase 1.6 breaking change audit. After a successful audit, update the catalogue with any additive changes and commit it as part of the release.

**1.0 readiness check**: After updating `STABILITY.md`, assess whether the project is ready to release 1.0. Two conditions must **both** be met:

1. **Checklist clear**: No remaining gaps, no "Fluid" items in the surface catalogue, documentation complete.
2. **Settling threshold met**: The settling threshold is purely time-based —
   new releases don't accelerate it, because new code is inherently
   destabilising. Count every public function, type, enum, constant, wire
   format, and config field in the surface catalogue, then look up the
   minimum settling period:

   | Surface items | Minimum settling period |
   |---|---|
   | < 20 | 1 month |
   | 20–50 | 2 months |
   | 50–100 | 3 months |
   | > 100 | 4 months |

   The clock starts from the last breaking change to the interaction surface.

If both conditions are met, flag it to the user: "the checklist is clear and the settling threshold is met — the project is eligible for 1.0." The user decides — this is never automatic. If only the checklist is clear but the settling threshold is not, report which condition is unmet and how far away it is.

If the project validates documentation during build (e.g., markdown link checkers), verify the build still passes after adding or updating `STABILITY.md`.

Commit and push the `STABILITY.md` changes, then proceed to B.4 (the breaking-change audit doesn't apply pre-1.0).

#### B.3: Breaking change audit (post-1.0 projects only)

**Skip this substep** if discover.sh's `# version_era` reports `pre-1.0`.

For post-1.0 projects, audit all changes since the last release for backwards-incompatible changes. This is a **hard gate** — if breaking changes are found, the release **must not proceed**.

**What constitutes a breaking change:**
- Removing or renaming public API functions, types, methods, or fields
- Changing function signatures (parameter types, return types, parameter order)
- Changing the semantic behaviour of existing functions in ways that break callers
- Removing or renaming CLI flags/subcommands
- Changing configuration file format in non-additive ways
- Changing wire/file/output formats that existing consumers depend on
- Removing or narrowing enum variants, error types, or other extensible constructs
- Tightening input validation that previously accepted valid input

**Audit procedure:**

1. **Diff the surface catalogue**: Read `STABILITY.md`'s interaction surface catalogue (the canonical baseline from the last release). Compare it against the current codebase — public headers, exported symbols, CLI entry points, config schemas. Use `git diff <last-tag>..HEAD` on the relevant files to identify changes. Every item in the catalogue must still exist with the same signature and semantics.

2. **Classify each change** as additive (new functions, new optional fields, new CLI flags) or breaking (anything listed above). Additive changes are fine for a minor release. Update the `STABILITY.md` catalogue to include additions.

3. **If no breaking changes found**: Report the audit results, commit the updated `STABILITY.md` catalogue, and proceed to B.4.

4. **If breaking changes found**: This is a **serious concern** that halts Phase B. Report each breaking change with specific file:line references, showing what changed relative to the `STABILITY.md` catalogue. Explain that post-1.0 breaking changes are not permitted as a minor or patch release.

   **The project's stance on breaking changes is absolute**: there is no "v2.0" of the same product. If a project genuinely needs to break backwards compatibility, the correct path is to **fork the project into a new product**. For example, `foo` would become `foo2` — a new repository (or a hard fork of the existing one) starting at `v0.1.0` with its own pre-1.0 stabilisation cycle. The original `foo` continues to exist at its last stable version for existing users.

   This policy exists because major version bumps within the same product create ecosystem fragmentation, dependency hell, and migration burdens. A clean fork makes the break explicit and lets both versions coexist without conflict.

   Present this recommendation to the user and halt Phase B. Do not proceed with the release.

#### B.4: Version

Determine the next version number. **Do not ask for confirmation** — just use the version determined below.

1. **Changes since last release**: Use the `# commits_since_last_tag` output already produced by discover.sh — do not re-run `git log`. Summarise the changes.

2. **Determine version**: If `# latest_tag` is `(none)`, use `v0.1.0`. Otherwise, bump MINOR and reset PATCH to 0 (e.g., `v0.1.0` → `v0.2.0`, `v1.3.0` → `v1.4.0`). Only use a different bump if the user explicitly requested one.

3. **Update version string**: If the project has a hardcoded version string (found in Phase 1 step 7), update it to match the new version. Commit the change before proceeding. If the version is injected at build time (e.g., via `-ldflags` or CI env vars), verify the injection mechanism uses the tag correctly and no manual update is needed.

   **C/C++ libraries with version macros**: If the header defines version macros (e.g., `#define PROJECTNAME_VERSION "x.y.z"` with `_MAJOR`, `_MINOR`, `_PATCH` companions), update all four macros to match the new version. Verify consistency: the string must equal `"MAJOR.MINOR.PATCH"`.

   **STABILITY.md catalogue**: If `STABILITY.md` lists version macro values in its interaction surface catalogue, update those to match the new version too. Also update the "Snapshot as of" line to reference the new version.

   **Go module version constants**: If the project has Go wrapper modules with
   version constants (e.g., `Version = "x.y.z"` with `VersionMajor`,
   `VersionMinor`, `VersionPatch`), update them to match the new version.

   **Top-level package `Version` constant**: Some Go libraries expose a
   single top-level `const Version = "x.y.z"` (typically in a small
   `version.go` at the repo root) so consumers can report the library
   version at runtime. Detect with
   `grep -l '^const Version = ' *.go 2>/dev/null` at the repo root —
   if a match exists, update the quoted string value to the new version
   with the leading `v` stripped (e.g., `v0.10.0` → `"0.10.0"`). The
   tag itself keeps the `v` prefix; only the constant drops it.

   **No version macros found**: If a C/C++ library has no version macros at all, note this as a gap. For pre-1.0 projects, record it in `STABILITY.md` under gaps/prerequisites. Don't block the release — version macros are a 1.0 prerequisite, not a pre-1.0 gate.

#### B.5: Release notes

Draft release notes from git history.

1. **Gather material**: Use the `# commits_since_last_tag` output from discover.sh — do not re-run `git log`. Read the commit subjects (and look up merged PRs if needed).

2. **Draft**: Write concise release notes. Group changes by category where natural:
   - Added (new features)
   - Changed (modifications to existing behaviour)
   - Fixed (bug fixes)
   - Removed (deprecated features removed)

   Don't force categories — if there are only a few changes, a simple bullet list is fine.

3. **Display**: Print the draft release notes in the transcript so the user can see them. Do not wait for approval — proceed immediately. (The `changelog-reviewed` gate is automated, not manual.)

#### B.6: CI setup (conditional)

**Skip this substep** if the project is a library without standalone binaries, or if a release CI workflow already exists and is working.

1. **Create release workflow**: Create `.github/workflows/release.yml` that triggers on `release` events (`types: [published]`). The workflow must **only build and upload artifacts** — it must **never create tags, releases, or draft releases** (the release already exists, created by `gh release create` in Phase 5). The workflow should:
   - Run tests
   - Build for macOS arm64, Linux x86_64, Linux arm64 using a matrix strategy
   - Package each binary as `<project>-<version>-<os>-<arch>.tar.gz`
   - Upload tarballs to the **existing** release with `gh release upload`

   **Cross-platform builds with CGO**: When the project requires CGO (e.g., for SQLite via `go-sqlite3`), cross-compilation is painful. Prefer **native ARM runners** (`ubuntu-24.04-arm`) for linux-arm64 builds over installing a cross-compiler (`gcc-aarch64-linux-gnu`). Native runners are simpler and more reliable. Use `runs-on: ${{ matrix.os }}` with per-target runner entries in the matrix. macOS arm64 builds on `macos-latest` (Apple Silicon) natively.

   **Generated/embedded files**: If the Makefile has copy or generate steps that feed `go:embed` (or similar compile-time embedding), CI must replicate those steps before building. For example, if the Makefile copies `agents-guide.md` to `internal/cli/help_agent.md` for `go:embed`, add an explicit step in the workflow (e.g., `cp agents-guide.md internal/cli/help_agent.md`) before the build step. Check for Makefile prerequisites of the `build` target that produce files listed in `.gitignore` — these are generated files that CI won't have.

   **mk-based projects**: If the project uses `mkfile` instead of `Makefile`, CI must install mk before building. Fetch the appropriate binary from `https://github.com/marcelocantos/mk/releases`. Example step:
   ```yaml
   - name: Install mk
     run: |
       MK_VERSION=$(gh release view --repo marcelocantos/mk --json tagName -q .tagName)
       curl -sL "https://github.com/marcelocantos/mk/releases/download/${MK_VERSION}/mk-${MK_VERSION#v}-linux-amd64.tar.gz" | tar xz -C /usr/local/bin mk
     env:
       GH_TOKEN: ${{ github.token }}
   ```
   Adjust the OS/arch in the tarball name to match the runner. Use `mk` instead of `make` in all build and test steps.

2. **Add homebrew-releaser job**: Add a job that runs after binaries are uploaded, using [homebrew-releaser](https://github.com/Justintime50/homebrew-releaser):

   ```yaml
   homebrew:
     needs: build  # wait for binary uploads
     runs-on: ubuntu-latest
     steps:
       - uses: Justintime50/homebrew-releaser@v3
         with:
           homebrew_owner: marcelocantos
           homebrew_tap: homebrew-tap
           github_token: ${{ secrets.HOMEBREW_TAP_TOKEN }}
           formula_folder: Formula
           version: ${{ github.event.release.tag_name }}
           install: 'bin.install "<project>" => "<project>"'
           target_darwin_arm64: true
           target_linux_amd64: true
           target_linux_arm64: true
           test: 'system bin/"<project>", "--version"'
           skip_checksum: true
           update_readme_table: true
   ```

   Key setup requirements:
   - **`HOMEBREW_TAP_TOKEN` secret**: A shared PAT for all repos is stored in 1Password. To add it to a new repo:
     1. Retrieve the token: `op read "op://Personal/GitHub Homebrew Tap PAT/token"`
     2. Set the secret: `gh secret set HOMEBREW_TAP_TOKEN --repo <owner>/<repo>` and paste the token value.
   - The `homebrew-tap` repo must exist at `marcelocantos/homebrew-tap` with a `Formula/` directory.
   - Binary tarballs must follow the naming convention `<project>-<version>-<os>-<arch>.tar.gz` where `<version>` has **no `v` prefix** (e.g., `myapp-1.2.0-darwin-arm64.tar.gz`). homebrew-releaser strips the `v` from the tag when searching for assets.
   - The `install` and `test` fields must match the project's actual binary name and CLI interface.
   - Add `depends_on` if the binary needs runtime dependencies.

   **Known homebrew-releaser issues:**
   - **`skip_checksum: true` is required** when `HOMEBREW_TAP_TOKEN` is scoped to the tap repo only. Without it, homebrew-releaser tries to upload `checksum.txt` to the source repo's release and gets a 403.
   - **The GitHub repo must have a description set.** homebrew-releaser crashes (`TypeError: 'NoneType' object is not subscriptable`) if the repo description is null. Set it with `gh repo edit --description "..."` before the first release.
   - **Formula description truncation.** homebrew-releaser truncates the repo description to fit Homebrew's field limit (~80 chars). Keep repo descriptions concise to avoid mid-word cutoffs.
   - **Version detection from arch-specific URLs.** Without an explicit `version` input, homebrew-releaser auto-detects the version from download URLs. Platform-specific URLs like `foo-1.0.0-darwin-arm64.tar.gz` can confuse the parser — it may extract "64" from "arm64" instead of "1.0.0". Always set `version: ${{ github.event.release.tag_name }}` to override auto-detection.

3. **Homebrew service definition** (conditional — persistent servers only): If the project is a long-running server (detected by: listening on a port, `--addr` flag, `serve` subcommand, MCP server), the Homebrew formula needs a service definition so `brew services start <project>` works. There are two approaches:

   - **`formula_includes`** in homebrew-releaser: Add a `formula_includes` field with a Ruby `service` block that configures launchd (macOS) and systemd (Linux). Example:
     ```yaml
     formula_includes: |
       service do
         run [opt_bin/"<project>"]
         keep_alive true
         log_path var/"log/<project>.log"
         error_log_path var/"log/<project>.log"
       end
     ```
   - **Manual formula edit**: If homebrew-releaser doesn't support the needed service options, edit the formula in `marcelocantos/homebrew-tap` directly after the first release.

   The agents-guide should document both macOS (`brew services start`) and Linux (`systemd --user` unit file) setup. Flag if the project is a persistent server but has no service definition.

4. **Verify**: Show the workflow file to the user for review. Commit it to `master` and push before tagging.

#### B.7: Gate check

Enforce the project's delivery gates before releasing.

1. Read the project's `## Gates` section from CLAUDE.md to determine the
   profile (default: `base`).
2. Read `~/.claude/gates/base.yaml` and the profile YAML (if not base).
   Merge them: profile gates add to base; `override: [gate: skip]`
   removes specific base gates.
3. Check each `pre-release` gate (in addition to any `pre-merge` gates
   that haven't already been satisfied):
   - **automated**: Verify the condition. Report pass/fail.
   - **routed**: Delegate to the named skill.
   - **manual**: A `manual` gate is a **serious concern** in the Phase B sense — surface it in the Phase B report at the end of execution rather than stopping mid-stream. Do not present its prompt as an in-flight blocker.
4. If any **automated** gate fails, that's a serious concern — surface it in the Phase B report.

**Run env-gated live tests as part of the `tests-exist` check.** Many
projects gate expensive or API-costing tests behind an environment
variable (`CLAUDIA_LIVE=1`, `RUN_LIVE_TESTS=1`, etc.) so they don't
run during routine local development or in contributor CI. These
tests are the exact ones that exercise the user-facing flow —
skipping them at the release gate defeats the whole point of gating
them separately. When running the test suite to verify
`tests-exist`, inspect the project for such env var conventions
(grep `t.Skip.*Getenv\|os.Getenv.*== ""` in `_test.go` files, or
check README/CONTRIBUTING for a "how to run live tests" section) and
re-run the suite with those variables set. Do not rely on the
default `go test ./...` / `cargo test` / equivalent to exercise
API-costing tests — its silence on those tests is by design, and
also silent about whether the user-facing flow works.

If no such gating convention exists, the default run is sufficient.
If the project has a specific command for live tests (e.g., a
Makefile target like `make test-live`), prefer that over
reconstructing the env vars by hand.

This check is part of the `tests-exist` gate in spirit even if the
gate yaml doesn't mention it explicitly. A "tests exist" pass that
only ran the non-live subset leaves the user-facing flow unverified
and is not sufficient for a release.

**Expect two PRs.** The `pr-workflow` pre-merge gate means release-skill work routes through a feature branch and PR, not a direct push to master. Combined with the audit-log chicken-and-egg (see **Audit log** section below), the typical release flow produces **two sequential PRs**:

1. **Release PR** — version bump, STABILITY.md updates, doc changes, and the audit-log entry with `Commit: pending`. CI must go green before squash-merge.
2. **Audit-log-hash PR** — a tiny docs-only follow-up that rewrites `pending` to the real merge-commit hash from PR #1. Also requires CI green before merge, then tag from the resulting master commit.

This is by design. Note it in the Phase B end-of-run report so the user knows the second PR is coming. If the project has no CI, the `pr-workflow` gate still applies — you still need to go through a PR, but CI waits are zero.

**Always squash-merge release PRs via `~/.claude/skills/push/merge.sh`, never via raw `gh pr merge`.** After a squash-merge, local master has N pre-squash commits while origin/master has one squash commit with a different SHA — `git pull` fails to fast-forward, `rebase` re-applies already-merged content, and `merge` would create a merge commit (forbidden under squash-only). The only safe resolution is `git reset --hard origin/master`, which is normally a user-only operation. `merge.sh` bundles the squash-merge, the fetch, the checkout, the hard reset, and the local feature-branch cleanup into a single vetted script — pre-authorising the reset by virtue of being a known script. Invoke as:

```
~/.claude/skills/push/merge.sh <pr-number> master <feature-branch>
```

Calling `gh pr merge --squash` directly leaves the user staring at a diverged local master with no clean recovery — they have to run `git reset --hard origin/master` by hand every time. That is the bug `merge.sh` exists to prevent. Do this for both the release PR and the audit-log-hash PR.

#### B.8: End-of-Phase-B report and decision point

After CI is green on the release PR, produce a brief report covering:

- Version selected and version-string updates applied.
- PR URL, CI status, gate results.
- Any messiness encountered during the run: rewritten tests, deferred items, infrastructure failures triaged, dist regen results, stash/restore, etc.
- The two-PR plan (release PR → audit-log-hash PR) if applicable.

Then **decide whether to proceed unattended**. Default is **yes — proceed straight into Phase C without asking**. Only stop and ask if a *serious concern* arose during Phase B that warrants user review before crossing the merge-to-master line:

- Breaking change found post-1.0 (already halted in B.3).
- Tests were rewritten in a way that suggests a regression rather than a deliberate change.
- A licence-attribution gap that wasn't resolvable automatically.
- A `manual` pre-merge or pre-release gate fired (surface its prompt now).
- An unresolved CI failure or an infrastructure failure that overlaps the release artifacts.
- The release-workflow risk signal fired and a prerelease dry-run was indicated.
- STABILITY.md "Fluid" items remain that the user might want to settle first.

Routine items are **not** serious concerns: a clean changelog display, a successful dist regen, a normal version bump, a `--prerelease` flag set per user request, expected two-PR flow, etc. Don't ask just to confirm something the user already implicitly authorised by running `/release`.

If the report shows no serious concerns: print the report, say *"proceeding to Phase C"*, and continue.

If a serious concern fires: print the report with the concern called out at the top and ask one focused question (*"merge anyway, or stop here?"*).

### Phase C: Complete the release

Squash-merge the prepared PR(s), tag, and create the GitHub release. Run unattended unless something fails along the way.

1. **Squash-merge the release PR(s)** via `~/.claude/skills/push/merge.sh <pr-number> master <feature-branch>`. If the project uses the audit-log placeholder pattern, open the audit-log-hash follow-up PR, wait for CI green, and squash-merge it the same way.

2. **Validate version strings**: Before tagging, verify that any in-source version strings match the release version. For C/C++ projects with version macros, check that the `#define` values match the tag (strip leading `v`). Fail early if they don't — the version commit from B.4 should have already handled this, but double-check.

3. **Push**: Ensure all commits (version bump, STABILITY.md updates, etc.) are on `master` before tagging. After the squash-merge in step 1, `merge.sh` already left the local `master` aligned with `origin/master`; double-check.

4. **Regenerate distribution files**: If B.1 identified a dist generation target (e.g., `make dist`), run it now. If it produces any changes, commit them on `master` (e.g., "Regenerate dist for \<version\>") and push before tagging. This ensures the release tag includes up-to-date distribution artifacts.

5. **Create the release**: Use `gh release create` which both tags and creates the release:
   ```bash
   gh release create <version> --title "<version>" --notes-file <notes-file>
   ```
   This triggers the `release.yml` workflow, which builds binaries, uploads them, and (if configured) runs homebrew-releaser to update the tap formula automatically.

6. **Sync local tags with the remote**: `gh release create` creates the
   tag on the remote but does **not** update the local `.git/refs/tags/`.
   Any tool that reads local tags immediately after a release (another
   `/cv` run, a manual `git describe`, a subagent spawned for follow-up
   work) will see the previous tag as the latest, re-detect the
   already-shipped commits as unreleased, and potentially recommend
   shipping them again. Close the gap here:
   ```bash
   git fetch --tags
   ```
   This is a git-protocol round-trip, not a `gh` API call — fast and
   cheap. Run it unconditionally after every `gh release create`. The
   downstream invariant this enforces is: *"after /release returns,
   local tags reflect reality."* Several other skills (notably `/cv`'s
   Step 0.5 "unreleased fixes" check) rely on that invariant holding
   and explicitly do **not** call `gh` for latency reasons, so it must
   be the release skill that keeps local state in sync.

7. **Go module tags**: If the project contains Go modules in subdirectories
   (e.g., `go/sqlpipe/go.mod`), create subdirectory-prefixed tags for each
   Go module so that `go get` can resolve them. For a module at path
   `go/sqlpipe` and release version `v0.11.0`, create and push:
   ```bash
   git tag go/sqlpipe/<version> <version>
   git push origin go/sqlpipe/<version>
   ```
   Also update the Go module's version constants (if any) to match the
   release version during the Phase 2 version bump.

8. **Monitor CI**: Wait for the release workflow to complete:
   ```bash
   gh run list --workflow=release.yml --limit=1
   gh run watch <run-id>
   ```
   If it fails, help diagnose — do not delete the release or tag without asking.

9. **Verify**: Confirm:
   - The release appears on GitHub with correct notes and artifacts
   - Binary tarballs are attached for each platform
   - The Homebrew formula was updated in `marcelocantos/homebrew-tap` (check the tap repo's recent commits). If the workflow includes a homebrew-releaser job, wait for it to finish (`gh run watch`) before proceeding — the tap commit must exist before the local install in step 9 will pick up the new version.

10. **Install locally**: Install the released version onto the laptop so the user can use it immediately. This step is **mandatory** for projects with a Homebrew tap — do not skip it and do not ask for permission.

   ```bash
   brew update
   brew upgrade marcelocantos/tap/<project> || brew install marcelocantos/tap/<project>
   ```

   `brew update` is required to pull the fresh formula from the tap — without it, Homebrew uses its cached copy and reinstalls the previous version. Use `upgrade || install` so the command works whether or not the formula is already installed.

   **Persistent services**: If the project is a long-running server with a Homebrew service definition (detected in Phase 4 step 3), restart the service so the new binary takes effect:
   ```bash
   brew services restart <project>
   ```

   **Verify the install**: Run `<project> --version` (or the equivalent) and confirm the output matches the released version. If it doesn't match, diagnose — common causes are a stale `brew update`, a PATH shadowing issue, or the homebrew-releaser job not having completed.

   **Non-Homebrew projects**: If the project has no Homebrew tap (e.g., a library, or a binary distributed another way), skip this step and note it in the Phase B report.

11. **Report**: Print:
    - Release URL
    - Homebrew install command (if tap was set up): `brew install marcelocantos/tap/<project>`
    - Confirmation that the new version is installed locally (include the `--version` output)

12. **Retire the release-readiness target and clean the tree**: If the
    project uses bullseye and the release was driven by a
    release-readiness target, retire it now via `bullseye_retire`. Then
    run `~/.claude/skills/release/finalize.sh <version> [target-id]` to
    commit any resulting `bullseye.yaml` diff locally (no push). This
    enforces the invariant *"after /release returns, `bullseye.yaml` is
    clean"* — `/cv` and other gates rely on it.

## Audit log

Append an entry to `docs/audit-log.md` as part of the release-prep commits (create the file with the standard header if it doesn't exist — see `~/.claude/skills/audit-log-convention.md` for the format).

The entry should include the version released, platforms, and any issues noted. Example:

```markdown
## 2026-02-28 — /release v0.2.0

- **Commit**: `a1b2c3d`
- **Outcome**: Released v0.2.0 (darwin-arm64, linux-amd64, linux-arm64). Homebrew formula updated.
```

**The commit hash chicken-and-egg.** The `Commit` field wants the final merge commit hash on master, but squash-merging a PR produces that hash *after* the PR merges — which is after the audit-log commit has already been made. Two accepted approaches:

1. **Placeholder + follow-up PR** (current pattern for this workflow). Write the audit log entry with `Commit: pending` in the release PR, let it merge, then open a tiny docs-only follow-up PR that rewrites `pending` to the real merge commit hash. Merge that second PR before tagging. This is how v0.7.0 and v0.8.0 of bullseye were done.

2. **Record the PR number instead**. Change the convention to `PR: #123` and drop the commit hash. The PR number is known at commit time, so no follow-up is needed. Trade-off: PR numbers are less useful than commit hashes for `git show` / blame lookups, but they round-trip through GitHub links.

Either is fine; pick one per-project and stick with it. The skill currently assumes approach 1.

**Skip this step** if invoked as part of another skill (e.g., `/open-source`) — the parent skill will log a summary entry.

## Error handling

- If `gh` CLI is not installed or not authenticated, tell the user and stop.
- If the working tree is dirty, ask the user to commit or stash before proceeding.
- If CI workflow fails after tagging, help diagnose — do not delete the tag without asking.
- Never force-push or rewrite history.
- Run the entire skill unattended unless a serious concern arose during Phase B (see B.8). The ideal `/release` invocation finishes without asking the user a single question. Per-phase approval prompts are gone — do not reintroduce them.

## Commit messages under MCP-mediated executors

When running `git commit` through an MCP-mediated executor (e.g. `doit_execute`, or any tool that ultimately runs the command through a single-line `sh -c` invocation), **do not use the `git commit -m "$(cat <<'EOF' ... EOF)"` heredoc pattern**. The executor serialises the entire command into a single line before passing it to `sh -c`, which collapses all the newlines in the heredoc body onto one line. The heredoc terminator then sits on the same line as the message body and `sh` fails with `syntax error near unexpected token '('`, producing an empty commit message and aborting the commit.

The reliable pattern is to write the message to a temp file and pass it via `-F`. Always use `mktemp` for the path — a fixed path like `/tmp/release-commit.txt` will collide with leftovers from a prior run, and the Write tool refuses to overwrite an existing file without first Reading it, forcing a fallback to `rm -f` that needs user approval. `mktemp` sidesteps that:

```sh
# 1. Allocate a unique temp file and arrange cleanup on exit.
msg=$(mktemp -t release-commit.XXXXXX)
trap 'rm -f "$msg"' EXIT

# 2. Write the message to "$msg" with the Write tool (not echo/cat) to preserve formatting.

# 3. Commit from the file.
git commit -F "$msg"
```

Same applies to `gh pr create --body-file ...` and `gh release create --notes-file ...` — prefer the `-file` variants over inline `--body`/`--notes` with multi-paragraph content, and allocate the path via `mktemp` with a `trap` to clean it up. This pattern is MCP-safe, gives you a reviewable artefact on disk before the command runs, and avoids the stale-file collision. Under a direct shell (not via an MCP-mediated executor), heredocs work fine — but the skill should default to the `-F`/`--*-file` variants so it works identically in both environments.

## Skill improvement

After each release, reflect on whether any reusable insights were gained during the process — new edge cases encountered, better patterns discovered, additional checks that would have caught problems earlier, or workflow improvements that would benefit future releases across any project. Pay special attention to unexpected failures in companion scripts (e.g., `discover.sh`) or tool invocations encountered during the run — these may indicate bugs to fix in the skill or its scripts, not just one-off issues. If any improvements are identified, propose the specific changes to this skill file (or its companion files) to the user. Only integrate them with user consent. This keeps the release skill evolving from real-world usage rather than hypothetical planning.
