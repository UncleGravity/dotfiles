#!/usr/bin/env python3
import shutil
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(message)


if len(sys.argv) != 2:
    fail("usage: prepare-runtime.py MODEL_ROOT")

model_root = Path(sys.argv[1])
encoding_source = model_root / "encoding" / "encoding_dsv4.py"
tokenizer_root = Path("/usr/local/lib/python3.12/dist-packages/vllm/tokenizers")
encoding_target = tokenizer_root / "deepseek_v4_encoding.py"
tokenizer_path = tokenizer_root / "deepseek_v4.py"

if not encoding_source.is_file():
    fail(f"missing DeepSeek V4 encoding source: {encoding_source}")
if not tokenizer_path.is_file():
    fail(f"missing vLLM DeepSeek V4 tokenizer: {tokenizer_path}")

shutil.copyfile(encoding_source, encoding_target)

old = '''elif reasoning_effort in ("max", "xhigh"):
                reasoning_effort = "max"
            else:
                reasoning_effort = "high"'''
new = '''elif reasoning_effort in ("max", "xhigh"):
                reasoning_effort = "max"
            elif reasoning_effort == "high":
                reasoning_effort = "high"
            else:
                reasoning_effort = "low"'''

contents = tokenizer_path.read_text()
if new not in contents:
    if old not in contents:
        fail("the pinned vLLM tokenizer no longer matches the 0731 compatibility patch")
    tokenizer_path.write_text(contents.replace(old, new, 1))
