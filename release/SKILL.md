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
- **Versioning**: Semantic versioning (`vMAJOR.MINOR.PATCH`). **Always suggest minor releases** (bump MINOR, reset PATCH to 0) unless the user explicitly requests a major or patch release.
- **Tag ownership**: The release tag is created **once** by `gh release create` locally. CI workflows must **never** create tags or releases — they only build artifacts and upload them to the existing release.

## Invocation

The user runs `/release`. No arguments needed — the skill discovers everything from the repo.

## Workflow

Execute these phases in order. Summarise findings at the end of each phase and confirm before proceeding.

### Phase 1: Discovery

Assess the project's current release state.

1. **Existing releases**: List existing tags and GitHub releases (`git tag --sort=-v:refname`, `gh release list`). Identify the latest version.

2. **Build system**: Determine how the project builds — mkfile, Makefile, go build, cargo, cmake, etc. If the project has a `mkfile`, run `mk --help-agent` to get build instructions and understand the mk syntax. mk binaries are available from https://github.com/marcelocantos/mk. Check for a distribution generation target (e.g., `make dist`, `mk dist`) that produces release artifacts (amalgamated headers, bundled files, etc.) that are checked into the repo. Note the target name for Phase 5.

3. **Project type**: Determine whether the project produces standalone binaries or is a library/tool that users consume as source. This affects whether CI binaries and Homebrew tap are relevant.

4. **CI workflows**: Check for existing `.github/workflows/` files, especially any release-related workflows.

5. **Homebrew tap**: Check if `marcelocantos/homebrew-tap` exists and whether it already has a formula for this project.

6. **Repo description**: Check that the GitHub repo has a description set (`gh repo view --json description`). homebrew-releaser crashes on null descriptions. If missing, set one with `gh repo edit --description "..."`.

7. **CLI flags audit**: If the project produces standalone binaries, check that the following flags exist and work:

   - **`--version`**: Search the codebase for how the version string is set — hardcoded strings, constants, build-time injection (e.g., `-ldflags -X`, `#define VERSION`). Report whether it exists, where the string is defined, whether it matches the latest tag, and how it gets updated. The Homebrew formula `test` block relies on this.
   - **`--help`**: Verify the binary prints usage information. Most CLI frameworks provide this automatically.
   - **`--help-agent`**: Check whether the binary can emit its agent guide (e.g., `agents-guide.md` or `AGENTS-<PROJECT>.md`) for use by coding agents. The output should be prefixed with the `--help` usage text (flags and descriptions) so agents get both CLI reference and domain guide in one call. For Go programs, embed the guide with `go:embed` and capture `flag.PrintDefaults()` into a buffer to prepend it. For other languages, equivalent embedding or a bundled string constant.

   Flag any that are missing.

8. **Working tree**: Verify the working tree is clean and up to date with the remote. If there are uncommitted changes or unpushed commits, flag them before proceeding.

Present a summary of findings and confirm before proceeding.

### Phase 2: Version

Determine the next version number. **Do not ask for confirmation** — just use the version determined below.

1. **Changes since last release**: Run `git log --oneline <last-tag>..HEAD` (or full log if no prior tags) and summarise the changes.

2. **Determine version**: If there are no prior releases, use `v0.1.0`. Otherwise, bump MINOR and reset PATCH to 0 (e.g., `v0.1.0` → `v0.2.0`, `v1.3.0` → `v1.4.0`). Only use a different bump if the user explicitly requested one.

3. **Update version string**: If the project has a hardcoded version string (found in Phase 1 step 7), update it to match the new version. Commit the change before proceeding. If the version is injected at build time (e.g., via `-ldflags` or CI env vars), verify the injection mechanism uses the tag correctly and no manual update is needed.

### Phase 3: Release notes

Draft release notes from git history.

1. **Gather material**: Read commit messages and any merged PRs since the last tag.

2. **Draft**: Write concise release notes. Group changes by category where natural:
   - Added (new features)
   - Changed (modifications to existing behaviour)
   - Fixed (bug fixes)
   - Removed (deprecated features removed)

   Don't force categories — if there are only a few changes, a simple bullet list is fine.

3. **Review**: Present the draft to the user. Incorporate feedback before proceeding.

### Phase 4: CI setup (conditional)

**Skip this phase** if the project is a library without standalone binaries, or if a release CI workflow already exists and is working.

1. **Create release workflow**: Create `.github/workflows/release.yml` that triggers on `release` events (`types: [published]`). The workflow must **only build and upload artifacts** — it must **never create tags, releases, or draft releases** (the release already exists, created by `gh release create` in Phase 5). The workflow should:
   - Run tests
   - Build for macOS arm64, Linux x86_64, Linux arm64 using a matrix strategy
   - Package each binary as `<project>-<version>-<os>-<arch>.tar.gz`
   - Upload tarballs to the **existing** release with `gh release upload`

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
           install: 'bin.install "<project>" => "<project>"'
           target_darwin_arm64: true
           target_linux_amd64: true
           target_linux_arm64: true
           test: 'system bin/"<project>", "--version"'
           skip_checksum: true
           update_readme_table: true
   ```

   Key setup requirements:
   - **`HOMEBREW_TAP_TOKEN` secret**: Each source repo that publishes to the tap needs its own PAT and secret. Create a separate token per repo:
     1. Create a **fine-grained** PAT at https://github.com/settings/personal-access-tokens/new — name it after the source repo (e.g., `<repo>-homebrew-tap`), select **only** the tap repo (`<owner>/homebrew-tap`) under "Repository access", and grant **Contents → Read and write** permission.
     2. Add the PAT as a secret named `HOMEBREW_TAP_TOKEN` at `https://github.com/<owner>/<repo>/settings/secrets/actions/new`.
     3. Provide these URLs to the user so they can complete the setup (secrets cannot be created via API without the token value).
   - The `homebrew-tap` repo must exist at `marcelocantos/homebrew-tap` with a `Formula/` directory.
   - Binary tarballs must follow the naming convention `<project>-<version>-<os>-<arch>.tar.gz` where `<version>` has **no `v` prefix** (e.g., `myapp-1.2.0-darwin-arm64.tar.gz`). homebrew-releaser strips the `v` from the tag when searching for assets.
   - The `install` and `test` fields must match the project's actual binary name and CLI interface.
   - Add `depends_on` if the binary needs runtime dependencies.

   **Known homebrew-releaser issues:**
   - **`skip_checksum: true` is required** when `HOMEBREW_TAP_TOKEN` is scoped to the tap repo only. Without it, homebrew-releaser tries to upload `checksum.txt` to the source repo's release and gets a 403.
   - **The GitHub repo must have a description set.** homebrew-releaser crashes (`TypeError: 'NoneType' object is not subscriptable`) if the repo description is null. Set it with `gh repo edit --description "..."` before the first release.
   - **Formula description truncation.** homebrew-releaser truncates the repo description to fit Homebrew's field limit (~80 chars). Keep repo descriptions concise to avoid mid-word cutoffs.

3. **Verify**: Show the workflow file to the user for review. Commit it to `master` and push before tagging.

### Phase 5: Release

Create the GitHub release and let CI handle the rest.

1. **Regenerate distribution files**: If Phase 1 identified a dist generation target (e.g., `make dist`), run it now. If it produces any changes, commit them (e.g., "Regenerate dist for \<version\>") and push before tagging. This ensures the release tag includes up-to-date distribution artifacts.

2. **Create the release**: Use `gh release create` which both tags and creates the release:
   ```bash
   gh release create <version> --title "<version>" --notes-file <notes-file>
   ```
   This triggers the `release.yml` workflow, which builds binaries, uploads them, and (if configured) runs homebrew-releaser to update the tap formula automatically.

3. **Monitor CI**: Wait for the release workflow to complete:
   ```bash
   gh run list --workflow=release.yml --limit=1
   gh run watch <run-id>
   ```
   If it fails, help diagnose — do not delete the release or tag without asking.

4. **Verify**: Confirm:
   - The release appears on GitHub with correct notes and artifacts
   - Binary tarballs are attached for each platform
   - The Homebrew formula was updated in `marcelocantos/homebrew-tap` (check the tap repo's recent commits)

5. **Report**: Print:
   - Release URL
   - Homebrew install command (if tap was set up): `brew install marcelocantos/tap/<project>`

## Error handling

- If `gh` CLI is not installed or not authenticated, tell the user and stop.
- If the working tree is dirty, ask the user to commit or stash before proceeding.
- If CI workflow fails after tagging, help diagnose — do not delete the tag without asking.
- Never force-push or rewrite history.
- Never proceed past a phase without user confirmation.
