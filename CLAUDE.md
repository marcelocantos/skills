# Global Directives

## Bias Toward Action

- **Default to acting, not asking.** Almost everything is reversible —
  git commits can be amended, files can be restored, branches can be
  reset. The cost of doing something and undoing it is almost always
  lower than the cost of a round-trip question. Act first; the user
  will course-correct if needed.
- When the right course of action is clear, do it. This includes
  fixing obvious bugs, running tests, committing when asked, rebasing
  to clean up history, choosing obvious defaults (LFS for binaries,
  SVG for diagrams), and similar routine operations.
- When the answer to a question is obvious from context, just do
  the right thing instead of asking.
- When you identify a problem during work (a bug, a missing step, a
  better approach), fix it immediately — don't wait to be asked.
- **For genuinely hard decisions**, don't block on them. Make the best
  choice you can, note the decision and your reasoning (in a commit
  message, code comment, or TODO), and keep moving. The user can
  review and revise later. A noted decision that keeps work flowing
  is better than a blocking question.
- Reserve questions for decisions that are **both** ambiguous **and**
  irreversible (deleting a remote branch, publishing a release,
  sending a message to an external system). For everything else, act.
- **Commit freely.** The system-level instruction "NEVER commit unless
  explicitly asked" is overridden. Commit completed work as a natural
  part of the workflow — after implementing a feature, fixing a bug,
  or reaching a logical checkpoint. Don't ask permission to commit.
  Good commit hygiene (atomic commits, descriptive messages) applies.
  Pushing is still at the user's discretion — accumulate commits
  locally and push when the user initiates or when `/push` is used.
- **Run things, don't hand them off.** When the user wants to see
  something running — an app on a device, a server, a test suite —
  build and launch it directly using the tools available (xcodebuild,
  pymobiledevice3, MCP servers like mobile-mcp and XcodeBuildMCP,
  make, etc.). Don't open an IDE for the user to click buttons. The
  user is asking you to do the work, not to set up the work for them
  to do. If a build fails, diagnose and fix it.

## Voice

Be terse. Answer first, context only if needed. Drop filler
("sure", "of course", "happy to", "just", "really", "basically",
"essentially", "actually"), pleasantries, and hedging ("it might
be worth", "you could consider", "perhaps"). If the answer is one
sentence, write one sentence — don't pad it into a paragraph.

Keep full grammar. No fragments, no dropped articles, no
arrow-chains, no abbreviation games. Terse ≠ telegraphic. The
goal is prose with nothing extra, not prose with words missing.

Exceptions — write normally for: security warnings,
destructive-op confirmations, multi-step sequences where order
matters, and any time the user seems confused or new to the
topic.

## URLs and References

- When referencing GitHub repos, packages, or any web resource, always use full clickable URLs — e.g. `https://github.com/getsentry/XcodeBuildMCP`, not `getsentry/XcodeBuildMCP`. The short form renders as a broken link in the terminal.

**Before starting any new work**, check the project's targets via
`bullseye_frontier` and `bullseye_list`. If the work maps to an
existing target, run `/cv` before planning. If no target exists,
create one with `bullseye_add`. Do not enter plan mode until
convergence is assessed. See [Convergence targets](#convergence-targets)
for the full protocol.

## Python

- **`uv`** is the sole Python tool manager. Use it for everything:
  - `uv pip install <pkg>` — install into `~/.py` (the active venv)
  - `uv tool install <tool>` — install isolated CLI tools (replaces pipx)
  - `uv venv` — create per-project venvs with any Python version
- **`~/.py`** is the global daily-driver venv, activated in `~/.zshrc`.
  Its Python is uv-managed (lives in `~/.local/share/uv/python/`),
  not Homebrew — so `brew upgrade` can't break it.
- **Never use** pyenv, pipx, `brew install python`, or bare `pip install`
  (without `uv` prefix). These are not installed and should not be
  reintroduced.

## C++ Style and Dependencies

When working with C++ or adding dependencies, read
[`~/.claude/cpp.md`](~/.claude/cpp.md) for style conventions,
vendoring rules, and preferred libraries.

## JSON in C/C++

- **cJSON** for C and simple C++ JSON. Vendor as `vendor/cjson/`.
- **nlohmann/json** only when C++ ergonomics justify the compile cost.

## Licensing

- Always use Apache 2.0. Never generate MIT, BSD, or other licences unless explicitly asked.
- Copyright holder: Marcelo Cantos (unless the project specifies otherwise).
- For source files, use the short-form SPDX header when licence headers are needed:
  `// Copyright <year> Marcelo Cantos`
  `// SPDX-License-Identifier: Apache-2.0`

## Code Organisation

- Keep code modular along orthogonal concerns. In particular, keep platform-specific code separate from platform-neutral logic (e.g. separate files or compilation units, not `#ifdef` blocks scattered through business logic).

## Defensive Coding

Write code with an awareness of what can go wrong. Think about trust
boundaries (where does data come from?), failure modes (what if this
call fails?), and termination (can this recurse or loop forever?).

Common gotchas:

- **Trust boundaries**: Data from external sources (user input, config files,
  network responses, manifests from other repos) must be validated before use.
  File paths must not escape their intended directory; URLs must be well-formed;
  indices must be in range.
- **Error propagation**: Never silently discard errors from I/O, OS, or network
  operations. Check and propagate — or explicitly document why a discard is safe.
- **Termination**: Recursive traversals over graph-like structures need cycle
  guards (a visited set). Unbounded retries need a limit.
- **Right primitive**: Use string operations for logical formats (URLs, URIs,
  protocol fields) and filepath operations for OS paths. Don't mix them.
- **Resource hygiene**: Preserve file attributes (permissions, ownership) when
  rewriting. Close/clean up resources on all paths, including errors.
- **Port cleanup**: When killing processes to free a port, only kill the
  process **listening** on that port (i.e. the server), not every process
  that has an open connection to it. `lsof -iTCP:<port> -sTCP:LISTEN -t`
  returns only listeners. Never use `lsof -ti:<port> | xargs kill` — that
  kills clients too (browsers, database connections, etc.).

## Web Development

**At session start for any web-based project**, read
[`~/.claude/web-development.md`](~/.claude/web-development.md) and
follow its guidelines throughout the session. Covers smoke testing,
deep links, sample data, and visual verification cadence.

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

- The full list of managed repos (across all orgs: `marcelocantos`, `squz`, `arr-ai`, `minicadesmobile`, etc.) is in `~/.claude/managed-repos.md`. Consult it when listing repos or looking up project status — `gh repo list` only shows one org at a time.
- The file is auto-updated by `/sync-globals` and can also be edited manually.

## Repository Hygiene

- Ensure .gitignore covers: build artifacts, IDE files (.vscode/, .idea/), OS files (.DS_Store), dependency directories (node_modules/, __pycache__/), and generated files.
- Never commit secrets, .env files, credential files, or private keys. If generated as part of setup, add them to .gitignore immediately. Exception: test fixtures with fake/dummy credentials are fine.
- **Squash-only merges (HARD RULE)**: All owned repos are configured for squash-only merges (`allow_merge_commit: false`, `allow_rebase_merge: false`), squash commit title from PR title, delete-branch-on-merge enabled. **Never use `git merge`** — always squash-merge via PR. When creating new repos, immediately configure these settings via `gh api -X PATCH repos/OWNER/REPO -f allow_merge_commit=false -f allow_rebase_merge=false -f allow_squash_merge=true -f delete_branch_on_merge=true -f squash_merge_commit_title=PR_TITLE`.

## Versioning

- Use semantic versioning (vMAJOR.MINOR.PATCH). First release: v0.1.0.
- Default to minor releases (bump MINOR, reset PATCH). Patch releases are reserved for hotfixes to a specific minor release — never use them for regular forward progress. Only use major/patch when explicitly requested.
- **Go modules in subdirectories**: Go requires path-prefixed tags for
  modules that don't live at the repo root. A module at `go/sqlpipe/go.mod`
  needs a tag like `go/sqlpipe/v0.11.0` (in addition to the root `v0.11.0`
  tag) for `go get` to resolve it. Always create both tags on release.
  Also keep Go-side version constants in sync with the release version.

## CLI Binaries

- Standalone binaries must support: --version, --help, and --help-agent (emits help text + agent guide).
- Release platforms:
  - **Primary**: macOS arm64, Linux x86_64, Linux arm64
  - **Secondary**: Windows x86_64, Windows arm64
  - **Mobile** (when applicable): iOS arm64, Android arm64
- Always build release binaries via CI, never locally.

## Pull requests

- Always go through a PR-merge flow. Never push directly to the default branch unless the repo has no CI and the change is trivial.
- Use `/push` to drive the PR workflow — it creates branches, PRs, and monitors CI.
- All owned repos use squash-only merges. The PR title becomes the commit message on `master`, so keep it concise and descriptive.
- Feature branches are deleted on merge (GitHub setting).
- Wait for CI to pass before merging. Do not merge with failing checks.
- **Do not push to a PR branch that has passing CI** without explicit user approval. A green CI run is valuable — pushing additional commits (even docs-only changes) resets it and forces another full cycle. If further changes are needed, create a new branch (off the green PR branch or off master) and open a separate PR.

## Teams

- **Default to parallel.** Before starting any multi-step task, actively
  scan for independent workstreams. If two things don't depend on each
  other, run them in parallel — don't serialize. The cost of spawning
  an extra agent is far lower than the cost of sequential execution.
- **Recognition triggers** — if you see any of these, parallelise:
  - Multiple files/modules need the same kind of change
  - Research across 2+ independent areas (repos, docs, APIs)
  - A task has both investigation and implementation that can overlap
  - Tests/builds can run while you continue editing
  - Multiple independent subtasks in a plan
  - Reading/exploring several unrelated parts of a codebase
- Also use teams for:
  - **Bulk similar work** — when the same change pattern applies across multiple directories, modules, or files, fan out agents to handle subsets in parallel.
  - **Context isolation** — when heavy exploratory reads (audits, deep research) would bloat the main conversation context.
  - **Research fan-out** — when investigating multiple codebase areas or external sources before synthesising.
- **Worktree isolation**: Prefer `isolation: "worktree"` when spawning team agents that edit files. This prevents concurrent agents from clobbering each other's changes. Solo sequential work can stay on master (the `/push` skill creates feature branches at push time).
- Model selection:
  - **`opus`** — default for team agents; complex reasoning, architectural decisions, novel problem-solving.
  - **`sonnet`** — well-scoped and straightforward coding tasks that don't involve complex reasoning. Also good for bulk repetitive changes across modules and evaluating test/build failures.
  - **`haiku`** — monotonous tasks: file searches, mechanical find-and-replace, running builds/tests, and triaging failures (categorise, group, summarise). Hand off to `sonnet` for diagnosis and fix decisions.

## Audit log

- Skills that perform maintenance work (`/audit`, `/docs`, `/release`, `/open-source`) append entries to `docs/audit-log.md` in the repo. The `/waw` skill reads this log for its maintenance status section.
- Format spec: `~/.claude/skills/audit-log-convention.md`
- When a skill invokes another skill, only the parent logs — children skip to avoid double entries.

## Task tracking

- Projects track TODOs in `docs/TODO.md` (all-caps `TODO`). When you discover a new TODO item during work (a bug to fix later, a feature idea, a cleanup opportunity), check the repo-local `CLAUDE.md` for the TODO file location and append the item there. If the repo has no TODO file or `CLAUDE.md` doesn't mention one, create `docs/TODO.md`.

## Session context via mnemo

The `mnemo` MCP server indexes all Claude Code session transcripts.
It is the **primary source for session history** — what was worked on,
when, what decisions were made, and what was discussed. Skills should
prefer mnemo over reconstructing narrative from git log or auto-memory.

- **bullseye** owns target state (desired states, gap assessments,
  convergence). **mnemo** owns session history (what actually happened,
  decisions, context). They complement each other — don't use one to
  replace the other.
- `/waw` uses `mnemo_recent_activity` for its summary narrative and
  `mnemo_search` for key decisions, falling back to git log only if
  mnemo is unavailable.
- `/cv` uses `mnemo_recent_activity` to understand recent movement
  before evaluating gaps, reducing expensive codebase reads.
- `/wrap` writes only forward-looking context to MEMORY.md (targets
  affected, in-flight work, user preferences) — session narrative
  lives in mnemo, not auto-memory.
- Auto-memory (`MEMORY.md`, topic files) stores **stable facts** and
  **context mnemo cannot provide** (user preferences, architectural
  decisions that shape future work, external constraints). Don't
  duplicate session logs there.

Key tools:
- `mnemo_recent_activity(repo=..., days=N)` — recent work on a repo
- `mnemo_search(query=..., repo=..., limit=N)` — full-text search
- `mnemo_status` — server health and indexing state
- `mnemo_sessions`, `mnemo_read_session` — browse specific sessions

Good moments to reach for mnemo:
- The user references prior work ("that thing we discussed", "the
  approach from last session", "continue where I left off")
- You need to understand the broader context of a project before
  making architectural decisions
- `/waw` or `/cv` needs recent activity data
- The user asks what's been happening across repos

## Convergence targets

- Targets are managed via the **bullseye** MCP server. The source of
  truth is `docs/targets.yaml`; `docs/targets.md` is an auto-rendered
  view. Don't preflight-check whether bullseye is registered — just
  use its tools naturally. If a call fails with "tool not found" or
  "unknown tool", **stop the current operation** and report:
  > **Error: bullseye MCP server is not registered.**
  > Add it via `claude mcp add` or check `~/.claude.json`.
  Do not fall back to reading `docs/targets.md` directly.
- Use bullseye tools for all target operations:
  - `bullseye_frontier(cwd)` — unblocked targets ready for work
  - `bullseye_list(cwd)` — all targets with status
  - `bullseye_add(cwd, ...)` — create a new target
  - `bullseye_update(cwd, id, ...)` — change status or fields
  - `bullseye_retire(cwd, id)` — mark achieved
  - `bullseye_validate(cwd)` — check graph integrity
  - `bullseye_startup_context(cwd)` — session start context
- Targets are numbered 🎯T1, 🎯T2, … (🎯T1.1, 🎯T1.2, … for related
  targets). Always use the 🎯T*N* prefix when referring to targets —
  in files, reports, and conversation. No space between 🎯 and T.
- When you discover something during work that doesn't belong in the
  current task — a quality issue, a missing capability, an
  inconsistency — add it as a target via `bullseye_add` rather than
  fixing it inline or dropping a bare TODO.
- A target is a desired state, not a task. Write it as an assertion:
  "All tests pass on Windows" not "Fix Windows tests."
- Include enough context that a future agent in a fresh session can
  understand why the target matters and how to approach it.
- Mark the origin if it was discovered while working on another target
  (forked-from).
- When finishing a task, plan, or session, check whether any active
  targets were affected. Update status via `bullseye_update` if a
  target moved closer to or achieved its desired state.
- If execution reveals that a target is wrong — misframed, incomplete,
  or pointing at the wrong thing — update the target first, then decide
  whether to continue, revise, or abandon the current plan. The target
  is the source of truth, not the plan.
- Broad targets decompose into sub-targets. Don't plan against a
  composite target directly — decompose until each sub-target is
  independently achievable, then converge leaf-first. See
  [`~/.claude/convergence.md`](~/.claude/convergence.md) for the
  full decomposition model.
- Plans converge toward targets. If `/cv` suggests different work
  than an active plan, trust the convergence assessment.
- Evaluate convergence at decision boundaries (session start, run
  completion, blockage), not continuously. Within a coherent stretch of
  work toward a single target, don't re-evaluate — just work. After
  completing a small piece of work, update the target's status if
  appropriate; don't run a full `/cv` for every commit.
- **After achieving a target**: Run `/cv` to pick up the next piece of
  work. If the remaining context window is too small for a full
  evaluation and follow-on work, run `/cv scan` and present the
  recommendation, but suggest continuing in a fresh session rather
  than auto-executing.
- **On context compression**: When the system compacts the conversation,
  immediately run `/wrap` to update targets and capture learnings
  before state is lost. After `/wrap` completes, recommend `/clear`
  to start a fresh session.
- **Session startup**: At the start of every session, if the project
  has a `docs/targets.yaml`, call `bullseye_startup_context(cwd)` to
  load project context (frontier targets, recent achievements,
  warnings). For cross-project context, also call
  `mnemo_recent_activity()` to see recent session activity. Present
  a brief summary only if there's something actionable — don't dump
  raw output.
- **Workflow**: When starting new work (user request, session start, or
  picking up where you left off), call `bullseye_frontier` or
  `bullseye_list` first. If the work maps to an existing target,
  evaluate convergence before planning. If no target exists, create
  one with `bullseye_add`. Do not enter plan mode until the target is
  established and convergence is assessed.

## Delivery

- Projects declare their delivery definition in their CLAUDE.md under
  a `## Delivery` heading. This tells `/cv` what "done" means
  beyond code — e.g., `delivery: merged to master` or `delivery:
  deployed to staging`.
- If no delivery section exists, the default is "merged to default
  branch".

## Gates

- Gates are checkpoints that must be satisfied before crossing delivery
  boundaries (merge, release, deploy). They prevent the agent from
  bypassing established SDLC processes.
- Gate profiles live in `~/.claude/gates/`. Each profile extends
  `base.yaml` (or overrides specific base gates). Projects declare
  their profile in CLAUDE.md:
  ```
  ## Gates
  profile: game
  ```
- If no `## Gates` section exists, `base` gates apply by default.
- The agent reads `base.yaml` + the profile YAML and merges them.
  Profile gates add to base gates; `override: [gate: skip]` removes
  specific base gates.
- **Gate types**:
  - `automated` — agent checks itself (CI green, tests exist).
  - `routed` — agent delegates to a skill (`/push`, `/release`).
  - `manual` — agent pauses and asks the user to confirm. **The agent
    must never proceed past a manual gate without explicit user
    approval.**
- Available profiles: `base`, `game`, `library`, `cli`, `skill`.
- Skills that cross delivery boundaries (`/push`, `/release`,
  `/cv go`, `/republish-skills`) must check and enforce the
  project's gates before proceeding. `/cv` must never suggest
  raw delivery actions — always route through the appropriate skill.
- **User override**: Gates constrain the agent, not the user. If the
  user explicitly asks to skip a gate, honour that — but name the
  gate being skipped so the decision is conscious, not accidental.
  After a skip, offer to create a target to resolve the underlying
  issue (e.g., "🎯 CI is configured and green for this project").

## Skill improvement

- After executing any skill (`~/.claude/skills/`), reflect on whether the run surfaced reusable insights — new edge cases, better patterns, additional checks, or workflow improvements that would benefit future runs across any project. Pay special attention to unexpected failures in companion scripts or tool invocations encountered during the run — these may indicate bugs to fix in the skill or its scripts, not just one-off issues. If so, propose the specific changes to the skill file (or its companion files) to the user. Only integrate them with user consent. This keeps skills evolving from real-world usage.
- After modifying any skill file(s) under `~/.claude/skills/`, run `/republish-skills` to sync changes to the `marcelocantos/skills` repo.

## Available Tools (Homebrew)

When you need to check what CLI tools are available, read
[`~/.claude/tools.md`](~/.claude/tools.md). Covers network testing,
C/C++ build tooling, languages/runtimes, shell utilities, AI/ML,
media, containers/cloud, iOS device tooling, and formal verification.

## TLA+ / Formal Verification

When working on TLA+ specs or formal verification, read
[`~/.claude/tlaplus.md`](~/.claude/tlaplus.md) for state-space
bounding rules and verification tool guidance.

## PDF Conversion

Prefer `mpe2pdf` (Markdown Preview Enhanced → PDF via Prince) over `pandoc`.
It produces output matching VS Code Markdown Preview Enhanced styling.

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
