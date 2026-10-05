---
name: stability
description: >
  Update one repo's STABILITY.md onto the current 1.0 approach, or, once
  it is current, review that contract and tell the owner what their
  `## 1.0 judgment` has to cover. Use for /stability, a stability-catalogue
  update, retiring a settling clock or feature-freeze, gap labels, or
  "is this ready to judge for 1.0?". The v1.0.0 cut stays /release.
user-invocable: true
---

# stability

Maintains one repo's public-contract notes, then tells the owner what
those notes ask them to weigh and what their `## 1.0 judgment` has to
cover. The cut is a different skill. The agent does not compose the
judgment.

The policy is the **Pre-1.0 → 1.0 gate** locked-in decision in
`/release`. B.3a is the check, and it runs only when the owner asks for
`v1.0.0`. Do not copy either, and do not write the quiet-period duration
into this skill's output or into `STABILITY.md`.

## Scope

The git root of the working directory. A named list of repos is that
list, one at a time. A request to do every repo, or "all the
`STABILITY.md` files", stops: ask which repos. Do not scan the fleet,
and do not follow the work into another checkout.

No `STABILITY.md`: say so and stop. Start a catalogue only when the
owner asks for one in this turn. That catalogue gets an agent's
`## 1.0 judgment` in the same run.

## Which job

Read `STABILITY.md`. It is current when all of these hold:

- Nothing in it makes a quiet period, N clean minors, a surface-size
  table, a feature-freeze, or an empty Experimental pile into what
  authorizes or blocks 1.0.
- The gaps intro does not require every item to land before the cut.
- Each item still under the gaps heading carries one label:
  **Additive**, **Closure**, **Expandability**, or **Refused**.
- Where a key defines **Stable**, it is the fork promise (breaking it
  after 1.0 means forking the product), not "this has not moved" and
  not "this will not change before 1.0".
- `## 1.0 judgment` is present, current as `/release` B.3a defines
  freshness, and still matches the rows it names.

If any of those fail, update, then review in the same turn. If all
hold, review only. An explicit "read only, change nothing" skips the
update and says the file is still on the old approach.

## Update

Edit the doctrine already written in the file. Leave the catalogue's
rows at their current levels. A row's level changes when its promise
changes. Quiet time is not a promotion.

**Levels.** In the annotation key, **Stable** means the owner will fork
rather than break that promise after 1.0. **Needs review** and
**Experimental** may still be true after 1.0; a non-empty pile is not a
failed gate. Keep **Fluid** (or any other local level) if the file
already uses it. Add a key line only for a level the file already uses
and does not define.

**Gaps.** Label each existing item in its own text. Do not add items to
fill the four labels out.

- **Additive** — can land later without revising a promise.
- **Closure** — the unmapped-domain break risk the locked-in decision
  defines. An unfinished feature is Additive.
- **Expandability** — a promise already made that a later requirement
  would have to revise. The shapes are the ones B.3a names.
- **Refused** — the owner has declined it. It is not a gap.

Replace a "must be resolved / must land before 1.0" intro with one
line: these are inputs to the owner's `## 1.0 judgment`, and they do
not authorize the cut.

**Eligibility.** Strike a numeric clock, a feature-freeze, a
clear-Experimental rule, or a checklist that presents itself as the
gate. Keep the last breaking tag and its date when the file already
records them. In their place, one sentence: the cut requires the
agent's `## 1.0 judgment`, under `/release` B.3a, and the last breaking
release is `<tag>` (or "not recorded here"). One further sentence may
name the rule just retired. Do not go diff tags to discover a break
this skill did not already find in the file.

Write or update `## 1.0 judgment` in this run, by the procedure in the
`/release` locked-in decision. A heading that only defers the
evaluation to the owner is a failed update.

**Bullseye.** When a target's acceptance *is* the old clock, patch that
target with `bullseye_apply`. Do not hand-edit `bullseye.yaml`. Take
the replacement name and acceptance from the sub-target pattern in
`/release` B.3a. Leave achieved targets. Leave an active target whose
acceptance is about the work itself. Relax an active target only when
its acceptance forbids a breaking fix in order to keep the clock
running. A known break is allowed before 1.0; what it costs is the
quiet period in the locked-in decision. Do not create a judgment target here.

Commit only `STABILITY.md` and `bullseye.yaml`, and only the changes
this run made. Do not push.

## Review

Report to the owner. Do not edit the file again in this pass.

State, in prose:

- Whether this run updated the file, and the last breaking tag as the
  file records it. Whether the quiet period has elapsed is B.3a's
  check, and only when the owner asks for the cut. An owner who wants
  to skip that period is not amending the judgment or this file. Say
  that the wish is an instruction for the cut. Do not record it in
  `STABILITY.md`, and do not edit `/release`.
- Whether `## 1.0 judgment` is present. If it is, say whether it
  addresses both qualities and whether B.3a's freshness check would
  pass. Do not grade the prose. If it is absent, the cut is
  unauthorized until the owner writes it. Tell them what they write,
  and do not write it for them: their own words under that heading, a
  conclusion on expandability and a conclusion on closure, using the
  weigh-list in this review, and the heading names the last breaking
  tag this file records. When they dictate it, file those words
  verbatim.
- Any stricter local rule still written in the file. It still binds
  until an update removes it.

Then recommend what to weigh, under the labels above and the row shapes
B.3a names. For an Expandability row, the recommendation is to grow a
seam or to state the limit as permanent. A Needs review or Experimental
row the owner has been postponing a break on: making the break now is
allowed and costs the quiet period; leaving it means the lock includes
today's promise.

A catalogue where no row asks for a seam, and no gap names an unmapped
situation, is a fact about the file. It is not a judgment, and it does
not authorize a cut.

Stop there. Do not propose `v1.0.0`, and do not draft the judgment
the owner has not dictated.
