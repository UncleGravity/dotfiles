#!/usr/bin/env python3
"""Focused release tests with real manifest files and mocked GitHub commands."""

import contextlib
import copy
import importlib.util
import io
import json
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "prepare_deployment", Path(__file__).with_name("prepare-deployment.py")
)
DEPLOYMENT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DEPLOYMENT)
REPOSITORY = "UncleGravity/dotfiles"
COMMIT = "a" * 40


def target(host="kiwi", agent=None):
    return {
        "host": host,
        "agent": agent or host,
        "storePath": f"/nix/store/{'0' * 32}-nixos-system-{host}-26.05",
    }


def environment(host="kiwi"):
    return {
        "name": host,
        "can_admins_bypass": False,
        "protection_rules": [{"type": "required_reviewers", "reviewers": [{"id": 42}]}],
    }


class PrepareDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.run = {
            "id": 123,
            "run_attempt": 2,
            "head_sha": COMMIT,
            "path": ".github/workflows/ci.yml",
            "status": "completed",
            "conclusion": "success",
            "event": "push",
            "head_branch": "main",
            "repository": {"full_name": REPOSITORY},
            "head_repository": {"full_name": REPOSITORY},
        }
        self.manifest = {"commit": COMMIT, "runId": 123, "runAttempt": 2, "targets": [target()]}
        self.environments = {"environments": [environment()]}
        self.commands = []
        self.download_error = False
        self.write_manifest = True
        self.raw_manifest = None
        command_patch = patch.object(DEPLOYMENT.subprocess, "run", side_effect=self.fake_gh)
        command_patch.start()
        self.addCleanup(command_patch.stop)

    def fake_gh(self, command, **kwargs):
        self.commands.append(command)
        if command[1:3] == ["run", "download"]:
            if self.download_error:
                raise subprocess.CalledProcessError(1, command, stderr="artifact expired")
            if self.write_manifest:
                directory = Path(command[command.index("--dir") + 1])
                content = self.raw_manifest if self.raw_manifest is not None else json.dumps(self.manifest)
                (directory / "release.json").write_text(content, encoding="utf-8")
            return subprocess.CompletedProcess(command, 0, stdout="")
        if command[1] == "api":
            payload = self.environments if "/environments?" in command[2] else self.run
            return subprocess.CompletedProcess(command, 0, stdout=json.dumps(payload))
        self.fail(f"unexpected GitHub command: {command}")

    def prepare(self, **kwargs):
        return DEPLOYMENT.prepare_release(REPOSITORY, "123", **kwargs)

    def test_valid_release_parses_real_manifest_and_ignores_extra_metadata(self):
        self.manifest["description"] = "optional metadata"
        self.manifest["targets"] = [target("spark-02"), target("kiwi", "kiwi-agent")]
        self.manifest["targets"][0]["extra"] = "ignored"
        self.environments["environments"].append(environment("spark-02"))
        release = self.prepare()
        self.assertEqual(release["hosts"], ["kiwi", "spark-02"])
        self.assertEqual(release["commit"], COMMIT)
        self.assertEqual(release["buildRunId"], 123)
        self.assertEqual(release["matrix"]["include"], [target("kiwi", "kiwi-agent"), target("spark-02")])
        download = self.commands[1]
        self.assertEqual(download[download.index("--name") + 1], "release-2")
        self.assertFalse(Path(download[download.index("--dir") + 1]).exists())

    def test_wrong_source_is_rejected_before_any_download(self):
        cases = [
            ("conclusion", "failure"), ("status", "in_progress"),
            ("event", "pull_request"), ("head_branch", "feature"),
            ("path", ".github/workflows/deploy.yml"), ("id", 124),
            ("repository", {"full_name": "other/repo"}),
            ("head_repository", {"full_name": "attacker/dotfiles"}),
        ]
        original = copy.deepcopy(self.run)
        for field, value in cases:
            with self.subTest(field=field):
                self.run = {**original, field: value}
                self.commands.clear()
                with self.assertRaises(DEPLOYMENT.DeploymentError):
                    self.prepare()
                self.assertEqual(len(self.commands), 1)
                self.assertEqual(self.commands[0][1], "api")

    def test_invalid_request_identifiers_make_no_github_calls(self):
        for run_id, attempt in (("0", ""), ("123/other", ""), ("123", "-1")):
            with self.subTest(run_id=run_id, attempt=attempt):
                with self.assertRaises(DEPLOYMENT.DeploymentError):
                    DEPLOYMENT.prepare_release(REPOSITORY, run_id, attempt)
        self.assertEqual(self.commands, [])

    def test_requested_attempt_uses_the_attempt_endpoint(self):
        self.prepare(attempt="2")
        self.assertEqual(self.commands[0], ["gh", "api", f"repos/{REPOSITORY}/actions/runs/123/attempts/2"])

    def test_manifest_must_match_source_commit_run_and_attempt(self):
        for field, value in (("commit", "b" * 40), ("runId", 124), ("runAttempt", 1)):
            with self.subTest(field=field):
                manifest = {"commit": COMMIT, "runId": 123, "runAttempt": 2, "targets": [target()]}
                self.manifest = {**manifest, field: value}
                with self.assertRaisesRegex(DEPLOYMENT.DeploymentError, "manifest does not match"):
                    self.prepare()

    def test_empty_manifest_cannot_create_an_empty_deployment_matrix(self):
        self.manifest["targets"] = []
        with self.assertRaisesRegex(DEPLOYMENT.DeploymentError, "release manifest has no targets"):
            self.prepare()

    def test_duplicate_hosts_with_distinct_agents_are_rejected(self):
        self.manifest["targets"] = [target(), target("kiwi", "other-agent")]
        with self.assertRaisesRegex(DEPLOYMENT.DeploymentError, "duplicate target host: kiwi"):
            self.prepare()

    def test_duplicate_agents_with_distinct_hosts_are_rejected(self):
        self.manifest["targets"] = [target(), target("portal", "kiwi")]
        self.environments["environments"].append(environment("portal"))
        with self.assertRaisesRegex(DEPLOYMENT.DeploymentError, "duplicate target agent: kiwi"):
            self.prepare()

    def test_selection_only_requires_selected_host_gates(self):
        self.manifest["targets"].append(target("new-host"))
        self.assertEqual(self.prepare(hosts=" kiwi ")["hosts"], ["kiwi"])
        for hosts in ("unknown", "kiwi, kiwi", "kiwi,", ","):
            with self.subTest(hosts=hosts):
                with self.assertRaises(DEPLOYMENT.DeploymentError):
                    self.prepare(hosts=hosts)

    def test_missing_reviewer_gate_and_admin_bypass_are_rejected(self):
        cases = [
            [], [{"name": "kiwi", "can_admins_bypass": False}],
            [{**environment(), "can_admins_bypass": True}],
            [{**environment(), "protection_rules": [{"type": "required_reviewers", "reviewers": []}]}],
        ]
        for environments in cases:
            with self.subTest(environments=environments):
                self.environments = {"environments": environments}
                with self.assertRaises(DEPLOYMENT.DeploymentError):
                    self.prepare()

    def test_self_review_policy_and_reviewer_schema_are_not_enforced(self):
        rule = self.environments["environments"][0]["protection_rules"][0]
        rule["prevent_self_review"] = True
        rule["reviewers"] = [{"type": "Team", "reviewer": {"name": "operators"}}]
        self.assertEqual(self.prepare()["hosts"], ["kiwi"])

    def test_basic_name_and_path_constraints_without_hostname_coupling(self):
        self.manifest["targets"][0]["storePath"] = f"/nix/store/{'0' * 32}-nixos-system-another-name-26.05"
        self.prepare()
        cases = (
            ("host", "../kiwi", "target host must be a safe lowercase name"),
            ("agent", "agent,other", "target agent must be a safe lowercase name"),
            ("storePath", "/tmp/activate", "target must have a valid Nix store path"),
        )
        for field, value, message in cases:
            with self.subTest(field=field):
                self.manifest["targets"] = [{**target(), field: value}]
                with self.assertRaisesRegex(DEPLOYMENT.DeploymentError, message):
                    self.prepare()

    def test_download_failure_and_real_manifest_read_errors_are_reported(self):
        self.download_error = True
        with self.assertRaisesRegex(DEPLOYMENT.DeploymentError, "GitHub command failed: artifact expired"):
            self.prepare()
        self.download_error = False
        self.write_manifest = False
        with self.assertRaisesRegex(DEPLOYMENT.DeploymentError, "cannot read release.json"):
            self.prepare()
        self.write_manifest = True
        self.raw_manifest = "{invalid JSON"
        with self.assertRaisesRegex(DEPLOYMENT.DeploymentError, "cannot read release.json"):
            self.prepare()

    def test_cli_success_and_source_failure(self):
        arguments = ["--repository", REPOSITORY, "--run-id", "123", "--hosts", " kiwi "]
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = DEPLOYMENT.main(arguments)
        self.assertEqual(result, 0)
        self.assertEqual(json.loads(stdout.getvalue())["hosts"], ["kiwi"])
        self.assertEqual(stderr.getvalue(), "")
        self.run["event"] = "pull_request"
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = DEPLOYMENT.main(arguments)
        self.assertEqual(result, 1)
        self.assertEqual(stdout.getvalue(), "")
        self.assertEqual(stderr.getvalue(), "error: source CI run must be a push to main\n")


if __name__ == "__main__":
    unittest.main()
