---
name: commit
description: Stage and commit changes with an auto-drafted message.
user-invocable: true
---

# Commit

Stage and commit current changes with an auto-drafted commit message.
Replaces the manual cycle of status/diff/log/add/commit/verify.

## Arguments

- `/commit` — auto-draft message from diff analysis (full tree).
- `/commit <message>` — use the given message as-is (still adds the
  Co-Authored-By trailer).
- `/commit --amend` — amend the previous commit instead of creating a
  new one. Only use when explicitly requested.

When the user mentions specific files in their request (e.g., "commit
foo.py" or "just commit the Makefile changes"), pass those paths to
gather.sh to scope the output. This avoids dumping the full-tree diff
when only a subset is relevant — critical for repos with large working
trees.

## Steps

### 1. Gather repo state

Run `~/.claude/skills/commit/gather.sh [path ...]` from the project
root. Pass file/directory paths to scope the output; omit for full
tree. It emits labelled sections — parse each section by its
`# <name>` header:

| Section | Contents | How to use |
|---|---|---|
| `# scope` | `full-tree` or a list of paths | Confirms what was scoped; if paths were given, only those paths appear in subsequent sections |
| `# status` | `git status --short --branch` output (always full tree) | Detect branch, staged/unstaged/untracked counts |
| `# log` | Last 5 commits (oneline) | Infer commit message style for the project |
| `# staged-stat` | `git diff --cached --stat` | Quick overview of what's already staged |
| `# unstaged-stat` | `git diff --stat` | Quick overview of what's modified but not staged |
| `# staged-diff` | Full `git diff --cached` | Understand staged changes in detail |
| `# unstaged-diff` | Full `git diff` | Understand unstaged changes in detail |
| `# untracked` | Each untracked text file: `FILE: <path>` header + first 100 lines, then blank line; binary files noted but skipped | Understand the purpose of new files |
| `# secret-candidates` | Full paths of changed/untracked files whose **basename** matches `.env`, `.env.*`, `*credential*`, `*secret*`, `*_key`, `*.pem`, `*.key`, `*token*` (case-insensitive) | First pass of files to exclude from staging |
| `# nothing-to-commit` | `true` or `false` | If `true`, report "nothing to commit" and stop |

If the script exits non-zero (e.g., not a git repo), report the error
and stop.

### 2. Filter files

Using the gathered data, identify files to stage. **Exclude** by default:

- Everything listed under `# secret-candidates` (filename-pattern matches)
- Any file whose **content** appears to contain secrets (API keys,
  passwords, private keys) — inspect `# staged-diff`, `# unstaged-diff`,
  and `# untracked` content for patterns like `sk-`, `-----BEGIN`,
  `password =`, `api_key =`, etc.

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

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If `--amend` was requested, use `git commit --amend` instead. Only
do this when the user explicitly asked for amend.

### 6. Verify

Run `git rev-parse --short HEAD` to capture the commit hash, then
`git log -1 --pretty=format:'%s'` for the subject. Report both as
`<hash> <subject>`. Don't assert "commit succeeded" without the
actual hash — `git commit` exits non-zero on failure, so a hash you
extracted post-hoc is the proof.

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
