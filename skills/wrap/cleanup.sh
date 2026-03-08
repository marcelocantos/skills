#!/bin/sh
# Clean up wrap-draft.md from the project's auto-memory directory.
set -e

MEMORY_DIR="$HOME/.claude/projects/$(echo "$PWD" | sed 's|/|-|g')/memory"
DRAFT="$MEMORY_DIR/wrap-draft.md"

if [ -f "$DRAFT" ]; then
    rm "$DRAFT"
    echo "deleted: $DRAFT"
else
    echo "no draft to clean up"
fi
