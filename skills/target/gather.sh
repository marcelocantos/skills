#!/bin/sh
# DEPRECATED: Target data is now accessed via bullseye MCP tools
# (bullseye_list, bullseye_frontier, etc.). This script is kept as a
# placeholder to avoid breaking callers that source it.
set -e

section() { echo "# $1"; }

section "targets-file"
echo "(deprecated — use bullseye MCP tools)"

# --- Delivery definition from CLAUDE.md ---
section "delivery"
if [ -f CLAUDE.md ]; then
    grep -i -E '^-?\s*delivery:' CLAUDE.md 2>/dev/null || echo "(no delivery definition — default: merged to default branch)"
else
    echo "(no CLAUDE.md — default: merged to default branch)"
fi

# --- Git state for implied target evaluation ---
section "git-state"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "## branch"
    git branch --show-current 2>/dev/null || echo "(detached)"

    echo "## open-prs"
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && gh repo view >/dev/null 2>&1; then
        gh pr list --state open --limit 20 2>/dev/null || echo "(gh pr list failed)"
    else
        echo "(gh not available)"
    fi

    echo "## recent-merges"
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "master")
    git log --oneline -5 "$default_branch" 2>/dev/null || true
else
    echo "(not a git repo)"
fi
