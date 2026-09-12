# Instrument error

*Companion to [`SKILL.md`](~/.claude/skills/oracle-first/SKILL.md) rule 17
and [`honesty-ratchet.md`](~/.claude/skills/oracle-first/honesty-ratchet.md).*

**The mode: attributing your own measurement error to the system under
test.** You run a check, you see a bad result, and you report a defect in
the thing you were checking. The defect is in how you measured.

This is not a Goodhart mode and the ratchet does not catch it. The Goodhart
modes are about a measure being gamed — the gap between the number and
product truth gets found and exploited under completion pressure. This one
runs the other way: the number is fine and *the reading* is wrong. Nobody is
cutting a corner. The reporter is being diligent, which is exactly the
problem — **you only generate these errors while actively checking things.**
An agent that verifies nothing never makes this mistake.

It is worth its own doctrine because of what a false defect report costs. It
is not a wasted check. It sends other people to fix code that works, it
impeaches a tool that was doing its job, and — worst — when it lands in a
report or a ledger attestation it becomes a fact that later readers inherit.
A false *green* is caught by the next oracle run. A false *red* about
somebody else's tool can sit uncorrected for a long time, because nobody
re-runs a check that already "found" something.

## Worked examples

Three from one burst (2026-09), all by agents who were mid-verification.

### 1. Exit status read through a pipe

    python3 drill.py 2>&1 | tail -15; echo "exit=$?"

Reported: "the drill prints failure and exits 0, so it cannot gate
anything." That was escalated as more serious than the actual bug, because a
self-test that exits 0 on failure makes every future green meaningless.

Actual: `$?` after a pipeline is the exit status of `tail`, which succeeded.
The drill exited 1 the whole time, correctly.

**Second check:** run the command with no pipe and read `$?` directly, or use
`${PIPESTATUS[0]}`, or redirect to a file and inspect afterwards.

    python3 drill.py > /tmp/out 2>&1; echo "exit=$?"

Two agents in the same burst made this identical error independently. In a
shell, any construct between the command and `$?` — a pipe, a `tee`, a
subshell, a trailing `|| true` — is an instrument in the path.

### 2. Test run from the wrong module directory

Reported: a build failure attributed to a colleague's branch.

Actual: the test was invoked from a directory where the module's compiled
dependency had not been built, so the linker failed on a missing archive.
The branch was fine; the working tree was not primed.

**Second check:** run the project's own documented gate command from the
project root before concluding anything about the code. If the failure is in
linking or resolution rather than in an assertion, suspect the environment
first. Build, then test, then attribute.

### 3. Tool-call serialization leaking into a value

Reported: "the ledger tool rejects every `context` value with 'contains
tool-call envelope marker' — a real bug that forces substance elsewhere."

Actual: the *client* was leaking XML tool-call syntax into the parameter
value. The server's guard read the value it actually received, found
`<parameter ` inside it, and refused with an error naming the exact marker.
The tool was working precisely as designed, and its message said so.

**Second check:** re-send the identical value through a cleanly formed call.
If it succeeds, the value was never the problem. Also: **read the error
message as evidence.** It named the marker it found. A tool that reports
*what* it saw is handing you the discriminator for free.

## The rule

**Before attributing a failure to the system under test, reproduce it by a
second route that does not share your instrument.**

"Does not share your instrument" is the load-bearing part, and it is the
step people skip — re-running the same command in the same shell is not a
second route. It shares every layer that could be lying. Change the layer
you suspect:

| Your reading came through | Second route |
|---|---|
| A shell pipeline (`\|`, `tee`, subshell, `&&`) | Run bare; read `$?` directly or `${PIPESTATUS[0]}` |
| A working directory or env assumption | Absolute paths from the project root; print `pwd` and the env vars in the same command |
| A build tree or cache | Clean rebuild, or build from source, before you trust the binary |
| A client/serialization layer | Re-send the same value through a differently shaped call |
| A wrapper script or harness | Invoke the underlying command directly |
| A summarised output (`tail`, `head`, `grep`) | Read the whole output, or the exit code, not the excerpt |

Three practical corollaries.

**Read the error text before theorising.** Tools that name what they saw
(`unrecognized token: "{"`, `contains marker <parameter `, `no such file
libfoo.a`) have already told you which side the fault is on. A message about
*your input* is not a message about *its behaviour*.

**Prefer the failure mode that explains the whole observation.** In example
1, "the tool has a bug" explains the exit code but not why the tool's author
had seen it work. "I measured the wrong process" explains both.

**A defect in someone else's tool needs a higher bar than one in your own.**
You can fix your own code on a hunch and the loop corrects you. A report
about another agent's work, another repo, or a shared tool leaves your hands
and becomes someone else's premise. Spend the second check.

## The authoring twin: a gate whose status is not what it gates

Instrument error has a twin on the *writing* side. The same confusion that
makes you misread an exit status makes you write a gate that cannot produce
one. `go test ./... | tail -20 && echo "✓ tests"` takes `tail`'s status, so
the recipe prints its tick over a failed suite and exits 0 — and every later
citation of "gate green" inherits a fact that was never checked.

This is worse than the reading error, because a misread dies with the
session while a hollow gate keeps manufacturing false evidence for everyone
who cites it. In the 2026-09 fleet audit it was found live in five repos,
and in one of them a "make bullseye green" had already been recorded in the
ledger as verification.

Rules and correct forms: [`bash.md`](~/.claude/bash.md), "A gate's exit
status must be the thing it gates". The one that catches people: **Make
recipes do not inherit `set -o pipefail`.**

The discipline is the same in both directions. **Plant a failure and watch
the gate go red before you trust it** — a gate nobody has seen fail is a
gate nobody knows works.

## The mirror case

Do not overcorrect into disbelieving every red. Instrument error has a twin
that is a *real* defect: **the instrument that is stale rather than wrong.**
A cached build serving old objects, a committed binary that no longer matches
its source, a fixture locked before a schema change — these produce readings
that are genuinely false, and the fault is genuinely in the system.

The same second route settles both. In the burst above, a checker auditing a
harness rebuilt its binary from source rather than trusting the committed
one, precisely because a stale binary is how an instance appears green
against code that no longer produces it. That is the identical discipline
reaching the opposite verdict.

The rule is not "doubt yourself." It is: **establish which side of the
instrument the fault is on, before you name it in a report.**

## The adjacent mode: a correct signal read as a stronger claim

Everything above assumes the instrument misled you. This one is different and
the doctrine as written would not have caught it: **the output was accurate,
and the claim drawn from it was stronger than the output supports.**

Nothing is broken. There is no second route that disagrees, because the first
route was right. What fails is the inference — a true statement about a narrow
thing gets read as a true statement about a wider thing. That makes it harder
to defend against than instrument error, where something eventually contradicts
you.

Three instances from one burst (2026-09), all inside a single investigation
into ledger data loss.

### 1. A summary read as a complete account

A ledger tool reported `changed: <one id>` after a write. That was accurate: one
target was named by the caller and one target was patched. Fifteen records
changed on disk — the write also stripped a field from fourteen others as a side
effect.

The line was not lying. It was answering "what did you ask me to change", and it
was read as "what changed".

**Second route:** read the diff, not the summary. The written artifact is the
account of what changed; a tool's own report of its work is a claim about
intent.

An agent did read it correctly at the time, noted the extra records in its
report, judged them stale and moved on — the summary had told it only two
things changed, so "stale leftovers" was the reasonable read of the rest.
Accurate output set up a wrong inference in a diligent reader.

### 2. "Nothing to commit" read as "committed"

Reconciling which of two agents had landed a fix, I claimed a commit I had not
made. My own transcript contained the disproof:

    nothing to commit, working tree clean

That is the version-control system stating plainly that the commit did not
happen. The next line was a log entry showing the expected subject and a
matching hash — another agent's commit, landed seconds earlier. I read the
second line as confirming the first had succeeded.

Not a missing check. A check that ran, reported correctly, and was read past,
because the state I expected was on the screen.

**Second route:** the reflog. One command, per-worktree, and it answers
authorship directly rather than by inference from adjacent output.

### 3. A count difference read as loss

Comparing a branch's records against the mainline showed 17 fewer on one repo,
29 on another, 12 on a third. Reported as ~70 lost records across four
repositories.

Three of the four were not loss. Those branches were 31, 174 and 27 commits
*behind* the mainline, so they predate the records the mainline had since
gained. Fewer entries on an older branch is what you would expect.

The subtraction was correct. It just does not mean "loss" without knowing the
ancestry of the two things being subtracted.

**Second route:** ask whether the mainline is an ancestor of the branch before
comparing counts at all. Where neither ref is an ancestor of the other, the
honest verdict is **"cannot compare by count"**, not a number.

    git merge-base --is-ancestor <mainline> <branch>

One repository passed that gate and its shortfall was real. Without the gate,
the report would have named four, one of them a repo someone was actively
working in.

### What this costs, and what can be fixed

Only the first instance is fixable in code, and it was fixed — a tool that
reports what it changed rather than what it was asked to change removes that
inference entirely.

The other two are not fixable in code. Nothing can stop a reader taking a true
"nothing to commit" and believing the adjacent line instead, or taking a true
subtraction and calling it loss. **A tool that reports truthfully is necessary
and not sufficient.** The reader still has to hold the output to what it
actually claims.

### The habit

Ask of any signal you are about to build a claim on: **what exactly is this
output a statement about?** Then check that your claim is not wider than the
answer.

| The signal says | It does not say |
|---|---|
| What the tool was asked to do | What the tool did |
| A command's own status | The status of a command it invoked, or one that ran nearby |
| Two artifacts differ by N | Which direction the difference came from, or why |
| A check passed | That the check was capable of failing |
| Nothing was reported | That nothing happened |

"Check authorship" and "check ancestry" are the same habit at two sites, which
is why neither transfers on its own. The transferable form is the question
above.

One warning from the third instance: **a method that is correct by accident is
not correct.** A parallel sweep of the same data avoided all three false
positives — but only because those three repositories happened to be checked
out on the mainline and were therefore never compared. Same conclusion, no
method behind it. Had the accident not held, it would have produced the same
false report. When a result comes out right, check that the method would have
caught the wrong answer too.

## When you get it wrong anyway

Say so plainly, early, and name the instrument. A correction that arrives as
"I was wrong, here is what I actually measured" is cheap. A correction that
never arrives leaves a false fact in a report or an attestation, where it
outlives the session.

If the false report already reached a ledger, fix the record, not just the
conversation — and if it reached another agent, tell them directly, because
they may already be acting on it.
