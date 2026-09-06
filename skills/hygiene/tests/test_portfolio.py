"""The fleet aggregator over a fixture fleet of three tiny repos.

Run as a subprocess against a temp `--root`, so the test covers the script as
the skill actually invokes it: discovery, per-repo checking, the JSON contract
the fleet queries read, and the text matrix a human reads.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from support import SKILL_DIR, write

PORTFOLIO = SKILL_DIR / "hygiene_portfolio.py"

GREEN = """
schema_version: 1
repo: green
aspires: 3
floors:
  correctness: 2
  security: 1
items:
  - id: correctness.tests
    dim: correctness
    desc: tests run
    state: enforced
    cadence: continuous
    enforce: blocking
    tier: 1
    evidence: {file: {path: Makefile, matches: 'go test'}}
  - id: correctness.race
    dim: correctness
    desc: race detector
    state: enforced
    cadence: continuous
    enforce: warning
    tier: 2
    evidence: {file: {path: Makefile, matches: '-race'}}
  - id: security.gitignore
    dim: security
    desc: gitignore present
    state: present
    cadence: once-must-hold
    enforce: warning
    tier: 1
    evidence: {file: {path: .gitignore}}
"""

DRIFTED = """
schema_version: 1
repo: drifted
aspires: 3
floors:
  correctness: 2
items:
  - id: correctness.tests
    dim: correctness
    desc: tests run
    state: enforced
    cadence: continuous
    enforce: blocking
    tier: 1
    evidence: {file: {path: Makefile, matches: 'go test'}}
  - id: correctness.race
    dim: correctness
    desc: race detector
    state: enforced
    cadence: continuous
    enforce: warning
    tier: 2
    evidence: {file: {path: Makefile, matches: '-race'}}
"""

BROKEN = "schema_version: 1\nrepo: broken\nitems: [\n"


class Fleet(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls._tmp.name)
        fleet = cls.root / "github.com" / "acme"

        write(fleet / "green" / "hygiene.yaml", GREEN)
        write(fleet / "green" / "Makefile", "test:\n\tgo test -race ./...\n")
        write(fleet / "green" / ".gitignore", "bin/\n")

        # Same declaration, but the race flag is gone from the gate: the
        # capability regressed and correctness must fall below its floor.
        write(fleet / "drifted" / "hygiene.yaml", DRIFTED)
        write(fleet / "drifted" / "Makefile", "test:\n\tgo test ./...\n")

        write(fleet / "broken" / "hygiene.yaml", BROKEN)

        # Not a repo declaration: discovery must not pick it up.
        write(cls.root / "github.com" / "acme" / "green" / "docs" / "notes.md",
              "not a hygiene file\n")

        cls.json = cls.run_portfolio("--json")
        cls.report = json.loads(cls.json)

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    @classmethod
    def run_portfolio(cls, *args) -> str:
        proc = subprocess.run(
            [sys.executable, str(PORTFOLIO), "--root", str(cls.root), *args],
            capture_output=True, text=True, timeout=120)
        assert proc.returncode == 0, proc.stderr
        return proc.stdout

    def repo(self, name):
        for r in self.report["repos"]:
            if r["repo"] == name:
                return r
        raise AssertionError(f"{name} not in {[r['repo'] for r in self.report['repos']]}")

    def test_discovers_every_declaring_repo_and_nothing_else(self):
        self.assertEqual({"green", "drifted", "broken"},
                         {r["repo"] for r in self.report["repos"]})

    def test_a_green_repo_holds_its_tiers(self):
        r = self.repo("green")
        self.assertTrue(r["passed"])
        self.assertEqual(2, r["dims"]["correctness"]["held"])
        self.assertEqual(1, r["dims"]["security"]["held"])

    def test_a_regressed_capability_shows_as_drift(self):
        r = self.repo("drifted")
        self.assertFalse(r["passed"])
        self.assertEqual(1, r["dims"]["correctness"]["held"])
        self.assertEqual(["correctness"], r["floor_violations"])

    def test_one_unparseable_repo_does_not_sink_the_fleet(self):
        self.assertIn("error", self.repo("broken"))
        self.assertTrue(self.repo("green")["passed"],
                        "a broken sibling must not affect other repos")

    def test_text_matrix_marks_drift_and_lists_gaps(self):
        text = self.run_portfolio()
        self.assertIn("corr", text)
        drift_rows = [ln for ln in text.splitlines() if "DRIFT" in ln]
        self.assertEqual(1, len(drift_rows), text)
        self.assertTrue(drift_rows[0].startswith("drifted"), drift_rows)
        self.assertIn("fleet gaps", text)

    def test_empty_root_is_not_an_error(self):
        with tempfile.TemporaryDirectory() as empty:
            proc = subprocess.run(
                [sys.executable, str(PORTFOLIO), "--root", empty],
                capture_output=True, text=True, timeout=120)
            self.assertEqual(0, proc.returncode)
            self.assertIn("no hygiene.yaml found", proc.stdout)


if __name__ == "__main__":
    unittest.main()
