# /sync-globals Worker — Global Directive Compliance

Scan managed repositories for compliance with global `~/.claude/CLAUDE.md`
directives and update the manifest.

## Progress reporting

Before starting each step, emit a progress heading **on its own line
followed by a blank line**, then proceed to tool calls. Use `##` for
major steps and `###` for sub-steps. Examples:

## Step 1 — Discover repos

## Step 3 — Check each repo

### Checking marcelocantos/dais

### Checking squz/multimaze

## Step 5 — Report

Do not put any other text on the same line or immediately after the
heading — the blank line is required. These headings are picked up by
the Agent framework and forwarded to the root session as progress
notifications.

## Step 1 — Discover repos

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

## Step 2 — Read current global directives

Read `~/.claude/CLAUDE.md` and extract the compliance-relevant sections:
- **Licensing**: expected license type, SPDX header format, copyright holder
- **Repository Hygiene**: .gitignore coverage requirements
- **Versioning**: semantic versioning expectations
- **CLI Binaries**: --version/--help/--help-agent requirements (if applicable)

## Step 3 — Check each repo

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

## Step 4 — Update manifest

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

## Step 5 — Report

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

Return the full compliance report as your result. If there are issues,
note them clearly so the root session can offer Fix mode to the user.
