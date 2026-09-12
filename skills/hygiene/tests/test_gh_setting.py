"""gh_setting evidence, against a fake `gh` on PATH.

Two properties matter. The comparison must reproduce what `gh api … --jq`
printed, because every declaration in the fleet was written against that
output — a repo with no advanced-security block reads empty, not "null" and
not an exception. And the repo object must be fetched once per repo, not once
per item: 241 items across the fleet at ~0.6 s each is the difference between
a fleet check of seconds and one of minutes.
"""

import unittest

from support import RepoCase, doc_with  # sets sys.path for the import below

import hygiene_check  # noqa: E402


def setting_item(slug: str, key: str, equals: str, tier: int = 1) -> str:
    return (f"  - id: correctness.{slug}\n"
            f"    dim: correctness\n"
            f"    desc: {key}\n"
            f"    state: enforced\n"
            f"    cadence: once-must-hold\n"
            f"    enforce: warning\n"
            f"    tier: {tier}\n"
            f"    evidence: {{gh_setting: {{key: {key}, equals: {equals}}}}}\n")


class GhJqValue(unittest.TestCase):
    """The local stand-in for `gh api --jq`, exercised directly."""

    OBJ = {"private": True, "allow_merge_commit": False,
           "default_branch": "master", "open_issues": 3,
           "security_and_analysis": None,
           "nested": {"deep": {"status": "enabled"}}}

    def value(self, key):
        return hygiene_check.gh_jq_value(self.OBJ, key)

    def test_booleans_print_lowercase(self):
        self.assertEqual("true", self.value("private"))
        self.assertEqual("false", self.value("allow_merge_commit"))

    def test_strings_print_bare(self):
        self.assertEqual("master", self.value("default_branch"))

    def test_numbers_print_as_digits(self):
        self.assertEqual("3", self.value("open_issues"))

    def test_missing_key_is_empty(self):
        self.assertEqual("", self.value("no_such_key"))

    def test_indexing_through_null_is_empty_not_an_error(self):
        # The orthograph case: a private repo with no advanced-security block.
        self.assertEqual(
            "", self.value("security_and_analysis.secret_scanning.status"))

    def test_nested_path_resolves(self):
        self.assertEqual("enabled", self.value("nested.deep.status"))


class GhSettingResolution(RepoCase):

    def setUp(self):
        super().setUp()
        self.git_init()
        self.log = self.fake_gh()

    def test_matching_setting_resolves(self):
        rep = self.check(doc_with(
            setting_item("squash", "allow_merge_commit", "false")))
        r = self.result(rep, "correctness.squash")
        self.assertTrue(r["ok"], r["detail"])

    def test_mismatching_setting_does_not_resolve(self):
        rep = self.check(doc_with(
            setting_item("squash", "allow_merge_commit", "true")))
        r = self.result(rep, "correctness.squash")
        self.assertFalse(r["ok"])
        self.assertIn("allow_merge_commit=false", r["detail"])

    def test_absent_advanced_security_reads_empty(self):
        rep = self.check(doc_with(setting_item(
            "secret-scan", "security_and_analysis.secret_scanning.status",
            "enabled")))
        r = self.result(rep, "correctness.secret-scan")
        self.assertFalse(r["ok"])
        self.assertIn("status= (want enabled)", r["detail"])

    def test_repo_object_is_fetched_once_for_many_items(self):
        doc = doc_with(
            setting_item("squash", "allow_merge_commit", "false")
            + setting_item("branch", "default_branch", "master")
            + setting_item("delete", "delete_branch_on_merge", "true")
            + setting_item("private", "private", "true"))
        rep = self.check(doc)
        self.assertTrue(all(self.result(rep, f"correctness.{s}")["ok"]
                            for s in ("squash", "branch", "delete", "private")))
        self.assertEqual(1, self.gh_call_count(self.log),
                         "four gh_setting items must share one gh api call")

    def test_gh_failure_is_reported_not_raised(self):
        hygiene_check.gh_repo_json.cache_clear()
        self.fake_gh(body="not found", exit_code=1)
        rep = self.check(doc_with(
            setting_item("squash", "allow_merge_commit", "false")))
        r = self.result(rep, "correctness.squash")
        self.assertFalse(r["ok"])
        self.assertIn("gh api error", r["detail"])


class GhSettingWithoutRemote(RepoCase):

    def test_no_origin_means_no_owner_repo(self):
        self.fake_gh()
        rep = self.check(doc_with(
            setting_item("squash", "allow_merge_commit", "false")))
        r = self.result(rep, "correctness.squash")
        self.assertFalse(r["ok"])
        self.assertIn("could not derive owner/repo", r["detail"])


if __name__ == "__main__":
    unittest.main()
