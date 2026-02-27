#!/bin/sh
# Locate and dump the project TODO file for the /todo skill.
# Outputs structured sections for LLM consumption.
set -e

section() { echo "# $1"; }

# --- Extract TODO path hint from CLAUDE.md ---
section "claude-md-hint"
if [ -f CLAUDE.md ]; then
    # Look for lines mentioning a todo file path
    grep -i -E '(todo\.md|TODO\.md|docs/todo)' CLAUDE.md 2>/dev/null || echo "(no hint)"
else
    echo "(no CLAUDE.md)"
fi

# --- Find the TODO file ---
section "todo-file"
TODO_PATH=""
for candidate in docs/todo.md TODO.md todo.md docs/TODO.md; do
    if [ -f "$candidate" ]; then
        TODO_PATH="$candidate"
        break
    fi
done

# If CLAUDE.md mentions a specific path, try that too
if [ -z "$TODO_PATH" ] && [ -f CLAUDE.md ]; then
    hint=$(grep -o -i -E '[A-Za-z0-9_/.-]*todo[A-Za-z0-9_/.-]*\.md' CLAUDE.md 2>/dev/null | head -1)
    if [ -n "$hint" ] && [ -f "$hint" ]; then
        TODO_PATH="$hint"
    fi
fi

if [ -n "$TODO_PATH" ]; then
    echo "path: $TODO_PATH"
    echo "---"
    cat "$TODO_PATH"
else
    echo "(not found)"
fi
