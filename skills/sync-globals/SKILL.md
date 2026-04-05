---
name: sync-globals
description: sync-globals
user-invocable: true
---

**DELEGATE VIA AGENT.** Spawn an Agent (subagent_type: general-purpose,
model: opus) with the prompt `"Read and execute
~/.claude/skills/sync-globals/worker.md. Return the compliance
report."`. Relay the agent's result to the user.

The worker handles Steps 1-5 (discover repos, read directives, check
compliance, update manifest, generate report). After presenting the
report, the root session handles Step 6 (Fix mode) if the user
requests it:

## Step 6: Fix mode (if requested)

For each repo with issues, `cd` into it and apply fixes:
- **Missing/wrong license**: Write the correct LICENSE file (Apache 2.0 with correct copyright)
- **Missing SPDX headers**: Add 2-line SPDX header to all source files
- **Missing .gitignore**: Create one appropriate for the language
- **Missing NOTICE**: Create if Apache 2.0 and not present

After fixing, commit changes to a branch and use `/push` if the user wants PRs.

IMPORTANT: Never push directly to master. Always confirm before committing.
