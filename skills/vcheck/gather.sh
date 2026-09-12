#!/usr/bin/env bash
# Evidence bundle for the /vcheck skill (V-boundary checker).
#
# Collects deterministic inputs only: the target record, the claim under
# audit, the references the claim cites (SHAs, test names, commands, paths),
# the commits that carry the work, the repo's oracle inventory, and the
# transcript rows that recorded the achieve call. The checker agent decides;
# this script never judges.
#
# Usage: gather.sh <target-id> [--cwd DIR] [--claim-file FILE]
#   --claim-file  attestation text for a pre-achieve check (the target is not
#                 yet achieved). Omitted: the attestation stored on the target.
#
# Dependencies: git, bullseye (CLI), curl + jq (transcript probe; degrades to
# "(unavailable)" without them).
set -euo pipefail

skill_dir=$(cd "$(dirname "$0")" && pwd)
section() { echo "# $1"; }

id=""
cwd="$PWD"
claim_file=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cwd) cwd="$2"; shift 2 ;;
        --claim-file) claim_file="$2"; shift 2 ;;
        -*) echo "error: unknown flag $1" >&2; exit 2 ;;
        *) id="$1"; shift ;;
    esac
done
if [[ -z "$id" ]]; then
    echo "usage: gather.sh <target-id> [--cwd DIR] [--claim-file FILE]" >&2
    exit 2
fi
id="${id#🎯}"
cd "$cwd"
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: $cwd is not inside a git repository" >&2
    exit 1
fi
repo_top=$(git rev-parse --show-toplevel)
repo_name=$(basename "$repo_top")

# ---------------------------------------------------------------------------
# args
# ---------------------------------------------------------------------------
section "args"
printf 'id %s\ncwd %s\nrepo_top %s\nrepo %s\n' "$id" "$cwd" "$repo_top" "$repo_name"

# ---------------------------------------------------------------------------
# target — the ledger record, verbatim
# ---------------------------------------------------------------------------
section "target"
target_text=$(bullseye query --view target --id "$id" --cwd "$cwd" 2>&1) || {
    echo "$target_text"
    echo "error: bullseye could not read target $id" >&2
    exit 1
}
echo "$target_text"

# ---------------------------------------------------------------------------
# claim — the text under audit. Pre-achieve: the supplied file. Achieved:
# the attestation block of the target record (from `attestation:` up to the
# next top-level key).
# ---------------------------------------------------------------------------
section "claim"
if [[ -n "$claim_file" ]]; then
    echo "source: --claim-file $claim_file"
    claim=$(cat "$claim_file")
else
    echo "source: target attestation"
    claim=$(echo "$target_text" | awk '
        /^attestation:/ { on=1; sub(/^attestation:[ ]*/, ""); if ($0 != "" && $0 != "|-" && $0 != "|") print; next }
        on && /^[a-z_]+:/ { on=0 }
        on { sub(/^  /, ""); print }
    ')
fi
if [[ -z "$claim" ]]; then
    echo "(none)"
else
    echo "$claim"
fi

# ---------------------------------------------------------------------------
# claim-refs — what the claim points at. Existence is checked below; a
# reference that resolves to nothing is itself evidence.
# ---------------------------------------------------------------------------
section "claim-refs"
shas=$(echo "$claim" | grep -oE '\b[0-9a-f]{7,40}\b' | grep -E '[a-f]' | sort -u || true)
tests=$(echo "$claim" | grep -oE '\bTest[A-Z][A-Za-z0-9_]+' | sort -u || true)
cmds=$(echo "$claim" | grep -oE '(go test|go vet|cargo (test|nextest|clippy)|make [A-Za-z0-9_-]+|bats\b|pytest\b|npm (test|run [A-Za-z0-9:-]+)|xcodebuild\b|swift test|hygiene_check\.py|bullseye (query|convergence)|\./[A-Za-z0-9_./-]+\.sh)[^;.]*' | sort -u || true)
paths=$(echo "$claim" | grep -oE '\b[A-Za-z0-9_][A-Za-z0-9_./-]*\.(go|rs|py|ts|js|sh|md|yaml|yml|star|c|cpp|h|swift|cs|json|log|txt)\b' | sort -u || true)
residue=$(echo "$claim" | grep -oiE '(residu[ae][a-z]*|not (run|performed|exercised|released|published|covered)|skipp?ed|stub[a-z]*|canned|only)[^.;]*' | sort -u || true)
echo "## shas"; [[ -n "$shas" ]] && echo "$shas" || echo "(none)"
echo "## tests"; [[ -n "$tests" ]] && echo "$tests" || echo "(none)"
echo "## commands"; [[ -n "$cmds" ]] && echo "$cmds" || echo "(none)"
echo "## paths"; [[ -n "$paths" ]] && echo "$paths" || echo "(none)"
echo "## residue-phrases"; [[ -n "$residue" ]] && echo "$residue" || echo "(none)"

# ---------------------------------------------------------------------------
# git-head — where the checker will run oracles
# ---------------------------------------------------------------------------
section "git-head"
printf 'head %s\nbranch %s\n' "$(git rev-parse HEAD)" "$(git branch --show-current 2>/dev/null || echo '(detached)')"
dirty=$(git status --porcelain | wc -l | tr -d ' ')
printf 'dirty-files %s\n' "$dirty"

# ---------------------------------------------------------------------------
# cited-commits — every SHA the claim names, resolved against this repo
# ---------------------------------------------------------------------------
section "cited-commits"
if [[ -z "$shas" ]]; then
    echo "(none cited)"
else
    while IFS= read -r sha; do
        [[ -n "$sha" ]] || continue
        if git cat-file -e "$sha^{commit}" 2>/dev/null; then
            git show --stat --format='%H %cd %s' --date=short "$sha" | head -60
            if git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
                echo "reachable-from-HEAD yes"
            else
                echo "reachable-from-HEAD no"
            fi
        else
            echo "$sha (not a commit in this repo)"
        fi
        echo
    done <<< "$shas"
fi

# ---------------------------------------------------------------------------
# id-commits — commits whose message names the target (fixed-string match)
# ---------------------------------------------------------------------------
section "id-commits"
id_commits=$(git log --all --fixed-strings --grep="$id" --format='%H %cd %s' --date=short 2>/dev/null | head -20 || true)
if [[ -z "$id_commits" ]]; then
    echo "(none)"
else
    echo "$id_commits"
fi

# ---------------------------------------------------------------------------
# diff-files — files touched by cited + id commits (union)
# ---------------------------------------------------------------------------
section "diff-files"
all_commits=$( { echo "$shas"; echo "$id_commits" | awk '{print $1}'; } | grep -E '^[0-9a-f]{7,40}$' | sort -u || true)
diff_files=""
if [[ -n "$all_commits" ]]; then
    while IFS= read -r c; do
        [[ -n "$c" ]] || continue
        git cat-file -e "$c^{commit}" 2>/dev/null || continue
        git show --name-only --format= "$c" 2>/dev/null || true
    done <<< "$all_commits" | sort -u > "${TMPDIR:-/tmp}/vcheck-diff-files.$$"
    diff_files=$(cat "${TMPDIR:-/tmp}/vcheck-diff-files.$$")
    rm -f "${TMPDIR:-/tmp}/vcheck-diff-files.$$"
fi
if [[ -z "$diff_files" ]]; then
    echo "(none — no commits resolved; the checker must locate the work by other means)"
else
    echo "$diff_files"
fi

# ---------------------------------------------------------------------------
# path-commits — when the claim names files (or tests whose files resolve
# below), the commits that last touched them. Finds the work when no commit
# message names the target (PR-number-only subjects are common).
# ---------------------------------------------------------------------------
section "path-commits"
path_list=$(echo "$paths" | while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    git ls-files --full-name -- "*$p" 2>/dev/null | head -3 || true
done | sort -u)
if [[ -z "$path_list" ]]; then
    echo "(no claim paths resolve in the tree)"
else
    while IFS= read -r p; do
        [[ -n "$p" ]] || continue
        echo "## $p"
        git log -3 --format='%H %cd %s' --date=short -- "$p" 2>/dev/null || true
    done <<< "$path_list"
fi

# ---------------------------------------------------------------------------
# cited-tests — does each named test exist at HEAD, and where
# ---------------------------------------------------------------------------
section "cited-tests"
if [[ -z "$tests" ]]; then
    echo "(none cited)"
else
    while IFS= read -r t; do
        [[ -n "$t" ]] || continue
        hits=$(git grep -n -E "(func|fn|def) ${t}\b|#\[test\][[:space:]]*fn ${t}\b" HEAD -- . 2>/dev/null | sed 's/^HEAD://' | head -5 || true)
        if [[ -n "$hits" ]]; then
            echo "$hits"
        else
            # Prefix match: TestFoo_* families are a common attestation shorthand.
            fam=$(git grep -n -E "func ${t%\*}[A-Za-z0-9_]*\(" HEAD -- . 2>/dev/null | sed 's/^HEAD://' | head -8 || true)
            if [[ -n "$fam" ]]; then
                echo "$fam"
            else
                echo "$t (NOT FOUND at HEAD)"
            fi
        fi
    done <<< "$tests"
fi

# ---------------------------------------------------------------------------
# oracle-inventory — what machine checks this repo offers
# ---------------------------------------------------------------------------
section "oracle-inventory"
echo "## build-systems"
for f in Makefile go.mod Cargo.toml package.json pyproject.toml Package.swift cvfile hygiene.yaml; do
    [[ -e "$repo_top/$f" ]] && echo "$f"
done
echo "## make-targets"
if [[ -f "$repo_top/Makefile" ]]; then
    grep -oE '^[A-Za-z0-9_-]+:' "$repo_top/Makefile" | tr -d ':' | sort -u | tr '\n' ' '; echo
else
    echo "(no Makefile)"
fi
echo "## ci-workflows"
ls "$repo_top/.github/workflows" 2>/dev/null || echo "(none)"
echo "## test-files-in-diff"
test_files=$(echo "$diff_files" | grep -E '(_test\.(go|rs|py)|\.bats|\.test\.(ts|js)|tests?/)' || true)
[[ -n "$test_files" ]] && echo "$test_files" || echo "(none)"
echo "## test-functions-in-diff"
if [[ -n "$test_files" ]]; then
    while IFS= read -r tf; do
        [[ -f "$repo_top/$tf" ]] || continue
        grep -hoE '(func Test[A-Za-z0-9_]+|fn [a-z0-9_]+\(\)|def test_[a-z0-9_]+|@test "[^"]+")' "$repo_top/$tf" | sed "s|^|$tf: |" || true
    done <<< "$test_files"
else
    echo "(none)"
fi

# ---------------------------------------------------------------------------
# transcript-achieve — the ledger mutation that recorded this claim, from
# mnemo. Gives the checker the session to drill into. Tries the daemon
# directly so a broken in-session MCP proxy does not blind the check.
# ---------------------------------------------------------------------------
section "transcript-achieve"
# Tool-agnostic: Claude Code records MCP calls as mcp__bullseye__*, Grok as
# use_tool/CallDynamicTool with the arguments nested; matching the JSON text
# for the id and an attestation key covers both.
sql="SELECT m.session_id, m.timestamp, m.tool_name, substr(json(m.tool_input),1,600) AS input FROM messages_v m WHERE m.content_type = 'tool_use' AND json(m.tool_input) LIKE '%attestation%' AND json(m.tool_input) LIKE '%achieve%' AND json(m.tool_input) LIKE '%$id%' AND json(m.tool_input) NOT LIKE '%SELECT %' AND m.tool_name NOT IN ('Bash','Shell','run_terminal_command','Read','Write','write','Edit','SendMessage','Task','WebFetch') AND (m.project LIKE '%$repo_name%' OR json(m.tool_input) LIKE '%$repo_name%') ORDER BY m.timestamp"
if rows=$("$skill_dir/mnemo-sql.sh" "$sql" 2>&1); then
    if [[ -z "$rows" || "$rows" == "No rows returned." ]]; then
        echo "(no MCP achieve call found in transcripts for $id in $repo_name)"
    else
        echo "$rows"
    fi
else
    echo "(unavailable: $rows)"
fi

# The CLI form (`bullseye commit --op achieve` / `bullseye apply`) leaves a
# Bash tool call instead of an MCP call.
section "transcript-achieve-cli"
sql="SELECT m.session_id, m.timestamp, m.tool_name, substr(COALESCE(NULLIF(m.tool_command,''), json_extract(m.tool_input,'\$.command')),1,400) AS command FROM messages_v m WHERE m.content_type = 'tool_use' AND m.tool_name IN ('Bash','Shell','run_terminal_command') AND COALESCE(NULLIF(m.tool_command,''), json_extract(m.tool_input,'\$.command')) LIKE '%bullseye %' AND json(m.tool_input) LIKE '%$id%' AND json(m.tool_input) NOT LIKE '%mnemo-sql.sh%' AND m.project LIKE '%$repo_name%' ORDER BY m.timestamp"
if rows=$("$skill_dir/mnemo-sql.sh" "$sql" 2>&1); then
    if [[ -z "$rows" || "$rows" == "No rows returned." ]]; then
        echo "(no CLI achieve call found in transcripts for $id in $repo_name)"
    else
        echo "$rows"
    fi
else
    echo "(unavailable: $rows)"
fi
