#!/usr/bin/env bash
# Phase 5 finalisation for the /release skill.
# Run after `bullseye_retire` (or any other bullseye mutation made during
# the release). Ensures bullseye.yaml is not left dirty in the working
# tree — /cv runs immediately after a release rely on a clean tree.
#
# Commits locally only. Does NOT push: per the global directive on
# target-only edits, retire commits ride along with the next substantive
# PR.
#
# Usage: finalize.sh <version> [target-id]
set -euo pipefail

version="${1:?usage: finalize.sh <version> [target-id]}"
target_id="${2:-}"

if [[ ! -f bullseye.yaml ]]; then
    exit 0
fi

if git diff --quiet bullseye.yaml && git diff --cached --quiet bullseye.yaml; then
    exit 0
fi

if [[ -n "$target_id" ]]; then
    msg="chore: retire 🎯T${target_id} — released in ${version}"
else
    msg="chore: refresh bullseye.yaml after ${version} release"
fi

git add bullseye.yaml
git commit -m "$msg"
echo "Committed bullseye.yaml cleanup: $msg"
