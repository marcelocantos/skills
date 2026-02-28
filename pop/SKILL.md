---
name: pop
description: Restore conversation context saved by /stash after a /clear.
user-invocable: true
---

Restore conversation context saved by `/stash`.

## Steps

1. **Read the snapshot.** Read `stash-context.md` from your auto-memory
   directory (the path is in your system prompt). If the file doesn't
   exist, tell the user "No saved context found. Use `/stash` to save
   context before `/clear`." and stop.

2. **Present the context.** Display the snapshot contents as a briefing
   to the user.

3. **Clean up.** Run the cleanup script:
   ```
   ~/.claude/skills/pop/cleanup.sh <auto-memory-dir>
   ```
   where `<auto-memory-dir>` is your auto-memory directory path from the
   system prompt.

4. **Ask what's next.** Ask the user what they'd like to do.
