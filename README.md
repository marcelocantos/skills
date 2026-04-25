# Skills

Claude Code skills for use with `~/.claude/skills/`.

Also includes my global [`CLAUDE.md`](CLAUDE.md) directives and the [`convergence.md`](convergence.md) reference.

## Available Skills

- **[`/build-perf-audit`](skills/build-perf-audit/SKILL.md)** — Audit a build system for performance issues — profile the build, identify hotspots, match against known anti-patterns, and propose (or apply) fixes with before/after measurements. Use when a build is slow, when CI times are creeping up, or when you suspect caching/parallelism is misconfigured.
- **[`/c`](skills/c/SKILL.md)** — Continue — restore compacted context from this session's chain after a /clear. Short to type on purpose.
- **[`/commit`](skills/commit/SKILL.md)** — Stage and commit changes with an auto-drafted message.
- **[`/cv`](skills/cv/SKILL.md)** — Evaluate convergence gaps on active targets and recommend next work.
- **[`/docs`](skills/docs/SKILL.md)** — End-to-end documentation sherpa — audit, plan, and write all project documentation.
- **[`/open-source`](skills/open-source/SKILL.md)** — Open-source a project — audit, fix, document, publish, and release.
- **[`/progress-report`](skills/progress-report/SKILL.md)** — Generate and publish a weekly progress report from git activity across all repos.
- **[`/push`](skills/push/SKILL.md)** — Push current work through a PR-based CI workflow. Creates branch and PR if needed.
- **[`/release`](skills/release/SKILL.md)** — Publish a release — version, release notes, CI, Homebrew tap, tag, and GitHub release.
- **[`/republish-skills`](skills/republish-skills/SKILL.md)** — Sync ~/.claude/skills/ to the marcelocantos/skills GitHub repo.
- **[`/sync-globals`](skills/sync-globals/SKILL.md)** — sync-globals
- **[`/target`](skills/target/SKILL.md)** — Manage targets — desired states for the project.
- **[`/todo`](skills/todo/SKILL.md)** — Summarise open TODOs from local todo file and GitHub issues.
- **[`/vera`](skills/vera/SKILL.md)** — Semantic code search, regex pattern search, and symbol lookup across a local repository. Returns ranked markdown codeblocks with file path, line range, content, and optional symbol info. Use `vera search` for conceptual/behavioral queries (how a feature works, where logic lives, exploring unfamiliar code). Use `vera grep` for exact strings, regex patterns, imports, and TODOs. Use `vera references` to trace callers/callees. Use rg only for bulk find-and-replace or files outside the index.
- **[`/waw`](skills/waw/SKILL.md)** — "Where Are We?" — Context restoration after being AFK. Default is a quick recap; `/waw all` runs the full deep briefing.
- **[`/ytt`](skills/ytt/SKILL.md)** — Fetch a YouTube video's transcript and present a detailed synopsis with key takeaways.

## License

Apache-2.0
