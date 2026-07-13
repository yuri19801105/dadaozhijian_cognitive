"""Benchmark: Python minbpe vs Mojo BPE tokenizer.

The minbpe reference is vendored under benchmarks/references/minbpe/
(see README.md there) so this benchmark is reproducible from a clean checkout.
"""
import os
import sys

# Point at the vendored minbpe package (relative to this file).
_REF_DIR = os.path.join(os.path.dirname(__file__), "references")
if _REF_DIR not in sys.path:
    sys.path.insert(0, _REF_DIR)

import time
from minbpe import BasicTokenizer

text = "天地玄黄 宇宙洪荒 日月盈昃 辰宿列张 寒来暑往 秋收冬藏 " * 1000
print(f"text_size: {len(text.encode('utf-8'))}")

t = BasicTokenizer()
t0 = time.perf_counter()
t.train(text, 300)
t1 = time.perf_counter()
print(f"train_time_ms: {(t1 - t0) * 1000:.0f}")

t2 = time.perf_counter()
ids = t.encode(text)
t3 = time.perf_counter()
print(f"encode_time_ms: {(t3 - t2) * 1000:.0f}")
print(f"encoded_ids: {len(ids)}")

t4 = time.perf_counter()
decoded = t.decode(ids)
t5 = time.perf_counter()
print(f"decode_time_ms: {(t5 - t4) * 1000:.0f}")
print(f"decode_match: {decoded == text}")

total = (t1 - t0 + t3 - t2 + t5 - t4) * 1000
print(f"total_time_ms: {total:.0f}")
