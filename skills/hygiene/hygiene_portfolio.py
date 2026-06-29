#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Fleet hygiene aggregator (fleet hygiene initiative).

Discovers every repo under ~/work that declares a hygiene.yaml, validates
each via hygiene_check.check_repo(), and prints a repo × dimension matrix of
**held tiers** (schema v1) plus a fleet-wide gap rollup. Answers "what tier is
dimension X at in repo Z?" and "which repos are weak on X?" in one command —
the question that motivated the whole initiative.

Mirrors bullseye_portfolio's cross-repo aggregation. Sibling tool to
hygiene_check.py in the `hygiene` skill (~/.claude/skills/hygiene); could
graduate to a bullseye-sibling MCP later.

Usage: hygiene_portfolio.py [--json] [--root DIR]   (default root: ~/work)
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hygiene_check import DIM_ORDER, check_repo  # noqa: E402

ABBREV = {  # 4-char column headers for the matrix
    "correctness": "corr", "security": "secu", "quality": "qual",
    "deps": "deps", "release": "rels", "governance": "govn",
    "build": "buil", "docs": "docs", "perf": "perf", "vcs": "vcs",
    "agent": "agnt",
}


def discover(root: Path) -> list[Path]:
    # Workspace layout: ~/work/<host>/<org>/<repo>/hygiene.yaml
    found = {p.parent.resolve() for p in root.glob("*/*/*/hygiene.yaml")}
    found |= {p.parent.resolve() for p in root.glob("hygiene.yaml")}  # root itself
    return sorted(found, key=lambda d: d.name)


def main() -> int:
    argv = sys.argv[1:]
    as_json = "--json" in argv
    root = Path.home() / "work"
    if "--root" in argv:
        root = Path(argv[argv.index("--root") + 1]).expanduser().resolve()

    repos = discover(root)
    reports = []
    for repo_root in repos:
        try:
            reports.append(check_repo(repo_root))
        except Exception as e:  # one bad repo must not sink the fleet view
            reports.append({"repo": repo_root.name, "error": str(e), "dims": {},
                            "aspires": 0, "passed": False, "results": [],
                            "floor_violations": []})

    if as_json:
        print(json.dumps({"root": str(root), "repos": reports}, indent=2))
        return 0

    if not reports:
        print(f"no hygiene.yaml found under {root}")
        return 0

    # --- coverage matrix: repo × dimension held tier ---
    name_w = max([len(r["repo"]) for r in reports] + [len("repo")])
    cell_w = 5
    header = f"{'repo':<{name_w}}  " + "".join(
        f"{ABBREV[d]:>{cell_w}}" for d in DIM_ORDER)
    print(header)
    print("─" * len(header))

    for r in reports:
        if "error" in r:
            print(f"{r['repo']:<{name_w}}  ⚠ {r['error'][:60]}")
            continue
        cells = ""
        for d in DIM_ORDER:
            v = r["dims"].get(d)
            if v is None:
                cells += f"{'·':>{cell_w}}"
            else:
                # held tier; trailing ✗ when below the declared floor
                mark = "✗" if not v["ok"] else " "
                text = f"{v['held']}{mark}"
                cells += f"{text:>{cell_w}}"
        verdict = "" if r["passed"] else "  DRIFT"
        print(f"{r['repo']:<{name_w}}  {cells}{verdict}")

    print(f"\ncell = held tier per dimension (0–{max((r['aspires'] for r in reports), default=3)})   "
          f"✗ = below declared floor   · = no items declared\n")

    # --- fleet gap rollup: weakest dimensions, by repo ---
    print("fleet gaps (dimensions below aspires, with unmet item count):")
    for r in reports:
        if "error" in r:
            continue
        weak = []
        for d in DIM_ORDER:
            v = r["dims"].get(d)
            if v is None:
                continue
            unmet_in_band = [it for it in v["unmet"] if it["tier"] <= r["aspires"]]
            if unmet_in_band:
                weak.append(f"{d}({v['held']}→{r['aspires']}, {len(unmet_in_band)})")
        if weak:
            print(f"  {r['repo']}: {', '.join(weak)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
