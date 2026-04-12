---
name: pop
description: Restore conversation context saved by /stash after a /clear.
user-invocable: true
---

Restore conversation context saved by `/stash`.

## Steps

1. **Read the snapshot.** Run `~/.claude/skills/_shared/memory-path.sh`
   to get `<dir>`, then read `<dir>/stash-context.md`. If the file
   doesn't exist, tell the user "No saved context found. Use `/stash`
   to save context before `/clear`." and stop.

2. **Present the context.** Display the snapshot contents as a briefing
   to the user.

3. **Clean up.** Run the cleanup script, letting the shared helper
   re-derive the auto-memory directory:
   ```bash
   ~/.claude/skills/pop/cleanup.sh "$(~/.claude/skills/_shared/memory-path.sh)"
   ```

4. **Ask what's next.** Ask the user what they'd like to do.
