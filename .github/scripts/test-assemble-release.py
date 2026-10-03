#!/usr/bin/env python3
"""Exercise the release publisher used by CI, including partial reruns."""

import json
import subprocess
import unittest
from pathlib import Path


FILTER = Path(__file__).with_name("assemble-release.jq")
COMMIT = "a" * 40


def target(host, revision="old"):
    return {"host": host, "agent": host, "storePath": f"/nix/store/{revision}-{host}"}


class AssembleReleaseTests(unittest.TestCase):
    def assemble(self, targets, attempt=1, matrix=None):
        if matrix is None:
            matrix = [
                {"name": "kiwi", "agent": "kiwi", "deploy": True},
                {"name": "portal", "agent": "portal", "deploy": True},
                {"name": "banana", "agent": "banana", "deploy": False},
            ]
        return subprocess.run(
            [
                "jq", "-s", "--arg", "commit", COMMIT,
                "--argjson", "runId", "123", "--argjson", "runAttempt", str(attempt),
                "--argjson", "matrix", json.dumps({"include": matrix}), "-f", str(FILTER),
            ],
            input="\n".join(json.dumps(item) for item in targets),
            text=True, capture_output=True, check=False,
        )

    def test_complete_release_preserves_source_and_exact_paths(self):
        result = self.assemble([target("portal"), target("kiwi")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {
            "commit": COMMIT, "runId": 123, "runAttempt": 1,
            "targets": [target("kiwi"), target("portal")],
        })

    def test_partial_rerun_reuses_unrebuilt_hosts_in_a_new_snapshot(self):
        first = json.loads(self.assemble([target("kiwi"), target("portal")]).stdout)
        rerun = self.assemble([target("kiwi", "new"), target("portal")], attempt=2)
        self.assertEqual(rerun.returncode, 0, rerun.stderr)
        second = json.loads(rerun.stdout)
        self.assertEqual(second["runAttempt"], 2)
        self.assertEqual(second["targets"], [target("kiwi", "new"), target("portal")])
        self.assertEqual(first["targets"][0], target("kiwi"))

    def test_missing_duplicate_or_misrouted_fragments_fail(self):
        for targets in ([target("kiwi")], [target("kiwi"), target("kiwi")],
                        [target("kiwi"), {**target("portal"), "agent": "wrong"}]):
            with self.subTest(targets=targets):
                result = self.assemble(targets)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("do not match", result.stderr)

    def test_duplicate_agents_in_inventory_fail(self):
        targets = [target("kiwi"), {**target("portal"), "agent": "kiwi"}]
        matrix = [{"name": item["host"], "agent": item["agent"], "deploy": True}
                  for item in targets]
        result = self.assemble(targets, matrix=matrix)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("agents must be unique", result.stderr)


if __name__ == "__main__":
    unittest.main()
