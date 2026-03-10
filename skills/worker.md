---
description: "Manage preemptive background workers via a broker for zero-latency task dispatch"
user-invocable: true
---

# Worker — preemptive background agent pool

This skill manages a pool of background worker agents via a Go broker
at `/Users/marcelo/think/claude-broker/claude-broker`. Workers connect
to the broker over a Unix socket and block until work arrives — zero
dispatch latency. The broker shadows the session transcript so workers
receive conversation context automatically.

The broker binary is at: `/Users/marcelo/think/claude-broker/claude-broker`
Default socket: `/tmp/claude-broker.sock`

## Usage

- `/worker` or `/worker start` — start broker + spawn 2 opus + 2 sonnet workers
- `/worker spawn [opus|sonnet]` — add a worker to the pool
- `/worker send [--model opus|sonnet] <task>` — dispatch work
- `/worker status` — check pool size by model
- `/worker stop` — shut down the broker

## Subcommands

### start

1. Find the current session transcript:
   ```bash
   ls -t ~/.claude/projects/$(echo "$PWD" | tr '/' '-')/*.jsonl | head -1
   ```
2. Start the broker with shadow mode:
   ```bash
   /Users/marcelo/think/claude-broker/claude-broker serve \
     --transcript <path> --context 30 2>&1 &
   ```
3. Wait 1-2 seconds, then spawn 4 workers in parallel:
   - 2 × opus (use `model: "opus"` on the Agent tool)
   - 2 × sonnet (use `model: "sonnet"` on the Agent tool)
4. Confirm: "Broker started, pool: 2 opus + 2 sonnet."

### spawn

Args: optional model name (default: `opus`).

Spawn a **background** agent with the matching `model` parameter and
this prompt (substitute MODEL for the actual model name):

```
You are a preemptive worker agent. Wait for work, then execute it.

1. Run: /Users/marcelo/think/claude-broker/claude-broker worker --model MODEL --timeout 590s
   Use a 600000ms bash timeout.
2. If the command exited with no output (timeout or shutdown), return
   "Worker expired."
3. If you received data on stdout, that is your task. It may be
   preceded by a CONVERSATION CONTEXT section — use it to understand
   the task. Execute the task fully using all tools available to you.
   Work in /Users/marcelo/think or whatever directory the task
   specifies.
4. Return a concise summary of what you did and any outputs.
```

After spawning, confirm: "MODEL worker added to pool."

### send

1. Parse args: `--model opus|sonnet` (optional) and the task text.
   If no `--model`, default to `opus`.
2. Dispatch via:
   ```bash
   /Users/marcelo/think/claude-broker/claude-broker dispatch --model MODEL '<task>'
   ```
3. If `OK` — tell the user: "Dispatched to MODEL. Results incoming."
4. If `NO_WORKERS` — tell the user, spawn a worker of that model,
   and retry.
5. **On receiving the worker's result**: present it to the user and
   **immediately spawn a replacement worker of the same model** so
   the pool stays warm.

### status

```bash
/Users/marcelo/think/claude-broker/claude-broker status
```

### stop

```bash
pkill -f "claude-broker serve"
rm -f /tmp/claude-broker.sock
```
