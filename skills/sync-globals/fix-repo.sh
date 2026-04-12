#!/usr/bin/env bash
# Copyright 2026 Marcelo Cantos
# SPDX-License-Identifier: Apache-2.0
#
# fix-repo.sh <repo-path> [--license] [--spdx] [--gitignore] [--notice]
#             [--year YYYY] [--holder "Name"]
#
# Mechanical per-repo fixer for sync-globals. Applies open-source hygiene
# operations to a repository directory. Flags can be combined freely.

set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: fix-repo.sh <repo-path> [OPTIONS]

Options:
  --license          Write Apache 2.0 LICENSE file (skips if already exists)
  --spdx             Prepend SPDX headers to source files missing them
  --gitignore        Write minimal .gitignore (skips if already exists)
  --notice           Write NOTICE file (skips if already exists)
  --year YYYY        Copyright year (default: current year)
  --holder "Name"    Copyright holder (default: Marcelo Cantos)
EOF
    exit 2
}

# Defaults
YEAR="$(date +%Y)"
HOLDER="Marcelo Cantos"
DO_LICENSE=0
DO_SPDX=0
DO_GITIGNORE=0
DO_NOTICE=0
REPO_PATH=""

# Parse arguments
if [[ $# -eq 0 ]]; then
    usage
fi

REPO_PATH="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --license)   DO_LICENSE=1; shift ;;
        --spdx)      DO_SPDX=1; shift ;;
        --gitignore) DO_GITIGNORE=1; shift ;;
        --notice)    DO_NOTICE=1; shift ;;
        --year)
            shift
            [[ $# -eq 0 ]] && { echo "error: --year requires a value" >&2; exit 2; }
            YEAR="$1"; shift
            ;;
        --holder)
            shift
            [[ $# -eq 0 ]] && { echo "error: --holder requires a value" >&2; exit 2; }
            HOLDER="$1"; shift
            ;;
        -h|--help) usage ;;
        *)
            echo "error: unknown option: $1" >&2
            usage
            ;;
    esac
done

if [[ $((DO_LICENSE + DO_SPDX + DO_GITIGNORE + DO_NOTICE)) -eq 0 ]]; then
    echo "error: no operation specified" >&2
    usage
fi

# Validate repo path — must be absolute and must not escape via symlink tricks
if [[ -z "$REPO_PATH" ]]; then
    echo "error: repo path is required" >&2
    usage
fi

REPO_REAL="$(realpath "$REPO_PATH" 2>/dev/null)" || {
    echo "error: cannot resolve repo path: $REPO_PATH" >&2
    exit 1
}

# Reject paths that resolve to / to avoid accidental root operations
if [[ "$REPO_REAL" == "/" ]]; then
    echo "error: repo path resolves to filesystem root" >&2
    exit 1
fi

# Ensure path resolves to a directory
if [[ ! -d "$REPO_REAL" ]]; then
    echo "error: not a directory: $REPO_REAL" >&2
    exit 1
fi

REPO_BASENAME="$(basename "$REPO_REAL")"

# ─── --license ────────────────────────────────────────────────────────────────

do_license() {
    local dest="$REPO_REAL/LICENSE"
    if [[ -e "$dest" ]]; then
        echo "LICENSE already exists, skipping" >&2
        return
    fi

    cat > "$dest" <<EOF
Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to the Licensor for inclusion in the Work by the copyright
      owner or by an individual or Legal Entity authorized to submit on
      behalf of the copyright owner. For the purposes of this definition,
      "submitted" means any form of electronic, verbal, or written
      communication sent to the Licensor or its representatives, including
      but not limited to communication on electronic mailing lists, source
      code control systems, and issue tracking systems that are managed by,
      or on behalf of, the Licensor for the purpose of discussing and
      improving the Work, but excluding communication that is conspicuously
      marked or otherwise designated in writing by the copyright owner as
      "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by the Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding any notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or exemplary damages of any character arising as a result
      of this License or out of the use or inability to use the Work
      (including but not limited to damages for loss of goodwill, work
      stoppage, computer failure or malfunction, or any and all other
      commercial damages or losses), even if such Contributor has been
      advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. Please also get an approval
      for your license at the Software Package Data Exchange (SPDX)
      website - https://spdx.org/licenses/.

   Copyright ${YEAR} ${HOLDER}

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
EOF
    echo "LICENSE written"
}

# ─── --gitignore ──────────────────────────────────────────────────────────────

do_gitignore() {
    local dest="$REPO_REAL/.gitignore"
    if [[ -e "$dest" ]]; then
        echo ".gitignore already exists, skipping" >&2
        return
    fi

    cat > "$dest" <<'EOF'
.DS_Store
*.swp
build/
dist/
node_modules/
__pycache__/
*.pyc
.vscode/
.idea/
.venv/
venv/
EOF
    echo ".gitignore written"
}

# ─── --notice ─────────────────────────────────────────────────────────────────

do_notice() {
    local dest="$REPO_REAL/NOTICE"
    if [[ -e "$dest" ]]; then
        echo "NOTICE already exists, skipping" >&2
        return
    fi

    cat > "$dest" <<EOF
${REPO_BASENAME}
Copyright ${YEAR} ${HOLDER}

This product includes software developed by ${HOLDER}.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
EOF
    echo "NOTICE written"
}

# ─── --spdx ───────────────────────────────────────────────────────────────────

# File extensions using // comments
SLASH_EXTS="c h cc cpp cxx hpp hxx m mm java kt kts swift ts tsx js jsx mjs cjs go rs cs scala dart"

# File extensions using # comments
HASH_EXTS="py rb sh zsh bash yaml yml mk tf"

# Special filenames using # comments
HASH_NAMES="Makefile"

# Directories to skip (relative, matched by path component)
SKIP_DIRS="vendor third_party extern node_modules build dist .git target .venv venv __pycache__"

# Build a find-style prune expression for skip dirs
build_prune_args() {
    local first=1
    for d in $SKIP_DIRS; do
        if [[ $first -eq 0 ]]; then
            printf " -o"
        fi
        printf " -name %s" "$d"
        first=0
    done
}

has_spdx_in_first10() {
    local file="$1"
    head -10 "$file" | grep -q "SPDX-License-Identifier"
}

# Returns the comment prefix for a file, or "" if unsupported
comment_style_for() {
    local file="$1"
    local base ext
    base="$(basename "$file")"
    ext="${base##*.}"

    # Check exact filenames first
    for name in $HASH_NAMES; do
        if [[ "$base" == "$name" ]]; then
            echo "#"
            return
        fi
    done

    # Extension match (only if there's an actual extension, i.e. dot not first char and ext != base)
    if [[ "$base" != "$ext" && "$base" != ".$ext" ]]; then
        for e in $SLASH_EXTS; do
            if [[ "$ext" == "$e" ]]; then
                echo "//"
                return
            fi
        done
        for e in $HASH_EXTS; do
            if [[ "$ext" == "$e" ]]; then
                echo "#"
                return
            fi
        done
    fi

    echo ""
}

prepend_spdx() {
    local file="$1"
    local prefix="$2"
    local original_mode
    original_mode="$(stat -f "%Mp%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)"

    local content
    content="$(cat "$file")"
    local shebang=""
    local encoding=""
    local rest="$content"

    # Extract shebang if present (only for # comment files)
    if [[ "$prefix" == "#" && "$content" == \#!* ]]; then
        shebang="$(printf '%s\n' "$content" | head -1)"
        rest="$(printf '%s\n' "$content" | tail -n +2)"

        # Extract encoding declaration if present (only Python)
        local ext="${file##*.}"
        if [[ "$ext" == "py" ]] && printf '%s\n' "$rest" | head -1 | grep -qE '^#.*coding[=:]'; then
            encoding="$(printf '%s\n' "$rest" | head -1)"
            rest="$(printf '%s\n' "$rest" | tail -n +2)"
        fi
    fi

    local header
    header="${prefix} Copyright ${YEAR} ${HOLDER}
${prefix} SPDX-License-Identifier: Apache-2.0"

    {
        if [[ -n "$shebang" ]]; then printf '%s\n' "$shebang"; fi
        if [[ -n "$encoding" ]]; then printf '%s\n' "$encoding"; fi
        printf '%s\n' "$header"
        printf '%s\n' "$rest"
    } > "${file}.spdx.tmp"

    mv "${file}.spdx.tmp" "$file"

    # Restore original mode
    chmod "$original_mode" "$file" 2>/dev/null || true

    echo "spdx: $file"
}

do_spdx() {
    # Build prune directories pattern
    local prune_args=()
    for d in $SKIP_DIRS; do
        prune_args+=(-name "$d" -prune -o)
    done

    while IFS= read -r -d '' file; do
        local prefix
        prefix="$(comment_style_for "$file")"
        [[ -z "$prefix" ]] && continue
        has_spdx_in_first10 "$file" && continue
        prepend_spdx "$file" "$prefix"
    done < <(find "$REPO_REAL" \
        "${prune_args[@]}" \
        -type f -print0)
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────

[[ $DO_LICENSE   -eq 1 ]] && do_license
[[ $DO_GITIGNORE -eq 1 ]] && do_gitignore
[[ $DO_NOTICE    -eq 1 ]] && do_notice
[[ $DO_SPDX      -eq 1 ]] && do_spdx
