---
name: open-source
description: Open-source a project — audit, fix, document, publish, and release.
user-invocable: true
---

# Open Source a Project

End-to-end skill for taking a private project public. Covers audit, fixes, documentation, repo creation, and releases.

## Locked-in decisions

- **License**: Apache 2.0 (always)
- **GitHub account**: `marcelocantos` (personal)
- **Git history**: Always keep full history (never squash)
- **Default branch**: `master`
- **Release platforms**: macOS arm64 + Linux x86_64 + Linux arm64
- **Homebrew tap**: `marcelocantos/homebrew-tap` — uses [homebrew-releaser](https://github.com/Justintime50/homebrew-releaser) GitHub Action for automated formula generation and publishing
- **Versioning**: **Always suggest minor releases** (bump MINOR, reset PATCH to 0) unless the user explicitly requests otherwise. First release: `v0.1.0`.
- **Tag ownership**: The release tag is created **once** by `gh release create` locally. CI workflows must **never** create tags or releases — they only build artifacts and upload them to the existing release.

## Invocation

The user runs `/open-source [repo-name]`. If no repo name is given, ask for one.

## Workflow

Execute these phases in order. At the end of each phase, summarize what was done and confirm before moving to the next.

### Phase 1: Audit

Scan the current working tree for issues that must be resolved before publishing.

1. **Secrets & credentials**: Search for API keys, tokens, passwords, private URLs, `.env` files, credentials files. Check common patterns: `password=`, `secret=`, `token=`, `api_key=`, `AWS_`, private IPs, `BEGIN RSA PRIVATE KEY`, etc. Report any findings.

2. **Large files**: Find files > 1MB that aren't clearly intentional (binaries, data files). Flag anything that looks like it shouldn't be in a public repo.

3. **Gitignore coverage**: Check that `.gitignore` covers build artifacts, IDE files (`.vscode/`, `.idea/`), OS files (`.DS_Store`, `Thumbs.db`), and dependency directories. Suggest additions if gaps are found.

4. **Dependency licenses**: For any vendored dependencies or submodules, check their licenses are compatible with Apache 2.0. Flag any GPL (non-LGPL), AGPL, or proprietary dependencies.

5. **Internal references**: Search for internal hostnames, private repo URLs, company-internal references, or TODOs marked private/internal.

6. **Existing LICENSE file**: Check if one already exists. If it does and it's not Apache 2.0, flag it.

7. **CLI flags audit** (if the project produces standalone binaries): Check that the following flags exist and work:

   - **`--version`**: The Homebrew formula `test` block relies on it. Flag if missing, if the version string is hardcoded but doesn't match any release tag, or if there's no clear mechanism for updating it at release time.
   - **`--help`**: Verify usage information is printed. Most CLI frameworks provide this automatically.
   - **`--help-agent`**: Should emit the project's agent guide (e.g., `agents-guide.md`) for use by coding agents. For Go programs this should use `go:embed`. Flag if missing.

Present all findings as a checklist. Ask the user to confirm which issues to fix before proceeding.

### Phase 2: Fixes

Apply fixes for issues identified in the audit.

1. **Add LICENSE**: Create an `Apache-2.0` LICENSE file with the current year and copyright holder "The [Project] Authors". Ask the user for the copyright holder name if unclear.

2. **Fix .gitignore**: Add any missing patterns identified in the audit.

3. **Remove secrets**: Help the user remove or redact any flagged secrets. Never silently delete — always show what will change and confirm.

4. **Add license headers**: If the project uses source files (.cpp, .h, .py, .go, etc.), ask whether the user wants Apache 2.0 header comments added to source files. If yes, add the short-form header:
   ```
   // Copyright [year] [copyright holder]
   // SPDX-License-Identifier: Apache-2.0
   ```

5. **Fix CLI flags**: Address any missing flags found in the audit:

   - **`--version`**: Prefer build-time injection from the git tag (e.g., `-ldflags -X main.version=$VERSION` for Go, `-DVERSION=` for C/C++) so the version stays in sync with releases automatically. If build-time injection isn't practical, add a hardcoded version constant and note that it must be updated each release.
   - **`--help`**: If the project doesn't use a CLI framework that provides this automatically, add basic usage output.
   - **`--help-agent`**: Add a flag that prints the project's agent guide to stdout. For Go programs, embed the markdown file with `go:embed`:
     ```go
     import _ "embed"

     //go:embed agents-guide.md
     var agentGuide string
     ```
     Then print `agentGuide` when `--help-agent` is passed. For other languages, use the equivalent embedding mechanism or bundle the content as a string constant. Ensure the embedded file path is correct relative to the package containing the `//go:embed` directive.

6. **Clean up flagged items**: Address any other audit findings the user confirmed.

### Phase 3: Documentation

Delegate to the `/docs` skill for comprehensive documentation audit and writing. This ensures the same thorough process is used whether open-sourcing or improving docs on an existing project.

Invoke `/docs` and follow its full workflow (discovery, audit, recommendations, execution, verification). The `/docs` skill will handle README, CONTRIBUTING, CHANGELOG, architecture docs, API docs, inline comments, and everything else appropriate for the project.

### Phase 4: Publish

Create the GitHub repository and push.

1. **Commit all changes** from phases 2-3 with a clear message.

2. **Create the repo**:
   ```bash
   gh repo create marcelocantos/<repo-name> --public --source=. --push \
     --description "<description>"
   ```
   Ask the user for the repo description if not obvious from the README.

3. **Set repo metadata**:
   - Add topics/tags (ask the user for relevant topics)
   - Confirm the repo is visible and the push succeeded

4. **Report**: Print the repo URL and a summary of what was published.

### Phase 5: Release (optional)

Ask if the user wants to create an initial release. If yes:

1. **Version**: Suggest `v0.1.0` for the first release. Only suggest a different version if the user explicitly requests one.

2. **Release notes**: Draft from README, CHANGELOG, or recent git history. Keep it concise.

3. **CI workflow** (ask if applicable — skip for libraries/tools that aren't standalone executables):
   - **Always use CI** — never build release binaries locally. Create a `.github/workflows/release.yml` that triggers on `release` events (`types: [published]`). The workflow must **only build and upload artifacts** — it must **never create tags, releases, or draft releases** (the release already exists, created by `gh release create` in step 4). The workflow should:
     - Run tests
     - Build for macOS arm64, Linux x86_64, Linux arm64 using a matrix strategy
     - Package each binary as `<project>-<version>-<os>-<arch>.tar.gz`
     - Upload tarballs to the **existing** release with `gh release upload`
   - Add a **homebrew-releaser** job (runs after binaries are uploaded) using [homebrew-releaser](https://github.com/Justintime50/homebrew-releaser):
     ```yaml
     homebrew:
       needs: build
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
             update_readme_table: true
     ```
   - **Required setup — `HOMEBREW_TAP_TOKEN` secret**: Each source repo that publishes to the tap needs its own PAT and secret. Create a separate token per repo:
     1. Create a **fine-grained** PAT at https://github.com/settings/personal-access-tokens/new — name it after the source repo (e.g., `<repo>-homebrew-tap`), select **only** the tap repo (`<owner>/homebrew-tap`) under "Repository access", and grant **Contents → Read and write** permission.
     2. Add the PAT as a secret named `HOMEBREW_TAP_TOKEN` at `https://github.com/<owner>/<repo>/settings/secrets/actions/new`.
     3. Provide these two URLs to the user so they can complete the setup manually (secrets cannot be created via CLI or API without the token value).
   - Binary tarballs must follow the naming convention `<project>-<version>-<os>-<arch>.tar.gz`. homebrew-releaser auto-detects these from the release assets and computes SHA256 checksums.
   - Show the workflow to the user for review. Commit to `master` and push before creating the release.

4. **Update version string**: If the project has a hardcoded version constant, update it to match the release version and commit before creating the release. If the version is injected at build time, verify the CI workflow passes the tag to the build.

5. **Create the release**: Use `gh release create` to tag and release in one step. The CI workflow builds binaries, uploads them, and homebrew-releaser automatically generates and pushes the formula to the tap.

6. **Verify**: Wait for CI, then confirm:
   - Binaries are attached to the release
   - Homebrew formula was pushed to `marcelocantos/homebrew-tap`
   - Report the install command: `brew install marcelocantos/tap/<project>`

## Error handling

- If `gh` CLI is not installed or not authenticated, tell the user and stop.
- If the repo name is already taken, ask for an alternative.
- Never force-push or rewrite history.
- Never proceed past a phase without user confirmation.
