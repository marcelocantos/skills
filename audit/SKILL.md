---
name: audit
description: Comprehensive codebase audit — code quality, security, testing, performance, legal, CI/CD, documentation, and agent-friendliness.
user-invocable: true
---

# Codebase Audit

Comprehensive end-to-end audit of a codebase from every angle that matters to engineers: code quality, architecture, security, testing, performance, build and CI/CD, legal compliance, documentation, dependency health, and agent-friendliness.

## Invocation

The user runs `/audit`. No arguments needed — the skill discovers everything from the repo. The user may optionally specify focus areas (e.g., `/audit security` or `/audit legal`) to run a subset of checks.

## Output

The audit produces a structured report with findings grouped by category, each rated by severity:

- **Critical**: Must fix. Security vulnerabilities, licence violations, broken builds, data loss risks.
- **High**: Should fix soon. Significant quality issues, missing tests for critical paths, architectural problems.
- **Medium**: Worth fixing. Code quality improvements, missing documentation, suboptimal patterns.
- **Low**: Nice to have. Style nits, minor improvements, optional enhancements.
- **Info**: Observations. Not problems, but worth noting — design trade-offs, areas of unusual complexity, things to watch.

Present findings as a numbered checklist grouped by category. For each finding, include:
- Severity rating
- Specific file:line references where applicable
- What the problem is and why it matters
- Suggested fix or approach

After presenting the full report, write it to `docs/audit-YYYY-MM-DD.md` (using today's date). The document should include a to-do checklist of actionable findings at the top, followed by the full detailed findings. Then append the audit-log entry (see "Audit log" section below) so both files are committed together. Offer to commit and push the report and log entry. Then ask the user which findings they want to address.

## Execution strategy

The audit has many independent phases. To complete it efficiently, use a team.

1. **Phase 0 (Orientation)** runs first — the lead agent does this itself to understand the project. This context informs which phases are relevant and what to tell teammates.

2. **Spawn a team** with audit-specialist teammates. Assign each teammate a subset of phases (e.g., "Code quality", "Security + Legal", "Testing + Performance", "Build/CI + Deps + Docs + Agent-friendliness + Portability"). The exact grouping depends on project size — for small projects 2-3 teammates suffice; for large projects use 4-5.

3. Each teammate receives the orientation summary and its assigned phases. Teammates work in parallel, producing findings in the standard format (severity, file:line, problem, fix). Teammates should be spawned with `subagent_type: "general-purpose"` since they need full tool access for builds, tests, and deep code exploration.

4. **Review gate**: Once all audit teammates have reported, the lead sends the collected findings to a **reviewer** teammate. The reviewer's job is adversarial — it challenges the findings, not the codebase. Specifically it should:
   - **Filter false positives**: Read the actual code at each file:line reference and verify the finding is real. Drop findings that misread context (e.g., a "hardcoded secret" that's a test fixture, a "missing error check" where the error is handled by the caller).
   - **Challenge severity**: Downgrade inflated ratings. A "High" that's mitigated by project context (e.g., internal-only library, no user input) should become Medium or Low. Upgrade under-rated findings if warranted.
   - **Spot contradictions**: Flag when findings from different phases contradict each other (e.g., one phase praises test coverage while another flags untested critical paths).
   - **Cut noise**: Remove findings that are technically correct but not actionable or useful — things the maintainer already knows and has consciously accepted, obvious trade-offs restated as problems, or findings so minor they waste the reader's attention.

   The reviewer returns a vetted list with annotations: each original finding marked as **kept** (optionally with revised severity), **dropped** (with reason), or **merged** (combined with a related finding).

5. The lead agent assembles the **final report** from the reviewer's vetted findings. Dropped findings are not included in the main report but may be summarised in a "Filtered out" appendix if the user wants full transparency.

This typically cuts audit wall-clock time by 3-4x compared to sequential execution and produces a higher signal-to-noise report than raw findings alone.

## Workflow

### Pre-flight: Audit log check

Before anything else, check whether a recent audit already exists. Read `docs/audit-log.md` if it exists and find the most recent `## ` entry containing `/audit`.

If a recent `/audit` entry exists (within the last 7 days AND at the same commit as `HEAD`):
- Present the previous outcome and any deferred items to the user
- Offer three options:
  - **Re-audit**: Proceed with a full audit from scratch
  - **Address deferred**: Skip the full audit and focus on the previously deferred items
  - **Skip**: No audit needed right now
- If the user chooses "Address deferred" or "Skip", stop here (no new log entry)

**Skip this check** if invoked by another skill (e.g., `/open-source`) — the calling skill manages flow control.

### Pre-flight: Working tree check

Before anything else, check `git status` and `git describe --tags --always`. If there are uncommitted changes (modified or untracked files beyond `.claude/`, `.mk/`, and other build artifacts):

1. **Warn** the user that the audit will reflect uncommitted state, which may not match any tagged version.
2. **Offer options**: Stash (`git stash`), Commit (stage and commit with a user-provided message), Abort (stop the audit), or Proceed anyway (audit the working tree as-is, noting the dirty state in the report).

Record the codebase version for the report header:
- **Commit**: short SHA from `git rev-parse --short HEAD`
- **Tag**: latest version tag from `git describe --tags --always`, or "untagged" if none
- **Dirty state**: if the working tree is dirty after the user's choice, note what is uncommitted (e.g., "3 modified files, 1 untracked") so the report is honest about what it audited

This information goes at the top of the audit report document, immediately after the title.

### Phase 0: Orientation

Before diving into checks, understand the project. **Start by running the companion gathering script:**

```
~/.claude/skills/audit/gather.sh
```

(It is already `chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command.)

This script collects baseline codebase metrics in one invocation (languages and LOC, build system, test frameworks, dependencies, licence, CI workflows, git stats, open issues/PRs, quick security scan, and TODO/FIXME counts). Parse its output, then supplement with deeper exploration as needed:

1. **Project survey**: Explore the project structure — languages, build system, directory layout, key entry points, public APIs, tests. Read CLAUDE.md, README, mkfile/Makefile, and any existing docs.

2. **Build system**: Determine how the project builds. If the project has a `mkfile`, run `mk --help-agent`. Try building and running tests to verify the project is in a working state. Note any build issues — they affect every subsequent check.

3. **Project type**: Classify the project:
   - Library (consumed as source/headers/package by other projects)
   - CLI tool (standalone binary with command-line interface)
   - Service (long-running server, API, daemon)
   - Hybrid (e.g., library with CLI wrapper)

   This determines which checks are relevant. A library doesn't need CLI flag checks; a service needs deployment and resilience checks a library doesn't.

4. **Language and ecosystem**: Note the primary language(s) and their ecosystem conventions. Many checks are language-specific (e.g., Go vet, Rust clippy, C++ sanitizers, Python type checking). Tailor recommendations to the ecosystem rather than imposing generic rules.

Present a brief orientation summary before proceeding to the audit phases.

### Phase 1: Code quality

Assess the code itself — structure, clarity, correctness, and maintainability.

#### 1.1 Architecture and design

- **Dependency structure**: Check for circular dependencies between modules/packages/files. Map the dependency graph if the project is large enough to warrant it.
- **Separation of concerns**: Are orthogonal concerns (I/O, business logic, presentation, platform-specific code) properly separated? Or is business logic tangled with database calls, HTTP handlers, or UI code?
- **API design**: Is the public API consistent? Do similar operations follow similar patterns? Are there naming inconsistencies, surprising parameter orders, or asymmetric designs (e.g., a `create` without a corresponding `delete`)?
- **Abstraction quality**: Are abstractions pulling their weight, or is there premature abstraction (one-implementation interfaces, unnecessary indirection)? Conversely, is there missing abstraction (duplicated logic that should be factored out)?
- **Module boundaries**: Are internal implementation details properly hidden from consumers? Check for public headers exposing internals, unexported functions that are imported anyway, or package-internal types in public APIs.

#### 1.2 Code correctness

- **Error handling**: Are errors checked consistently? Are there swallowed errors (empty catch blocks, ignored return values, unchecked error codes)? Do error messages include enough context to diagnose the problem?
- **Resource management**: Are resources (memory, file handles, database connections, locks) properly acquired and released? Check for RAII usage in C++, defer in Go, context managers in Python, try-with-resources in Java.
- **Null/nil safety**: Are there potential null pointer dereferences? Unchecked optional values? Functions that can return null but whose callers don't handle it?
- **Concurrency**: If the project uses threads, goroutines, async, or shared state — are there data races, deadlock risks, or missing synchronisation? Are concurrent data structures used where needed?
- **Integer overflow / type safety**: Are there arithmetic operations on user-controlled input without bounds checking? Implicit narrowing conversions? Signed/unsigned mismatches?
- **Edge cases**: Are boundary conditions handled? Empty collections, zero values, maximum values, Unicode, very long strings, concurrent access?

#### 1.3 Code hygiene

- **Dead code**: Search for unused functions, unreachable branches, commented-out code blocks, and unused imports/includes. Dead code rots — it confuses readers and accumulates tech debt.
- **Duplication**: Identify non-trivial copy-paste patterns (3+ lines repeated in multiple places). These are maintenance hazards — a fix in one copy is easily missed in others.
- **Naming**: Are names clear and consistent? Do variables, functions, and types follow the project's naming conventions? Flag misleading names (e.g., `isValid` that returns an error, `count` that returns a boolean).
- **Magic values**: Are there hardcoded numbers, strings, or paths that should be named constants or configuration? (Exception: 0, 1, "", and obvious literals don't need constants.)
- **TODOs and FIXMEs**: Catalogue them. Are any stale (referencing removed code or resolved issues)? Are any hiding real bugs (`// FIXME: this is wrong but works for now`)?
- **Code complexity**: Flag functions that are excessively long (100+ lines), deeply nested (4+ levels), or have high cyclomatic complexity. These are hard to understand, test, and maintain.

### Phase 2: Security

Assess the project for vulnerabilities and security hygiene. Scale the depth to the project's exposure — a library with no network access needs less scrutiny than a web service handling user input.

#### 2.1 Input handling

- **Injection**: Check for SQL injection (string concatenation in queries), command injection (unsanitised input in shell commands), path traversal (user input in file paths without validation), and template injection.
- **Validation**: Is input validated at system boundaries? Are there missing length limits, type checks, or range constraints on user-supplied data?
- **Deserialisation**: If the project deserialises untrusted data (JSON, XML, YAML, protobuf, pickle), are there safeguards against malicious payloads? Is the deserialiser configured safely (e.g., YAML safe_load vs load)?

#### 2.2 Secrets and credentials

- **Hardcoded secrets**: Search for API keys, tokens, passwords, private keys, connection strings, and other credentials in source code, config files, and test fixtures. Check common patterns: `password=`, `secret=`, `token=`, `api_key=`, `AWS_`, `BEGIN RSA PRIVATE KEY`, `BEGIN PRIVATE KEY`, base64-encoded blobs that decode to key material.
- **Credential files**: Check for `.env` files, `credentials.json`, `serviceAccountKey.json`, `.netrc`, `.npmrc` with tokens, SSH private keys, or similar files that should not be in version control.
- **Git history**: Note that even if secrets have been removed from the current tree, they may persist in git history. Flag this if credentials are found in any checked-in file that has been modified.

#### 2.3 Cryptography

- **Weak algorithms**: Flag use of MD5, SHA-1 (for security purposes), DES, RC4, ECB mode, or other deprecated cryptographic primitives. (SHA-1 and MD5 are fine for non-security purposes like checksums or cache keys — only flag security-sensitive uses.)
- **Hardcoded keys/IVs**: Check for encryption keys, initialisation vectors, or salts embedded in source code.
- **Random number generation**: Is `rand()`, `Math.random()`, or other non-cryptographic PRNGs used where cryptographic randomness is needed (token generation, nonce creation, key derivation)?

#### 2.4 Access and exposure

- **Overly permissive defaults**: Does the project default to insecure configurations (e.g., binding to 0.0.0.0, CORS allow-all, debug mode enabled, authentication disabled)?
- **Error information leakage**: Do error messages or stack traces expose internal paths, database schemas, or other implementation details to end users?
- **Dependency vulnerabilities**: If the ecosystem has a vulnerability scanner (npm audit, cargo audit, pip-audit, govulncheck), note whether it's integrated into the build/CI pipeline.

### Phase 3: Testing

Assess test coverage, quality, and infrastructure.

#### 3.1 Coverage

- **Critical path coverage**: Are the most important code paths tested? Identify functions, modules, or features that have no tests at all and assess their risk. Focus on business logic, security-sensitive code, and error handling paths.
- **Edge case coverage**: Are boundary conditions tested? Empty inputs, maximum values, concurrent access, error conditions, timeout scenarios.
- **Negative testing**: Are failure modes tested? Invalid input, network errors, disk full, permission denied, malformed data.

#### 3.2 Test quality

- **Assertion quality**: Are tests making meaningful assertions, or just checking that code runs without crashing? A test that calls a function and asserts nothing is a false sense of security.
- **Test isolation**: Do tests depend on external state (filesystem, network, databases, environment variables, other tests' side effects)? Tests that depend on shared state are fragile and can produce intermittent failures.
- **Test naming and organisation**: Can you understand what a test verifies from its name? Are tests organised logically (by feature, by module, by scenario)?
- **Flakiness indicators**: Are there sleep/delay calls in tests? Tests that retry on failure? Tests with comments like "sometimes fails"?

#### 3.3 Test infrastructure

- **Runability**: Can tests be run with a single command? Are there undocumented prerequisites (databases, services, env vars)?
- **Speed**: Are there obviously slow tests that could be faster (e.g., sleeping instead of using test clocks, making real network calls instead of mocking)?
- **CI integration**: Are tests run in CI? On every push? On PRs? Are there tests that only run locally but not in CI (or vice versa)?

### Phase 4: Performance

Identify obvious performance issues and anti-patterns. This is not a benchmarking phase — it's a code review for performance red flags.

- **Algorithmic complexity**: Flag O(n^2) or worse algorithms where O(n) or O(n log n) alternatives exist. Common culprits: nested loops over the same collection, repeated linear searches, string concatenation in loops.
- **Unnecessary allocation**: Repeated allocation in hot loops, allocating large buffers that could be reused, creating temporary objects that could be avoided (e.g., string formatting in logging calls that are disabled).
- **Unnecessary copies**: Large objects passed by value where a reference/pointer would suffice. String copies where string_view/span would work. Copying collections when a move or reference would do.
- **I/O patterns**: Unbuffered I/O, excessive small reads/writes, missing connection pooling, N+1 query patterns in database code.
- **Missing caching**: Repeated expensive computations (file reads, network calls, complex calculations) that produce the same result and could be cached.
- **Resource leaks**: Connections, file handles, or goroutines/threads that are created but never cleaned up, especially in error paths.

### Phase 5: Build, CI/CD, and infrastructure

Assess the build system, continuous integration, and project infrastructure.

#### 5.1 Build system

- **Reproducibility**: Does the build produce consistent output? Are there non-deterministic elements (timestamps, random values, unordered maps serialised to output)?
- **Build correctness**: Does the build actually work? Run it and report any warnings or errors. Check for missing dependencies, incorrect paths, or stale build rules.
- **Parallel builds**: Is the build configured for parallel execution where the build tool supports it?
- **Build warnings**: Are compiler/linter warnings enabled? Are there suppressed warnings that should be addressed? Is the project clean at the highest reasonable warning level?

#### 5.2 CI/CD

- **Pipeline existence**: Does CI exist? What does it run (build, test, lint, security scan)?
- **Pipeline completeness**: Is the pipeline missing important steps? Common gaps: no linting, no security scanning, no build on multiple platforms when the project targets multiple platforms, tests only on one OS.
- **Pipeline correctness**: Do CI config files reference correct branches, build commands, and artifacts? Are there CI configs that are clearly stale or broken?
- **Secrets management**: Are CI secrets (tokens, keys) configured via the CI platform's secret store, or are they hardcoded in workflow files?
- **Merge settings**: Verify squash-only merge is enabled (`allow_merge_commit` and `allow_rebase_merge` should be false), squash commit title is set to `PR_TITLE`, and delete-branch-on-merge is enabled. Check via `gh api repos/{owner}/{repo} --jq '{allow_squash_merge, allow_merge_commit, allow_rebase_merge, squash_merge_commit_title, delete_branch_on_merge}'`. Flag deviations.

#### 5.3 Repository hygiene

- **Gitignore coverage**: Does `.gitignore` cover build artifacts, IDE files (`.vscode/`, `.idea/`), OS files (`.DS_Store`, `Thumbs.db`), dependency directories, and generated files? Flag anything tracked that should be ignored.
- **Large files**: Find files > 1MB that aren't clearly intentional. Binary files, data dumps, or vendored archives that inflate the repo.
- **Sensitive files**: Check for `.env`, credential files, private keys, or other files that should never be in version control.
- **Branch hygiene**: Is the default branch `master`? Are there stale branches?

### Phase 6: Legal and licensing

Assess licence compliance and legal hygiene. This is a **critical** category for open-source projects — licence violations can have serious legal consequences. For proprietary projects, focus on dependency compliance without adding a project licence.

#### 6.1 Project licence

First, assess if the project is intended for open-source distribution:
- Check CLAUDE.md for a marker like "## Private Project" or similar comment indicating proprietary status.
- If gh (GitHub CLI) is available, run `gh repo view --json visibility -q .visibility` to check if the repo is "public" or "private". If private, treat as proprietary and add "## Private Project" marker to the top of CLAUDE.md for future audits.
- Look for other indicators: public repository, project description mentions open-source, or existing licence files.

If it's proprietary or internal, licence compliance still matters for dependencies, but skip adding a project licence.

- **Licence file**: If open-source, does the project have a `LICENSE` file? Is it a recognised open-source licence? Is it the one the project intends (check SPDX identifiers in source headers if present)?
- **Licence consistency**: If open-source, do source file headers (if present) match the project-level licence? Are there files with conflicting or missing licence headers?
- **Copyright notices**: Are copyright years current? Is the copyright holder correctly identified?

#### 6.2 Third-party compliance

- **Dependency licence inventory**: For every third-party dependency (vendored, submoduled, package-managed, or copied), identify its licence. Flag any that are:
  - **Incompatible** with the project's licence (e.g., GPL code in an Apache/MIT project)
  - **Copyleft** (GPL, LGPL, MPL) — these have specific obligations that must be understood
  - **Unknown** — no licence file or licence identifier found
  - **Commercial / proprietary** — requires a licence agreement

- **Attribution requirements**: Check whether the project satisfies the attribution requirements of its dependencies. Most open-source licences (MIT, BSD, Apache 2.0) require the licence text to be included with distributions. Verify that a NOTICES, THIRD_PARTY, or equivalent file exists and covers all dependencies, or that licence files are included alongside vendored code.

- **Licence file presence**: For each vendored or copied dependency, check that its original licence file is included in the repo. A dependency without its licence file is a compliance gap even if the project's NOTICES file lists it.

#### 6.3 Internal references

- **Private references**: Search for internal hostnames, private repo URLs, company-internal references, internal issue tracker links, or TODOs marked private/internal. These should not be in public repositories.
- **Personal information**: Check for email addresses, names, or other PII that shouldn't be public (beyond standard copyright notices and git history).

### Phase 7: Documentation

Assess documentation completeness and accuracy. This phase overlaps with the `/docs` skill — it performs a documentation audit at the same depth, but as part of a broader codebase review rather than as a standalone documentation project.

Follow the same audit methodology as the `/docs` skill's Phase 2 (Audit), evaluating:

1. **Project overview** (README.md) — clear description, quickstart, build instructions, examples, licence notice
2. **Architecture documentation** — system design, data flow, key decisions
3. **API documentation** — public interfaces, parameters, return values, error handling, examples
4. **User guide / tutorials** — getting started, common workflows, configuration reference
5. **Development guide** — dev environment setup, code style, how to run tests
6. **Inline code documentation** — complex logic explained, public APIs documented at declaration, no stale comments
7. **Testing documentation** — how to run tests, test strategy, how to add tests
8. **CLAUDE.md** — accurate, current, covers build commands, architecture, conventions

For each document category, assess: exists? accurate? complete? stale?

Rate documentation findings by severity using the same scale as other audit categories. Missing docs for a public API used by external consumers is **High**; a missing internal architecture doc is **Medium**; a stale comment is **Low**.

### Phase 8: Dependency health

Assess the health and hygiene of project dependencies.

- **Outdated dependencies**: Are any dependencies significantly behind their latest versions? Are there known security fixes in newer versions?
- **Unmaintained dependencies**: Are any dependencies archived, abandoned, or not updated in 2+ years? These are risks — bugs won't be fixed, security issues won't be patched.
- **Unnecessary dependencies**: Are there dependencies that are only used in one place, or that duplicate functionality already available in the language's standard library or another existing dependency?
- **Vendoring hygiene**: If the project vendors dependencies, are they clean copies or have they been modified? Modified vendored code is a maintenance hazard — upgrades require re-applying patches.
- **Pinning**: Are dependency versions pinned? Unpinned dependencies can break builds when upstream releases a breaking change.

### Phase 9: Agent-friendliness

Assess how well the project supports AI-assisted development workflows.

- **CLAUDE.md**: Does it exist? Is it accurate and current? Does it cover build commands, architecture, key files, conventions, and testing? Would an AI agent be able to build, test, and make changes to the project using only the information in CLAUDE.md?
- **agents-guide.md**: For projects that are consumed by other projects (libraries, tools), does an agents-guide.md exist? Is it concise enough for a context window? Does it cover the essential API surface, common patterns, and gotchas?
- **Build discoverability**: Can an agent figure out how to build and test the project without human help? Is the build command documented? Does it work without undocumented prerequisites?
- **Error message quality**: When things fail (build errors, test failures, runtime errors), do the error messages contain enough information to diagnose the problem? Or do they produce cryptic output that requires human interpretation?
- **Project structure clarity**: Is the project structure conventional for its language/framework, or is it unusual in ways that would confuse an agent? Are important files in expected locations?
- **CLI `--help-agent` flag**: If the project produces standalone binaries, does it support `--help-agent` to emit both CLI reference and agent guide in one call?

### Phase 10: Portability and compatibility

Assess platform assumptions and compatibility constraints.

- **Platform assumptions**: Does the code assume a specific OS, architecture, or environment? Are path separators hardcoded (`/` vs `\`)? Are there endianness assumptions? POSIX-specific system calls without Windows alternatives (or vice versa)?
- **Compiler / runtime requirements**: Are minimum version requirements documented? Does the code use features that require a specific version (e.g., C++23 features, Go 1.22 range-over-func)?
- **Implicit environment dependencies**: Does the code assume the presence of specific tools, environment variables, or system libraries without documenting them?

## Audit log

Before offering to commit, append an entry to `docs/audit-log.md` (create the file with the standard header if it doesn't exist — see `~/.claude/skills/audit-log-convention.md` for the format). This ensures the log entry is committed alongside the report.

The entry should include finding counts by severity and any deferred items. Example:

```markdown
## 2026-02-25 — /audit

- **Commit**: `790893a`
- **Outcome**: 30 findings (4 critical, 7 high, 5 medium, 5 low, 9 info). Report: docs/audit-2026-02-25.md. All critical/high items addressed.
- **Deferred**:
  - audit.max_size_mb not enforced (medium)
  - 5 packages at 0% test coverage (high)
```

**Skip this step** if invoked as part of another skill (e.g., `/open-source`) — the parent skill will log a summary entry.

## Calling from other skills

The `/audit` skill is designed to be invoked by other skills that need a codebase assessment. When called from another skill:

- The calling skill may specify which phases to run (e.g., "Run Phase 6: Legal and licensing only")
- The calling skill may provide additional context (e.g., "This project is about to be open-sourced" or "This is a pre-release audit")
- Findings are returned to the calling skill for integration into its own workflow

The `/open-source` skill delegates its audit phase to `/audit`. The `/release` skill's licence attribution check (Phase 1, step 8) is a subset of `/audit` Phase 6.

## Skill improvement

After each audit, reflect on whether any reusable insights were gained — new categories of issues worth checking, better patterns for specific languages or project types, checks that would have caught problems earlier. Pay special attention to unexpected failures in companion scripts (e.g., `gather.sh`) or tool invocations encountered during the run — these may indicate bugs to fix in the skill or its scripts, not just one-off issues. If any improvements are identified, propose the specific changes to this skill file (or its companion files) to the user. Only integrate them with user consent.
