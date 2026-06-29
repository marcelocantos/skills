#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Validate hygiene.yaml against repo reality (fleet hygiene initiative).

hygiene.yaml declares a repo's steady-state hygiene posture: a list of items,
each pairing an intent with a machine-checkable `evidence` pointer. The
validator resolves every pointer against what the repo actually contains — CI
jobs, Makefile targets, files, gh settings, scanners.

Tiers are PER DIMENSION, not a single repo score (schema v1). For each
dimension the validator derives the **held tier** = the highest T such that
every item in that dimension with `tier <= T` is satisfied. The repo declares
a per-dimension `floors` ratchet; drift (a dimension dropping below its floor)
fails the check. `aspires` is the gap horizon for reporting. `enforce` is
intent-only metadata and no longer affects tiers.

bullseye tracks aspirational state ("achieve X"); this tracks steady-state
("we maintain X"). Invoked by the `hygiene` skill (/hygiene).

`check_repo(root)` is repo-agnostic, so the fleet aggregator
(hygiene_portfolio.py) reuses it. Lives in the `hygiene` skill
(~/.claude/skills/hygiene, synced to marcelocantos/skills); could graduate to
a bullseye-sibling MCP later.

Usage: hygiene_check.py [--json] [path/to/hygiene.yaml]
       (default: ./hygiene.yaml, repo root = cwd)
"""

import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import yaml

VALID_STATE = {"enforced", "present", "manual", "planned", "skipped"}
VALID_ENFORCE = {"blocking", "warning", "informational"}
REASON_REQUIRED = {"skipped", "planned"}  # negative space must justify itself
NO_TIER = 90                              # sentinel for an item missing `tier`

DIM_ORDER = ["correctness", "security", "quality", "deps", "release",
             "governance", "build", "docs", "perf", "vcs", "agent"]


@dataclass
class Ctx:
    """Everything an evidence resolver needs, bound to one repo."""
    root: Path
    workflows: dict      # filename -> parsed workflow yaml
    owner_repo: str | None  # "owner/name" for gh api, or None


def load_workflows(root: Path) -> dict:
    wf = {}
    for p in sorted((root / ".github" / "workflows").glob("*.y*ml")):
        try:
            wf[p.name] = yaml.safe_load(p.read_text()) or {}
        except yaml.YAMLError as e:
            wf[p.name] = {"__error__": str(e)}
    return wf


def gh_owner_repo(root: Path) -> str | None:
    try:
        url = subprocess.run(
            ["git", "-C", str(root), "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=10,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    m = re.search(r"[/:]([^/:]+)/([^/:]+?)(?:\.git)?$", url)
    return f"{m.group(1)}/{m.group(2)}" if m else None


# --- evidence resolution ---------------------------------------------------
# Each resolver returns (ok, detail). `ok` means "this pointer resolves
# against reality". The `absent:` wrapper inverts a nested resolver.

def resolve(ctx: Ctx, ev: dict) -> tuple[bool, str]:
    if not isinstance(ev, dict) or len(ev) != 1:
        return False, f"malformed evidence (need exactly one key): {ev!r}"
    (kind, val), = ev.items()

    if kind == "absent":
        ok, detail = resolve(ctx, val)
        return (not ok), (f"present — {detail}" if ok else f"absent — {detail}")

    if kind == "ci_job":
        wf_name, _, job_spec = str(val).partition("#")
        job_id, _, matrix_name = job_spec.partition(":")
        wf = ctx.workflows.get(wf_name)
        if wf is None:
            return False, f"workflow {wf_name} not found"
        jobs = wf.get("jobs", {})
        if job_id not in jobs:
            return False, f"job '{job_id}' not in {wf_name}"
        if matrix_name:
            include = (jobs[job_id].get("strategy", {})
                       .get("matrix", {}).get("include", []) or [])
            names = [e.get("name") for e in include if isinstance(e, dict)]
            if matrix_name not in names:
                return False, f"matrix entry '{matrix_name}' not in job '{job_id}'"
            return True, f"{wf_name}#{job_id} matrix '{matrix_name}'"
        return True, f"{wf_name}#{job_id}"

    if kind == "ci_step":
        wf_name, want = val["workflow"], val["name"]
        wf = ctx.workflows.get(wf_name) or {}
        for job_id, job in (wf.get("jobs", {}) or {}).items():
            for step in (job.get("steps", []) or []):
                if isinstance(step, dict) and step.get("name") == want:
                    return True, f"{wf_name}#{job_id} step '{want}'"
        return False, f"no step named '{want}' in {wf_name}"

    if kind == "make_target":
        mk = (ctx.root / "Makefile").read_text()
        if re.search(rf"(?m)^{re.escape(str(val))}\s*:", mk):
            return True, f"Makefile target '{val}'"
        return False, f"no Makefile target '{val}'"

    if kind == "command":
        try:
            r = subprocess.run(str(val), shell=True, cwd=ctx.root,
                               capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.SubprocessError) as e:
            return False, f"command errored: {e}"
        return (r.returncode == 0), f"`{val}` exit {r.returncode}"

    if kind == "file":
        path = ctx.root / val["path"]
        if not path.exists():
            return False, f"missing {val['path']}"
        if "matches" in val:
            try:
                if not re.search(val["matches"], path.read_text(errors="replace")):
                    return False, f"{val['path']} present but /{val['matches']}/ not found"
            except OSError as e:
                return False, f"{val['path']}: {e}"
        return True, f"{val['path']}"

    if kind == "gh_setting":
        if ctx.owner_repo is None:
            return False, "could not derive owner/repo from git remote"
        try:
            r = subprocess.run(
                ["gh", "api", f"repos/{ctx.owner_repo}", "--jq", f".{val['key']}"],
                capture_output=True, text=True, timeout=20,
            )
        except (OSError, subprocess.SubprocessError) as e:
            return False, f"gh api failed: {e}"
        if r.returncode != 0:
            return False, f"gh api error: {r.stderr.strip()[:80]}"
        got = r.stdout.strip()
        want = json.dumps(val["equals"]) if isinstance(val["equals"], bool) else str(val["equals"])
        return (got == want), f"{val['key']}={got} (want {want})"

    if kind == "scanner":
        tool = val["tool"]
        cfg_ok = (ctx.root / val["config"]).exists() if "config" in val else True
        invoked = any(tool in yaml.safe_dump(wf) for wf in ctx.workflows.values())
        return (cfg_ok and invoked), \
            f"{tool}: config={'ok' if cfg_ok else 'missing'} invoked={'yes' if invoked else 'no'}"

    if kind == "manual":
        lv = val.get("last_verified")
        return (lv is not None), f"manual attestation (last_verified={lv})"

    return False, f"unknown evidence kind '{kind}'"


# --- per-item evaluation ---------------------------------------------------

def evaluate(ctx: Ctx, item: dict) -> dict:
    iid = item.get("id", "<no-id>")
    state = item.get("state")
    enforce = item.get("enforce")
    errors = []
    if state not in VALID_STATE:
        errors.append(f"invalid state '{state}'")
    if enforce not in VALID_ENFORCE:
        errors.append(f"invalid enforce '{enforce}'")
    if state in REASON_REQUIRED and not item.get("reason"):
        errors.append(f"state '{state}' requires a reason")

    ev = item.get("evidence")
    ok, detail = resolve(ctx, ev) if ev else (False, "no evidence declared")

    # `satisfied` = "this hygiene guarantee actually holds right now".
    #   planned  -> declared gap, never satisfied (but flag if reality
    #               outran the declaration: the thing now exists).
    #   skipped  -> satisfied iff the thing really is absent (else: silently
    #               running -> the skip is a lie).
    #   else     -> satisfied iff evidence resolves.
    advisory = None
    if state == "planned":
        satisfied = False
        if not ok:  # absent: holds == gap still open (normal); ok==False => closed
            advisory = "reality outran declaration — gap appears closed; reclassify"
    elif state == "skipped":
        satisfied = ok
        if not ok:
            advisory = "SKIP VIOLATED — declared skipped but present"
    else:
        satisfied = ok

    return {
        "id": iid, "dim": item.get("dim"), "tier": item.get("tier", NO_TIER),
        "state": state, "enforce": enforce, "desc": item.get("desc", ""),
        "satisfied": satisfied, "ok": ok, "detail": detail,
        "errors": errors, "advisory": advisory,
    }


# --- per-dimension tier logic ----------------------------------------------
# held tier of a dimension = highest T such that every item in that dimension
# with tier <= T is satisfied. A gap at the dimension's lowest tier yields 0.

def held_tier(items: list[dict]) -> int:
    tiers = sorted({it["tier"] for it in items if it["tier"] < NO_TIER})
    held = 0
    for t in tiers:
        if all(it["satisfied"] for it in items if it["tier"] <= t):
            held = t
        else:
            break
    return held


def check_repo(root: Path, doc_path: Path | None = None) -> dict:
    """Evaluate one repo's hygiene.yaml; the reusable entry point."""
    doc_path = doc_path or (root / "hygiene.yaml")
    doc = yaml.safe_load(doc_path.read_text())
    ctx = Ctx(root=root, workflows=load_workflows(root), owner_repo=gh_owner_repo(root))

    floors = doc.get("floors", {}) or {}
    aspires = doc.get("aspires", 0)
    results = [evaluate(ctx, it) for it in doc.get("items", [])]

    by_dim: dict[str, list[dict]] = {}
    for r in results:
        by_dim.setdefault(r["dim"], []).append(r)

    dims = {}
    for d, items in by_dim.items():
        held = held_tier(items)
        floor = floors.get(d, 0)
        unmet = sorted((it for it in items if not it["satisfied"]),
                       key=lambda x: (x["tier"], x["id"]))
        dims[d] = {"held": held, "floor": floor, "ok": held >= floor, "unmet": unmet}

    floor_violations = sorted(d for d, v in dims.items() if not v["ok"])
    skip_violations = [r for r in results
                       if r["state"] == "skipped" and not r["satisfied"]]
    config_errors = [e for r in results for e in r["errors"]]
    passed = not (floor_violations or skip_violations or config_errors)

    return {
        "repo": doc.get("repo", root.name), "aspires": aspires,
        "dims": dims, "results": results, "floor_violations": floor_violations,
        "skip_violations": skip_violations, "config_errors": config_errors,
        "passed": passed,
    }


# --- single-repo report (CLI) ----------------------------------------------

def main() -> int:
    argv = sys.argv[1:]
    as_json = "--json" in argv
    positional = [a for a in argv if not a.startswith("--")]
    if positional:
        doc_path = Path(positional[0]).resolve()
        root = doc_path.parent
    else:
        root = Path.cwd()
        doc_path = root / "hygiene.yaml"

    rep = check_repo(root, doc_path)

    if as_json:
        print(json.dumps(rep, indent=2))
        return 0 if rep["passed"] else 1

    print(f"hygiene: {rep['repo']}   aspires tier {rep['aspires']}\n")
    print("  dimension     held  floor")
    for d in sorted(rep["dims"], key=lambda x: DIM_ORDER.index(x) if x in DIM_ORDER else 99):
        v = rep["dims"][d]
        flag = "✓" if v["ok"] else "✗ BELOW FLOOR"
        extra = f"  (+{v['held'] - v['floor']} above)" if v["ok"] and v["held"] > v["floor"] else ""
        print(f"  {d:12}  T{v['held']}    T{v['floor']}   {flag}{extra}")
    print()

    # gaps: unmet items with tier <= aspires, grouped by dimension
    print(f"gaps to close (unmet, tier ≤ {rep['aspires']}):")
    any_gap = False
    for d in sorted(rep["dims"], key=lambda x: DIM_ORDER.index(x) if x in DIM_ORDER else 99):
        gaps = [it for it in rep["dims"][d]["unmet"] if it["tier"] <= rep["aspires"]]
        if not gaps:
            continue
        any_gap = True
        ids = ", ".join(f"{it['id'].split('.', 1)[1]}[T{it['tier']}]" for it in gaps)
        print(f"  {d}: {ids}")
    if not any_gap:
        print("  (none)")
    print()

    print("─" * 60)
    if rep["floor_violations"]:
        print("FLOOR DRIFT — dimensions below their declared floor:")
        for d in rep["floor_violations"]:
            v = rep["dims"][d]
            print(f"  ✗ {d}: held T{v['held']} < floor T{v['floor']}")
            for it in v["unmet"]:
                if it["tier"] <= v["floor"]:
                    print(f"      unmet at/below floor: {it['id']} [T{it['tier']}] — {it['detail']}")
    for r in rep["skip_violations"]:
        print(f"  ✗ skip violated: {r['id']} — {r['detail']}")
    for e in rep["config_errors"]:
        print(f"  ✗ declaration error: {e}")

    print(f"\n{'PASS' if rep['passed'] else 'FAIL'}")
    return 0 if rep["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
