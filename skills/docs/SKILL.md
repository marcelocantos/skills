---
name: docs
description: End-to-end documentation sherpa — audit, plan, and write all project documentation.
user-invocable: true
---

# Documentation Sherpa

End-to-end skill that takes a project from any documentation state to a well-documented system. Audits what exists, identifies gaps and quality issues, builds a prioritised plan, then drafts and writes every document with user review.

## Invocation

The user runs `/docs`. No arguments needed — the skill discovers everything from the codebase.

## Workflow

Execute these phases in order. Summarise findings at the end of each phase and confirm before proceeding.

### Phase 1: Discovery

Understand the project before assessing its docs.

1. **Codebase survey**: Explore the project structure — languages, build system, directory layout, key entry points, public APIs, tests. Read CLAUDE.md, README, Makefile, and any existing docs.

2. **Audience identification**: Determine who the docs serve. Ask the user to confirm:
   - End users (people running/using the software)
   - Contributors (developers working on the codebase)
   - Integrators (developers consuming it as a library/API)
   - Operators (people deploying/maintaining it)

   Most projects have multiple audiences. The mix determines which doc types matter most.

3. **Project maturity**: Assess whether the project is early-stage (API still shifting), stable (ready for public use), or mature (established user base). This affects the tone and depth of recommendations.

Present a brief project summary and confirmed audience list before proceeding.

### Phase 2: Audit

Catalog all existing documentation and assess its state. Evaluate each document category below.

#### Document categories

For each category, determine: **exists?** / **accurate?** / **complete?** / **stale?**

1. **Project overview** (README.md)
   - Clear one-line description of what it does and why
   - Quickstart: can a new user get running in under 5 minutes?
   - Installation/build instructions — do they actually work?
   - Usage examples
   - License notice
   - Links to further docs

2. **Architecture documentation** (docs/, CLAUDE.md, or inline)
   - System design: major components and how they interact
   - Data flow: how data moves through the system
   - Key design decisions and their rationale
   - Diagrams (even ASCII ones) where they'd help

3. **API documentation**
   - Public headers/interfaces: are they documented?
   - Function signatures: are parameters, return values, and side effects clear?
   - Usage examples for non-obvious APIs
   - Error handling: what can go wrong and how callers should handle it

4. **User guide / tutorials**
   - Getting started guide (beyond quickstart)
   - Common workflows and use cases
   - Configuration reference (env vars, config files, CLI flags)
   - Troubleshooting / FAQ

5. **Development guide**
   - How to set up a dev environment
   - Code style and conventions
   - How to run tests
   - Where to find things in the codebase

6. **Inline code documentation**
   - Are complex algorithms or non-obvious logic explained?
   - Are public functions/methods documented at the declaration site?
   - Is there excessive boilerplate documentation that adds noise without value?
   - Are there stale comments that describe code that has since changed?

7. **Ops / deployment documentation**
   - How to deploy, configure, and run in production
   - Monitoring, logging, health checks
   - Backup/restore procedures
   - Only relevant if the project is a service or has operational concerns

8. **Testing documentation**
   - How to run the test suite
   - Test strategy (what's tested, what isn't, and why)
   - How to add new tests
   - How to update golden files / snapshots if applicable

9. **CLAUDE.md** (Claude Code integration)
    - Does it accurately describe the project for AI-assisted development?
    - Are build commands, architecture, key files, and conventions covered?
    - Is it current with the actual codebase?

#### Quality checks (for docs that exist)

For each existing document, assess:

- **Accuracy**: Does it match the current code? Run any build/test commands it lists to verify.
- **Completeness**: Does it cover the topic adequately, or are there significant gaps?
- **Staleness**: Are there references to removed features, old file paths, deprecated APIs?
- **Clarity**: Is it well-structured and easy to follow? Or is it a wall of text?
- **Redundancy**: Is the same information duplicated across multiple docs, risking drift?

### Phase 3: Recommendations

Produce a prioritised action plan based on the audit.

#### Prioritisation criteria

Rank recommendations by impact:
1. **Critical**: Missing or broken docs that block users from building/running the project
2. **High**: Gaps that affect the primary audience's ability to use or contribute
3. **Medium**: Quality improvements to existing docs (staleness, inaccuracy, restructuring)
4. **Low**: Nice-to-haves (diagrams, tutorials for edge cases, contributor templates)

#### Output format

Present a numbered, prioritised list. For each item:
- What document to create or fix
- Why it matters (which audience, what problem it solves)
- Estimated scope (small: < 50 lines, medium: 50-200 lines, large: 200+ lines)
- Dependencies (e.g., "architecture doc should be written before API doc")

Ask the user which items to proceed with. They may choose all, a subset, or reorder.

### Phase 4: Execution

For each approved item, in priority order:

1. **Research**: Read the relevant code thoroughly. Don't write docs from guesses — verify every claim against the source.

2. **Draft**: Write the document. Follow these principles:
   - **Accuracy over polish**: every command, path, and code snippet must be correct and current
   - **Show, don't tell**: prefer concrete examples over abstract descriptions
   - **Respect the reader's time**: front-load the most important information
   - **Match the project's voice**: if existing docs are terse and technical, don't write flowery prose
   - **No filler**: skip generic platitudes ("This project aims to..."). Get to the point.
   - **Runnable examples**: any code/command examples should actually work if copy-pasted

3. **Review**: Present the draft to the user. Incorporate feedback. Don't write to disk until approved.

4. **Write**: Save the file and confirm.

5. **Cross-reference**: After writing each doc, check if other docs need updates to link to it or stay consistent.

Repeat for each approved item. After all items are done, do a final consistency check across all documentation.

### Phase 5: Verification

After all writing is done:

1. **Command verification**: Run every build/test/install command mentioned in the docs to confirm they work.

2. **Link check**: Verify all internal cross-references and file paths are valid.

3. **Consistency check**: Ensure terminology, project name, and conventions are consistent across all docs.

4. **Audit log**: Append the audit-log entry (see "Audit log" section below) so it is committed with the documentation changes.

5. **Commit**: If any files were created or modified, commit all documentation changes (including the audit-log entry) with a descriptive message summarising what was added or updated.

6. **Final summary**: Report what was created, updated, and verified. List any remaining items the user deferred.

## Document types to consider

During the audit and recommendations phases, consider the full range of document types below. Not every project needs all of these — recommend only what's appropriate for the project's audiences and maturity. Scale documentation to the size of the project: a small library might only need a good README and API reference, while a large multi-component system may warrant the full set. Don't overwhelm a tiny project with a documentation suite substantially larger than the codebase itself.

### Guides (task-oriented, walk the reader through doing something)

- **Getting started guide** — From zero to running: install, configure, first use
- **Tutorial** — Step-by-step walkthrough of a realistic use case, end to end
- **How-to guide** — Focused recipe for a specific task (e.g., "How to add a new endpoint")
- **Migration guide** — How to upgrade between versions or from a predecessor system
- **Development guide** — How to set up a dev environment, build, test, and contribute
- **Deployment guide** — How to deploy, configure, and run in production

### References (information-oriented, looked up rather than read through)

- **API reference** — Public interfaces, function signatures, parameters, return values, error conditions
- **Configuration reference** — Every env var, config file option, and CLI flag with defaults and valid values
- **CLI reference** — Commands, subcommands, flags, and examples
- **Data model / schema reference** — Database tables, wire protocol structs, file formats
- **Glossary** — Domain-specific terms the reader might not know

### Explanations (understanding-oriented, the "why" behind decisions)

- **Architecture overview** — Major components, how they interact, data flow
- **Design decisions / ADRs** — Key choices, alternatives considered, rationale (Architecture Decision Records)
- **Research reports** — Investigations, benchmarks, spikes, feasibility analyses, trade-off evaluations. Typically written before or during implementation to inform decisions. Belong in `docs/research/` or similar.

### Agentic coding guide

- **agents-guide.md** — A highly condensed reference tailored for agentic coding tools (Claude Code, Cursor, Copilot, etc.). Distils the essential information from all other docs into a single file that an agent can ingest quickly. Should be concise enough to fit comfortably in a context window.

  **For libraries**: What it does, how to include it, key API surface, common patterns, and gotchas.

  **For programs**: What it does, architecture overview, how to build and run, key modules and entry points, configuration, extension points, and common development tasks.

  **Placement**: Place `agents-guide.md` in the project root by default. Exception: for single- or two-file libraries distributed as `dist/something.h` (and optionally `dist/something.cpp`), co-locate it alongside those files in `dist/` so that consumers who vendor just the dist files get the agent guide with them.

  **README mention**: When the project has an agents-guide.md, the README should mention it — e.g., "If you use an agentic coding tool, include `agents-guide.md` in your project context."

### Project-level documents

- **README.md** — Project overview, quickstart, license
- **CLAUDE.md** — Claude Code integration: build commands, architecture, conventions, key files

### In-code documentation

- **Inline comments** — Explain *why*, not *what*. Complex algorithms, non-obvious invariants, gotchas.
- **Doc comments** — Public API declarations: what, parameters, return values, side effects, examples

### Explicitly excluded

Do **not** recommend or create:
- CONTRIBUTING.md, CONTRIBUTORS file, or similar
- Codes of conduct
- Issue or PR templates
- Community guidelines or governance documents

## Guidelines

- Never invent information. If you're unsure about something, read the code or ask the user.
- Don't add documentation for documentation's sake. If code is self-explanatory, say so and move on.
- Prefer updating existing docs over creating new files. Don't fragment information.
- Respect existing doc structure. If the project already has a `docs/` convention, follow it.
- Inline comments should explain *why*, not *what*. Don't recommend adding comments that restate the code.
- If a CLAUDE.md exists, treat it as the canonical architecture reference. Recommend improvements to it rather than creating a separate architecture doc that would drift.

## Audit log

Before the Phase 5 commit (step 5), append an entry to `docs/audit-log.md` (create the file with the standard header if it doesn't exist — see `~/.claude/skills/audit-log-convention.md` for the format). This ensures the entry is committed alongside the documentation changes.

The entry should summarise what documents were created or updated and list any deferred recommendations.

**Skip this step** if invoked as part of another skill (e.g., `/open-source`) — the parent skill will log a summary entry.

## Skill improvement

After each documentation run, reflect on whether any reusable insights were gained — new document categories worth auditing, better quality checks, patterns for structuring docs in specific project types, or improvements to the workflow phases. Pay special attention to unexpected failures in companion scripts or tool invocations encountered during the run — these may indicate bugs to fix in the skill or its scripts, not just one-off issues. If any improvements are identified, propose the specific changes to this skill file (or its companion files) to the user. Only integrate them with user consent.
