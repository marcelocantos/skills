---
name: status
description: Show project maintenance status from the audit log — recent activities, deferred items, and time since last audit/release/docs.
user-invocable: true
---

# Project Status

Reads `docs/audit-log.md` in the current repo and presents a maintenance status summary.

## Invocation

The user runs `/status`. No arguments needed.

## Workflow

### Step 1: Read the log

Read `docs/audit-log.md` in the current repo. If it doesn't exist, report:

> No audit log found. Run `/audit` to create one, or see the [audit log convention](~/.claude/skills/audit-log-convention.md) for the format.

### Step 2: Parse entries

Each entry starts with a `## ` heading in the format:

```
## YYYY-MM-DD — /skill-name [optional context]
```

Parse all entries and extract:
- Date
- Skill name (or free-form process name)
- Commit SHA
- Outcome summary
- Deferred items (if any)

### Step 3: Present summary

Display a concise status report:

#### Activity timeline

List all entries in reverse chronological order (newest first for display), showing date, skill, and a one-line outcome. For long logs (10+ entries), show only the last 10 and note the total count.

#### Key dates

Report time since:
- **Last audit**: date and how many days ago (or "never")
- **Last release**: date, version, and how many days ago (or "never")
- **Last docs pass**: date and how many days ago (or "never")

#### Unresolved deferred items

Collect all items from **Deferred** sections across all entries. An item is considered **resolved** if a subsequent entry's outcome mentions addressing it, or if a later entry for the same skill has no deferred items (implying a clean re-run). Present unresolved items grouped by the entry they came from, with the date.

If there are no unresolved deferred items, say so.

### Step 4: Suggest next action

Based on the status:
- If no audit has been run in 30+ days, suggest `/audit`
- If there are unresolved deferred items, suggest addressing them
- If the log is healthy and recent, say so

## Notes

- This skill is read-only — it does not modify the audit log
- It does not aggregate across repos — use `/progress-report` for cross-repo activity
- It does not append an entry to the audit log (status checks are not maintenance activities)
