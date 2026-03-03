---
name: todo
description: Summarise open TODOs from local todo file and GitHub issues.
user-invocable: true
---

Manage TODO items for this project. Behaviour depends on whether
arguments are provided after `/todo`.

## Step 1 — Gather

Execute `~/.claude/skills/todo/gather.sh` directly (it is already `chmod +x` —
do **not** wrap it in `bash`, just invoke the path as the command). This script
locates the TODO file (checking CLAUDE.md for a path hint, then trying common
names) and dumps its contents in one call.

Parse the output:
- `# claude-md-hint` — any mention of a TODO file in CLAUDE.md.
- `# todo-file` — either `path: <path>` followed by `---` and the file
  contents, or `(not found)`.
- `# github-issues` — open GitHub issues from `gh issue list`, or a
  skip message if `gh` is unavailable / not in a repo.

## Step 1.5 — Normalise path

If a TODO file was found but its path is non-standard, flag it before
proceeding:
- **Wrong case** (e.g. `todo.md`, `Todo.md`): tell the user and offer to
  `git mv` it to the all-caps `TODO.md` equivalent.
- **Wrong directory** (e.g. `TODO.md` or `todo.md` in the repo root instead
  of `docs/`): tell the user and offer to `git mv` it to `docs/TODO.md`.
- If both are wrong, offer a single move (e.g. `todo.md` → `docs/TODO.md`).

Only proceed with the rename if the user agrees. Use `git mv` so history
is preserved. After renaming, update the project's `CLAUDE.md` if it
references the old path.

## Step 2 — Act

### If no TODO file was found

- **`/todo` (no args)**: Report that no TODO file exists and offer to create
  `docs/TODO.md` (always all-caps `TODO`).
- **`/todo <text>`**: Create `docs/TODO.md` automatically (always all-caps `TODO`) and add the item.

### `/todo` (no arguments) — Summarise

Present a combined view of all open work:

**Local TODOs** (from the TODO file):
- Group items by section/heading as they appear in the file.
- Show only **open** items (`- [ ]`). Skip completed (`- [x]`) and
  struck-through items.
- For each item, show the bold title and a short one-line description
  (not the full design notes).
- Prefix each item with a category emoji inferred from its content:
  - 🐛 Bug — fixes, crashes, error handling, null refs, regressions
  - ✨ Feature — new functionality, user-facing additions
  - 🔧 Tooling — build, CI, developer workflow, editor config
  - 🏗️ Architecture — refactoring, restructuring, design patterns
  - 💡 Idea — speculative, exploratory, "think about" items
  - 📖 Docs — documentation, README, comments, guides
  - 🔒 Security — auth, permissions, secrets, vulnerability fixes
  - 📦 Dependency — upgrades, vendoring, package management
  - 📋 Task — anything that doesn't fit the above categories

**GitHub Issues** (from the gather output):
- List open issues with number, title, and labels.
- Group by label if labels are present; otherwise list flat.

End with a combined count: "N local TODOs, M GitHub issues open."

### `/todo <text>` — Add a new item

Use the `path:` from the gather output. Append the provided text as a new
open TODO item (`- [ ] …`) to the file. Choose the most appropriate existing
section based on the item's content. If no section fits well, append to the
end of the file.

After adding, confirm with the item text and the section it was placed in.
