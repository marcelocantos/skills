---
name: docs
description: End-to-end documentation sherpa — audit, plan, and write all project documentation.
user-invocable: true
---

**DELEGATE VIA AGENT.** Spawn an Agent (subagent_type: general-purpose,
model: opus) with the prompt `"Read and execute
~/.claude/skills/docs/worker.md. Return the full documentation audit
and prioritised recommendations."`. Relay the agent's result to the
user.

The worker handles Phases 1-3 (Discovery, Audit, Recommendations).
After presenting the recommendations, the root session handles
Phases 4-5 (Execution, Verification) interactively — drafting docs,
reviewing with the user, and committing.

## Phase 4: Execution

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

## Phase 5: Verification

After all writing is done:

1. **Command verification**: Run every build/test/install command mentioned in the docs to confirm they work.

2. **Link check**: Run `~/.claude/skills/docs/link-check.sh` (directly — it is `chmod +x`). It walks all `*.md` files and reports broken local links in the format `<source>:<line>: broken link: <target>`. Exit code 0 means clean; non-zero means broken links. For each reported break, read the source file to understand context and fix the link (or file reference) before proceeding.

3. **Consistency check**: Ensure terminology, project name, and conventions are consistent across all docs.

4. **Commit**: If any files were created or modified, commit all documentation changes with a descriptive message summarising what was added or updated.

5. **Final summary**: Report what was created, updated, and verified. List any remaining items the user deferred.

## Skill improvement

After each documentation run, reflect on whether any reusable insights were gained — new document categories worth auditing, better quality checks, patterns for structuring docs in specific project types, or improvements to the workflow phases. Pay special attention to unexpected failures in companion scripts or tool invocations encountered during the run. If any improvements are identified, propose the specific changes to the skill files to the user. Only integrate them with user consent.
