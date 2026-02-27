---
name: todo
description: Summarise open TODOs from the project's todo file.
user-invocable: true
---

Manage TODO items for this project. Behaviour depends on whether
arguments are provided after `/todo`.

## Locate the TODO file

1. Check the repo-local `CLAUDE.md` for a mentioned TODO file path (e.g.
   `docs/todo.md`, `TODO.md`, `todo.md`).
2. If `CLAUDE.md` doesn't mention one, look for common names: `docs/todo.md`,
   `TODO.md`, `todo.md`, `docs/TODO.md`.
3. If no file is found and the command is summarise (`/todo` with no args),
   say so and offer to create `docs/TODO.md`.
4. If no file is found and the command is add (`/todo <text>`), create
   `docs/TODO.md` automatically and add the item there.

## `/todo` (no arguments) — Summarise

Read the file and present a concise summary:
- Group items by section/heading as they appear in the file.
- Show only **open** items (`- [ ]`). Skip completed (`- [x]`) and
  struck-through items.
- For each item, show the bold title and a short one-line description
  (not the full design notes).
- End with a count: "N open items across M sections."

## `/todo <text>` — Add a new item

Append the provided text as a new open TODO item (`- [ ] …`) to the
file. Choose the most appropriate existing section based on the item's
content. If no section fits well, append to the end of the file.

After adding, confirm with the item text and the section it was placed
in.
