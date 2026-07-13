#!/bin/sh
# Comprehensive data gathering for /waw skill.
# Single script to minimise tool calls and permission prompts.
set -e

section() { echo "# $1"; }

# --- Git basics ---
section "repo"
git remote get-url origin 2>/dev/null | sed 's|.*/||;s|\.git$||' || basename "$(pwd)"

section "branch"
git branch --show-current 2>/dev/null || echo "(detached)"

section "status"
git status --short --branch

section "log"
git log --oneline -10

section "stash"
git stash list 2>/dev/null || true

# --- Working tree detail ---
section "diff-stat"
git diff --stat 2>/dev/null || true

section "diff-cached-stat"
git diff --cached --stat 2>/dev/null || true

# --- Project agent instructions ---
section "agent-docs"
any_doc=0
for f in AGENTS.md CLAUDE.md Claude.md; do
    if [ -f "$f" ]; then
        any_doc=1
        echo "## $f"
        cat "$f"
        echo
    fi
done
if [ "$any_doc" -eq 0 ]; then
    echo "(none)"
fi

# --- Session notes / memory ---
section "memory"
# Prefer Grok session dir; fall back to Claude Code auto-memory layout.
if command -v python3 >/dev/null 2>&1; then
    encoded=$(python3 -c 'import os, urllib.parse; print(urllib.parse.quote(os.getcwd(), safe=""))')
    GROK_DIR="$HOME/.grok/sessions/$encoded"
else
    GROK_DIR=""
fi
CLAUDE_MEM="$HOME/.claude/projects/$(pwd | tr '/.' '-')/memory"
MEMORY_DIR=""
if [ -n "$GROK_DIR" ] && [ -d "$GROK_DIR" ]; then
    MEMORY_DIR="$GROK_DIR"
elif [ -d "$CLAUDE_MEM" ]; then
    MEMORY_DIR="$CLAUDE_MEM"
fi
if [ -n "$MEMORY_DIR" ] && [ -d "$MEMORY_DIR" ]; then
    for f in "$MEMORY_DIR"/*.md; do
        [ -f "$f" ] || continue
        echo "## $(basename "$f")"
        cat "$f"
        echo
    done
else
    echo "(none)"
fi

# --- GSD/planning state ---
section "planning"
if [ -d .planning ]; then
    for f in .planning/PROJECT.md .planning/ROADMAP.md .planning/STATE.md; do
        if [ -f "$f" ]; then
            echo "## $f"
            cat "$f"
            echo
        fi
    done
else
    echo "(none)"
fi
