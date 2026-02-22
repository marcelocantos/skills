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

5. **Clean up flagged items**: Address any other audit findings the user confirmed.

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

1. **Tag**: Ask for version (suggest `v0.1.0` for first public release, or `v1.0.0` if the project is mature).

2. **Release notes**: Draft from README, CHANGELOG, or recent git history. Keep it concise.

3. **Binaries** (ask if applicable — skip for libraries/tools that aren't standalone executables):
   - Determine the build command from the Makefile/build system
   - Build for: macOS arm64, Linux x86_64, Linux arm64
   - For cross-compilation, suggest using Docker or CI. If CI doesn't exist, offer to create a GitHub Actions workflow for release builds.
   - Package each binary as `<project>-<version>-<os>-<arch>.tar.gz`

4. **Create the release**:
   ```bash
   gh release create <tag> --title "<tag>" --notes-file <notes-file> <assets...>
   ```

5. **CI for future releases** (ask if wanted): Offer to create a `.github/workflows/release.yml` that builds and uploads binaries on tag push.

## Error handling

- If `gh` CLI is not installed or not authenticated, tell the user and stop.
- If the repo name is already taken, ask for an alternative.
- Never force-push or rewrite history.
- Never proceed past a phase without user confirmation.
