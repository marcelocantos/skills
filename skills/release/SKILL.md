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

Execute these phases in order. Summarise findings at the end of each phase and confirm before proceeding.

### Phase 1: Discovery

Assess the project's current release state. **Start by running the companion discovery script:**

```
~/.claude/skills/release/discover.sh
```

(It is already `chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command.)

This script gathers all Phase 1 data in one invocation (tags, releases, build system, project type, CI workflows, Homebrew tap, repo description, version macros, vendored dependency licences, and working tree status). Parse its output, then verify or supplement the following items as needed:

1. **Existing releases**: List existing tags and GitHub releases (`git tag --sort=-v:refname`, `gh release list`). Identify the latest version.

2. **Build system**: Determine how the project builds — mkfile, Makefile, go build, cargo, cmake, etc. If the project has a `mkfile`, run `mk --help-agent` to get build instructions and understand the mk syntax. mk binaries are available from https://github.com/marcelocantos/mk. Check for a distribution generation target (e.g., `make dist`, `mk dist`) that produces release artifacts (amalgamated headers, bundled files, etc.) that are checked into the repo. Note the target name for Phase 5.

3. **Project type**: Determine whether the project produces standalone binaries or is a library/tool that users consume as source. This affects whether CI binaries and Homebrew tap are relevant.

4. **CI workflows**: Check for existing `.github/workflows/` files, especially any release-related workflows.

5. **Homebrew tap**: Check if `marcelocantos/homebrew-tap` exists and whether it already has a formula for this project.

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

Present a summary of findings and confirm before proceeding.

### Phase 1.5: Stability tracking (pre-1.0 projects only)

**Skip this phase** if the project is already at v1.0.0 or later.

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

Commit and push the `STABILITY.md` changes before proceeding to Phase 2.

### Phase 1.6: Breaking change audit (post-1.0 projects only)

**Skip this phase** if the project is pre-1.0 (below v1.0.0).

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

3. **If no breaking changes found**: Report the audit results, commit the updated `STABILITY.md` catalogue, and proceed to Phase 2.

4. **If breaking changes found**: **Stop the release.** Report each breaking change with specific file:line references, showing what changed relative to the `STABILITY.md` catalogue. Explain that post-1.0 breaking changes are not permitted as a minor or patch release.

   **The project's stance on breaking changes is absolute**: there is no "v2.0" of the same product. If a project genuinely needs to break backwards compatibility, the correct path is to **fork the project into a new product**. For example, `foo` would become `foo2` — a new repository (or a hard fork of the existing one) starting at `v0.1.0` with its own pre-1.0 stabilisation cycle. The original `foo` continues to exist at its last stable version for existing users.

   This policy exists because major version bumps within the same product create ecosystem fragmentation, dependency hell, and migration burdens. A clean fork makes the break explicit and lets both versions coexist without conflict.

   Present this recommendation to the user and stop. Do not proceed with the release.

### Phase 2: Version

Determine the next version number. **Do not ask for confirmation** — just use the version determined below.

1. **Changes since last release**: Run `git log --oneline <last-tag>..HEAD` (or full log if no prior tags) and summarise the changes.

2. **Determine version**: If there are no prior releases, use `v0.1.0`. Otherwise, bump MINOR and reset PATCH to 0 (e.g., `v0.1.0` → `v0.2.0`, `v1.3.0` → `v1.4.0`). Only use a different bump if the user explicitly requested one.

3. **Update version string**: If the project has a hardcoded version string (found in Phase 1 step 7), update it to match the new version. Commit the change before proceeding. If the version is injected at build time (e.g., via `-ldflags` or CI env vars), verify the injection mechanism uses the tag correctly and no manual update is needed.

   **C/C++ libraries with version macros**: If the header defines version macros (e.g., `#define PROJECTNAME_VERSION "x.y.z"` with `_MAJOR`, `_MINOR`, `_PATCH` companions), update all four macros to match the new version. Verify consistency: the string must equal `"MAJOR.MINOR.PATCH"`.

   **STABILITY.md catalogue**: If `STABILITY.md` lists version macro values in its interaction surface catalogue, update those to match the new version too. Also update the "Snapshot as of" line to reference the new version.

   **Go module version constants**: If the project has Go wrapper modules with
   version constants (e.g., `Version = "x.y.z"` with `VersionMajor`,
   `VersionMinor`, `VersionPatch`), update them to match the new version.

   **No version macros found**: If a C/C++ library has no version macros at all, note this as a gap. For pre-1.0 projects, record it in `STABILITY.md` under gaps/prerequisites. Don't block the release — version macros are a 1.0 prerequisite, not a pre-1.0 gate.

### Phase 3: Release notes

Draft release notes from git history.

1. **Gather material**: Read commit messages and any merged PRs since the last tag.

2. **Draft**: Write concise release notes. Group changes by category where natural:
   - Added (new features)
   - Changed (modifications to existing behaviour)
   - Fixed (bug fixes)
   - Removed (deprecated features removed)

   Don't force categories — if there are only a few changes, a simple bullet list is fine.

3. **Display**: Print the draft release notes in the transcript so the user can see them. Do not wait for approval — proceed immediately. (The `changelog-reviewed` gate is automated, not manual.)

### Phase 4: CI setup (conditional)

**Skip this phase** if the project is a library without standalone binaries, or if a release CI workflow already exists and is working.

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

### Phase 4.5: Gate check

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
   - **manual**: Present the gate's prompt to the user and **wait for
     explicit approval**. Do not proceed until the user confirms.
4. If any gate fails, **stop**. Report which gate failed and why.
   Do not proceed to Phase 5.

**Expect two PRs.** The `pr-workflow` pre-merge gate means release-skill work routes through a feature branch and PR, not a direct push to master. Combined with the audit-log chicken-and-egg (see **Audit log** section below), the typical release flow produces **two sequential PRs**:

1. **Release PR** — version bump, STABILITY.md updates, doc changes, and the audit-log entry with `Commit: pending`. CI must go green before squash-merge.
2. **Audit-log-hash PR** — a tiny docs-only follow-up that rewrites `pending` to the real merge-commit hash from PR #1. Also requires CI green before merge, then tag from the resulting master commit.

This is by design. Tell the user upfront at the start of Phase 4.5 so the second PR isn't a surprise. If the project has no CI, the `pr-workflow` gate still applies — you still need to go through a PR, but CI waits are zero.

### Phase 5: Release

Create the GitHub release and let CI handle the rest.

1. **Validate version strings**: Before tagging, verify that any in-source version strings match the release version. For C/C++ projects with version macros, check that the `#define` values match the tag (strip leading `v`). Fail early if they don't — the version commit from Phase 2 step 3 should have already handled this, but double-check.

2. **Push**: Ensure all commits (version bump, STABILITY.md updates, etc.) are pushed to the remote before tagging. The release tag must point to a commit that exists on the remote.

3. **Regenerate distribution files**: If Phase 1 identified a dist generation target (e.g., `make dist`), run it now. If it produces any changes, commit them (e.g., "Regenerate dist for \<version\>") and push before tagging. This ensures the release tag includes up-to-date distribution artifacts.

4. **Create the release**: Use `gh release create` which both tags and creates the release:
   ```bash
   gh release create <version> --title "<version>" --notes-file <notes-file>
   ```
   This triggers the `release.yml` workflow, which builds binaries, uploads them, and (if configured) runs homebrew-releaser to update the tap formula automatically.

5. **Go module tags**: If the project contains Go modules in subdirectories
   (e.g., `go/sqlpipe/go.mod`), create subdirectory-prefixed tags for each
   Go module so that `go get` can resolve them. For a module at path
   `go/sqlpipe` and release version `v0.11.0`, create and push:
   ```bash
   git tag go/sqlpipe/<version> <version>
   git push origin go/sqlpipe/<version>
   ```
   Also update the Go module's version constants (if any) to match the
   release version during the Phase 2 version bump.

6. **Monitor CI**: Wait for the release workflow to complete:
   ```bash
   gh run list --workflow=release.yml --limit=1
   gh run watch <run-id>
   ```
   If it fails, help diagnose — do not delete the release or tag without asking.

7. **Verify**: Confirm:
   - The release appears on GitHub with correct notes and artifacts
   - Binary tarballs are attached for each platform
   - The Homebrew formula was updated in `marcelocantos/homebrew-tap` (check the tap repo's recent commits). If the workflow includes a homebrew-releaser job, wait for it to finish (`gh run watch`) before proceeding — the tap commit must exist before the local install in step 8 will pick up the new version.

8. **Install locally**: Install the released version onto the laptop so the user can use it immediately. This step is **mandatory** for projects with a Homebrew tap — do not skip it and do not ask for permission.

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

   **Non-Homebrew projects**: If the project has no Homebrew tap (e.g., a library, or a binary distributed another way), skip this step and note it in the Phase 5 report.

9. **Report**: Print:
   - Release URL
   - Homebrew install command (if tap was set up): `brew install marcelocantos/tap/<project>`
   - Confirmation that the new version is installed locally (include the `--version` output)

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
- Never proceed past a phase without user confirmation, except where a gate is automated (e.g., release notes display).

## Skill improvement

After each release, reflect on whether any reusable insights were gained during the process — new edge cases encountered, better patterns discovered, additional checks that would have caught problems earlier, or workflow improvements that would benefit future releases across any project. Pay special attention to unexpected failures in companion scripts (e.g., `discover.sh`) or tool invocations encountered during the run — these may indicate bugs to fix in the skill or its scripts, not just one-off issues. If any improvements are identified, propose the specific changes to this skill file (or its companion files) to the user. Only integrate them with user consent. This keeps the release skill evolving from real-world usage rather than hypothetical planning.
