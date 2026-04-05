# /docs Worker — Documentation Audit and Recommendations

Audit the project's documentation and produce a prioritised action plan.
This covers Phases 1-3. Phases 4-5 (Execution, Verification) are handled
interactively in the root session.

## Progress reporting

Before starting each phase, emit a progress heading **on its own line
followed by a blank line**, then proceed to tool calls. Use `##` for
major phases and `###` for sub-steps. Examples:

```
## Phase 1 — Discovery

### Audience identification

## Phase 2 — Audit

### API documentation

## Phase 3 — Recommendations
```

Do not put any other text on the same line or immediately after the
heading — the blank line is required. These headings are picked up by
the Agent framework and forwarded to the root session as progress
notifications.

## Phase 1 — Discovery

Understand the project before assessing its docs.

### 1a. Codebase survey

Explore the project structure — languages, build system, directory layout,
key entry points, public APIs, tests. Read CLAUDE.md, README, Makefile,
and any existing docs.

### 1b. Audience identification

Determine who the docs serve. Assess which of the following audiences
the project serves:

- End users (people running/using the software)
- Contributors (developers working on the codebase)
- Integrators (developers consuming it as a library/API)
- Operators (people deploying/maintaining it)

Most projects have multiple audiences. The mix determines which doc
types matter most.

### 1c. Project maturity

Assess whether the project is early-stage (API still shifting), stable
(ready for public use), or mature (established user base). This affects
the tone and depth of recommendations.

Present a brief project summary and confirmed audience list in the output.

## Phase 2 — Audit

Catalog all existing documentation and assess its state. Evaluate each
document category below.

### Document categories

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

### Quality checks (for docs that exist)

For each existing document, assess:

- **Accuracy**: Does it match the current code? Run any build/test commands it lists to verify.
- **Completeness**: Does it cover the topic adequately, or are there significant gaps?
- **Staleness**: Are there references to removed features, old file paths, deprecated APIs?
- **Clarity**: Is it well-structured and easy to follow? Or is it a wall of text?
- **Redundancy**: Is the same information duplicated across multiple docs, risking drift?

## Phase 3 — Recommendations

Produce a prioritised action plan based on the audit.

### Prioritisation criteria

Rank recommendations by impact:
1. **Critical**: Missing or broken docs that block users from building/running the project
2. **High**: Gaps that affect the primary audience's ability to use or contribute
3. **Medium**: Quality improvements to existing docs (staleness, inaccuracy, restructuring)
4. **Low**: Nice-to-haves (diagrams, tutorials for edge cases, contributor templates)

### Output format

Present a numbered, prioritised list. For each item:
- What document to create or fix
- Why it matters (which audience, what problem it solves)
- Estimated scope (small: < 50 lines, medium: 50-200 lines, large: 200+ lines)
- Dependencies (e.g., "architecture doc should be written before API doc")

Return the full audit results and prioritised recommendation list as
your result. The root session will present these to the user and handle
Phases 4-5.

## Document types to consider

During the audit and recommendations phases, consider the full range of
document types below. Not every project needs all of these — recommend
only what's appropriate for the project's audiences and maturity. Scale
documentation to the size of the project: a small library might only
need a good README and API reference, while a large multi-component
system may warrant the full set. Don't overwhelm a tiny project with a
documentation suite substantially larger than the codebase itself.

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
