#!/usr/bin/env bash
# Save the /wrap safety-net draft to the auto-memory directory.
#
# Reads markdown from stdin and writes it to <auto-memory-dir>/wrap-draft.md,
# where <auto-memory-dir> is derived from the current working directory via
# the shared memory-path helper. The destination directory is created if it
# does not already exist.
#
# Usage:
#   ./save-draft.sh <<'EOF'
#   # Wrap draft (YYYY-MM-DD)
#   ...
#   EOF
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="$("$here/../_shared/memory-path.sh" --ensure)"
file="$dir/wrap-draft.md"

cat >"$file"
echo "wrote: $file"
