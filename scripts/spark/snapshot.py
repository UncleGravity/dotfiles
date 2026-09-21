#!/usr/bin/env python3
"""Capture the deployed TP4 configuration and host diagnostics without changing it."""

import argparse
import concurrent.futures
import datetime
import hashlib
import json
import math
import os
import re
import shlex
import signal
import subprocess
import time
import urllib.request
from pathlib import Path


REDACTED = "[REDACTED]"


def sensitive_key(name):
    name = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)
    normalized = re.sub(r"[^A-Z0-9]+", "_", name.upper()).strip("_")
    parts = normalized.split("_")
    if set(parts) & {"SECRET", "SECRETS", "PASSWORD", "PASSWORDS", "CREDENTIAL", "CREDENTIALS"}:
        return True
    if "API_KEY" in normalized:
        return True
    if re.search(r"(?:^|_)(?:MAX|MIN|NUM)_TOKENS?$|(?:^|_)TOKENS?_(?:COUNT|LENGTH|LIMIT|BUDGET|SIZE)$", normalized):
        return False
    return "TOKEN" in parts


def redact(value):
    if isinstance(value, dict):
        return {key: REDACTED if sensitive_key(key) else redact(item) for key, item in value.items()}
    if isinstance(value, list):
        result = []
        redact_next = False
        for item in value:
            result.append(REDACTED if redact_next else redact(item))
            redact_next = isinstance(item, str) and item.startswith("--") and "=" not in item and sensitive_key(item)
        return result
    if isinstance(value, str) and "=" in value:
        key, item = value.split("=", 1)
        if sensitive_key(key):
            return f"{key}={REDACTED}"
    return value


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def ssh(args, node, command):
    invocation = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5"]
    if args.identity:
        invocation += ["-o", "IdentityAgent=none", "-o", "IdentitiesOnly=yes", "-i", args.identity]
    invocation += [node, shlex.join(command)]
    try:
        result = subprocess.run(invocation, capture_output=True, text=True, timeout=45)
        return {"exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr}
    except subprocess.TimeoutExpired:
        return {"exit_code": 124, "stdout": "", "stderr": "SSH command timed out after 45 seconds"}
    except OSError as error:
        return {"exit_code": 127, "stdout": "", "stderr": str(error)}


def fetch(url):
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            return {"status": response.status, "body": response.read().decode()}
    except (OSError, ValueError) as error:
        return {"error": str(error)}


def parse_numbers(output, separator=None):
    values = {}
    for line in output.splitlines():
        fields = line.split(separator, 1) if separator else line.split(None, 1)
        if len(fields) != 2:
            continue
        tokens = fields[1].strip().split()
        if not tokens:
            continue
        value = tokens[0]
        if value.isdigit():
            values[fields[0]] = int(value)
    return values


def snapshot_node(args, node, full):
    unit = f"infer-node-{args.instance}.service"
    result = {"node": node, "sampled_at": utc_now(), "errors": []}
    commands = {
        "meminfo": ["cat", "/proc/meminfo"],
        "vmstat": ["cat", "/proc/vmstat"],
        "service": ["systemctl", "show", unit, "--property=ActiveState,SubState,Result,MainPID,ControlGroup,MemoryCurrent,MemoryPeak,MemorySwapCurrent,MemorySwapPeak,ActiveEnterTimestamp,InvocationID"],
        "gpu": ["nvidia-smi", "--query-gpu=uuid,driver_version,pstate,clocks.sm,utilization.gpu,power.draw,temperature.gpu", "--format=csv,noheader,nounits"],
    }
    if getattr(args, "max_new_swapout_pages", None) is not None or getattr(args, "fail_on_new_oom", False):
        commands["boot_id"] = ["cat", "/proc/sys/kernel/random/boot_id"]
    if full:
        commands["container"] = ["sudo", "-n", "podman", "inspect", f"infer-{args.instance}"]
        commands["kernel"] = ["sudo", "-n", "journalctl", "-k", "--since", args.since, "--no-pager", "-o", "short-iso", "--grep=NVRM|Out of memory|oom-kill|Killed process|SMMU|Xid"]
        commands["sysctls"] = ["sysctl", "vm.swappiness", "vm.min_free_kbytes"]
    for name, command in commands.items():
        response = ssh(args, node, command)
        if name == "kernel" and response["exit_code"] == 1 and response["stdout"].strip() == "-- No entries --" and not response["stderr"]:
            result[name] = ""
            continue
        if response["exit_code"]:
            error = {"command": name, **response}
            if name == "container":
                error.pop("stdout", None)
            result["errors"].append(error)
            continue
        raw = response["stdout"]
        if name == "meminfo":
            result["memory_kib"] = parse_numbers(raw, ":")
        elif name == "vmstat":
            counters = parse_numbers(raw)
            result["vmstat"] = {key: counters[key] for key in ("pswpin", "pswpout", "pgmajfault", "oom_kill", "compact_stall", "compact_fail") if key in counters}
        elif name == "service":
            result[name] = dict(line.split("=", 1) for line in raw.splitlines() if "=" in line)
        elif name == "container":
            try:
                container = json.loads(raw)[0]
                config = container["Config"]
                allowed = ("INFER_", "NCCL_", "GLOO_", "VLLM_", "B12X_", "TORCH_", "FLASHINFER_", "CUTE_", "PYTORCH_")
                environment = dict(item.split("=", 1) for item in config.get("Env", []) if "=" in item)
                result[name] = redact({
                    "id": container["Id"], "image_id": container["Image"],
                    "image_reference": container["ImageName"], "args": config.get("Cmd", []),
                    "entrypoint": config.get("Entrypoint"),
                    "environment": {key: value for key, value in environment.items() if key.startswith(allowed)},
                    "mounts": container.get("Mounts", []),
                    "labels": {key: value for key, value in config.get("Labels", {}).items() if key.startswith(("io.angel.infer.", "local.glm53.", "org.opencontainers.image."))},
                    "state": container.get("State"),
                })
            except (ValueError, TypeError, KeyError, IndexError, AttributeError) as error:
                result["errors"].append({"command": name, "error": f"Invalid container response: {type(error).__name__}"})
        elif name == "boot_id":
            result[name] = raw.strip()
        else:
            result[name] = raw
    group = result.get("service", {}).get("ControlGroup")
    if group:
        response = ssh(args, node, ["cat", f"/sys/fs/cgroup{group}/memory.events"])
        if response["exit_code"] == 0:
            result["memory_events"] = parse_numbers(response["stdout"])
        else:
            result["errors"].append({"command": "memory_events", **response})
    return result


def validate_tp4(nodes):
    errors = []
    containers = [node.get("container", {}) for node in nodes]
    if len(nodes) != 4 or any(not isinstance(container, dict) or not container for container in containers):
        return ["All four running containers must be captured"]
    if any(not isinstance(container.get("environment"), dict) or not isinstance(container.get("args"), list) or not container.get("image_id") for container in containers):
        return ["Every container must include environment, arguments, and image ID"]
    if {container["environment"].get("INFER_WORLD_SIZE") for container in containers} != {"4"}:
        errors.append("Every rank must report INFER_WORLD_SIZE=4")
    if {container["environment"].get("INFER_RANK") for container in containers} != {"0", "1", "2", "3"}:
        errors.append("Expected exactly ranks 0, 1, 2, 3")
    if len({container["image_id"] for container in containers}) != 1:
        errors.append("Container image IDs differ across ranks")
    if len({json.dumps(container["args"]) for container in containers}) != 1:
        errors.append("Container arguments differ across ranks")
    for node, container in zip(nodes, containers):
        state = container.get("state")
        if not isinstance(state, dict) or not state.get("Running"):
            errors.append(f"{node['node']}: container is not running")
        command = container["args"]
        context_index = command.index("--max-model-len") + 1 if "--max-model-len" in command else len(command)
        if context_index >= len(command) or command[context_index] != "1048576":
            errors.append(f"{node['node']}: expected 1M context")
    return errors


def capture(args, full):
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        nodes = list(pool.map(lambda node: snapshot_node(args, node, full), args.nodes))
    report = {"schema_version": 1, "sampled_at": utc_now(), "instance": args.instance, "nodes": nodes, "collection_errors": []}
    report["api_health"] = fetch(args.endpoint.rstrip("/") + "/health")
    report["api_metrics"] = fetch(args.endpoint.rstrip("/") + "/metrics")
    if full:
        plan = ssh(args, args.nodes[0], ["infer", "plan", args.instance, "--json"])
        if plan["exit_code"]:
            report["plan"] = {key: value for key, value in plan.items() if key != "stdout"}
            report["collection_errors"].append("infer plan failed")
        else:
            try:
                report["plan"] = redact(json.loads(plan["stdout"]))
                if not isinstance(report["plan"], dict):
                    raise ValueError("Expected plan object")
            except (ValueError, TypeError) as error:
                report["plan"] = {"error": f"Invalid plan response: {type(error).__name__}"}
                report["collection_errors"].append("infer plan returned invalid JSON or structure")
        report["tp4_validation_errors"] = validate_tp4(nodes)
        if not report["tp4_validation_errors"]:
            report["tensor_parallel_size"] = 4
            report["context_window"] = 1048576
    return report


def collection_errors(report):
    errors = list(report.get("tp4_validation_errors", [])) + list(report.get("collection_errors", []))
    errors.extend(error for node in report["nodes"] for error in node["errors"])
    for name in ("api_health", "api_metrics"):
        if report[name].get("status") != 200:
            errors.append(f"{name} check failed")
    return errors


class ResourceGuards:
    def __init__(self, args):
        self.nodes = set(args.nodes)
        self.minimum = args.min_available_gib
        self.swap_limit = args.max_new_swapout_pages
        self.oom = args.fail_on_new_oom
        self.baseline = {}
        self.previous = {}
        self.identities = {}
        self.failed = False
        self.policy = {
            "min_available_gib": self.minimum,
            "max_new_swapout_pages": self.swap_limit,
            "fail_on_new_oom": self.oom,
            "collector_source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        }

    def evaluate(self, report, phase):
        failures = []
        observations = []

        def fail(node, counter, reason, **values):
            failures.append({"node": node, "counter": counter, "reason": reason, **values})

        rows = report.get("nodes", [])
        names = [row.get("node") for row in rows]
        for name in sorted(self.nodes):
            if names.count(name) != 1:
                fail(name, "node", "missing or duplicate node")
        for name in names:
            if name not in self.nodes:
                fail(name, "node", "unexpected node")
        for row in rows:
            name = row.get("node")
            if name not in self.nodes or names.count(name) != 1:
                continue
            if self.swap_limit is not None or self.oom:
                identity = {"boot_id": row.get("boot_id")}
                if self.oom:
                    service = row.get("service")
                    service = service if isinstance(service, dict) else {}
                    identity.update({key: service.get(key) for key in ("InvocationID", "ControlGroup")})
                    if service.get("ActiveState") != "active" or service.get("SubState") != "running":
                        fail(name, "service", "service is not active/running")
                if any(not isinstance(value, str) or not value.strip() for value in identity.values()):
                    fail(name, "identity", "missing required counter identity", observed=identity)
                elif name not in self.identities:
                    self.identities[name] = identity
                elif identity != self.identities[name]:
                    fail(name, "identity", "counter identity changed", baseline=self.identities[name], observed=identity)

            counters = []
            if self.minimum is not None:
                counters.append(("memory_kib", "MemAvailable", None))
            if self.swap_limit is not None:
                counters.append(("vmstat", "pswpout", self.swap_limit))
            if self.oom:
                counters += [("vmstat", "oom_kill", 0), ("memory_events", "oom", 0), ("memory_events", "oom_kill", 0)]
                events = row.get("memory_events")
                if (isinstance(events, dict) and "oom_group_kill" in events) or (name, "memory_events.oom_group_kill") in self.baseline:
                    counters.append(("memory_events", "oom_group_kill", 0))
            for section, counter, limit in counters:
                label = f"{section}.{counter}"
                values = row.get(section)
                value = values.get(counter) if isinstance(values, dict) else None
                if type(value) is not int or value < 0:
                    fail(name, label, "missing or invalid required counter", observed=value)
                    continue
                key = (name, label)
                observation = {"node": name, "counter": label, "observed": value}
                if section == "memory_kib":
                    observation.update({"minimum_gib": self.minimum, "unit": "KiB"})
                    if value / 1048576 < self.minimum:
                        fail(name, label, "below minimum available memory", **{key: item for key, item in observation.items() if key not in ("node", "counter")})
                else:
                    if key not in self.baseline and phase != "preflight":
                        fail(name, label, "counter missing from first sample", observed=value)
                        continue
                    baseline = self.baseline.setdefault(key, value)
                    previous = self.previous.get(key, value)
                    observation.update({"baseline": baseline, "previous": previous, "delta": value - baseline, "limit": limit,
                                        "unit": "pages" if counter == "pswpout" else "events"})
                    if value < previous:
                        fail(name, label, "counter decreased or reset", baseline=baseline, previous=previous, observed=value)
                    elif value - baseline > limit:
                        fail(name, label, "cumulative increase exceeded limit", **{key: item for key, item in observation.items() if key not in ("node", "counter")})
                    self.previous[key] = value
                observations.append(observation)
        self.failed |= bool(failures)
        report.update({"guard_policy": self.policy, "guard_phase": phase, "guard_observations": observations,
                       "guard_failures": failures, "guard_failed": self.failed})
        return failures


def record_sample(args, output, guards=None, phase=None):
    row = capture(args, full=False)
    guard_failures = guards.evaluate(row, phase) if guards is not None else []
    output.write(json.dumps(row) + "\n")
    output.flush()
    errors = collection_errors(row)
    memory = {}
    for node in row["nodes"]:
        values = node.get("memory_kib")
        available = values.get("MemAvailable") if isinstance(values, dict) else None
        memory[node["node"]] = round(available / 1048576, 2) if type(available) is int and available >= 0 else None
    progress = {"sampled_at": row["sampled_at"], "memory_available_gib": memory, "errors": errors}
    if guards is not None:
        progress.update({"guard_failures": guard_failures, "guard_failed": guards.failed, "guard_phase": phase})
    print(json.dumps(progress), flush=True)
    return bool(errors)


def stop_child(child):
    if child.poll() is None:
        try:
            child.terminate()
        except ProcessLookupError:
            pass
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                child.kill()
            except ProcessLookupError:
                pass
            child.wait(timeout=5)


def process_group_exists(pgid):
    """Return None when permissions prevent confirming process-group state."""
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return None
    return True


def stop_child_group(child):
    pgid = child.pid
    if type(pgid) is not int or pgid <= 1 or pgid == os.getpgrp():
        raise ValueError("Refusing to signal an invalid or parent process group")
    failures = []

    def send(sig):
        try:
            os.killpg(pgid, sig)
        except ProcessLookupError:
            pass
        except PermissionError:
            failures.append(f"Permission denied sending {sig.name} to process group")

    def await_group_exit():
        deadline = time.monotonic() + 5
        while True:
            exists = process_group_exists(pgid)
            if exists is None:
                failures.append("Permission denied checking process-group exit")
                return False
            if not exists:
                return True
            child.poll()
            if time.monotonic() >= deadline:
                return False
            time.sleep(0.05)

    # start_new_session makes the owned child's PID its isolated process-group ID.
    send(signal.SIGTERM)
    confirmed = await_group_exit()
    if not confirmed:
        send(signal.SIGKILL)
        confirmed = await_group_exit()
    if not confirmed:
        failures.append("Could not confirm process-group exit after the bounded SIGKILL attempt")
    try:
        child.wait(timeout=5)
    except subprocess.TimeoutExpired:
        failures.append("Owned child wait timed out after five seconds")
    except PermissionError:
        failures.append("Permission denied waiting for owned child")
    return {"pgid": pgid, "group_exit_confirmed": confirmed, "problems": failures} if failures else None


def watch_command(args):
    guards = ResourceGuards(args) if guards_enabled(args) else None
    with args.output.open("a") as output:
        def sample(phase):
            return record_sample(args, output, guards, phase) if guards is not None else record_sample(args, output)

        failed = sample("preflight")
        if guards is not None and guards.failed:
            return 1
        if guards is not None:
            child = subprocess.Popen(args.watch_command, shell=False, start_new_session=True)
        else:
            child = subprocess.Popen(args.watch_command, shell=False)
        cleanup = stop_child_group if guards is not None else stop_child
        cleanup_attempted = False

        def clean():
            nonlocal failed, cleanup_attempted
            cleanup_attempted = True
            failure = cleanup(child)
            if failure:
                failed = True
                event = {"schema_version": 1, "event": "cleanup_failure", "sampled_at": utc_now(),
                         "nodes": [], "cleanup_failure": failure}
                output.write(json.dumps(event) + "\n")
                output.flush()
                print(json.dumps(event), flush=True)

        try:
            while child.poll() is None:
                failed |= sample("running")
                if guards is not None and guards.failed:
                    clean()
                    break
                try:
                    child.wait(timeout=args.interval)
                except subprocess.TimeoutExpired:
                    pass
            if guards is not None and not cleanup_attempted:
                clean()
            failed |= sample("final")
            if guards is not None and guards.failed:
                return 1
            if child.returncode:
                return child.returncode if child.returncode > 0 else 128 - child.returncode
            return int(failed)
        except KeyboardInterrupt:
            return 130
        finally:
            if not cleanup_attempted:
                clean()


def guards_enabled(args):
    return (getattr(args, "min_available_gib", None) is not None
            or getattr(args, "max_new_swapout_pages", None) is not None
            or getattr(args, "fail_on_new_oom", False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--instance", default="glm53-flash-nvfp4-vllm")
    parser.add_argument("--nodes", nargs=4, default=[f"spark-{index:02d}.local" for index in range(1, 5)])
    parser.add_argument("--endpoint", default="http://spark-01.local:8888")
    parser.add_argument("--identity", help="Optional existing SSH private-key path; never copied into the report")
    parser.add_argument("--since", default="today", help="journalctl --since expression for kernel diagnostics")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--watch-seconds", type=float, default=0)
    parser.add_argument("--interval", type=float, default=15)
    parser.add_argument("--min-available-gib", type=float, help="Stop the owned command below this per-node MemAvailable floor; disabled by default")
    parser.add_argument("--max-new-swapout-pages", type=int, help="Stop above this per-node cumulative pswpout increase from the first sample, in pages, not bytes; disabled by default")
    parser.add_argument("--fail-on-new-oom", action="store_true", help="Stop on new host or service-cgroup OOM events; disabled by default")
    parser.add_argument("--watch-command", nargs=argparse.REMAINDER, help="Run an argv command without a shell and monitor until it exits; place this option last")
    args = parser.parse_args()
    if not math.isfinite(args.watch_seconds) or not math.isfinite(args.interval) or args.watch_seconds < 0 or args.interval < 1:
        parser.error("watch-seconds must be nonnegative and interval must be at least one second")
    if args.min_available_gib is not None and (not math.isfinite(args.min_available_gib) or args.min_available_gib <= 0):
        parser.error("min-available-gib must be finite and positive")
    if args.max_new_swapout_pages is not None and args.max_new_swapout_pages < 0:
        parser.error("max-new-swapout-pages must be a nonnegative integer")
    if guards_enabled(args) and args.watch_command is None:
        parser.error("resource guards require watch-command")
    if args.watch_command is not None:
        if not args.watch_command:
            parser.error("watch-command requires a command")
        if args.watch_seconds:
            parser.error("watch-command cannot be combined with positive watch-seconds")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.watch_command is not None:
        return watch_command(args)
    if args.watch_seconds:
        deadline = time.monotonic() + args.watch_seconds
        failed = False
        with args.output.open("a") as output:
            while time.monotonic() < deadline:
                failed |= record_sample(args, output)
                time.sleep(min(args.interval, max(0, deadline - time.monotonic())))
        return int(failed)
    report = capture(args, full=True)
    temporary = args.output.with_suffix(args.output.suffix + ".tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n")
    temporary.replace(args.output)
    errors = collection_errors(report)
    print(json.dumps({"output": str(args.output), "errors": errors}, indent=2))
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
