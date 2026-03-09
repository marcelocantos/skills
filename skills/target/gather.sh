#!/bin/sh
# Locate and dump the project targets file for the /target skill.
# Outputs structured sections for LLM consumption.
set -e

section() { echo "# $1"; }

# --- Extract targets path hint from CLAUDE.md ---
section "claude-md-hint"
if [ -f CLAUDE.md ]; then
    grep -i -E '(targets\.md|docs/targets)' CLAUDE.md 2>/dev/null || echo "(no hint)"
else
    echo "(no CLAUDE.md)"
fi

# --- Find the targets file ---
section "targets-file"
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

# --- Delivery definition from CLAUDE.md ---
section "delivery"
if [ -f CLAUDE.md ]; then
    # Extract delivery line(s) from CLAUDE.md
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

# --- Changed files since last evaluation ---
section "changed-files"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Check for last-evaluated SHA in targets file
    LAST_SHA=""
    if [ -n "$TARGETS_PATH" ]; then
        LAST_SHA=$(grep -o 'last-evaluated: [0-9a-f]\{7,40\}' "$TARGETS_PATH" 2>/dev/null | head -1 | awk '{print $2}')
    fi

    if [ -n "$LAST_SHA" ] && git cat-file -e "$LAST_SHA" 2>/dev/null; then
        echo "since: $LAST_SHA"
        git diff --name-only "$LAST_SHA" 2>/dev/null || true
    else
        echo "since: (no baseline — showing uncommitted changes)"
        git diff --name-only 2>/dev/null || true
        git diff --name-only --cached 2>/dev/null || true
    fi
else
    echo "(not a git repo)"
fi

# --- Saved context from auto-memory ---
section "saved-context"
# Resolve project memory dir: ~/.claude/projects/-<cwd-with-dashes>/memory/
MEMORY_DIR="$HOME/.claude/projects/$(echo "${PROJECT_ROOT:-$PWD}" | sed 's|[/.]|-|g')/memory"
if [ -d "$MEMORY_DIR" ]; then
    for f in "$MEMORY_DIR"/*.md; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        echo "## $fname"
        if [ "$fname" = "stash-context.md" ]; then
            echo "(stashed session — check for target-relevant progress/blockers)"
        fi
        # Emit first 10 non-empty lines (headings + opening content)
        grep -m 10 '.' "$f" 2>/dev/null
        echo "..."
    done
else
    echo "(no auto-memory directory)"
fi
