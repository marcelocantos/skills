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

Delegate to the `/audit` skill for a comprehensive codebase assessment. Run the full audit — all phases are relevant when preparing a project for public release.

In addition to the standard audit findings, pay special attention to:

- **Secrets in git history**: Even if secrets have been removed from the current tree, they persist in git history. Since we always keep full history (never squash), any secret that was ever committed will be public. Flag these as **Critical**.
- **Internal references**: Company-internal hostnames, private repo URLs, issue tracker links, or TODOs marked private/internal — these are embarrassing in a public repo.
- **Licence compatibility with Apache 2.0**: All third-party dependencies must have Apache-2.0-compatible licences. Flag GPL (non-LGPL), AGPL, or proprietary dependencies.

Present all findings as a checklist. Ask the user to confirm which issues to fix before proceeding.

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

Invoke the `/release` skill and follow its full workflow — discovery script, all phases, gate checks, everything. Do not hand-roll release workflows, CI configurations, or Homebrew setup. The `/release` skill encodes institutional knowledge (asset naming conventions, homebrew-releaser configuration, HOMEBREW_TAP_TOKEN setup instructions with specific URLs, STABILITY.md for pre-1.0 projects, binary naming as `<project>-<version>-<os>-<arch>.tar.gz`, etc.) that is easy to get wrong when reimplemented from memory.

**This is not a suggestion — it is a hard delegation.** The only acceptable path for creating a release is through `/release`.

## Audit log

After all phases are complete, append a single summary entry to `docs/audit-log.md` (create the file with the standard header if it doesn't exist — see `~/.claude/skills/audit-log-convention.md` for the format). Commit and push it immediately so the entry doesn't drift into the next work cycle. (As an orchestrator spanning multiple commits, this is an exception to the "before the final commit" convention.)

The entry should cover all sub-skills that ran (/audit, /docs, /release) and their outcomes. Example:

```markdown
## 2026-02-25 — /open-source doit v0.1.0

- **Commit**: `790893a`
- **Outcome**: Open-sourced doit. Audit: 30 findings (4 critical, 7 high), all critical/high addressed. Docs: README, CLAUDE.md, agents-guide.md written. Released v0.1.0 (darwin-arm64, linux-amd64, linux-arm64) with Homebrew tap.
- **Deferred**:
  - audit.max_size_mb not enforced
  - 5 packages at 0% test coverage
  - per-project config not implemented
```

Sub-skills (/audit, /docs, /release) skip their own audit-log entries when called from /open-source — this entry is the single record.

## Error handling

- If `gh` CLI is not installed or not authenticated, tell the user and stop.
- If the repo name is already taken, ask for an alternative.
- Never force-push or rewrite history.
- Never proceed past a phase without user confirmation.

## Skill improvement

After each open-sourcing run, reflect on whether any reusable insights were gained — new audit checks that would have caught problems earlier, better patterns for documentation or licensing, workflow improvements, or edge cases in CI setup. Pay special attention to unexpected failures in companion scripts or tool invocations encountered during the run — these may indicate bugs to fix in the skill or its scripts, not just one-off issues. If any improvements are identified, propose the specific changes to this skill file (or its companion files) to the user. Only integrate them with user consent.
