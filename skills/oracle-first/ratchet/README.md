# ratchet — honesty-ratchet skeleton

Single-file, stdlib-only Python 3 gate implementing the five ingredients
in [`../honesty-ratchet.md`](~/.claude/skills/oracle-first/honesty-ratchet.md).

## Project layout it expects

```
ratchet.json            gate description (below)
ratchet-baseline.json   locked numbers + provenance; written only by `lock`
corpus/<family>/<case>.*     source inputs — the universe is COUNTED here
reference/<family>/<case>.*  frozen expected outputs
holdout/**/<case>.*          out-of-corpus inputs (optional but recommended)
```

## ratchet.json

```json
{
  "schema": 1,
  "baseline": "ratchet-baseline.json",
  "corpus": "corpus",
  "reference": "reference",
  "out": "out",
  "produce": "<shipped path> --corpus {corpus} --out {out}",
  "score": "<comparator> --out {out} --ref {ref}",
  "tolerance": {"default": 0, "per_family": {"flaky-family": 1}},
  "embed_guard": {"sources": ["src/**/*.rs"], "forbidden": ["reference", "expected", "golden"]},
  "holdout": {
    "inputs": "holdout/**/*",
    "produce_one": "<shipped path> --one {input} --output {output}",
    "reference_one": "<reference generator> --one {input} --output {output}"
  }
}
```

`produce` must run the product exactly as shipped. `score` prints
`{"<family>": {"pass": N, "eligible": M}}`; `eligible` is cross-checked
against the corpus tree and rejected if it differs. Commands run through
the shell from the config's directory.

## Commands

```
python3 ratchet.py check                       # the gate; exit 1 on any finding
python3 ratchet.py lock --reason R --mechanism M   # re-run guards, then lock
python3 ratchet.py show                        # print the locked baseline
```

Findings print as `BLOCKED [TAG] message`; tags are listed in
`honesty-ratchet.md` §4. Wire `check` into a pre-push hook or CI job as
part of adopting it, and drill it (`honesty-ratchet.md` §5) before
trusting it.
