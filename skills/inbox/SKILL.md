---
name: inbox
description: Pull cross-session inbox notes addressed to this repo (or a given directory) via mnemo, and optionally wait for one to arrive.
user-invocable: true
---

Receive directory-addressed inbox notes left by another agent session
(Grok or Claude), backed by the mnemo MCP server (🎯T65). A note is
addressed to a **directory** — usually a repo root. `/inbox` reads the
notes waiting for *this* session's directory; `/inbox <path>` reads
another's.

This is the consumer half of the inbox primitive. The producer half is
`/post` (a thin wrapper over `mnemo_note_post`).

If a mnemo tool errors (e.g. connection refused), the daemon isn't
running — tell the user to start it (`brew services start mnemo`) rather
than reading any files by hand.

## Determine the inbox

- **`/inbox` (no args)** — your inbox is this session's own working
  directory. You already know it (the session's primary working
  directory). Use that **absolute path** as the inbox.

  Equivalently, `mnemo_note_recv(inbox: ".")` resolves `"."` against
  the session's *initial* cwd on the daemon side — but that requires the
  daemon to have bound this MCP connection to its agent session.
  If a `"."` call errors with "the calling session's cwd is unknown",
  establish the binding once via the `mnemo_self` nonce dance (call
  `mnemo_self` with no argument, emit the returned nonce in your reply so
  it is ingested, then call `mnemo_self` again with that nonce) and
  retry — or just pass the absolute path, which never needs the binding.

- **`/inbox <path>`** — use `<path>` as the inbox (absolute, or relative
  to this session's cwd). A leading `~` is not allowed (shell
  home-expansion is ambiguous); pass an absolute path or a `./`-relative
  one.

## Read

Call `mnemo_note_recv` with the resolved inbox. Defaults are
`unread_only=true` and `mark_read=true`, so a plain read consumes the
pending notes (they remain browsable later via `mnemo_note_list`):

```
mnemo_note_recv(inbox: "<resolved inbox>")
```

Present each note's `body`, who sent it (`from_repo` / `from_session`),
and `posted_at`.

**If `mnemo_note_recv` returns no unread notes, do NOT just report an
empty inbox.** Fall back to a non-consuming browse of the same inbox:

```
mnemo_note_list(inbox: "<resolved inbox>", days: 7)
```

If that surfaces recently-read notes, show the most recent one (or two),
framed as already-delivered — e.g. *"Nothing new. The last note (already
read at `<read_at>`, from `<from_repo>`) was:"* followed by its body.
Only when `mnemo_note_list` is **also** empty do you report a genuinely
empty inbox.

Why this matters: `mnemo_note_recv` marks a note read the instant it is
returned — *before* you present it. If the session is interrupted between
the recv and showing you the note (a rate-limit error, `/clear`, a
crash), the note is consumed (no longer unread) but you never saw it. The
fallback browse re-surfaces such a note on the next `/inbox` instead of
silently showing empty. mnemo retains notes after delivery (mark-read is
non-destructive), so they are always recoverable this way.

To peek without consuming at any time, pass `mark_read=false` to
`mnemo_note_recv`, or use `mnemo_note_list(inbox: "<resolved inbox>")`.

## Wait for a note (`/loop /inbox`)

For the wait-on-event case — you're blocked on something another session
will finish (a release landing, a dependency publishing) — run:

```
/loop /inbox
```

`/loop` self-paces via cache-aware `ScheduleWakeup`: it re-runs `/inbox`
on a sensible cadence until a note arrives, then injects it and lets you
continue the dependent work. mnemo does **not** long-poll; the wait
primitive lives in the harness, so a plain `mnemo_note_recv` returns
immediately with whatever is currently pending. End the loop once you've
received and acted on the note.
