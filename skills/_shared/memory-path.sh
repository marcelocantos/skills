#!/usr/bin/env bash
# Print the Claude Code auto-memory directory for the current working directory.
#
# The harness encodes the cwd into a directory name under
# $HOME/.claude/projects/ by replacing '/' and '.' with '-'. This script
# mirrors that derivation so skills don't have to duplicate the fragile
# substitution in agent prose.
#
# Usage:
#   memory-path.sh            # print the directory (may not exist)
#   memory-path.sh --ensure   # create the directory if missing, then print
set -euo pipefail

ensure=0
case "${1:-}" in
    "") ;;
    --ensure) ensure=1 ;;
    *)
        echo "usage: $(basename "$0") [--ensure]" >&2
        exit 2
        ;;
esac

dir="$HOME/.claude/projects/$(pwd | tr '/.' '-')/memory"

if (( ensure )); then
    mkdir -p "$dir"
fi

echo "$dir"
