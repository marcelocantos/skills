---
name: todo
description: Summarise and manage open TODOs for this project via mnemo, and triage them toward convergence targets.
user-invocable: true
---

Manage TODO items for this project, backed entirely by the mnemo MCP
server. Behaviour depends on whether arguments are provided after `/todo`.

mnemo indexes `TODO.md` / `todos.md` (and any configured `todo_glob`)
anywhere within a project's tree, parses the Obsidian Tasks dialect
(📅 due, ⏳ scheduled, 🛫 start, ✅/❌ done/cancelled, 🔺⏫🔼🔽⏬ priority,
🔁 recurrence, #tags, [[links]]), and exposes query/add/edit tools. There
is no file to locate or `cat` — the index is the source of truth.

If a mnemo tool errors (e.g. connection refused), the daemon isn't
running; tell the user to start it (`brew services start mnemo`) rather
than falling back to reading files by hand.

## Step 1 — Gather

Call `mnemo_todos` scoped to the current project:
- `repo`: the current repo — its name, or a path fragment of the cwd
  (e.g. the project directory name) when the name isn't known.
- `status`: `open`.

Each result carries its `section`, `priority`, `due` date, `tags`,
overdue flag, source `file_path`, and `id`. The `id` is what you pass to
`mnemo_todo_set` to edit an item in place.

If the result is empty, the project has no open TODOs (or none indexed
yet) — take the "no open items" branch in Step 2.

## Step 2 — Act

### If there are no open items

- **`/todo` (no args)**: Report that there are no open TODOs and offer to
  start one — `mnemo_todo_add` creates `docs/TODO.md` on the first add.
- **`/todo <text>`**: Add it (see below); the file is created
  automatically if absent.

### `/todo` (no arguments) — Summarise & triage

Present the open work grouped by section/heading as `mnemo_todos` reports
it. Surface **overdue** items first (mnemo flags them). For each item show
the bold title and a short one-line description (not the full notes),
prefixed with a category emoji inferred from its content:
- 🐛 Bug — fixes, crashes, error handling, regressions
- ✨ Feature — new functionality, user-facing additions
- 🔧 Tooling — build, CI, developer workflow, editor config
- 🏗️ Architecture — refactoring, restructuring, design patterns
- 💡 Idea — speculative, exploratory, "think about" items
- 📖 Docs — documentation, README, comments, guides
- 🔒 Security — auth, permissions, secrets, vulnerability fixes
- 📦 Dependency — upgrades, vendoring, package management
- 📋 Task — anything that doesn't fit the above

**Triage pass — two tracking systems, one flow:**

> **TODOs** = inbox (low-friction capture)
> **Targets** = backlog (desired states the agent converges toward)

Items flow upward: a thought lands in a TODO, gets triaged into a target
(or discarded), and the TODO list drains toward empty. For each item,
assess where it belongs and offer the matching action:
- 🎯 **Promote to target** — items describing a desired state ("all tests
  pass on CI", "dispatch supports structured results"). Offer to create it
  (`bullseye_put`, or suggest `/target …`); once it's captured, mark the
  TODO done with `mnemo_todo_set id:<id> status:done`.
- ✅ **Keep as TODO** — speculative ideas, trivial one-offs, notes to self
  that don't warrant tracking overhead.
- 🗑️ **Discard** — stale, already done, or superseded. Offer to close it
  with `mnemo_todo_set id:<id> status:cancelled`.

Only mutate (promote, mark done/cancelled) with the user's go-ahead.

End with a count: "N open TODOs (K promote candidates, M overdue)."

### `/todo <text>` — Add a new item

Call `mnemo_todo_add` with:
- `dir`: the current working directory (resolves to this project's
  `docs/TODO.md`, created if absent) — **or** `file` for an explicit path.
- `text`: the item, including any Obsidian decorations the user supplied
  (e.g. `📅 2026-07-01 ⏫ #docs`).
- `section`: the most appropriate existing heading for the item's content;
  omit to append at end of file.

The tool creates the file when needed, writes atomically, and re-indexes
immediately. Confirm with the returned item text, its `file_path`, and the
section it landed in.
