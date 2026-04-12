---
name: stash
description: Save conversation context to auto-memory before /clear. Restore later with /pop.
user-invocable: true
---

Save the current conversation state so it survives a `/clear`.

## Steps

1. **Gather context.** Review the full conversation and produce a snapshot
   covering these sections (skip any that have nothing to report):

   - **Summary** — 1-3 sentences: what was happening in this session.
   - **Key Decisions** — Bullet list of design choices, trade-offs, or
     explicit decisions made.
   - **Current State** — What was just done, what's built/broken, working
     tree status (run `git status --short --branch`).
   - **Next Steps** — What was about to happen or what the user likely
     wants to do next.
   - **Important Context** — Anything hard to reconstruct: specific
     findings, gotchas, values, paths, error messages discovered during
     exploration.

2. **Check convergence targets.** Call `bullseye_list(cwd)` (where `cwd`
   is the project's working directory) to retrieve active targets. If the
   bullseye MCP server is not registered (tool not found), **stop and
   report**:

   > **Error: bullseye MCP server is not registered.**
   > Add it via `claude mcp add` or check `~/.claude.json`. /stash
   > needs bullseye to check target state before stashing.

   If the tool exists but returns no targets (empty project), skip
   target checking and proceed. Otherwise, check whether any targets
   were affected during this session. If so, prompt the user:
   "These targets may have changed status during this session: [list].
   Update before stashing?" If the user confirms, call the appropriate
   bullseye tools (`bullseye_put`, `bullseye_retire`)
   to apply the changes. If they decline or there are no changes, proceed.

3. **Write the snapshot.** Pipe the snapshot markdown into
   `~/.claude/skills/stash/save.sh` — it derives the auto-memory
   directory via the shared `_shared/memory-path.sh` helper and writes
   the file to `<dir>/stash-context.md`. Use this format:

   ```bash
   ~/.claude/skills/stash/save.sh <<'EOF'
   # Saved Context
   **Saved**: {YYYY-MM-DD HH:MM}

   ## Summary
   ...

   ## Key Decisions
   ...

   ## Current State
   ...

   ## Next Steps
   ...

   ## Important Context
   ...
   EOF
   ```

4. **Prompt the user.** Output:

   > Context saved. Run `/clear`, then `/pop` to restore.
