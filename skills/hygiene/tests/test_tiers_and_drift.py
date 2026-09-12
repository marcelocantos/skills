"""Held tiers, the per-dimension floor ratchet, and drift in both directions.

Drift has two directions and the check must fail on both: a capability that
regressed below its floor, and a declared absence that quietly started being
present. A validator that only caught the first would let hygiene.yaml drift
into fiction from the other side.
"""

import unittest

from support import RepoCase, doc_with

import hygiene_check  # noqa: E402


def item(slug: str, dim: str, tier: int, evidence: str,
         state: str = "present", extra: str = "") -> str:
    return (f"  - id: {dim}.{slug}\n"
            f"    dim: {dim}\n"
            f"    desc: {slug}\n"
            f"    state: {state}\n"
            f"    cadence: continuous\n"
            f"    enforce: warning\n"
            f"    tier: {tier}\n"
            f"{extra}"
            f"    evidence: {evidence}\n")


PRESENT = "{file: {path: there}}"
ABSENT = "{file: {path: not-there}}"


class HeldTier(unittest.TestCase):
    """held_tier in isolation: the highest T with every item at or below it met."""

    @staticmethod
    def items(*pairs):
        return [{"tier": t, "satisfied": s} for t, s in pairs]

    def test_all_met_holds_the_highest_tier(self):
        self.assertEqual(3, hygiene_check.held_tier(
            self.items((1, True), (2, True), (3, True))))

    def test_a_gap_stops_the_ladder_below_it(self):
        self.assertEqual(1, hygiene_check.held_tier(
            self.items((1, True), (2, False), (3, True))))

    def test_a_gap_at_the_lowest_tier_yields_zero(self):
        self.assertEqual(0, hygiene_check.held_tier(
            self.items((1, False), (2, True))))

    def test_a_dimension_starting_at_tier_two_can_still_hold_it(self):
        self.assertEqual(2, hygiene_check.held_tier(
            self.items((2, True), (3, False))))

    def test_untiered_items_do_not_set_a_tier(self):
        self.assertEqual(0, hygiene_check.held_tier(
            self.items((hygiene_check.NO_TIER, True))))


class FloorRatchet(RepoCase):

    def setUp(self):
        super().setUp()
        self.file("there")

    def test_meeting_the_floor_passes(self):
        rep = self.check(doc_with(
            item("a", "correctness", 1, PRESENT) +
            item("b", "correctness", 2, PRESENT),
            floors="correctness: 2"))
        self.assertEqual(2, rep["dims"]["correctness"]["held"])
        self.assertTrue(rep["passed"])

    def test_dropping_below_the_floor_is_drift(self):
        rep = self.check(doc_with(
            item("a", "correctness", 1, PRESENT) +
            item("b", "correctness", 2, ABSENT),
            floors="correctness: 2"))
        self.assertEqual(1, rep["dims"]["correctness"]["held"])
        self.assertFalse(rep["dims"]["correctness"]["ok"])
        self.assertEqual(["correctness"], rep["floor_violations"])
        self.assertFalse(rep["passed"])

    def test_a_gap_parked_above_the_floor_is_not_drift(self):
        rep = self.check(doc_with(
            item("a", "correctness", 1, PRESENT) +
            item("b", "correctness", 3, ABSENT, state="planned",
                 extra="    reason: not wired yet\n"),
            floors="correctness: 1"))
        self.assertTrue(rep["passed"])
        self.assertIn("correctness.b",
                      [g["id"] for g in rep["dims"]["correctness"]["unmet"]])

    def test_floors_are_per_dimension(self):
        rep = self.check(doc_with(
            item("a", "correctness", 2, PRESENT) +
            item("b", "security", 2, ABSENT),
            floors="correctness: 2\n  security: 2"))
        self.assertEqual(["security"], rep["floor_violations"])
        self.assertEqual(2, rep["dims"]["correctness"]["held"])

    def test_an_undeclared_dimension_floors_at_zero(self):
        rep = self.check(doc_with(
            item("b", "security", 1, ABSENT), floors="correctness: 0"))
        self.assertTrue(rep["passed"])
        self.assertEqual(0, rep["dims"]["security"]["floor"])


class NegativeSpace(RepoCase):
    """Declared absences, and what happens when reality contradicts them."""

    def setUp(self):
        super().setUp()
        self.file("there")

    def test_a_holding_skip_is_satisfied(self):
        rep = self.check(doc_with(item(
            "b", "correctness", 1, "{absent: {file: {path: not-there}}}",
            state="skipped", extra="    reason: deliberately not done\n"),
            floors="correctness: 1"))
        self.assertTrue(rep["passed"])
        self.assertTrue(self.result(rep, "correctness.b")["satisfied"])

    def test_a_violated_skip_fails_even_above_the_floor(self):
        rep = self.check(doc_with(item(
            "b", "correctness", 3, "{absent: {file: {path: there}}}",
            state="skipped", extra="    reason: deliberately not done\n"),
            floors="correctness: 0"))
        r = self.result(rep, "correctness.b")
        self.assertEqual("SKIP VIOLATED — declared skipped but present",
                         r["advisory"])
        self.assertEqual(["correctness.b"],
                         [v["id"] for v in rep["skip_violations"]])
        self.assertFalse(rep["passed"], "a lying skip must fail the check")

    def test_a_closed_gap_is_advised_not_silently_kept_open(self):
        rep = self.check(doc_with(item(
            "b", "correctness", 3, "{absent: {file: {path: there}}}",
            state="planned", extra="    reason: not wired yet\n"),
            floors="correctness: 0"))
        r = self.result(rep, "correctness.b")
        self.assertFalse(r["satisfied"])
        self.assertIn("reality outran declaration", r["advisory"])


class DeclarationErrors(RepoCase):

    def setUp(self):
        super().setUp()
        self.file("there")

    def test_planned_without_a_reason_fails(self):
        rep = self.check(doc_with(
            item("b", "correctness", 3, ABSENT, state="planned")))
        self.assertIn("state 'planned' requires a reason", rep["config_errors"])
        self.assertFalse(rep["passed"])

    def test_skipped_without_a_reason_fails(self):
        rep = self.check(doc_with(
            item("b", "correctness", 3, ABSENT, state="skipped")))
        self.assertIn("state 'skipped' requires a reason", rep["config_errors"])

    def test_an_invalid_state_fails(self):
        rep = self.check(doc_with(
            item("b", "correctness", 1, PRESENT, state="mostly")))
        self.assertIn("invalid state 'mostly'", rep["config_errors"])

    def test_an_invalid_enforce_fails(self):
        doc = doc_with(item("b", "correctness", 1, PRESENT)).replace(
            "enforce: warning", "enforce: loud")
        rep = self.check(doc)
        self.assertIn("invalid enforce 'loud'", rep["config_errors"])


if __name__ == "__main__":
    unittest.main()
