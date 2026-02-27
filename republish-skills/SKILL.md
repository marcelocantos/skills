---
name: republish-skills
description: Sync ~/.claude/skills/ to the marcelocantos/skills GitHub repo.
user-invocable: true
---

# Republish Skills

Syncs the contents of `~/.claude/skills/` to the `marcelocantos/skills` GitHub repo and pushes.

## Workflow

Execute `~/.claude/skills/republish-skills/publish.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command).

After completion, print the repo URL: https://github.com/marcelocantos/skills
