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

# --- Project CLAUDE.md ---
section "claude-md"
if [ -f CLAUDE.md ]; then
    cat CLAUDE.md
else
    echo "(none)"
fi

# --- Auto-memory ---
section "memory"
MEMORY_DIR="$HOME/.claude/projects/$(pwd | tr '/.' '-')/memory"
if [ -d "$MEMORY_DIR" ]; then
    for f in "$MEMORY_DIR"/*.md; do
        [ -f "$f" ] || continue
        echo "## $(basename "$f")"
        cat "$f"
        echo
    done
else
    echo "(none)"
fi

# --- Convergence targets ---
section "targets"
TARGETS_PATH=""
for candidate in docs/targets.md targets.md; do
    if [ -f "$candidate" ]; then
        TARGETS_PATH="$candidate"
        break
    fi
done

# If CLAUDE.md mentions a specific path, try that too
if [ -z "$TARGETS_PATH" ] && [ -f CLAUDE.md ]; then
    hint=$(grep -o -i -E '[A-Za-z0-9_/.-]*targets[A-Za-z0-9_/.-]*\.md' CLAUDE.md 2>/dev/null | head -1)
    if [ -n "$hint" ] && [ -f "$hint" ]; then
        TARGETS_PATH="$hint"
    fi
fi

if [ -n "$TARGETS_PATH" ]; then
    echo "path: $TARGETS_PATH"
    echo "---"
    cat "$TARGETS_PATH"
else
    echo "(not found)"
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
