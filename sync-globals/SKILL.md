# sync-globals

Scan managed repositories for compliance with global `~/.claude/CLAUDE.md` directives and update the manifest.

## When to use

- After changing global directives (license policy, header format, .gitignore rules, etc.)
- Periodically, to check fleet health
- When onboarding a new repo (run after adding its `CLAUDE.md`)

## Steps

### 1. Discover repos

Find all repositories with a `CLAUDE.md` in the root. Search under `~/work/` recursively (max depth 3 to avoid vendor/node_modules noise):

```bash
find ~/work -maxdepth 3 -name CLAUDE.md -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/node_modules/*' -exec dirname {} \;
```

### 2. Read current global directives

Read `~/.claude/CLAUDE.md` and extract the compliance-relevant sections:
- **Licensing**: expected license type, SPDX header format, copyright holder
- **Repository Hygiene**: .gitignore coverage requirements
- **Versioning**: semantic versioning expectations
- **CLI Binaries**: --version/--help/--help-agent requirements (if applicable)

### 3. Check each repo

For every discovered repo, check:

| Check | How | Pass condition |
|---|---|---|
| **License file** | Read `LICENSE` first line | Matches expected type from global directives |
| **SPDX headers** | Sample first source file (`*.go`, `*.rs`, `*.py`, `*.ts`, `*.cpp`, `*.h`) | Contains `SPDX-License-Identifier` line |
| **.gitignore** | File exists and covers build artifacts | `.gitignore` present |
| **Last audit** | Look for `docs/audit-*.md` | Note date if present, `—` if not |
| **Secrets** | Check for `.env`, `credentials.json`, `*.pem` in tracked files | None found |

For SPDX headers: sample up to 3 source files (skip `vendor/`, `.git/`, generated files). If the repo has no source files (e.g., pure docs/config), mark as `n/a`.

For language detection: check for `go.mod` (Go), `Cargo.toml` (Rust), `package.json` (JS/TS), `pyproject.toml`/`setup.py` (Python), `Makefile` with `.cpp`/`.h` (C++).

### 4. Update manifest

Read `~/.claude/managed-repos.md`. For each repo:
- If already in the table, update its columns
- If new (has CLAUDE.md but not in table), add it
- If in the table but no longer has CLAUDE.md, keep it but add `(removed)` to Notes

Update the `Last scanned` date.

### 5. Report

Print a summary to the user:

```
Managed repos: N
  Compliant:    X
  Issues:       Y

Issues:
  repo-name: license is MIT (expected Apache-2.0), no SPDX headers
  repo-name: no license file
  ...
```

If there are issues, ask the user whether they'd like to:
1. Fix all issues across repos (will cd into each and make changes)
2. Fix specific repos only
3. Just note them for now

### 6. Fix mode (if requested)

For each repo with issues, `cd` into it and apply fixes:
- **Missing/wrong license**: Write the correct LICENSE file (Apache 2.0 with correct copyright)
- **Missing SPDX headers**: Add 2-line SPDX header to all source files
- **Missing .gitignore**: Create one appropriate for the language
- **Missing NOTICE**: Create if Apache 2.0 and not present

After fixing, commit changes to a branch and use `/push` if the user wants PRs.

IMPORTANT: Never push directly to master. Always confirm before committing.
