#!/usr/bin/env bash
# Save a stash snapshot to the auto-memory directory.
#
# Reads markdown from stdin and writes it to <auto-memory-dir>/stash-context.md,
# where <auto-memory-dir> is derived from the current working directory via
# the shared memory-path helper. The destination directory is created if it
# does not already exist.
#
# Usage:
#   ./save.sh <<'EOF'
#   # Saved Context
#   ...
#   EOF
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="$("$here/../_shared/memory-path.sh" --ensure)"
file="$dir/stash-context.md"

cat >"$file"
echo "wrote: $file"
