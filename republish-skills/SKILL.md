---
name: republish-skills
description: Sync ~/.claude/skills/ to the marcelocantos/skills GitHub repo.
user-invocable: true
---

# Republish Skills

Syncs the contents of `~/.claude/skills/` to the `marcelocantos/skills` GitHub repo and pushes.

## Workflow

Run `mk` (**NOT `make`**) in `~/work/github.com/marcelocantos/skills/`. It handles syncing, README generation, diffing, committing, and pushing.

After completion, print the repo URL: https://github.com/marcelocantos/skills
