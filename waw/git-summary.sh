#!/bin/sh
# Git state snapshot for /waw skill.
git remote get-url origin 2>/dev/null | sed 's|.*/||;s|\.git$||'
echo "---"
git status --short --branch
echo "---"
git log --oneline -8
