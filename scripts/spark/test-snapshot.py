#!/usr/bin/env python3
"""Offline regression tests for the TP4 snapshot collector."""

import contextlib
import copy
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch


SPEC = importlib.util.spec_from_file_location("snapshot", Path(__file__).with_name("snapshot.py"))
SNAPSHOT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SNAPSHOT)


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.args = SimpleNamespace(instance="fixture", since="today", identity=None, endpoint="http://fixture", nodes=[f"rank-{rank}" for rank in range(4)])
        self.container = {
            "Id": "container", "Image": "image", "ImageName": "fixture:latest",
            "Config": {"Env": ["INFER_WORLD_SIZE=4", "INFER_RANK=0"], "Cmd": ["--max-model-len", "1048576"]},
            "State": {"Running": True},
        }
        self.responses = {}
        self.ssh_patch = patch.object(SNAPSHOT, "ssh", side_effect=self.fake_ssh)
        self.fetch_patch = patch.object(SNAPSHOT, "fetch", return_value={"status": 200, "body": ""})
        self.ssh_patch.start()
        self.fetch_patch.start()
        self.addCleanup(self.ssh_patch.stop)
        self.addCleanup(self.fetch_patch.stop)

    def fake_ssh(self, args, node, command):
        if command[0] == "sudo":
            name = command[2]
        elif command[0] == "cat":
            name = Path(command[-1]).name
        else:
            name = command[0]
        if name in self.responses:
            return self.responses[name]
        outputs = {
            "podman": json.dumps([self.container]), "journalctl": "", "sysctl": "vm.swappiness = 1\n",
            "meminfo": "MemAvailable: 1048576 kB\n", "vmstat": "pswpout 3\n",
            "systemctl": "ActiveState=active\nControlGroup=/fixture\n", "nvidia-smi": "GPU-fixture\n",
            "memory.events": "oom 0\noom_kill 0\n", "infer": "{}",
        }
        if name not in outputs:
            raise AssertionError(f"Unexpected offline command: {command}")
        return {"exit_code": 0, "stdout": outputs[name], "stderr": ""}

    def valid_nodes(self):
        return [{"node": f"rank-{rank}", "errors": [], "container": {
            "environment": {"INFER_WORLD_SIZE": "4", "INFER_RANK": str(rank)},
            "image_id": "image", "args": ["--max-model-len", "1048576"], "state": {"Running": True},
        }} for rank in range(4)]

    def test_numbers_and_empty_values(self):
        self.assertEqual(SNAPSHOT.parse_numbers("MemAvailable: 42 kB\nEmpty: \nBad: x\n", ":"), {"MemAvailable": 42})
        self.assertEqual(SNAPSHOT.parse_numbers("oom 0\npgmajfault 12\n"), {"oom": 0, "pgmajfault": 12})

    def test_nested_secret_redaction_preserves_operational_limits(self):
        fixture = {"nodePlans": [{"container": {"environment": {
            "VLLM_API_KEY": "secret-a", "HF_TOKEN": "secret-b", "INFER_SECRET": "secret-c",
            "PASSWORD": "secret-d", "CREDENTIAL": "secret-e", "apiKey": "secret-f",
            "MODEL_LENGTH": "1048576", "MAX_TOKENS": "128", "TOKEN_COUNT": 17,
            "maxNumBatchedTokens": 8192,
        }}}]}
        original = copy.deepcopy(fixture)
        value = SNAPSHOT.redact(fixture)
        env = value["nodePlans"][0]["container"]["environment"]
        for key in ("VLLM_API_KEY", "HF_TOKEN", "INFER_SECRET", "PASSWORD", "CREDENTIAL", "apiKey"):
            self.assertEqual(env[key], SNAPSHOT.REDACTED)
        for key in ("MODEL_LENGTH", "MAX_TOKENS", "TOKEN_COUNT", "maxNumBatchedTokens"):
            self.assertEqual(env[key], original["nodePlans"][0]["container"]["environment"][key])
        self.assertEqual(fixture, original)

    def test_env_entries_and_cli_credentials(self):
        values = ["HF_TOKEN=fixture-secret", "MAX_TOKENS=128", "--api-key", "fixture-secret", "--password=fixture-secret"]
        result = SNAPSHOT.redact(values)
        self.assertNotIn("fixture-secret", json.dumps(result))
        self.assertEqual(result[1], "MAX_TOKENS=128")
        self.assertEqual(result[2], "--api-key")

    def test_container_redacts_allowed_secret_environment(self):
        self.container["Config"]["Env"] += ["VLLM_API_KEY=fixture-secret", "HF_TOKEN=filtered-secret", "VLLM_MAX_TOKENS=128"]
        node = SNAPSHOT.snapshot_node(self.args, "rank-0", full=True)
        self.assertNotIn("fixture-secret", json.dumps(node))
        self.assertNotIn("filtered-secret", json.dumps(node))
        self.assertEqual(node["container"]["environment"]["VLLM_MAX_TOKENS"], "128")

    def test_failed_inspect_never_saves_raw_stdout(self):
        self.responses["podman"] = {"exit_code": 1, "stdout": "fixture-secret", "stderr": "permission denied"}
        node = SNAPSHOT.snapshot_node(self.args, "rank-0", full=True)
        self.assertNotIn("fixture-secret", json.dumps(node))
        self.assertEqual(node["errors"][0]["command"], "container")
        self.assertIn("gpu", node)

    def test_malformed_inspect_preserves_other_diagnostics(self):
        for raw in ("not JSON fixture-secret", "[]", "null", '[{"Config": null}]'):
            with self.subTest(raw=raw):
                self.responses["podman"] = {"exit_code": 0, "stdout": raw, "stderr": ""}
                node = SNAPSHOT.snapshot_node(self.args, "rank-0", full=True)
                self.assertTrue(node["errors"])
                self.assertIn("gpu", node)
                self.assertNotIn("fixture-secret", json.dumps(node))

    def test_cgroup_failure_is_recorded(self):
        self.responses["memory.events"] = {"exit_code": 1, "stdout": "", "stderr": "permission denied"}
        node = SNAPSHOT.snapshot_node(self.args, "rank-0", full=False)
        self.assertEqual(node["errors"][0]["command"], "memory_events")

    def test_boot_identity_is_collected_only_for_cumulative_guards(self):
        self.responses["boot_id"] = {"exit_code": 0, "stdout": "fixture-boot\n", "stderr": ""}
        self.assertNotIn("boot_id", SNAPSHOT.snapshot_node(self.args, "rank-0", full=False))
        self.args.max_new_swapout_pages = 0
        self.assertEqual(SNAPSHOT.snapshot_node(self.args, "rank-0", full=False)["boot_id"], "fixture-boot")
        self.args.max_new_swapout_pages = None
        self.args.fail_on_new_oom = True
        self.assertEqual(SNAPSHOT.snapshot_node(self.args, "rank-0", full=False)["boot_id"], "fixture-boot")

    def test_no_kernel_matches_is_not_an_error(self):
        self.responses["journalctl"] = {"exit_code": 1, "stdout": "-- No entries --\n", "stderr": ""}
        node = SNAPSHOT.snapshot_node(self.args, "rank-0", full=True)
        self.assertEqual(node["errors"], [])
        self.assertEqual(node["kernel"], "")

    def test_valid_tp4(self):
        self.assertEqual(SNAPSHOT.validate_tp4(self.valid_nodes()), [])

    def test_invalid_tp4_fields_do_not_crash(self):
        for field, value in (("args", ["--max-model-len"]), ("args", None), ("state", None), ("state", "invalid"), ("environment", None)):
            with self.subTest(field=field, value=value):
                nodes = self.valid_nodes()
                nodes[0]["container"][field] = value
                self.assertTrue(SNAPSHOT.validate_tp4(nodes))

    def test_mismatched_topology_and_image_fail_validation(self):
        nodes = self.valid_nodes()
        nodes[1]["container"]["environment"]["INFER_RANK"] = "0"
        nodes[2]["container"]["environment"]["INFER_WORLD_SIZE"] = "2"
        nodes[3]["container"]["image_id"] = "different"
        self.assertEqual(len(SNAPSHOT.validate_tp4(nodes)), 3)

    def test_failed_plan_and_metrics_are_fatal(self):
        self.responses["infer"] = {"exit_code": 1, "stdout": "fixture-secret", "stderr": "failed"}
        with patch.object(SNAPSHOT, "snapshot_node", side_effect=lambda args, node, full: self.valid_nodes()[int(node[-1])]), patch.object(SNAPSHOT, "fetch", side_effect=[{"status": 200}, {"error": "offline"}]):
            report = SNAPSHOT.capture(self.args, full=True)
        self.assertNotIn("fixture-secret", json.dumps(report))
        self.assertIn("infer plan failed", SNAPSHOT.collection_errors(report))
        self.assertIn("api_metrics check failed", SNAPSHOT.collection_errors(report))

    def test_invalid_plan_is_reported_without_raw_stdout(self):
        for raw in ("fixture-secret", "[]"):
            with self.subTest(raw=raw):
                self.responses["infer"] = {"exit_code": 0, "stdout": raw, "stderr": ""}
                report = SNAPSHOT.capture(self.args, full=True)
                self.assertTrue(report["collection_errors"])
                self.assertNotIn("fixture-secret", json.dumps(report))

    def test_plan_is_recursively_redacted(self):
        self.responses["infer"] = {"exit_code": 0, "stdout": json.dumps({"environment": {"HF_TOKEN": "fixture-secret", "MAX_TOKENS": "128"}}), "stderr": ""}
        report = SNAPSHOT.capture(self.args, full=True)
        self.assertNotIn("fixture-secret", json.dumps(report))
        self.assertEqual(report["plan"]["environment"]["MAX_TOKENS"], "128")

    def test_watch_failure_returns_nonzero_and_missing_memory_is_null(self):
        row = {"sampled_at": "fixture", "nodes": [{"node": "rank-0", "errors": [{"command": "meminfo"}]}], "api_health": {"status": 200}, "api_metrics": {"status": 200}}
        with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT, "capture", return_value=row), patch.object(SNAPSHOT.time, "monotonic", side_effect=[0, 0, 2, 2]), patch.object(SNAPSHOT.time, "sleep"), patch("sys.argv", ["snapshot", "--watch-seconds", "1", "--output", str(Path(directory) / "watch.jsonl")]), contextlib.redirect_stdout(io.StringIO()) as stdout:
            self.assertEqual(SNAPSHOT.main(), 1)
        self.assertIsNone(json.loads(stdout.getvalue())["memory_available_gib"]["rank-0"])

    def test_nonfinite_durations_rejected(self):
        for option, value in (("--watch-seconds", "nan"), ("--watch-seconds", "inf"), ("--interval", "nan"), ("--interval", "inf")):
            with self.subTest(option=option, value=value), patch("sys.argv", ["snapshot", "--output", "/unused", option, value]), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
                SNAPSHOT.main()
            self.assertEqual(raised.exception.code, 2)

    def command_args(self, directory):
        return SimpleNamespace(output=Path(directory) / "monitor.jsonl", watch_command=["python3", "benchmark.py", "--label", "literal;value"], interval=15)

    def test_command_monitor_includes_baseline_and_final_sample(self):
        child = Mock(returncode=0)
        child.poll.side_effect = [None, 0, 0]
        child.wait.return_value = 0
        with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT.subprocess, "Popen", return_value=child) as spawn, patch.object(SNAPSHOT, "record_sample", return_value=False) as record:
            args = self.command_args(directory)
            self.assertEqual(SNAPSHOT.watch_command(args), 0)
        spawn.assert_called_once_with(args.watch_command, shell=False)
        self.assertEqual(record.call_count, 3)
        child.wait.assert_called_once_with(timeout=15)
        child.terminate.assert_not_called()

    def test_command_monitor_continues_after_wait_timeout(self):
        child = Mock(returncode=0)
        child.poll.side_effect = [None, None, 0, 0]
        child.wait.side_effect = [SNAPSHOT.subprocess.TimeoutExpired("fixture", 15), 0]
        with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT.subprocess, "Popen", return_value=child), patch.object(SNAPSHOT, "record_sample", return_value=False) as record:
            self.assertEqual(SNAPSHOT.watch_command(self.command_args(directory)), 0)
        self.assertEqual(record.call_count, 4)
        self.assertEqual(child.wait.call_count, 2)

    def test_command_monitor_preserves_child_exit_status(self):
        for code, expected in ((7, 7), (-15, 143)):
            with self.subTest(code=code):
                child = Mock(returncode=code)
                child.poll.return_value = code
                with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT.subprocess, "Popen", return_value=child), patch.object(SNAPSHOT, "record_sample", return_value=True) as record:
                    self.assertEqual(SNAPSHOT.watch_command(self.command_args(directory)), expected)
                self.assertEqual(record.call_count, 2)

    def test_command_monitor_collector_error_changes_success_exit(self):
        child = Mock(returncode=0)
        child.poll.return_value = 0
        with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT.subprocess, "Popen", return_value=child), patch.object(SNAPSHOT, "record_sample", side_effect=[False, True]):
            self.assertEqual(SNAPSHOT.watch_command(self.command_args(directory)), 1)

    def test_command_interrupt_terminates_and_waits_for_owned_child(self):
        child = Mock(returncode=None)
        child.poll.return_value = None
        with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT.subprocess, "Popen", return_value=child), patch.object(SNAPSHOT, "record_sample", side_effect=[False, KeyboardInterrupt]):
            self.assertEqual(SNAPSHOT.watch_command(self.command_args(directory)), 130)
        child.terminate.assert_called_once_with()
        child.wait.assert_called_once_with(timeout=5)
        child.kill.assert_not_called()

    def test_command_exception_kills_unresponsive_owned_child(self):
        child = Mock(returncode=None)
        child.poll.return_value = None
        child.wait.side_effect = [SNAPSHOT.subprocess.TimeoutExpired("fixture", 5), -9]
        with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT.subprocess, "Popen", return_value=child), patch.object(SNAPSHOT, "record_sample", side_effect=[False, RuntimeError("collector failed")]), self.assertRaisesRegex(RuntimeError, "collector failed"):
            SNAPSHOT.watch_command(self.command_args(directory))
        child.terminate.assert_called_once_with()
        child.kill.assert_called_once_with()
        self.assertEqual(child.wait.call_count, 2)
        child.wait.assert_called_with(timeout=5)

    def test_failed_baseline_does_not_spawn_child(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT.subprocess, "Popen") as spawn, patch.object(SNAPSHOT, "record_sample", side_effect=OSError("output unavailable")), self.assertRaises(OSError):
            SNAPSHOT.watch_command(self.command_args(directory))
        spawn.assert_not_called()

    def test_command_arguments_validation(self):
        for tail in (("--watch-command",), ("--watch-command", "--"), ("--watch-seconds", "1", "--watch-command", "true")):
            with self.subTest(tail=tail), patch("sys.argv", ["snapshot", "--output", "/unused", *tail]), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
                SNAPSHOT.main()
            self.assertEqual(raised.exception.code, 2)

    def test_command_argv_remainder(self):
        with tempfile.TemporaryDirectory() as directory, patch("sys.argv", ["snapshot", "--output", str(Path(directory) / "monitor.jsonl"), "--watch-command", "python3", "benchmark.py", "--output", "benchmark.json"]), patch.object(SNAPSHOT, "watch_command", return_value=0) as watch:
            self.assertEqual(SNAPSHOT.main(), 0)
        self.assertEqual(watch.call_args.args[0].watch_command, ["python3", "benchmark.py", "--output", "benchmark.json"])


class ResourceGuardTests(unittest.TestCase):
    def args(self, **options):
        values = {"nodes": [f"rank-{rank}" for rank in range(4)], "min_available_gib": None,
                  "max_new_swapout_pages": None, "fail_on_new_oom": False,
                  "watch_command": ["python3", "benchmark.py"], "interval": 15}
        values.update(options)
        return SimpleNamespace(**values)

    def report(self):
        return {"sampled_at": "fixture", "api_health": {"status": 200}, "api_metrics": {"status": 200},
                "nodes": [{"node": f"rank-{rank}", "errors": [], "boot_id": f"boot-{rank}",
                           "memory_kib": {"MemAvailable": 2 * 1048576},
                           "vmstat": {"pswpout": 100 + rank, "oom_kill": 7},
                           "memory_events": {"oom": 8, "oom_kill": 6, "oom_group_kill": 2},
                           "service": {"InvocationID": f"invocation-{rank}", "ControlGroup": "/fixture",
                                       "ActiveState": "active", "SubState": "running"}}
                          for rank in range(4)]}

    def test_memory_floor_boundary_and_invalid_counters(self):
        guards = SNAPSHOT.ResourceGuards(self.args(min_available_gib=2))
        self.assertEqual(guards.evaluate(self.report(), "preflight"), [])
        for value in (2 * 1048576 - 1, None, True, "2097152", -1):
            with self.subTest(value=value):
                row = self.report()
                row["nodes"][0]["memory_kib"]["MemAvailable"] = value
                self.assertTrue(guards.evaluate(row, "running"))
        row = self.report()
        row["nodes"][0]["memory_kib"] = None
        self.assertTrue(guards.evaluate(row, "running"))

    def test_swap_budget_is_cumulative_per_node_in_pages(self):
        guards = SNAPSHOT.ResourceGuards(self.args(max_new_swapout_pages=10))
        self.assertEqual(guards.evaluate(self.report(), "preflight"), [])
        for increase in (6, 10):
            row = self.report()
            row["nodes"][3]["vmstat"]["pswpout"] += increase
            self.assertEqual(guards.evaluate(row, "running"), [])
        row["nodes"][3]["vmstat"]["pswpout"] += 1
        failure, = guards.evaluate(row, "running")
        self.assertEqual((failure["node"], failure["baseline"], failure["delta"], failure["unit"]), ("rank-3", 103, 11, "pages"))

    def test_zero_swap_budget_allows_existing_count_only(self):
        guards = SNAPSHOT.ResourceGuards(self.args(max_new_swapout_pages=0))
        self.assertEqual(guards.evaluate(self.report(), "preflight"), [])
        self.assertEqual(guards.evaluate(self.report(), "running"), [])
        row = self.report()
        row["nodes"][0]["vmstat"]["pswpout"] += 1
        self.assertTrue(guards.evaluate(row, "running"))

    def test_counter_reset_above_baseline_fails_closed(self):
        guards = SNAPSHOT.ResourceGuards(self.args(max_new_swapout_pages=100))
        guards.evaluate(self.report(), "preflight")
        row = self.report()
        row["nodes"][0]["vmstat"]["pswpout"] = 160
        self.assertEqual(guards.evaluate(row, "running"), [])
        row["nodes"][0]["vmstat"]["pswpout"] = 150
        failure, = guards.evaluate(row, "running")
        self.assertEqual((failure["baseline"], failure["previous"], failure["reason"]), (100, 160, "counter decreased or reset"))

    def test_oom_baseline_is_allowed_and_every_new_event_fails(self):
        for section, key in (("vmstat", "oom_kill"), ("memory_events", "oom"), ("memory_events", "oom_kill"), ("memory_events", "oom_group_kill")):
            with self.subTest(section=section, key=key):
                guards = SNAPSHOT.ResourceGuards(self.args(fail_on_new_oom=True))
                self.assertEqual(guards.evaluate(self.report(), "preflight"), [])
                row = self.report()
                row["nodes"][0][section][key] += 1
                failure, = guards.evaluate(row, "running")
                self.assertEqual(failure["counter"], f"{section}.{key}")
                self.assertEqual(failure["delta"], 1)

    def test_missing_required_data_and_nodes_fail_closed(self):
        for section, key in (("memory_kib", "MemAvailable"), ("vmstat", "pswpout"), ("vmstat", "oom_kill"), ("memory_events", "oom"), ("memory_events", "oom_kill"), ("service", "InvocationID"), ("service", "ControlGroup")):
            with self.subTest(section=section, key=key):
                guards = SNAPSHOT.ResourceGuards(self.args(min_available_gib=1, max_new_swapout_pages=0, fail_on_new_oom=True))
                row = self.report()
                del row["nodes"][0][section][key]
                self.assertTrue(guards.evaluate(row, "preflight"))
        for mutation in (lambda rows: rows.pop(), lambda rows: rows.append(copy.deepcopy(rows[0]))):
            guards = SNAPSHOT.ResourceGuards(self.args(min_available_gib=1))
            row = self.report()
            mutation(row["nodes"])
            self.assertTrue(guards.evaluate(row, "preflight"))

    def test_identity_changes_and_missing_boot_id_fail_closed(self):
        for section, key in ((None, "boot_id"), ("service", "InvocationID"), ("service", "ControlGroup")):
            with self.subTest(key=key):
                guards = SNAPSHOT.ResourceGuards(self.args(fail_on_new_oom=True))
                guards.evaluate(self.report(), "preflight")
                row = self.report()
                target = row["nodes"][0][section] if section else row["nodes"][0]
                target[key] = "changed"
                self.assertEqual(guards.evaluate(row, "running")[0]["reason"], "counter identity changed")
        row = self.report()
        del row["nodes"][0]["boot_id"]
        guards = SNAPSHOT.ResourceGuards(self.args(max_new_swapout_pages=0))
        self.assertTrue(guards.evaluate(row, "preflight"))
        self.assertEqual(SNAPSHOT.ResourceGuards(self.args(min_available_gib=1)).evaluate(row, "preflight"), [])

    def test_optional_group_oom_counter_cannot_disappear_or_rebaseline(self):
        guards = SNAPSHOT.ResourceGuards(self.args(fail_on_new_oom=True))
        row = self.report()
        del row["nodes"][0]["memory_events"]["oom_group_kill"]
        self.assertEqual(guards.evaluate(row, "preflight"), [])
        self.assertTrue(guards.evaluate(self.report(), "running"))
        guards = SNAPSHOT.ResourceGuards(self.args(fail_on_new_oom=True))
        guards.evaluate(self.report(), "preflight")
        self.assertTrue(guards.evaluate(row, "running"))

    def run_monitor(self, args, rows, child, group_exists=None, group_signals=None):
        child.pid = 24680
        with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT, "capture", side_effect=copy.deepcopy(rows)), patch.object(SNAPSHOT.subprocess, "Popen", return_value=child) as spawn, patch.object(SNAPSHOT.os, "getpgrp", return_value=12345), patch.object(SNAPSHOT.os, "killpg", side_effect=group_signals) as signals, patch.object(SNAPSHOT, "process_group_exists", side_effect=group_exists, return_value=False), contextlib.redirect_stdout(io.StringIO()) as stdout:
            child.group_signals = signals
            args.output = Path(directory) / "monitor.jsonl"
            status = SNAPSHOT.watch_command(args)
            recorded = [json.loads(line) for line in args.output.read_text().splitlines()]
        return status, recorded, spawn, [json.loads(line) for line in stdout.getvalue().splitlines()]

    def test_preflight_guard_failure_records_policy_without_launch(self):
        status, rows, spawn, progress = self.run_monitor(self.args(min_available_gib=3), [self.report()], Mock())
        self.assertEqual(status, 1)
        spawn.assert_not_called()
        self.assertEqual(rows[0]["guard_phase"], "preflight")
        self.assertTrue(rows[0]["guard_failures"])
        self.assertTrue(progress[0]["guard_failed"])
        self.assertEqual(rows[0]["guard_policy"]["collector_source_sha256"], SNAPSHOT.hashlib.sha256(Path(SNAPSHOT.__file__).read_bytes()).hexdigest())

    def test_running_guard_failure_terminates_waits_and_preserves_final_sample(self):
        child = Mock(returncode=0)
        child.poll.return_value = None
        breach = self.report()
        breach["nodes"][0]["vmstat"]["pswpout"] += 1
        status, rows, spawn, progress = self.run_monitor(self.args(max_new_swapout_pages=0), [self.report(), breach, breach], child)
        self.assertEqual(status, 1)
        self.assertEqual([row["guard_phase"] for row in rows], ["preflight", "running", "final"])
        self.assertTrue(rows[1]["guard_failures"])
        self.assertTrue(progress[-1]["guard_failed"])
        spawn.assert_called_once_with(["python3", "benchmark.py"], shell=False, start_new_session=True)
        child.group_signals.assert_called_once_with(24680, SNAPSHOT.signal.SIGTERM)
        child.terminate.assert_not_called()
        child.wait.assert_called_once_with(timeout=5)
        child.kill.assert_not_called()

    def test_guard_cleanup_kill_race_still_waits_and_records_final(self):
        child = Mock(returncode=-9)
        child.poll.return_value = None
        with patch.object(SNAPSHOT.time, "monotonic", side_effect=[0, 6, 6]):
            status, rows, _, _ = self.run_monitor(self.args(min_available_gib=2), [self.report(), {**self.report(), "nodes": []}, self.report()], child,
                                                 group_exists=[True, False], group_signals=[ProcessLookupError, ProcessLookupError])
        self.assertEqual(status, 1)
        self.assertEqual(rows[-1]["guard_phase"], "final")
        self.assertTrue(rows[-1]["guard_failed"])
        child.group_signals.assert_any_call(24680, SNAPSHOT.signal.SIGKILL)
        child.wait.assert_called_once_with(timeout=5)

    def test_final_guard_failure_overrides_successful_child_exit(self):
        child = Mock(returncode=0)
        child.poll.return_value = 0
        breach = self.report()
        breach["nodes"][0]["memory_events"]["oom"] += 1
        status, rows, _, _ = self.run_monitor(self.args(fail_on_new_oom=True), [self.report(), breach], child)
        self.assertEqual(status, 1)
        self.assertEqual(len(rows), 2)
        child.terminate.assert_not_called()

    def test_unrelated_collection_failure_preserves_existing_non_abort_behavior(self):
        child = Mock(returncode=0)
        child.poll.return_value = 0
        row = self.report()
        row["api_health"] = {"error": "unavailable"}
        status, rows, spawn, _ = self.run_monitor(self.args(min_available_gib=1), [row, self.report()], child)
        self.assertEqual(status, 1)
        spawn.assert_called_once()
        self.assertFalse(any(row["guard_failed"] for row in rows))
        child.terminate.assert_not_called()
        child.group_signals.assert_called_once_with(24680, SNAPSHOT.signal.SIGTERM)

    def test_group_cleanup_waits_for_descendants_after_leader_exits(self):
        child = Mock(pid=24680, returncode=0)
        child.poll.return_value = 0
        with patch.object(SNAPSHOT.os, "getpgrp", return_value=12345), patch.object(SNAPSHOT.os, "killpg") as signals, patch.object(SNAPSHOT, "process_group_exists", side_effect=[True, False]), patch.object(SNAPSHOT.time, "monotonic", side_effect=[0, 6, 6]):
            self.assertIsNone(SNAPSHOT.stop_child_group(child))
        self.assertEqual(signals.call_args_list, [unittest.mock.call(24680, SNAPSHOT.signal.SIGTERM), unittest.mock.call(24680, SNAPSHOT.signal.SIGKILL)])
        child.wait.assert_called_once_with(timeout=5)

    def test_group_cleanup_allows_bounded_graceful_exit(self):
        child = Mock(pid=24680, returncode=0)
        with patch.object(SNAPSHOT.os, "getpgrp", return_value=12345), patch.object(SNAPSHOT.os, "killpg") as signals, patch.object(SNAPSHOT, "process_group_exists", side_effect=[True, False]), patch.object(SNAPSHOT.time, "monotonic", side_effect=[0, 1]), patch.object(SNAPSHOT.time, "sleep") as sleep:
            SNAPSHOT.stop_child_group(child)
        signals.assert_called_once_with(24680, SNAPSHOT.signal.SIGTERM)
        sleep.assert_called_once_with(0.05)
        child.wait.assert_called_once_with(timeout=5)

    def test_group_cleanup_refuses_parent_and_invalid_groups(self):
        for pid in (0, 1, -1, 12345, None, True):
            with self.subTest(pid=pid), patch.object(SNAPSHOT.os, "getpgrp", return_value=12345), patch.object(SNAPSHOT.os, "killpg") as signals, self.assertRaisesRegex(ValueError, "parent process group"):
                SNAPSHOT.stop_child_group(Mock(pid=pid))
            signals.assert_not_called()

    def test_process_group_probe_tolerates_exit_race(self):
        with patch.object(SNAPSHOT.os, "killpg", side_effect=ProcessLookupError):
            self.assertFalse(SNAPSHOT.process_group_exists(24680))
        with patch.object(SNAPSHOT.os, "killpg", return_value=None) as signals:
            self.assertTrue(SNAPSHOT.process_group_exists(24680))
        signals.assert_called_once_with(24680, 0)

    def test_process_group_probe_permission_failure_is_unknown_not_absent(self):
        with patch.object(SNAPSHOT.os, "killpg", side_effect=PermissionError):
            self.assertIsNone(SNAPSHOT.process_group_exists(24680))

    def test_cleanup_handles_real_probe_permission_path_without_throwing(self):
        child = Mock(pid=24680, returncode=-15)
        with patch.object(SNAPSHOT.os, "getpgrp", return_value=12345), patch.object(SNAPSHOT.os, "killpg", side_effect=[None, PermissionError, PermissionError, PermissionError]) as signals:
            failure = SNAPSHOT.stop_child_group(child)
        self.assertFalse(failure["group_exit_confirmed"])
        self.assertEqual(signals.call_args_list, [
            unittest.mock.call(24680, SNAPSHOT.signal.SIGTERM), unittest.mock.call(24680, 0),
            unittest.mock.call(24680, SNAPSHOT.signal.SIGKILL), unittest.mock.call(24680, 0),
        ])
        child.wait.assert_called_once_with(timeout=5)

    def test_denied_group_cleanup_preserves_guard_breach_and_final_sample(self):
        child = Mock(returncode=-15)
        child.poll.return_value = None
        breach = self.report()
        breach["nodes"][0]["vmstat"]["pswpout"] += 1
        status, rows, _, progress = self.run_monitor(
            self.args(max_new_swapout_pages=0), [self.report(), breach, breach], child,
            group_exists=[None, None], group_signals=[None, PermissionError],
        )
        self.assertEqual(status, 1)
        self.assertEqual([row.get("guard_phase", row.get("event")) for row in rows],
                         ["preflight", "running", "cleanup_failure", "final"])
        failure = rows[2]["cleanup_failure"]
        self.assertFalse(failure["group_exit_confirmed"])
        self.assertEqual(failure["problems"].count("Permission denied checking process-group exit"), 2)
        self.assertIn("Permission denied sending SIGKILL to process group", failure["problems"])
        self.assertIn("Could not confirm", failure["problems"][-1])
        self.assertTrue(rows[-1]["guard_failed"])
        self.assertEqual(progress[2]["event"], "cleanup_failure")
        self.assertEqual(child.group_signals.call_count, 2)
        child.wait.assert_called_once_with(timeout=5)

    def test_denied_signals_cannot_pass_after_successful_child_exit(self):
        child = Mock(returncode=0)
        child.poll.return_value = 0
        status, rows, _, _ = self.run_monitor(
            self.args(min_available_gib=1), [self.report(), self.report()], child,
            group_exists=[None, None], group_signals=[PermissionError, PermissionError],
        )
        self.assertEqual(status, 1)
        self.assertFalse(rows[1]["cleanup_failure"]["group_exit_confirmed"])
        self.assertIn("Permission denied sending SIGTERM to process group", rows[1]["cleanup_failure"]["problems"])
        self.assertEqual(rows[-1]["guard_phase"], "final")
        self.assertEqual(child.group_signals.call_count, 2)

    def test_denied_child_wait_records_failure_and_preserves_final_sample(self):
        child = Mock(returncode=0)
        child.poll.return_value = 0
        child.wait.side_effect = PermissionError
        status, rows, _, _ = self.run_monitor(self.args(min_available_gib=1), [self.report(), self.report()], child)
        self.assertEqual(status, 1)
        self.assertTrue(rows[1]["cleanup_failure"]["group_exit_confirmed"])
        self.assertEqual(rows[1]["cleanup_failure"]["problems"], ["Permission denied waiting for owned child"])
        self.assertEqual(rows[-1]["guard_phase"], "final")
        child.wait.assert_called_once_with(timeout=5)

    def test_cleanup_exception_is_not_retried_in_finally(self):
        child = Mock(returncode=0)
        child.poll.return_value = 0
        with patch.object(SNAPSHOT, "stop_child_group", side_effect=ValueError("fixture invalid group")) as cleanup, self.assertRaisesRegex(ValueError, "fixture invalid group"):
            self.run_monitor(self.args(min_available_gib=1), [self.report()], child)
        cleanup.assert_called_once_with(child)

    def test_guarded_collector_exception_cleans_owned_group(self):
        child = Mock(pid=24680, returncode=None)
        child.poll.return_value = None
        with tempfile.TemporaryDirectory() as directory, patch.object(SNAPSHOT, "capture", side_effect=[self.report(), RuntimeError("fixture capture failure")]), patch.object(SNAPSHOT.subprocess, "Popen", return_value=child), patch.object(SNAPSHOT, "stop_child_group", return_value=None) as cleanup, contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(RuntimeError, "fixture capture failure"):
            args = self.args(min_available_gib=1, output=Path(directory) / "monitor.jsonl")
            SNAPSHOT.watch_command(args)
        cleanup.assert_called_once_with(child)

    def test_unconfirmed_group_exit_records_failure_and_preserves_final_sample(self):
        child = Mock(returncode=0)
        child.poll.return_value = 0
        with patch.object(SNAPSHOT.time, "monotonic", side_effect=[0, 6, 6, 12]):
            status, rows, _, progress = self.run_monitor(self.args(min_available_gib=1), [self.report(), self.report()], child,
                                                        group_exists=[True, True])
        self.assertEqual(status, 1)
        self.assertEqual(rows[1]["event"], "cleanup_failure")
        self.assertIn("Could not confirm", rows[1]["cleanup_failure"]["problems"][0])
        self.assertEqual(rows[-1]["guard_phase"], "final")
        self.assertEqual(progress[1]["event"], "cleanup_failure")
        child.wait.assert_called_once_with(timeout=5)

    def test_child_wait_failure_records_failure_and_preserves_final_sample(self):
        child = Mock(returncode=0)
        child.poll.return_value = 0
        child.wait.side_effect = SNAPSHOT.subprocess.TimeoutExpired("fixture", 5)
        status, rows, _, _ = self.run_monitor(self.args(min_available_gib=1), [self.report(), self.report()], child)
        self.assertEqual(status, 1)
        self.assertEqual(rows[1]["cleanup_failure"]["problems"], ["Owned child wait timed out after five seconds"])
        self.assertEqual(rows[-1]["guard_phase"], "final")

    def test_guard_arguments_are_validated_and_require_command(self):
        tails = [("--min-available-gib", value) for value in ("0", "-1", "nan", "inf", "-inf")]
        tails += [("--max-new-swapout-pages", value) for value in ("-1", "nan", "inf", "1.5")]
        tails += [("--min-available-gib", "1"), ("--max-new-swapout-pages", "0"), ("--fail-on-new-oom",)]
        for tail in tails:
            with self.subTest(tail=tail), patch("sys.argv", ["snapshot", "--output", "/unused", *tail]), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
                SNAPSHOT.main()
            self.assertEqual(raised.exception.code, 2)
        with tempfile.TemporaryDirectory() as directory, patch("sys.argv", ["snapshot", "--output", str(Path(directory) / "monitor.jsonl"), "--min-available-gib", "2", "--max-new-swapout-pages", "0", "--fail-on-new-oom", "--watch-command", "true"]), patch.object(SNAPSHOT, "watch_command", return_value=0) as watch:
            self.assertEqual(SNAPSHOT.main(), 0)
        args = watch.call_args.args[0]
        self.assertEqual((args.min_available_gib, args.max_new_swapout_pages, args.fail_on_new_oom), (2, 0, True))


if __name__ == "__main__":
    unittest.main()
