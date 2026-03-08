#!/usr/bin/env python3
"""Rank active convergence targets by effective weight with dependency analysis."""

import re
import sys
from collections import defaultdict


def parse_targets(path):
    """Parse targets.md and return dict of target_id -> target dict."""
    with open(path) as f:
        content = f.read()

    targets = {}
    heading_re = re.compile(r'^#{3,4}\s+(🎯T[\d.]+)\s+(.*)', re.MULTILINE)
    section_re = re.compile(r'^##\s+(Active|Achieved|Archive)\b', re.MULTILINE)
    tid_re = re.compile(r'🎯T[\d.]+')

    # Build a map of position -> section name
    sections = [(m.start(), m.group(1).lower()) for m in section_re.finditer(content)]

    def section_at(pos):
        """Return the section name for a given position in the file."""
        current = None
        for sec_pos, sec_name in sections:
            if sec_pos > pos:
                break
            current = sec_name
        return current

    matches = list(heading_re.finditer(content))
    for i, match in enumerate(matches):
        body_start = match.end()
        body_end = matches[i + 1].start() if i + 1 < len(matches) else len(content)
        body = content[body_start:body_end]

        tid = match.group(1)
        name = match.group(2).strip()
        sec = section_at(match.start())

        t = {
            'id': tid,
            'name': name,
            'section': sec,
            'value': 0,
            'cost': 1,
            'has_weight': False,
            'status': 'achieved' if sec in ('achieved', 'archive') else 'identified',
            'depends_on': [],
            'parent': None,
            'gates': [],
        }

        for line in body.split('\n'):
            line = line.strip()
            if not line.startswith('- **'):
                continue

            wm = re.match(
                r'- \*\*Weight\*\*:\s*\d+\s*\(value\s+(\d+)\s*/\s*cost\s+(\d+)\)',
                line,
            )
            if wm:
                t['value'] = int(wm.group(1))
                t['cost'] = int(wm.group(2))
                t['has_weight'] = True
                continue

            sm = re.match(r'- \*\*Status\*\*:\s*(\S+)', line)
            if sm:
                t['status'] = sm.group(1)
                continue

            dm = re.match(r'- \*\*Depends on\*\*:\s*(.*)', line)
            if dm:
                t['depends_on'] = tid_re.findall(dm.group(1))
                continue

            pm = re.match(r'- \*\*Parent\*\*:\s*(🎯T[\d.]+)', line)
            if pm:
                t['parent'] = pm.group(1)
                continue

            gm = re.match(r'- \*\*Gates\*\*:\s*(.*)', line)
            if gm:
                t['gates'] = tid_re.findall(gm.group(1))
                continue

        targets[tid] = t

    return targets


def rank_targets(path):
    targets = parse_targets(path)
    if not targets:
        print("# rank\n\nNo targets found.")
        return

    # Build dependency graph: deps[X] = set of target IDs that X depends on
    deps = defaultdict(set)
    for t in targets.values():
        tid = t['id']
        for dep in t['depends_on']:
            if dep in targets:
                deps[tid].add(dep)
        if t['parent'] and t['parent'] in targets:
            deps[t['parent']].add(tid)
        for gated in t['gates']:
            if gated in targets:
                deps[gated].add(tid)

    # Build reverse deps: reverse_deps[X] = targets that depend on X
    reverse_deps = defaultdict(set)
    for tid, dep_set in deps.items():
        for dep in dep_set:
            reverse_deps[dep].add(tid)

    # Transitive dependents (everything that depends on tid, directly or not)
    def get_dependents(tid):
        visited = set()
        stack = list(reverse_deps.get(tid, set()))
        while stack:
            d = stack.pop()
            if d not in visited:
                visited.add(d)
                stack.extend(reverse_deps.get(d, set()) - visited)
        return visited

    # Filter: exclude achieved targets and sub-targets of achieved parents
    active = [
        t for t in targets.values()
        if t['status'] != 'achieved'
        and not (
            t['parent']
            and t['parent'] in targets
            and targets[t['parent']]['status'] == 'achieved'
        )
    ]

    if not active:
        print("# rank\n\nAll targets achieved.")
        return

    # Check for missing Weight fields on active targets
    missing_weight = [t for t in active if not t['has_weight']]
    if missing_weight:
        print("# errors")
        for t in missing_weight:
            print(f"\n{t['id']} {t['name']}")
            print("  missing: Weight field (expected: - **Weight**: N (value V / cost C))")
        print()
        sys.exit(1)

    # Compute blocked-by and effective values
    results = {}
    for t in active:
        tid = t['id']

        # Direct deps that are not achieved
        blockers = sorted(
            d for d in deps.get(tid, set())
            if d in targets and targets[d]['status'] != 'achieved'
        )

        # gated_value = sum of declared values of all transitive dependents
        dependents = get_dependents(tid)
        gated_value = sum(targets[d]['value'] for d in dependents if d in targets)
        eff_value = t['value'] + gated_value
        eff_weight = eff_value / t['cost'] if t['cost'] > 0 else 0

        # Direct active dependents (for "enables" line)
        enables = sorted(
            d for d in reverse_deps.get(tid, set())
            if d in targets and targets[d]['status'] != 'achieved'
        )

        results[tid] = {
            'blockers': blockers,
            'eff_value': eff_value,
            'eff_weight': eff_weight,
            'enables': enables,
        }

    # Split and sort by effective weight descending
    unblocked = sorted(
        [t for t in active if not results[t['id']]['blockers']],
        key=lambda t: results[t['id']]['eff_weight'],
        reverse=True,
    )
    blocked = sorted(
        [t for t in active if results[t['id']]['blockers']],
        key=lambda t: results[t['id']]['eff_weight'],
        reverse=True,
    )

    def fmt_weight(value, cost):
        w = value / cost if cost > 0 else 0
        return str(int(w)) if w == int(w) else f"{w:.1f}"

    def print_target(t):
        tid = t['id']
        r = results[tid]
        print(f"\n{tid} {t['name']}")
        print(f"  status: {t['status']}")
        print(f"  weight: {fmt_weight(t['value'], t['cost'])} "
              f"(value {t['value']} / cost {t['cost']})")
        print(f"  effective: {r['eff_weight']:.1f} "
              f"(value {r['eff_value']} / cost {t['cost']})")
        if r['enables']:
            print(f"  enables: {', '.join(r['enables'])}")
        if r['blockers']:
            print(f"  blocked-by: {', '.join(r['blockers'])}")

    print("# rank")

    print("\n## unblocked")
    if unblocked:
        for t in unblocked:
            print_target(t)
    else:
        print("\n(none)")

    print("\n## blocked")
    if blocked:
        for t in blocked:
            print_target(t)
    else:
        print("\n(none)")


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <targets.md>", file=sys.stderr)
        sys.exit(1)
    rank_targets(sys.argv[1])
