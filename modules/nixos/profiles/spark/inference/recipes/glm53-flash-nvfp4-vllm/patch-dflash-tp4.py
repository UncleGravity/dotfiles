#!/usr/bin/env python3
"""Extend the pinned GLM DFlash2 adapter and preserve Mamba checkpoint alignment."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path


PATCH_ID = "glm53-dflash2-tp4-v2"
MODEL = "models/glm5next/nvidia/model.py"
CACHE = "v1/core/kv_cache_utils.py"
SCHEDULER = "v1/core/sched/scheduler.py"
SOURCE_HASHES = {
    MODEL: "2d6ae29fa262bb3afc7a6f303a6a7fa52e7f84812e07935df3ed35fe7697f091",
    CACHE: "77a8993c174c4ce91b260aab93f32fb9099985723bd162203aa29a1d0ac0449a",
    SCHEDULER: "4bafc9c06bc5e2add085e3b3df658e3bf52c47006706c3950ce646e65788d3fd",
    "model_executor/models/qwen3_dflash.py": "2ed8cd217aad112e19309713e0c8b491bf3250698f50509d9b1d1fb1cd7295e9",
    "model_executor/models/qwen3_dflash2.py": "c141daa4b2059c0098224ac36471c2197b7052c100bef0a4dbc2ca79b627053f",
    "model_executor/layers/logits_processor.py": "6b0603d67b0c756253c2fdc882a3896d2e873a16e9aa2ef877aabca8d36bdb5f",
    "v1/worker/gpu/spec_decode/dflash2/speculator.py": "9ae6a9e27e8777d9590914cbc925d9cb3b66a3031e830abb468c7c4cb2295382",
    "v1/worker/gpu/spec_decode/dflash/speculator.py": "093e49493b6e80bb2a0f660f20f77cb6d88695d09e79abf9505ad7e70661bb5f",
}


def replace_once(source: str, old: str, new: str) -> str:
    if source.count(old) != 1:
        raise ValueError(f"Expected one source anchor: {old!r}")
    return source.replace(old, new, 1)


def transform(relative: str, source: str) -> str:
    if relative == MODEL:
        source = replace_once(
            source,
            "    if pc.tensor_parallel_size != 2 or sc.draft_parallel_config.tensor_parallel_size != 2:\n"
            '        raise ValueError("GLM DFlash2 v3 requires target TP2 and draft TP2")\n',
            "    tp_size = pc.tensor_parallel_size\n"
            "    if tp_size not in (2, 4) or sc.draft_parallel_config.tensor_parallel_size != tp_size:\n"
            '        raise ValueError("GLM DFlash2 requires equal target/draft TP2 or TP4")\n'
            "    if (getattr(draft, \"num_attention_heads\", None) != 32\n"
            "            or getattr(draft, \"num_key_value_heads\", None) != 8\n"
            "            or getattr(draft, \"head_dim\", None) != 128\n"
            "            or getattr(draft, \"intermediate_size\", None) != 12288):\n"
            '        raise ValueError("GLM DFlash2 requires the reviewed Q32/KV8/head128 draft")\n',
        )
    elif relative == CACHE:
        source = replace_once(
            source,
            "def _glm53_draft_spec_ok(spec):\n"
            "    # KpoolTailSpec is a SlidingWindowSpec subclass: exact type is intentional.\n",
            "def _glm53_draft_spec_ok(spec, tp_size=None):\n"
            "    # Construction checks the configured TP; projected groups retain only specs.\n"
            "    if tp_size is not None and tp_size not in (2, 4):\n"
            "        return False\n"
            "    expected_heads = (2, 4) if tp_size is None else (8 // tp_size,)\n"
            "    # KpoolTailSpec is a SlidingWindowSpec subclass: exact type is intentional.\n",
        )
        source = replace_once(
            source,
            "            and spec.num_kv_heads == 4  # 8 checkpoint KV heads / TP2\n"
            "            and spec.num_heads == 4\n",
            "            and spec.num_kv_heads in expected_heads\n"
            "            and spec.num_heads == spec.num_kv_heads\n",
        )
        source = replace_once(
            source,
            "    if vllm_config.parallel_config.tensor_parallel_size != 2:\n"
            '        raise ValueError("GLM DFlash2 v3.1 is scoped to TP2")\n'
            "    draft = {n: s for n, s in kv_cache_spec.items() if type(s) is SlidingWindowSpec}\n"
            "    if len(draft) != 5 or not all(_glm53_draft_spec_ok(s) for s in draft.values()):\n"
            '        raise ValueError("GLM DFlash2: expected five non-quantized TP2 sliding KV layers")\n',
            "    tp_size = vllm_config.parallel_config.tensor_parallel_size\n"
            "    if tp_size not in (2, 4):\n"
            '        raise ValueError("GLM DFlash2 is scoped to TP2 or TP4")\n'
            "    if sc.draft_parallel_config.tensor_parallel_size != tp_size:\n"
            '        raise ValueError("GLM DFlash2 target and draft TP must match")\n'
            "    draft = {n: s for n, s in kv_cache_spec.items() if type(s) is SlidingWindowSpec}\n"
            "    if len(draft) != 5 or not all(_glm53_draft_spec_ok(s, tp_size) for s in draft.values()):\n"
            '        raise ValueError("GLM DFlash2: expected five BF16 sliding KV layers with 8/TP heads")\n',
        )
    elif relative == SCHEDULER:
        tree = ast.parse(source)
        scheduler = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == "Scheduler")
        method = next(node for node in scheduler.body if isinstance(node, ast.FunctionDef) and node.name == "_mamba_block_aligned_split")
        lines = source.splitlines(keepends=True)
        method_source = "".join(lines[method.lineno - 1:method.end_lineno])
        updated = replace_once(
            method_source,
            "        block_size = self.cache_config.block_size\n",
            "        # The minimum cache-group block can be smaller than a Mamba state.\n"
            "        block_size = self.block_size\n",
        )
        source = "".join(lines[:method.lineno - 1]) + updated + "".join(lines[method.end_lineno:])
    ast.parse(source, filename=relative)
    return source


def verified_sources(root: Path) -> dict[str, str]:
    sources = {}
    for relative, expected in SOURCE_HASHES.items():
        payload = (root / relative).read_bytes()
        actual = hashlib.sha256(payload).hexdigest()
        if actual != expected:
            raise ValueError(f"Unreviewed source {relative}: {actual}, expected {expected}")
        sources[relative] = payload.decode("utf-8")
    return sources


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vllm-root", type=Path, default=Path("/usr/local/lib/python3.12/dist-packages/vllm"))
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    sources = verified_sources(args.vllm_root)
    updates = {relative: transform(relative, sources[relative]) for relative in (MODEL, CACHE, SCHEDULER)}
    manifest = {
        "patch": PATCH_ID,
        "source_hashes": SOURCE_HASHES,
        "patched_hashes": {
            relative: hashlib.sha256(source.encode()).hexdigest()
            for relative, source in updates.items()
        },
    }
    if not args.check_only:
        for relative, source in updates.items():
            destination = args.vllm_root / relative
            temporary = destination.with_suffix(".py.tp4-tmp")
            temporary.write_text(source, encoding="utf-8")
            temporary.replace(destination)
        (args.vllm_root / "glm53-dflash-tp4-manifest.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
