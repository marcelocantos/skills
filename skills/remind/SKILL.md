---
name: remind
description: >
  Schedule a reminder that fires as a Slack DM at a future time.
  Claude-only: requires claude.ai RemoteTrigger. Under Grok, refuse and
  suggest Calendar or running /remind in Claude. Also lists and cancels
  existing reminders.
user-invocable: true
---

# remind

## Grok / non-Claude harness

**This skill does not work in Grok Build.** It depends on Claude.ai
`RemoteTrigger` routines and Slack MCP auth in the Claude routine
context. If invoked under Grok (or any harness without `RemoteTrigger`):

1. **Stop.** Do not invent a local cron substitute that pretends to be this skill.
2. Tell the user options: run `/remind` in **Claude Code**, or schedule a
   **Google Calendar** event (managed connector), or use a short-horizon
   in-session scheduler if the harness has one.
3. Offer to create a Calendar event if they want a durable ping from here.

## Claude Code

Set a future reminder (or recurring reminder) that fires as a Slack
direct message to Marcelo. Built on the `RemoteTrigger` MCP tool — the
reminder runs as a claude.ai routine on Anthropic's servers, so it
fires whether or not your local Claude session is open.

For the simple case ("ping me in a month to check upstream X") the
fired routine just sends a DM. For the active case ("in a month, check
upstream X and tell me if there's anything to pull") the routine can
do real work first and report findings — the user's `<what>` is passed
verbatim into the routine's prompt as its mission.

## Arguments

```
/remind <when> <what>            # schedule a new reminder
/remind list                     # show active reminders
/remind cancel <id-or-substring> # cancel a reminder
```

If invoked with no arguments, prompt for the missing pieces. Don't
guess.

### `<when>` examples

- Relative: `in a month`, `in 3 weeks`, `in 2 hours`, `tomorrow`
- Absolute: `2026-07-01`, `next Monday`, `June 15`
- With time: `tomorrow at 5pm`, `next Monday at 09:30`
- Recurring: `every Monday at 9am`, `weekly`, `monthly on the 1st`,
  `daily at 8am`

If `<when>` has no time-of-day component, default to **09:00 local
time** (Marcelo is in Sydney — AEST/AEDT). Off-zero minute drift not
needed; RemoteTrigger schedules in absolute UTC and is not coordinating
with a fleet the way CronCreate is.

### `<what>`

Free-form prose describing what to remind about. Two flavors:

- **Passive ping** — short message, ends up in the DM verbatim.
  Example: `check whether upstream alacritty has a 0.16 release`.
- **Active investigation** — multi-step instructions for the routine
  to follow before reporting. Example: `read git log on
  danielpaulus/go-ios since today, check for any RSD-related fixes,
  and DM me with a one-line verdict and links`. The skill detects
  multi-step language (imperative verbs like "check", "read", "look",
  "compare", "search") and passes the instructions through as the
  routine's mission.

When in doubt, treat `<what>` as the routine's mission and let the
routine decide how much investigation to do before sending the DM.

## Constants

These values are stable and baked into routine bodies. Update them
here if they ever change.

- **Marcelo's Slack user ID**: `U033G8GU0` (DMs use the user ID as the
  channel ID).
- **Slack MCP connector UUID**: `6d163723-35e8-44bc-ba25-5fe6b52cad17`.
- **Slack MCP URL**: `https://mcp.slack.com/mcp`.
- **Default routine environment ID**: `env_0183N2rUyRZCqoV3QrR6yGsG`.
- **Default routine model**: `claude-haiku-4-5` for passive pings (cheap,
  fast — all it does is send a message), `claude-sonnet-4-6` for active
  investigations.
- **Routine name prefix**: `[remind]` — used to filter our own routines
  when listing and cancelling.

## Steps

### 1. Branch on subcommand

- `list` → step 6.
- `cancel <X>` → step 7.
- Anything else → treat as `<when> <what>` and continue.

### 2. Parse `<when>` to an absolute fire time

Use the current date from session context (today is provided in the
prompt). Compute the absolute fire time in **Sydney local time**, then
convert to UTC for `run_once_at`.

For relative offsets ("in a month"), add to today's date naively
(month arithmetic: month+1, clamp day to month length).

For recurring expressions, build a 5-field cron expression in **UTC**.
Translate "9am Sydney" to the correct UTC hour for the current season
(AEDT = UTC+11, AEST = UTC+10). If the recurrence crosses a DST
boundary the cron will drift by one hour for half the year — call this
out to the user; if it matters they can split into two cron rules.

If the parsed time is in the past, stop and ask the user.

### 3. Build the routine prompt

Template — substitute the variables, keep the rest verbatim:

```
You are a one-shot reminder agent. Marcelo asked on <TODAY_DATE> to be
reminded: <WHAT>

Your mission:

<WHAT>

When you're done (or immediately, if the reminder is a passive ping
with nothing to investigate), send Marcelo a Slack DM summarising what
you found, using the slack_send_message MCP tool with:

- channel: U033G8GU0
- text: <markdown message; keep under ~10 lines, no greetings, no
  signoff, no emoji unless naturally warranted by the content>

After the DM is sent, stop. Do not loop, do not open PRs, do not edit
files unless the mission explicitly asks for it.
```

For **passive pings** (no investigation required), shorten to:

```
Send Marcelo a Slack DM with the following text, using
slack_send_message with channel=U033G8GU0:

<WHAT>

That's your only job. Stop after the DM is sent.
```

The shorter form lets the routine run on Haiku.

### 4. Build the RemoteTrigger body

```json
{
  "name": "[remind] <SHORT_SUMMARY_OF_WHAT_max_60_chars>",
  "enabled": true,
  "persist_session": false,
  "cron_expression": "<CRON_OR_EMPTY>",
  "run_once_at": "<UTC_ISO8601_OR_OMIT>",
  "job_config": {
    "ccr": {
      "environment_id": "env_0183N2rUyRZCqoV3QrR6yGsG",
      "events": [
        {
          "data": {
            "message": {
              "content": "<ROUTINE_PROMPT_FROM_STEP_3>",
              "role": "user",
              "parent_tool_use_id": null,
              "session_id": "",
              "type": "user"
            }
          }
        }
      ],
      "session_context": {
        "allowed_tools": ["Bash", "Read", "Glob", "Grep"],
        "model": "<claude-haiku-4-5 OR claude-sonnet-4-6>"
      }
    }
  },
  "mcp_connections": [
    {
      "connector_uuid": "6d163723-35e8-44bc-ba25-5fe6b52cad17",
      "name": "Slack",
      "permitted_tools": [],
      "transport_type": "http",
      "url": "https://mcp.slack.com/mcp"
    }
  ]
}
```

Rules for cron vs run_once_at:

- One-shot: set `run_once_at` to the UTC ISO timestamp, leave
  `cron_expression: ""`.
- Recurring: set `cron_expression` (5-field, UTC), omit
  `run_once_at`.

If the active mission needs to read a specific repo, add a
`sources` entry under `session_context`:

```json
"sources": [
  { "git_repository": { "url": "https://github.com/<owner>/<repo>" } }
]
```

Only add `sources` when the mission text references a repo by name or
URL. Don't auto-attach the current working repo — reminders often
outlive the working directory.

### 5. Create the routine and confirm

Call `RemoteTrigger(action="create", body=<the body>)`. The response
includes the new `id` and a claude.ai URL. Relay both to the user:

```
✓ Reminder scheduled for <human-readable local time> (<UTC timestamp>).
  ID: <trig_…>
  Manage at: <claude.ai URL>
```

The server reports back its parsed `next_run_at` — quote it so the
user can sanity-check that you parsed the time correctly.

### 6. List

Call `RemoteTrigger(action="list")`. Filter the `data` array to
entries where `name` starts with `[remind]` AND `enabled: true`. For
each, print one line:

```
<id>  <next_run_at local>  <name without [remind] prefix>
```

Sorted by `next_run_at` ascending. If none, say so.

### 7. Cancel

Look up the trigger:

- If the arg looks like a full ID (`trig_…`), use it directly.
- Otherwise, list active `[remind]` routines and find one whose name
  substring-matches the arg. If multiple match, list them and stop —
  don't guess.

Call `RemoteTrigger(action="update", trigger_id=<id>, body={"enabled": false})`
to cancel. (The API has no destructive delete in this skill's surface;
disabling is equivalent for our purposes.)

Confirm: `✓ Cancelled '<name>'.`

## Examples

### Passive ping in a month

```
/remind in a month check if alacritty has a 0.16 release
```

→ Creates a Haiku routine that fires once, DMs:

> check if alacritty has a 0.16 release

### Active investigation in a month

```
/remind in a month read git log on danielpaulus/go-ios since 2026-05-20,
look for any RSD-related fixes, and tell me whether to rebase my fork
or open the PR as-is
```

→ Creates a Sonnet routine that fires once, performs the
investigation, then DMs a verdict.

### Recurring weekly

```
/remind every Monday at 9am tell me what bullseye targets are on the
frontier across all my repos
```

→ Creates a Sonnet routine that fires weekly. **Note**: warn the user
about the 7-day expiry caveat if RemoteTrigger has one (CronCreate
does — check whether RemoteTrigger does too; if unknown, mention that
recurring routines may need periodic re-creation).

## Notes

- **Hard floor: 5 minutes from now.** RemoteTrigger has scheduling
  granularity that doesn't reliably handle "in 30 seconds". If the
  user wants sub-minute timing, use `CronCreate` with `recurring:
  false` instead — it fires in-session, no Slack involved, and is
  fine for short horizons.
- **No way to edit a routine in place via this skill** — cancel and
  re-create.
- **The Slack MCP must be authenticated in the routine's context.**
  Routines inherit Marcelo's MCP auth. If a routine fires and the DM
  fails with auth errors, point the user at the Slack reconnect flow
  in claude.ai settings.
- **Don't use this for "remind me in 5 minutes" workflow tasks** —
  that's what `ScheduleWakeup` and `CronCreate` are for. `/remind` is
  for *days-to-months* reminders that need to survive Claude restarts.
