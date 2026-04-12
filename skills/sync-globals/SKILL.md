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

For each repo with issues, invoke `~/.claude/skills/sync-globals/fix-repo.sh <repo-path>` with the relevant flags — pass only what the audit flagged:

- `--license` — write Apache 2.0 LICENSE (skips if already present)
- `--spdx` — prepend two-line SPDX header to all unlicensed source files
- `--gitignore` — write minimal .gitignore (skips if already present)
- `--notice` — write NOTICE file (skips if already present)

Override `--year` and `--holder` when the repo uses a non-default copyright holder. The script reports each file it modifies to stdout and skips files that already exist (with a stderr message).

Example invocation:

```sh
~/.claude/skills/sync-globals/fix-repo.sh ~/work/github.com/marcelocantos/myrepo \
    --license --spdx --gitignore --notice
```

After fixing, review the diffs, commit to a branch, and use `/push` if the user wants PRs.

IMPORTANT: Never push directly to master. Always confirm before committing.
