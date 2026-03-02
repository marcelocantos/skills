# Audit Log Convention

Reference document for the `docs/audit-log.md` file that skills append to. This is not a skill — it defines the shared format and rules.

## Location

`docs/audit-log.md` in each repository root.

## File structure

```markdown
# Audit Log

Chronological record of audits, releases, documentation passes, and other
maintenance activities. Append-only — newest entries at the bottom.

## YYYY-MM-DD — /skill-name [optional context]

- **Commit**: `abc1234` (or "working tree dirty — `abc1234`")
- **Outcome**: 1-2 sentence summary of what was done and key results
- **Deferred**:
  - item 1 (reason or category)
  - item 2
```

## Entry format rules

- The `## ` heading is the entry delimiter — agents parse on this.
- Date is ISO 8601 (`YYYY-MM-DD`).
- Skill name is the slash-command name (e.g., `/audit`, `/release`, `/docs`).
- `[optional context]` is for version tags (`v0.1.0`), scope (`security only`), or parent reference (`via /open-source`).
- **Commit** is the short SHA of HEAD when the skill started (the state that was examined), captured via `git rev-parse --short HEAD` before making any changes. If the working tree had uncommitted changes at that point, use `"working tree dirty — \`abc1234\`"` to flag this while still recording the base commit.
- **Outcome** is a brief factual summary — finding counts, what was written, version released, etc.
- **Deferred** lists items that were identified but not addressed. Omit this section entirely if nothing was deferred.
- Non-agentic entries use a free-form name instead of `/skill-name` (e.g., `manual security review`, `CI migration`, `dependency upgrade`).

## When to log

Each skill appends an entry **before the final commit** of its workflow, so the entry is included in the same commit as the skill's work. This avoids orphaned log entries that drift into the next work cycle.

Exception: orchestrator skills (e.g., `/open-source`) that delegate to sub-skills spanning multiple commits may append after the final sub-skill completes and commit the entry as a follow-up push.

## When NOT to log

1. **Child invocation**: When a skill is invoked by another skill (e.g., `/audit` called by `/open-source`), the child skips logging. The parent logs a single summary entry covering all sub-skills.
2. **Same-day dedup**: If an entry for the same skill already exists today at the same commit, skip logging.
3. **Aborted runs**: If the user aborts mid-skill, do not log.

## Staleness check (audit skill only)

Before starting, `/audit` reads the log and checks the most recent `/audit` entry. If it is within the last 7 days AND at the same commit, offer the user three options:
- **Re-audit**: Full audit from scratch
- **Address deferred**: Focus only on previously deferred items
- **Skip**: No audit

This check is skipped when `/audit` is invoked by another skill.

## Non-agentic contributions

The format is simple enough to append manually. Example:

```markdown
## 2026-03-15 — dependency upgrade

- **Commit**: `f4e2a1b`
- **Outcome**: Upgraded gopkg.in/yaml.v3 to v3.1.0
```

## How `/waw` uses the log

The `/waw` skill reads `docs/audit-log.md` (in its "Maintenance status"
section) and presents:
- Time since last audit, release, and docs pass
- Unresolved deferred items (items in deferred lists not addressed by a later entry)
- A nudge if an audit is overdue or deferred items need attention
