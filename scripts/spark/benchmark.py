#!/usr/bin/env python3
"""Run bounded TP4 diagnostics against an already running server.

Uses the existing benchmark's HTTP, SSE, and tokenized ledger helpers. This
program never changes services, clears a server's cache, or executes model code
on the host. Executable coding tests require an opt-in remote container.
"""

import argparse
import ast
import concurrent.futures
import datetime
import hashlib
import http.client
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid


SPEC = importlib.util.spec_from_file_location(
    "spark_client", Path(__file__).with_name("client.py")
)
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)
SNAPSHOT_SPEC = importlib.util.spec_from_file_location("spark_snapshot", Path(__file__).with_name("snapshot.py"))
SNAPSHOT = importlib.util.module_from_spec(SNAPSHOT_SPEC)
SNAPSHOT_SPEC.loader.exec_module(SNAPSHOT)

METRIC_NAMES = (
    "prefix_cache", "preemption", "spec_decode", "kv_cache_usage",
    "gpu_cache_usage", "num_requests_running", "num_requests_waiting", "request_success_total",
)
METRIC_LINE = re.compile(r"^([a-zA-Z_:][a-zA-Z0-9_:]*)(\{.*\})?\s+([^\s]+)(?:\s+[^\s]+)?$")
PINNED_IMAGE = re.compile(r"(?:sha256:|[A-Za-z0-9][A-Za-z0-9._:/-]*@sha256:)[a-f0-9]{64}\Z")
CODE_CASES = {
    "merge_intervals": {
        "prompt": "Write merge_intervals(intervals), merging overlapping closed integer intervals and returning a list of lists sorted by start. Empty input returns []. Endpoint-touching intervals overlap. Input intervals have start <= end and may be unsorted or duplicated.",
        "tests": [
            {"args": [[]], "expected": []},
            {"args": [[[8, 10], [1, 3], [2, 6], [15, 18], [10, 12]]], "expected": [[1, 6], [8, 12], [15, 18]]},
            {"args": [[[1, 4], [2, 3], [1, 4]]], "expected": [[1, 4]]},
            {"args": [[[-5, -1], [-1, 0], [2, 2], [3, 5]]], "expected": [[-5, 0], [2, 2], [3, 5]]},
            {"args": [[[4, 4], [2, 3], [3, 4], [8, 9]]], "expected": [[2, 4], [8, 9]]},
        ],
    },
    "bracket_balance": {
        "prompt": "Write bracket_balance(text), returning bool for whether (), [], and {} are correctly nested and balanced. Ignore every other character. Empty input is balanced.",
        "tests": [
            {"args": [""], "expected": True},
            {"args": ["a([{}])z"], "expected": True},
            {"args": ["([)]"], "expected": False},
            {"args": [")("], "expected": False},
            {"args": ["unfinished {"], "expected": False},
            {"args": ["plain text"], "expected": True},
            {"args": ["[]{}()"], "expected": True},
        ],
    },
}
CODE_RUNNER = r'''
import ast
import builtins
import json
import sys

payload = json.load(sys.stdin)
result = {"passed": False, "tests_passed": 0, "tests_total": len(payload["tests"])}
try:
    tree = ast.parse(payload["code"])
    if not tree.body or any(not isinstance(node, ast.FunctionDef) for node in tree.body):
        raise ValueError("Only function definitions are accepted")
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom, ast.Global, ast.Nonlocal, ast.ClassDef)):
            raise ValueError("Imports, classes, and scope mutation are disabled")
        if isinstance(node, ast.Attribute) and node.attr.startswith("__"):
            raise ValueError("Dunder attribute access is disabled")
        if isinstance(node, ast.Name) and node.id.startswith("__"):
            raise ValueError("Dunder names are disabled")
        if isinstance(node, ast.FunctionDef) and node.decorator_list:
            raise ValueError("Decorators are disabled")
    allowed = ("abs", "all", "any", "bool", "dict", "enumerate", "filter", "float",
               "int", "isinstance", "len", "list", "map", "max", "min", "range",
               "reversed", "set", "slice", "sorted", "str", "sum", "tuple", "zip",
               "Exception", "ValueError", "TypeError")
    namespace = {"__builtins__": {name: getattr(builtins, name) for name in allowed}}
    exec(compile(tree, "<candidate>", "exec"), namespace)
    function = namespace[payload["function"]]
    for index, case in enumerate(payload["tests"]):
        actual = function(*case["args"])
        if type(actual) is not type(case["expected"]) or actual != case["expected"]:
            raise AssertionError("Held-out case " + str(index) + " returned the wrong value")
        result["tests_passed"] += 1
    result["passed"] = True
except BaseException as error:
    result["error"] = type(error).__name__ + ": " + str(error)[:1000]
print(json.dumps(result))
sys.exit(0 if result["passed"] else 1)
'''.strip()


def extract_code(content, function):
    code = content.strip()
    if code.startswith("```"):
        first, separator, rest = code.partition("\n")
        if not separator or first.lower() not in ("```", "```python", "```py") or not rest.endswith("```"):
            raise ValueError("Expected a single Python code block")
        code = rest[:-3].strip()
    if len(code.encode()) > 65536:
        raise ValueError("Generated code exceeds 64 KiB")
    tree = ast.parse(code)
    if not tree.body or any(not isinstance(node, ast.FunctionDef) for node in tree.body):
        raise ValueError("Generated answer must contain only function definitions")
    if function not in {node.name for node in tree.body}:
        raise ValueError(f"Generated answer does not define {function}")
    return code


def code_ssh(args, command):
    invocation = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5"]
    if args.ssh_identity:
        invocation += ["-o", "IdentityAgent=none", "-o", "IdentitiesOnly=yes", "-i", args.ssh_identity]
    return invocation + [args.code_host, shlex.join(command)]


def code_command(args, name):
    return code_ssh(args, [
        "sudo", "-n", "podman", "run", "--rm", "--interactive", "--pull", "never",
        "--name", name, "--network", "none", "--read-only", "--cap-drop", "ALL",
        "--timeout", str(math.ceil(args.code_timeout)),
        "--env", "NVIDIA_VISIBLE_DEVICES=void", "--env", "CUDA_VISIBLE_DEVICES=",
        "--http-proxy=false", "--image-volume", "ignore",
        "--security-opt", "no-new-privileges", "--user", "65534", "--pids-limit", "32",
        "--memory", "256m", "--cpus", "1", "--tmpfs", "/tmp:rw,noexec,nosuid,size=16m",
        "--entrypoint", "python3", args.code_image, "-I", "-S", "-c", CODE_RUNNER,
    ])


def run_code(args, content, function):
    try:
        code = extract_code(content, function)
    except (SyntaxError, ValueError) as error:
        return {"passed": False, "error": str(error)[:2000], "executed": False}
    name = "tp4-code-" + uuid.uuid4().hex
    payload = {"code": code, "function": function, "tests": CODE_CASES[function]["tests"]}
    result = {"passed": False, "container": name, "image": args.code_image, "host": args.code_host}
    started = time.perf_counter()
    try:
        process = subprocess.run(
            code_command(args, name), input=json.dumps(payload), text=True,
            capture_output=True, timeout=args.code_timeout,
        )
        result.update(exit_code=process.returncode, stdout=process.stdout[:4000], stderr=process.stderr[:4000])
        try:
            checks = json.loads(process.stdout)
            result["checks"] = checks
            result["passed"] = (
                process.returncode == 0 and checks.get("passed") is True
                and checks.get("tests_passed") == len(payload["tests"])
                and checks.get("tests_total") == len(payload["tests"])
            )
        except (ValueError, AttributeError):
            result["error"] = "Container did not return a valid test report"
    except subprocess.TimeoutExpired:
        result["error"] = f"Code container timed out after {args.code_timeout} seconds"
        result["timed_out"] = True
    except OSError as error:
        result["error"] = str(error)
    finally:
        try:
            cleanup = subprocess.run(
                code_ssh(args, ["sudo", "-n", "podman", "rm", "--force", "--ignore", name]),
                capture_output=True, text=True, timeout=10,
            )
            result["cleanup_exit_code"] = cleanup.returncode
            if cleanup.returncode:
                result["cleanup_error"] = cleanup.stderr[:1000]
                result["passed"] = False
        except (OSError, subprocess.TimeoutExpired) as error:
            result["cleanup_error"] = str(error)[:1000]
            result["passed"] = False
    result["elapsed_seconds"] = time.perf_counter() - started
    return result


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=True).encode()).hexdigest()


def nonce(args, *parts):
    # Arm and endpoint deliberately do not affect workloads in paired trials.
    return digest([args.campaign_id, args.seed, *parts])


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
            temporary = stream.name
            json.dump(value, stream, indent=2, allow_nan=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


def percentile(values, fraction):
    values = sorted(value for value in values if value is not None)
    if not values:
        return None
    position = (len(values) - 1) * fraction
    lo, hi = math.floor(position), math.ceil(position)
    return values[lo] + (values[hi] - values[lo]) * (position - lo)


def parse_metrics(raw):
    samples = {}
    for line in raw.splitlines():
        if line.startswith("#"):
            continue
        match = METRIC_LINE.match(line)
        if not match or not any(name in match[1] for name in METRIC_NAMES):
            continue
        try:
            value = float(match[3])
        except ValueError:
            continue
        if math.isfinite(value):
            samples[match[1] + (match[2] or "")] = value
    return samples


def metric_delta(before, after):
    old, new = before.get("samples", {}), after.get("samples", {})
    counters, gauges, resets = {}, {}, []
    for key in old.keys() & new.keys():
        name = key.split("{", 1)[0]
        if name.endswith(("_total", "_count", "_sum", "_bucket")):
            if new[key] < old[key]:
                resets.append(key)
            else:
                counters[key] = new[key] - old[key]
        else:
            gauges[key] = {"before": old[key], "after": new[key]}
    def total(name):
        values = [value for key, value in counters.items() if key.split("{", 1)[0] == name]
        return sum(values) if values else None

    drafts = total("vllm:spec_decode_num_drafts_total")
    drafted = total("vllm:spec_decode_num_draft_tokens_total")
    accepted = total("vllm:spec_decode_num_accepted_tokens_total")
    return {
        "counters": counters, "gauges": gauges, "counter_resets": sorted(resets),
        "preemptions": total("vllm:num_preemptions_total"),
        "drafts": drafts, "drafted_tokens": drafted, "accepted_tokens": accepted,
        "acceptance_fraction": accepted / drafted if accepted is not None and drafted else None,
        "accepted_tokens_per_draft": accepted / drafts if accepted is not None and drafts else None,
        "mean_acceptance_length_including_bonus": 1 + accepted / drafts if accepted is not None and drafts else None,
    }


def cached_tokens(row):
    usage = row.get("usage") or {}
    return (usage.get("prompt_tokens_details") or {}).get("cached_tokens")


def accounting(before, after, expected):
    parsed = []
    required = ("vllm:num_requests_running", "vllm:num_requests_waiting",
                "vllm:request_success_total", "vllm:num_preemptions_total")
    for snapshot in (before, after):
        if snapshot.get("error"):
            raise ValueError("Request accounting metrics are unavailable")
        values = {}
        for line in snapshot.get("raw", "").splitlines():
            if not any(re.match(re.escape(name) + r"(?:\{|\s|$)", line) for name in required):
                continue
            match = METRIC_LINE.fullmatch(line)
            if not match:
                raise ValueError("Malformed request accounting metric")
            key, value = match[1] + (match[2] or ""), float(match[3])
            if not math.isfinite(value) or value < 0 or not value.is_integer() or key in values:
                raise ValueError("Invalid or duplicated request accounting metric")
            values[key] = value
        for name in ("vllm:num_requests_running", "vllm:num_requests_waiting"):
            gauges = [value for key, value in values.items() if key.split("{", 1)[0] == name]
            if not gauges or any(value != 0 for value in gauges):
                raise ValueError("Request accounting requires an idle server")
        counters = {}
        for name in ("vllm:request_success_total", "vllm:num_preemptions_total"):
            entries = {key: value for key, value in values.items() if key.split("{", 1)[0] == name}
            declared = f"# TYPE {name} counter" in snapshot.get("raw", "").splitlines()
            if (not entries and not declared) or any(value < 0 for value in entries.values()):
                raise ValueError(f"Missing or invalid counter: {name}")
            counters[name] = entries
        parsed.append(counters)
    deltas = {}
    for name, old in parsed[0].items():
        new = parsed[1][name]
        if old.keys() - new.keys() or any(new[key] < old[key] for key in old):
            raise ValueError(f"Counter labels reset or disappeared: {name}")
        deltas[name] = sum(new.values()) - sum(old.values())
    if deltas["vllm:request_success_total"] != expected or deltas["vllm:num_preemptions_total"] != 0:
        raise ValueError("Unexpected successful requests or preemptions")
    return {"expected_requests": expected, "successful_request_delta": expected, "preemptions": 0}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def timestamp(value):
    parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(parsed.tzinfo is not None, "Evidence timestamps must include a timezone")
    return parsed


def invalid_json_constant(value):
    raise ValueError(f"Nonfinite JSON constant in response: {value}")


def validate(row, expectation=None, cache_mode=None, min_cache_ratio=0.8, prompt_target=None, context_window=None, output_tokens=None):
    problems = []
    if row.get("error"):
        problems.append(row["error"])
    if "\ufffd" in row.get("content", "") + row.get("reasoning", "") + json.dumps(row.get("tool_calls", []), ensure_ascii=False):
        problems.append("Unicode replacement character in output")
    if expectation:
        if row.get("finish_reason") == "length" and expectation.get("kind") != "korean_unicode":
            problems.append("Quality answer exhausted its output budget")
        try:
            if expectation["kind"] == "json":
                answer = row.get("content", "").strip()
                if answer.startswith("```") and answer.endswith("```"):
                    answer = answer.split("\n", 1)[1].rsplit("```", 1)[0].strip()
                if digest(json.loads(answer)) != digest(expectation["value"]):
                    problems.append("Known-answer JSON mismatch")
            elif expectation["kind"] == "tool":
                calls = row.get("tool_calls", [])
                if len(calls) != 1 or calls[0]["function"]["name"] != expectation["name"]:
                    problems.append("Expected exactly one call to the requested tool")
                elif digest(json.loads(calls[0]["function"]["arguments"])) != digest(expectation["value"]):
                    problems.append("Tool arguments differ from expected values")
                finish_reasons = expectation.get("finish_reasons", ["tool_calls"])
                if row.get("finish_reason") not in finish_reasons:
                    problems.append(f"Expected {' or '.join(finish_reasons)} finish reason")
            elif expectation["kind"] in ("korean_prose", "korean_unicode"):
                hangul = len(re.findall("[\uac00-\ud7a3]", row.get("content", "")))
                row["unicode_probe"] = {
                    "content_hangul_syllables": hangul,
                    "replacement_characters": (row.get("content", "") + row.get("reasoning", "")).count("\ufffd"),
                }
                if hangul < expectation["min_hangul_syllables"]:
                    problems.append("Free-generation probe did not produce enough Korean text")
        except (ValueError, KeyError, IndexError, TypeError):
            problems.append("Unparseable known-answer response")
    if cache_mode:
        cached = cached_tokens(row)
        prompt = (row.get("usage") or {}).get("prompt_tokens")
        if type(cached) is not int or type(prompt) is not int or prompt <= 0:
            problems.append("Per-request cached-token usage is missing")
        elif cached < 0 or cached > prompt:
            problems.append("Invalid cached-token usage")
        elif cache_mode == "warm" and cached / prompt < min_cache_ratio:
            problems.append(f"Prefix reuse below {min_cache_ratio:.0%}: {cached}/{prompt} cached tokens")
        elif cache_mode == "cold" and cached / prompt > 0.1:
            problems.append(f"Cold-prefix trial was already cached: {cached}/{prompt} tokens")
    if prompt_target is not None:
        usage = row.get("usage") or {}
        prompt, completion = usage.get("prompt_tokens"), usage.get("completion_tokens")
        if type(prompt) is not int or not max(prompt_target * .9, prompt_target - 256) <= prompt <= prompt_target + 256:
            problems.append("Actual prompt tokens differ from the requested context target")
        elif context_window is not None and prompt + output_tokens > context_window:
            problems.append("Actual prompt tokens do not reserve the requested output budget")
        if type(completion) is not int or not 0 < completion <= output_tokens:
            problems.append("Invalid completion-token usage")
        if row.get("finish_reason") not in (("stop",) if expectation else ("stop", "length")):
            problems.append("Missing or unexpected terminal finish reason")
    row["validation"] = {"passed": not problems, "problems": problems}
    return not problems


def summarize(rows, elapsed):
    def count(value):
        return value if type(value) is int and value >= 0 else 0

    failed = sum(not row.get("validation", {}).get("passed", False) for row in rows)
    counts = [(row.get("usage") or {}).get("completion_tokens") for row in rows]
    tokens = sum(count(value) for value in counts)
    successful_tokens = sum(
        count((row.get("usage") or {}).get("completion_tokens"))
        for row in rows if row.get("validation", {}).get("passed", False)
    )
    rates = [row.get("decode_tps_estimate") for row in rows]
    return {
        "requests": len(rows), "failed_requests": failed, "all_passed": failed == 0,
        "completion_tokens_including_failed_requests": tokens,
        "requests_missing_or_invalid_completion_usage": sum(type(value) is not int or value < 0 for value in counts),
        "elapsed_seconds": elapsed,
        "aggregate_output_tps": tokens / elapsed if elapsed else None,
        "successful_output_tps": successful_tokens / elapsed if elapsed else None,
        "ttft_p50_seconds": percentile([row.get("ttft_seconds") for row in rows], 0.5),
        "ttft_p95_seconds": percentile([row.get("ttft_seconds") for row in rows], 0.95),
        "request_latency_p50_seconds": percentile([row.get("elapsed_seconds") for row in rows], 0.5),
        "request_latency_p95_seconds": percentile([row.get("elapsed_seconds") for row in rows], 0.95),
        "decode_tps_p50_estimate": percentile(rates, 0.5),
        "latency_samples": sum(row.get("ttft_seconds") is not None for row in rows),
        "cached_tokens": sum(count(cached_tokens(row)) for row in rows),
        "requests_missing_cache_usage": sum(cached_tokens(row) is None for row in rows),
    }


class Client(BASE.Client):
    def get(self, route):
        headers = {}
        if os.environ.get("OPENAI_API_KEY"):
            headers["Authorization"] = f"Bearer {os.environ['OPENAI_API_KEY']}"
        request = urllib.request.Request(f"{self.base}{route}", headers=headers)
        with urllib.request.urlopen(request, timeout=min(self.args.timeout, 10)) as response:
            return response.read().decode("utf-8")

    def snapshot(self):
        try:
            raw = self.get("/metrics")
            return {"at": utc_now(), "samples": parse_metrics(raw), "raw": raw}
        except (OSError, ValueError, http.client.HTTPException) as error:
            return {"at": utc_now(), "error": str(error), "samples": {}}

    def measure_body(self, label, body, **metadata):
        result = {"label": label, "request_sha256": digest(body), **metadata}
        content, reasoning, calls = [], [], {}
        first = last = usage = None
        done = False
        started = time.perf_counter()
        try:
            with self.post("/v1/chat/completions", body) as response:
                for raw in BASE.sse_events(response):
                    now = time.perf_counter()
                    if raw == "[DONE]":
                        done = True
                        break
                    event = json.loads(raw, parse_constant=invalid_json_constant)
                    if event.get("error"):
                        raise ValueError(json.dumps(event["error"]))
                    if event.get("usage"):
                        usage = event["usage"]
                    for choice in event.get("choices", []):
                        delta = choice.get("delta") or {}
                        text = delta.get("content") or ""
                        thought = delta.get("reasoning_content") or delta.get("reasoning") or ""
                        tool_parts = delta.get("tool_calls") or []
                        if text or thought or tool_parts:
                            first = now if first is None else first
                            last = now
                        content.append(text)
                        reasoning.append(thought)
                        for part in tool_parts:
                            call = calls.setdefault(part["index"], {"function": {"name": "", "arguments": ""}})
                            if part.get("id"):
                                call["id"] = part["id"]
                            for key in ("name", "arguments"):
                                call["function"][key] += (part.get("function") or {}).get(key) or ""
                        if choice.get("finish_reason"):
                            result["finish_reason"] = choice["finish_reason"]
            if not done or not usage or "completion_tokens" not in usage or first is None:
                raise ValueError("Incomplete stream, missing token usage, or empty output")
            if result.get("finish_reason") not in ("stop", "length", "tool_calls"):
                raise ValueError("Missing or unexpected terminal finish reason")
            if (type(usage.get("prompt_tokens")) is not int or usage["prompt_tokens"] <= 0
                    or type(usage["completion_tokens"]) is not int
                    or not 0 < usage["completion_tokens"] <= body["max_tokens"]):
                raise ValueError("Invalid prompt or completion token usage")
            if body.get("ignore_eos") and usage["completion_tokens"] != body["max_tokens"]:
                raise ValueError("Fixed output-token budget was not honored")
        except urllib.error.HTTPError as error:
            result["error"] = f"HTTP {error.code}: {error.read().decode(errors='replace')[:4000]}"
        except (OSError, ValueError, KeyError, TypeError, http.client.HTTPException) as error:
            result["error"] = str(error)
        elapsed = time.perf_counter() - started
        tokens = (usage or {}).get("completion_tokens")
        decode_seconds = last - first if last is not None and first is not None else None
        result.update(
            content="".join(content), reasoning="".join(reasoning),
            tool_calls=[calls[key] for key in sorted(calls)], usage=usage,
            elapsed_seconds=elapsed, ttft_seconds=first - started if first is not None else None,
            decode_seconds=decode_seconds,
            decode_tps_estimate=(tokens - 1) / decode_seconds if type(tokens) is int and tokens > 0 and decode_seconds else None,
            finished_perf_counter=time.perf_counter(),
        )
        return result


def body_for(client, prompt, tokens, fixed=False):
    body = client.chat_body(prompt)
    body.update(
        stream=True, stream_options={"include_usage": True},
        temperature=client.args.temperature, seed=client.args.seed, max_tokens=tokens,
    )
    if fixed:
        body["ignore_eos"] = True
    return body


def cache_bodies(client, prompt, expected, tokens):
    original = body_for(client, prompt, tokens)
    prefix = prompt.rsplit("Return only a JSON object", 1)[0]
    suffix = body_for(client, prefix + "Return only a JSON object with the exact access code for vault_b, and no other keys. Use exactly the key vault_b, with its original access code as the string value.", tokens)
    appended = body_for(client, prompt, tokens)
    appended["messages"] += [
        {"role": "assistant", "content": json.dumps(expected, sort_keys=True)},
        {"role": "user", "content": "Now return only a JSON object with vault_c's original access code, and no other keys. Use exactly the key vault_c, with its original access code as the string value."},
    ]
    return original, suffix, appended


class Campaign:
    def __init__(self, args, client):
        self.args, self.client = args, client
        self.report = {
            "schema_version": 1, "started_at": utc_now(), "status": "running",
            "settings": {key: str(value) if isinstance(value, Path) else value for key, value in vars(args).items() if key != "ssh_identity"},
            "manifest": json.loads(args.manifest.read_text()) if args.manifest else None,
            "limitations": [
                "Known-answer probes are diagnostics, not a broad reasoning-quality evaluation or formal qualification.",
                ("Executable coding uses fixed held-out cases in a CPU-only remote container; generated code is never executed on the host."
                 if getattr(args, "code_host", None) else
                 "Executable coding accuracy is not covered; generated code is never executed on the host."),
                "Process-wide successful-request accounting cannot exclude cancelled traffic or unrelated host load.",
                "SSE decode speed is estimated; aggregate throughput uses final server token counts including reasoning.",
                "Throughput runs force output length; quality and cache retrieval runs allow EOS.",
                "No cache reset is performed; a fresh campaign ID is required after repeating an arm on the same service.",
                "Cache eviction under full-capacity load is not covered by the default bounded memory-pressure probe.",
                "The manifest records operator-supplied runtime identity; this HTTP client cannot verify TP size or image digest.",
            ],
            "results": [], "batches": [], "gates": [], "quiet_intervals": [], "complete": False,
            "source_hashes": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in
                              (Path(__file__), Path(BASE.__file__), Path(SNAPSHOT.__file__))},
        }
        self.initial_metrics = self.last_metrics = None
        self.guard_record = None
        if self.report["manifest"] is not None:
            if self.report["manifest"].get("tensor_parallel_size") != 4:
                raise ValueError("Manifest must declare tensor_parallel_size=4")
            context = self.report["manifest"].get("context_window")
            if context is not None and context != args.context_window:
                raise ValueError("Manifest context_window differs from the benchmark setting")
        if getattr(args, "stage", None) == "long":
            manifest = self.report["manifest"]
            require(manifest is not None and not SNAPSHOT.collection_errors(manifest)
                    and not SNAPSHOT.validate_tp4(manifest["nodes"]), "Long diagnostics require a clean full TP4 manifest")
            age = (datetime.datetime.now(datetime.timezone.utc) - timestamp(manifest["sampled_at"])).total_seconds()
            require(0 <= age <= 300, "Long diagnostics require a manifest no older than five minutes")
            head = next(node for node in manifest["nodes"] if node["container"]["environment"]["INFER_RANK"] == "0")
            command = head["container"]["args"]
            require(command.count("--port") == 1 and command.index("--port") + 1 < len(command), "Manifest is missing the serving port")
            endpoint = f"http://{head['node']}:{command[command.index('--port') + 1]}"
            require(args.endpoint.rstrip("/").removesuffix("/v1") == endpoint, "Long endpoint must match the manifest's head node and port")
            self.initial_metrics = self.last_metrics = {"raw": manifest["api_metrics"]["body"]}
            self.report["initial_metrics"] = self.initial_metrics
            self.report["limitations"] += [
                "Long is a standalone single-stream size/reuse diagnostic, not a paired quality or full-pool eviction qualification.",
                "Resource enforcement is sampled; a passing report still requires its monitor's clean final sample and successful exit.",
            ]

    def check_guard(self):
        if getattr(self.args, "stage", None) != "long":
            return None
        raw = self.args.guard_log.read_bytes()
        require(len(raw) <= 64 * 1024 * 1024, "Guard log exceeds the bounded reader limit")
        complete = raw[:raw.rfind(b"\n") + 1]
        if self.guard_record:
            size = self.guard_record["bytes"]
            require(len(complete) >= size and hashlib.sha256(complete[:size]).hexdigest() == self.guard_record["sha256"], "Guard log prefix changed")
        rows = [json.loads(line) for line in complete.splitlines() if line.strip()]
        require(rows and rows[0].get("guard_phase") == "preflight"
                and sum(row.get("guard_phase") == "preflight" for row in rows) == 1, "Require one fresh guarded watch invocation")
        require(all(row.get("guard_phase") in ("preflight", "running") for row in rows), "Guard is finished or reports a cleanup failure")
        age = (datetime.datetime.now(datetime.timezone.utc) - timestamp(rows[-1]["sampled_at"])).total_seconds()
        require(0 <= age <= 120, "Active guard sample is stale or future-dated")
        policy = rows[0].get("guard_policy", {})
        minimum, swap = policy.get("min_available_gib"), policy.get("max_new_swapout_pages")
        require(type(minimum) in (int, float) and math.isfinite(minimum) and minimum >= 8,
                "Long diagnostics require an explicit guard floor of at least 8 GiB")
        require(type(swap) is int and swap >= 0 and policy.get("fail_on_new_oom") is True,
                "Long diagnostics require explicit swap-out and new-OOM guards")
        nodes = {node["node"]: node for node in self.report["manifest"]["nodes"]}
        require(len(nodes) == 4, "Manifest must contain four distinct nodes")
        guards = SNAPSHOT.ResourceGuards(argparse.Namespace(nodes=list(nodes), min_available_gib=minimum,
                                                           max_new_swapout_pages=swap, fail_on_new_oom=True))
        for row in rows:
            require(row.get("guard_policy") == guards.policy and row.get("guard_failed") is False
                    and row.get("guard_failures") == [], "Guard policy/source changed or resource guard failed")
            require(not SNAPSHOT.collection_errors(row) and row.get("instance") == self.report["manifest"]["instance"],
                    "Guard health/collection failed or monitors another instance")
            checked = dict(row)
            require(not guards.evaluate(checked, row["guard_phase"]), "Raw guard observations fail the resource policy")
            for node in row["nodes"]:
                expected, service = nodes[node["node"]]["service"], node["service"]
                require(all(isinstance(expected.get(key), str) and expected[key].strip() and service.get(key) == expected[key]
                            for key in ("InvocationID", "ControlGroup", "MainPID"))
                        and expected["MainPID"].isdecimal() and int(expected["MainPID"]) > 0, "Guarded service identity changed")
        self.guard_record = {"path": str(self.args.guard_log.resolve()), "bytes": len(complete),
                             "sha256": hashlib.sha256(complete).hexdigest(), "last_sampled_at": rows[-1]["sampled_at"],
                             "pswpout": {node["node"]: node["vmstat"]["pswpout"] for node in rows[-1]["nodes"]}, "policy": policy}
        self.report["guard_trace"] = self.guard_record
        return self.guard_record

    def save(self):
        self.report["tokenize_error"] = self.client.tokenize_error
        self.report["failed_requests"] = sum(not row["validation"]["passed"] for row in self.report["results"])
        groups = {}
        for batch in self.report["batches"]:
            if not batch["warmup"]:
                groups.setdefault(re.sub(r"-r\d+", "", batch["label"]), []).append(batch)
        self.report["summaries"] = {}
        for key, batches in groups.items():
            labels = {batch["label"] for batch in batches}
            rows = [row for row in self.report["results"] if row["batch"] in labels]
            self.report["summaries"][key] = {
                "trials": len(batches),
                **summarize(rows, sum(batch["elapsed_seconds"] for batch in batches)),
                "trial_aggregate_tps_p50": percentile([batch["aggregate_output_tps"] for batch in batches], 0.5),
                "trial_aggregate_tps_min": min(batch["aggregate_output_tps"] for batch in batches),
                "trial_aggregate_tps_max": max(batch["aggregate_output_tps"] for batch in batches),
            }
        atomic_json(self.args.output, self.report)

    def batch(self, label, cases, warmup=False):
        self.check_guard()
        before = self.client.snapshot()
        gap = accounting(self.last_metrics or before, before, 0)
        if self.initial_metrics is None:
            self.initial_metrics = before
            self.report["initial_metrics"] = before
        self.save()
        started = time.perf_counter()
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(cases)) as pool:
            pending = {
                pool.submit(self.client.measure_body, f"{label}-{index}", case["body"],
                            batch=label, warmup=warmup,
                            prompt_sha256=digest(case["body"]["messages"])): (index, case)
                for index, case in enumerate(cases)
            }
            rows = []
            for future in concurrent.futures.as_completed(pending):
                index, case = pending[future]
                row = future.result()
                row["case_index"] = index
                row["expectation"] = case.get("expectation")
                row["cache_mode"] = case.get("cache_mode")
                row["prompt_target"] = case.get("prompt_target")
                validate(row, case.get("expectation"), case.get("cache_mode"), self.args.min_cache_ratio,
                         case.get("prompt_target"), getattr(self.args, "context_window", None), case["body"].get("max_tokens"))
                if case.get("code_function"):
                    if row.get("finish_reason") == "length":
                        row["validation"]["passed"] = False
                        row["validation"]["problems"].append("Generated code exhausted its output budget")
                    if row["validation"]["passed"]:
                        row["code_execution"] = run_code(self.args, row["content"], case["code_function"])
                        if not row["code_execution"]["passed"]:
                            row["validation"]["passed"] = False
                            row["validation"]["problems"].append("Executable coding checks failed")
                rows.append(row)
                self.report["results"].append(row)
                self.save()
                print(f"{row['label']}: {'PASS' if row['validation']['passed'] else 'FAIL'} "
                      f"TTFT={row['ttft_seconds']} cached={cached_tokens(row)} "
                      f"{'; '.join(row['validation']['problems'])}", flush=True)
        elapsed = max(row["finished_perf_counter"] for row in rows) - started
        after = self.client.snapshot()
        batch = {
            "label": label, "warmup": warmup, "concurrency": len(cases),
            **summarize(rows, elapsed), "metrics_before": before, "metrics_after": after,
            "metrics_delta": metric_delta(before, after),
        }
        self.report["batches"].append(batch)
        self.save()
        batch["accounting"] = {"gap": gap, "request": accounting(before, after, len(cases))}
        self.last_metrics = after
        self.check_guard()
        self.save()
        require(all(row["validation"]["passed"] for row in rows), f"Failed response in {label}; no further batch will run")
        return sorted(rows, key=lambda row: row["case_index"])

    def settle(self, previous_target, next_target):
        first = self.check_guard()
        before = self.client.snapshot()
        accounting(self.last_metrics or before, before, 0)
        started = datetime.datetime.now(datetime.timezone.utc)
        deadline = time.monotonic() + 90
        interval = {"from_target": previous_target, "to_target": next_target, "started_at": started.isoformat(), "complete": False}
        self.report["quiet_intervals"].append(interval)
        self.save()
        previous = before
        while True:
            require(time.monotonic() <= deadline, "Quiet interval could not obtain a timely final guard sample")
            trace = self.check_guard()
            require(trace["pswpout"] == first["pswpout"], "New swap-out during the quiet interval")
            current = self.client.snapshot()
            accounting(previous, current, 0)
            previous = current
            if (timestamp(trace["last_sampled_at"]) - started).total_seconds() >= 60:
                break
            time.sleep(min(5, max(0, deadline - time.monotonic())))
        self.last_metrics = previous
        interval.update(complete=True, finished_at=utc_now(), guard_start=first, guard_end=trace,
                        accounting=accounting(before, previous, 0), new_swapout_pages=0)
        self.save()

    def finish(self):
        after = self.client.snapshot()
        accounting(self.last_metrics or after, after, 0)
        self.report["final_metrics"] = after
        self.report["final_accounting"] = accounting(self.initial_metrics or after, after, len(self.report["results"]))
        self.check_guard()
        self.report["complete"] = True
        if getattr(self.args, "stage", None) == "long":
            self.report["pending_external_guard_final"] = True

    def gate(self, label, rows):
        passed = bool(rows) and all(row["validation"]["passed"] for row in rows)
        self.report["gates"].append({"label": label, "passed": passed})
        self.save()
        return passed

    def ledger(self, target, *parts, content_seed=None):
        prompt, expected, count = BASE.long_prompt(
            self.client, target, nonce(self.args, target, *parts),
            self.args.seed + target if content_seed is None else content_seed,
        )
        if count is None:
            raise ValueError("Tokenization is required for controlled TP4 context measurements")
        if count < target * 0.9:
            raise ValueError(f"Tokenized prompt {count} falls below 90% of target {target}")
        return prompt, expected

    def warm(self, concurrency, target, label):
        cases = []
        for index in range(concurrency):
            prompt, _ = self.ledger(target, "warmup", label, concurrency, index)
            cases.append({"body": body_for(self.client, prompt, 32, fixed=True), "prompt_target": target})
        if label == "long":
            label = f"long-{target}"
        return self.gate(f"warmup-{label}-c{concurrency}", self.batch(f"warmup-{label}-c{concurrency}", cases, warmup=True))

    def tool_requests(self, repeat):
        rows = []
        for mode in ("forced", "auto"):
            body = body_for(self.client, "Call record_visit with city \uc11c\uc6b8, days 3, and confirmed true.", self.args.quality_output_tokens)
            body["tools"] = [{"type": "function", "function": {
                "name": "record_visit", "description": "Record a requested city visit.",
                "parameters": {"type": "object", "properties": {
                    "city": {"type": "string"}, "days": {"type": "integer"},
                    "confirmed": {"type": "boolean"}},
                    "required": ["city", "days", "confirmed"], "additionalProperties": False},
            }}]
            body["tool_choice"] = (
                {"type": "function", "function": {"name": "record_visit"}} if mode == "forced" else "auto"
            )
            label = "accuracy-tools" if mode == "forced" else "accuracy-tools-auto"
            expected = {
                "kind": "tool", "name": "record_visit", "value": {"city": "\uc11c\uc6b8", "days": 3, "confirmed": True},
            }
            if mode == "forced":
                expected["finish_reasons"] = ["stop", "tool_calls"]
            rows += self.batch(f"{label}-r{repeat}", [{"body": body, "expectation": expected}])
        return rows

    def tools(self):
        rows = []
        for repeat in range(self.args.repeats):
            rows += self.tool_requests(repeat)
        return self.gate("tools", rows)

    def unicode(self):
        prompt = "\uc778\uacf5\uc9c0\ub2a5\uc758 \uc5ed\uc0ac\ub97c 1950\ub144\ub300\ubd80\ud130 \ud604\uc7ac\uae4c\uc9c0 \uc2dc\ub300\ubcc4\ub85c \ub098\ub204\uc5b4 \ud55c\uad6d\uc5b4\ub85c \uc790\uc138\ud788 \uc124\uba85\ud574 \uc8fc\uc138\uc694."
        rows = []
        for repeat in range(self.args.repeats):
            body = body_for(
                self.client, f"Trial: {nonce(self.args, 'unicode-korean', repeat)}\n{prompt}",
                self.args.quality_output_tokens,
            )
            rows += self.batch(f"unicode-korean-r{repeat}", [{
                "body": body,
                "expectation": {"kind": "korean_unicode", "min_hangul_syllables": 256},
            }])
        return self.gate("unicode", rows)

    def accuracy(self):
        cases = [
            ("arithmetic", "Return only JSON: {\"answer\": value of 137 multiplied by 29}.", {"kind": "json", "value": {"answer": 3973}}),
            ("sum-squares", "Return only JSON with key answer and the sum of the squares of integers 1 through 100 inclusive.", {"kind": "json", "value": {"answer": 338350}}),
            ("intervals", "Merge overlapping closed intervals [[8,10],[1,3],[2,6],[15,18],[10,12]]. Return only JSON with key intervals and the merged intervals sorted by start.", {"kind": "json", "value": {"intervals": [[1, 6], [8, 12], [15, 18]]}}),
            ("korean", "\ub2e4\uc74c \ud55c\uad6d\uc5b4 \ubb38\uc7a5\uc744 \uc815\ud655\ud788 \ubcf5\uc0ac\ud558\uc5ec text \ud0a4\uc758 JSON\uc73c\ub85c\ub9cc \uc751\ub2f5\ud558\uc138\uc694: \uc548\ub155\ud558\uc138\uc694. \uc624\ub298\uc740 \ub0a0\uc528\uac00 \ub9d1\uc2b5\ub2c8\ub2e4. \uc11c\uc6b8\uc5d0\uc11c \ubd80\uc0b0\uae4c\uc9c0 \uae30\ucc28\ub85c \uc5ec\ud589\ud569\ub2c8\ub2e4.", {"kind": "json", "value": {"text": "\uc548\ub155\ud558\uc138\uc694. \uc624\ub298\uc740 \ub0a0\uc528\uac00 \ub9d1\uc2b5\ub2c8\ub2e4. \uc11c\uc6b8\uc5d0\uc11c \ubd80\uc0b0\uae4c\uc9c0 \uae30\ucc28\ub85c \uc5ec\ud589\ud569\ub2c8\ub2e4."}}),
            ("korean-prose", "Explain how a prefix cache makes repeated conversations faster, entirely in Korean. Write four complete sentences containing at least 150 Korean syllables in total. Return prose only, without JSON or a code block.", {"kind": "korean_prose", "min_hangul_syllables": 64}),
        ]
        all_rows = []
        for repeat in range(self.args.repeats):
            for name, prompt, expected in cases:
                body = body_for(self.client, f"Trial: {nonce(self.args, 'accuracy', repeat, name)}\n{prompt}", self.args.quality_output_tokens)
                all_rows += self.batch(f"accuracy-{name}-r{repeat}", [{"body": body, "expectation": expected}])
            all_rows += self.tool_requests(repeat)
            if getattr(self.args, "code_host", None):
                for name, case in CODE_CASES.items():
                    prompt = (
                        f"Trial: {nonce(self.args, 'accuracy-code', repeat, name)}\n{case['prompt']} "
                        "Return only Python function definitions without imports, decorators, type annotations, tests, or commentary. "
                        "Use Python builtins only."
                    )
                    body = body_for(self.client, prompt, self.args.quality_output_tokens)
                    all_rows += self.batch(f"accuracy-code-{name}-r{repeat}", [{"body": body, "code_function": name}])
        return self.gate("accuracy", all_rows)

    def cache(self, target, concurrent=True, label="cache"):
        if not self.warm(1, target, label):
            return False
        prompt, expected = self.ledger(target, label, target)
        original, suffix, appended = cache_bodies(self.client, prompt, expected, self.args.quality_output_tokens)
        rows = []
        for repeat in range(3 if label == "long" else max(3, self.args.repeats)):
            rows += self.batch(f"{label}-{target}-exact-r{repeat}", [{
                "body": original, "expectation": {"kind": "json", "value": expected},
                "cache_mode": "cold" if repeat == 0 else "warm", "prompt_target": target,
            }])
        for name, body, value in (
            ("suffix", suffix, {"vault_b": expected["vault_b"]}),
            ("appended", appended, {"vault_c": expected["vault_c"]}),
        ):
            rows += self.batch(f"{label}-{target}-{name}", [{
                "body": body, "expectation": {"kind": "json", "value": value}, "cache_mode": "warm", "prompt_target": target,
            }])
        if concurrent:
            concurrency = max(self.args.concurrency)
            if not self.warm(concurrency, target, f"{label}-shared"):
                return False
            shared = []
            for index in range(concurrency):
                body = body_for(self.client, prompt + f"\nBatch item {index}: return the same three vault codes as JSON.", self.args.quality_output_tokens)
                shared.append({"body": body, "expectation": {"kind": "json", "value": expected}, "cache_mode": "warm", "prompt_target": target})
            rows += self.batch(f"{label}-{target}-shared-c{concurrency}", shared)
            rows += self.batch(f"{label}-{target}-after-pressure", [{
                "body": original, "expectation": {"kind": "json", "value": expected}, "cache_mode": "warm", "prompt_target": target,
            }])
        return self.gate(f"{label}-{target}", rows)

    def mixed_cache(self):
        targets = (self.args.cache_tokens, self.args.cache_tokens + 2304)
        self.report["mixed_cache_scope"] = {
            "concurrency": [4, 8], "cold_target_prompt_tokens": list(targets),
            "seed_requests": 3, "warm_fraction": 0.5,
            "shape_warmup_requests": 12, "measured_requests": 15,
            "notes": "One mixed batch per concurrency, independent of --repeats; targets are sized by /tokenize, not exact boundary offsets.",
        }
        self.save()
        for concurrency in (4, 8):
            cases = []
            for index in range(concurrency):
                prompt, _ = self.ledger(targets[index % 2], "mixed-cache-warmup", concurrency, index)
                cases.append({"body": body_for(self.client, prompt, 32, fixed=True)})
            rows = self.batch(f"mixed-cache-warmup-c{concurrency}", cases, warmup=True)
            if not self.gate(f"mixed-cache-warmup-c{concurrency}", rows):
                return False

        seed = int(nonce(self.args, "mixed-cache-values", "seed")[:16], 16)
        prompt, expected = self.ledger(targets[0], "mixed-cache-seed", content_seed=seed)
        original = body_for(self.client, prompt, self.args.quality_output_tokens)
        rows = []
        for repeat in range(3):
            rows += self.batch(f"mixed-cache-seed-r{repeat}", [{
                "body": original, "expectation": {"kind": "json", "value": expected},
            }])
        if not self.gate("mixed-cache-seed", rows):
            return False

        prefix = prompt.rsplit("Return only a JSON object", 1)[0]
        for concurrency in (4, 8):
            cases = []
            for index in range(concurrency // 2):
                vault = list(expected)[index % len(expected)]
                suffix = (
                    f"Batch item {concurrency}-{index}: return only a JSON object with "
                    f"the exact access code for {vault}, and no other keys. "
                    f"Use exactly the key {vault}, with its original access code as the string value."
                )
                cases.append({
                    "body": body_for(self.client, prefix + suffix, self.args.quality_output_tokens),
                    "expectation": {"kind": "json", "value": {vault: expected[vault]}},
                    "cache_mode": "warm",
                })
                cold_seed = int(nonce(self.args, "mixed-cache-values", concurrency, index)[:16], 16)
                cold, cold_expected = self.ledger(
                    targets[index % 2], "mixed-cache-cold", concurrency, index,
                    content_seed=cold_seed,
                )
                cases.append({
                    "body": body_for(self.client, cold, self.args.quality_output_tokens),
                    "expectation": {"kind": "json", "value": cold_expected},
                    "cache_mode": "cold",
                })
            mixed = self.batch(f"mixed-cache-c{concurrency}", cases)
            rows += mixed
            if not self.gate(f"mixed-cache-c{concurrency}", mixed):
                return False
        return self.gate("mixed-cache", rows)

    def short(self):
        all_rows = []
        for concurrency in self.args.concurrency:
            warm_cases = [{"body": body_for(
                self.client, f"Trial: {nonce(self.args, 'tiny-warmup', concurrency, index)}\n{BASE.PROMPTS['dns']}",
                32, fixed=True,
            )} for index in range(concurrency)]
            if not self.gate(f"warmup-tiny-c{concurrency}", self.batch(f"warmup-tiny-c{concurrency}", warm_cases, warmup=True)):
                return False
            for repeat in range(self.args.repeats):
                for name, prompt in BASE.PROMPTS.items():
                    tiny_cases = [{"body": body_for(
                        self.client,
                        f"Trial: {nonce(self.args, 'tiny', name, concurrency, repeat, index)}\n" + prompt,
                        self.args.speed_output_tokens, fixed=True,
                    )} for index in range(concurrency)]
                    all_rows += self.batch(f"throughput-tiny-{name}-c{concurrency}-r{repeat}", tiny_cases)
            if not self.warm(concurrency, self.args.speed_prompt_tokens, "throughput"):
                return False
            for repeat in range(self.args.repeats):
                cases = []
                for index in range(concurrency):
                    prompt, _ = self.ledger(self.args.speed_prompt_tokens, "throughput", concurrency, repeat, index)
                    prefix = prompt.rsplit("Return only a JSON object", 1)[0]
                    prompt = prefix + BASE.PROMPTS[list(BASE.PROMPTS)[index % len(BASE.PROMPTS)]]
                    cases.append({"body": body_for(self.client, prompt, self.args.speed_output_tokens, fixed=True), "cache_mode": "cold"})
                all_rows += self.batch(f"throughput-c{concurrency}-r{repeat}-cold", cases)
                for case in cases:
                    case["cache_mode"] = "warm"
                all_rows += self.batch(f"throughput-c{concurrency}-r{repeat}-warm", cases)
        return self.gate("throughput", all_rows)

    def run(self):
        self.save()
        self.check_guard()
        self.client.get("/health")
        self.report["server_models"] = json.loads(self.client.get("/v1/models"))
        self.save()
        stage = self.args.stage
        if stage == "tools":
            return self.tools()
        if stage == "unicode":
            return self.unicode()
        if stage == "long":
            previous = None
            for target in self.args.long_targets:
                if previous is not None:
                    self.settle(previous, target)
                if not self.cache(target, concurrent=False, label="long"):
                    return False
                previous = target
            return True
        if stage in ("accuracy", "all") and not self.accuracy():
            return False
        if stage in ("cache", "all") and not self.cache(self.args.cache_tokens):
            return False
        if stage in ("mixed-cache", "all") and not self.mixed_cache():
            return False
        if stage in ("short", "all") and not self.short():
            return False
        return True


def positive_csv(value):
    try:
        result = [int(part) for part in value.split(",")]
        if not result or any(part <= 0 for part in result):
            raise ValueError()
        return result
    except ValueError as error:
        raise argparse.ArgumentTypeError("Expected comma-separated positive integers") from error


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", default="http://spark-01.local:8888")
    parser.add_argument("--model", required=True)
    parser.add_argument("--arm", required=True, help="Report label, e.g. glm53-flash-nvfp4-vllm or reference")
    parser.add_argument("--campaign-id", required=True, help="Use the same ID across arms, a fresh one when repeating the campaign")
    parser.add_argument("--stage", choices=("short", "accuracy", "tools", "unicode", "cache", "mixed-cache", "long", "all"), default="short",
                        help="long is an explicit guarded C1 ramp; all excludes long")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, help="JSON containing observed image, checkpoint/revision, TP, cache capacity, and server arguments")
    parser.add_argument("--guard-log", type=Path, help="Active snapshot.py JSONL watch log; required for long")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--repeats", type=int, default=1)
    parser.add_argument("--concurrency", type=positive_csv, default=[1])
    parser.add_argument("--reasoning-effort", choices=("low", "high", "max"), default="low")
    parser.add_argument("--temperature", type=float, default=0)
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--context-window", type=int, default=1048576)
    parser.add_argument("--speed-prompt-tokens", type=int, default=16384)
    parser.add_argument("--speed-output-tokens", type=int, default=256)
    parser.add_argument("--quality-output-tokens", type=int, default=2048)
    parser.add_argument("--cache-tokens", type=int, default=16384)
    parser.add_argument("--min-cache-ratio", type=float, default=0.8)
    parser.add_argument("--long-targets", type=positive_csv, default=[16384, 131072, 262144, 524288, 1000000])
    parser.add_argument("--code-host", help="Opt in to executable coding tests in isolated Podman containers on this SSH host")
    parser.add_argument("--code-image", help="Existing code-test image pinned by sha256:ID or image@sha256:digest")
    parser.add_argument("--ssh-identity", help="Optional SSH private-key path for the isolated code runner; omitted from report settings")
    parser.add_argument("--code-timeout", type=float, default=30, help="Code-container timeout in seconds, excluding bounded cleanup")
    args = parser.parse_args(argv)
    if args.repeats < 1 or not math.isfinite(args.timeout) or args.timeout <= 0 or not math.isfinite(args.temperature) or args.temperature < 0:
        parser.error("repeats and timeout must be positive; temperature must be nonnegative")
    if args.stage == "long":
        if args.manifest is None or args.guard_log is None:
            parser.error("long requires a fresh --manifest and an active --guard-log from snapshot.py")
        if args.concurrency != [1] or args.repeats != 1:
            parser.error("long requires --concurrency 1 --repeats 1; every size has one cold retrieval and two exact repeats")
    if bool(args.code_host) != bool(args.code_image):
        parser.error("code-host and code-image must be supplied together")
    if args.code_image and not PINNED_IMAGE.fullmatch(args.code_image):
        parser.error("code-image must be pinned by sha256:ID or image@sha256:digest")
    if args.code_host and args.code_host.startswith("-"):
        parser.error("code-host must be an SSH host name")
    if not math.isfinite(args.code_timeout) or args.code_timeout <= 0 or args.code_timeout > 60:
        parser.error("code-timeout must be in (0, 60] seconds")
    if not 0 < args.min_cache_ratio <= 1:
        parser.error("min-cache-ratio must be in (0, 1]")
    if min(args.speed_output_tokens, args.quality_output_tokens) < 1:
        parser.error("output-token budgets must be positive")
    if args.long_targets != sorted(set(args.long_targets)):
        parser.error("long-targets must be unique and increasing")
    for target in [args.cache_tokens, args.speed_prompt_tokens, *args.long_targets]:
        if target < 4096 or target + max(args.speed_output_tokens, args.quality_output_tokens) + 256 > args.context_window:
            parser.error("prompt targets must be >=4096 and reserve output plus 256 chat/suffix tokens")
    if args.stage in ("mixed-cache", "all") and args.cache_tokens + 2304 + args.quality_output_tokens + 256 > args.context_window:
        parser.error("mixed-cache requires room for cache-tokens plus 2304, output tokens, and suffix margin")
    if args.output.exists():
        parser.error("output already exists; choose a new output file to preserve previous evidence")
    return args


def main(argv=None):
    args = parse_args(argv)
    campaign = None
    try:
        campaign = Campaign(args, Client(args))
        passed = campaign.run()
        if passed:
            campaign.finish()
        campaign.report["status"] = "passed" if passed else "failed"
    except (Exception, KeyboardInterrupt) as error:
        if campaign is None:
            atomic_json(args.output, {"status": "blocked", "complete": False, "fatal_error": str(error), "finished_at": utc_now()})
            return 1
        campaign.report.update(status="interrupted" if isinstance(error, KeyboardInterrupt) else "failed", complete=False,
                               fatal_error=f"{type(error).__name__}: {error}")
        passed = False
    campaign.report["finished_at"] = utc_now()
    campaign.save()
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
