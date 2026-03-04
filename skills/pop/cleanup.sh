#!/usr/bin/env bash
# Called by /pop skill after restoring context.
# Removes the stash-context.md snapshot from the auto-memory directory.
#
# Usage: cleanup.sh <auto-memory-dir>

set -euo pipefail

dir="${1:?Usage: cleanup.sh <auto-memory-dir>}"
file="$dir/stash-context.md"

if [[ -f "$file" ]]; then
    rm "$file"
else
    echo "Nothing to clean up — $file does not exist." >&2
fi
