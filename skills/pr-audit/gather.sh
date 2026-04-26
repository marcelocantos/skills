#!/bin/sh
# Gather open PRs across all repos authored by the current GitHub user
# and emit structured data for the /pr-audit skill to classify.
section() { echo "# $1"; }

# --- Identify the user ---
section "user"
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "")
echo "login: $GH_USER"
if [ -z "$GH_USER" ]; then
    echo "(gh not authenticated — abort)"
    exit 1
fi

# --- All open PRs authored by this user ---
section "open-prs"
gh search prs \
    --author "$GH_USER" \
    --state open \
    --limit 200 \
    --sort updated \
    --json repository,number,title,createdAt,updatedAt,isDraft,url

# --- Per-PR detail enrichment ---
# For each PR returned above, query: file list (to detect target-only),
# CI status, mergeable state, head/base ref. Emit one JSON object per
# line so the skill can correlate with the list above.
section "pr-details"
gh search prs --author "$GH_USER" --state open --limit 200 --json url --jq '.[].url' | \
while IFS= read -r url; do
    # url form: https://github.com/<owner>/<repo>/pull/<n>
    repo=$(echo "$url" | sed -E 's#https://github.com/([^/]+/[^/]+)/pull/.*#\1#')
    num=$(echo "$url" | sed -E 's#.*/pull/([0-9]+).*#\1#')
    gh pr view "$num" --repo "$repo" --json url,files,mergeable,mergeStateStatus,headRefName,baseRefName,statusCheckRollup,reviewDecision,labels 2>/dev/null \
        | jq -c '{url, files: [.files[].path], mergeable, mergeStateStatus, headRefName, baseRefName, checks: [.statusCheckRollup[]? | {name, conclusion, status}], reviewDecision, labels: [.labels[].name]}' \
        || echo "{\"url\":\"$url\",\"error\":\"view-failed\"}"
done

# --- Recently-merged PRs (last 30 days) ---
# Used to detect "superseded" target-only PRs: if a substantive PR
# touching the same area was merged after the target-only PR was opened,
# the target-only one can usually be closed.
section "recently-merged"
gh search prs \
    --author "$GH_USER" \
    --state closed \
    --merged \
    --updated ">$(date -u -v-30d +%Y-%m-%d 2>/dev/null || date -u -d '30 days ago' +%Y-%m-%d)" \
    --limit 100 \
    --sort updated \
    --json repository,number,title,updatedAt,url
