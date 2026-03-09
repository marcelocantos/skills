#!/bin/sh
# Clean up wrap-draft.md from the given auto-memory directory.
# Pass the directory path as $1.
set -e

DIR="${1:?usage: cleanup.sh /path/to/auto-memory/directory}"
DRAFT="$DIR/wrap-draft.md"

if [ -f "$DRAFT" ]; then
    rm "$DRAFT"
    echo "deleted: $DRAFT"
else
    echo "no draft to clean up"
fi
