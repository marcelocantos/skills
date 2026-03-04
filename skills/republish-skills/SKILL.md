---
name: republish-skills
description: Sync ~/.claude/skills/ to the marcelocantos/skills GitHub repo.
user-invocable: true
---

# Republish Skills

Syncs the contents of `~/.claude/skills/` to the `marcelocantos/skills` GitHub repo and pushes.

## Gate check

Before publishing, enforce the `skill` gate profile:

1. Read `~/.claude/gates/base.yaml` and `~/.claude/gates/skill.yaml`.
2. Merge them (skill profile skips ci-green, tests-exist, pr-workflow).
3. Check each `pre-publish` gate:
   - **republish-clean**: This is satisfied by the publish step itself
     succeeding — if the script fails, the gate fails.
4. If the skill changes affect other skills that have their own gate
   profiles, note it but don't block — skill publishing is about syncing
   the definitions, not enforcing downstream project gates.

## Workflow

Execute `~/.claude/skills/republish-skills/publish.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command).
