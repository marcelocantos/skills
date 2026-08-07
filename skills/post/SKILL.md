---
name: post
description: Post a cross-session inbox note to another repo/session via mnemo (a thin wrapper over mnemo_note op=post).
user-invocable: true
---

Leave a directory-addressed inbox note for another agent session (Grok
or Claude) to pick up, backed by the mnemo MCP server (🎯T65). This is
the producer half of the inbox primitive; the consumer reads it with
`/inbox`.

Usage: `/post <inbox> <body>`

- `<inbox>` — the recipient **directory** (usually a repo root). It may
  be absolute (`/Users/me/work/ytt`) or relative to *this* session's
  initial working directory (`../ytt`). A leading `~` is not allowed
  (shell home-expansion is ambiguous). The directory must exist; a
  non-existent inbox is a clear error and posts nothing.
- `<body>` — the note text (the rest of the line). Quote-free; everything
  after the inbox is the body.

Call:

```
mnemo_note(op: "post", inbox: "<inbox>", body: "<body>")
```

`from_session` and `from_repo` are stamped automatically from your MCP
connection identity — don't pass them unless overriding.

If a relative `<inbox>` errors with "the calling session's cwd is
unknown", the daemon hasn't bound this MCP connection to its session
yet. Establish the binding once via the `mnemo_self` nonce dance (call
`mnemo_self` with no argument, emit the returned nonce in your reply so
it is ingested, then call `mnemo_self` again with that nonce) and retry —
or pass an absolute inbox path, which never needs the binding.

On success, report the note id and the canonical inbox the daemon
resolved (it collapses `./..`, resolves symlinks, and requires the
directory to exist, so the stored inbox may differ in spelling from what
you typed). Tell the user the recipient can read it with `/inbox` (or
`/loop /inbox` to wait for it).

If a mnemo tool errors (e.g. connection refused), the daemon isn't
running — tell the user to start it (`brew services start mnemo`).
