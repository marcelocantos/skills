#!/usr/bin/env bash
# Phase 1 Discovery script for the /release skill.
# Gathers all discovery information from the current repo in one invocation.
# Takes no arguments — discovers everything from the working directory.
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

has_cmd() { command -v "$1" &>/dev/null; }

# Try to get repo owner/name from git remote, fall back to directory name.
repo_name() {
    local url
    url=$(git remote get-url origin 2>/dev/null) || { basename "$(pwd)"; return; }
    # Strip .git suffix, then extract owner/repo from any URL format.
    url="${url%.git}"
    if [[ "$url" == *github.com* ]]; then
        echo "$url" | sed -E 's|.*github\.com[:/]||'
    else
        basename "$url"
    fi
}

# Detect licence type from a licence file by scanning first ~30 lines.
detect_licence() {
    local f="$1"
    [[ -f "$f" ]] || { echo "unknown"; return; }
    local head
    head=$(head -40 "$f" 2>/dev/null) || { echo "unknown"; return; }
    if echo "$head" | grep -qi "Apache License.*2\.0\|Apache-2\.0"; then
        echo "Apache-2.0"
    elif echo "$head" | grep -qi "Boost Software License\|BSL-1\.0"; then
        echo "BSL-1.0"
    elif echo "$head" | grep -qi "MIT License\|Permission is hereby granted.*MIT"; then
        echo "MIT"
    elif echo "$head" | grep -qi "BSD 3-Clause\|Redistribution and use.*three conditions\|3-Clause"; then
        echo "BSD-3-Clause"
    elif echo "$head" | grep -qi "BSD 2-Clause\|Simplified BSD\|2-Clause"; then
        echo "BSD-2-Clause"
    elif echo "$head" | grep -qi "ISC License\|ISC"; then
        echo "ISC"
    elif echo "$head" | grep -qi "GNU General Public License\|GPL"; then
        if echo "$head" | grep -qi "Version 3\|GPLv3\|GPL-3"; then
            echo "GPL-3.0"
        elif echo "$head" | grep -qi "Version 2\|GPLv2\|GPL-2"; then
            echo "GPL-2.0"
        else
            echo "GPL"
        fi
    elif echo "$head" | grep -qi "GNU Lesser General Public\|LGPL"; then
        echo "LGPL"
    elif echo "$head" | grep -qi "Mozilla Public License\|MPL"; then
        echo "MPL-2.0"
    elif echo "$head" | grep -qi "Unlicense\|unlicense"; then
        echo "Unlicense"
    elif echo "$head" | grep -qi "Creative Commons\|CC0\|CC-BY"; then
        echo "CC"
    elif echo "$head" | grep -qi "Public Domain\|public domain"; then
        echo "Public-Domain"
    elif echo "$head" | grep -qi "zlib\|zlib/libpng"; then
        echo "Zlib"
    else
        echo "unknown"
    fi
}

# ---------------------------------------------------------------------------
# 1. Repo
# ---------------------------------------------------------------------------
echo "# repo"
repo_name

# ---------------------------------------------------------------------------
# 2. Tags
# ---------------------------------------------------------------------------
echo "# tags"
all_tags=$(git tag --sort=-v:refname 2>/dev/null || true)
if [[ -n "$all_tags" ]]; then
    echo "$all_tags"
else
    echo "(no tags)"
fi

# ---------------------------------------------------------------------------
# 2a. Latest semver tag
# ---------------------------------------------------------------------------
echo "# latest_tag"
latest_tag=$(echo "$all_tags" | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
if [[ -n "$latest_tag" ]]; then
    echo "$latest_tag"
else
    echo "(none)"
fi

# ---------------------------------------------------------------------------
# 2b. Commits since last tag (or all commits if no tags)
# ---------------------------------------------------------------------------
echo "# commits_since_last_tag"
if [[ -n "$latest_tag" ]]; then
    git log --oneline "$latest_tag..HEAD" 2>/dev/null || echo "(git log failed)"
else
    git log --oneline 2>/dev/null | head -50 || echo "(no commits)"
fi

# ---------------------------------------------------------------------------
# 2c. Version era (pre-1.0 vs post-1.0) — routes Phase 1.5 vs 1.6
# ---------------------------------------------------------------------------
echo "# version_era"
if [[ -z "$latest_tag" ]]; then
    echo "pre-1.0"
else
    major=$(echo "${latest_tag#v}" | cut -d. -f1)
    if [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 1 )); then
        echo "post-1.0"
    else
        echo "pre-1.0"
    fi
fi

# ---------------------------------------------------------------------------
# 2d. STABILITY.md (complement to version_era)
# ---------------------------------------------------------------------------
echo "# stability_md"
if [[ -f STABILITY.md ]]; then
    echo "exists"
else
    echo "missing"
fi

# ---------------------------------------------------------------------------
# 3. Releases (requires gh)
# ---------------------------------------------------------------------------
echo "# releases"
if has_cmd gh; then
    gh release list --limit 20 2>/dev/null || echo "(no releases or gh auth issue)"
else
    echo "(gh not installed)"
fi

# ---------------------------------------------------------------------------
# 3a. Default-branch CI status (requires gh)
# ---------------------------------------------------------------------------
# A red default-branch run means the next merge will inherit the same
# failures unless the release-prep PR happens to fix them. Surface this
# early so the skill can decide whether to pause and triage. The PR
# created later in Phase 5 will hit the same gates the default-branch
# run is hitting now, so a red signal here is a near-certain
# pre-release block.
#
# We probe only the *latest completed* run on the default branch (push
# event), not in-progress runs — an in-progress run tells us nothing
# until it finishes. The conclusion field is one of: success, failure,
# cancelled, skipped, action_required, neutral, timed_out.
echo "# default_branch_ci_status"
if has_cmd gh; then
    default_branch=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null) || default_branch=""
    if [[ -z "$default_branch" ]]; then
        echo "(unknown — gh repo view failed)"
    else
        # Take the latest completed push run on the default branch.
        ci_line=$(gh run list \
                    --branch "$default_branch" \
                    --event push \
                    --status completed \
                    --limit 1 \
                    --json databaseId,conclusion,workflowName,createdAt,url \
                    --jq '.[0] | "\(.conclusion)\t\(.workflowName)\t\(.databaseId)\t\(.url)"' \
                  2>/dev/null) || ci_line=""
        if [[ -z "$ci_line" ]]; then
            echo "(no completed CI runs on $default_branch)"
        else
            echo "$ci_line"
        fi
    fi
else
    echo "(gh not installed)"
fi

# ---------------------------------------------------------------------------
# 4. Description (requires gh) — reports "null" if unset, else the description
# ---------------------------------------------------------------------------
echo "# description"
if has_cmd gh; then
    desc=$(gh repo view --json description -q '.description' 2>/dev/null) || desc=""
    if [[ -z "$desc" || "$desc" == "null" ]]; then
        echo "null"
    else
        echo "$desc"
    fi
else
    echo "(gh not installed)"
fi

# ---------------------------------------------------------------------------
# 5. Build system
# ---------------------------------------------------------------------------
echo "# build_system"
for f in Makefile makefile GNUmakefile mkfile CMakeLists.txt Cargo.toml go.mod meson.build build.gradle build.gradle.kts pom.xml package.json pyproject.toml setup.py SConstruct Justfile Taskfile.yml; do
    [[ -f "$f" ]] && echo "$f"
done

# ---------------------------------------------------------------------------
# 6. Dist target
# ---------------------------------------------------------------------------
echo "# dist_target"
found_dist=false
if [[ -f mkfile ]]; then
    if grep -qE '^dist[[:space:]]*:' mkfile 2>/dev/null; then
        echo "mkfile: dist target found"
        found_dist=true
    fi
fi
if [[ -f Makefile ]]; then
    if grep -qE '^dist[[:space:]]*:' Makefile 2>/dev/null; then
        echo "Makefile: dist target found"
        found_dist=true
    fi
fi
if [[ -f GNUmakefile ]]; then
    if grep -qE '^dist[[:space:]]*:' GNUmakefile 2>/dev/null; then
        echo "GNUmakefile: dist target found"
        found_dist=true
    fi
fi
if [[ "$found_dist" == false ]]; then
    echo "(no dist target found)"
fi

# ---------------------------------------------------------------------------
# 7. Project type heuristic
# ---------------------------------------------------------------------------
echo "# project_type"
is_binary=false
# Go: a project is a library if the module root directory contains any
# .go file declaring a non-main package — that non-main root package is
# the importable surface consumers depend on. The presence of cmd/
# alongside such a root package just means the repo also ships
# diagnostic tools, examples, or ancillary binaries (e.g. claudia's
# cmd/probe-ready), not that the project's primary product is a
# binary. Only classify as binary if there is NO non-main root
# package AND a main package exists (at the root or under cmd/).
if [[ -f go.mod ]]; then
    root_has_library=false
    shopt -s nullglob
    for f in *.go; do
        [[ "$f" == *_test.go ]] && continue
        pkg=$(grep -E '^package[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$f" 2>/dev/null | head -1 | awk '{print $2}')
        if [[ -n "$pkg" && "$pkg" != "main" ]]; then
            root_has_library=true
            break
        fi
    done
    shopt -u nullglob
    if [[ "$root_has_library" == false ]] && { [[ -d cmd ]] || [[ -f main.go ]]; }; then
        is_binary=true
    fi
elif [[ -d cmd ]] || [[ -f main.go ]]; then
    # Non-Go project with cmd/ or main.go — probably a binary.
    is_binary=true
fi
# Rust: check for [[bin]] in Cargo.toml or src/main.rs
if [[ -f Cargo.toml ]]; then
    if grep -qE '^\[\[bin\]\]' Cargo.toml 2>/dev/null || [[ -f src/main.rs ]]; then
        is_binary=true
    fi
fi
# C/C++: check Makefile for binary targets (heuristic: look for -o <name> or BIN)
if [[ -f Makefile ]]; then
    if grep -qE '^\s*BIN\s*[:?]?=' Makefile 2>/dev/null || grep -qE '^\s*TARGET\s*[:?]?=\s*\S' Makefile 2>/dev/null; then
        is_binary=true
    fi
fi
# Python: check for entry_points/scripts in pyproject.toml
if [[ -f pyproject.toml ]]; then
    if grep -qE '\[project\.scripts\]|\[tool\.poetry\.scripts\]' pyproject.toml 2>/dev/null; then
        is_binary=true
    fi
fi
# CMake: any add_executable(...) call means the project ships at least
# one binary. This is a loose signal — a CMakeLists.txt that only has
# test executables would also match — but for the common case where
# `add_executable(<project>)` produces the release binary, it's
# correct. Projects that are genuinely library-only will not declare
# add_executable in their top-level CMakeLists.txt.
if [[ -f CMakeLists.txt ]]; then
    if grep -qE '^[[:space:]]*add_executable[[:space:]]*\(' CMakeLists.txt 2>/dev/null; then
        is_binary=true
    fi
fi
if [[ "$is_binary" == true ]]; then
    echo "binary"
else
    echo "library"
fi

# ---------------------------------------------------------------------------
# 8. Workflows
# ---------------------------------------------------------------------------
echo "# workflows"
if compgen -G ".github/workflows/*.yml" >/dev/null 2>&1 || compgen -G ".github/workflows/*.yaml" >/dev/null 2>&1; then
    ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null || true
else
    echo "(none)"
fi

# ---------------------------------------------------------------------------
# 9. Homebrew tap (requires gh)
# ---------------------------------------------------------------------------
# Some projects deliberately opt out of the tap — e.g., a package
# manager that replaces Homebrew can't coherently ship via a tap.
# The opt-out signal lives in the project's CLAUDE.md as a
# `homebrew_tap: disabled` directive (mirroring existing directives
# like `delivery:` and `profile:`). When set, both tap sections
# below emit sentinel values and the skill knows to skip tap-related
# phases instead of flagging missing secrets and an absent formula.
homebrew_tap_disabled=false
if [[ -f CLAUDE.md ]] && grep -qE '^[[:space:]]*homebrew_tap:[[:space:]]*disabled[[:space:]]*$' CLAUDE.md 2>/dev/null; then
    homebrew_tap_disabled=true
fi

echo "# homebrew_tap"
if [[ "$homebrew_tap_disabled" == true ]]; then
    echo "(disabled — CLAUDE.md declares homebrew_tap: disabled)"
elif has_cmd gh; then
    gh api repos/marcelocantos/homebrew-tap/contents/Formula --jq '.[].name' 2>/dev/null || echo "(no tap or no Formula/ directory)"
else
    echo "(gh not installed)"
fi

# ---------------------------------------------------------------------------
# 9b. Homebrew tap token secret (needed by homebrew-releaser)
# ---------------------------------------------------------------------------
# homebrew-releaser reads HOMEBREW_TAP_TOKEN from the repo's action
# secrets to authenticate its push to marcelocantos/homebrew-tap. A
# new repo won't have it set, and the error when it's missing is
# opaque ("You must provide all necessary environment variables").
# Catching it in Phase 1 saves a failed release-workflow run after
# the tag has already been created and the homebrew-releaser job
# has to be re-run by hand.
#
# Tap-disabled projects don't need this secret at all; skip the
# lookup so the skill doesn't raise a false alarm.
echo "# homebrew_tap_token_secret"
if [[ "$homebrew_tap_disabled" == true ]]; then
    echo "(n/a — tap disabled)"
elif has_cmd gh; then
    if gh secret list 2>/dev/null | awk '{print $1}' | grep -qx 'HOMEBREW_TAP_TOKEN'; then
        echo "set"
    else
        echo "missing"
    fi
else
    echo "(gh not installed)"
fi

# ---------------------------------------------------------------------------
# 10. Version macros
# ---------------------------------------------------------------------------
echo "# version_macros"
# Search for VERSION defines/constants in source files, excluding vendor/
grep -rn --include='*.h' --include='*.hpp' --include='*.cc' --include='*.cpp' \
    --include='*.c' --include='*.go' --include='*.rs' --include='*.py' \
    --include='*.toml' --include='*.json' \
    -E '(#define\s+\w*VERSION|version\s*=\s*"|const.*[Vv]ersion\s*=)' \
    --exclude-dir=vendor --exclude-dir=third_party --exclude-dir=extern \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=build \
    . 2>/dev/null || echo "(none found)"

# ---------------------------------------------------------------------------
# 12. Vendor dependencies + licence detection
# ---------------------------------------------------------------------------
echo "# vendor_deps"
found_vendor=false
for vdir in vendor third_party extern; do
    [[ -d "$vdir" ]] || continue
    found_vendor=true

    # Submodule-style directories (e.g., vendor/github.com/org/repo)
    if [[ -d "$vdir/github.com" ]] || [[ -d "$vdir/bitbucket.com" ]] || [[ -d "$vdir/gitlab.com" ]]; then
        for host_dir in "$vdir"/github.com "$vdir"/bitbucket.com "$vdir"/gitlab.com; do
            [[ -d "$host_dir" ]] || continue
            for org_dir in "$host_dir"/*/; do
                [[ -d "$org_dir" ]] || continue
                for repo_dir in "$org_dir"*/; do
                    [[ -d "$repo_dir" ]] || continue
                    dep_name="${repo_dir#$vdir/}"
                    dep_name="${dep_name%/}"
                    licence="none"
                    for lf in "$repo_dir"LICENSE* "$repo_dir"LICENCE* "$repo_dir"COPYING* "$repo_dir"license* "$repo_dir"licence*; do
                        if [[ -f "$lf" ]]; then
                            licence=$(detect_licence "$lf")
                            break
                        fi
                    done
                    echo "$dep_name: $licence"
                done
            done
        done
    fi

    # Header-only libs in vendor/include
    if [[ -d "$vdir/include" ]]; then
        for item in "$vdir/include"/*/; do
            [[ -d "$item" ]] || continue
            dep_name="include/$(basename "$item")"
            licence="none"
            for lf in "$item"LICENSE* "$item"LICENCE* "$item"COPYING* "$item"license*; do
                if [[ -f "$lf" ]]; then
                    licence=$(detect_licence "$lf")
                    break
                fi
            done
            echo "$dep_name: $licence"
        done
        # Standalone headers
        for item in "$vdir/include"/*.h "$vdir/include"/*.hpp; do
            [[ -f "$item" ]] || continue
            dep_name="include/$(basename "$item")"
            # Try to detect licence from header comment
            licence=$(head -30 "$item" 2>/dev/null | grep -qi "MIT\|BSD\|Apache\|Boost\|BSL\|ISC\|Public.Domain\|Zlib" && detect_licence "$item" || echo "check-header")
            echo "$dep_name: $licence"
        done
    fi

    # Standalone source files in vendor/src
    if [[ -d "$vdir/src" ]]; then
        for item in "$vdir/src"/*.c "$vdir/src"/*.cc "$vdir/src"/*.cpp; do
            [[ -f "$item" ]] || continue
            echo "src/$(basename "$item"): check-header"
        done
    fi
done
if [[ "$found_vendor" == false ]]; then
    echo "(no vendor directory)"
fi

# ---------------------------------------------------------------------------
# 13. Notices file
# ---------------------------------------------------------------------------
echo "# notices_file"
found_notices=false
for f in NOTICES NOTICES.md NOTICE NOTICE.md THIRD_PARTY THIRD_PARTY.md THIRD-PARTY-NOTICES THIRD-PARTY-NOTICES.md ATTRIBUTION ATTRIBUTION.md; do
    if [[ -f "$f" ]]; then
        echo "exists: $f"
        found_notices=true
        break
    fi
done
if [[ "$found_notices" == false ]]; then
    echo "missing"
fi

# ---------------------------------------------------------------------------
# 14. Agent guide
# ---------------------------------------------------------------------------
echo "# agent_guide"
found_agent_guide=false
for f in agents-guide.md AGENTS-GUIDE.md docs/agents-guide.md docs/AGENTS-GUIDE.md dist/agents-guide.md; do
    if [[ -f "$f" ]]; then
        echo "exists: $f"
        found_agent_guide=true
        break
    fi
done
if [[ "$found_agent_guide" == false ]]; then
    echo "missing"
fi

# Check if README mentions agent guide
echo "# agent_guide_in_readme"
if [[ -f README.md ]] && grep -qi 'agents-guide\|agent.guide' README.md 2>/dev/null; then
    echo "mentioned"
else
    echo "not mentioned"
fi

# ---------------------------------------------------------------------------
# 15. README
# ---------------------------------------------------------------------------
echo "# readme"
if [[ -f README.md ]]; then
    echo "exists: README.md"
elif [[ -f README ]]; then
    echo "exists: README"
elif [[ -f readme.md ]]; then
    echo "exists: readme.md"
else
    echo "missing"
fi

# ---------------------------------------------------------------------------
# 16. Language bindings / wrappers
# ---------------------------------------------------------------------------
echo "# bindings"
found_bindings=false
for d in go python py wasm ffi bindings csharp java ruby swift kotlin; do
    if [[ -d "$d" ]]; then
        echo "$d/"
        found_bindings=true
    fi
done
if [[ "$found_bindings" == false ]]; then
    echo "(none)"
fi

# ---------------------------------------------------------------------------
# 17. Working tree
# ---------------------------------------------------------------------------
echo "# working_tree"
git status --short --branch 2>/dev/null || echo "(not a git repo)"

# ---------------------------------------------------------------------------
# 18. Unpushed commits
# ---------------------------------------------------------------------------
# Emit both the count and the one-line log so the skill can reason about
# whether the unpushed commits represent meaningful atomic history (which
# would be destroyed by a squash-merge of the release PR) vs. WIP scratch
# (which should be committed or discarded before proceeding). The skill's
# Phase 1 handling compares the count against a threshold and, if
# exceeded, presents the master-fast-forward vs. PR-squash choice
# explicitly.
echo "# unpushed"
tracking=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || true
if [[ -n "$tracking" ]]; then
    count=$(git rev-list --count "$tracking..HEAD" 2>/dev/null) || count=0
    echo "$count"
else
    echo "(no upstream tracking branch)"
fi

echo "# unpushed_log"
if [[ -n "$tracking" ]]; then
    git log --oneline "$tracking..HEAD" 2>/dev/null | head -20 || echo "(git log failed)"
else
    echo "(no upstream tracking branch)"
fi
