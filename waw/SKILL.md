---
name: waw
description: "Where Are We?" — Context restoration after being AFK. Summarises session state, surfaces important details, and proposes continuation options.
user-invocable: true
---

The user has been away and needs to get back up to speed.

First, execute `~/.claude/skills/waw/git-summary.sh` directly (it is already
`chmod +x` — do **not** wrap it in `bash`, just invoke the path as the command)
to get repo name, working tree state, and recent commits in a single call.

Then produce a concise context-restoration briefing covering the following
sections. Skip any section that has nothing to report.

## 1. Summary

Include the current repository name (from the working directory or git remote)
in the heading, e.g. "## 👉 Summary — myproject". Then one or two sentences
covering what was accomplished in this session and where things stand right now.
If conversation context has been compacted, note this and flag that details from
before the compaction boundary may be approximate.

## 2. Working tree state

Check for uncommitted changes (unstaged edits, staged but uncommitted work,
untracked files). These often represent the exact point where work was
interrupted. Report them briefly — file names and what changed, not full diffs.

## 3. Recent commits

List commits made during this session (use judgement on how far back to look).
One line each — hash and message.

## 4. Key decisions

If the session involved design discussions, trade-off decisions, or explicit
choices to do or not do something, summarise them briefly. This helps the user
remember *why* things are the way they are.

## 5. Build / test status

If the last build or test run had failures, surface them prominently — they're
likely the most urgent thing to deal with. If everything was green, say so
briefly.

## 6. Open TODOs

Invoke the `/todo` skill to surface open TODO items for the project. Include
its output as this section.

## 7. What's next?

Based on the session context, infer what was likely to happen next. Present
one or more concrete continuation options for the user to pick from. Frame
these as actionable choices, not open-ended questions.
