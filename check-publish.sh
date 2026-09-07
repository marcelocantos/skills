#!/usr/bin/env bash
# Verify the published tree is self-contained.
#
# CLAUDE.md is an adapter: it `@import`s AGENTS.md and links sibling
# companion files. Anything it names with a repo-relative path must be in
# the repo, or a clone of this repo reads an adapter whose rules are
# missing. Links to ~/.claude/... are deliberately author-machine paths and
# are not checked here.
set -uo pipefail

cd "$(dirname "$0")"

fail=0

for f in AGENTS.md CLAUDE.md convergence.md; do
  if [ ! -f "$f" ]; then
    echo "check-publish: FAIL: $f is not in the repo" >&2
    fail=1
  fi
done

# Repo-relative broken links in the root adapter documents. Files under
# skills/ are an rsync mirror of the live tree and are checked there, not
# here; their relative links point at the repos the skills operate on.
broken=$(./skills/docs/link-check.sh 2>&1 \
  | grep -E '^(AGENTS|CLAUDE|convergence|README)\.md:' \
  | grep 'broken link:' | grep -v 'broken link: ~/')
if [ -n "$broken" ]; then
  echo "check-publish: FAIL: repo-relative links do not resolve:" >&2
  printf '%s\n' "$broken" >&2
  fail=1
fi

[ "$fail" -eq 0 ] && echo "check-publish: OK"
exit "$fail"
