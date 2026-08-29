#!/usr/bin/env bash
# Print the Grok session directory for the current working directory
# (legacy Claude Code path kept as fallback when Grok sessions are absent).
#
# Grok encodes cwd as a percent-encoded path under $HOME/.grok/sessions/.
# Claude Code used $HOME/.claude/projects/ with '/' and '.' replaced by '-'.
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

# Prefer Grok session root for this cwd (URL-encoded absolute path).
# python3 is always available on this machine; fall back to Claude layout.
if command -v python3 >/dev/null 2>&1; then
    encoded=$(python3 -c 'import os, urllib.parse; print(urllib.parse.quote(os.getcwd(), safe=""))')
    grok_dir="$HOME/.grok/sessions/$encoded"
else
    grok_dir=""
fi
claude_dir="$HOME/.claude/projects/$(pwd | tr '/.' '-')/memory"

if [[ -n "$grok_dir" && ( -d "$grok_dir" || (( ensure )) ) ]]; then
    dir="$grok_dir"
elif [[ -d "$claude_dir" ]]; then
    dir="$claude_dir"
elif [[ -n "$grok_dir" ]]; then
    dir="$grok_dir"
else
    dir="$claude_dir"
fi

if (( ensure )); then
    mkdir -p "$dir"
fi

echo "$dir"
