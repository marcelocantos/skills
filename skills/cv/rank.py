#!/usr/bin/env python3
"""Rank active convergence targets using parent/child value propagation."""

import re
import sys
from collections import defaultdict, deque


def parse_targets(path):
    """Parse targets.md and return dict of target_id -> target dict."""
    with open(path) as f:
        content = f.read()

    targets = {}
    heading_re = re.compile(r'^#{3,4}\s+(🎯T[\d.]+)\s+(.*)', re.MULTILINE)
    section_re = re.compile(r'^##\s+(Active|Achieved|Archive)\b', re.MULTILINE)
    tid_re = re.compile(r'🎯T[\d.]+')

    sections = [(m.start(), m.group(1).lower()) for m in section_re.finditer(content)]

    def section_at(pos):
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
            'value': None,
            'cost': None,
            'weight': None,
            'parent': None,
            'gates': [],        # target IDs this target gates (enables)
            'tags': [],
            'status': 'achieved' if sec in ('achieved', 'archive') else 'identified',
            'depends_on': [],
        }

        for line in body.split('\n'):
            line = line.strip()
            if not line.startswith('- **'):
                continue

            # Weight: N (value V / cost C)
            wm = re.match(r'- \*\*Weight\*\*:\s*([\d.]+)\s*\(value\s+([\d.]+)\s*/\s*cost\s+([\d.]+)\)', line)
            if wm:
                t['weight'] = float(wm.group(1))
                t['value'] = float(wm.group(2))
                t['cost'] = float(wm.group(3))
                continue

            # Parent: 🎯TN
            pm = re.match(r'- \*\*Parent\*\*:\s*(🎯T[\d.]+)', line)
            if pm:
                t['parent'] = pm.group(1)
                continue

            # Gates: 🎯TN, 🎯TM
            gm = re.match(r'- \*\*Gates\*\*:\s*(.*)', line)
            if gm:
                t['gates'] = tid_re.findall(gm.group(1))
                continue

            # Tags
            tm = re.match(r'- \*\*Tags\*\*:\s*(.*)', line)
            if tm:
                t['tags'] = [s.strip() for s in tm.group(1).split(',') if s.strip()]
                continue

            # Status
            sm = re.match(r'- \*\*Status\*\*:\s*(.+)', line)
            if sm:
                t['status'] = sm.group(1)
                continue

            # Depends on
            dm = re.match(r'- \*\*Depends on\*\*:\s*(.*)', line)
            if dm:
                t['depends_on'] = tid_re.findall(dm.group(1))
                continue

        targets[tid] = t

    return targets


def build_children(targets):
    """Build parent -> [children] map from Parent fields."""
    children = defaultdict(list)
    for tid, t in targets.items():
        if t['parent'] and t['parent'] in targets:
            children[t['parent']].append(tid)
    return children


def rank_targets(path, mermaid_only=False):
    targets = parse_targets(path)
    if not targets:
        print("# rank\n\nNo targets found.")
        return

    # Filter to active targets
    active_ids = {tid for tid, t in targets.items()
                  if t['section'] not in ('achieved', 'archive')}
    active_targets = {tid: t for tid, t in targets.items() if tid in active_ids}

    if not active_targets:
        print("# rank\n\nAll targets achieved.")
        return

    children = build_children(targets)

    # Validate: active targets must have Weight (value/cost)
    errors = []
    for tid, t in active_targets.items():
        if t['weight'] is None:
            errors.append(f"  {tid} {t['name']}: missing Weight field")
        elif t['value'] is None or t['cost'] is None:
            errors.append(f"  {tid} {t['name']}: Weight missing (value V / cost C) breakdown")
    if errors:
        print("# errors\n")
        print('\n'.join(errors))
        sys.exit(1)

    # Determine blocked targets (via Depends on)
    blocked_by = {}
    for tid in active_ids:
        t = targets[tid]
        blockers = sorted(
            d for d in t['depends_on']
            if d in targets and targets[d]['status'] != 'achieved'
        )
        blocked_by[tid] = blockers

    # Build results using declared values
    results = {}
    for tid in active_ids:
        t = targets[tid]
        val = float(t['value'])
        cost = float(t['cost'])
        weight = val / cost if cost > 0 else 0.0
        results[tid] = {
            'value': val,
            'cost': cost,
            'weight': weight,
            'blockers': blocked_by[tid],
            'children': [c for c in children.get(tid, []) if c in active_ids],
        }

    # Mermaid-only mode
    if mermaid_only:
        print(generate_mermaid(targets, active_ids, results, children))
        return

    # Split: top-level (no parent or parent not active) vs children
    top_level = sorted(
        [t for t in active_targets.values()
         if not t['parent'] or t['parent'] not in active_ids],
        key=lambda t: results[t['id']]['weight'],
        reverse=True,
    )

    def fmt_num(n):
        return str(int(n)) if n == int(n) else f"{n:.1f}"

    def print_target(t, indent=0):
        tid = t['id']
        r = results[tid]
        prefix = "  " * indent
        print(f"\n{prefix}{tid} {t['name']}")
        print(f"{prefix}  status: {t['status']}")
        print(f"{prefix}  value: {fmt_num(r['value'])}  cost: {fmt_num(r['cost'])}  "
              f"weight: {fmt_num(r['weight'])}")
        if t['tags']:
            print(f"{prefix}  tags: {', '.join(t['tags'])}")
        if t['gates']:
            print(f"{prefix}  gates: {', '.join(t['gates'])}")
        if r['blockers']:
            print(f"{prefix}  blocked-by: {', '.join(r['blockers'])}")
        # Print children
        for child_tid in sorted(r['children'],
                                key=lambda c: results[c]['weight'],
                                reverse=True):
            print_target(targets[child_tid], indent + 1)

    # Separate blocked/unblocked at top level
    unblocked = [t for t in top_level if not results[t['id']]['blockers']]
    blocked = [t for t in top_level if results[t['id']]['blockers']]

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

    # Append mermaid graph
    print("\n## graph\n")
    print("```mermaid")
    print(generate_mermaid(targets, active_ids, results, children))
    print("```")


def condense_title(name):
    """Shorten a target name for Mermaid graph display."""
    short = name
    for word in ['works', 'is ', 'are ', 'the ', 'The ']:
        short = short.replace(word, '')
    short = short.strip().rstrip('.')
    if len(short) > 30:
        short = short[:28] + '…'
    return short


def generate_mermaid(targets, active_ids, results, children_map):
    """Generate Mermaid graph of active targets."""
    lines = ['graph TD']

    # Nodes
    for tid in sorted(active_ids):
        t = targets[tid]
        title = condense_title(t['name'])
        node_id = tid.replace('🎯', '').replace('.', '_')
        lines.append(f'    {node_id}["{title}"]')

    # Parent -> child edges
    for parent_tid in sorted(active_ids):
        parent_node = parent_tid.replace('🎯', '').replace('.', '_')
        for child_tid in children_map.get(parent_tid, []):
            if child_tid not in active_ids:
                continue
            child_node = child_tid.replace('🎯', '').replace('.', '_')
            lines.append(f'    {parent_node} --> {child_node}')

    # Gates edges (cross-cutting)
    for tid in sorted(active_ids):
        t = targets[tid]
        node_id = tid.replace('🎯', '').replace('.', '_')
        for gated_tid in t.get('gates', []):
            if gated_tid not in active_ids:
                continue
            gated_node = gated_tid.replace('🎯', '').replace('.', '_')
            lines.append(f'    {node_id} -.->|gates| {gated_node}')

    # Depends-on edges
    for tid in sorted(active_ids):
        t = targets[tid]
        node_id = tid.replace('🎯', '').replace('.', '_')
        for dep_tid in t.get('depends_on', []):
            if dep_tid not in active_ids:
                continue
            dep_node = dep_tid.replace('🎯', '').replace('.', '_')
            lines.append(f'    {node_id} -.->|needs| {dep_node}')

    return '\n'.join(lines)


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    flags = {a for a in sys.argv[1:] if a.startswith('-')}

    if not args:
        print(f"Usage: {sys.argv[0]} [--mermaid] <targets.md>", file=sys.stderr)
        sys.exit(1)

    mermaid_only = '--mermaid' in flags
    rank_targets(args[0], mermaid_only=mermaid_only)
