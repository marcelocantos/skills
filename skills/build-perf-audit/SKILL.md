---
name: build-perf-audit
description: Audit a build system for performance issues — profile the build, identify hotspots, match against known anti-patterns, and propose (or apply) fixes with before/after measurements. Use when a build is slow, when CI times are creeping up, or when you suspect caching/parallelism is misconfigured.
user-invocable: true
---

Execute `~/.claude/skills/build-perf-audit/worker.md`. The worker handles
profiling, hotspot analysis, pattern matching, fix proposal, and
verification.

Optional arguments:
- A specific build target or command (e.g. `/build-perf-audit make test`)
- `--apply` to auto-apply low-risk fixes instead of just proposing them
- `--focus <area>` to narrow scope (e.g. `caching`, `parallelism`, `tests`)

If no argument is given, the worker discovers the primary build from the
repo (Makefile, Cargo.toml, CMakeLists.txt, build.gradle, *.xcodeproj,
go.mod, package.json, etc.) and profiles the default target.

## Skill improvement

After each run, reflect on whether new anti-patterns were encountered
that aren't yet in `patterns/`. If so, propose additions to the relevant
pattern file (or a new one for a new build system). Pay attention to
detection heuristics that produced false positives — those indicate the
pattern file needs refinement. Only integrate changes with user consent.
