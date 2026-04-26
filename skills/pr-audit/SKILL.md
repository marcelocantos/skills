---
name: pr-audit
description: Audit open PRs across all owned repos and recommend cleanup actions (close superseded, merge ready, poke contrib reviewers, fan-in synchronized rollouts).
user-invocable: true
---

Survey open pull requests across every GitHub repo authored by the current
user, classify each one, and recommend a concrete next action. Don't take
the actions automatically — present a triage list and let the user
approve in bulk.

## Step 1 — Gather

Execute `~/.claude/skills/pr-audit/gather.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`). The script emits four
sections:

- `# user` — the GitHub login it queried as.
- `# open-prs` — JSON array: every open PR authored by the user, with
  `repository`, `number`, `title`, `createdAt`, `updatedAt`, `isDraft`,
  `url`.
- `# pr-details` — one JSON object per PR (newline-delimited): `url`,
  `files` (file list — used to detect target-only PRs), `mergeable`,
  `mergeStateStatus`, `headRefName`, `baseRefName`, `statusCheckRollup`,
  `reviewDecision`, `labels`, `commits`.
- `# recently-merged` — JSON array: PRs merged in the last 30 days.
  Used to detect superseded target-only PRs.

If gather fails (e.g. `gh` not authenticated), report the error and stop.

## Step 2 — Classify

For each open PR, assign exactly one classification:

### 🗑️ `close-superseded`
- **Target-only PR** (the only file touched across all commits is
  `bullseye.yaml`) **and** a substantive PR in the same repo was
  merged after this one was opened — the target state likely already
  reflects the new reality, or a newer target-only PR has overwritten
  the same edit.
- Any PR for a project listed as obsolete in the user's auto-memory
  (check `~/.claude/projects/-Users-marcelo-think/memory/MEMORY.md`).

### ✅ `merge-now`
- Not a target-only PR.
- `mergeable: MERGEABLE` and `mergeStateStatus: CLEAN`.
- All status checks `SUCCESS` (or no checks configured).
- Not draft.
- No `CHANGES_REQUESTED` review.
- Owned-org repo (skip contrib repos like `anz-bank/*`, `arr-ai/*` if
  reviews are pending — those go to `poke-reviewer`).

### 📋 `target-only-leave-open`
- Only file touched is `bullseye.yaml`, AND no superseding merge.
- Per global CLAUDE.md, these intentionally stay open until the
  substantive work lands. Just count them; don't recommend action
  unless the count for a single repo exceeds 3 (then suggest a manual
  consolidation pass).

### 🚧 `resolve-conflicts`
- `mergeable: CONFLICTING` or `mergeStateStatus: DIRTY`.
- Recommend: rebase onto base branch, or close if the work is stale.

### 🔴 `fix-ci`
- Status checks include `FAILURE` or `ERROR`.
- Recommend: investigate the failing check.

### 👀 `poke-reviewer`
- Contrib repo (org isn't one of: `marcelocantos`, `squz`,
  `minicadesmobile`, `linqgo`).
- Open >14 days with no `reviewDecision` of `APPROVED` or
  `CHANGES_REQUESTED`.
- Recommend: add a polite nudge comment, or close if abandoned (>180
  days).

### 🪦 `abandoned`
- Open >90 days, no commits or comments in 60 days.
- Recommend: close with a brief explanation, or revive with a clear
  next step.

### 🚂 `rollout-fan-in`
- Three or more open PRs across different repos with substantively
  identical titles or head-branch names (e.g. seven "ccache wiring"
  PRs opened the same day). Group them.
- Recommend: drive them all to merge in one batch, or close the ones
  that are no longer needed.

### ⏳ `wait`
- Draft, or recently updated (<48h) and CI still running.
- No action — comes back next audit.

## Step 3 — Report

Present a compact table grouped by classification, ordered by urgency:

```
🗑️  Close superseded (N)
  - <repo>#<num>  <title>           <age>   reason
✅  Ready to merge (N)
  - <repo>#<num>  <title>           <age>
🚂 Rollout fan-in (N groups)
  - "<common title>" — <repo>#<num>, <repo>#<num>, ...
🚧 Conflicts (N)
🔴 Failing CI (N)
👀 Poke reviewers (N)
🪦 Abandoned (N)
📋 Target-only PRs holding pattern (N total, K in repos with >3)
⏳ Waiting (N)
```

End with a one-line summary: "M PRs total, X actionable now."

## Step 4 — Act (only on user request)

Don't take any action automatically. After presenting the report:

- If the user says "close all superseded" / "merge all green" / "poke
  the contrib ones" / etc., perform the action via `gh`.
- For `close-superseded`, use `gh pr close <num> --repo <repo>
  --comment "..."` with a short reason.
- For `merge-now`, route through the project's `/push` skill if its
  merge gates apply, or `gh pr merge --squash --delete-branch
  --repo <repo> <num>` for trivial merges.
- For `poke-reviewer`, draft a short comment and confirm before
  posting.
- Always batch confirmations: "Close these 4 superseded PRs? [y/n]"
  rather than one-by-one prompts.

## Notes

- "Owned org" list is currently `marcelocantos`, `squz`,
  `minicadesmobile`, `linqgo`. Expand here if the user adds new orgs.
- Target-only detection is structural (file list = `[bullseye.yaml]`),
  not title-based. A PR that mixes target edits and code is **not**
  target-only.
- The script queries via `gh search prs --author <login>`, so it sees
  every PR you've opened across all of GitHub, including contrib
  upstreams. Filter as needed.
- This skill is read-mostly and idempotent — safe to run frequently.
