"""Shared HTTP, SSE, and tokenized ledger helpers for the Spark benchmark."""

import http.client
import json
import os
import random
import urllib.request


PROMPTS = {
    "dns": "Explain how a recursive DNS resolver resolves a fresh domain lookup, "
    "including caching, TTLs, negative answers, and DNSSEC validation.",
    "code": "Write a Python function that merges overlapping closed integer "
    "intervals. Explain the invariant and include examples and complexity.",
    "math": "Derive the sum of the first n squares by induction, carefully "
    "explaining every algebraic step, then evaluate it for n=100.",
    "creative": "Write a vivid story about an engineer restoring a silent lunar "
    "radio station. Include dialogue and a surprising but plausible ending.",
}


def sse_events(response):
    data = []
    for raw in response:
        line = raw.decode("utf-8").rstrip("\r\n")
        if not line:
            if data:
                yield "\n".join(data)
                data = []
        elif line.startswith("data:"):
            data.append(line[5:].lstrip(" "))
    if data:
        yield "\n".join(data)


class Client:
    def __init__(self, args):
        base = args.endpoint.rstrip("/")
        self.base = base[:-3] if base.endswith("/v1") else base
        self.args = args
        self.tokenize_error = None

    def post(self, route, body):
        headers = {"Content-Type": "application/json"}
        api_key = os.environ.get("OPENAI_API_KEY")
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"
        request = urllib.request.Request(
            f"{self.base}{route}", json.dumps(body).encode(), headers=headers
        )
        return urllib.request.urlopen(request, timeout=self.args.timeout)

    def chat_body(self, prompt):
        return {
            "model": self.args.model,
            "messages": [{"role": "user", "content": prompt}],
            "chat_template_kwargs": {"reasoning_effort": self.args.reasoning_effort},
        }

    def tokenize(self, prompt):
        if self.tokenize_error:
            return None
        try:
            with self.post("/tokenize", self.chat_body(prompt)) as response:
                result = json.load(response)
            count = result.get("count")
            if count is None:
                count = len(result["tokens"])
            return int(count)
        except (OSError, ValueError, KeyError, http.client.HTTPException) as error:
            self.tokenize_error = str(error)
            print(f"Tokenization unavailable: {error}.", flush=True)
            return None


def long_prompt(client, target, nonce, seed):
    rng = random.Random(seed)
    expected = {f"vault_{name}": f"{rng.getrandbits(64):016x}" for name in ("a", "b", "c")}
    needles = list(expected.items())
    records = max(100, target // 22)

    def build(count):
        positions = {int(count * fraction): needles[index] for index, fraction in enumerate((0.1, 0.5, 0.9))}
        lines = [f"Request nonce: {nonce}", "Read the following maintenance ledger carefully."]
        for index in range(count):
            if index in positions:
                key, value = positions[index]
                lines.append(f"CRITICAL VAULT RECORD: {key} has access code {value}.")
            lines.append(
                f"Record {index:06d}: sector {index % 97:02d} passed inspection; "
                f"pressure {980 + index % 31} units; maintenance cycle {index % 13:02d} complete."
            )
        lines.append(
            "Return only a JSON object with the exact access codes for vault_a, "
            "vault_b, and vault_c. Do not include commentary or other keys."
        )
        return "\n".join(lines)

    prompt = build(records)
    count = client.tokenize(prompt)
    if count is None:
        records = max(100, int(records * target / max(1, len(prompt) / 4)))
        prompt = build(records)
    else:
        # Leave a small margin for the chat template and integer record lengths.
        for _ in range(5):
            if target - 128 <= count <= target:
                break
            records = max(100, int(records * (target - 64) / count))
            prompt = build(records)
            count = client.tokenize(prompt)
            if count is None:
                break
        if count is not None and count > target:
            raise ValueError(f"Long prompt has {count} tokens, exceeding target {target}")
    return prompt, expected, count
