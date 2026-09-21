#!/usr/bin/env python3
"""CPU contracts for the TP4 extension; no weights, model execution, or CUDA."""

from __future__ import annotations

import ast
from copy import deepcopy
from dataclasses import replace
import importlib.util
import logging
import math
import os
from pathlib import Path
from types import SimpleNamespace as NS
import unittest

os.environ["CUDA_VISIBLE_DEVICES"] = ""
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

import torch

torch.set_num_threads(1)

HERE = Path(__file__).resolve().parent
ROOT = Path(os.environ.get("GLM53_VLLM_ROOT", "/usr/local/lib/python3.12/dist-packages/vllm"))
spec = importlib.util.spec_from_file_location("tp4_patch", HERE / "patch-dflash-tp4.py")
patch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch)
SOURCES = patch.verified_sources(ROOT)
PATCHED = {relative: patch.transform(relative, source) for relative, source in SOURCES.items()}

from vllm.v1.core import kv_cache_utils as E
from vllm.v1.kv_cache_interface import (
    get_mamba_prefill_checkpoint_position,
    is_mamba_prefill_checkpoint_valid,
)


def load_function(source, name, namespace, class_name=None):
    tree = ast.parse(source)
    if class_name:
        tree = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == class_name)
    functions = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == name]
    node = deepcopy(functions[-1])
    node.decorator_list = []
    module = ast.Module(
        body=[ast.ImportFrom(module="__future__", names=[ast.alias(name="annotations")], level=0), node],
        type_ignores=[],
    )
    exec(compile(ast.fix_missing_locations(module), name, "exec"), namespace)
    return namespace[name]


# Only this test process sees the replacement functions. Installed files stay intact.
for function in ("_glm53_draft_spec_ok", "get_kv_cache_groups"):
    load_function(PATCHED[patch.CACHE], function, vars(E))
guard = load_function(
    PATCHED[patch.MODEL], "_glm53_dflash2_guard", {"torch": torch, "logger": logging.getLogger(__name__)}
)


def config(tp=4, k=5):
    draft = NS(
        architectures=["DFlash2DraftModel"], num_hidden_layers=5, hidden_size=4096,
        vocab_size=154880, num_attention_heads=32, num_key_value_heads=8,
        head_dim=128, intermediate_size=12288, sliding_window=2048,
        is_causal=False, layer_types=["sliding_attention"] * 5,
        dflash_config={
            "block_size": 8, "conv_group_size": 16, "conv_kernel_size": 2,
            "mask_token_id": 154856, "selector_rank": 256, "selector_top_k": 16,
            "target_layer_ids": [5, 14, 24, 33, 42],
        },
    )
    return NS(
        max_in_flight_tokens=8192,
        speculative_config=NS(
            method="dflash", draft_model_config=NS(hf_config=draft, quantization=None),
            draft_parallel_config=NS(tensor_parallel_size=tp), num_speculative_tokens=k,
            attention_backend="TRITON_ATTN", kv_cache_dtype="auto",
            rejection_sample_method="standard", enable_adaptive_verification=False,
            draft_sample_method="probabilistic", disable_eagle_block_drop=False,
        ),
        parallel_config=NS(tensor_parallel_size=tp, pipeline_parallel_size=1,
                           decode_context_parallel_size=1, prefill_context_parallel_size=1,
                           data_parallel_size=1),
        model_config=NS(
            dtype=torch.bfloat16, max_model_len=1048576,
            hf_config=NS(model_type="glm5_next", architectures=["Glm5NextForConditionalGeneration"],
                         vision_config=NS(model_type="glm5_next_vision")),
            hf_text_config=NS(model_type="glm5_next_text"),
        ),
        scheduler_config=NS(disable_hybrid_kv_cache_manager=False, max_num_batched_tokens=8192),
        cache_config=NS(get_resolved_kv_cache_layout=lambda: E.KVCacheLayout.LBHNC,
                        num_gpu_blocks_override=None, prefix_cache_retention_interval=None,
                        mamba_cache_mode="align"),
    )


TARGET = NS(num_hidden_layers=45, hidden_size=4096, vocab_size=154880, mhc=True)


def cache_specs(tp, block):
    specs = {}
    for i in range(11):
        specs[f"target.mla.{i}"] = E.MLAAttentionSpec(
            block_size=block, num_kv_heads=1, head_size=656, dtype=torch.uint8,
            state_content_bytes=656, cache_dtype_str="fp8_ds_mla",
        )
        specs[f"target.index.{i}"] = E.MLAAttentionSpec(
            block_size=block, num_kv_heads=1, head_size=320, dtype=torch.uint8,
            state_content_bytes=320, tokens_per_state=4,
        )
        specs[f"target.tail.{i}"] = E.KpoolTailSpec(
            block_size=4, num_kv_heads=1, head_size=128, head_size_v=0,
            dtype=torch.bfloat16, sliding_window=4,
        )
    for i in range(34):
        specs[f"target.mamba.{i}"] = E.MambaSpec(
            block_size=block, shapes=((block * 656 - 1024,),), dtypes=(torch.uint8,),
            num_speculative_blocks=7, mamba_cache_mode="align",
        )
    for i in range(5):
        specs[f"draft.layers.{i}"] = E.SlidingWindowSpec(
            block_size=block, num_kv_heads=8 // tp, head_size=128,
            dtype=torch.bfloat16, sliding_window=2048,
        )
    return specs


class RuntimeContracts(unittest.TestCase):
    def _scheduler_control(self, source, *, prompt=16299, resume=0,
                           minimum=1152, hash_block=1152, eagle=True,
                           shared=0):
        function = load_function(
            source, "_mamba_block_aligned_split",
            {"get_mamba_prefill_checkpoint_position": get_mamba_prefill_checkpoint_position,
             "is_mamba_prefill_checkpoint_valid": is_mamba_prefill_checkpoint_valid},
            "Scheduler",
        )
        scheduler = NS(
            cache_config=NS(block_size=minimum), block_size=2304,
            hash_block_size=hash_block, use_eagle_block_drop=eagle,
            mamba_has_prefill_checkpoint_blocks=False,
            mamba_partial_cache_hit=hash_block < 2304,
            mamba_prefill_checkpoint_alignment=None, max_num_scheduled_tokens=8192,
            scheduler_config=NS(long_prefill_token_threshold=0),
        )
        request = NS(num_computed_tokens=resume, num_tokens=prompt,
                     num_prompt_tokens=prompt, shared_prefix_boundary=shared)
        return function, scheduler, request

    def _scheduler_chunks(self, source, *, budgets=(8192,), **kwargs):
        function, scheduler, request = self._scheduler_control(source, **kwargs)
        ends = []
        while request.num_computed_tokens < request.num_prompt_tokens:
            budget = min(budgets[min(len(ends), len(budgets) - 1)],
                         request.num_prompt_tokens - request.num_computed_tokens)
            amount = function(scheduler, request, budget)
            self.assertGreater(amount, 0)
            self.assertLessEqual(amount, budget)
            request.num_computed_tokens += amount
            ends.append(request.num_computed_tokens)
        return ends

    def test_dflash_scheduler_uses_physical_alignment_not_minimum_group(self):
        original = self._scheduler_chunks(SOURCES[patch.SCHEDULER])
        candidate = self._scheduler_chunks(PATCHED[patch.SCHEDULER])
        self.assertEqual(original, [8064, 14976, 16128, 16299])
        self.assertEqual(candidate, [6912, 13824, 16128, 16299])
        self.assertNotEqual(original[0] % 2304, 0)
        self.assertTrue(all(end % 2304 == 0 for end in candidate[:-1]))

    def test_dflash_scheduler_fine_resumes_shared_junctions_and_mixed_budgets(self):
        for prompt in (15001, 16299, 17281):
            tail = prompt // 1152 * 1152
            for resume in (0, 8064, 9216, 11520, 13824, 14976):
                for budgets in ((8192,), (4096,), (8192, 4096, 8192), (2304, 4096, 8192)):
                    for shared in (0, 13000, 14976):
                        with self.subTest(prompt=prompt, resume=resume, budgets=budgets, shared=shared):
                            ends = self._scheduler_chunks(PATCHED[patch.SCHEDULER], prompt=prompt,
                                                          resume=resume, budgets=budgets, shared=shared)
                            self.assertEqual(ends[-1], prompt)
                            # Only the explicit prompt-tail checkpoint may be
                            # finer than a physical Mamba block; it has its own key.
                            self.assertTrue(all(end % 2304 == 0 or end == tail for end in ends[:-1]))
                            if resume % 2304 and ends[0] < prompt:
                                self.assertEqual(ends[0], (resume // 2304 + 1) * 2304)

    def test_dflash_scheduler_defers_too_small_budget(self):
        for budget in (1, 512, 1152, 2303):
            for resume in (0, 9216, 13824):
                with self.subTest(budget=budget, resume=resume):
                    function, scheduler, request = self._scheduler_control(PATCHED[patch.SCHEDULER], resume=resume)
                    self.assertEqual(function(scheduler, request, budget), 0)
        function, scheduler, request = self._scheduler_control(PATCHED[patch.SCHEDULER], resume=8064)
        self.assertEqual(function(scheduler, request, 1152), 1152)
        function, scheduler, request = self._scheduler_control(PATCHED[patch.SCHEDULER], resume=16128)
        self.assertEqual(function(scheduler, request, 171), 171)

    def test_scheduler_unchanged_for_mtp_and_baseline_equal_block_sizes(self):
        for eagle in (False, True):
            for resume in (0, 6912, 9216, 13824):
                for budgets in ((8192,), (4096,), (2304, 8192)):
                    with self.subTest(eagle=eagle, resume=resume, budgets=budgets):
                        kwargs = dict(minimum=2304, hash_block=2304, eagle=eagle,
                                      resume=resume, budgets=budgets, shared=13000)
                        self.assertEqual(self._scheduler_chunks(SOURCES[patch.SCHEDULER], **kwargs),
                                         self._scheduler_chunks(PATCHED[patch.SCHEDULER], **kwargs))

    def test_scheduler_ast_unchanged_outside_alignment_method(self):
        trees = [ast.parse(source) for source in (SOURCES[patch.SCHEDULER], PATCHED[patch.SCHEDULER])]
        for tree in trees:
            scheduler = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == "Scheduler")
            scheduler.body = [node for node in scheduler.body
                              if not isinstance(node, ast.FunctionDef) or node.name != "_mamba_block_aligned_split"]
        self.assertEqual(ast.dump(trees[0]), ast.dump(trees[1]))

    def test_scheduler_source_anchor_drift_fails_before_patch(self):
        source = SOURCES[patch.SCHEDULER]
        anchor = "        block_size = self.cache_config.block_size\n"
        self.assertIn(anchor, source)
        with self.assertRaises(ValueError):
            patch.transform(patch.SCHEDULER, source.replace(anchor, "        block_size = self.hash_block_size\n"))

    def test_guard_accepts_equal_tp2_tp4_and_reviewed_k(self):
        for tp in (2, 4):
            for k in (4, 5, 6, 7):
                with self.subTest(tp=tp, k=k):
                    self.assertTrue(guard(config(tp, k), TARGET))

    def test_guard_rejects_mismatched_tp_and_draft_geometry(self):
        for field, value in (("num_attention_heads", 16), ("num_key_value_heads", 4),
                             ("head_dim", 256), ("intermediate_size", 16384)):
            c = config()
            setattr(c.speculative_config.draft_model_config.hf_config, field, value)
            with self.subTest(field=field), self.assertRaises(ValueError):
                guard(c, TARGET)
        for tp, draft_tp in ((1, 1), (8, 8), (4, 2), (2, 4)):
            c = config(tp)
            c.speculative_config.draft_parallel_config.tensor_parallel_size = draft_tp
            with self.subTest(tp=tp, draft_tp=draft_tp), self.assertRaises(ValueError):
                guard(c, TARGET)

    def test_mtp_guard_and_target_forward_are_unchanged(self):
        c = config()
        c.speculative_config.method = "mtp"
        self.assertFalse(guard(c, TARGET))
        original = ast.parse(SOURCES[patch.MODEL])
        candidate = ast.parse(PATCHED[patch.MODEL])
        old_nodes = [ast.dump(n) for n in original.body if not isinstance(n, ast.FunctionDef) or n.name != "_glm53_dflash2_guard"]
        new_nodes = [ast.dump(n) for n in candidate.body if not isinstance(n, ast.FunctionDef) or n.name != "_glm53_dflash2_guard"]
        self.assertEqual(old_nodes, new_nodes)

    def test_native_target_cache_and_draft_geometry(self):
        for tp in (2, 4):
            for block in (2304, 4608):
                with self.subTest(tp=tp, block=block):
                    c = config(tp)
                    specs = cache_specs(tp, block)
                    target_specs = {n: s for n, s in specs.items() if n.startswith("target.")}
                    reference = E._get_kv_cache_groups_glm5_next(c, dict(target_specs))
                    groups = E.get_kv_cache_groups(c, dict(specs))
                    target, draft, _ = E._glm53_split_managed_groups(groups)
                    self.assertEqual(target, reference)
                    self.assertEqual(draft.kv_cache_spec.num_kv_heads, 8 // tp)
                    self.assertEqual([g.is_eagle_group for g in groups], [False] * len(target) + [True])
                    self.assertEqual(math.lcm(*(g.kv_cache_spec.block_size for g in groups)),
                                     math.lcm(*(g.kv_cache_spec.block_size for g in target)))
                    self.assertEqual(set(n for g in groups for n in g.layer_names), set(specs))
                    pool = E._get_kv_cache_bytes_per_block(groups)
                    self.assertEqual(pool, E._glm53_original_pool_bytes(target))
                    for count in (2, 17, 4096):
                        allocation = E.get_kv_cache_config_from_groups(c, groups, pool * count)
                        baseline = E._glm53_original_allocate(c, target, pool * count)
                        self.assertEqual(allocation.kv_cache_tensors[:-5], baseline.kv_cache_tensors)
                        self.assertEqual(allocation.num_blocks, baseline.num_blocks)
                        for tensor in allocation.kv_cache_tensors[-5:]:
                            payload = draft.kv_cache_spec.page_size_bytes
                            self.assertLessEqual(payload, tensor.block_stride)
                            self.assertLessEqual(tensor.offset + (count - 1) * tensor.block_stride + payload, tensor.size)
                    self.assertGreater(E._max_memory_usage_bytes_from_groups(c, groups),
                                       E._glm53_original_max_memory(c, target))

    def test_tp4_rejects_tp2_cache_and_kpool_tail(self):
        with self.assertRaises(ValueError):
            E.get_kv_cache_groups(config(4), cache_specs(2, 2304))
        tail = cache_specs(4, 2304)["target.tail.0"]
        self.assertFalse(E._glm53_draft_spec_ok(tail, 4))
        specs = cache_specs(4, 2304)
        specs["draft.layers.0"] = replace(specs["draft.layers.0"], dtype=torch.float32)
        with self.assertRaises(ValueError):
            E.get_kv_cache_groups(config(4), specs)

    def _assert_vocab_parallel_candidates(self, source):
        generator = torch.Generator().manual_seed(173)
        vocabulary, padded, batch, k = 154880, 155008, 3, 16
        logits = torch.rand(batch, padded, generator=generator)
        logits[:, vocabulary:] = float("inf")
        expected_logits = logits.clone()
        expected_logits[:, vocabulary:] = -float("inf")
        expected_values, expected_ids = expected_logits.topk(k, dim=-1)
        for tp in (2, 4):
            width = padded // tp
            values, ids = [], []
            for rank in range(tp):
                shard = expected_logits[:, rank * width:(rank + 1) * width]
                v, i = shard.topk(k, dim=-1)
                values.append(v)
                ids.append(i + rank * width)
            for rank in range(tp):
                calls = iter((
                    (values[rank], torch.cat(values, dim=-1)),
                    (ids[rank], torch.cat(ids, dim=-1)),
                ))

                def checked_gather(tensor, dim):
                    expected_local, gathered = next(calls)
                    self.assertEqual(dim, -1)
                    self.assertTrue(
                        torch.equal(tensor, expected_local),
                        f"Incorrect local candidates for TP{tp} rank {rank}",
                    )
                    return gathered

                namespace = {
                    "torch": torch,
                    "_topk": lambda scores, count: torch.topk(scores, count, dim=-1),
                    "tensor_model_parallel_all_gather": checked_gather,
                }
                topk = load_function(source, "get_top_k_tokens", namespace, "LogitsProcessor")
                shard = logits[:, rank * width:(rank + 1) * width].clone()
                processor = NS(scale=1.0, soft_cap=None, _apply_head=lambda *args: shard)
                head = NS(tp_size=tp, shard_indices=NS(
                    num_org_vocab_padding=max(0, (rank + 1) * width - vocabulary),
                    org_vocab_start_index=rank * width,
                ))
                actual_ids, actual_values = topk(processor, head, torch.empty(batch, 1), k)
                self.assertTrue(torch.equal(actual_ids, expected_ids))
                self.assertTrue(torch.equal(actual_values, expected_values))
                with self.assertRaises(StopIteration):
                    next(calls)

    def test_vocab_parallel_candidates_match_full_vocabulary(self):
        self._assert_vocab_parallel_candidates(SOURCES["model_executor/layers/logits_processor.py"])

    def test_vocab_collective_rejects_bad_local_mask_or_offset(self):
        source = SOURCES["model_executor/layers/logits_processor.py"]
        mutations = (
            ('logits[..., -num_pad:] = -float("inf")', 'logits[..., -num_pad:] = float("inf")'),
            ("ids = ids.to(torch.int64) + lm_head.shard_indices.org_vocab_start_index",
             "ids = ids.to(torch.int64)"),
        )
        for old, new in mutations:
            with self.subTest(mutation=old):
                self.assertIn(old, source)
                with self.assertRaisesRegex(AssertionError, "Incorrect local candidates"):
                    self._assert_vocab_parallel_candidates(source.replace(old, new))

    def test_source_drift_fails_before_patch(self):
        with self.assertRaises(ValueError):
            patch.transform(patch.MODEL, SOURCES[patch.MODEL].replace("pc.tensor_parallel_size != 2", "pc.tensor_parallel_size != 3"))

    def test_no_cuda_context(self):
        self.assertFalse(torch.cuda.is_initialized())


if __name__ == "__main__":
    unittest.main(verbosity=2)
