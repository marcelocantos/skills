"""Fixtures shared by the hygiene tests: throwaway repos and a fake `gh`.

A hygiene check reads the filesystem, shells out to git, and asks GitHub about
the repo. All three are cheap to fake honestly — a real temp directory, a real
`git init`, and a real executable named `gh` earlier on PATH — so the tests
exercise the resolvers rather than a mock of them.
"""

import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SKILL_DIR))

import hygiene_check  # noqa: E402

# A repo object shaped like the fields hygiene.yaml files actually ask about.
# `security_and_analysis: null` is the case that matters: a private repo
# without advanced security, where jq must yield empty rather than raise.
FAKE_REPO_JSON = """{
  "name": "fixture",
  "private": true,
  "default_branch": "master",
  "allow_merge_commit": false,
  "delete_branch_on_merge": true,
  "open_issues": 3,
  "security_and_analysis": null
}"""


def write(path: Path, content: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content).lstrip("\n"))
    return path


class RepoCase(unittest.TestCase):
    """A test case owning one temp directory, with helpers to fill it."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.root = self.tmp / "repo"
        self.root.mkdir()
        # Defensive: if the cache is ever removed, the "one fetch per repo"
        # test should fail on its own terms rather than every test erroring
        # on a missing attribute.
        clear = getattr(hygiene_check.gh_repo_json, "cache_clear", lambda: None)
        clear()
        self.addCleanup(clear)

    # --- filling the repo ---------------------------------------------

    def file(self, relpath: str, content: str = "x\n") -> Path:
        return write(self.root / relpath, content)

    def workflow(self, name: str, content: str) -> Path:
        return write(self.root / ".github" / "workflows" / name, content)

    def git_init(self) -> None:
        """A real repo, so `git ls-files` and remote parsing are real too."""
        run = lambda *a: subprocess.run(  # noqa: E731 - one-line git shorthand
            ["git", "-C", str(self.root), *a], check=True,
            capture_output=True, text=True)
        run("init", "-q", "-b", "master")
        run("config", "user.email", "fixture@example.invalid")
        run("config", "user.name", "Fixture")
        run("remote", "add", "origin", "git@github.com:acme/fixture.git")

    def git_commit_all(self, message: str = "fixture") -> None:
        subprocess.run(["git", "-C", str(self.root), "add", "-A"],
                       check=True, capture_output=True)
        subprocess.run(["git", "-C", str(self.root), "commit", "-qm", message],
                       check=True, capture_output=True)

    # --- faking gh -----------------------------------------------------

    def fake_gh(self, body: str = FAKE_REPO_JSON, exit_code: int = 0) -> Path:
        """Put an executable `gh` on PATH that logs each call and prints body.

        Returns the log path; one line per invocation, which is how the
        "one fetch per repo, not one per item" behaviour is asserted.
        """
        bindir = self.tmp / "bin"
        bindir.mkdir(exist_ok=True)
        log = self.tmp / "gh-calls.log"
        script = bindir / "gh"
        script.write_text(
            "#!/bin/sh\n"
            f'echo "$@" >> {log}\n'
            f"cat <<'GH_BODY'\n{body}\nGH_BODY\n"
            f"exit {exit_code}\n")
        script.chmod(0o755)
        old_path = os.environ["PATH"]
        os.environ["PATH"] = f"{bindir}{os.pathsep}{old_path}"
        self.addCleanup(os.environ.__setitem__, "PATH", old_path)
        return log

    @staticmethod
    def gh_call_count(log: Path) -> int:
        return len(log.read_text().splitlines()) if log.exists() else 0

    # --- running the check ---------------------------------------------

    def check(self, doc: str) -> dict:
        write(self.root / "hygiene.yaml", doc)
        return hygiene_check.check_repo(self.root)

    def result(self, report: dict, item_id: str) -> dict:
        for r in report["results"]:
            if r["id"] == item_id:
                return r
        raise AssertionError(f"no result for {item_id}: "
                             f"{[r['id'] for r in report['results']]}")


def doc_with(items: str, floors: str = "correctness: 0") -> str:
    """A minimal hygiene.yaml around the items under test.

    `items` is spliced in verbatim, so callers write it at YAML indentation
    rather than at Python indentation — dedenting a list of mappings would
    destroy the structure being tested.
    """
    return (f"schema_version: 1\nrepo: fixture\naspires: 3\n"
            f"floors:\n  {floors}\nitems:\n{items}")
