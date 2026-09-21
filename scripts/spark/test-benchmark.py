#!/usr/bin/env python3
"""Offline tests for TP4 measurement, cache gates, and workload identity."""

import argparse
import contextlib
import copy
import datetime
import importlib.util
import io
import json
from pathlib import Path
import shlex
import subprocess
import tempfile
import time
import unittest
from unittest import mock


SPEC = importlib.util.spec_from_file_location(
    "tp4", Path(__file__).with_name("benchmark.py")
)
TP4 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TP4)


def args(**overrides):
    settings = {
        "endpoint": "http://unused.invalid:8888", "model": "spark-current",
        "arm": "mtp5", "campaign_id": "paired-trial", "seed": 42,
        "temperature": 0, "reasoning_effort": "low", "timeout": 2,
        "code_host": "spark-01.local", "code_image": "sha256:" + "a" * 64,
        "ssh_identity": None, "code_timeout": 30,
    }
    return argparse.Namespace(**(settings | overrides))


def response(events, done=True):
    lines = [f"data: {json.dumps(event)}\n\n" for event in events]
    if done:
        lines.append("data: [DONE]\n\n")
    return io.BytesIO("".join(lines).encode())


def metrics(count=0, running=0, preemptions=None):
    lines = ["# TYPE vllm:request_success_total counter", "# TYPE vllm:num_preemptions_total counter",
             f'vllm:request_success_total{{engine="0",finished_reason="stop"}} {count}',
             f'vllm:num_requests_running{{engine="0"}} {running}', 'vllm:num_requests_waiting{engine="0"} 0']
    for label, value in (preemptions or {}).items():
        lines.append(f'vllm:num_preemptions_total{{engine="{label}"}} {value}')
    raw = "\n".join(lines)
    return {"raw": raw, "samples": TP4.parse_metrics(raw)}


def manifest():
    return {"instance": "glm53-flash-nvfp4-vllm", "tensor_parallel_size": 4, "context_window": 1048576,
            "sampled_at": TP4.utc_now(), "collection_errors": [], "tp4_validation_errors": [],
            "api_health": {"status": 200}, "api_metrics": {"status": 200, "body": metrics()["raw"]},
            "nodes": [{"node": f"spark-{index + 1:02d}.local", "errors": [], "boot_id": f"boot-{index}",
                       "service": {"ActiveState": "active", "SubState": "running", "InvocationID": f"invocation-{index}",
                                   "ControlGroup": "/fixture", "MainPID": "42"},
                       "container": {"environment": {"INFER_WORLD_SIZE": "4", "INFER_RANK": str(index)},
                                     "args": ["--port", "8888", "--max-model-len", "1048576"],
                                     "image_id": "a" * 64, "state": {"Running": True}},
                       "memory_kib": {"MemAvailable": 8 * 1048576}, "vmstat": {"pswpout": 100, "oom_kill": 0},
                       "memory_events": {"oom": 0, "oom_kill": 0}} for index in range(4)]}


def guard_row():
    row = manifest()
    policy = TP4.SNAPSHOT.ResourceGuards(argparse.Namespace(nodes=[node["node"] for node in row["nodes"]],
                                                          min_available_gib=8, max_new_swapout_pages=0, fail_on_new_oom=True)).policy
    row.update(guard_phase="preflight", guard_policy=policy, guard_failed=False, guard_failures=[])
    return row


class StreamClient(TP4.Client):
    def __init__(self, events, done=True):
        super().__init__(args())
        self.events, self.done = events, done

    def post(self, route, body):
        return response(self.events, self.done)


class MixedCampaign(TP4.Campaign):
    def __init__(self, arm="mtp5", failed_label=None):
        self.args = args(arm=arm, cache_tokens=16384, quality_output_tokens=1024, min_cache_ratio=0.8)
        self.client = TP4.Client(self.args)
        self.report, self.calls, self.ledger_calls = {}, [], []
        self.failed_label = failed_label

    def save(self):
        pass

    def ledger(self, target, *parts, content_seed=None):
        self.ledger_calls.append((target, parts, content_seed))
        prefix = f"Request nonce: {TP4.nonce(self.args, *parts)}\nLedger contents.\n"
        values = {f"vault_{name}": f"{content_seed}-{name}" for name in ("a", "b", "c")}
        return prefix + "Return only a JSON object with the three codes.", values

    def batch(self, label, cases, warmup=False):
        self.calls.append((label, cases, warmup))
        rows = []
        for case in cases:
            row = {
                "content": json.dumps((case.get("expectation") or {}).get("value", {})),
                "usage": {"prompt_tokens": 16000, "prompt_tokens_details": {
                    "cached_tokens": 13824 if case.get("cache_mode") == "warm" else 0,
                }},
            }
            if label == self.failed_label:
                row["usage"]["prompt_tokens_details"]["cached_tokens"] = 0
            TP4.validate(row, case.get("expectation"), case.get("cache_mode"))
            rows.append(row)
        return rows

    def gate(self, label, rows):
        return all(row["validation"]["passed"] for row in rows)


class QualificationTests(unittest.TestCase):
    def test_safe_cli_defaults_and_explicit_long_requirements(self):
        with tempfile.TemporaryDirectory() as directory:
            base = ["--model", "spark-current", "--arm", "current", "--campaign-id", "fresh",
                    "--output", str(Path(directory) / "result.json")]
            parsed = TP4.parse_args(base)
            self.assertEqual((parsed.stage, parsed.concurrency, parsed.repeats), ("short", [1], 1))
            for extra in (["--stage", "long"], ["--stage", "long", "--manifest", "a", "--guard-log", "b", "--concurrency", "2"],
                          ["--stage", "long", "--manifest", "a", "--guard-log", "b", "--repeats", "3"]):
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    TP4.parse_args(base + extra)

    def test_all_never_invokes_long_or_quiet_waits(self):
        campaign = TP4.Campaign.__new__(TP4.Campaign)
        campaign.args = args(stage="all", cache_tokens=16384)
        campaign.client, campaign.report = mock.Mock(), {}
        campaign.client.get.return_value = "{}"
        campaign.save = campaign.check_guard = mock.Mock()
        for name in ("accuracy", "cache", "mixed_cache", "short", "settle"):
            setattr(campaign, name, mock.Mock(return_value=True))
        self.assertTrue(campaign.run())
        campaign.cache.assert_called_once_with(16384)
        campaign.settle.assert_not_called()

    def test_accounting_rejects_missing_invalid_and_reset_metrics(self):
        good = metrics()
        self.assertEqual(TP4.accounting(good, metrics(1), 1)["successful_request_delta"], 1)
        for name in ("vllm:num_requests_running", "vllm:num_requests_waiting",
                     "vllm:request_success_total", "vllm:num_preemptions_total"):
            for value in ("NaN", "+Inf", "bad", "-1", "0.5", ""):
                broken = {"raw": good["raw"] + f'\n{name}{{engine="bad"}} {value}'}
                with self.subTest(name=name, value=value), self.assertRaises(ValueError):
                    TP4.accounting(good, broken, 0)
        for before, after, expected in (
            (good, metrics(1), 0), (good, metrics(running=1), 0),
            (metrics(2), metrics(1), 0),
            (metrics(preemptions={"0": 3}), metrics(preemptions={"1": 3}), 0),
            (metrics(preemptions={"0": 3, "1": 0}), metrics(preemptions={"0": 2, "1": 1}), 0),
            (good, {"raw": "# TYPE vllm:request_success_total counter"}, 0),
        ):
            with self.assertRaises(ValueError):
                TP4.accounting(before, after, expected)
        with self.assertRaises(ValueError):
            TP4.accounting(good, {"raw": good["raw"] + '\nvllm:num_requests_waiting{engine="0"} 0'}, 0)

    def test_empty_declared_counters_are_valid_only_before_samples_exist(self):
        empty = metrics()
        empty["raw"] = "\n".join(line for line in empty["raw"].splitlines() if not line.startswith("vllm:request_success_total"))
        TP4.accounting(empty, metrics(1), 1)
        with self.assertRaises(ValueError):
            TP4.accounting(metrics(1), empty, 0)

    def test_stream_requires_valid_terminal_and_integer_usage(self):
        for finish, prompt, completion in ((None, 20, 2), ("unknown", 20, 2), ("stop", True, 2),
                                          ("stop", 20, 2.0), ("stop", 20, -1), ("stop", 20, "bad")):
            client = StreamClient([{"choices": [{"delta": {"content": "{}"}, "finish_reason": finish}],
                                    "usage": {"prompt_tokens": prompt, "completion_tokens": completion}}])
            with self.subTest(finish=finish, prompt=prompt, completion=completion):
                self.assertIn("error", client.measure_body("test", {"max_tokens": 32}))

    def test_nonfinite_stream_json_cannot_poison_atomic_report(self):
        for value in (float("nan"), float("inf"), float("-inf")):
            client = StreamClient([{"choices": [{"delta": {"content": "{}"}, "finish_reason": "stop"}],
                                    "usage": {"prompt_tokens": 20, "completion_tokens": value}}])
            row = client.measure_body("test", {"max_tokens": 32})
            self.assertIn("Nonfinite JSON constant", row["error"])
            with tempfile.TemporaryDirectory() as directory:
                TP4.atomic_json(Path(directory) / "failed.json", row)

    def test_long_validation_keeps_full_answer_and_bounds(self):
        expected = {"kind": "json", "value": {"answer": 7}}
        valid = {"content": '{"answer":7}', "finish_reason": "stop", "usage": {
            "prompt_tokens": 16300, "completion_tokens": 10, "prompt_tokens_details": {"cached_tokens": 13824}}}
        def check(row):
            return TP4.validate(row, expected, "warm", .8, 16384, 1048576, 2048)
        self.assertTrue(check(copy.deepcopy(valid)))
        for content in ('{"answer":7}\nCommentary\n{"answer":7}', '{"answer":8}'):
            self.assertFalse(check(valid | {"content": content}))
        self.assertTrue(check(valid | {"content": '```json\n{"answer":7}\n```'}))
        for field, value in (("prompt_tokens", 15000), ("prompt_tokens", 17000), ("completion_tokens", True),
                             ("completion_tokens", 2049), ("completion_tokens", 0)):
            self.assertFalse(check(valid | {"usage": valid["usage"] | {field: value}}))
        self.assertFalse(check(valid | {"finish_reason": None}))
        self.assertFalse(check(valid | {"usage": valid["usage"] | {"prompt_tokens_details": {"cached_tokens": True}}}))

    def test_long_has_exactly_six_c1_requests_with_native_eos_retrieval(self):
        campaign = TP4.Campaign.__new__(TP4.Campaign)
        campaign.args = args(repeats=9, quality_output_tokens=2048)
        campaign.client = TP4.Client(campaign.args)
        campaign.ledger = mock.Mock(return_value=("Ledger. Return only a JSON object", {"vault_a": "a", "vault_b": "b", "vault_c": "c"}))
        campaign.batch = mock.Mock(return_value=[{"validation": {"passed": True}}])
        campaign.gate = mock.Mock(return_value=True)
        self.assertTrue(campaign.cache(16384, concurrent=False, label="long"))
        calls = campaign.batch.call_args_list
        self.assertEqual(len(calls), 6)
        self.assertTrue(all(len(call.args[1]) == 1 for call in calls))
        self.assertEqual(calls[0].args[0], "warmup-long-16384-c1")
        self.assertEqual(calls[0].args[1][0]["body"]["max_tokens"], 32)
        self.assertTrue(calls[0].args[1][0]["body"]["ignore_eos"])
        self.assertEqual([call.args[1][0]["cache_mode"] for call in calls[1:]], ["cold"] + ["warm"] * 4)
        self.assertTrue(all("ignore_eos" not in call.args[1][0]["body"] for call in calls[1:]))

    def test_warm_prefixes_are_separate_per_target_and_from_retrieval(self):
        campaign = TP4.Campaign.__new__(TP4.Campaign)
        campaign.args, campaign.client = args(), mock.Mock()
        with mock.patch.object(TP4.BASE, "long_prompt", side_effect=lambda client, target, identity, seed: (identity, {}, target)):
            first = campaign.ledger(16384, "warmup", "long", 1, 0)[0]
            self.assertNotEqual(first, campaign.ledger(131072, "warmup", "long", 1, 0)[0])
            self.assertNotEqual(first, campaign.ledger(16384, "long", 16384)[0])

    def test_long_guard_replays_policy_and_rejects_stale_finished_changed_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest_path, guard_path = Path(directory) / "before.json", Path(directory) / "guard.jsonl"
            manifest_path.write_text(json.dumps(manifest()))
            campaign = TP4.Campaign(args(stage="long", manifest=manifest_path, guard_log=guard_path,
                                         endpoint="http://spark-01.local:8888", context_window=1048576), mock.Mock())
            with self.assertRaises(FileNotFoundError):
                campaign.check_guard()
            good = guard_row()
            guard_path.write_text(json.dumps(good) + "\n")
            self.assertEqual(campaign.check_guard()["policy"]["min_available_gib"], 8)
            variants = []
            for field, value in (("guard_phase", "final"), ("guard_failed", True),
                                 ("sampled_at", "2020-01-01T00:00:00+00:00")):
                variants.append(good | {field: value})
            changed = copy.deepcopy(good)
            changed["nodes"][0]["service"]["InvocationID"] = "another"
            variants.append(changed)
            changed = copy.deepcopy(good)
            changed["guard_policy"]["min_available_gib"] = 6
            variants.append(changed)
            changed = copy.deepcopy(good)
            changed["nodes"][0]["vmstat"]["pswpout"] += 1
            changed["guard_phase"] = "running"
            variants.append(changed)
            for changed in variants:
                campaign.guard_record = None
                rows = [good, changed] if changed["guard_phase"] == "running" else [changed]
                guard_path.write_text("".join(json.dumps(row) + "\n" for row in rows))
                with self.subTest(changed=changed), self.assertRaises(ValueError):
                    campaign.check_guard()

    def test_long_rejects_stale_manifest_and_endpoint_alias(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "before.json"
            for data, endpoint in ((manifest(), "http://another-host:8888"),
                                   (manifest() | {"sampled_at": "2020-01-01T00:00:00+00:00"}, "http://spark-01.local:8888")):
                path.write_text(json.dumps(data))
                with self.assertRaises(ValueError):
                    TP4.Campaign(args(stage="long", manifest=path, endpoint=endpoint, context_window=1048576), mock.Mock())

    def test_constructor_failure_persists_blocked_report(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "result.json"
            with mock.patch.object(TP4, "Campaign", side_effect=ValueError("bad manifest")):
                self.assertEqual(TP4.main(["--model", "spark-current", "--arm", "current", "--campaign-id", "fresh",
                                           "--output", str(output)]), 1)
            saved = json.loads(output.read_text())
            self.assertEqual(saved["status"], "blocked")
            self.assertFalse(saved["complete"])

    def test_failed_guard_after_response_preserves_row_and_metrics(self):
        with tempfile.TemporaryDirectory() as directory:
            settings = args(output=Path(directory) / "report.json", manifest=None, min_cache_ratio=.8)
            client = mock.Mock(tokenize_error=None)
            client.snapshot.side_effect = [metrics(), metrics(1)]
            client.measure_body.side_effect = lambda label, body, **metadata: {
                "label": label, **metadata, "content": '{"answer":7}', "usage": {"completion_tokens": 3},
                "finished_perf_counter": time.perf_counter(), "ttft_seconds": .1, "elapsed_seconds": .2}
            campaign = TP4.Campaign(settings, client)
            campaign.check_guard = mock.Mock(side_effect=[None, ValueError("guard failed")])
            case = {"body": {"messages": [{"role": "user", "content": "test"}]},
                    "expectation": {"kind": "json", "value": {"answer": 7}}}
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(ValueError, "guard failed"):
                campaign.batch("test", [case])
            saved = json.loads(settings.output.read_text())
            self.assertEqual(len(saved["results"]), 1)
            self.assertEqual(saved["batches"][0]["metrics_after"]["raw"], metrics(1)["raw"])
            self.assertFalse(saved["complete"])
            campaign.check_guard = mock.Mock()
            campaign.last_metrics = metrics()
            client.snapshot.side_effect = [metrics(1)]
            client.measure_body.reset_mock()
            with self.assertRaisesRegex(ValueError, "Unexpected successful"):
                campaign.batch("never-sent", [case])
            client.measure_body.assert_not_called()

    def test_invalid_raw_usage_survives_failed_batch_persistence(self):
        for value in (None, "bad", True, -1, 3.5):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as directory:
                settings = args(output=Path(directory) / "report.json", manifest=None, min_cache_ratio=.8,
                                context_window=1048576)
                client = mock.Mock(tokenize_error=None)
                client.snapshot.side_effect = [metrics(), metrics(1)]
                client.measure_body.side_effect = lambda label, body, **metadata: {
                    "label": label, **metadata, "content": '{"answer":7}', "finish_reason": "stop",
                    "usage": {"prompt_tokens": 16384, "completion_tokens": value,
                              "prompt_tokens_details": {"cached_tokens": "bad"}},
                    "finished_perf_counter": time.perf_counter(), "ttft_seconds": .1, "elapsed_seconds": .2}
                campaign = TP4.Campaign(settings, client)
                case = {"body": {"messages": [{"role": "user", "content": "test"}], "max_tokens": 2048},
                        "expectation": {"kind": "json", "value": {"answer": 7}}, "prompt_target": 16384, "cache_mode": "cold"}
                with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(ValueError, "Failed response"):
                    campaign.batch("bad-usage", [case])
                campaign.save()
                saved = json.loads(settings.output.read_text())
                self.assertEqual(saved["results"][0]["usage"]["completion_tokens"], value)
                self.assertEqual(saved["failed_requests"], 1)
                self.assertEqual(saved["summaries"]["bad-usage"]["requests_missing_or_invalid_completion_usage"], 1)

    def test_quiet_interval_requires_sixty_seconds_without_new_swap_or_traffic(self):
        campaign = TP4.Campaign.__new__(TP4.Campaign)
        campaign.report, campaign.last_metrics = {"quiet_intervals": []}, metrics()
        campaign.client, campaign.save = mock.Mock(), mock.Mock()
        campaign.client.snapshot.return_value = metrics()
        now = datetime.datetime.now(datetime.timezone.utc)
        first = {"pswpout": {"spark-01.local": 100}, "last_sampled_at": now.isoformat()}
        last = first | {"last_sampled_at": (now + datetime.timedelta(seconds=61)).isoformat()}
        campaign.check_guard = mock.Mock(side_effect=[first, first, last])
        with mock.patch.object(TP4.time, "sleep"):
            campaign.settle(16384, 131072)
        self.assertTrue(campaign.report["quiet_intervals"][0]["complete"])
        campaign.check_guard = mock.Mock(side_effect=[first, last | {"pswpout": {"spark-01.local": 101}}])
        with self.assertRaisesRegex(ValueError, "swap-out"):
            campaign.settle(131072, 262144)
        campaign.check_guard = mock.Mock(side_effect=[first, last])
        campaign.client.snapshot.side_effect = [metrics(), metrics(1)]
        with self.assertRaisesRegex(ValueError, "Unexpected successful"):
            campaign.settle(131072, 262144)

    def test_arm_is_excluded_from_prompt_identity(self):
        first = TP4.nonce(args(arm="mtp5"), "throughput", 4, 1, 2)
        self.assertEqual(first, TP4.nonce(args(arm="dflash5"), "throughput", 4, 1, 2))
        self.assertNotEqual(first, TP4.nonce(args(arm="mtp5"), "throughput", 4, 2, 2))
        self.assertNotEqual(first, TP4.nonce(args(campaign_id="next-trial"), "throughput", 4, 1, 2))

    def test_cache_variants_preserve_prefix_and_change_answer(self):
        client = TP4.Client(args())
        prefix = "Request nonce: same\n" + "Ledger record.\n" * 4096
        prompt = prefix + "Return only a JSON object with all access codes."
        expected = {"vault_a": "a", "vault_b": "b", "vault_c": "c"}
        original, suffix, appended = TP4.cache_bodies(client, prompt, expected, 1024)
        self.assertEqual(original["messages"][0]["content"], prompt)
        self.assertTrue(suffix["messages"][0]["content"].startswith(prefix))
        self.assertTrue(suffix["messages"][0]["content"].endswith(
            "Use exactly the key vault_b, with its original access code as the string value."))
        self.assertNotEqual(original["messages"], suffix["messages"])
        self.assertEqual(appended["messages"][0], original["messages"][0])
        self.assertEqual(json.loads(appended["messages"][1]["content"]), expected)
        self.assertEqual(appended["messages"][2]["role"], "user")
        self.assertTrue(appended["messages"][2]["content"].endswith(
            "Use exactly the key vault_c, with its original access code as the string value."))
        settings = {key: value for key, value in original.items() if key != "messages"}
        for variant in (suffix, appended):
            self.assertEqual({key: value for key, value in variant.items() if key != "messages"}, settings)
        self.assertNotIn("ignore_eos", original)
        self.assertNotIn("ignore_eos", appended)

    def test_cache_correct_value_under_wrong_key_still_fails(self):
        for vault in ("vault_b", "vault_c"):
            with self.subTest(vault=vault):
                expected = {"kind": "json", "value": {vault: "correct-code"}}
                row = {"content": '{"access_code": "correct-code"}', "usage": {
                    "prompt_tokens": 16299, "prompt_tokens_details": {"cached_tokens": 13824}}}
                self.assertFalse(TP4.validate(row, expected, "warm"))
                self.assertEqual(row["validation"]["problems"], ["Known-answer JSON mismatch"])
                row["content"] = json.dumps({vault: "correct-code"})
                self.assertTrue(TP4.validate(row, expected, "warm"))

    def test_http_success_does_not_hide_cache_failure(self):
        row = {"content": '{"answer": 7}', "usage": {"prompt_tokens": 16384, "prompt_tokens_details": {"cached_tokens": 0}}}
        self.assertFalse(TP4.validate(row, {"kind": "json", "value": {"answer": 7}}, "warm"))
        self.assertIn("Prefix reuse below", row["validation"]["problems"][0])

    def test_missing_usage_is_not_a_cache_hit(self):
        row = {"content": "ok", "usage": {"prompt_tokens": 16000}}
        self.assertFalse(TP4.validate(row, cache_mode="warm"))
        self.assertIsNone(TP4.cached_tokens(row))

    def test_cached_wrong_answer_fails(self):
        row = {"content": '{"vault_b": "stale"}', "usage": {"prompt_tokens": 16000, "prompt_tokens_details": {"cached_tokens": 15872}}}
        self.assertFalse(TP4.validate(row, {"kind": "json", "value": {"vault_b": "fresh"}}, "warm"))

    def test_unicode_corruption_in_reasoning_or_tools_fails(self):
        self.assertFalse(TP4.validate({"content": "valid", "reasoning": "\ufffd"}))
        self.assertFalse(TP4.validate({"tool_calls": [{"function": {"arguments": "\ufffd"}}]}))

    def test_korean_generation_requires_hangul_and_rejects_corruption(self):
        expected = {"kind": "korean_prose", "min_hangul_syllables": 64}
        row = {"content": "\ud55c\uae00" * 40}
        self.assertTrue(TP4.validate(row, expected))
        self.assertEqual(row["unicode_probe"]["content_hangul_syllables"], 80)
        self.assertFalse(TP4.validate({"content": "English only."}, expected))
        row["reasoning"] = "\ufffd"
        self.assertFalse(TP4.validate(row, expected))
        self.assertEqual(row["unicode_probe"]["replacement_characters"], 1)

    def test_long_unicode_probe_allows_budget_but_not_corruption_or_no_coverage(self):
        expected = {"kind": "korean_unicode", "min_hangul_syllables": 256}
        row = {"content": "\ud55c\uae00" * 128, "finish_reason": "length"}
        self.assertTrue(TP4.validate(row, expected))
        self.assertFalse(TP4.validate(row, dict(expected, kind="korean_prose")))
        self.assertFalse(TP4.validate(dict(row, content="English only."), expected))
        self.assertFalse(TP4.validate(dict(row, reasoning="\ufffd"), expected))
        self.assertFalse(TP4.validate(dict(row, content=row["content"] + "\ufffd"), expected))

    def test_long_unicode_workload_pairs_arms_and_temperatures(self):
        workloads = []
        for arm, temperature in (("mtp5", 0), ("dflash5", 0), ("mtp5", 0.7)):
            campaign = TP4.Campaign.__new__(TP4.Campaign)
            campaign.args = args(arm=arm, temperature=temperature, repeats=3, quality_output_tokens=4096)
            campaign.client = TP4.Client(campaign.args)
            campaign.batch = mock.Mock(return_value=[])
            campaign.gate = mock.Mock(return_value=True)
            self.assertTrue(campaign.unicode())
            cases = [call.args[1][0] for call in campaign.batch.call_args_list]
            self.assertEqual(len(cases), 3)
            self.assertEqual(len({TP4.digest(case["body"]["messages"]) for case in cases}), 3)
            for case in cases:
                self.assertEqual(case["body"]["max_tokens"], 4096)
                self.assertEqual(case["body"]["temperature"], temperature)
                self.assertNotIn("ignore_eos", case["body"])
                self.assertEqual(case["expectation"]["kind"], "korean_unicode")
            workloads.append(cases)
        self.assertEqual(workloads[0], workloads[1])
        self.assertEqual(
            [case["body"]["messages"] for case in workloads[0]],
            [case["body"]["messages"] for case in workloads[2]],
        )
        self.assertNotEqual(workloads[0], workloads[2])

    def test_unicode_stage_is_standalone(self):
        campaign = TP4.Campaign.__new__(TP4.Campaign)
        campaign.args = args(stage="unicode")
        campaign.report = {}
        campaign.client = mock.Mock()
        campaign.client.get.return_value = '{"data": []}'
        campaign.save = mock.Mock()
        campaign.unicode = mock.Mock(return_value=True)
        campaign.accuracy = mock.Mock(side_effect=AssertionError("Unexpected accuracy stage"))
        self.assertTrue(campaign.run())
        campaign.unicode.assert_called_once_with()

    def test_tool_stream_reassembles_fragmented_arguments(self):
        client = StreamClient([
            {"choices": [{"delta": {"tool_calls": [{"index": 0, "id": "call1", "function": {"name": "record_visit", "arguments": '{"days":'}}]}}]},
            {"choices": [{"delta": {"tool_calls": [{"index": 0, "function": {"arguments": "3}"}}]}, "finish_reason": "tool_calls"}]},
            {"usage": {"completion_tokens": 10, "prompt_tokens": 20}},
        ])
        row = client.measure_body("tool", TP4.body_for(client, "tool", 100))
        self.assertTrue(TP4.validate(row, {"kind": "tool", "name": "record_visit", "value": {"days": 3}}))
        self.assertEqual(row["tool_calls"][0]["id"], "call1")
        self.assertIsNotNone(row["ttft_seconds"])

    def test_named_tool_stop_requires_explicit_finish_contract(self):
        row = {
            "finish_reason": "stop",
            "tool_calls": [{"function": {"name": "record_visit", "arguments": '{"days":3}'}}],
        }
        expected = {"kind": "tool", "name": "record_visit", "value": {"days": 3}}
        self.assertFalse(TP4.validate(row, expected))
        self.assertEqual(row["validation"]["problems"], ["Expected tool_calls finish reason"])
        expected["finish_reasons"] = ["stop", "tool_calls"]
        self.assertTrue(TP4.validate(row, expected))
        row["tool_calls"][0]["function"]["arguments"] = '{"days":4}'
        self.assertFalse(TP4.validate(row, expected))
        self.assertEqual(row["validation"]["problems"], ["Tool arguments differ from expected values"])

    def test_known_answers_preserve_json_value_types(self):
        expected = {"kind": "json", "value": {"confirmed": True, "days": 3}}
        for content in ('{"confirmed":1,"days":3}', '{"confirmed":true,"days":3.0}'):
            with self.subTest(content=content):
                row = {"content": content}
                self.assertFalse(TP4.validate(row, expected))
                self.assertEqual(row["validation"]["problems"], ["Known-answer JSON mismatch"])
        self.assertTrue(TP4.validate({"content": '{"days":3,"confirmed":true}'}, expected))

    def test_tool_arguments_preserve_boolean_and_integer_types(self):
        expected = {"kind": "tool", "name": "record_visit", "value": {"confirmed": True, "days": 3}}
        for arguments in ('{"confirmed":1,"days":3}', '{"confirmed":true,"days":3.0}'):
            with self.subTest(arguments=arguments):
                row = {"finish_reason": "tool_calls", "tool_calls": [{"function": {
                    "name": "record_visit", "arguments": arguments,
                }}]}
                self.assertFalse(TP4.validate(row, expected))
                self.assertEqual(row["validation"]["problems"], ["Tool arguments differ from expected values"])
        row["tool_calls"][0]["function"]["arguments"] = '{"days":3,"confirmed":true}'
        self.assertTrue(TP4.validate(row, expected))

    def test_tools_stage_keeps_named_and_auto_contracts_separate(self):
        campaign = TP4.Campaign.__new__(TP4.Campaign)
        campaign.args = args(stage="tools", repeats=3, quality_output_tokens=2048)
        campaign.client = TP4.Client(campaign.args)
        campaign.batch = mock.Mock(return_value=[{"validation": {"passed": True}}])
        campaign.gate = mock.Mock(return_value=True)
        self.assertTrue(campaign.tools())
        self.assertEqual(campaign.batch.call_count, 6)
        for repeat in range(3):
            forced_call, auto_call = campaign.batch.call_args_list[2 * repeat:2 * repeat + 2]
            self.assertEqual(forced_call.args[0], f"accuracy-tools-r{repeat}")
            self.assertEqual(auto_call.args[0], f"accuracy-tools-auto-r{repeat}")
            forced = forced_call.args[1][0]
            automatic = auto_call.args[1][0]
            self.assertEqual(forced["body"]["tool_choice"], {"type": "function", "function": {"name": "record_visit"}})
            self.assertEqual(automatic["body"]["tool_choice"], "auto")
            self.assertEqual(forced["body"]["messages"], automatic["body"]["messages"])
            self.assertEqual(forced["body"]["tools"], automatic["body"]["tools"])
            self.assertEqual(forced["expectation"]["finish_reasons"], ["stop", "tool_calls"])
            self.assertNotIn("finish_reasons", automatic["expectation"])
            self.assertNotIn("ignore_eos", forced["body"])
        campaign.gate.assert_called_once()

    def test_tools_stage_does_not_run_other_quality_or_cache_cases(self):
        campaign = TP4.Campaign.__new__(TP4.Campaign)
        campaign.args = args(stage="tools")
        campaign.client = mock.Mock()
        campaign.client.get.return_value = "{}"
        campaign.report = {}
        campaign.save = mock.Mock()
        campaign.tools = mock.Mock(return_value=True)
        campaign.accuracy = mock.Mock()
        campaign.cache = mock.Mock()
        self.assertTrue(campaign.run())
        campaign.tools.assert_called_once_with()
        campaign.accuracy.assert_not_called()
        campaign.cache.assert_not_called()

    def test_incomplete_stream_and_truncation_fail(self):
        events = [{"choices": [{"delta": {"content": '{"answer":7}'}, "finish_reason": "length"}]}, {"usage": {"completion_tokens": 8}}]
        client = StreamClient(events, done=False)
        row = client.measure_body("incomplete", TP4.body_for(client, "answer", 8))
        self.assertFalse(TP4.validate(row, {"kind": "json", "value": {"answer": 7}}))
        self.assertEqual(len(row["validation"]["problems"]), 2)

    def test_failed_requests_still_count_in_capacity(self):
        rows = [
            {"validation": {"passed": True}, "usage": {"completion_tokens": 100}, "ttft_seconds": 1, "elapsed_seconds": 10},
            {"validation": {"passed": False}, "usage": {"completion_tokens": 20}, "ttft_seconds": 3, "elapsed_seconds": 12},
            {"validation": {"passed": False}, "error": "timeout", "elapsed_seconds": 30},
        ]
        report = TP4.summarize(rows, 30)
        self.assertEqual(report["requests"], 3)
        self.assertEqual(report["failed_requests"], 2)
        self.assertEqual(report["aggregate_output_tps"], 4)
        self.assertAlmostEqual(report["successful_output_tps"], 100 / 30)
        self.assertEqual(report["latency_samples"], 2)
        self.assertEqual(report["ttft_p50_seconds"], 2)

    def test_metrics_keep_labels_and_detect_counter_reset(self):
        before = TP4.parse_metrics('vllm:num_preemptions_total{engine="0"} 2\nvllm:spec_decode_num_drafts_total{engine="0"} 5\nvllm:kv_cache_usage_perc{engine="0"} 0.1\n')
        after = TP4.parse_metrics('vllm:num_preemptions_total{engine="0"} 3\nvllm:spec_decode_num_drafts_total{engine="0"} 1\nvllm:kv_cache_usage_perc{engine="0"} 0.8\n')
        delta = TP4.metric_delta({"samples": before}, {"samples": after})
        self.assertEqual(delta["preemptions"], 1)
        self.assertEqual(delta["counter_resets"], ['vllm:spec_decode_num_drafts_total{engine="0"}'])
        self.assertIsNone(delta["accepted_tokens_per_draft"])

    def test_atomic_report_preserves_old_file_on_serialization_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "report.json"
            TP4.atomic_json(path, {"status": "running"})
            with self.assertRaises(ValueError):
                TP4.atomic_json(path, {"invalid": float("nan")})
            self.assertEqual(json.loads(path.read_text()), {"status": "running"})
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_batch_persists_failed_requests_and_summary(self):
        class FakeClient:
            tokenize_error = None

            def __init__(self):
                self.samples = iter([metrics(0), metrics(2)])

            def snapshot(self):
                return next(self.samples)

            def measure_body(self, label, body, **metadata):
                return {
                    "label": label, **metadata, "content": body["messages"][0]["content"],
                    "usage": {"completion_tokens": 12}, "finished_perf_counter": time.perf_counter(),
                    "ttft_seconds": 0.1, "elapsed_seconds": 0.2,
                }

        with tempfile.TemporaryDirectory() as directory:
            settings = args(output=Path(directory) / "report.json", manifest=None, min_cache_ratio=0.8)
            campaign = TP4.Campaign(settings, FakeClient())
            cases = [
                {"body": {"messages": [{"role": "user", "content": '{"answer":7}'}]}, "expectation": {"kind": "json", "value": {"answer": 7}}},
                {"body": {"messages": [{"role": "user", "content": '{"answer":8}'}]}, "expectation": {"kind": "json", "value": {"answer": 7}}},
            ]
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(ValueError, "Failed response"):
                campaign.batch("known-answer-r0", cases)
            report = json.loads(settings.output.read_text())
            self.assertEqual(report["failed_requests"], 1)
            self.assertEqual(report["summaries"]["known-answer"]["requests"], 2)
            self.assertEqual(report["summaries"]["known-answer"]["completion_tokens_including_failed_requests"], 24)

    def test_long_stage_stops_before_larger_prompts_on_cache_failure(self):
        class FakeClient:
            def get(self, route):
                return "{}"

        class FakeCampaign(TP4.Campaign):
            def __init__(self):
                self.args = args(stage="long", cache_tokens=16384, long_targets=[16384, 131072, 262144])
                self.client, self.report, self.seen = FakeClient(), {}, []

            def save(self):
                pass

            def check_guard(self):
                pass

            def settle(self, previous, target):
                pass

            def accuracy(self):
                return True

            def mixed_cache(self):
                return True

            def cache(self, target, **kwargs):
                self.seen.append(target)
                return len(self.seen) < 3

        campaign = FakeCampaign()
        self.assertFalse(campaign.run())
        self.assertEqual(campaign.seen, [16384, 131072, 262144])

    def test_mixed_batches_have_cold_and_changed_warm_prefixes(self):
        campaign = MixedCampaign()
        self.assertTrue(campaign.mixed_cache())
        self.assertEqual([call[0] for call in campaign.calls], [
            "mixed-cache-warmup-c4", "mixed-cache-warmup-c8",
            "mixed-cache-seed-r0", "mixed-cache-seed-r1", "mixed-cache-seed-r2",
            "mixed-cache-c4", "mixed-cache-c8",
        ])
        seeds = [cases[0] for label, cases, _ in campaign.calls if "seed" in label]
        self.assertTrue(all(case["body"] == seeds[0]["body"] for case in seeds))
        self.assertTrue(all(case.get("cache_mode") is None for case in seeds))
        seed_prefix = seeds[0]["body"]["messages"][0]["content"].split("Return only", 1)[0]
        cold_bodies, expected_values = [], []
        for label, cases, _ in campaign.calls[-2:]:
            concurrency = int(label.rsplit("c", 1)[1])
            self.assertEqual(len(cases), concurrency)
            self.assertEqual([case["cache_mode"] for case in cases], ["warm", "cold"] * (concurrency // 2))
            for case in cases:
                text = case["body"]["messages"][0]["content"]
                self.assertNotIn("ignore_eos", case["body"])
                if case["cache_mode"] == "warm":
                    self.assertTrue(text.startswith(seed_prefix))
                    self.assertNotEqual(case["expectation"], seeds[0]["expectation"])
                    vault = next(iter(case["expectation"]["value"]))
                    self.assertIn(
                        f"Use exactly the key {vault}, with its original access code as the string value.",
                        text,
                    )
                else:
                    self.assertFalse(text.startswith(seed_prefix))
                    cold_bodies.append(TP4.digest(case["body"]))
                    expected_values.append(TP4.digest(case["expectation"]))
        self.assertEqual(len(set(cold_bodies)), 6)
        self.assertEqual(len(set(expected_values)), 6)
        cold_targets = [target for target, parts, _ in campaign.ledger_calls if parts[0] == "mixed-cache-cold"]
        self.assertEqual(cold_targets, [16384, 18688, 16384, 18688, 16384, 18688])

    def test_mixed_payloads_are_identical_across_arms(self):
        mtp, dflash = MixedCampaign("mtp5"), MixedCampaign("dflash5")
        self.assertTrue(mtp.mixed_cache())
        self.assertTrue(dflash.mixed_cache())
        self.assertEqual(mtp.calls, dflash.calls)

    def test_mixed_miss_stops_before_larger_concurrency(self):
        campaign = MixedCampaign(failed_label="mixed-cache-c4")
        self.assertFalse(campaign.mixed_cache())
        self.assertNotIn("mixed-cache-c8", [call[0] for call in campaign.calls])

    def test_long_is_standalone_and_waits_between_sizes(self):
        campaign = TP4.Campaign.__new__(TP4.Campaign)
        campaign.args = args(stage="long", cache_tokens=16384, long_targets=[16384, 131072])
        campaign.client = mock.Mock()
        campaign.client.get.return_value = "{}"
        campaign.report = {}
        campaign.save = mock.Mock()
        campaign.accuracy = mock.Mock(return_value=True)
        campaign.cache = mock.Mock(return_value=True)
        campaign.mixed_cache = mock.Mock(side_effect=AssertionError("Long must not run mixed workloads"))
        campaign.check_guard = mock.Mock()
        campaign.settle = mock.Mock()
        self.assertTrue(campaign.run())
        self.assertEqual(campaign.cache.call_args_list, [mock.call(16384, concurrent=False, label="long"),
                                                        mock.call(131072, concurrent=False, label="long")])
        campaign.settle.assert_called_once_with(16384, 131072)
        campaign.accuracy.assert_not_called()
        campaign.mixed_cache.assert_not_called()

    def test_code_extraction_rejects_top_level_execution(self):
        self.assertEqual(
            TP4.extract_code("```python\ndef bracket_balance(text):\n    return True\n```", "bracket_balance"),
            "def bracket_balance(text):\n    return True",
        )
        for code in ("print('passed')", "import os\ndef bracket_balance(text):\n    return True", "def other():\n    return True"):
            with self.assertRaises(ValueError):
                TP4.extract_code(code, "bracket_balance")

    def test_code_command_has_cpu_container_isolation(self):
        command = TP4.code_command(args(ssh_identity="/tmp/identity with spaces"), "tp4-code-example")
        self.assertIn("IdentityAgent=none", command)
        remote = shlex.split(command[-1])
        self.assertEqual(remote[:5], ["sudo", "-n", "podman", "run", "--rm"])
        for flag, value in (
            ("--network", "none"), ("--cap-drop", "ALL"), ("--security-opt", "no-new-privileges"),
            ("--user", "65534"), ("--memory", "256m"), ("--cpus", "1"),
            ("--pids-limit", "32"), ("--pull", "never"), ("--entrypoint", "python3"),
            ("--timeout", "30"),
        ):
            self.assertEqual(remote[remote.index(flag) + 1], value)
        self.assertIn("--read-only", remote)
        self.assertIn("NVIDIA_VISIBLE_DEVICES=void", remote)
        self.assertNotIn("--device", remote)
        self.assertNotIn("--volume", remote)
        self.assertNotIn("--mount", remote)
        self.assertEqual(remote[-4:], ["-I", "-S", "-c", TP4.CODE_RUNNER])
        compile(TP4.CODE_RUNNER, "<fixed-runner>", "exec")

    def test_remote_code_timeout_rounds_up_and_rejects_nonfinite_cli_values(self):
        remote = shlex.split(TP4.code_command(args(code_timeout=1.25), "tp4-code-test")[-1])
        self.assertEqual(remote[remote.index("--timeout") + 1], "2")
        for value in ("nan", "inf", "-inf", "0", "-1", "61"):
            with self.subTest(value=value), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                TP4.parse_args([
                    "--model", "spark-current", "--arm", "test", "--campaign-id", "test",
                    "--output", "/tmp/unused-tp4-timeout-test.json", "--code-timeout", value,
                ])

    def test_code_is_stdin_data_and_cleanup_is_always_attempted(self):
        report = {"passed": True, "tests_passed": 7, "tests_total": 7}
        completed = subprocess.CompletedProcess([], 0, json.dumps(report), "")
        cleanup = subprocess.CompletedProcess([], 0, "", "")
        code = "def bracket_balance(text):\n    return True"
        with mock.patch.object(TP4.subprocess, "run", side_effect=[completed, cleanup]) as run:
            result = TP4.run_code(args(), code, "bracket_balance")
        self.assertTrue(result["passed"])
        first = run.call_args_list[0]
        self.assertNotIn(code, first.args[0][-1])
        self.assertEqual(json.loads(first.kwargs["input"])["code"], code)
        remote_cleanup = shlex.split(run.call_args_list[1].args[0][-1])
        self.assertEqual(remote_cleanup[:6], ["sudo", "-n", "podman", "rm", "--force", "--ignore"])
        self.assertEqual(remote_cleanup[-1], result["container"])

    def test_code_timeout_cleans_up_named_container(self):
        timeout = subprocess.TimeoutExpired(["ssh"], 30)
        cleanup = subprocess.CompletedProcess([], 0, "", "")
        with mock.patch.object(TP4.subprocess, "run", side_effect=[timeout, cleanup]) as run:
            result = TP4.run_code(args(), "def bracket_balance(text):\n    while True: pass", "bracket_balance")
        self.assertFalse(result["passed"])
        self.assertTrue(result["timed_out"])
        self.assertEqual(run.call_count, 2)
        self.assertEqual(result["cleanup_exit_code"], 0)

    def test_code_stdout_cannot_override_fixed_test_count(self):
        completed = subprocess.CompletedProcess([], 0, '{"passed":true,"tests_passed":0,"tests_total":0}', "")
        cleanup = subprocess.CompletedProcess([], 0, "", "")
        with mock.patch.object(TP4.subprocess, "run", side_effect=[completed, cleanup]):
            result = TP4.run_code(args(), "def bracket_balance(text):\n    return True", "bracket_balance")
        self.assertFalse(result["passed"])

    def test_code_image_requires_digest(self):
        self.assertTrue(TP4.PINNED_IMAGE.fullmatch("sha256:" + "1" * 64))
        self.assertTrue(TP4.PINNED_IMAGE.fullmatch("registry.example/repo@sha256:" + "a" * 64))
        self.assertFalse(TP4.PINNED_IMAGE.fullmatch("registry.example/repo:latest"))


if __name__ == "__main__":
    unittest.main()
