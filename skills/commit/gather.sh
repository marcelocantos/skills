#!/usr/bin/env bash
# Data gathering script for the /commit skill.
# Emits labelled sections covering working-tree state, diffs, untracked
# file contents, and secret-candidate filenames.
#
# Usage: gather.sh [path ...]
#   No arguments — gather state for the entire working tree.
#   With arguments — scope diffs, untracked listing, and secret scanning
#   to only the given paths. Status and log are always full-tree.
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

section() { echo "# $1"; }

# Return 0 if a file is likely text (not binary), 1 otherwise.
is_text_file() {
    local f="$1"
    local enc
    enc=$(file -b --mime-encoding "$f" 2>/dev/null) || return 1
    [[ "$enc" != "binary" ]]
}

# ---------------------------------------------------------------------------
# Path arguments (empty = full tree)
# ---------------------------------------------------------------------------
paths=("$@")

# ---------------------------------------------------------------------------
# Guard: must be inside a git repo
# ---------------------------------------------------------------------------
if ! git rev-parse --git-dir &>/dev/null; then
    echo "error: not a git repository" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 0. Scope
# ---------------------------------------------------------------------------
section "scope"
if [[ ${#paths[@]} -eq 0 ]]; then
    echo "full-tree"
else
    printf '%s\n' "${paths[@]}"
fi

# ---------------------------------------------------------------------------
# 1. Status
# ---------------------------------------------------------------------------
section "status"
git status --short --branch

# ---------------------------------------------------------------------------
# 2. Log (recent history for message-style reference)
# ---------------------------------------------------------------------------
section "log"
git log --oneline -5 2>/dev/null || echo "(no commits yet)"

# ---------------------------------------------------------------------------
# 3. Staged diff stat
# ---------------------------------------------------------------------------
section "staged-stat"
staged_stat=$(git diff --cached --stat -- "${paths[@]}" 2>/dev/null)
if [[ -n "$staged_stat" ]]; then
    echo "$staged_stat"
else
    echo "(none)"
fi

# ---------------------------------------------------------------------------
# 4. Unstaged diff stat
# ---------------------------------------------------------------------------
section "unstaged-stat"
unstaged_stat=$(git diff --stat -- "${paths[@]}" 2>/dev/null)
if [[ -n "$unstaged_stat" ]]; then
    echo "$unstaged_stat"
else
    echo "(none)"
fi

# ---------------------------------------------------------------------------
# 5. Staged diff (full)
# ---------------------------------------------------------------------------
section "staged-diff"
staged_diff=$(git diff --cached -- "${paths[@]}" 2>/dev/null)
if [[ -n "$staged_diff" ]]; then
    echo "$staged_diff"
else
    echo "(none)"
fi

# ---------------------------------------------------------------------------
# 6. Unstaged diff (full)
# ---------------------------------------------------------------------------
section "unstaged-diff"
unstaged_diff=$(git diff -- "${paths[@]}" 2>/dev/null)
if [[ -n "$unstaged_diff" ]]; then
    echo "$unstaged_diff"
else
    echo "(none)"
fi

# ---------------------------------------------------------------------------
# 7. Untracked files (first 100 lines of each text file)
# ---------------------------------------------------------------------------
section "untracked"
if [[ ${#paths[@]} -eq 0 ]]; then
    mapfile -t untracked_files < <(git ls-files --others --exclude-standard 2>/dev/null)
else
    # Filter untracked files to only those under the given paths.
    mapfile -t untracked_files < <(git ls-files --others --exclude-standard -- "${paths[@]}" 2>/dev/null)
fi
if [[ ${#untracked_files[@]} -eq 0 ]]; then
    echo "(none)"
else
    for f in "${untracked_files[@]}"; do
        [[ -f "$f" ]] || continue
        if is_text_file "$f"; then
            echo "FILE: $f"
            head -100 "$f" 2>/dev/null || true
            echo
        else
            echo "FILE: $f (binary, skipped)"
            echo
        fi
    done
fi

# ---------------------------------------------------------------------------
# 8. Secret candidates (filename-based, case-insensitive)
#    Matches only the basename so pkg/token/file.go doesn't trigger.
# ---------------------------------------------------------------------------
section "secret-candidates"

# Collect tracked-with-changes files (staged + unstaged), scoped to paths
mapfile -t changed_files < <(
    { git diff --name-only -- "${paths[@]}"; git diff --cached --name-only -- "${paths[@]}"; } 2>/dev/null | sort -u
)

# Combine with untracked
all_files=("${changed_files[@]}" "${untracked_files[@]}")

secret_pattern='^(\.env(\..+)?)$|credential|secret|_key$|token'
found_secrets=false
for f in "${all_files[@]}"; do
    bn=$(basename "$f")
    bn_lower="${bn,,}"
    # Match .env / .env.* exactly, or filename contains credential/secret/token, or ends in _key
    if [[ "$bn_lower" =~ ^\.env(\..*)?$ ]] \
    || [[ "$bn_lower" =~ credential ]] \
    || [[ "$bn_lower" =~ secret ]] \
    || [[ "$bn_lower" =~ _key$ ]] \
    || [[ "$bn_lower" =~ token ]] \
    || [[ "$bn_lower" =~ \.pem$ ]] \
    || [[ "$bn_lower" =~ \.key$ ]]; then
        echo "$f"
        found_secrets=true
    fi
done
if [[ "$found_secrets" == false ]]; then
    echo "(none)"
fi

# ---------------------------------------------------------------------------
# 9. Nothing-to-commit flag
# ---------------------------------------------------------------------------
section "nothing-to-commit"
# True only when: no staged changes, no unstaged changes, no untracked files.
if [[ -z "$staged_stat" && -z "$unstaged_stat" && ${#untracked_files[@]} -eq 0 ]]; then
    echo "true"
else
    echo "false"
fi
