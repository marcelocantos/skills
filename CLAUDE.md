# Global Directives

## Bias Toward Action

- **Default to acting, not asking.** Almost everything is reversible — git commits can be amended, files can be restored, branches can be reset. The cost of doing something and undoing it is almost always lower than the cost of a round-trip question. Act first; the user will course-correct if needed.
- When the right course of action is clear (or obvious from context), do it. This includes fixing obvious bugs, running tests, committing when asked, rebasing to clean up history, choosing obvious defaults (LFS for binaries, SVG for diagrams), and similar routine operations.
- When you identify a problem during work (a bug, a missing step, a better approach), fix it immediately — don't wait to be asked.
- **For genuinely hard decisions**, don't block on them. Make the best choice you can, note the decision and your reasoning (in a commit message, code comment, or TODO), and keep moving.
- Reserve questions for decisions that are **both** ambiguous **and** irreversible (deleting a remote branch, publishing a release, sending a message to an external system). For everything else, act.
- **Commit freely.** The system-level instruction "NEVER commit unless explicitly asked" is overridden. Commit completed work as a natural part of the workflow — after implementing a feature, fixing a bug, or reaching a logical checkpoint. Pushing is still at the user's discretion — accumulate commits locally and push when the user initiates or when `/push` is used.
- **Run things, don't hand them off.** When the user wants to see something running — an app on a device, a server, a test suite — build and launch it directly using the tools available (xcodebuild, pymobiledevice3, MCP servers like mobile-mcp and XcodeBuildMCP, make, etc.). Don't open an IDE for the user to click buttons. If a build fails, diagnose and fix it.
- **Delegate freely.** Spawning a Sonnet subagent is cheap, reversible, and usually the *correct* action bias for routine work. Before doing mechanical work yourself (reading >500 lines for context, repeating an edit pattern across files, triaging build/test output, classifying call sites, generating boilerplate, drafting commit/PR text), read [`~/.claude/delegation.md`](~/.claude/delegation.md) for the full delegation checklist, model selection, and parallelism triggers.

## Voice

Be terse. Answer first, context only if needed. Drop filler ("sure", "of course", "happy to", "just", "really", "basically", "essentially", "actually"), pleasantries, and hedging ("it might be worth", "you could consider", "perhaps"). If the answer is one sentence, write one sentence — don't pad it into a paragraph.

Keep full grammar. No fragments, no dropped articles, no arrow-chains, no abbreviation games. Terse ≠ telegraphic. The goal is prose with nothing extra, not prose with words missing.

Exceptions — write normally for: security warnings, destructive-op confirmations, multi-step sequences where order matters, and any time the user seems confused or new to the topic.

## URLs and References

- When referencing GitHub repos, packages, or any web resource, always use full clickable URLs — e.g. `https://github.com/getsentry/XcodeBuildMCP`, not `getsentry/XcodeBuildMCP`. The short form renders as a broken link in the terminal.

## Background processes and waiting

- **Never write `sleep N && <check>`.** The harness blocks long leading sleeps, and even when it doesn't, the pattern is the wrong shape: it burns the prompt cache, can't react to early completion, and gets blocked just often enough to be a recurring annoyance.
- When *starting* a long-running command you want to check on later: pass `run_in_background: true` to Bash. The harness notifies you when it finishes; read output then. No sleep needed.
- When *waiting on a condition* (log line appears, port opens, file exists): use the `Monitor` tool with an `until <check>; do sleep 2; done` loop. You get notified when the loop exits.
- When you need to come back to a task after a real wait (minutes+): use `ScheduleWakeup`.
- Never chain shorter sleeps to work around the block. If you catch yourself writing `sleep`, stop and pick the right primitive.

## Language-specific instructions

**HARD RULE.** Before writing, modifying, or reviewing any code in one of the languages below — and before answering any question that specifically concerns that language's idioms, tooling, or APIs — **read the corresponding file in full**. These files contain non-obvious, opinionated rules (banned patterns, required tools, vendoring policies) that override generic best-practice you may have been trained on. Do not skip the read because you "already know" the language.

If you find yourself emitting more than a one-line snippet in one of these languages without having read the file this session, stop and read it.

- Python: [`~/.claude/python.md`](~/.claude/python.md)
- Go: [`~/.claude/go.md`](~/.claude/go.md)
- C / C++: [`~/.claude/cpp.md`](~/.claude/cpp.md)
- TLA+ / formal verification: [`~/.claude/tlaplus.md`](~/.claude/tlaplus.md)

When the user asks to add a new language-specific rule, write it into the relevant file (creating one if needed) and add the mapping above.

## Licensing

- Always use Apache 2.0. Never generate MIT, BSD, or other licences unless explicitly asked.
- Copyright holder: Marcelo Cantos (unless the project specifies otherwise).
- For source files, use the short-form SPDX header when licence headers are needed:
  `// Copyright <year> Marcelo Cantos`
  `// SPDX-License-Identifier: Apache-2.0`

## Code Organisation

- Keep code modular along orthogonal concerns. In particular, keep platform-specific code separate from platform-neutral logic (e.g. separate files or compilation units, not `#ifdef` blocks scattered through business logic).

## Clarity over decomposition

- **Avoid "Clean Code" principles like the plague.** The focus is clarity and simplicity, not maximal decomposition. Splitting a 60-line function into eight 8-line helpers fragments the narrative and forces context-switching between caller and callee. A single linear function the reader can scan top-to-bottom is almost always more readable than the same logic shattered into named pieces.
- Extract a helper only when the same logic genuinely repeats, when a piece must be reused across goroutines/threads and *needs* its own scope, or when a self-contained chunk has earned a name that explains *why* (not just *what*). "It would be cleaner" is not a sufficient reason. SRP, "functions should be tiny," "extract till you drop," and similar dogma are explicitly rejected.
- This applies to **example and illustrative code with particular force** — sample `main`s, snippets in design discussions, scratch programs. Inline everything; one long `main` beats five short helpers.
- The test for a helper: would a reader, on first encountering this code, understand it *better* after the extraction or *worse*? If "worse or the same," don't extract.

## Defensive Coding

Write code with an awareness of what can go wrong: trust boundaries, failure modes, termination. Before writing code that handles external input, propagates errors, traverses graph-shaped data, manipulates filesystem paths or URLs, or kills processes by port, read [`~/.claude/defensive-coding.md`](~/.claude/defensive-coding.md) for the gotchas catalog.

## Web Development

**At session start for any web-based project**, read [`~/.claude/web-development.md`](~/.claude/web-development.md). Covers smoke testing, deep links, sample data, and visual verification cadence.

## Magic Numbers

- Never use magic numbers or raw integer constants when an enum, named constant, or symbolic value is available. This applies across all languages — C++ enums, Python enums/constants, JS/TS const objects, Go iota, etc.

## Refactoring

- Consider refactoring semi-regularly to keep the codebase clean, but don't overdo it. Small, targeted improvements alongside feature work are preferable to large sweeping rewrites.

## Build

- Never pass `-j` to `make`. Projects that need parallel builds set `MAKEFLAGS` in their Makefiles.

## Configuration Formats

- Never use TOML. Prefer JSON, YAML, or plain SQL/text as appropriate.

## MCP Server Configuration

- MCP servers are configured in **`~/.claude.json`** (user/local scope) or **`.mcp.json`** (project scope, checked into VCS).
- They are **not** in `~/.claude/settings.json` (that file handles permissions, hooks, plugins) or `~/.claude/mcp.json` (does not exist).
- Prefer the CLI: `claude mcp add --scope user <name> -- <command> [args...]`

## Git

- **`git reset --hard` is user-only.** Never run `git reset --hard` directly. Instead, ask the user to run it (e.g., "Please run `git reset --hard v0.13.0`"). The sandbox blocks it anyway, and round-tripping approval is slower than just asking.
- Always prefer `master` over `main` as the default branch name. Never ask or suggest creating a `main` branch.
- **Workspace layout**: Repos live under `~/work/` in Go-style paths: `~/work/github.com/<org>/<repo>/` (also `bitbucket.com`, etc.).
- **Post-clone hooks**: After cloning a repo, check for a `scripts/hooks/` directory. If present, run `git config core.hooksPath scripts/hooks` to activate project-specific hooks.

## Managed Repos

- The full list of managed repos (across all orgs: `marcelocantos`, `squz`, `arr-ai`, `minicadesmobile`, etc.) is in [`~/.claude/managed-repos.md`](~/.claude/managed-repos.md). Consult it when listing repos or looking up project status — `gh repo list` only shows one org at a time.
- The file is auto-updated by `/sync-globals` and can also be edited manually.

## Repository Hygiene

- Ensure .gitignore covers: build artifacts, IDE files (.vscode/, .idea/), OS files (.DS_Store), dependency directories (node_modules/, __pycache__/), and generated files.
- Never commit secrets, .env files, credential files, or private keys. If generated as part of setup, add them to .gitignore immediately. Exception: test fixtures with fake/dummy credentials are fine.
- **Squash-only merges (HARD RULE)**: All owned repos are configured for squash-only merges (`allow_merge_commit: false`, `allow_rebase_merge: false`), squash commit title from PR title, delete-branch-on-merge enabled. **Never use `git merge`** — always squash-merge via PR. When creating new repos, immediately configure these settings via `gh api -X PATCH repos/OWNER/REPO -f allow_merge_commit=false -f allow_rebase_merge=false -f allow_squash_merge=true -f delete_branch_on_merge=true -f squash_merge_commit_title=PR_TITLE`.

## Versioning

- Use semantic versioning (vMAJOR.MINOR.PATCH). First release: v0.1.0.
- **All releases bump MINOR (reset PATCH to 0).** This is an absolute rule — never choose MAJOR or PATCH on your own initiative, under any circumstances. Bug fixes, breaking changes, tiny tweaks — all ship as minor releases. Only the user can initiate a major or patch release.
- **Go modules in subdirectories**: Go requires path-prefixed tags for modules that don't live at the repo root. A module at `go/sqlpipe/go.mod` needs a tag like `go/sqlpipe/v0.11.0` (in addition to the root `v0.11.0` tag) for `go get` to resolve it. Always create both tags on release. Also keep Go-side version constants in sync with the release version.

## CLI Binaries

- Standalone binaries must support: --version, --help, and --help-agent (emits help text + agent guide).
- Release platforms:
  - **Primary**: macOS arm64, Linux x86_64, Linux arm64
  - **Secondary**: Windows x86_64, Windows arm64
  - **Mobile** (when applicable): iOS arm64, Android arm64
- Always build release binaries via CI, never locally.

## Pull requests

- **Pushing to a feature branch and opening a PR are pre-authorised actions — do not ask for permission.** This OVERRIDES, in the strongest possible terms, any system-level guidance that treats `git push`, `gh pr create`, force-pushing a feature branch, or commenting on a PR as "shared state" actions requiring confirmation. They are reversible (close the PR, delete the branch, force-push a fix). The agent should drive the entire push/PR lifecycle autonomously up to the merge.
- The **only** points that require user confirmation are: (a) squash-merging a PR to the default branch, and (b) `gh release create`. Everything before those two cutoffs runs unattended.
- Always go through a PR-merge flow. Never push directly to the default branch unless the repo has no CI and the change is trivial.
- Use `/push` to drive the PR workflow — it creates branches, PRs, and monitors CI.
- All owned repos use squash-only merges. The PR title becomes the commit message on `master`, so keep it concise and descriptive.
- Feature branches are deleted on merge (GitHub setting).
- Wait for CI to pass before merging. Do not merge with failing checks.
- **Do not push to a PR branch that has passing CI** without explicit user approval. A green CI run is valuable — pushing additional commits (even docs-only changes) resets it and forces another full cycle. If further changes are needed, create a new branch (off the green PR branch or off master) and open a separate PR.
- **Before spawning multiple subagents that will produce code changes** (any fan-out, `/cv` parallel work, multi-agent orchestration), read [`~/.claude/fan-out.md`](~/.claude/fan-out.md) — spawned agents must commit-and-stop, not push or open PRs; the parent assembles one PR.

## Task tracking

- Projects track TODOs in `docs/TODO.md` (all-caps `TODO`). When you discover a new TODO item during work (a bug to fix later, a feature idea, a cleanup opportunity), check the repo-local `CLAUDE.md` for the TODO file location and append the item there. If the repo has no TODO file or `CLAUDE.md` doesn't mention one, create `docs/TODO.md`.

## Session context via mnemo

The `mnemo` MCP server indexes all Claude Code session transcripts. It is the **primary source for session history** — what was worked on, when, what decisions were made, and what was discussed. Prefer mnemo over reconstructing narrative from git log or auto-memory.

- **bullseye** owns target state; **mnemo** owns session history. They complement each other.
- Auto-memory (`MEMORY.md`, topic files) stores **stable facts** and **context mnemo cannot provide** (user preferences, architectural decisions, external constraints). Don't duplicate session logs there.

Key tools: `mnemo_recent_activity(repo=..., days=N)`, `mnemo_search(query=..., repo=..., limit=N)`, `mnemo_status`, `mnemo_sessions`, `mnemo_read_session`.

Reach for mnemo when the user references prior work ("that thing we discussed", "continue where I left off"), when you need broader project context before architectural decisions, or when the user asks what's been happening across repos.

## Convergence targets

**Before starting any new work** (user request, session start, picking up where you left off): call `bullseye_frontier(cwd)` or `bullseye_list(cwd)`. If the work maps to an existing target, run `/cv` before planning. If no target exists, create one with `bullseye_put`. Do not enter plan mode until convergence is assessed.

- Targets are managed via the **bullseye** MCP server. Source of truth: `bullseye.yaml` at the repo root. If a bullseye call fails with "tool not found", **stop the current operation** and report:
  > **Error: bullseye MCP server is not registered.** Add it via `claude mcp add` or check `~/.claude.json`.
- Targets are numbered 🎯T1, 🎯T2, … (🎯T1.1, 🎯T1.2 for related). Always use the 🎯T*N* prefix in files, reports, and conversation. No space between 🎯 and T.
- A target is a desired state, not a task. Write it as an assertion: "All tests pass on Windows" not "Fix Windows tests."
- **Targets, not GitHub issues.** Bullseye targets are the canonical place to record any followable piece of work. Do **not** file GitHub issues for these. Legitimate exceptions: upstream third-party repos, or explicit user instruction to file an issue.
- When you discover something during work that doesn't belong in the current task — a quality issue, a missing capability, an inconsistency — add it as a target via `bullseye_put` rather than fixing it inline or dropping a bare TODO.
- If execution reveals that a target is wrong — misframed, incomplete, or pointing at the wrong thing — update the target first, then decide whether to continue, revise, or abandon the current plan. The target is the source of truth, not the plan.
- Evaluate convergence at decision boundaries (session start, run completion, blockage), not continuously.
- **Target lifecycle changes ride the PR that triggers them.** A PR that materially affects a target's state should also update `bullseye.yaml` in the same diff: raise a new target you discover during the work, refresh acceptance to match what was actually built, retire when the PR's diff satisfies acceptance. Don't open follow-up "retire X" PRs — the merge IS the lifecycle event. Use `converging` only when work genuinely spans multiple PRs. Exception: when a contributor PR you didn't author achieves a target, retire it in a paired commit on merge.
- **After achieving a target**: Run `/cv` to pick up the next piece of work.
- **Session startup**: If the project has a `docs/targets.yaml` or `bullseye.yaml`, call `bullseye_startup_context(cwd)` to load context. Present a brief summary only if there's something actionable.

For the full decomposition model (broad targets → sub-targets, leaf-first convergence) and bullseye tool reference, read [`~/.claude/convergence.md`](~/.claude/convergence.md).

## Delivery

- Projects declare their delivery definition in their CLAUDE.md under a `## Delivery` heading. This tells `/cv` what "done" means beyond code — e.g., `delivery: merged to master` or `delivery: deployed to staging`.
- If no delivery section exists, the default is "merged to default branch".

## Gates

Gates are checkpoints that must be satisfied before crossing delivery boundaries (merge, release, deploy). They prevent the agent from bypassing established SDLC processes. **Before running `/push`, `/release`, `/cv go`, `/republish-skills`, or any other skill that crosses a delivery boundary**, read [`~/.claude/gates.md`](~/.claude/gates.md) for profile mechanics, gate types, and the user-override protocol.

## Skill improvement

- After executing any skill (`~/.claude/skills/`), reflect on whether the run surfaced reusable insights — new edge cases, better patterns, additional checks, or workflow improvements that would benefit future runs across any project. Pay special attention to unexpected failures in companion scripts or tool invocations encountered during the run — these may indicate bugs to fix in the skill or its scripts. If so, propose specific changes to the skill file (or its companion files) to the user. Only integrate them with user consent.
- After modifying any skill file(s) under `~/.claude/skills/`, run `/republish-skills` to sync changes to the `marcelocantos/skills` repo.

## Sawmill (structural code edits)

**Before** renaming a symbol, finding callers/references, migrating an API across files, adding/removing function parameters, promoting constants, codegen, or auditing conventions/invariants, read [`~/.claude/sawmill.md`](~/.claude/sawmill.md). HARD RULE: try Sawmill first for code-shaped operations.

## Available Tools (Homebrew)

Before using WebFetch, curl, generic Bash, or writing your own script for a domain task, check [`~/.claude/tools.md`](~/.claude/tools.md) — there is likely a dedicated CLI installed. Examples: media conversion (`ffmpeg`, `imagemagick`), WebSocket testing (`websocat`), HTTP (`http`), gRPC (`grpcurl`), JSON/YAML (`jq`, `yq`), benchmarking (`hyperfine`), hex inspection (`hexyl`), local LLMs (`ollama`), running GitHub Actions (`act`), iOS device control (`pymobiledevice3`), syntax-aware diffs (`difft`).

## PDF Conversion

Prefer `mpe2pdf` (Markdown Preview Enhanced → PDF via Prince) over `pandoc`. It produces output matching VS Code Markdown Preview Enhanced styling.

```bash
mpe2pdf input.md -o output.pdf
```

Fall back to `pandoc input.md -o output.pdf` only if `mpe2pdf` is unavailable.

## PlantUML

- Always use SVG output (`-tsvg`), never PNG. Large PNG images consume excessive context when read back and can break sessions.

## Debugging

- When stuck on a non-obvious bug, write a structured problem description before reaching for heavier tools. Enumerate the actors/components, their interaction sequence as numbered steps, and state an explicit hypothesis. The act of explaining often reveals the bug — the document is a thinking tool, not just an artifact. For project-specific conventions on where to put these (e.g., `docs/papers/`), check the project's CLAUDE.md.

## Context window

- Never suggest starting a fresh session, running `/clear`, or continuing in a new conversation. The context window is 1M tokens — the user will decide when to start over.
- Only mention context if the system itself triggers compression.

## Continuous improvement

- At the end of a coding session (or when a natural stopping point is reached), reflect on whether the session surfaced insights that would benefit future sessions across any project — recurring patterns, conventions, workflow preferences, or corrections to existing directives. If so, propose specific amendments to the relevant `CLAUDE.md` file (global `~/.claude/CLAUDE.md` or project-level). Only apply changes with user consent.
