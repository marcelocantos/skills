# Retro probe battery

Every SQL probe runs through `mnemo_query`. All were validated against the
live index on 2026-07-31; the shapes are known-good, not guessed.

Substitute the resolved window everywhere `-7 days` appears. Where a probe
takes a repo scope, add `AND sm.repo LIKE '%<repo>%'` to the `win` CTE
(join `session_meta sm`).

## Performance rules

`messages` has **no timestamp index** and the table is large (~10^8 rows).
Never scan it by timestamp alone. Every probe starts from the small
`session_summary` table, filters the window there, and joins `messages` on
the indexed `session_id`:

```sql
WITH win AS (
  SELECT ss.session_id
  FROM session_summary ss
  WHERE ss.last_msg >= datetime('now','-7 days')
    AND ss.session_type IN ('interactive','subagent','worktree')
)
```

Then add `AND m.timestamp >= datetime('now','-7 days')` as a residual
filter (sessions straddle the boundary). Dropping either half is a bug:
without the CTE the probe scans everything; without the residual it
includes pre-window messages from long-running sessions.

Session types: `interactive` (you and the user), `subagent`, `worktree`,
`ephemeral`. Friction probes about *user* experience use `interactive`
only. Machinery probes (tool errors, dead surface, retry loops) use all
three of the first types — most tool volume is subagents, and that is
exactly where broken machinery hides.

## Source scoping — mandatory

The index is **not** Claude-only. `session_meta.source` carries `claude`,
`codex`, and `grok` (32126 / 675 / 417 sessions as of 2026-07-31). A probe
that ignores it attributes Codex and Grok behaviour to Claude Code
instructions, which is how a retro produces a confident, wrong proposal to
edit `CLAUDE.md`.

Default every probe to `source = 'claude'`:

```sql
WITH win AS (
  SELECT ss.session_id, sm.repo, sm.source
  FROM session_summary ss
  JOIN session_meta sm ON sm.session_id = ss.session_id
  WHERE ss.last_msg >= datetime('now','-7 days')
    AND ss.session_type IN ('interactive','subagent','worktree')
    AND sm.source = 'claude'
)
```

The exception is any finding about `AGENTS.md` — shared cross-tool
directives. There, run the probe once per source and compare: a rule
obeyed under Claude and ignored under Codex is a *loading* defect (Codex
reads `~/.codex/AGENTS.md`, a hand-synced copy), not a wording defect.
Report the per-source split whenever it differs.

`source` is absent from `STABILITY.md`'s schema table — treat the live
`sqlite_master` output as authoritative over the doc.

---

## A. Machinery failure

### A1. Tool errors by tool

The single highest-yield probe. `is_error` lives on the tool_**result**
row, which carries no `tool_name` — join back to the tool_use row via
`tool_use_id` or every error aggregates under `''`.

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days')
               AND ss.session_type IN ('interactive','subagent','worktree')),
err AS (SELECT m.session_id, m.tool_use_id, m.text
        FROM win w JOIN messages m ON m.session_id = w.session_id
        WHERE m.is_error = 1 AND m.timestamp >= datetime('now','-7 days'))
SELECT u.tool_name, count(*) AS errors,
       count(DISTINCT e.session_id) AS sessions,
       substr(replace(min(e.text), char(10), ' '), 1, 160) AS sample
FROM err e
JOIN messages u ON u.tool_use_id = e.tool_use_id AND u.content_type = 'tool_use'
GROUP BY u.tool_name ORDER BY errors DESC LIMIT 30;
```

Read it as: **MCP tool errors are server defects** (file a target in that
repo); **Bash errors are workflow defects**; **Edit/Write errors are
process defects** (stale reads, non-unique `old_string`).

### A2. Error signatures for one tool

Drill-down for any tool from A1 with a meaningful count. Swap
`u.tool_name = 'Bash'` for the tool under investigation.

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days')
               AND ss.session_type IN ('interactive','subagent','worktree')),
err AS (SELECT m.session_id, m.tool_use_id, m.text
        FROM win w JOIN messages m ON m.session_id = w.session_id
        WHERE m.is_error = 1 AND m.timestamp >= datetime('now','-7 days'))
SELECT substr(replace(replace(e.text,'<tool_use_error>',''), char(10), ' '), 1, 100) AS signature,
       count(*) AS n, min(e.session_id) AS example_session
FROM err e
JOIN messages u ON u.tool_use_id = e.tool_use_id AND u.content_type = 'tool_use'
WHERE u.tool_name = 'Bash'
GROUP BY signature ORDER BY n DESC LIMIT 25;
```

### A3. Retry loops — same command repeated in one session

Six identical invocations is a poll loop, a flapping test, or an agent
stuck. All three are findings.

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days'))
SELECT m.session_id, substr(replace(m.tool_command, char(10), ' '), 1, 80) AS cmd, count(*) AS n
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.tool_name = 'Bash' AND m.timestamp >= datetime('now','-7 days')
  AND m.tool_command IS NOT NULL
GROUP BY m.session_id, m.tool_command HAVING n >= 6
ORDER BY n DESC LIMIT 20;
```

### A4. Hook and harness blocks

Blocks are the system correcting you. Each one is a rule you broke often
enough that someone mechanised the enforcement — and each recurrence means
the instruction still is not landing.

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days')
               AND ss.session_type IN ('interactive','subagent','worktree')),
err AS (SELECT m.session_id, m.tool_use_id, m.text
        FROM win w JOIN messages m ON m.session_id = w.session_id
        WHERE m.is_error = 1 AND m.timestamp >= datetime('now','-7 days'))
SELECT substr(replace(e.text, char(10), ' '), 1, 140) AS block, count(*) AS n,
       min(e.session_id) AS example_session
FROM err e
WHERE e.text LIKE '%Blocked:%' OR e.text LIKE '%was blocked%'
   OR e.text LIKE '%isolated in the worktree%' OR e.text LIKE '%not permitted%'
GROUP BY block ORDER BY n DESC LIMIT 20;
```

---

## B. User friction

### B1. Interrupts, rejections, aborts

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days')
               AND ss.session_type = 'interactive')
SELECT CASE
         WHEN m.text LIKE '%tool use was rejected%'       THEN 'permission-denied'
         WHEN m.text LIKE '%Request interrupted by user%' THEN 'user-interrupt'
         ELSE 'aborted' END AS kind,
       count(*) AS n, count(DISTINCT m.session_id) AS sessions
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.timestamp >= datetime('now','-7 days')
  AND (m.text LIKE '%tool use was rejected%'
    OR m.text LIKE '%Request interrupted by user%'
    OR m.text LIKE '%operation was aborted%')
GROUP BY kind ORDER BY n DESC;
```

Then drill into what was being *attempted* at each interrupt — the message
immediately before is the real signal. An interrupt spike in one repo is a
loud statement that the default approach there is wrong.

### B2. Corrections in the user's own words

The user is terse, so cast a wide net and expect a low hit rate. Do not
tune the patterns to raise the count — a wide net with 3 real hits beats a
narrow one with 30 false ones.

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days')
               AND ss.session_type = 'interactive')
SELECT m.session_id, m.timestamp,
       substr(replace(m.text, char(10), ' '), 1, 200) AS txt
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.role = 'user' AND m.is_noise = 0 AND m.content_type = 'text'
  AND m.timestamp >= datetime('now','-7 days') AND length(m.text) < 500
  AND (m.text LIKE 'no,%' OR m.text LIKE 'No,%' OR m.text LIKE 'no.%' OR m.text LIKE 'No.%'
    OR m.text LIKE '%that''s wrong%' OR m.text LIKE '%you were supposed to%'
    OR m.text LIKE '%I told you%'    OR m.text LIKE '%I said%'
    OR m.text LIKE '%why did you%'   OR m.text LIKE '%stop %'
    OR m.text LIKE '%don''t do that%' OR m.text LIKE '%never do%'
    OR m.text LIKE '%again%wrong%'   OR m.text LIKE '%read the%first%')
ORDER BY m.timestamp DESC LIMIT 40;
```

Every hit is read in context (`mnemo_search` with `expand: "segment"`, or
`mnemo_read_session`). Classify each as: **instruction gap** (no rule
covers it) / **instruction miss** (a rule covers it and was not followed) /
**one-off preference**. Only the first two generate proposals, and the
second generates an *enforcement* proposal, not a restatement.

### B3. Directive violations — the hard-rule audit

Cheap, mechanical, and the highest-severity class. Each pattern maps to a
numbered hard rule or a standing ban.

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days')
               AND ss.session_type IN ('interactive','subagent','worktree'))
SELECT CASE
         WHEN m.tool_command LIKE '%git reset --hard%'   THEN 'HR2 git reset --hard'
         WHEN m.tool_command LIKE 'git merge %'
           OR m.tool_command LIKE '%&& git merge %'      THEN 'HR3 non-squash merge'
         WHEN m.tool_command LIKE 'gh release create%'
           OR m.tool_command LIKE '%&& gh release create%' THEN 'HR6 release outside /release'
         WHEN m.tool_command LIKE 'sleep %'
           OR m.tool_command LIKE '%&& sleep %'          THEN 'ban: leading sleep'
         WHEN m.tool_command LIKE '%checkout -b main %'
           OR m.tool_command LIKE '%branch -M main%'
           OR m.tool_command LIKE '%switch -c main%'     THEN 'ban: main branch'
       END AS violation,
       count(*) AS n, min(m.session_id) AS example_session,
       substr(replace(min(m.tool_command), char(10), ' '), 1, 100) AS sample
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.tool_name = 'Bash' AND m.timestamp >= datetime('now','-7 days')
  AND m.tool_command IS NOT NULL
  -- exclusions: Monitor-style wait loops are the *sanctioned* pattern, and
  -- merge-base/--abort are not merges
  AND m.tool_command NOT LIKE '%do sleep%' AND m.tool_command NOT LIKE '%until %'
  AND m.tool_command NOT LIKE '%while %'   AND m.tool_command NOT LIKE '%merge-base%'
  AND m.tool_command NOT LIKE '%merge --abort%'
GROUP BY violation HAVING violation IS NOT NULL ORDER BY n DESC;
```

The anchoring (`LIKE 'x%'` / `'%&& x%'`) and the exclusion list matter: the
unanchored form matches the string inside heredocs, comments, and `printf`
payloads, which inflated `sleep` 4× and `gh release create` 8× in
validation. This probe generates **candidates**; each one is confirmed by
reading the command in context before it becomes a finding.

Companion probe — **secrets in command lines**, which is hard rule #4
territory and worth surfacing even at n=1:

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days')
               AND ss.session_type IN ('interactive','subagent','worktree'))
SELECT m.session_id, substr(replace(m.tool_command, char(10), ' '), 1, 90) AS sample, count(*) AS n
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.tool_name = 'Bash' AND m.timestamp >= datetime('now','-7 days')
  AND (m.tool_command LIKE '%PASSWORD=%' OR m.tool_command LIKE '%_TOKEN=%'
    OR m.tool_command LIKE '%API_KEY=%'  OR m.tool_command LIKE '%SECRET=%')
GROUP BY sample ORDER BY n DESC LIMIT 15;
```

Report the *shape* of any hit — `VAR=<redacted>` and the session — never
the literal value. A hit means a credential is sitting in a transcript on
disk; say so plainly and recommend rotation plus a `.env`/keychain route.

---

## C. Dead and missing surface

### C1. MCP servers: registered vs used

Pair with `claude mcp list` (Bash) for the registered set. Zero calls over
a week for a server whose tools load into every session is pure context
tax — and for a server a directive calls *mandatory*, it is a live
contradiction between the instructions and the behaviour.

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days'))
SELECT CASE WHEN m.tool_name LIKE 'mcp__%'
            THEN substr(m.tool_name, 6, instr(substr(m.tool_name, 6), '__') - 1)
            ELSE '(builtin)' END AS server,
       count(*) AS calls, count(DISTINCT m.tool_name) AS distinct_tools,
       count(DISTINCT m.session_id) AS sessions
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.content_type = 'tool_use' AND m.timestamp >= datetime('now','-7 days')
GROUP BY server ORDER BY calls DESC;
```

### C2. Skills: on disk vs invoked

Invocations arrive two ways and both must be counted, or a heavily used
slash command reads as dead:

```sql
-- Skill tool
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days'))
SELECT m.tool_skill AS skill, count(*) AS n, count(DISTINCT m.session_id) AS sessions
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.tool_name = 'Skill' AND m.timestamp >= datetime('now','-7 days')
GROUP BY skill ORDER BY n DESC;
```

```sql
-- Slash commands typed by the user. NOT entries.data_command — that field
-- is the *hook* command line ($.data.command, e.g. "python3
-- ~/.claude/hooks/…"), and it stopped being emitted after 2026-04 along
-- with all hook_progress entries. The slash command is embedded in the
-- user message text instead.
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days')
               AND ss.session_type = 'interactive')
SELECT rtrim(substr(m.text, instr(m.text, '<command-name>') + 14,
                    instr(substr(m.text, instr(m.text, '<command-name>') + 14), '<') - 1)) AS cmd,
       count(*) AS n
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.timestamp >= datetime('now','-7 days') AND m.role = 'user'
  AND m.text LIKE '%<command-name>%'
  AND instr(m.text, '<command-name>') <= 40   -- else prose *about* commands matches
GROUP BY cmd ORDER BY n DESC LIMIT 30;
```

Diff the union against `ls -d ~/.claude/skills/*/`. Unused ≠ useless — a
release skill is used when there is a release — so weight by *opportunity*:
a skill is dead only if its trigger condition occurred and it still was not
invoked. Check that with a targeted `mnemo_search` before proposing removal.

### C3. Companion-doc pull-through

`CLAUDE.md` marks several `~/.claude/*.md` files as mandatory reads before
touching a language or domain. This measures whether that actually happens.

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days'))
SELECT m.tool_file_path AS f, count(*) AS reads, count(DISTINCT m.session_id) AS sessions
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.tool_name = 'Read' AND m.timestamp >= datetime('now','-7 days')
  AND m.tool_file_path LIKE '/Users/marcelo/.claude/%.md'
GROUP BY f ORDER BY reads DESC LIMIT 40;
```

Diff against `ls ~/.claude/*.md`. For each never-read companion, establish
whether its trigger even fired in the window (e.g. `go.md` unread is only a
finding if Go files were edited):

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days'))
SELECT CASE
         WHEN m.tool_file_path LIKE '%.go'   THEN 'go.md'
         WHEN m.tool_file_path LIKE '%.py'   THEN 'python.md'
         WHEN m.tool_file_path LIKE '%.rs'   THEN 'rust.md'
         WHEN m.tool_file_path LIKE '%.cc' OR m.tool_file_path LIKE '%.cpp'
           OR m.tool_file_path LIKE '%.h'    THEN 'cpp.md'
         WHEN m.tool_file_path LIKE '%.tla'  THEN 'tlaplus.md'
         WHEN m.tool_file_path LIKE '%.sql'  THEN 'sql.md'
       END AS companion,
       count(*) AS edits, count(DISTINCT m.session_id) AS sessions
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.tool_name IN ('Edit','Write') AND m.timestamp >= datetime('now','-7 days')
  AND m.tool_file_path IS NOT NULL
GROUP BY companion HAVING companion IS NOT NULL ORDER BY edits DESC;
```

`edits ≫ 0` with `reads = 0` is a **broken trigger** — the highest-value
finding this skill produces, because it invalidates a rule the user
believes is in force.

### C4. Missing tools — searches that found nothing

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days'))
SELECT m.tool_query AS q, count(*) AS n
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.tool_name = 'ToolSearch' AND m.timestamp >= datetime('now','-7 days')
GROUP BY q ORDER BY n DESC LIMIT 30;
```

Repeated `select:` queries for the same tools are a *deferred-loading tax*
finding: those tools should be resident, or the workflow should be wrapped
in a skill that loads them once.

### C5. mnemo's own workaround detector

Run `mnemo_discover_patterns` with `days` set to the window. It detects
transcript access that bypasses mnemo (direct JSONL reads, greps over the
projects directory) and query shapes repeated across ≥3 sessions —
literal evidence for "this deserves a saved template or a dedicated tool".
Repeated query shapes are evidence that a shape deserves a first-class
affordance — propose one in the report. (mnemo's saved-query-template
tools were retired in 🎯T143.1: defined and executed zero times between
them in four months.)

---

## D. Cost and shape of work

### D1. Token spend by repo

`mnemo_usage` with `group_by: "repo"` and `group_by: "model"`. Look for
disproportion, not absolutes: a repo consuming a third of the week's tokens
for one merged PR is a workflow finding. Cross-check any surprise against
the `reference_claudia_fleet_token_burn` memory — background fleets in
detached tmux are the known invisible-drain mechanism.

### D2. Bash command-shape census

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days'))
SELECT trim(substr(replace(m.tool_command, char(10), ' '), 1, 30)) AS head, count(*) AS n
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.tool_name = 'Bash' AND m.timestamp >= datetime('now','-7 days')
  AND m.tool_command IS NOT NULL
GROUP BY head ORDER BY n DESC LIMIT 40;
```

Read for three things: (a) long incantations repeated across sessions →
script or skill candidates; (b) `cd <abs-path> && …` prefixes → agents
fighting the working directory, or absolute paths that a worktree agent
cannot use; (c) hand-rolled `python3 -c` one-liners doing what a dedicated
CLI or MCP tool already does.

### D3. Rework — files churned across sessions

```sql
WITH win AS (SELECT ss.session_id FROM session_summary ss
             WHERE ss.last_msg >= datetime('now','-7 days'))
SELECT m.tool_file_path AS f, count(*) AS edits, count(DISTINCT m.session_id) AS sessions
FROM win w JOIN messages m ON m.session_id = w.session_id
WHERE m.tool_name IN ('Edit','Write') AND m.timestamp >= datetime('now','-7 days')
  AND m.tool_file_path IS NOT NULL
GROUP BY f HAVING sessions >= 3 ORDER BY edits DESC LIMIT 25;
```

Many sessions touching one file means the design is unsettled, the file is
a god-object, or successive agents are undoing each other. Distinguish by
reading two of the sessions before writing the finding.

### D4. Subagent yield

```sql
SELECT ss.session_type, count(*) AS sessions,
       sum(ss.substantive_msgs) AS msgs,
       round(avg(ss.substantive_msgs), 1) AS avg_msgs
FROM session_summary ss
WHERE ss.last_msg >= datetime('now','-7 days')
GROUP BY ss.session_type ORDER BY sessions DESC;
```

A large population of subagents with tiny message counts means fan-out is
being spent on work too small to justify the spawn cost; the inverse means
delegation is under-used relative to the standing bias in `delegation.md`.

---

## E. Corroborating sources

Not everything is in the transcript index. Pull these before writing the
report:

- `mnemo_recent_activity` — where the week's work actually was, so findings
  can be weighted by exposure.
- `mnemo_decisions` — decisions made in the window; a decision that
  contradicts a standing instruction is a finding either way.
- `mnemo_divergence` — stale derived state (uncompacted sessions,
  un-ingested transcripts). A large gap means *this retro's own evidence is
  incomplete*; say so in the report rather than reporting a clean bill.
- `mnemo_permissions` — ready-made `allowedTools` suggestions from actual
  usage, for any permission-denial finding in B1.
- `bullseye_portfolio` / `bullseye_query view=summary` — targets that
  churned without converging.
- `git -C ~/.claude log --oneline --since=<window>` — instruction and skill
  changes made *during* the window; a finding whose fix already landed
  mid-week is not a finding.
