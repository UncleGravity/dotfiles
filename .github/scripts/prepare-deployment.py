#!/usr/bin/env python3
"""Prepare selected machines from a successful CI release snapshot."""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory


class DeploymentError(ValueError):
    """The selected release cannot be deployed."""


def require(condition, message):
    if not condition:
        raise DeploymentError(message)


def gh(*arguments):
    try:
        return subprocess.run(
            ["gh", *arguments], check=True, capture_output=True, text=True
        ).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        detail = (getattr(error, "stderr", None) or str(error)).strip()
        summary = detail.splitlines()[0] if detail else "no error details"
        raise DeploymentError(f"GitHub command failed: {summary}") from error


def api(endpoint):
    try:
        return json.loads(gh("api", endpoint))
    except json.JSONDecodeError as error:
        raise DeploymentError("GitHub returned invalid JSON") from error


def validate_source(run, repository, run_id, attempt):
    require(
        run.get("path") == ".github/workflows/ci.yml"
        and run.get("status") == "completed"
        and run.get("conclusion") == "success",
        "source must be a completed, successful CI run",
    )
    require(
        run.get("event") == "push" and run.get("head_branch") == "main",
        "source CI run must be a push to main",
    )
    require(
        (run.get("repository") or {}).get("full_name") == repository
        and (run.get("head_repository") or {}).get("full_name") == repository,
        "source CI run must belong to the expected repository",
    )
    require(run.get("id") == int(run_id), "source CI run id does not match the request")
    require(
        not attempt or run.get("run_attempt") == int(attempt),
        "source CI attempt does not match the request",
    )


def select_targets(manifest, run, hosts):
    require(isinstance(manifest, dict), "release manifest must be a JSON object")
    require(
        (manifest.get("commit"), manifest.get("runId"), manifest.get("runAttempt"))
        == (run["head_sha"], run["id"], run["run_attempt"]),
        "release manifest does not match the source CI run",
    )
    targets = manifest.get("targets")
    require(isinstance(targets, list) and targets, "release manifest has no targets")
    available = {}
    agents = set()
    for target in targets:
        require(isinstance(target, dict), "release target must be a JSON object")
        for field in ("host", "agent"):
            value = target.get(field)
            require(
                isinstance(value, str)
                and re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", value),
                f"target {field} must be a safe lowercase name",
            )
        path = target.get("storePath")
        require(
            isinstance(path, str)
            and re.fullmatch(r"/nix/store/[0-9abcdfghijklmnpqrsvwxyz]{32}-[A-Za-z0-9+._?=-]+", path),
            "target must have a valid Nix store path",
        )
        require(target["host"] not in available, f"duplicate target host: {target['host']}")
        require(target["agent"] not in agents, f"duplicate target agent: {target['agent']}")
        available[target["host"]] = {key: target[key] for key in ("host", "agent", "storePath")}
        agents.add(target["agent"])
    selected = [host.strip() for host in hosts.split(",")] if hosts.strip() else list(available)
    require(all(selected), "selected hosts must not include empty names")
    require(len(selected) == len(set(selected)), "selected hosts must be unique")
    for host in selected:
        require(host in available, f"selected host is not in this release: {host}")
    return [available[host] for host in sorted(selected)]


def validate_gates(payload, hosts):
    environments = {environment["name"]: environment for environment in payload["environments"]}
    for host in hosts:
        environment = environments.get(host)
        require(environment is not None, f"host {host} has no approval environment")
        require(environment.get("can_admins_bypass") is False, f"environment {host} permits admin bypass")
        require(
            any(
                rule.get("type") == "required_reviewers" and rule.get("reviewers")
                for rule in environment.get("protection_rules", [])
            ),
            f"environment {host} must require reviewers",
        )


def prepare_release(repository, run_id, attempt="", hosts=""):
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository), "repository must be owner/name")
    require(re.fullmatch(r"[1-9][0-9]*", run_id), "run id must be a positive integer")
    require(not attempt or re.fullmatch(r"[1-9][0-9]*", attempt), "attempt must be a positive integer")
    endpoint = f"repos/{repository}/actions/runs/{run_id}"
    if attempt:
        endpoint += f"/attempts/{attempt}"
    run = api(endpoint)
    validate_source(run, repository, run_id, attempt)
    with TemporaryDirectory(prefix="nix-release-") as directory:
        gh("run", "download", run_id, "--repo", repository,
           "--name", f"release-{run['run_attempt']}", "--dir", directory)
        try:
            manifest = json.loads(Path(directory, "release.json").read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise DeploymentError(f"cannot read release.json: {error}") from error
        targets = select_targets(manifest, run, hosts)
    host_names = [target["host"] for target in targets]
    validate_gates(api(f"repos/{repository}/environments?per_page=100"), host_names)
    return {
        "commit": run["head_sha"],
        "buildRunId": run["id"],
        "hosts": host_names,
        "matrix": {"include": targets},
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--attempt", default="", help="CI attempt; defaults to the latest")
    parser.add_argument("--hosts", default="", help="comma-separated hosts; defaults to all")
    args = parser.parse_args(argv)
    try:
        release = prepare_release(args.repository, args.run_id, args.attempt, args.hosts)
    except DeploymentError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(json.dumps(release, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
