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
compaction per active span; `mnemo_ops` (op=restore) walks the `/clear`-
bounded chain and returns every compaction oldest-first.

## Steps

1. **Identify the session to restore.** Call `mnemo_sessions` with the
   current repo and `session_type: "interactive"`, and take the most
   recent session other than this one — that is the span `/clear` just
   ended.

   This replaced `mnemo_self`, removed 2026-08-07. That tool used a
   nonce round-trip: emit `mnemo:self:<nonce>`, wait for the transcript
   to be ingested, then ask which session contained it. It depended on
   ingest having caught up mid-turn and recorded **2 nonces in four
   months** against 11 calls. The recency heuristic here is less precise
   in principle and works more often in practice; when it picks wrong,
   the restored summary is visibly about other work, so pass an explicit
   `session_id` from `mnemo_sessions` instead.

2. **Fetch the chain compactions.** Call `mnemo_ops(op: "restore")` with
   `session_id=<id from step 1>`. It returns a pre-formatted multi-span
   summary (targets, files, decisions, open threads per span),
   oldest-first — and it walks the `/clear`-bounded chain from that id,
   so landing anywhere in the chain restores the whole chain.

3. **Present verbatim.** Relay the tool output to the user with at
   most a one-line framing. Do **not** re-summarise — the output is
   already compacted. If the restored context makes the next move
   obvious, say so in one line; otherwise wait for the user to
   direct.

## If there is no compaction yet

If `mnemo_ops` (op=restore) says "No compactions available yet for this
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
