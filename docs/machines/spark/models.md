# Models

Model services start manually. Run archive commands on `spark-01`.

## Archive

Commands are resumable.

```sh
ssh spark-01.local models archive \
  deepseek-ai/DeepSeek-V4-Flash-0731@7872f01b1d1fe23eabc4c98b48bffcef5a386062
```

## Copy

Copy and verify an archived model on another Spark:

```sh
ssh spark-02.local models ensure \
  deepseek-ai/DeepSeek-V4-Flash-0731@7872f01b1d1fe23eabc4c98b48bffcef5a386062 \
  --source spark-01
```

## DeepSeek V4 Flash

DeepSeek uses `spark-01` and `spark-02`.

```sh
ssh spark-01.local sudo systemctl start infer-deepseek-v4-flash-0731
ssh spark-01.local journalctl -fu infer-deepseek-v4-flash-0731
ssh spark-01.local sudo systemctl stop infer-deepseek-v4-flash-0731
```

## GLM 5.3 Flash NVFP4

The deployed `glm53-flash-nvfp4-vllm` recipe uses corrected **DFlash2 at TP4,
K=5**, across `spark-01` through `spark-04`. It serves `spark-current`;
services still start manually.

### Configuration

- Target: `nvidia/GLM-5.3-Flash-NVFP4@09b04e5e74bca08ca8549fc736d4cdd8624bfde3`.
- BF16 draft: `incoai/GLM-5.3-Flash-DFlash2@bf582e4eacc1810f76656d1811693ff6c6737d2a`.
- Pinned SM121 B12X vLLM runtime, with the TP4 draft adapter and Mamba scheduler
  checkpoint-alignment correction. Target weights and sampling/rejection
  implementations are unchanged; model files are mounted read-only.
- DFlash uses TRITON draft attention, probabilistic proposals and standard
  rejection sampling, with adaptive verification disabled.
- Native context limit: 1,048,576 tokens; eight active requests; chunked prefill
  with an 8,192-token batch budget; CUDA graph capture limit 64.
- GPU memory utilization: 0.80 with automatic KV sizing, no explicit KV-byte
  pin; BF16 model dtype and FP8 KV cache. Recurrent state remains FP32.
- Prefix caching uses Mamba `align` mode and retention interval **2304**.
  Observed physical target/draft cache blocks are 2304/1152 tokens; the
  scheduler correction aligns checkpoints to the target's 2304-token boundary.

Persistent compilation caches live under
`/var/cache/glm53-flash-nvfp4-vllm`, retaining the tested DFlash compile-cache
subdirectory `vllm/tp4-dflash5-cache`.
Automatic sizing and an advertised 1M limit do not guarantee eight simultaneous
full-length contexts. Startup and first-use compilation can be slow and can page.

Archive both pinned checkpoints before preparing local copies:

```sh
ssh spark-01.local models archive \
  nvidia/GLM-5.3-Flash-NVFP4@09b04e5e74bca08ca8549fc736d4cdd8624bfde3
ssh spark-01.local models archive \
  incoai/GLM-5.3-Flash-DFlash2@bf582e4eacc1810f76656d1811693ff6c6737d2a
```

Manage the canonical service:

```sh
ssh spark-01.local sudo systemctl start infer-glm53-flash-nvfp4-vllm
ssh spark-01.local infer watch glm53-flash-nvfp4-vllm
ssh spark-01.local sudo systemctl stop infer-glm53-flash-nvfp4-vllm
```

For repeatable maintenance checks, use the
[Spark benchmark and resource monitor](../../../scripts/spark/README.md).

### Measured Choice

The September 19 comparison used matched TP4 requests, three batch trials,
K5, retention 2304, the same target/runtime, and forced 256-token outputs.
Median aggregate code throughput was:

| Concurrent requests | Cached MTP5 tok/s | DFlash5 tok/s |
| --- | ---: | ---: |
| 1 | 43.51 | 58.47 |
| 4 | 90.35 | 122.98 |
| 8 | 124.81 | 168.15 |

DFlash won 71 of 72 timed batch pairs and delivered roughly 34-36% higher code
throughput at these concurrencies. These rates include reasoning, not useful
answers per second; timed runs had swap-ins and are not independent cold starts.
Cached MTP had lower warm-prefix time to first output, while DFlash had shorter
median fixed-length completion times. That timing starts on content, reasoning,
or a tool fragment, not necessarily the first visible final answer.

The corrected DFlash path passed 23 cache and 27 mixed-cache requests around
16K input tokens. All 13 designated warm-cache checks reused 13,824 tokens;
the first exact repeat improved first-output latency from 6.14 to 1.41 seconds.
Mixed cold/warm work can still delay cached requests. A separate bounded Pi SDK
diagnostic passed six small repair workflows and their held-out checks, with
real tool-call IDs and reasoning/history serialization. It was not a full
unrestricted Pi CLI test or a broad coding-accuracy evaluation.

### Limitations

Intermittent extra assistant turns can produce a correct answer followed by
reasoning and a duplicate answer. This also reproduced on MTP and without
speculation; switching back is not a demonstrated fix. The finite low-effort
quality suite scored DFlash 102/108 strict responses versus MTP 103/108, with
different failing tasks. All held-out code checks passed, but that does not
establish broad accuracy parity. Markdown fences alone are acceptable for this
selection and are not a promotion blocker; duplicated or extraneous answers
remain a real output-contract risk. Do not silently trim them to claim a pass.

Higher reasoning effort did not satisfy every targeted output contract, so
the client default remains low. Longer Korean integrity probes found no
replacement characters, but did not grade factual correctness.

The single-stream diagnostic below supports cache reuse through roughly 1M
tokens. Full-pool eviction, simultaneous near-1M requests, and broad long-context
reasoning/coding accuracy remain untested. It is not a formal paired quality
qualification or a long-output throughput comparison.

### Long-Context Diagnostic

On September 20, the deployed canonical TP4 DFlash service passed a sequential
context ramp: **25/25 scored retrieval/cache requests and five shape warmups**.
Each size tested cold retrieval of random values near 10%, 50%, and 90% of a
synthetic ledger, two identical repeats, an edited suffix, and an appended turn.
Scored requests used temperature 0, low reasoning, native end-of-sequence, and a
2,048-token output budget. The JSON validator permits one outer Markdown fence,
but not commentary or duplicate answers. There was one active request at a time.

| Actual cold prompt tokens | Cold first output | First cached repeat | Second cached repeat |
| ---: | ---: | ---: | ---: |
| 16,318 | 6.09 s | 1.36 s | 1.36 s |
| 130,998 | 47.32 s | 2.42 s | 1.36 s |
| 262,060 | 99.13 s | 2.76 s | 1.61 s |
| 524,215 | 219.17 s | 3.44 s | 2.21 s |
| 999,931 | 487.70 s | 5.60 s | 4.16 s |

At roughly 1M tokens, exact repeats reused 99.54% and 99.77% of the prompt.
The suffix edit returned first output in 4.00 seconds with 99.77% reuse;
the appended turn used 1,000,021 input tokens and took 3.24 seconds with
99.88% reuse. These are first-output timings, potentially including reasoning,
not time to the complete final answer. Cold here means no reused prompt tokens;
each size had a preceding shape warmup, not a fresh engine start.

Across the two diagnostic runs, 374 resource samples and final snapshots showed
no new swap writes, OOM events, service restarts, or preemptions. Minimum observed
available memory was 8.77 GiB on the head and over 11 GiB on each worker.
Small reads from existing swap remained (about 8-50 MiB per node), so this was
not entirely paging-free. The diagnostic guard required at least 8 GiB available
and allowed up to 1 GiB of new swap writes per node; the stricter qualification
gate was not changed. Four quiet intervals separated the increasing sizes.

A separate mixed-concurrency diagnostic stopped at **56/57 passing requests**:
one cold request in an eight-request batch returned correct JSON, commentary,
then duplicate JSON. The failure is retained in this summary; the subsequent
30-request single-stream ramp does not turn it into a pass. Completion accounting
found no unexplained successful requests, and image/runtime identities and test
sources stayed unchanged. These bounded results support keeping DFlash for
single-session long-context use, without promising concurrent 1M capacity or
strict output-contract reliability.

### Cleanup Deployment

On September 20, the canonical service replaced the experimental instances on
all four nodes, preserving the selected model pins, arguments and compilation
cache. The rebuilt image passed its runtime tests; concurrent startup warmup
and both forced and automatic tool-call checks passed after deployment.

The 16K cache smoke stopped at its zero-new-swapout guard after the first
32-token warmup: `spark-03` wrote about 450 MiB to swap. The service remained
healthy, with no new OOM or restart, but the warm-cache retrieval checks were
not reached. The later long-context diagnostic above completed without further
swap writes; it does not erase that earlier startup/first-use paging event.
Raw experiment, migration, and diagnostic reports and temporary runners were
deleted; only this summary remains.

## API

The OpenAI-compatible API is `http://spark-01.local:8888/v1`. Cluster recipes
serve the model as `spark-current`.

```sh
curl --fail http://spark-01.local:8888/v1/models
```

LiteLLM exposes the recipe as `spark-current` at
`https://ai-api.angel.pizza/v1`. No Kiwi configuration change is required.
GLM emits reasoning separately from final content, so clients should allow at
least 128-256 completion tokens even for short answers. A smaller limit can
end with `finish_reason: length` before any final content is emitted.
