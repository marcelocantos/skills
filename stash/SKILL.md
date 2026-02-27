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

2. **Write the snapshot.** Write the snapshot as markdown to
   `stash-context.md` inside your auto-memory directory (the path is in
   your system prompt). Use this format:

   ```
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
   ```

3. **Prompt the user.** Output:

   > Context saved. Run `/clear`, then `/pop` to restore.
