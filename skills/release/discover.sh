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
git tag --sort=-v:refname 2>/dev/null || echo "(no tags)"

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
# 4. Description (requires gh)
# ---------------------------------------------------------------------------
echo "# description"
if has_cmd gh; then
    gh repo view --json description -q '.description' 2>/dev/null || echo "(unavailable)"
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
# Go: cmd/ or main package
if [[ -d cmd ]] || [[ -f main.go ]]; then
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
echo "# homebrew_tap"
if has_cmd gh; then
    gh api repos/marcelocantos/homebrew-tap/contents/Formula --jq '.[].name' 2>/dev/null || echo "(no tap or no Formula/ directory)"
else
    echo "(gh not installed)"
fi

# ---------------------------------------------------------------------------
# 10. Description check
# ---------------------------------------------------------------------------
echo "# description_check"
if has_cmd gh; then
    desc=$(gh repo view --json description -q '.description' 2>/dev/null) || desc=""
    if [[ -z "$desc" || "$desc" == "null" ]]; then
        echo "null"
    else
        echo "set"
    fi
else
    echo "(gh not installed)"
fi

# ---------------------------------------------------------------------------
# 11. Version macros
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
for f in agents-guide.md AGENTS-GUIDE.md dist/agents-guide.md; do
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
echo "# unpushed"
tracking=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || true
if [[ -n "$tracking" ]]; then
    count=$(git rev-list --count "$tracking..HEAD" 2>/dev/null) || count=0
    echo "$count"
else
    echo "(no upstream tracking branch)"
fi
