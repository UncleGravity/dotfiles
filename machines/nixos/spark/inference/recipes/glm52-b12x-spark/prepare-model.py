#!/usr/bin/env python3
import json
import os
import shutil
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(message)


def link_tree(source: Path, target: Path) -> None:
    for source_path in source.rglob("*"):
        relative = source_path.relative_to(source)
        target_path = target / relative
        if source_path.is_dir():
            target_path.mkdir(parents=True, exist_ok=True)
            continue
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.unlink(missing_ok=True)
        target_path.symlink_to(source_path)


if len(sys.argv) != 4:
    fail("usage: prepare-model.py BASE_MODEL MTP_OVERLAY TARGET")

base_root, mtp_root, target_root = map(Path, sys.argv[1:])
for name, root in (("base model", base_root), ("MTP overlay", mtp_root)):
    if not root.is_dir():
        fail(f"missing {name}: {root}")

staging_root = target_root.with_name(f".{target_root.name}.staging-{os.getpid()}")
old_root = target_root.with_name(f".{target_root.name}.old")
shutil.rmtree(staging_root, ignore_errors=True)
staging_root.mkdir(parents=True)

link_tree(base_root, staging_root)
link_tree(mtp_root, staging_root)

config_path = staging_root / "config.json"
index_path = staging_root / "model.safetensors.index.json"
mtp_shard = staging_root / "model-00046-of-00046.safetensors"
if not config_path.is_file() or not index_path.is_file() or not mtp_shard.is_file():
    fail("the assembled model is missing its MTP config, index, or shard")

config = json.loads(config_path.read_text())
if config.get("num_hidden_layers") != 78 or config.get("num_nextn_predict_layers") != 1:
    fail("the overlay config does not describe the expected GLM 5.2 MTP layout")

weight_map = json.loads(index_path.read_text()).get("weight_map", {})
if not any(name.startswith("model.layers.78.") for name in weight_map):
    fail("the overlay index does not contain the native MTP layer")
missing_shards = sorted(
    shard for shard in set(weight_map.values()) if not (staging_root / shard).is_file()
)
if missing_shards:
    fail(f"the assembled model is missing indexed shards: {', '.join(missing_shards)}")

shutil.rmtree(old_root, ignore_errors=True)
if target_root.exists():
    target_root.rename(old_root)
staging_root.rename(target_root)
shutil.rmtree(old_root, ignore_errors=True)
