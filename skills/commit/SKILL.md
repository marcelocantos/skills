---
name: commit
description: Stage and commit changes with an auto-drafted message.
user-invocable: true
---

# Commit

Stage and commit current changes with an auto-drafted commit message.
Replaces the manual cycle of status/diff/log/add/commit/verify.

## Arguments

- `/commit` — auto-draft message from diff analysis.
- `/commit <message>` — use the given message as-is (still adds the
  Co-Authored-By trailer).
- `/commit --amend` — amend the previous commit instead of creating a
  new one. Only use when explicitly requested.

## Steps

### 1. Survey changes

Run in parallel:
- `git status --short --branch` (never `-uall`)
- `git diff --stat` and `git diff --cached --stat`
- `git log --oneline -5` (for message style reference)

If there are no changes (no modified, staged, or untracked files),
report "nothing to commit" and stop.

### 2. Read diffs

Read the actual diffs to understand what changed:
- `git diff` for unstaged changes
- `git diff --cached` for already-staged changes
- For untracked files, read them (or at least their first ~100 lines
  for large files) to understand their purpose.

### 3. Filter files

Identify files to stage. **Exclude** by default:
- `.env`, `.env.*` files
- Files matching `*credential*`, `*secret*`, `*_key`, `*.pem`,
  `*.key`, `*token*` (case-insensitive, in filename not path
  components like `pkg/token/`)
- Any file that appears to contain secrets (API keys, passwords,
  private keys) based on content inspection

If any excluded files are found, warn the user and list them. If
the user's explicit message or prior instruction includes those
files, ask for confirmation before staging them.

Stage everything else. Prefer `git add <file1> <file2> ...` over
`git add -A`.

### 4. Draft message

If the user provided a message argument, use it directly.

Otherwise, analyse the staged diffs and draft a commit message:

- **First line**: imperative mood, under 72 chars. Summarise the
  *purpose* of the change (the "why"), not a mechanical listing of
  files. Use accurate verbs: "add" for new features, "fix" for bug
  fixes, "update" for enhancements, "remove" for deletions,
  "refactor" for structural changes with no behaviour change.
- **Body** (optional): if the change is non-trivial, add a blank
  line then 1-3 sentences of context. Skip if the first line says
  it all.
- Follow the commit message style visible in `git log`.
- End with the `Co-Authored-By` trailer.

Present the draft to the user for approval. If they approve (or
say nothing contentious), proceed. If they suggest edits, incorporate
them.

### 5. Commit

Create the commit using a HEREDOC for the message:

```bash
git commit -m "$(cat <<'EOF'
<message>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

If `--amend` was requested, use `git commit --amend` instead. Only
do this when the user explicitly asked for amend.

### 6. Verify

Run `git status --short --branch` to confirm the commit succeeded.
Report the commit hash and summary.

If the commit fails due to a pre-commit hook:
1. Read the hook output to understand the failure.
2. Fix the issue.
3. Re-stage the fixed files.
4. Create a **new** commit (never amend after a hook failure unless
   the user explicitly requests it, since the failed commit didn't
   happen).

## Notes

- Never push after committing — that's `/push`'s job.
- Never skip hooks (`--no-verify`).
- Always use HEREDOC for the commit message to preserve formatting.
- If all changes are already staged (cached), don't re-add them.
