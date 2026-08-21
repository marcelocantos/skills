# Entropy audit — marcelocantos/skills

Date: 2026-08-22
Mode: full (entropy + hygiene)
Auditor: Grok Build subagent (entropy-audit owner)

## Executive summary

- **Snapshot:** `/Users/marcelo/work/github.com/marcelocantos/skills`
  - Branch: `unify-skills-single-tree` (tracks `origin/unify-skills-single-tree`)
  - HEAD: `1f7de0015c742d66ea44bba387818dea6237705f` (2026-08-16, "Update skills from ~/.claude/skills")
  - Default branch `master`: `7051f6f` (2026-07-12) — **20 commits behind this HEAD**
  - Initial dirty state: clean (`git status --porcelain=v1 -b` showed only the branch header)
- **Scope:** this git tree only. Canonical live install `~/.claude/skills/` was compared as an auxiliary source-of-truth check, not as the shipped path. No other repos.
- **Exclusions:** `.git/`; untracked `__pycache__` (global gitexcludes); `.claude/` and `.cv/` (gitignored local state). No vendored or generated production trees.
- **Headline mechanism:** this repository is a **batch rsync snapshot** of `~/.claude/skills/` plus copies of global `CLAUDE.md` / `convergence.md`. Agents edit the install tree; `/republish-skills` later dumps it here and `git push`es the current branch. Three snapshots therefore coexist and already disagree: live install, this branch, and GitHub `master`.
- **Highest-consequence findings:** ENT-001 (triple-snapshot drift, unpublished `entropy-audit`), ENT-002 (`CLAUDE.md` `@AGENTS.md` has no `AGENTS.md` in the repo), ENT-004 (no tests/CI for agent-executed Python and bash), ENT-003 (public Apache-2.0 claim with no LICENSE file).
- **Unverified residue:** whether GitHub `master` is *intentionally* frozen; whether personal identifiers in `/expenses` and `/remind` are accepted public content; whether bash 3.2 is an intended runtime for skill scripts (shebang is `env bash`, which is 5.x on this host).

## Scope and exclusions

In scope: 22 `SKILL.md` entry points under `skills/`, companion `.sh`/`.py` scripts, `cvfile` publish recipe, root `CLAUDE.md` / `convergence.md` / `README.md` / `bullseye.yaml`, `docs/reports/desired-state-convergence.md`.

Named exclusions:

| Path | Reason |
|---|---|
| `.git/` | VCS metadata |
| `skills/hygiene/__pycache__/` | Bytecode; untracked via global gitexcludes |
| `.claude/`, `.cv/` | Local agent state, gitignored |
| `~/.claude/skills/` | Live install; used only to measure mirror lag |

Languages analysed (from the tree, not assumed): Python 3 and bash/POSIX sh. No Go, Rust, C/C++, SQL, or web frontend. Companions read: `python.md`, `bash.md`. `web-development.md` / `journeys.md` do not apply.

## Commands run

| Command | Version | Exit | Shipped vs auxiliary | Notes |
|---|---|---|---|---|
| `git rev-parse HEAD`; `git status --porcelain=v1 -b` | git 2.55.0 | 0 | shipped | Initial snapshot; clean |
| `find . -type f -not -path './.git/*'` | find (BSD) | 0 | shipped | 74 tracked files; 16 `.sh`, 4 `.py`, 49 `.md` |
| `rsync -ani --exclude='.*' --delete ~/.claude/skills/ skills/` | rsync 3.4.4 | 0 | auxiliary | Dry-run; 14 delta lines including new `entropy-audit/` |
| `gh repo view` / workflows / branch protection | gh | 0 / 404 / 404 | shipped remote | Public; `license: null`; no workflows; `master` unprotected |
| `git log --name-only` churn; `git rev-list --count master..HEAD` | git 2.55.0 | 0 | shipped | 207 commits; 20 commits on this branch not in `master` |
| `bash -n` on `*.sh` | bash 5.3.15 | 1 | auxiliary | False fail on `skills/docs/link-check.sh` (Python, `.sh` name) |
| `/bin/bash skills/commit/gather.sh` | bash 3.2.57 | 1 | shipped path under 3.2 | `paths[@]: unbound variable` at line 65 |
| `python3 -m py_compile` on four `.py` files | Python 3.13.0 | 0 | shipped | Syntax only |
| `~/.claude/skills/hygiene/hygiene_check.py` | uv 0.6.14 / same file as `skills/hygiene/hygiene_check.py` | 1 | shipped | `FileNotFoundError: hygiene.yaml` |
| `python3 skills/docs/link-check.sh .` | Python 3.13.0 | 1 | shipped | 23 broken links in 6 files (49 scanned) |
| `ruff check` on Python | ruff 0.15.20 | 0 | auxiliary | All checks passed |
| `shellcheck -f gcc` on shell | ShellCheck 0.11.0 | 0/1 | auxiliary | SC2078 on `skills/_shared/memory-path.sh:33`; unused `secret_pattern` |
| `resolve({"make_target":"test"})` via `hygiene_check` | Python 3.13.0 | n/a | shipped | `FileNotFoundError: Makefile` |
| Reproduce `memory-path.sh` `[[ ... (( ensure )) ]]` | bash 5.3.15 | 0 | shipped | First branch taken even when `ensure=0` and dir missing |

Not run (unavailable or out of policy): jscpd (not installed; not added). No pytest suite exists to run. No CI job exists to invoke.

Limitations: clone detection is manual. Coverage of every `SKILL.md` prose path is sampling, not exhaustive. Remote GitHub 404s decide "no workflows / no protection" for this clone's credentials.

## Observed architecture

### Declared

- Git mirror of `~/.claude/skills/` via `/republish-skills` (`skills/republish-skills/SKILL.md`, `cvfile`).
- Global `CLAUDE.md` is a Claude adapter over shared `AGENTS.md` (`CLAUDE.md:3`, `CLAUDE.md:5-6`).
- Per-skill directory with `SKILL.md` front matter; optional `worker.md` and companion scripts.
- Intent ledger: `bullseye.yaml` at repo root. `/target` skill text still names `docs/targets.yaml`.
- License: README says Apache-2.0.

### Observed

```
~/.claude/skills/  (canonical live install; not this repo)
        │  rsync --exclude='.*' --delete   (cvfile !publish)
        ▼
skills/<name>/SKILL.md [+ scripts]
CLAUDE.md  ← cp ~/.claude/CLAUDE.md     (AGENTS.md not copied)
convergence.md ← cp ~/.claude/convergence.md
README.md  ← generated from first `description:` line
        │  git add -A && commit && git push   (current branch)
        ▼
GitHub marcelocantos/skills
  default branch master (20 commits behind this HEAD)
```

Runtime entry points are **agent-invoked paths**, not a compiled binary: `~/.claude/skills/<skill>/…` (hardcoded in SKILL.md) and `cvfile`'s `!publish`. Python tools are uv-run scripts with inline `pyyaml`. There is no package graph, lockfile, Makefile, or `.github/workflows`.

Dependency direction (intended, and mostly held):

- Skills do not import each other as code. Cross-skill coupling is **prose delegation** (`/release` → `discover.sh`; `/cv` → bullseye MCP; `/docs` → `worker.md` + `link-check.sh`; `/entropy-audit` → `/hygiene`).
- Shared executable code is only `skills/_shared/memory-path.sh`.
- `hygiene_portfolio.py` imports `hygiene_check.py` (same directory).

### Declared and observed agree

- One directory per user-invocable skill with a `SKILL.md`.
- Publish is a snapshot, not an in-place working tree for Claude/Grok (agents edit `~/.claude/skills/`).
- `set -euo pipefail` on most bash; POSIX `set -e` on a few `#!/bin/sh` gathers.

### Observed, inferred from code

- `cvfile` is the real publisher; `publish.sh` is a four-line `cv -C` wrapper.
- README is generated and will rot whenever publish is skipped (it already has).
- `skills/docs/targets.md` is leftover ledger markdown inside the docs skill, not a docs-skill spec.

### Contradictions

- `CLAUDE.md:3` `@AGENTS.md` — file absent from this repo; `cvfile:8-9` copies only `CLAUDE.md` and `convergence.md`.
- `skills/target/SKILL.md:9` names `docs/targets.yaml`; this repo and the modern bullseye CLI use `bullseye.yaml`.
- `skills/cv/SKILL.md:38-41` says the historical full-tier gather evaluation is gone; `bullseye.yaml` 🎯T1 still requires scan/default/full gather-script budgets and remains `converging`.
- `skills/docs/targets.md` marks 🎯T1 achieved and 🎯T2 as the design report; root `bullseye.yaml` has T1 `converging` and T2 as scale calibration (design report is T3).
- README Apache-2.0 vs no `LICENSE` vs GitHub `license: null`.
- GitHub default `master` is not the latest published snapshot.

### Unknown intent (owner)

- Is `unify-skills-single-tree` supposed to become `master`, or is `master` a frozen public cut?
- Should `AGENTS.md` be published here, or should `CLAUDE.md` stop claiming to be an adapter?
- Are `/expenses` and `/remind` meant to be public with workplace email and Slack/RemoteTrigger identifiers?

## Dimension vector

| Dimension | State | Evidence summary | Change from baseline |
|---|---|---|---|
| Architecture topology | concern | Skill-per-directory is coherent; publish topology yields three disagreeing snapshots (live / this branch / `master`). | n/a (first full audit) |
| Redundancy / sources of truth | concern | Live install vs git tree vs `master`; `bullseye.yaml` vs `skills/docs/targets.md`; `CLAUDE.md` vs missing `AGENTS.md`; README vs SKILL.yaml. | n/a |
| Change amplification | concern | `release/discover.sh` is 796 lines with no tests; unpublished ledger-walk was copied into two canonical scripts; every skill edit needs a whole-tree republish. | n/a |
| Local code quality | concern | ruff clean; `commit/gather.sh` dies on bash 3.2; `memory-path.sh` `ensure` flag is a constant inside `[[ ]]`. | n/a |
| Correctness / verification | concern | Zero tests, zero CI. `hygiene_check.py` and gather scripts are fleet-facing with only `py_compile` / `bash -n`. | n/a |
| Security / dependencies | concern | No leaked keys found. Public repo publishes work email, Slack user id, RemoteTrigger UUIDs. No secret-scan CI. uv inline deps are pinned only by name. | n/a |
| Build / release / operations | concern | No workflows, no tags, no releases, unprotected `master`. `cvfile` `git add -A && git push` on whatever branch is checked out. | n/a |
| Documentation / governance | concern | Hygiene undeclared. `@AGENTS.md` dangling. LICENSE missing. README folded-scalar descriptions render as `>`. | n/a |

Do not aggregate these into a scalar.

## Findings

### ENT-001: Three snapshots of the skill tree already disagree

- **Priority:** P1
- **Dimensions:** Architecture topology; Redundancy / sources of truth; Change amplification; Build / release / operations
- **Status:** observed fact
- **Evidence:**
  - `rsync -ani --exclude='.*' --delete ~/.claude/skills/ skills/` (exit 0) lists new `entropy-audit/` (`SKILL.md`, `agents/openai.yaml`, `references/audit-lenses.md`, `references/report-contract.md`) and content diffs in `commit/SKILL.md`, `commit/gather.sh`, `hygiene/SKILL.md`, `oracle-first/SKILL.md`, `push/SKILL.md`, `push/preflight.sh`.
  - Canonical `commit/gather.sh` (mtime 2026-08-19) adds a `# ledger` walk for dirty `bullseye.yaml`; repo copy (mtime 2026-04-12) lacks it.
  - `git rev-list --count master..HEAD` = 20. `master` = `7051f6f` (2026-07-12). HEAD = `1f7de00` (2026-08-16).
  - `cvfile:3-7` rsyncs the whole install tree; `cvfile:46-47` commits and `git push`es the current branch, not `master`.
- **Mechanism:** the git repo is not the working trunk. Skill edits land in `~/.claude/skills/` and reach GitHub only when someone runs `!publish`. That command pushes the checked-out branch. GitHub's default branch can lag both the live tree and the last publish branch. Consumers of `https://github.com/marcelocantos/skills` therefore do not see `entropy-audit` or the bullseye-ledger commit rail.
- **Blast radius:** any clone, fork, or agent that treats GitHub as the skill source; future `/republish-skills` on the wrong branch; comparisons of "what's published" vs "what agents run".
- **Counterevidence checked:** `republish-skills/SKILL.md` documents this as a sync-to-GitHub dump, so dual trees are intentional. Intent does not make the three-way lag false. `rsync --delete` does converge when publish actually runs.
- **Smallest coherent remediation:** make publish a fast-forward onto `master` (or retarget default branch to the publish branch); add an exclude list (`__pycache__`, `docs/targets.md` debris); fail publish if HEAD is not the default branch unless overridden.
- **Verification:** `rsync -ani --exclude='.*' --delete ~/.claude/skills/ skills/` is empty after publish; `git rev-parse origin/master` equals the publish commit; `test -d skills/entropy-audit`.
- **Ratchet candidate:** `command:` evidence that the rsync dry-run is empty, plus a CI job on `master` listing expected skill directories from a frozen manifest.

### ENT-002: Published CLAUDE.md @imports AGENTS.md that is never copied

- **Priority:** P1
- **Dimensions:** Redundancy / sources of truth; Documentation / governance
- **Status:** observed fact
- **Evidence:**
  - `CLAUDE.md:3` `@AGENTS.md`
  - `CLAUDE.md:5-6` "Shared rules live there"
  - `CLAUDE.md:106` markdown link `AGENTS.md` (also reported by `link-check.sh`: `CLAUDE.md:106: broken link: AGENTS.md`)
  - `cvfile:8-9` copies only `~/.claude/CLAUDE.md` and `~/.claude/convergence.md`
  - `diff -u CLAUDE.md ~/.claude/CLAUDE.md` is non-empty: repo still says "Target lifecycle rides the **PR**" (`CLAUDE.md:124`); live file (2026-08-19) says it rides the **commit** and that `/push` refuses a dirty `bullseye.yaml`. Live file also adds the `journeys.md` bullet.
  - `ls AGENTS.md` → no such file
- **Mechanism:** the adapter file is published without its source of truth. A GitHub clone, or any tool that does not expand `~/.claude/` `@` imports against the author's home directory, is missing the shared hard rules. The copied adapter is already stale relative to the live file, so even a reader who has both sees mixed doctrine (PR-lifecycle vs commit-lifecycle).
- **Blast radius:** every agent using this repo's `CLAUDE.md` as project instructions; anyone auditing hard rules from GitHub.
- **Counterevidence checked:** Claude Code expands `@AGENTS.md` from `~/.claude/` when this file is loaded as a global, not as the git copy. That protects the author's live Claude. It does not protect GitHub consumers or Grok's ingest of the repo file.
- **Smallest coherent remediation:** copy `AGENTS.md` in `cvfile` (and keep it in sync), or stop publishing a global adapter here and ship a repo-local `AGENTS.md` that does not `@import` a missing file.
- **Verification:** `link-check.sh` no longer reports `AGENTS.md`; `diff CLAUDE.md ~/.claude/CLAUDE.md` empty after publish.
- **Ratchet candidate:** `file: {path: AGENTS.md}` plus a publish-time `diff` against `~/.claude/AGENTS.md`.

### ENT-003: Public Apache-2.0 claim with no LICENSE file

- **Priority:** P2
- **Dimensions:** Documentation / governance; Security / dependencies
- **Status:** observed fact
- **Evidence:**
  - `README.md:32-34` `## License` / `Apache-2.0`
  - `cvfile:37` hardcodes that footer in the generator
  - `ls LICENSE LICENSE.md COPYING` → none; `git log --all -- LICENSE` empty
  - `gh api repos/marcelocantos/skills` → `"license": null`, `"visibility": "public"`
  - `skills/open-source/SKILL.md:37-47` requires an Apache 2.0 LICENSE before going public
  - `skills/release/SKILL.md:196-199` calls a missing root licence file a **blocker**; `link-check.sh` reports `skills/release/SKILL.md:199: broken link: LICENSE`
- **Mechanism:** SPDX is asserted in README prose only. GitHub cannot classify the repo. The repo's own open-source and release skills would halt a release of this tree. Downstream copies have no grant text.
- **Blast radius:** public consumers, GitHub licence API, any `/release` of this repo.
- **Counterevidence checked:** no other licence file under another name. Apache-2.0 is the fleet default (`skills/open-source/SKILL.md:13`); the gap is the file, not the choice.
- **Smallest coherent remediation:** add the canonical Apache-2.0 `LICENSE` at the root (via `/sync-globals` `--license` if desired) and keep the README mention.
- **Verification:** `test -f LICENSE`; GitHub `license.spdx_id == Apache-2.0`; `link-check.sh` silent on that link.
- **Ratchet candidate:** hygiene `file: {path: LICENSE, matches: Apache}`.

### ENT-004: Fleet-facing scripts have no tests, no CI, no branch protection

- **Priority:** P2
- **Dimensions:** Correctness / verification; Build / release / operations
- **Status:** observed fact
- **Evidence:**
  - `find` for `*test*` / `test_*` / `*_test.*` → none
  - `ls .github/workflows` → directory absent; `gh api .../contents/.github/workflows` → 404
  - `gh api .../branches/master/protection` → "Branch not protected"
  - Executable surface: `skills/hygiene/hygiene_check.py` (331 lines), `hygiene_portfolio.py` (116), `release/discover.sh` (796), `sync-globals/fix-repo.sh` (494), `progress-report/gather.sh` (446), plus push/commit gathers
  - `python3 -m py_compile` passes; `ruff check` passes; neither is wired to CI
  - `git tag` empty; `gh release list` empty
- **Mechanism:** agents invoke these scripts as the shipped path across the fleet (`~/.claude/skills/...`). A regression is discovered only when a skill run fails in a live session. `discover.sh` in particular concentrates every `/release` probe in one untested file; a missed section silently omits a discovery field.
- **Blast radius:** every repo's `/commit`, `/push`, `/release`, `/hygiene`, `/progress-report`.
- **Counterevidence checked:** ruff is clean (no static Python defects of the kinds it flags). Most shell scripts `set -euo pipefail`. These are not substitutes for behaviour tests. This repo is a skill dump, not a product binary — still, the Python validator is a real program with a fleet aggregator.
- **Smallest coherent remediation:** pytest for `hygiene_check.resolve` / `held_tier` / missing-file CLI; a macOS workflow that runs those tests and `bash -n` / a bash-3.2 job for `*.sh` with `#!/usr/bin/env bash`.
- **Verification:** CI job on `master` required and green; `pytest` fails if `make_target` hits a missing Makefile without a structured error.
- **Ratchet candidate:** hygiene `ci_job:` once a workflow exists; until then the honest state is undeclared (see Hygiene posture).

### ENT-005: `/commit` gather is not bash 3.2-safe despite `env bash`

- **Priority:** P2
- **Dimensions:** Local code quality; Correctness / verification
- **Status:** observed fact
- **Evidence:**
  - `skills/commit/gather.sh:1` `#!/usr/bin/env bash`
  - `skills/commit/gather.sh:10` `set -euo pipefail`
  - `skills/commit/gather.sh:65` `git diff --cached --stat -- "${paths[@]}"` — under `/bin/bash` 3.2.57 with no args: `line 65: paths[@]: unbound variable` (exit 1)
  - `skills/commit/gather.sh:110-113` `mapfile -t`
  - `skills/commit/gather.sh:149` `bn_lower="${bn,,}"`
  - `/bin/bash -c 'bn=FOO; echo ${bn,,}'` → `bad substitution`
  - Host: `/bin/bash` 3.2.57, `env bash` 5.3.15
  - `skills/release/SKILL.md:226-257` requires a macOS bash 3.2 CI job for distributed shell; this repo has none
  - `shellcheck` SC2034: `secret_pattern` at `skills/commit/gather.sh:145` is unused
- **Mechanism:** empty-array `"${arr[@]}"` under `set -u` is unbound on bash <4.4. Even if that were guarded, `mapfile` and `${var,,}` are bash 4+. The shebang hides this on the author's Mac because Homebrew bash 5 is first on `PATH`. Any invocation that actually uses `/bin/bash` (CI macOS runner, `bash` wrapper, PATH without Homebrew) aborts `/commit` before secret scanning.
- **Blast radius:** `/commit` in every repo; similar patterns may exist in other `env bash` scripts not exercised under 3.2 in this audit (residue).
- **Counterevidence checked:** `env bash` on this machine is 5.3, so the author's default path works. `bash -n` does not catch `mapfile` or empty-array `-u`. POSIX gathers (`target/gather.sh`, `waw/gather.sh`, `pr-audit/gather.sh`) do not use these constructs.
- **Smallest coherent remediation:** use `${paths[@]+"${paths[@]}"}`, replace `mapfile` with a `while read` loop, replace `${bn,,}` with `tr`. Add the bash 3.2 CI job the release skill already specifies.
- **Verification:** `PATH` with `/bin/bash` shimmed as `bash`; `./skills/commit/gather.sh` exits 0 in this repo.
- **Ratchet candidate:** the macOS bash-3.2 job from `skills/release/SKILL.md:250-257`.

### ENT-006: hygiene_check.py cannot describe "undeclared" and crashes on missing Makefile

- **Priority:** P2
- **Dimensions:** Local code quality; Correctness / verification
- **Status:** observed fact
- **Evidence:**
  - `skills/hygiene/hygiene_check.py:237` `doc = yaml.safe_load(doc_path.read_text())` with no existence check
  - `skills/hygiene/hygiene_check.py:272-283` CLI defaults to `./hygiene.yaml` then calls `check_repo`
  - Running `~/.claude/skills/hygiene/hygiene_check.py` in this repo: `FileNotFoundError: .../hygiene.yaml` (exit 1, traceback)
  - `skills/hygiene/hygiene_check.py:120-124` `make_target` does `(ctx.root / "Makefile").read_text()`; `resolve({"make_target":"test"})` here → `FileNotFoundError: .../Makefile`
  - `skills/hygiene/hygiene_check.py:128-129` `command` evidence: `subprocess.run(..., shell=True, timeout=120)`
- **Mechanism:** the validator that other repos use to declare posture does not have a first-class "no hygiene.yaml" outcome. Missing Makefile is an uncaught exception rather than `ok=False`. `shell=True` on `command:` evidence will execute whatever string a `hygiene.yaml` contains.
- **Blast radius:** every `/hygiene` invocation; fleet `hygiene_portfolio.py` already catches per-repo exceptions (`skills/hygiene/hygiene_portfolio.py:55-58`) so the portfolio degrades, but the single-repo CLI does not.
- **Counterevidence checked:** `hygiene_portfolio.py` swallows errors per repo. `command:` is documented as "runs in the repo root". No `hygiene.yaml` in *this* repo means `make_target` is not hit in production here; the crash is still in the shipped function.
- **Smallest coherent remediation:** if the file is missing, print `hygiene posture not declared` and exit 2 (distinct from drift). Guard `Makefile` reads. Avoid `shell=True` or restrict `command:` to an argv list.
- **Verification:** `hygiene_check.py` in a directory without `hygiene.yaml` exits 2 with one line, no traceback; a unit test for missing Makefile returns `(False, "no Makefile")`.
- **Ratchet candidate:** pytest on those two cases, once tests exist (ENT-004).

### ENT-007: Publish README regex and `git add -A` amplify every skill-front-matter mistake

- **Priority:** P2
- **Dimensions:** Change amplification; Documentation / governance; Build / release / operations
- **Status:** observed fact
- **Evidence:**
  - `cvfile:21` `re.search(r'^description:\s*(.+)$', text, re.MULTILINE)` takes the first line only
  - `skills/demo/SKILL.md:3`, `skills/expenses/SKILL.md:3`, `skills/remind/SKILL.md:3` use YAML `description: >`
  - `README.md:13`, `16`, `24` render as `— >`
  - `skills/sync-globals/SKILL.md:3` `description: sync-globals` → `README.md:26` is the skill name only
  - `cvfile:41-47` `git add -A` then `git commit` then `git push`
- **Mechanism:** folded YAML scalars are valid skill front matter (Claude reads the folded block). The publisher's first-line regex is a second parser that disagrees. `git add -A` will stage whatever is in the worktree (including an in-progress audit report, local debris rsync copied, or `__pycache__` if excludes ever change) and push it.
- **Blast radius:** README as the public catalogue; every publish commit; accidental ship of unrelated dirty files.
- **Counterevidence checked:** rsync `--exclude='.*'` drops dotfiles. Global gitexcludes drop `__pycache__` today. Skills with a single-line `description:` catalogue correctly.
- **Smallest coherent remediation:** parse YAML front matter (or strip `>` / `|` and join the folded block); `git add` an explicit path list (`skills/`, `CLAUDE.md`, `AGENTS.md`, `convergence.md`, `README.md`); never `git add -A`.
- **Verification:** README lines for demo/expenses/remind contain real sentences; a dirty untracked file outside that list is not in `git diff --cached` after a dry-run publish.
- **Ratchet candidate:** `command:` that greps README for `— >` and fails if found.

### ENT-008: Competing target ledgers and stale bullseye path names

- **Priority:** P2
- **Dimensions:** Redundancy / sources of truth; Change amplification
- **Status:** observed fact
- **Evidence:**
  - `bullseye.yaml:3-6` 🎯T1 status `converging`; `bullseye.yaml:88-91` T2 is "Value and cost scales are calibrated…"; `bullseye.yaml:98-106` T3 is the design report, `achieved`
  - `skills/docs/targets.md:7` Active `(none)`; `skills/docs/targets.md:11-33` 🎯T1 **achieved** 2026-03-04; `skills/docs/targets.md:122-133` 🎯T2 is the design report
  - `skills/docs/targets.md:3` `last-evaluated: fd98e65`
  - `skills/target/SKILL.md:8-10` "The source of truth is `docs/targets.yaml`; `docs/targets.md` is an auto-rendered view"
  - `skills/cv/SKILL.md:228` "No `targets.yaml` found"
  - `cvfile:6` rsync copies `~/.claude/skills/docs/targets.md` into the published skill
- **Mechanism:** two ledgers describe the same IDs with different status and different T2 identity. Agents following `/target` still look for `docs/targets.yaml`. The docs-skill directory is a published skill, so a stale markdown ledger rides along forever unless excluded. A fix to T1 in `bullseye.yaml` does not update `skills/docs/targets.md`, and vice versa.
- **Blast radius:** `/cv` and `/target` on this repo; any consumer of the docs skill who treats `targets.md` as an example.
- **Counterevidence checked:** 🎯T1 remaining `converging` in `bullseye.yaml` is consistent with `skills/cv/SKILL.md:38-41` (old gather-tier acceptance is obsolete). That is healthy tracking in the *root* ledger. The defect is the second copy plus the wrong path in the skill text.
- **Smallest coherent remediation:** delete `skills/docs/targets.md` from the install tree (or rsync-exclude it); change `/target` and `/cv` prose to `bullseye.yaml`; refresh 🎯T1 acceptance to the thin-shim `/cv` that actually exists, then achieve or rewrite T1.
- **Verification:** `rg -n 'docs/targets.yaml' skills/` empty; `test ! -f skills/docs/targets.md`; 🎯T1 acceptance matches `cv/SKILL.md`.
- **Ratchet candidate:** rsync exclude for `targets.md` under skill dirs; test that `/target` SKILL.md mentions `bullseye.yaml`.

### ENT-009: memory-path.sh `--ensure` is a constant inside `[[ ]]`

- **Priority:** P2
- **Dimensions:** Local code quality; Correctness / verification
- **Status:** observed fact
- **Evidence:**
  - `skills/_shared/memory-path.sh:33` `if [[ -n "$grok_dir" && ( -d "$grok_dir" || (( ensure )) ) ]]; then`
  - `shellcheck -f gcc` → `skills/_shared/memory-path.sh:33:48: error: This expression is constant. Did you forget a $ somewhere? [SC2078]`
  - Reproduction: `ensure=0; grok_dir=/nonexistent/grok` with the repo condition prints `FIRST_BRANCH`; the intended `{ [[ -d ]] || (( ensure )); }` prints `intended_NOT_FIRST`
- **Mechanism:** inside `[[ ]]`, `(( ensure ))` is grouping plus the literal word `ensure`, which is always true. When `python3` exists, `grok_dir` is always set, so the Claude fallback (`skills/_shared/memory-path.sh:35-36`) is dead. `--ensure` does not change the branch; it only affects the later `mkdir`.
- **Blast radius:** any skill using `_shared/memory-path.sh` for session memory when a Grok session directory is absent.
- **Counterevidence checked:** in *this* cwd the Grok session dir exists, so the live run prints a real path. The bug is latent here, not hypothetical — the parse is constant.
- **Smallest coherent remediation:** `if [[ -n "$grok_dir" ]] && { [[ -d "$grok_dir" ]] || (( ensure )); }; then`
- **Verification:** with `ensure=0` and a missing grok dir, script prints the Claude path if that dir exists; `shellcheck` SC2078 gone.
- **Ratchet candidate:** `shellcheck -S error` on `skills/_shared/*.sh` in CI.

### ENT-010: Public skill dump contains workplace and messaging identifiers

- **Priority:** P2
- **Dimensions:** Security / dependencies; Documentation / governance
- **Status:** observed fact
- **Evidence:**
  - `skills/expenses/SKILL.md:17-22` CBA work mailbox `marcelo.cantos@cba.com.au`, personal Gmail
  - `skills/remind/SKILL.md:84-88` Slack user id `U033G8GU0`, Slack MCP connector UUID, `environment_id`, routine model names
  - Repo is public (`gh api` visibility)
  - `skills/open-source/SKILL.md:35` flags internal references as pre-publication audit items
- **Mechanism:** skills that are useful because they encode *this owner's* constants were rsynced into a public GitHub repo. These are not API keys; they are stable identifiers that belong in a private overlay, not in the published catalogue.
- **Blast radius:** public GitHub; anyone searching the repo; future copies of `/expenses` and `/remind`.
- **Counterevidence checked:** no `ghp_`, `sk-`, PEM, or 1Password secret values found. `op://Personal/GitHub Homebrew Tap PAT/token` in `/release` is a 1Password item path, not a credential. The author may have accepted this as a personal public dump — that is owner residue, not a reason to omit the fact.
- **Smallest coherent remediation:** move mailbox, Slack, and RemoteTrigger constants to an untracked local overlay (or a private sibling repo) and keep the skill logic public; or make this GitHub repo private.
- **Verification:** `rg` for `@cba.com.au` and `U033G8GU0` empty in the published tree.
- **Ratchet candidate:** `command:` `rg` over those literals in CI if the repo stays public.

### ENT-011: `skills/worker.md` is an invocable skill that the catalogue cannot see

- **Priority:** P3
- **Dimensions:** Architecture topology; Documentation / governance
- **Status:** observed fact
- **Evidence:**
  - `skills/worker.md:1-4` YAML front matter `user-invocable: true` but no `name:` and not a `SKILL.md` in a directory
  - `cvfile:15-18` catalogues only `skills/<dir>/SKILL.md`
  - `skills/worker.md:8-14` hardcoded `/Users/marcelo/think/claude-broker/claude-broker`
- **Mechanism:** the file is in the published tree and looks like a skill, but README generation skips it. Callers must already know `/worker`. The absolute home path will not work for anyone else.
- **Blast radius:** discoverability of `/worker`; public leak of a host-local broker path (low sensitivity).
- **Counterevidence checked:** other skills with `worker.md` keep `SKILL.md` as the entry (`docs`, `retro`, `waw`, `sync-globals`). This one is the odd layout.
- **Smallest coherent remediation:** move to `skills/worker/SKILL.md` or drop `user-invocable` and treat it as a private note excluded from rsync.
- **Verification:** README lists `/worker` or the file is gone from `skills/`.
- **Ratchet candidate:** publish check that every `user-invocable: true` file is `skills/*/SKILL.md`.

## Redundancy and competing-source-of-truth inventory

| Fact | Copies | Drift already? | Owner that should win |
|---|---|---|---|
| Skill definitions | `~/.claude/skills/` vs `skills/` vs GitHub `master` | Yes (ENT-001) | Live install, with git as a publish artifact — or invert and develop in git |
| Agent hard rules | `~/.claude/AGENTS.md` vs repo `CLAUDE.md` `@AGENTS.md` | Yes; AGENTS.md unpublished (ENT-002) | `AGENTS.md`; CLAUDE.md adapter only |
| CLAUDE.md body | live `~/.claude/CLAUDE.md` vs repo `CLAUDE.md` | Yes, 2026-08-16 vs 2026-08-19 | live file, copied on publish |
| Skill catalogue | `SKILL.md` `description:` vs `README.md` | Yes, `>` and `sync-globals` (ENT-007) | SKILL.md; README generated by a real YAML parse |
| Targets for this repo | `bullseye.yaml` vs `skills/docs/targets.md` | Yes (ENT-008) | `bullseye.yaml` |
| Ledger path in skills | `bullseye.yaml` vs documented `docs/targets.yaml` | Yes (ENT-008) | `bullseye.yaml` |
| Licence | README Apache-2.0 vs missing LICENSE vs GitHub null | Yes (ENT-003) | `LICENSE` file |
| Bullseye dirty-ledger walk | unpublished copies in canonical `commit/gather.sh` and `push/preflight.sh` | Not in this snapshot yet; will land as duplicated walks on next publish | One `_shared` helper |

Deliberate duplication to keep: per-skill `gather.sh` scripts (different sections, different consumers). Coupling them would mix `/commit` diffs with `/progress-report` gitstats.

## Healthy structure worth retaining

- One directory per skill with `SKILL.md` as the only catalogue entry — the rsync layout is understandable.
- uv-run Python with inline `requires-python` and `dependencies = ["pyyaml"]` (`skills/hygiene/hygiene_check.py:1-5`) — no repo venv to rot.
- `hygiene_check.py` dimension vector, `floors` ratchet, and `absent:` / `skipped` negative space are a sound design (the defects are CLI edge cases, not the model).
- `ruff check` clean on all four Python files.
- Most bash uses `set -euo pipefail`; POSIX gathers stay simple.
- `open-source` and `release` skills already encode "LICENSE file is a blocker" — reuse that, do not invent a second policy.
- `publish.sh` stays a four-line wrapper; logic lives in `cvfile`.
- `docs/reports/desired-state-convergence.md` exists and matches achieved 🎯T3.

## Hygiene posture

`hygiene.yaml` is **absent**. Hygiene posture not declared. No `hygiene.yaml` was created.

Validator invocation (mandatory):

```
$ /Users/marcelo/.claude/skills/hygiene/hygiene_check.py
Traceback (most recent call last):
  ...
  File ".../hygiene_check.py", line 237, in check_repo
    doc = yaml.safe_load(doc_path.read_text())
  ...
FileNotFoundError: [Errno 2] No such file or directory: '/Users/marcelo/work/github.com/marcelocantos/skills/hygiene.yaml'
exit=1
```

There are no held tiers or floors to report. The traceback is itself ENT-006.

Overlap: entropy findings ENT-003, ENT-004, ENT-001 are the items a future `hygiene.yaml` would declare (LICENSE, tests/CI, publish-sync). Do not treat this audit's finding list as that declaration.

Ratchet candidates from entropy (adopt only on request): LICENSE file evidence; bash-3.2 CI job; pytest for `hygiene_check`; rsync-dry-run-empty; README `— >` forbidden; `AGENTS.md` present.

## Oracle coverage and residue

| Property | Decided by | Result |
|---|---|---|
| Working tree clean at audit start | `git status --porcelain=v1 -b` | clean |
| Python syntax | `py_compile` | pass |
| Python lint | `ruff check` (auxiliary) | pass |
| Shell parse (bash 5) | `bash -n` | pass except misnamed `link-check.sh` |
| Shell parse/runtime (bash 3.2) | `/bin/bash skills/commit/gather.sh` | fail (ENT-005) |
| ShellCheck errors | `shellcheck` | SC2078 (ENT-009) |
| Mirror vs live install | `rsync -ani` | drift (ENT-001) |
| Local markdown links | `link-check.sh` | 23 breaks; many are `~/.claude/...` (expected for a copied global file) plus `AGENTS.md` and `LICENSE` |
| Hygiene floors | shipped `hygiene_check.py` | undeclared; CLI traceback |
| Clone percentage | jscpd | **not run** (not installed) |
| Test behaviour of hygiene_check / gather scripts | pytest / bats | **nothing** |
| GitHub workflows / protection | `gh api` | none |
| Secret values in tree | `rg` for key patterns | no tokens found; identifiers found (ENT-010) |

Owner residue (intent / taste only):

1. Should GitHub `master` be the publish target, or is this branch the public cut?
2. Should `AGENTS.md` be published, or should this repo stop carrying global directives?
3. Are `/expenses` and `/remind` constants accepted in a public repo?
4. Is bash 3.2 a required runtime for skill scripts, or is Homebrew bash 5 the contract?

Do not hand back "write tests" as owner residue; that is mechanical (ENT-004).

## Remediation sequence

1. **Oracle seam:** missing-file behaviour in `hygiene_check.py`; pytest for `resolve` / `held_tier`; bash 3.2 job that actually runs `commit/gather.sh`. Without these, later cleanups cannot be locked.
2. **Converge snapshots:** publish onto the GitHub default branch; copy `AGENTS.md`; exclude `__pycache__` and skill-dir `targets.md`; replace `git add -A` with an explicit path list; parse YAML descriptions for README.
3. **Converge ledgers:** delete `skills/docs/targets.md`; rename `docs/targets.yaml` in `/target` and `/cv` to `bullseye.yaml`; rewrite or achieve 🎯T1 against the thin-shim `/cv` that exists.
4. **Governance files:** add `LICENSE`; decide public-vs-private for PII skills (ENT-010).
5. **Local fixes that are now cheap:** `memory-path.sh` condition; bash 3.2 guards in `commit/gather.sh`; `make_target` missing Makefile.
6. **Ratchet** the accepted properties in CI and, when requested, a new `hygiene.yaml`. Do not author `hygiene.yaml` as part of this audit.
7. **Re-run** this audit on the same definitions (rsync dry-run empty; link-check `AGENTS.md`/`LICENSE`; bash 3.2 gather exit 0).
