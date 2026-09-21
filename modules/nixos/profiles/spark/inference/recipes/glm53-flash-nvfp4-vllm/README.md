# GLM 5.3 Flash NVFP4 Runtime

The canonical recipe uses four DGX Sparks, DFlash2 with five speculative tokens,
a 1,048,576-token context, GPU memory utilization 0.80, and prefix-cache
retention interval 2304. Target and draft revisions are pinned in `default.nix`.
KV memory is sized automatically. The compilation cache remains
`/cache/vllm/tp4-dflash5-cache` to preserve existing artifacts.

This image extends the pinned Pilcothink runtime's DFlash2 adapter from equal
target/draft TP2 to equal TP2 or TP4. The NVIDIA target checkpoint, b12x target
backends, BF16 draft, sampling/rejection implementation, mHC tap transform,
target forward, and native cache allocator are retained.

The TP4 extension changes two installed files. The model guard validates the
reviewed draft dimensions (32 query heads, 8 KV heads, head dimension 128,
intermediate size 12288). Cache construction checks `8 / TP` local KV heads,
then reuses the existing block-divisor selection, separate draft block table,
physical MLA slot views, and admission accounting. Projected cache groups can
recognize either two or four local heads. Other parallel layouts are rejected.

Version `glm53-dflash2-tp4-v2` also corrects the scheduler's Mamba prefill
alignment source. Engine initialization sets `cache_config.block_size` to the
smallest prefix-cacheable group: 1152 for the observed DFlash draft, versus
2304 for the target Mamba state and scheduler LCM. The native splitter used
the smaller value. It now uses the separately resolved scheduler block size,
which preserves physical target checkpoint boundaries. The source change is
limited to `_mamba_block_aligned_split`; no draft group is excluded.

For a 16,299-token prompt with an 8192-token chunk budget, extracted-method
controls change chunk ends from 8064/14976/16128/16299 to
6912/13824/16128/16299. Symbolic native allocator/hash accounting demonstrates
the former can associate an 8064-token state with a 9216-token prefix hash;
the corrected control has matching state/hash lengths. This is a CPU model,
not inspection of live GPU tensor contents. MTP/no-speculation splitting is
unchanged when the minimum group block already equals the scheduler LCM.

## Source Audit

Base image:
`pilcothink/vllm_spark_glm53@sha256:09da6eb394216d174ab8692758d90f9f458398d9c8fbc11ba6f04e93d5cf6392`.
Its recorded vLLM source commit is
`6fbb00b18874e27ba7d7adc0a3b8e93fee763ab1`, with additional installed GLM patches.
The patch verifies exact SHA-256 values for eight installed dependencies before
changing any of the three files; it does not assume that an upstream version string
identifies all local changes.

- `qwen3_dflash.py` divides query/KV heads by tensor-parallel size, uses
  `QKVParallelLinear` and `RowParallelLinear`, and obtains context-KV projection
  dimensions from each rank's loaded attention layers.
- `qwen3_dflash2.py` keeps grouped convolution and the candidate selector
  replicated. These operate on the full hidden vector after the attention/MLP
  reductions. They contain no TP2-specific dimension.
- `logits_processor.py` collects per-rank top-K values and global vocabulary
  IDs, then reduces them to the global top-K. Padding is masked before selection.
- The installed GLM model materializes deferred mHC post state only for its
  five side outputs and contracts the residual streams. Its sequence-parallel
  branch gathers those side outputs before handing them to the draft.
- The installed DFlash attention metadata override already selects the draft
  model's geometry while retaining the matching tensor-parallel topology.

References:
[pinned upstream draft model](https://github.com/vllm-project/vllm/blob/6fbb00b18874e27ba7d7adc0a3b8e93fee763ab1/vllm/model_executor/models/qwen3_dflash.py),
[pinned upstream DFlash2](https://github.com/vllm-project/vllm/blob/6fbb00b18874e27ba7d7adc0a3b8e93fee763ab1/vllm/model_executor/models/qwen3_dflash2.py),
[draft checkpoint configuration](https://huggingface.co/incoai/GLM-5.3-Flash-DFlash2/blob/bf582e4eacc1810f76656d1811693ff6c6737d2a/config.json).
The external
[TP4 launch recipe](https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-1M-KV-4x-DGX-Spark/blob/main/launch-glm53-tp4-24g.sh)
is evidence of another TP4 integration, not the source of this patch or proof
of compatibility with this image.

## Validation

`test-runtime.py` runs 15 CPU tests against the unmodified pinned base runtime,
including deliberately broken padding and vocabulary-offset controls and
extracted scheduler regressions
for physical checkpoint alignment, fine cache-hit resumes, mixed chunk budgets,
and unchanged behavior when the minimum group block equals the scheduler LCM.
It applies only in-memory function replacements to that test
process and confirms that no CUDA context was initialized. The container build
runs those tests against the unmodified pinned base before installing the patch.

The tests cover TP2/TP4 and K4-7 guards, incorrect topology/model/cache geometry,
unchanged MTP guard behavior and target forward AST, real vLLM cache specs and
allocator descriptors at 2304/4608-token blocks, target tensor preservation,
draft admission cost, block bounds, and vocabulary top-K across each simulated
TP rank including padded vocabulary entries. Synthetic cache geometry is not a
measurement of runtime cache capacity. The collective test supplies the gathered
CPU tensors; it does not exercise NCCL or GPU communication.

The CPU tests do not qualify model output quality, CUDA graph replay,
concurrency, long-context behavior, or cache eviction. The runtime retains
known strict-format failures; no parser, stop-token, or output-trimming
workaround is installed.
No DFlash prefix-cache exclusion, kernel substitution, custom RoCE communicator,
or proposal/rejection change is part of this runtime.
