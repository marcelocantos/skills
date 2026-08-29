#!/bin/sh
# Gather git state and delivery definition for the /target skill's
# implied-target evaluation. Targets themselves come from the bullseye
# MCP server (bullseye_list, bullseye_frontier, etc.); this script
# gathers the surrounding context the skill needs.
set -e

section() { echo "# $1"; }

# --- Delivery definition from AGENTS.md / CLAUDE.md ---
section "delivery"
found_delivery=""
for f in AGENTS.md CLAUDE.md Claude.md; do
    if [ -f "$f" ]; then
        found_delivery=$(grep -i -E '^-?\s*delivery:' "$f" 2>/dev/null || true)
        if [ -n "$found_delivery" ]; then
            echo "$found_delivery"
            break
        fi
    fi
done
if [ -z "$found_delivery" ]; then
    echo "(no delivery definition — default: merged to default branch)"
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
