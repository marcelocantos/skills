---
name: c
description: Continue — restore compacted context from this session's chain after a /clear. Short to type on purpose.
user-invocable: true
---

# /c — Continue where you left off

Restores the compacted context from the session chain that contains
this session. Use immediately after `/clear` (or at the start of a
fresh session that is continuing earlier work) to pick up with the
targets, decisions, files, and open threads from prior spans.

Backed by the mnemo compactor: a background summariser writes a
compaction per active span; `mnemo_restore` walks the `/clear`-
bounded chain and returns every compaction oldest-first.

## Steps

1. **Identify this session.** Invoke `mcp__mnemo__mnemo_self` with
   a short random nonce (e.g. 8 hex chars). Include the literal
   string `mnemo:self:<nonce>` in the same message's text so the
   server can correlate. The tool returns this session's ID.

2. **Fetch the chain compactions.** Invoke `mcp__mnemo__mnemo_restore`
   with `session_id=<id from step 1>`. It returns a pre-formatted
   multi-span summary (targets, files, decisions, open threads per
   span), oldest-first.

3. **Present verbatim.** Relay the tool output to the user with at
   most a one-line framing. Do **not** re-summarise — the output is
   already compacted. If the restored context makes the next move
   obvious, say so in one line; otherwise wait for the user to
   direct.

## If there is no compaction yet

If `mnemo_restore` says "No compactions available yet for this
session chain", that means either this is a brand-new session with
nothing upstream, or the prior span was too short/idle for the
background compactor (runs every 5 minutes) to have fired. Say so
plainly, then fall back to `mnemo_recent_activity` or
`git log --oneline -10` and ask the user what to work on.

## Do not

- Do not chain into `/cv` automatically. `/c` restores context; the
  user runs `/cv` separately if they want a next-work recommendation.
- Do not summarise the compacted context further — further
  summarisation drops load-bearing detail.
