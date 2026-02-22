---
name: republish-skills
description: Sync ~/.claude/skills/ to the marcelocantos/skills GitHub repo.
user-invocable: true
---

# Republish Skills

Syncs the contents of `~/.claude/skills/` to the `marcelocantos/skills` GitHub repo and pushes.

## Workflow

1. **Sync**: Copy all files from `~/.claude/skills/` into the local clone at `~/work/github.com/marcelocantos/skills/`, replacing existing content (except `.git/` and `README.md`).

2. **Regenerate README**: Rebuild `README.md` from the current set of skills. Format:

   ```markdown
   # Skills

   Claude Code skills for use with `~/.claude/skills/`.

   ## Available Skills

   - **[`/skill-name`](skill-name/SKILL.md)** — Description from the skill's frontmatter.
   ...

   ## License

   Apache-2.0
   ```

   Read each skill's `SKILL.md` frontmatter `description` field to generate the bullet. Sort skills alphabetically.

3. **Diff**: Show the user what changed (`git diff` + any untracked files). If nothing changed, say so and stop.

4. **Commit and push**: Commit all changes with a descriptive message summarising what was added/changed/removed, then push to `origin master`.
