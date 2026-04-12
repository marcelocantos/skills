#!/usr/bin/env bash
# Preflight data-gathering script for the /push skill.
# Emits structured sections the agent parses to route push logic.
# Takes no arguments — discovers everything from the working directory.
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

has_cmd() { command -v "$1" &>/dev/null; }

# Ensure we are inside a git repo.
if ! git rev-parse --git-dir &>/dev/null; then
    echo "error: not a git repository" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# working-tree
# ---------------------------------------------------------------------------
echo "# working-tree"
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo "dirty"
else
    echo "clean"
fi

# ---------------------------------------------------------------------------
# status
# ---------------------------------------------------------------------------
echo "# status"
git status --short --branch 2>/dev/null

# ---------------------------------------------------------------------------
# branch
# ---------------------------------------------------------------------------
echo "# branch"
branch=$(git branch --show-current 2>/dev/null)
if [[ -z "$branch" ]]; then
    echo "(detached)"
else
    echo "$branch"
fi

# ---------------------------------------------------------------------------
# default-branch
# ---------------------------------------------------------------------------
echo "# default-branch"
default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||') || default_branch=""
if [[ -z "$default_branch" ]]; then
    default_branch="master"
fi
echo "$default_branch"

# ---------------------------------------------------------------------------
# on-default-branch
# ---------------------------------------------------------------------------
echo "# on-default-branch"
if [[ "$branch" == "$default_branch" ]]; then
    echo "true"
else
    echo "false"
fi

# ---------------------------------------------------------------------------
# upstream
# ---------------------------------------------------------------------------
echo "# upstream"
upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || upstream=""
if [[ -z "$upstream" ]]; then
    echo "(none)"
else
    echo "$upstream"
fi

# ---------------------------------------------------------------------------
# unpushed-commits
# ---------------------------------------------------------------------------
echo "# unpushed-commits"
if [[ "$branch" == "$default_branch" ]]; then
    # On default branch: compare against remote default
    git log --oneline "origin/${default_branch}..HEAD" 2>/dev/null || true
elif [[ -n "$upstream" ]]; then
    # Feature branch with upstream: compare against upstream
    git log --oneline "${upstream}..HEAD" 2>/dev/null || true
else
    # Feature branch without upstream: compare against remote default
    git log --oneline "origin/${default_branch}..HEAD" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# existing-pr
# ---------------------------------------------------------------------------
echo "# existing-pr"
if ! has_cmd gh; then
    echo "(gh not available)"
elif [[ -z "$branch" || "$branch" == "(detached)" ]]; then
    echo "(none)"
else
    pr=$(gh pr list --head "$branch" --state open \
        --json number,url,title \
        --jq 'if length > 0 then .[0] | "\(.number)\t\(.title)\t\(.url)" else "(none)" end' \
        2>/dev/null) || pr=""
    if [[ -z "$pr" ]]; then
        echo "(none)"
    else
        echo "$pr"
    fi
fi
