"""Benchmark: Python minbpe RegexTokenizer vs Mojo RegexTokenizer."""
import os
import sys

# Use the vendored minbpe reference (benchmarks/references/minbpe) so this
# benchmark is reproducible from a clean checkout. Requires the `regex` package
# (see benchmarks/references/requirements.txt).
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "references"))

import time
from minbpe import RegexTokenizer

text = "the quick brown fox jumps over the lazy dog. The dog was lazy! 123 4567. hello-world foo_bar. " * 500
print(f"text_size: {len(text.encode('utf-8'))}")

t = RegexTokenizer()
t0 = time.perf_counter()
t.train(text, 300)
t1 = time.perf_counter()
print(f"train_time_ms: {(t1 - t0) * 1000:.0f}")

t2 = time.perf_counter()
ids = t.encode_ordinary(text)
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
