#!/usr/bin/env bash
#
# gather.sh — Collect codebase metrics and state for /audit.
# Takes no arguments; discovers everything from the current repo.
# Output uses # section_name markdown heading delimiters.

set -uo pipefail
# Note: -e intentionally omitted. Grep returning exit 1 (no match) is normal
# and should not abort the script.

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Directories excluded from all scans.
GREP_EXCLUDE="--exclude-dir=vendor --exclude-dir=build --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=third_party --exclude-dir=extern"

# Find files by extension, excluding noise directories.
# Usage: find_ext .cc .cpp .h
find_ext() {
    local args=()
    local first=true
    for ext in "$@"; do
        if $first; then
            args+=( -name "*${ext}" )
            first=false
        else
            args+=( -o -name "*${ext}" )
        fi
    done
    find . \
        \( -name vendor -o -name build -o -name node_modules \
           -o -name .git -o -name dist -o -name third_party -o -name extern \) \
        -prune -o -type f \( "${args[@]}" \) -print 2>/dev/null
}

# Count lines from stdin.
count_stdin() {
    wc -l | tr -d ' '
}

# Sum lines of code from file paths on stdin (empty input yields 0).
loc_stdin() {
    local files
    files=$(cat)
    if [ -z "$files" ]; then
        echo 0
    else
        echo "$files" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1+0}'
    fi
}

# ===================================================================
# 1. Repo name
# ===================================================================
echo "# repo"
basename "$ROOT"

# ===================================================================
# 2. Primary language(s)
# ===================================================================
echo ""
echo "# language"

count_lang() {
    local name="$1"; shift
    local n
    n=$(find_ext "$@" | count_stdin)
    if [ "$n" -gt 0 ]; then
        echo "$n $name"
    fi
}

{
    count_lang go          .go
    count_lang c           .c
    count_lang cpp         .cc .cpp .cxx
    count_lang header      .h .hpp .hxx
    count_lang python      .py
    count_lang rust        .rs
    count_lang typescript  .ts .tsx
    count_lang javascript  .js .jsx .mjs
    count_lang java        .java
    count_lang ruby        .rb
    count_lang swift       .swift
    count_lang kotlin      .kt .kts
    count_lang csharp      .cs
    count_lang shell       .sh .bash .zsh
    count_lang lua         .lua
    count_lang zig         .zig
} | sort -rn | while read -r cnt lang; do
    echo "$lang: $cnt files"
done

# ===================================================================
# 3. File counts
# ===================================================================
echo ""
echo "# file_counts"

src_count=$(find_ext .go .c .cc .cpp .cxx .py .rs .ts .tsx .js .jsx .java .rb .swift .kt .cs .lua .zig .sh | count_stdin)
test_count=$(find_ext .go .c .cc .cpp .cxx .py .rs .ts .tsx .js .jsx .java .rb .swift .kt .cs .lua .zig .sh .h .hpp \
    | { grep -E '(_test\.|\.test\.|_spec\.|\.spec\.|/test_)' || true; } | count_stdin)
header_count=$(find_ext .h .hpp .hxx | count_stdin)
doc_count=$(find_ext .md .rst .txt .adoc | count_stdin)

echo "source:  $src_count"
echo "test:    $test_count"
echo "header:  $header_count"
echo "docs:    $doc_count"

# ===================================================================
# 4. Lines of code
# ===================================================================
echo ""
echo "# loc"

src_loc=$(find_ext .go .c .cc .cpp .cxx .py .rs .ts .tsx .js .jsx .java .rb .swift .kt .cs .lua .zig .sh \
    | { grep -vE '(_test\.|\.test\.|_spec\.|\.spec\.|/test_)' || true; } \
    | loc_stdin)
test_loc=$(find_ext .go .c .cc .cpp .cxx .py .rs .ts .tsx .js .jsx .java .rb .swift .kt .cs .lua .zig .sh .h .hpp \
    | { grep -E '(_test\.|\.test\.|_spec\.|\.spec\.|/test_)' || true; } \
    | loc_stdin)
header_loc=$(find_ext .h .hpp .hxx | loc_stdin)

echo "source:  ${src_loc:-0}"
echo "test:    ${test_loc:-0}"
echo "header:  ${header_loc:-0}"

# ===================================================================
# 5. Build system
# ===================================================================
echo ""
echo "# build_system"

build_files=(
    Makefile makefile GNUmakefile
    CMakeLists.txt meson.build build.ninja
    Cargo.toml go.mod go.sum
    package.json pom.xml build.gradle build.gradle.kts
    setup.py setup.cfg pyproject.toml
    Gemfile Rakefile
    BUILD BUILD.bazel WORKSPACE WORKSPACE.bazel
    mkfile
    justfile Justfile
    SConstruct
    build.zig
    Taskfile.yml
    flake.nix shell.nix default.nix
)

found_any=false
for f in "${build_files[@]}"; do
    if [ -e "$f" ]; then
        echo "$f"
        found_any=true
    fi
done
for pat in '*.sln' '*.csproj' '*.xcodeproj'; do
    for match in $pat; do
        if [ -e "$match" ]; then
            echo "$match"
            found_any=true
        fi
    done
done
if ! $found_any; then
    echo "(none detected)"
fi

# ===================================================================
# 6. Test framework
# ===================================================================
echo ""
echo "# test_framework"

frameworks=""

detect_framework() {
    local name="$1" pattern="$2"
    if grep -rlq $GREP_EXCLUDE "$pattern" . 2>/dev/null; then
        frameworks="${frameworks:+$frameworks, }$name"
    fi
}

detect_framework "doctest"    '#include.*doctest'
detect_framework "gtest"      '#include.*gtest'
detect_framework "Catch2"     '#include.*catch2\|#include.*catch\.hpp'
detect_framework "pytest"     'import pytest\|from pytest'
detect_framework "unittest"   'import unittest\|from unittest'
detect_framework "jest"       "from 'jest'\\|require.*jest"
detect_framework "mocha"      "from 'mocha'\\|require.*mocha"
detect_framework "vitest"     "from 'vitest'\\|import.*vitest"
detect_framework "go test"    'func Test.*testing\.T'
detect_framework "cargo test" '#\[cfg(test)\]\|#\[test\]'
detect_framework "JUnit"      'import org\.junit\|import junit'
detect_framework "RSpec"      "require.*rspec\\|RSpec\\.describe"
detect_framework "XCTest"     'import XCTest'

if [ -n "$frameworks" ]; then
    echo "$frameworks"
else
    echo "(none detected)"
fi

# ===================================================================
# 7. Dependencies (vendored)
# ===================================================================
echo ""
echo "# dependencies"

dep_dirs=(vendor third_party extern)
found_deps=false

for dir in "${dep_dirs[@]}"; do
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 4 -type f \( -iname 'LICENSE*' -o -iname 'LICENCE*' -o -iname 'COPYING*' \) 2>/dev/null \
            | sort | while read -r lic; do
            dep_path=$(dirname "$lic")
            licence_id=$(head -5 "$lic" 2>/dev/null \
                | { grep -oiE 'MIT|Apache.?2|BSD|GPL|LGPL|MPL|ISC|Unlicense|Boost|Zlib|CC0' || true; } \
                | head -1)
            if [ -z "$licence_id" ]; then
                licence_id="(check manually)"
            fi
            echo "$dep_path  [$licence_id]"
        done
        found_deps=true
    fi
done

if ! $found_deps; then
    echo "(no vendor/third_party/extern directories)"
fi

# ===================================================================
# 8. NOTICES file
# ===================================================================
echo ""
echo "# notices_file"

notices_found=false
for f in NOTICES NOTICE NOTICES.md THIRD_PARTY THIRD_PARTY.md THIRD_PARTY_NOTICES; do
    if [ -e "$f" ]; then
        echo "$f"
        notices_found=true
    fi
done
if ! $notices_found; then
    echo "(missing)"
fi

# ===================================================================
# 9. Project licence
# ===================================================================
echo ""
echo "# licence"

lic_file=""
for f in LICENSE LICENSE.md LICENSE.txt LICENCE LICENCE.md LICENCE.txt COPYING COPYING.md; do
    if [ -e "$f" ]; then
        lic_file="$f"
        break
    fi
done

if [ -n "$lic_file" ]; then
    licence_id=$(head -5 "$lic_file" 2>/dev/null \
        | { grep -oiE 'MIT|Apache.?2|BSD.?[23]?|GPL.?v?[23]|LGPL|MPL|ISC|Unlicense|Boost|Zlib|CC0' || true; } \
        | head -1)
    if [ -n "$licence_id" ]; then
        echo "$lic_file ($licence_id)"
    else
        echo "$lic_file (unknown — inspect manually)"
    fi
else
    echo "(no licence file found)"
fi

# ===================================================================
# 10. CI workflow files
# ===================================================================
echo ""
echo "# ci"

ci_found=false

if [ -d .github/workflows ]; then
    find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort
    ci_found=true
fi
for f in .gitlab-ci.yml .circleci/config.yml .travis.yml azure-pipelines.yml Jenkinsfile; do
    if [ -e "$f" ]; then
        echo "$f"
        ci_found=true
    fi
done
if [ -d .buildkite ]; then
    find .buildkite -type f -name '*.yml' 2>/dev/null | sort
    ci_found=true
fi

if ! $ci_found; then
    echo "(none)"
fi

# ===================================================================
# 11. Git stats
# ===================================================================
echo ""
echo "# git_stats"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "?")
    contributors=$(git shortlog -sn --no-merges HEAD 2>/dev/null | count_stdin)
    first_commit=$(git log --reverse --format='%ai' 2>/dev/null | head -1 | cut -d' ' -f1)
    last_commit=$(git log -1 --format='%ai' 2>/dev/null | cut -d' ' -f1)
    echo "commits:      $total_commits"
    echo "contributors: $contributors"
    echo "first_commit: ${first_commit:-(unknown)}"
    echo "last_commit:  ${last_commit:-(unknown)}"
else
    echo "(not a git repository)"
fi

# ===================================================================
# 12. Open issues / PRs
# ===================================================================
echo ""
echo "# open_issues"

if command -v gh >/dev/null 2>&1; then
    if gh repo view --json name >/dev/null 2>&1; then
        open_issues=$(gh issue list --state open --limit 1000 --json number 2>/dev/null \
            | { grep -c '"number"' || true; })
        open_prs=$(gh pr list --state open --limit 1000 --json number 2>/dev/null \
            | { grep -c '"number"' || true; })
        echo "issues: ${open_issues:-0}"
        echo "PRs:    ${open_prs:-0}"
    else
        echo "(not a GitHub repo or no remote configured)"
    fi
else
    echo "(gh CLI not available — skipped)"
fi

# ===================================================================
# 13. Security scan (quick)
# ===================================================================
echo ""
echo "# security_scan"

# Hardcoded secrets (exclude test files and docs).
secrets_count=$(grep -rn $GREP_EXCLUDE \
    --exclude='*_test.*' --exclude='*.test.*' --exclude='*_spec.*' --exclude='*.spec.*' \
    --exclude='*.md' \
    -iE '(api_key|api_secret|apikey|secret_key|auth_token|access_token)\s*[=:]\s*"[A-Za-z0-9+/=_-]{8,}' \
    . 2>/dev/null | count_stdin)
password_count=$(grep -rn $GREP_EXCLUDE \
    --exclude='*_test.*' --exclude='*.test.*' --exclude='*_spec.*' --exclude='*.spec.*' \
    --exclude='*.md' \
    -iE 'password\s*[=:]\s*"[^"]{4,}"' \
    . 2>/dev/null | count_stdin)

echo "hardcoded secrets (api_key/secret/token): $secrets_count matches"
echo "hardcoded passwords:                      $password_count matches"

# Unsafe C/C++ functions.
unsafe_count=$(grep -rn $GREP_EXCLUDE \
    --include='*.c' --include='*.cc' --include='*.cpp' --include='*.cxx' \
    --include='*.h' --include='*.hpp' \
    -E '\b(gets|strcpy|strcat|sprintf|vsprintf)\b' \
    . 2>/dev/null | count_stdin)
echo "unsafe C/C++ functions (gets/strcpy/sprintf): $unsafe_count matches"

# SQL injection patterns.
sqli_count=$(grep -rn $GREP_EXCLUDE \
    -E '(execute|query|raw|exec)\s*\(.*"\s*\+|f".*SELECT|f".*INSERT|f".*UPDATE|f".*DELETE' \
    . 2>/dev/null | count_stdin)
echo "SQL injection patterns:                    $sqli_count matches"

# ===================================================================
# 14. TODO/FIXME/HACK/XXX
# ===================================================================
echo ""
echo "# todo_fixme"

todo_count=$(grep -rn $GREP_EXCLUDE \
    -E '\b(TODO|FIXME|HACK|XXX)\b' \
    . 2>/dev/null | count_stdin)
echo "TODO/FIXME/HACK/XXX: $todo_count"

# ===================================================================
# 15. Working tree status
# ===================================================================
echo ""
echo "# working_tree"

git status --short --branch 2>/dev/null || echo "(not a git repository)"
