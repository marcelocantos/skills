---
name: waw
description: "Where Are We?" — Context restoration after being AFK. Default is a quick recap; `/waw all` runs the full deep briefing.
user-invocable: true
args: "[all]"
---

## Modes

- **`/waw`** (default) — Quick recap. Run `gather.sh`, then produce a
  short briefing covering only: Summary, Working tree state, Git
  activity (recent commits), and What's next. No target evaluation, no
  maintenance audit, no TODO scan. This should be fast — a few tool
  calls at most.

- **`/waw all`** — Full deep briefing. Delegates to worker.md for
  the complete context restoration including target status, maintenance
  status, TODOs, key decisions, and build/test status.

## Quick mode (default)

Execute `~/.claude/skills/waw/gather.sh` directly (it is already
`chmod +x`). From its output, produce a briefing with these sections
only (skip any that have nothing to report):

### Summary — {repo}
One or two sentences: what branch, how far ahead/behind remote, and
the general state of things (based on recent commit messages and
working tree).

### Working tree
Uncommitted changes — file names and a brief note on each. Flag
untracked files that look like they should be committed or ignored.

### Recent commits
Last ~10 commits, one line each (hash + message).

### What's next
Infer from the working tree state and recent commits. Suggest 2-3
concrete continuation options.

If a `wrap-draft.md` exists in the auto-memory directory, mention it:
"Interrupted wrap recovered — run `/waw all` or `/cv` to
incorporate."

## All mode

**DELEGATE VIA AGENT.** Spawn an Agent (subagent_type: general-purpose,
model: opus) with the prompt `"Read and execute
~/.claude/skills/waw/worker.md. Return the full briefing."`.
Relay the agent's result to the user.
