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

### Phase 1: Pre-publication audit

Audit the codebase for issues that matter when going public. Cover at least:

- **Secrets in git history**: Even if secrets have been removed from the current tree, they persist in git history. Since we always keep full history (never squash), any secret that was ever committed will be public. Flag these as **Critical**.
- **Internal references**: Company-internal hostnames, private repo URLs, issue tracker links, or TODOs marked private/internal — these are embarrassing in a public repo.
- **Licence compatibility with Apache 2.0**: All third-party dependencies must have Apache-2.0-compatible licences. Flag GPL (non-LGPL), AGPL, or proprietary dependencies.
- **LICENSE / NOTICES presence**: Confirm Apache 2.0 LICENSE file exists; if vendored or copied dependencies are present, confirm a NOTICES/THIRD_PARTY file lists them with their licences.
- **`.gitignore` hygiene**: Build artifacts, IDE files, OS files, dependency directories, and any generated `.env`/credential files are ignored.
- **README and basic docs**: A README exists and minimally covers what the project is, how to build/run it, and how to contribute.

Present findings as a checklist. Ask the user to confirm which issues to fix before proceeding.

### Phase 2: Fixes

Apply fixes for issues identified in the audit.

1. **Add LICENSE**: Create an `Apache-2.0` LICENSE file with the current year and copyright holder. Ask the user for the copyright holder name if unclear.

2. **Fix .gitignore**: Add any missing patterns identified in the audit.

3. **Remove secrets**: Help the user remove or redact any flagged secrets. Never silently delete — always show what will change and confirm.

4. **Add licence headers**: If the project uses source files (.cpp, .h, .py, .go, etc.), ask whether the user wants Apache 2.0 header comments added to source files. If yes, add the short-form header:
   ```
   // Copyright [year] [copyright holder]
   // SPDX-License-Identifier: Apache-2.0
   ```

5. **Add third-party attribution**: If the audit found vendored or copied dependencies without proper attribution, create a NOTICES or THIRD_PARTY file listing each dependency with its licence.

6. **CLI flags**: Do not fix CLI flags (`--version`, `--help`, `--help-agent`) in this phase. The `/release` skill (Phase 5) performs a thorough CLI flag audit with discovery and handles all flag gaps. Fixing them here creates overlap and risks inconsistency.

7. **Address remaining findings**: Work through other audit findings the user confirmed, in priority order.

### Phase 3: Documentation

Delegate to the `/docs` skill for comprehensive documentation audit and writing. This ensures the same thorough process is used whether open-sourcing or improving docs on an existing project.

Invoke `/docs` and follow its full workflow (discovery, audit, recommendations, execution, verification). The `/docs` skill will handle README, architecture docs, API docs, inline comments, and everything else appropriate for the project.

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

### Phase 5: Release

Invoke the `/release` skill and follow its full workflow — discovery script, all phases, gate checks, everything. Do not hand-roll release workflows, CI configurations, or Homebrew setup. The `/release` skill encodes institutional knowledge (asset naming conventions, homebrew-releaser configuration, HOMEBREW_TAP_TOKEN setup instructions with specific URLs, binary naming as `<project>-<version>-<os>-<arch>.tar.gz`, etc.) that is easy to get wrong when reimplemented from memory.

**This is not a suggestion — it is a hard delegation.** The only acceptable path for creating a release is through `/release`.

## Error handling

- If `gh` CLI is not installed or not authenticated, tell the user and stop.
- If the repo name is already taken, ask for an alternative.
- Never force-push or rewrite history.
- Never proceed past a phase without user confirmation.

## Skill improvement

After each open-sourcing run, reflect on whether any reusable insights were gained — new audit checks that would have caught problems earlier, better patterns for documentation or licensing, workflow improvements, or edge cases in CI setup. Pay special attention to unexpected failures in companion scripts or tool invocations encountered during the run — these may indicate bugs to fix in the skill or its scripts, not just one-off issues. If any improvements are identified, propose the specific changes to this skill file (or its companion files) to the user. Only integrate them with user consent.
