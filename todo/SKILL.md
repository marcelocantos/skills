---
name: todo
description: Summarise open TODOs from the project's todo file.
user-invocable: true
---

Find and summarise open TODO items for this project.

1. Check the repo-local `CLAUDE.md` for a mentioned TODO file path (e.g.
   `docs/todo.md`, `TODO.md`, `todo.md`).
2. If `CLAUDE.md` doesn't mention one, look for common names: `docs/todo.md`,
   `TODO.md`, `todo.md`, `docs/TODO.md`.
3. If no file is found, say so and offer to create one.

Once found, read the file and present a concise summary:
- Group items by section/heading as they appear in the file.
- Show only **open** items (`- [ ]`). Skip completed (`- [x]`) and
  struck-through items.
- For each item, show the bold title and a short one-line description
  (not the full design notes).
- End with a count: "N open items across M sections."
