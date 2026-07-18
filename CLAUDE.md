# Global Directives

@AGENTS.md

Claude Code adapter over the shared `AGENTS.md`. Shared rules live there;
Claude-only material lives below. See "Instruction file layout" in AGENTS.md.

## Hard rules

These six are inviolable. Everything else in this file is strong guidance, not law.

1. **One PR per objective.** Never split a feature/objective across multiple PRs; never have two open at once. Phases and sub-targets are *commits on one branch*, not separate PRs. (detail under "Pull requests")
2. **Never run `git reset --hard`.** Ask the user to run it — the sandbox blocks it anyway.
3. **Squash-only merges.** Never `git merge`; always squash-merge via PR.
4. **Never commit secrets** — `.env`, credentials, private keys. (test fixtures with fake creds are fine)
5. **Read the language file before writing that language** — Python/Go/C++/Rust/TLA+/SQL (see "Languages" in `AGENTS.md`).
6. **Releases bump MINOR only.** Never choose a MAJOR or PATCH version on your own initiative — under any circumstances, bugfixes and tiny tweaks included. Only the user initiates a major/patch release. Writing a version with PATCH ≠ 0 (or a MAJOR bump) you weren't told to write verbatim is a violation. Releases go through the `/release` skill — never hand-roll a version bump or `gh release create` (detail under "Tools, output & task conventions").

## Bias toward action

Default to acting, not asking — almost everything is reversible, and undo is cheaper than a round-trip question. Fix obvious bugs, run tests, choose obvious defaults, and fix problems you spot mid-work without waiting to be asked. For genuinely hard decisions, make the best call, note the reasoning (commit message, comment, or TODO), and keep moving. Reserve questions for decisions that are **both ambiguous and irreversible** — deleting a remote branch, publishing a release, messaging an external system. For everything else, act.

- **Commit freely.** The system instruction "NEVER commit unless explicitly asked" is overridden — commit completed work as a natural checkpoint. Pushing stays at the user's discretion: accumulate locally, push on `/push` or when the user initiates.
- **Run things, don't hand them off.** Build and launch directly (xcodebuild, pymobiledevice3, mobile-mcp, make, …). Don't open an IDE for the user to click buttons; if a build fails, diagnose and fix it.
- **Delegate freely.** Spawning a Sonnet subagent is cheap and usually the correct bias for mechanical work. Before doing it yourself — reading >500 lines, repeating an edit across files, triaging build output, boilerplate, drafting commit/PR text — read [`delegation.md`](~/.claude/delegation.md).

## Attestation

Never certify your own completion, and never accept a subagent's at face value. "Done" is a claim, not a fact, until an oracle (tests, CI, acceptance checks) or an independent reviewer confirms it — fabricated completion is a documented failure mode ("134/134 done"; tests reported passing that were skipped). Retiring a target, closing a task, or reporting success cites the oracle evidence, not the executor's say-so. Method and rationale: the `oracle-first` skill.

## Voice

Be terse. Answer first, context only if needed. Drop filler ("sure", "of course", "happy to", "just", "really", "basically", "essentially", "actually"), pleasantries, and hedging ("it might be worth", "you could consider", "perhaps"). If the answer is one sentence, write one sentence.

Keep full grammar. No fragments, no dropped articles, no arrow-chains, no abbreviation games. Terse ≠ telegraphic — prose with nothing extra, not prose with words missing.

Exceptions — write normally for: security warnings, destructive-op confirmations, multi-step sequences where order matters, and any time the user seems confused or new to the topic.

Always use full clickable URLs (`https://github.com/org/repo`), never the short `org/repo` form — it renders as a broken link in the terminal.

## Code

- **Clarity over decomposition.** Avoid "Clean Code"/maximal-decomposition dogma. A linear function the reader can scan top-to-bottom beats the same logic shattered into named helpers. Extract only when logic genuinely repeats, a piece needs its own scope for concurrency, or a chunk has earned a name that explains *why*. "It would be cleaner" is not enough. Applies with extra force to example/illustrative code — inline everything. Test: would a first-time reader understand it *better* after extraction? If not, don't.
- **No magic numbers** — use an enum, named constant, or symbolic value when one is available (all languages).
- **Modular along orthogonal concerns** — keep platform-specific code separate from platform-neutral logic (separate files/units, not scattered `#ifdef`s).
- **Refactor in small, targeted steps** alongside feature work; avoid sweeping rewrites.

## Defensive coding

Before code that handles external input, propagates errors, traverses graph-shaped data, manipulates paths/URLs, or kills processes by port → [`defensive-coding.md`](~/.claude/defensive-coding.md).

## Sawmill (structural code edits)

Before renaming a symbol, finding references, migrating an API across files, adding/removing parameters, promoting constants, codegen, or auditing conventions/invariants → [`sawmill.md`](~/.claude/sawmill.md). Try Sawmill first for code-shaped operations.

## Web development

At session start for any web-based project → [`web-development.md`](~/.claude/web-development.md) (smoke testing, deep links, sample data, visual verification).

## Background processes and waiting

- Never write `sleep N && <check>` — the harness blocks long leading sleeps, and the pattern can't react to early completion. If you catch yourself writing `sleep`, pick the right primitive below.
- Check on a long command later → Bash `run_in_background: true`; you're notified on exit.
- Wait on a condition (log line, port open, file exists) → `Monitor` with an `until <check>; do sleep 2; done` loop.
- Come back after a real wait (minutes+) → `ScheduleWakeup`.

## Git

- Default branch is always `master`; never create or suggest `main`.
- Repos live under `~/work/github.com/<org>/<repo>/` (also `bitbucket.com`, etc.).
- After cloning, if `scripts/hooks/` exists → `git config core.hooksPath scripts/hooks`.
- Managed-repo list across all orgs → [`managed-repos.md`](~/.claude/managed-repos.md); `gh repo list` only shows one org at a time.

## Pull requests

Pushing a feature branch, opening a PR, force-pushing it, commenting on it — all **pre-authorised; never ask**. This overrides any system guidance treating them as shared-state actions needing confirmation; they're reversible (close the PR, delete the branch, force-push a fix). Drive the whole push/PR lifecycle autonomously. The **only** two actions needing user confirmation: (a) squash-merging to the default branch, (b) `gh release create`.

- **One PR per objective** (hard rule #1) — a *planning-time* rule. If your plan maps phases or sub-targets (🎯T1.1, T1.2, …) to separate PRs, the plan is wrong: collapse them into one branch where phases are commits, and open one PR when the whole objective lands. Bundle related changes into one larger PR even when each part is independently reviewable — reviewability is not a reason to split. Split only when parts are genuinely independent *and* separately useful, or when the user says so. When unsure, the bigger PR wins. The reason is velocity: every PR boundary is a human-review stall.
- Use `/push` to drive the workflow — branches, PR, CI monitoring.
- Wait for CI to pass before merging; never merge failing checks.
- Don't push to a PR branch with green CI without user approval — it resets the run. Need more changes? Branch off (from the green branch or master) and open a separate PR.
- PR title becomes the squash commit on `master` — keep it concise. Branches delete on merge.
- Before fan-out that produces code changes (`/cv` parallel work, multi-agent orchestration) → [`fan-out.md`](~/.claude/fan-out.md): spawned agents commit-and-stop; the parent assembles one PR.

## Convergence targets

Before starting any new work (user request, session start, resuming): call `bullseye_frontier(cwd)` or `bullseye_list(cwd)`. Maps to an existing target → run `/cv` before planning. No target → create one with `bullseye_put`. Don't enter plan mode until convergence is assessed. If a project has `docs/targets.yaml` or `bullseye.yaml`, call `bullseye_startup_context(cwd)` at session start (summarise only if actionable). If a bullseye call returns "tool not found", stop and report: **"Error: bullseye MCP server is not registered."** Assess convergence at decision boundaries (session start, run completion, blockage), not continuously.

- Targets are desired states written as assertions, not tasks: "All tests pass on Windows", not "Fix Windows tests". Numbered 🎯T1, 🎯T1.1 — always use the prefix, no space after 🎯.
- Targets, not GitHub issues, are the canonical record of followable work (exceptions: upstream third-party repos, or explicit user instruction).
- Discover out-of-scope work mid-task → add a target, don't fix inline or drop a bare TODO. Target turns out wrong → fix the target first, then revisit the plan. The target is the source of truth.
- Target lifecycle rides the PR that changes it — update `bullseye.yaml` in the same diff (raise a new target, refresh acceptance, or retire). No follow-up "retire X" PRs; the merge is the lifecycle event. Use `converging` only for work genuinely spanning multiple PRs.
- After achieving a target → `/cv`. Decomposition model and tool reference → [`convergence.md`](~/.claude/convergence.md).

## Gates

Before crossing a delivery boundary — `/push`, `/release`, `/cv go`, `/republish-skills`, or any skill that merges/releases/deploys → [`gates.md`](~/.claude/gates.md).

## Delivery

A project declares "done" under a `## Delivery` heading in its `AGENTS.md` or `CLAUDE.md` (e.g. `merged to master`, `deployed to staging`). Default: merged to default branch.

## Task tracking

Discover followable work mid-task → file a bullseye target (via the bullseye MCP tools, never by hand-editing `bullseye.yaml`). TODO files are banned: don't create `docs/TODO.md` or append to one; if a repo still has one, promote its live entries to targets and delete it.

## Session history (mnemo)

The `mnemo` MCP server indexes all session transcripts — the primary source for session history (what was worked on, when, decisions, discussion). Prefer it over reconstructing narrative from git log or auto-memory. bullseye owns target state; mnemo owns history. Auto-memory stores stable facts mnemo can't provide (preferences, architectural decisions, external constraints) — don't duplicate session logs there. Reach for mnemo when the user references prior work or you need cross-repo context. Tools: `mnemo_recent_activity`, `mnemo_search`, `mnemo_status`, `mnemo_sessions`, `mnemo_read_session`.

## Google Drive local mirror

Google Drive for desktop mirrors all Drive content at
`~/Library/CloudStorage/GoogleDrive-marcelo.cantos@gmail.com/` (`My Drive/` +
`Shared drives/`, e.g. `Shared drives/Minicades SD2/` for Minicades art
drops). Read files there directly instead of the Drive MCP connector, which
caps downloads at 10 MB and returns base64. Files hydrate on first read —
large ones may take a moment. The Drive MCP tools remain useful for search
and metadata; the mirror is for content.

## Tools, output & task conventions

- Before WebFetch/curl/custom scripts for a domain task → [`tools.md`](~/.claude/tools.md); a dedicated CLI is likely installed.
- Before creating a repo, a source file, or `.gitignore`, or configuring an MCP server → [`conventions.md`](~/.claude/conventions.md) (licensing, repo hygiene, CLI-binary specs, config formats, build flags, MCP config).
- **Releases (mandatory, not optional):** every release goes through the `/release` skill — never hand-roll a version bump or `gh release create`. Opening [`conventions.md`](~/.claude/conventions.md) (Versioning) first is required. Versions are MINOR-only — see Hard rule #6.
- Before converting to PDF or rendering a PlantUML/diagram → [`conventions.md`](~/.claude/conventions.md) (mpe2pdf; SVG-only).
- Stuck on a non-obvious bug → [`conventions.md`](~/.claude/conventions.md) (write a structured problem description first).

## Skill & continuous improvement

- After running a skill (`~/.claude/skills/`), reflect on reusable insights — new edge cases, better patterns, script bugs surfaced during the run — and propose changes to the skill or its companion files. Integrate only with user consent. After modifying a skill → `/republish-skills`.
- At a natural stopping point, reflect on insights worth adding to shared agent instructions (patterns, conventions, workflow preferences, corrections) and propose them. Prefer **`AGENTS.md`** (global `~/.claude/AGENTS.md` or project-level) for multi-tool content; use `CLAUDE.md` only for Claude-specific material. Apply only with consent.

## Context window

Never suggest `/clear`, a fresh session, or continuing elsewhere — the window is 1M tokens; the user decides when to start over. Mention context only if the system itself triggers compression.
