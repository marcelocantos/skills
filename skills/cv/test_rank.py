#!/usr/bin/env python3
"""End-to-end tests for rank.py."""

import os
import subprocess
import sys
import tempfile
import textwrap

RANK_PY = os.path.join(os.path.dirname(__file__), 'rank.py')


def run(content, *, mermaid=False):
    """Write content to a temp file, run rank.py, return (stdout, stderr, rc)."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
        f.write(textwrap.dedent(content))
        f.flush()
        args = [sys.executable, RANK_PY]
        if mermaid:
            args.append('--mermaid')
        args.append(f.name)
        result = subprocess.run(args, capture_output=True, text=True)
        os.unlink(f.name)
        return result.stdout, result.stderr, result.returncode


def test_empty_file():
    out, _, rc = run("")
    assert rc == 0
    assert "No targets found" in out


def test_all_achieved():
    out, _, rc = run("""\
        # Targets

        ## Achieved

        ### 🎯T1 Everything is great
        - **Weight**: 2 (value 8 / cost 3)
        - **Status**: achieved
    """)
    assert rc == 0
    assert "All targets achieved" in out


def test_missing_weight_errors():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 No weight target
        - **Status**: not started
    """)
    assert rc == 1
    assert "errors" in out
    assert "missing Weight" in out


def test_missing_breakdown_errors():
    """Weight without (value V / cost C) should error."""
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Bare weight
        - **Weight**: 3
        - **Status**: not started
    """)
    assert rc == 1
    assert "errors" in out
    assert "missing Weight" in out


def test_single_leaf_target():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Tests pass on all platforms
        - **Weight**: 2 (value 8 / cost 3)
        - **Status**: converging
    """)
    assert rc == 0
    assert "🎯T1" in out
    assert "value: 8" in out
    assert "cost: 3" in out
    assert "status: converging" in out
    assert "unblocked" in out


def test_parent_child_hierarchy():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Runtime is ready
        - **Weight**: 1 (value 10 / cost 8)
        - **Status**: not started

        ### 🎯T1.1 I/O wrappers exist
        - **Weight**: 2 (value 8 / cost 5)
        - **Parent**: 🎯T1
        - **Status**: not started

        ### 🎯T1.2 HTTP server works
        - **Weight**: 1 (value 5 / cost 8)
        - **Parent**: 🎯T1
        - **Status**: not started
    """)
    assert rc == 0
    # Parent should appear at top level
    assert "🎯T1 Runtime is ready" in out
    # Children nested under parent
    assert "🎯T1.1 I/O wrappers exist" in out
    assert "🎯T1.2 HTTP server works" in out
    # Only parent at top level (children indented)
    lines = out.split('\n')
    top_targets = [l for l in lines if l.startswith('\n🎯') or (l.startswith('🎯'))]
    child_lines = [l for l in lines if '🎯T1.1' in l or '🎯T1.2' in l]
    # Children should be indented
    for cl in child_lines:
        assert cl.startswith('  ') or cl.startswith('\n  ')


def test_weight_ordering():
    """Higher weight targets should appear first."""
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Low priority
        - **Weight**: 1 (value 2 / cost 5)
        - **Status**: not started

        ### 🎯T2 High priority
        - **Weight**: 3 (value 8 / cost 3)
        - **Status**: not started
    """)
    assert rc == 0
    t1_pos = out.index("🎯T1")
    t2_pos = out.index("🎯T2")
    assert t2_pos < t1_pos, "Higher weight T2 should appear before T1"


def test_blocked_target():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Foundation work
        - **Weight**: 2 (value 5 / cost 3)
        - **Status**: not started

        ### 🎯T2 Depends on foundation
        - **Weight**: 3 (value 8 / cost 3)
        - **Depends on**: 🎯T1
        - **Status**: not started
    """)
    assert rc == 0
    # T2 should be in blocked section
    blocked_section = out.split("## blocked")[1]
    assert "🎯T2" in blocked_section
    assert "blocked-by: 🎯T1" in out


def test_blocked_by_achieved_is_unblocked():
    """Dependency on an achieved target should not block."""
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T2 Next step
        - **Weight**: 2 (value 5 / cost 3)
        - **Depends on**: 🎯T1
        - **Status**: not started

        ## Achieved

        ### 🎯T1 Foundation done
        - **Weight**: 2 (value 5 / cost 3)
        - **Status**: achieved
    """)
    assert rc == 0
    unblocked_section = out.split("## blocked")[0]
    assert "🎯T2" in unblocked_section
    assert "blocked-by" not in out


def test_gates_in_output():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Infra target
        - **Weight**: 2 (value 5 / cost 3)
        - **Gates**: 🎯T2
        - **Status**: not started

        ### 🎯T2 User feature
        - **Weight**: 3 (value 8 / cost 3)
        - **Status**: not started
    """)
    assert rc == 0
    assert "gates: 🎯T2" in out


def test_tags_in_output():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Tagged target
        - **Weight**: 2 (value 5 / cost 3)
        - **Tags**: runtime, performance
        - **Status**: not started
    """)
    assert rc == 0
    assert "tags: runtime, performance" in out


def test_mixed_active_and_achieved():
    """Only active targets should appear in ranking."""
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T2 Active work
        - **Weight**: 2 (value 5 / cost 3)
        - **Status**: not started

        ## Achieved

        ### 🎯T1 Done work
        - **Weight**: 8 (value 8 / cost 1)
        - **Status**: achieved
    """)
    assert rc == 0
    assert "🎯T2 Active work" in out
    # T1 should not appear in unblocked/blocked sections
    rank_section = out.split("## graph")[0]
    # T1 may appear in the full output only as part of dependency resolution,
    # but not as a ranked target
    unblocked = out.split("## blocked")[0].split("## unblocked")[1]
    assert "🎯T1" not in unblocked


def test_fractional_weight_display():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Fractional weight
        - **Weight**: 1 (value 3 / cost 8)
        - **Status**: not started
    """)
    assert rc == 0
    # 3/8 = 0.375, displayed as 0.4
    assert "weight: 0.4" in out


def test_mermaid_output():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Parent
        - **Weight**: 1 (value 5 / cost 4)
        - **Status**: not started

        ### 🎯T1.1 Child
        - **Weight**: 2 (value 5 / cost 2)
        - **Parent**: 🎯T1
        - **Status**: not started
    """, mermaid=True)
    assert rc == 0
    assert "graph TD" in out
    assert "T1[" in out
    assert "T1_1[" in out
    assert "T1 --> T1_1" in out


def test_mermaid_gates_edges():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Infra
        - **Weight**: 2 (value 5 / cost 3)
        - **Gates**: 🎯T2
        - **Status**: not started

        ### 🎯T2 Feature
        - **Weight**: 3 (value 8 / cost 3)
        - **Status**: not started
    """, mermaid=True)
    assert rc == 0
    assert "T1 -.->|gates| T2" in out


def test_mermaid_depends_edges():
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Foundation
        - **Weight**: 2 (value 5 / cost 3)
        - **Status**: not started

        ### 🎯T2 Dependent
        - **Weight**: 3 (value 8 / cost 3)
        - **Depends on**: 🎯T1
        - **Status**: not started
    """, mermaid=True)
    assert rc == 0
    assert "T2 -.->|needs| T1" in out


def test_deep_nesting():
    """Three-level hierarchy: T1 > T1.1 > T1.1.1."""
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Top
        - **Weight**: 1 (value 10 / cost 10)
        - **Status**: not started

        ### 🎯T1.1 Middle
        - **Weight**: 1 (value 5 / cost 5)
        - **Parent**: 🎯T1
        - **Status**: not started

        ### 🎯T1.1.1 Leaf
        - **Weight**: 2 (value 3 / cost 2)
        - **Parent**: 🎯T1.1
        - **Status**: not started
    """)
    assert rc == 0
    assert "🎯T1 Top" in out
    assert "🎯T1.1 Middle" in out
    assert "🎯T1.1.1 Leaf" in out


def test_decimal_weight_values():
    """Weight with decimal values like 1.5 should parse."""
    out, _, rc = run("""\
        # Targets

        ## Active

        ### 🎯T1 Decimal weights
        - **Weight**: 1.5 (value 7.5 / cost 5)
        - **Status**: not started
    """)
    assert rc == 0
    assert "value: 7.5" in out or "value: 8" in out  # 7.5 displayed
    assert "cost: 5" in out


def test_real_targets_file():
    """Run against the actual CSP targets.md if it exists."""
    targets_path = os.path.join(
        os.path.dirname(__file__), '..', '..', '..', '..', '..', '..',
        'work', 'github.com', 'marcelocantos', 'csp', 'docs', 'targets.md'
    )
    targets_path = os.path.normpath(targets_path)
    if not os.path.exists(targets_path):
        return  # skip if not in the expected location
    result = subprocess.run(
        [sys.executable, RANK_PY, targets_path],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, f"rank.py failed on real targets: {result.stdout}\n{result.stderr}"
    assert "# rank" in result.stdout


if __name__ == '__main__':
    # Simple test runner — find and run all test_ functions
    passed = failed = 0
    tests = [(name, obj) for name, obj in globals().items()
             if name.startswith('test_') and callable(obj)]
    for name, func in sorted(tests):
        try:
            func()
            passed += 1
            print(f"  PASS  {name}")
        except Exception as e:
            failed += 1
            print(f"  FAIL  {name}: {e}")
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
