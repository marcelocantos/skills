---
name: vcheck
description: V-boundary checker. Before a target is achieved, demoed, or attested, an independent fresh-context agent audits the claim against the oracle — did V run, on the product path, and does the claim trace to the oracle's output? Returns PASS or BLOCK with the exact command and output relied on. Refuses to pass on executor say-so.
user-invocable: true
---

# /vcheck — V-boundary checker

The standing form of the discipline gate in
[`oracle-first`](~/.claude/skills/oracle-first/SKILL.md) ("Oracle, code,
and verification are three nodes"): **V — the oracle run against the code,
green — is the achievement gate, not C.** This skill makes the gate
independent. The executor that wrote the code does not adjudicate its own
completion; a checker with no shared context does, and it may only say
PASS when it can point at oracle output.

Why an independent party: every false completion on record (HMS 134/134,
RustUML "0 failures" on the oracle-assisted tier, pageflip, tern) was
sincere. The executor's context is the problem, not its honesty.

## Usage

```
/vcheck T131                                  # achieved target: audit the stored attestation
/vcheck T131 --cwd ~/work/github.com/o/r      # explicit repo
/vcheck T12.3 --claim "go test ./... ok at 3f1c2ab; TestFoo_* green"
                                              # pre-achieve: audit the claim you are about to attest
/vcheck T12.3 --claim-file <path>             # same, claim text from a file
```

Target ids accept the 🎯 prefix. `--cwd` defaults to the current directory.

## The three questions

| | Question | PASS needs |
|---|---|---|
| Q1 | Did V run? | An oracle covering the decidable acceptance clauses ran green — by the checker's own re-run, or as `tool_result` output in the transcript. |
| Q2 | Against the product path? | The oracle exercises the shipped entry point and asserts the clause's property — not an instrumented tier, an adjacent property, or an executor-owned denominator. |
| Q3 | Does the claim trace to the oracle's output? | The attestation names the oracle (command, tests, harness, live check) and what it produced, and the checker's re-run agrees. |

All three YES → **PASS**. Anything else → **BLOCK**, with the exact
command whose cited green output would flip it.

**Say-so rule.** Attestation prose, commit messages, docs, PR bodies, and
"tests pass" without output are not evidence. A claim that describes the
work instead of citing the oracle is BLOCK even when the checker's own run
is green: Q3 fails, and the "To pass" line tells the executor what to cite.

**Unit-of-progress rule.** A verification-campaign target (forms, goldens,
scenarios, coverage, "N of M") passes only on *activated green evidence*
counted from oracle output. Artifact counts — captures taken, goldens
written, comparators built — are BLOCK on their own.

## Execution (root session)

1. Resolve `cwd`, `id`, and the claim source. For an inline `--claim`,
   write the text to `<scratchpad>/vcheck-<id>.claim.txt`.
2. Gather the bundle:
   ```
   ~/.claude/skills/vcheck/gather.sh <id> --cwd <dir> [--claim-file <file>] > <scratchpad>/vcheck-<id>.bundle.md
   ```
   Invoke the path directly (it is `chmod +x`). It needs `bullseye` and
   `git`; the transcript sections degrade to `(unavailable: …)` without
   mnemo. If it exits non-zero, relay the error and stop.
3. **Spawn the checker with a fresh context.** `Agent` with
   `subagent_type: general-purpose`, `model: opus`, prompt:
   ```
   Read and execute ~/.claude/skills/vcheck/checker.md.
   Bundle: <scratchpad>/vcheck-<id>.bundle.md
   Target: <id>
   cwd: <dir>
   Return the verdict block verbatim.
   ```
   Never use `subagent_type: fork` here — a fork inherits the executor's
   context, which is exactly the independence the gate exists to remove.
   Do not pass the executor's own summary, diff, or reasoning; the bundle
   is the whole brief.
4. **Relay the verdict block verbatim.** Do not soften, summarise, or
   argue with a BLOCK. If the root session is itself the executor, that
   is the moment the gate is for.

## Acting on the verdict

- **PASS** → proceed to achieve. Put the checker's oracle line into the
  attestation so the ledger carries the trace:
  `… vcheck PASS <date>: <command> → <outcome>`.
- **BLOCK** → do **not** call `bullseye_commit op=achieve`,
  `bullseye_retire`, or demo the capability. Then one of:
  1. run the oracle the verdict names, fix what it finds, re-attest citing
     its output, and run `/vcheck` again;
  2. the uncovered clauses are genuinely glance-gated → split them into a
     downstream sub-target (`convergence.md`, "Acceptance criteria: split
     by verification class") and re-check the decidable remainder;
  3. user override: the user may achieve anyway, but name the gate being
     skipped and record `vcheck BLOCK overridden by user` in the
     attestation (see `gates.md`, "User override").
- **Attestation shopping is not an option.** Re-running `/vcheck` with a
  reworded claim and no new oracle run is the failure mode this skill
  exists to stop. A new run needs new evidence.

## Hook points

`/vcheck` fires at the V boundary — the moment before a completion claim
becomes a ledger fact or a demo. The skills that own those moments call
it:

| Moment | Owner | Wiring |
|---|---|---|
| Achieve at the end of `/cv` Execute-now work | `cv/SKILL.md` | Before `bullseye_commit op=achieve`, run `/vcheck <id> --claim "<attestation>"`; achieve only on PASS. |
| `/cv` auto-fix "retire targets that describe themselves as achieved" | `cv/SKILL.md` | The context line is say-so. Run `/vcheck <id>`; retire on PASS, otherwise leave it on the frontier with the verdict in the report. |
| `/target retire` | `target/SKILL.md` | `/vcheck` first; retire only on PASS. |
| `/commit` with a ledger diff that flips a target to `achieved` | `commit/SKILL.md` | If the new attestation carries no `vcheck PASS` line, run `/vcheck` before committing; a BLOCK holds the ledger change out of the commit. |
| `bullseye_commit op=achieve` (proposed, not applied — bullseye source is out of scope) | bullseye | A `vcheck:` field on achieve, required by a profile flag, whose value is the checker's oracle line; absent field → the tool refuses the achieve the way it refuses an empty attestation today. |

Fan-out workers never call `/vcheck` on their own targets and never
achieve; they commit and stop (`fan-out.md`). The parent runs `/vcheck`
per target during assembly.

## Cost and proportionality

One opus agent, typically one or two oracle runs, bounded at ten minutes
per run. For a class-1 target whose attestation already cites the exact
command and its output, the checker's whole job is to re-run it — cheap.
The expensive cases are the ones the gate exists for: a claim with no
runnable oracle behind it, where the checker has to establish that
nothing ran.

## Files

- `checker.md` — the checker agent's brief (phases, evidence rules,
  verdict format).
- `gather.sh` — deterministic evidence bundle: target record, claim,
  cited refs, commits, diff files, cited-test locations, oracle inventory,
  transcript rows for the achieve call.
- `mnemo-sql.sh` — direct-to-daemon `mnemo_query` fallback when the
  session's MCP route to mnemo is down.

## Drill

Drilled 2026-09-06 on two already-achieved targets in cold repos, evidence
under `~/think/burst-2026-09/vcheck-drill/` (bundles, verbatim verdicts,
reproduction steps).

| Case | Target | Attestation shape | Verdict |
|---|---|---|---|
| A | 🎯T23, ytt @ 5e9f0d2 | cites `bats 73/73`, three named cases, a SHA, live-ledger counts | **PASS** — checker re-ran `make test-scripts` at the cited SHA (73/73, exit 0) and at HEAD (78/78) |
| B | 🎯T133.2, spyder @ 39562150 | prose only: names files and a constant map, no command, no output | **BLOCK** — Q3 NO |

Case B is the one that matters: the checker's own `go test
./internal/ship/...` was green (Q1 YES) and it still blocked, because the
claim cites no oracle and one acceptance clause (multi-alias `play_upload`)
is unaddressed. Green code is not a green claim.

The drill also found and fixed a `gather.sh` defect: the
`# transcript-achieve` query matched any tool call mentioning the id and
"attestation", pulling in an unrelated agent report, a doc write, and the
drill's own scouting shell call. It now also requires "achieve" and excludes
shell/file/message tool names.

## Skill improvement

After a real BLOCK, ask whether the executor could have known: if the
attestation format itself invited say-so, propose the fix to
`oracle-first` or the bullseye attestation guidance rather than adding
rules here. A checker that grows heuristics is a checker that can be
gamed; keep it asking the three questions.
