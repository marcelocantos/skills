# Skills

Claude Code skills for use with `~/.claude/skills/`.

Also includes my global [`CLAUDE.md`](CLAUDE.md) directives and the [`convergence.md`](convergence.md) reference.

## Available Skills

- **[`/build-perf-audit`](skills/build-perf-audit/SKILL.md)** — Audit a build system for performance issues — profile the build, identify hotspots, match against known anti-patterns, and propose (or apply) fixes with before/after measurements. Use when a build is slow, when CI times are creeping up, or when you suspect caching/parallelism is misconfigured.
- **[`/c`](skills/c/SKILL.md)** — Continue — restore compacted context from this session's chain after a /clear. Short to type on purpose.
- **[`/commit`](skills/commit/SKILL.md)** — Stage and commit changes with an auto-drafted message.
- **[`/cv`](skills/cv/SKILL.md)** — Evaluate convergence gaps on active targets and recommend next work.
- **[`/demo`](skills/demo/SKILL.md)** — >
- **[`/docs`](skills/docs/SKILL.md)** — End-to-end documentation sherpa — audit, plan, and write all project documentation.
- **[`/expenses`](skills/expenses/SKILL.md)** — >
- **[`/hygiene`](skills/hygiene/SKILL.md)** — Declare and drift-validate a repo's steady-state hygiene posture (tests, security scans, code quality, governance, …) and aggregate coverage across the fleet. Use to check a repo's hygiene.yaml against reality, onboard a repo, or answer "is X covered in repo Z?" / "which repos lack X?".
- **[`/open-source`](skills/open-source/SKILL.md)** — Open-source a project — audit, fix, document, publish, and release.
- **[`/oracle-first`](skills/oracle-first/SKILL.md)** — Verification-economics method for AI-assisted work. Use when porting or migrating legacy code, replicating an existing system's behaviour ("match the old app exactly"), doing visual/physics/feel parity work (especially spatial/geometry), authoring the correctness spec for new code (property tests, invariants, TLA+), designing acceptance criteria for a target, planning verification for a codebase analysis, or when repeated tweak-and-check against human judgment isn't converging.
- **[`/pr-audit`](skills/pr-audit/SKILL.md)** — Audit open PRs across all owned repos and recommend cleanup actions (close superseded, merge ready, poke contrib reviewers, fan-in synchronized rollouts).
- **[`/progress-report`](skills/progress-report/SKILL.md)** — Generate and publish a weekly progress report from git activity across all repos.
- **[`/push`](skills/push/SKILL.md)** — Push current work through a PR-based CI workflow. Creates branch and PR if needed.
- **[`/release`](skills/release/SKILL.md)** — Publish a release — version, release notes, CI, Homebrew tap, tag, and GitHub release.
- **[`/remind`](skills/remind/SKILL.md)** — >
- **[`/republish-skills`](skills/republish-skills/SKILL.md)** — Sync ~/.claude/skills/ to the marcelocantos/skills GitHub repo.
- **[`/retro`](skills/retro/SKILL.md)** — Mine the last week of session transcripts for concrete improvements to the system itself — skills, tools, MCP servers, scripts, CLAUDE.md/AGENTS.md, permissions, hooks. Produces an evidence-backed, ranked proposal list, applies the approved ones, and files targets for the rest.
- **[`/sync-globals`](skills/sync-globals/SKILL.md)** — sync-globals
- **[`/target`](skills/target/SKILL.md)** — Manage targets — desired states for the project.
- **[`/vera`](skills/vera/SKILL.md)** — Semantic code search, regex pattern search, and symbol lookup across a local repository. Returns ranked markdown codeblocks with file path, line range, content, and optional symbol info. Use `vera search` for conceptual/behavioral queries (how a feature works, where logic lives, exploring unfamiliar code). Use `vera grep` for exact strings, regex patterns, imports, and TODOs. Use `vera references` to trace callers/callees. Use rg only for bulk find-and-replace or files outside the index.
- **[`/waw`](skills/waw/SKILL.md)** — "Where Are We?" — Context restoration after being AFK. Default is a quick recap; `/waw all` runs the full deep briefing.
- **[`/ytt`](skills/ytt/SKILL.md)** — Fetch a YouTube video's transcript and ingest it into ~/think/knowledge/youtube/ as a synopsis with key takeaways. Updates the knowledge-base index and commits.

## License

Apache-2.0
