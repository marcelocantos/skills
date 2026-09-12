"""Every evidence kind resolves against a real repo, or honestly does not.

Evidence resolution is the whole mechanism: it is what makes drift mechanical
instead of prose. A resolver that silently starts answering "yes" turns the
fleet matrix green without anything improving, which is the failure these
tests exist to catch.
"""

import unittest

from support import RepoCase, doc_with


def one_item(evidence: str, state: str = "present", tier: int = 1,
             extra: str = "") -> str:
    return (f"  - id: correctness.subject\n"
            f"    dim: correctness\n"
            f"    desc: subject under test\n"
            f"    state: {state}\n"
            f"    cadence: continuous\n"
            f"    enforce: warning\n"
            f"    tier: {tier}\n"
            f"{extra}"
            f"    evidence: {evidence}\n")


class FileEvidence(RepoCase):

    def test_present_file_resolves(self):
        self.file("LICENSE", "Apache License\n")
        rep = self.check(doc_with(one_item("{file: {path: LICENSE}}")))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])

    def test_missing_file_does_not_resolve(self):
        rep = self.check(doc_with(one_item("{file: {path: LICENSE}}")))
        r = self.result(rep, "correctness.subject")
        self.assertFalse(r["ok"])
        self.assertIn("missing LICENSE", r["detail"])

    def test_matches_must_also_hold(self):
        self.file("LICENSE", "MIT License\n")
        rep = self.check(doc_with(
            one_item("{file: {path: LICENSE, matches: 'Apache License'}}")))
        r = self.result(rep, "correctness.subject")
        self.assertFalse(r["ok"])
        self.assertIn("not found", r["detail"])

    def test_matches_is_a_regex(self):
        self.file("Makefile", "lint:\n\tcargo clippy --all -- -D warnings\n")
        rep = self.check(doc_with(
            one_item("{file: {path: Makefile, matches: 'cargo clippy .*-D warnings'}}")))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])


class CommandEvidence(RepoCase):

    def test_exit_zero_resolves(self):
        rep = self.check(doc_with(one_item("{command: 'exit 0'}")))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])

    def test_nonzero_exit_does_not_resolve(self):
        rep = self.check(doc_with(one_item("{command: 'exit 3'}")))
        r = self.result(rep, "correctness.subject")
        self.assertFalse(r["ok"])
        self.assertIn("exit 3", r["detail"])

    def test_command_runs_in_the_repo_root(self):
        self.file("marker", "")
        rep = self.check(doc_with(one_item("{command: 'test -f marker'}")))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])


class GitTrackedEvidence(RepoCase):
    """The declared-absence idiom: "no Makefile is TRACKED here".

    An untracked Makefile in the working tree (bullseye_convergence writes
    one) must not read as the repo having adopted a Makefile front door.
    """

    EVIDENCE = "{absent: {command: 'git ls-files --error-unmatch Makefile'}}"

    def setUp(self):
        super().setUp()
        self.git_init()
        self.file("README.md", "# fixture\n")
        self.git_commit_all()

    def test_untracked_makefile_keeps_the_absence_true(self):
        self.file("Makefile", "bullseye:\n\t@true\n")
        rep = self.check(doc_with(one_item(
            self.EVIDENCE, state="skipped",
            extra="    reason: go build is the front door\n")))
        r = self.result(rep, "correctness.subject")
        self.assertTrue(r["ok"], r["detail"])
        self.assertTrue(r["satisfied"])
        self.assertEqual([], rep["skip_violations"])

    def test_tracked_makefile_violates_the_absence(self):
        self.file("Makefile", "all:\n\t@true\n")
        self.git_commit_all("add Makefile")
        rep = self.check(doc_with(one_item(
            self.EVIDENCE, state="skipped",
            extra="    reason: go build is the front door\n")))
        r = self.result(rep, "correctness.subject")
        self.assertFalse(r["ok"])
        self.assertFalse(r["satisfied"])
        self.assertEqual(["correctness.subject"],
                         [v["id"] for v in rep["skip_violations"]])


class WorkflowEvidence(RepoCase):

    WORKFLOW = (
        "name: ci\n"
        "on: [push]\n"
        "jobs:\n"
        "  gate:\n"
        "    runs-on: macos-latest\n"
        "    steps:\n"
        "      - name: Test\n"
        "        run: cargo test\n"
        "  matrixed:\n"
        "    strategy:\n"
        "      matrix:\n"
        "        include:\n"
        "          - name: linux-arm64\n"
        "    steps:\n"
        "      - run: true\n")

    def setUp(self):
        super().setUp()
        self.workflow("ci.yml", self.WORKFLOW)

    def test_ci_job_present(self):
        rep = self.check(doc_with(one_item('{ci_job: "ci.yml#gate"}')))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])

    def test_ci_job_absent(self):
        rep = self.check(doc_with(one_item('{ci_job: "ci.yml#windows"}')))
        self.assertIn("not in ci.yml",
                      self.result(rep, "correctness.subject")["detail"])

    def test_ci_job_missing_workflow(self):
        rep = self.check(doc_with(one_item('{ci_job: "release.yml#build"}')))
        self.assertIn("workflow release.yml not found",
                      self.result(rep, "correctness.subject")["detail"])

    def test_ci_job_matrix_entry(self):
        rep = self.check(doc_with(one_item('{ci_job: "ci.yml#matrixed:linux-arm64"}')))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])
        rep = self.check(doc_with(one_item('{ci_job: "ci.yml#matrixed:win-x64"}')))
        self.assertFalse(self.result(rep, "correctness.subject")["ok"])

    def test_ci_step_by_name(self):
        rep = self.check(doc_with(
            one_item("{ci_step: {workflow: ci.yml, name: Test}}")))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])
        rep = self.check(doc_with(
            one_item("{ci_step: {workflow: ci.yml, name: Clippy}}")))
        self.assertFalse(self.result(rep, "correctness.subject")["ok"])

    def test_scanner_needs_config_and_invocation(self):
        self.file(".gitleaks.toml", "# config\n")
        rep = self.check(doc_with(one_item(
            "{scanner: {tool: gitleaks, config: .gitleaks.toml}}")))
        self.assertFalse(self.result(rep, "correctness.subject")["ok"],
                         "config alone must not satisfy a scanner")

        self.workflow("scan.yml", "jobs:\n  s:\n    steps:\n"
                                  "      - run: gitleaks detect\n")
        rep = self.check(doc_with(one_item(
            "{scanner: {tool: gitleaks, config: .gitleaks.toml}}")))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])


class MakeTargetEvidence(RepoCase):

    def test_target_found_and_missing(self):
        self.file("Makefile", "test:\n\tcargo test\n\nfmt:\n\tcargo fmt\n")
        rep = self.check(doc_with(one_item("{make_target: test}")))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])
        rep = self.check(doc_with(one_item("{make_target: bench}")))
        self.assertFalse(self.result(rep, "correctness.subject")["ok"])


class ManualAndMalformedEvidence(RepoCase):

    def test_manual_attestation_needs_a_date(self):
        rep = self.check(doc_with(
            one_item("{manual: {last_verified: 2026-06-15}}")))
        self.assertTrue(self.result(rep, "correctness.subject")["ok"])
        rep = self.check(doc_with(one_item("{manual: {}}")))
        self.assertFalse(self.result(rep, "correctness.subject")["ok"])

    def test_two_keys_is_malformed(self):
        rep = self.check(doc_with(
            one_item('{ci_job: "ci.yml#gate", script: scripts/win.sh}')))
        r = self.result(rep, "correctness.subject")
        self.assertFalse(r["ok"])
        self.assertIn("need exactly one key", r["detail"])

    def test_unknown_kind_is_reported(self):
        rep = self.check(doc_with(one_item("{smoke: scripts/smoke.sh}")))
        self.assertIn("unknown evidence kind",
                      self.result(rep, "correctness.subject")["detail"])

    def test_no_evidence_at_all(self):
        item = ("  - id: correctness.subject\n"
                "    dim: correctness\n"
                "    desc: subject\n"
                "    state: present\n"
                "    cadence: continuous\n"
                "    enforce: warning\n"
                "    tier: 1\n")
        rep = self.check(doc_with(item))
        self.assertIn("no evidence declared",
                      self.result(rep, "correctness.subject")["detail"])


if __name__ == "__main__":
    unittest.main()
