# sync-globals

Scan managed repositories for compliance with global `~/.claude/CLAUDE.md` directives and update the manifest.

## When to use

- After changing global directives (license policy, header format, .gitignore rules, etc.)
- Periodically, to check fleet health
- When onboarding a new repo (run after adding its `CLAUDE.md`)

## Steps

### 1. Discover repos

Find all repositories with a `CLAUDE.md` in the root. Search under
`~/work/github.com/` — the CLAUDE.md sits at depth 3 (`org/repo/CLAUDE.md`):

```bash
find ~/work/github.com -mindepth 3 -maxdepth 3 -name CLAUDE.md -exec dirname {} \;
```

**Exclude forks**: Check the "Known Forks" section at the bottom of
`~/.claude/managed-repos.md` first. If the `org/repo` slug appears there,
skip it without calling GitHub.

For repos not in the known-forks list, derive the `org/repo` slug from
the directory path (e.g. `~/work/github.com/squz/multimaze` →
`squz/multimaze`) and check GitHub:

```bash
gh api "repos/$slug" --jq '.fork'
```

- If `.fork` is `true`, skip the repo **and add it to the "Known Forks"
  list** in `managed-repos.md` (see step 4).
- If `.fork` is `false`, include the repo.
- If the `gh` check fails (not on GitHub, no remote, API error), include
  the repo — err on the side of inclusion.

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

Read `~/.claude/managed-repos.md`. The table uses `org/repo` as the repo
identifier (e.g. `marcelocantos/dais`, `squz/multimaze`). For each repo:
- If already in the table, update its columns
- If new (has CLAUDE.md but not in table), add it
- If in the table but no longer has CLAUDE.md, keep it but add `(removed)` to Notes

Update the `Last scanned` date.

Maintain a "Known Forks" section after the managed repos table. Format:

```markdown
## Known Forks

These repos have a `CLAUDE.md` but are forks of upstream projects.
They are excluded from compliance checks.

- `anz-bank/decimal`
```

Add any newly discovered forks here. Do not remove entries — once
a repo is known to be a fork, it stays cached.

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
