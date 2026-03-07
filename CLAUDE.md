# Global Directives

**Before starting any new work**, check the project's `docs/targets.md`
for convergence targets. If the work maps to an existing target, run
`/cv` before planning. If no target exists, create one first. Do
not enter plan mode until convergence is assessed. See
[Convergence targets](#convergence-targets) for the full protocol.

## Dependencies

- Favour header-only libraries over compiled ones when a suitable option exists.
- Prefer vendored submodules over homebrew installs where practicable.
- When bringing in third-party repos, submodule them into `vendor/github.com/<org>/<repo>` (or `bitbucket.com`, etc).
- When bringing in single `.h` libraries, put them in `vendor/include`.
- If there's an associated `.c`/`.cpp`, put it in `vendor/src`.
- Use spdlog for logging. Never use printf/fprintf for diagnostic output. Prefer the `SPDLOG_INFO`, `SPDLOG_WARN`, `SPDLOG_ERROR`, etc. macros over direct `spdlog::info`/`spdlog::error` calls, as the macros automatically include source file and line information.
- Preferred libraries (use these unless there is a strong reason not to):
  - **Rendering**: bgfx (with bx/bimg utilities)
  - **Windowing/input**: SDL3 (+ SDL3_image, SDL3_ttf)
  - **Logging**: spdlog (header-only)
  - **Linear algebra**: linalg.h (header-only)
  - **Testing**: doctest (header-only)
  - **Image I/O**: stb_image / stb_image_write (header-only)
  - **Triangulation**: earcut.hpp (header-only), Triangle (C library for quality meshes)
  - **Database**: SQLite3
- When vendoring third-party code, always include the dependency's original LICENSE file alongside it. For distributed projects, maintain a NOTICES file (or THIRD_PARTY if one already exists) with attribution for all bundled dependencies.

## Licensing

- Always use Apache 2.0. Never generate MIT, BSD, or other licences unless explicitly asked.
- Copyright holder: Marcelo Cantos (unless the project specifies otherwise).
- For source files, use the short-form SPDX header when licence headers are needed:
  `// Copyright <year> Marcelo Cantos`
  `// SPDX-License-Identifier: Apache-2.0`

## C++ Style

- Make effective use of the pImpl idiom: `struct M; std::shared_ptr<M> m;` (or `unique_ptr`).

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

## Refactoring

- Consider refactoring semi-regularly to keep the codebase clean, but don't overdo it. Small, targeted improvements alongside feature work are preferable to large sweeping rewrites.

## Build

- Never pass `-j` to `make`. Projects that need parallel builds set `MAKEFLAGS` in their Makefiles.

## Configuration Formats

- Never use TOML. Prefer JSON, YAML, or plain SQL/text as appropriate.

## Git

- Always prefer `master` over `main` as the default branch name. Never ask or suggest creating a `main` branch.

## Managed Repos

- The full list of managed repos (across all orgs: `marcelocantos`, `squz`, `arr-ai`, `minicadesmobile`, etc.) is in `~/.claude/managed-repos.md`. Consult it when listing repos or looking up project status — `gh repo list` only shows one org at a time.
- The file is auto-updated by `/sync-globals` and can also be edited manually.

## Repository Hygiene

- Ensure .gitignore covers: build artifacts, IDE files (.vscode/, .idea/), OS files (.DS_Store), dependency directories (node_modules/, __pycache__/), and generated files.
- Never commit secrets, .env files, credential files, or private keys. If generated as part of setup, add them to .gitignore immediately. Exception: test fixtures with fake/dummy credentials are fine.
- GitHub repo settings for owned repos: squash-only merges (`allow_merge_commit: false`, `allow_rebase_merge: false`), squash commit title from PR title, delete-branch-on-merge enabled.

## Versioning

- Use semantic versioning (vMAJOR.MINOR.PATCH). First release: v0.1.0.
- Default to minor releases (bump MINOR, reset PATCH). Only use major/patch when explicitly requested.

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

## Teams

- Proactively use teams when a task has 2+ substantial independent workstreams that can be parallelised.
- Also use teams for:
  - **Bulk similar work** — when the same change pattern applies across multiple directories, modules, or files, fan out agents to handle subsets in parallel.
  - **Context isolation** — when heavy exploratory reads (audits, deep research) would bloat the main conversation context.
  - **Research fan-out** — when investigating multiple codebase areas or external sources before synthesising.
- **Worktree isolation**: Prefer `isolation: "worktree"` when spawning team agents that edit files. This prevents concurrent agents from clobbering each other's changes. Solo sequential work can stay on master (the `/push` skill creates feature branches at push time).
- Model selection:
  - **`opus`** — default for team agents; complex reasoning, architectural decisions, novel problem-solving.
  - **`sonnet`** — well-scoped coding tasks, bulk repetitive changes across modules, evaluating test/build failures.
  - **`haiku`** — monotonous tasks: file searches, mechanical find-and-replace, running builds/tests, and triaging failures (categorise, group, summarise). Hand off to `sonnet` for diagnosis and fix decisions.

## Audit log

- Skills that perform maintenance work (`/audit`, `/docs`, `/release`, `/open-source`) append entries to `docs/audit-log.md` in the repo. The `/waw` skill reads this log for its maintenance status section.
- Format spec: `~/.claude/skills/audit-log-convention.md`
- When a skill invokes another skill, only the parent logs — children skip to avoid double entries.

## Task tracking

- Projects track TODOs in `docs/TODO.md` (all-caps `TODO`). When you discover a new TODO item during work (a bug to fix later, a feature idea, a cleanup opportunity), check the repo-local `CLAUDE.md` for the TODO file location and append the item there. If the repo has no TODO file or `CLAUDE.md` doesn't mention one, create `docs/TODO.md`.

## Convergence targets

- Targets are numbered 🎯T1, 🎯T2, … (sub-targets: 🎯T1.1, 🎯T1.2, …).
  Always use the 🎯T*N* prefix when referring to targets — in files,
  reports, and conversation. No space between 🎯 and T.
- Projects track desired states in `docs/targets.md`. When you discover
  something during work that doesn't belong in the current task — a
  quality issue, a missing capability, an inconsistency — add it as a
  target rather than fixing it inline or dropping a bare TODO.
- A target is a desired state, not a task. Write it as an assertion:
  "All tests pass on Windows" not "Fix Windows tests."
- Include enough context that a future agent in a fresh session can
  understand why the target matters and how to approach it.
- Mark the origin if it was discovered while working on another target
  (forked-from).
- When finishing a task, plan, or session, check whether any active
  targets were affected. Update status if a target moved closer to or
  achieved its desired state. Don't leave stale targets.
- If execution reveals that a target is wrong — misframed, incomplete,
  or pointing at the wrong thing — update the target first, then decide
  whether to continue, revise, or abandon the current plan. The target
  is the source of truth, not the plan.
- Broad targets decompose into sub-targets. Don't plan against a
  composite target directly — decompose until each sub-target is
  independently achievable, then converge leaf-first. The hierarchy
  emerges as you understand the problem; you don't need the full tree
  upfront. See [`~/.claude/convergence.md`](~/.claude/convergence.md)
  for the full decomposition model.
- Plans converge toward targets. If `/cv` suggests different work
  than an active plan, trust the convergence assessment.
- Evaluate convergence at decision boundaries (session start, run
  completion, blockage), not continuously. Within a coherent stretch of
  work toward a single target, don't re-evaluate — just work. After
  completing a small piece of work, update the target's status field if
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
- **Workflow**: When starting new work (user request, session start, or
  picking up where you left off), check `docs/targets.md` first. If the
  work maps to an existing target, evaluate convergence before planning.
  If no target exists, create one. Do not enter plan mode until the
  target is established and convergence is assessed. This is a hard
  prerequisite — convergence determines whether planning is even the
  right next action.

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

Notable tools installed via Homebrew that may be useful during development:

**WebSocket / Network testing:**
- `websocat` — WebSocket client/server CLI. Use for testing WebSocket endpoints (e.g. `websocat ws://localhost:42069/path`).
- `websocketd` — turn any CLI program into a WebSocket server.
- `grpcurl` — `curl` for gRPC services.
- `httpie` (`http`) — user-friendly HTTP client (aliased to `h` with `--check-status --follow`).
- `nmap` — network scanning and port discovery.

**C/C++ build tooling:**
- `cmake`, `ninja` — build system generators.
- `ccache` — compiler cache (speeds up rebuilds).
- `bear` — generates `compile_commands.json` from build commands (for clangd/LSP).
- `compiledb` — alternative `compile_commands.json` generator from make.
- `clang-format` — C/C++ code formatter.
- `include-what-you-use` — header dependency analysis.
- `conan` — C/C++ package manager (prefer vendoring per Dependencies policy, but available).

**Languages / Runtimes (beyond C++):**
- `go` (1.25), `rust`, `zig` (0.15), `node`, `python` (3.9–3.14 via pyenv), `ruby`, `kotlin`, `elixir`/`erlang`, `ocaml`, `lua`, `dotnet`.
- `emcc` (Emscripten) — compile C/C++ to WebAssembly.
- `uv` — fast Python package/project manager.

**VCS:**
- `jj` (Jujutsu) — Git-compatible VCS with simpler mental model. Available alongside `git`.
- `gh` — GitHub CLI.
- `difftastic` (`difft`) — syntax-aware structural diffs. Shows what changed semantically, not just line-by-line.

**Shell / File utilities:**
- `bat` — `cat` with syntax highlighting.
- `fd` — fast `find` alternative.
- `entr` — run commands when files change (e.g. `fd .cpp | entr make`).
- `tokei` — code statistics (lines of code by language).
- `dust` — disk usage visualiser.
- `parallel` — GNU parallel for parallelising shell commands.
- `shellcheck`, `shfmt` — shell script linting and formatting.
- `pandoc` — universal document converter.
- `hyperfine` — precise CLI benchmarking (e.g. `hyperfine 'make' 'make -B'`).
- `hexyl` — hex viewer for binary file inspection (mesh packs, wire protocol dumps, texture data).

**AI / ML (local):**
- `ollama` — run local LLMs. Use for testing AI integrations without API calls.
- `llama.cpp` — direct LLM inference engine.

**Media:**
- `ffmpeg` — audio/video transcoding and manipulation.
- `imagemagick` — image conversion and manipulation from CLI.

**JSON / Data:**
- `jq` — JSON processor (installed via zerobrew at `/opt/zerobrew/prefix/bin/jq`).
- `yq` — YAML/JSON/XML processor.

**Containers / Cloud:**
- OrbStack — Docker Desktop replacement (see Shell Startup Scripts in `~/CLAUDE.md`).
- `k9s`, `kubectl`, `skaffold` — Kubernetes management.
- `gcloud` — Google Cloud CLI.
- `qemu` — hardware virtualisation / emulation.
- `act` — run GitHub Actions locally. Test CI workflows without pushing.

**Formal verification:**
- TLA+ (`tla2tools.jar`) — model checker for concurrent/distributed protocols. Projects that use it typically have a `formal/` directory with a `tlc` wrapper script.

## Debugging

- When stuck on a non-obvious bug, write a structured problem description before reaching for heavier tools. Enumerate the actors/components, their interaction sequence as numbered steps, and state an explicit hypothesis. The act of explaining often reveals the bug — the document is a thinking tool, not just an artifact. For project-specific conventions on where to put these (e.g., `docs/papers/`), check the project's CLAUDE.md.

## Continuous improvement

- At the end of a coding session (or when a natural stopping point is reached), reflect on whether the session surfaced insights that would benefit future sessions across any project — recurring patterns, conventions, workflow preferences, or corrections to existing directives. If so, propose specific amendments to the relevant `CLAUDE.md` file (global `~/.claude/CLAUDE.md` or project-level). Only apply changes with user consent.

