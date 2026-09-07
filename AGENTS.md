# Shared agent directives

Cross-tool instructions. Canonical for Codex, Grok, Cursor, Copilot coding
agent, and any other tool that reads `AGENTS.md`. Claude Code loads this via
`@AGENTS.md` from `~/.claude/CLAUDE.md`.

Language-specific rule files and companion docs live in `~/.claude/` and are
shared by all tools.

## Instruction file layout

**`AGENTS.md` is the shared source of truth** for agent-facing instructions
(global and per-repo). Industry standard: https://agents.md/ (Agentic AI
Foundation / Linux Foundation). Supported widely (Codex, Cursor, Copilot,
Grok, Aider, …).

| File | Role |
|------|------|
| `AGENTS.md` | Shared instructions — edit this for anything multi-tool |
| `CLAUDE.md` | Claude Code adapter: `@AGENTS.md` import + Claude-only material (skills, hooks, hard-rule numbering, attestation) |
| `~/.claude/*.md` | Language / domain companions (python, go, rust, …) — shared by path |

### How each tool loads globals

| Tool | Global load path |
|------|------------------|
| **Grok** | Native: `~/.grok/{AGENTS,CLAUDE}.md`. **Claude compat** (default on): also scans `~/.claude/` for `AGENTS.md` + `CLAUDE.md` and loads **both** as separate files (does not expand `@` imports — each file is ingested whole). Verify with `grok inspect` → "Project Instructions". |
| **Claude Code** | `~/.claude/CLAUDE.md`; expands `@AGENTS.md` (and other `@` imports). |
| **Codex** | `~/.codex/AGENTS.md` (keep in sync with `~/.claude/AGENTS.md` + language files). |

**When editing instructions:**

1. Shared behaviour, language maps, build conventions → `AGENTS.md` (or the
   language file it points at).
2. Claude-only mechanics → `CLAUDE.md` only.
3. Per-repo: prefer `AGENTS.md` as canonical; if a repo still has only
   `CLAUDE.md`, propose `AGENTS.md` + thin `CLAUDE.md` that starts with
   `@AGENTS.md`.

Do not grow parallel copies of the same rules in both files.

## Skills (single tree)

Shared workflow skills (`/release`, `/push`, `/cv`, `/commit`, …) live in
**one** install tree:

| Path | Role |
|------|------|
| `~/.claude/skills/` | **Canonical** — edit here; Claude Code loads natively |
| `marcelocantos/skills` | Git mirror via `/republish-skills` |
| `~/.grok/skills/` | **Grok-only** skills (docx/pptx/xlsx/imagine/help/…) — not forks of shared skills |

Grok consumes the shared tree via `[compat.claude] skills = true` in
`~/.grok/config.toml`. Do **not** re-fork shared skills under
`~/.grok/skills/` — same-name entries shadow the canonical tree and drift.

After changing a shared skill → `/republish-skills`. Hardcode companion
scripts as `~/.claude/skills/<name>/…` (not `~/.grok/skills/…`).

## Languages

Before writing, modifying, or reviewing code in these languages — or answering
about their idioms, tooling, or APIs — **read the corresponding file in full**.
These files contain opinionated rules that override generic best-practice.
Don't skip because you "already know" the language; if you're emitting more
than a one-liner, stop and read.

- **Bash / shell** → [`bash.md`](~/.claude/bash.md) — read it before creating or
  extending a committed `*.sh` file, or choosing shell for a new task. Covers
  the boundary rule for when NOT to use shell at all, macOS bash 3.2, and
  GNU/BSD portability. (Not needed for ad-hoc commands in a tool call.)
- Python → [`python.md`](~/.claude/python.md)
- Go → [`go.md`](~/.claude/go.md)
- C / C++ → [`cpp.md`](~/.claude/cpp.md)
- **Rust** → [`rust.md`](~/.claude/rust.md) (build latency, CI cache, nextest, profiles)
- TLA+ → [`tlaplus.md`](~/.claude/tlaplus.md)
- SQL → [`sql.md`](~/.claude/sql.md)

New language rule → write it into the relevant file (creating one if needed)
and add the mapping here **and** in any tool-specific adapter that duplicates
the list.

## Verification honesty (pervasive)

Standing principles for **all** work, not just invocations of the
`oracle-first` skill (deep method and evidence live there). Premise:
the verification layer is itself a Goodhart target — under completion
pressure, any gap between a measured quantity and product truth will be
exploited, sincerely, by you. Design and treat gates accordingly.

- **Headline numbers come from the shipped path.** Oracle-assisted or
  instrumented paths are regression nets, never the completion metric.
- **No self-owned gate inputs.** Numerators, denominators, corpora, and
  thresholds in acceptance criteria are computed from source or a
  frozen reference, never from the executor's own inventory.
- **Ratchets, not thresholds.** Lock baselines in both directions;
  numbers move only by deliberate commit — no silent drift either way.
- **Provenance over plausibility.** Fixes trace to a named mechanism;
  an unexplained constant is suspect even under a green check.
- **Evidence, not machinery, is progress.** A verification asset counts
  for zero until it runs green against the product on fresh inputs;
  report activated green evidence, never artifact counts.
- **An oracle is a loop, not an artifact.** Wire it to a standing
  enforcement point (CI, hook, gate) as part of building it — unwired
  oracles decay.
- **Declare residue; never fudge it.** Enumerate what the oracle cannot
  decide and verify it visibly by hand.
- **Live provider paths.** Hermetic fakes cannot decide spawn, submit,
  auth, or turn-loop behaviour. When you change a backend's real
  process contract, run that project's live gate on every backend
  whose wire you touched — or name the skip as residue. CI green is
  not that evidence. (claudia: project `AGENTS.md` → Live tests.)
- **Owner-visible product paths.** A change the user can see or do
  through the shipped product needs a **journey** (whole product, thin
  slice, live agent/backend, machine-checkable outcome) or an explicit
  exception. Expense slims or caches the slice; it does not omit the
  gate. Guide: [`journeys.md`](~/.claude/journeys.md).
- **Generalize defenses.** A hardening pattern that proves out in one
  repo goes into the shared skill/doctrine immediately, not after the
  next repo's incident.

## Configuration formats

- **Do not introduce or recommend TOML** for new config, examples, MCP
  snippets, or docs. Prefer JSON, YAML, or plain text as appropriate.
- **Existing TOML is fine to touch.** Cargo, toolchains, third-party
  projects, and configs already written in TOML may be edited in place.
  Do not migrate away from TOML unprompted, and do not invent more of it
  (see [`conventions.md`](~/.claude/conventions.md)).

## Tool output and synced directories

**Tool output never lands in a synced or git-backed directory.** Playwright
MCP, network captures, screenshots, and similar tool artefacts default to
`<cwd>/.playwright-mcp/` or `<cwd>` itself. If the cwd is a repo with an
auto-commit job (`think-auto-sync`, yadm) or a cloud-synced folder, captures
reach the remote before anyone looks at them — on 2026-08-27 three bank API
captures (a full statement PDF, session tokens, account IDs) were pushed to
GitHub from `~/think` this way and had to be purged from history. Write
captures to the session scratchpad, or `.gitignore` the tool's output
directory before the first capture.

## Domains (non-language)

Before work in these areas, **read the companion file**:

- **Mobile / real-device lab** → [`mobile-development.md`](~/.claude/mobile-development.md)
  (spyder, inventory, fleet coverage). Matrix write-up:
  `~/think/lab/device-fleet-coverage.md`.
- **Web frontend projects** → [`web-development.md`](~/.claude/web-development.md)
  (also pointed from `CLAUDE.md`). **Hard rule:** never trust your own
  judgment about what CSS/layout will do — expert humans cannot; verify
  against a **real render** (layout/Playwright/smoke), not CSS-token
  greps alone. Full doctrine in that file under "CSS and layout".
- **Host Mac ML/inference sizing** → [`hardware.md`](~/.claude/hardware.md)
  (not the phone shelf).
- **Owner-visible E2E / journeys** → [`journeys.md`](~/.claude/journeys.md)
  — read before adding, skipping, or citing a product E2E. Whole
  product, thin user slice, live backend, machine-checkable outcome.
  Not hermetics, not doc greps.

## Delivery: two planes — act hard locally, ship only on request

Bias toward action and “don’t open PRs all the time” are **not** in
conflict if you split **two planes**:

| Plane | Be aggressive? | Includes |
|---|---|---|
| **Build** (default always on) | **Yes** | Edit, run, fix, test, commit, local merge/cherry-pick onto `master` or a batch branch, restart daemons, spawn work |
| **Ship** (opt-in) | **Only when asked** | `git push`, `/push`, `gh pr create`, CI-as-gate, squash to `origin/master`, releases |

Training collapses “done” into the Ship plane. **This owner usually
wants Build-plane aggression and Ship-plane restraint** — especially
when many slices must cohere and be tested before any remote.

### Default (all tools)

1. **Commit freely** on the working branch (Build plane). A dirty
   in-repo `bullseye.yaml` is part of the work: `/commit` stages it,
   `/push` refuses if it is still dirty. Do not omit it as bookkeeping.
2. **Stay off the Ship plane** unless the user explicitly opened it
   (`/push`, “open a PR”, “ship this”, “push and PR”, “push to origin”).
   “Work is done” / “ready for review” / finishing a target is **not**
   Ship permission.
3. **Build-plane done** = commits + required oracles/tests + status.
   A PR URL is not a trophy. Target achieve is Build-plane: the
   code landing is the achievement. `/release` does not keep a
   target open. Unreleased fixes are a `/cv` shipping signal, not
   an unachieved target.
4. When Ship is open: one PR per objective; `/push` not ad-hoc `gh`;
   squash-merge and releases still need explicit confirmation per skill.
5. Fan-out children: **commit and stop** — never Ship
   ([`fan-out.md`](~/.claude/fan-out.md)).

### Batch / local-cohere mode (common)

When the user says work must **come together locally** first (multi-agent
batch, “merge to master locally”, “no PR yet”, week-of-use, etc.):

- Prefer one long-lived local branch or local `master` integration.
- Cherry-pick/merge **locally** as slices land; run the real test path.
- **Do not** open per-slice PRs or “helpfully” push mid-batch.
- Ship only when they explicitly close the batch (`/push` the whole
  objective, or “ok ship it”).

### Ship mode (when they want aggression on the remote too)

If they say e.g. “push as you go”, “PR each slice”, “ship continuously
to origin” — then Ship-plane aggression is on **for that scope only**.
Still one PR per objective unless they asked for multiple.

### Vocabulary

| Said | Plane |
|---|---|
| **master** / merge to master | **Local** `master` unless they said origin/GitHub |
| **locally** / local only / no PR | Build only — no Ship |
| **ship** / open a PR / `/push` / push to origin | Ship plane open |

Jevons product mirrors this for the fleet (🎯T104). This section is the
**outer-agent** rail.
