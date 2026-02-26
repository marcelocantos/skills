#!/bin/sh
# Git state snapshot for /waw skill.
echo "=== repo ==="
git remote get-url origin 2>/dev/null | sed 's|.*/||;s|\.git$||'
echo "=== status ==="
git status --short --branch
echo "=== log ==="
git log --oneline -8
