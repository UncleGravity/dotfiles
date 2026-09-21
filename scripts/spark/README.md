# Spark Inference Checks

Two standard-library Python tools for an already running TP4 vLLM service:

- `benchmark.py`: throughput, tool-call, answer, and prefix-cache checks.
- `snapshot.py`: deployed configuration, health, and host-resource monitoring.

`client.py` is a shared helper, not another command. These tools do not deploy
recipes, restart services, or flush the server cache. Keep only useful summaries
in [the model notes](../../docs/machines/spark/models.md); temporary JSON/JSONL
reports are not an archive. Do not delete reports until the command and final
resource audit have finished.

## Small Checks

Run from the repository root. Choose a new campaign ID and output path for each
run so a previously cached prompt is not mistaken for a cold request. Use the
same ID and settings only when deliberately pairing different recipe arms.

```sh
python3 -B scripts/spark/snapshot.py --output /tmp/spark-manifest.json
python3 -B scripts/spark/benchmark.py \
  --endpoint http://spark-01.local:8888 --model spark-current \
  --arm glm53-flash-nvfp4-vllm --campaign-id unique-check-id \
  --manifest /tmp/spark-manifest.json \
  --stage tools --output /tmp/spark-tools.json
```

The snapshot defaults to the canonical `glm53-flash-nvfp4-vllm` instance on four
Sparks. Use `--identity /path/to/key` for an explicit SSH key, and `--instance`
for a different instance. The benchmark accepts `OPENAI_API_KEY` when needed.

| Stage | Scope |
| --- | --- |
| `short` (default) | Fixed-output throughput on small and 16K cold/reused prompts. Defaults to one concurrent request and one repetition. |
| `tools` | Forced and automatic tool-call checks. |
| `accuracy` | Small known-answer, Korean, and tool-call regression probes. |
| `unicode` | Longer Korean generation to detect replacement characters. |
| `cache` | Exact repeats, edited suffix, appended turn, and shared-prefix requests around 16K. |
| `mixed-cache` | Mixed cold/warm requests at C4 and C8, regardless of `--concurrency`. |
| `all` | Accuracy, cache, mixed-cache, and short stages; never the long-context ramp. |
| `long` | Explicit, guarded single-stream context ramp described below. |

For broader throughput checks, explicitly select `--concurrency 1,4,8` and
`--repeats 3`. Concurrent checks and `all` can affect other users' latency.
Use a quiet server for measurements, especially cache and long-context tests.

Generated code is never executed locally. Executable checks are optional:
`--code-host` and digest-pinned `--code-image` together opt into bounded CPU-only
Podman containers on that SSH host. See `--help` for limits and key selection.

## Guarded Long Context

Long mode is a diagnostic, not a formal accuracy qualification. It runs one
request at a time and stops at the first failed request or guard/accounting
check. Each size sends one 32-token shape warmup, cold retrieval, two exact
repeats, a suffix edit, and an appended conversation turn. Scored requests allow
native EOS and default to a 2,048-token output budget. Sizes default to 16K,
128K, 256K, 512K, and 1,000,000 input tokens, with 60-second quiet intervals
between sizes. Tokenization and actual usage must support the requested sizes.

Capture a manifest within five minutes of starting the check. Long mode connects
directly to the manifest's rank-0 hostname and serving port, not a proxy or alias.
It requires an active snapshot guard log with an available-memory floor of at
least 8 GiB and explicit cumulative swap-out and new-OOM policies.
Use the same log path for the monitor's `--output` and benchmark's `--guard-log`:

```sh
python3 -B scripts/spark/snapshot.py --output /tmp/spark-long-manifest.json
python3 -B scripts/spark/snapshot.py \
  --output /tmp/spark-long-resources.jsonl --interval 5 \
  --min-available-gib 8 --max-new-swapout-pages 0 --fail-on-new-oom \
  --watch-command python3 -B scripts/spark/benchmark.py \
    --endpoint http://spark-01.local:8888 --model spark-current \
    --arm glm53-flash-nvfp4-vllm --campaign-id unique-long-check-id \
    --stage long --concurrency 1 --repeats 1 \
    --manifest /tmp/spark-long-manifest.json \
    --guard-log /tmp/spark-long-resources.jsonl \
    --output /tmp/spark-long.json
```

Put every monitor option before `--watch-command`; do not insert another `--`.
For a shorter ramp, use `--long-targets 16384,131072` on the benchmark. A cold 1M
request can take about eight minutes to produce first output on the selected
recipe; a full ramp takes substantially longer. This does not test concurrent
1M capacity, full-pool eviction, or broad long-context reasoning accuracy.

Guard thresholds are operator-selected, not guaranteed capacity limits. The
example permits no new swap writes; existing swap usage does not itself fail.
`--max-new-swapout-pages` is in **pages, not bytes**, cumulative per node over
the monitored command. Check the host page size before choosing a byte-based
allowance. Zero new swap-out does not mean zero swap-ins or page faults.

Monitoring is sampled, so transient pressure between samples may be missed.
The wrapper terminates only its owned local process group on a guard failure;
it does not stop the service or guarantee instant cancellation of a remote
generation. Inspect the wrapper exit status and final resource sample as well
as the benchmark report. An incomplete report is not a pass. Guards are opt-in
for other stages; the same wrapper can monitor any of them. The collector alone
records unrelated collection/health errors as failures but only configured
resource guards stop its child immediately.

## Interpreting Results

- TTFT starts at the first content, reasoning, or tool fragment, not necessarily
  the final answer. Output-token counts include reasoning.
- Fixed-output throughput is not accuracy evidence; streaming decode speed is
  an estimate because one SSE event may carry multiple tokens.
- JSON checks allow one outer Markdown fence, but reject extra prose, duplicate
  answers, wrong keys, and wrong values. Do not trim failures into passes.
- Cache checks require reported token reuse as well as the correct answer.
  A shape warmup is excluded from scored results and is not a cold engine boot.
- A saved manifest describes an observation, not permanent runtime identity.
  The long-mode monitor checks current guard evidence and request accounting.
- These tools replace the experiment-specific paired qualification/comparison
  scripts; they do not reproduce or certify the removed formal qualification.

## Offline Tests

Neither test command contacts the cluster or model API:

```sh
python3 -B scripts/spark/test-benchmark.py
python3 -B scripts/spark/test-snapshot.py
```
