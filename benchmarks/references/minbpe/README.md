# Vendored reference: Karpathy/minbpe

This directory is a **vendored, frozen copy** of the byte-level BPE reference
implementation used to benchmark the Mojo tokenizers
(`../bench_bpe.mojo` for M1, `../bench_regex.mojo` for M2).

## Provenance

- Source: <https://github.com/karpathy/minbpe>
- Pinned commit: `1acefe89412b20245db5a22d2a02001e547dc602`
- Fetched: 2026-07-10
- License: MIT — Copyright (c) 2024 Andrej Karpathy (see `LICENSE`)

## What is retained

- `base.py` — `Tokenizer` base class, `get_stats`, `merge`
- `basic.py` — `BasicTokenizer` (byte-level BPE, no regex splitting, no special tokens) — used by M1
- `regex.py` — `RegexTokenizer` (GPT-4 split pattern + special tokens) — used by M2
- `__init__.py` — exports `Tokenizer`, `BasicTokenizer`, `RegexTokenizer`

The upstream `gpt4.py` variant is intentionally **dropped** because it requires
`tiktoken` / `torch`, which are irrelevant to these benchmarks.

## Third-party dependency

`regex.py` imports the third-party **`regex`** package (not the stdlib `re`),
because the GPT-4 split pattern relies on Unicode property escapes (`\p{L}`,
`\p{N}`). Install it once into the project venv:

```bash
uv pip install --python .venv -r benchmarks/references/requirements.txt
```

`requirements.txt` pins the exact version captured on 2026-07-10.

## Why vendored

The original benchmark scripts hard-coded transient scratch paths
(`/tmp/minbpe`, `/tmp/minbpe-src`), which made the Python side of the benchmarks
non-reproducible. Vendoring the reference here makes the Mojo-vs-Python
comparison re-runnable at any time from a clean checkout.

## Reproduce the comparisons

```bash
# --- M1: BasicTokenizer ---
./.venv/bin/mojo run -I src benchmarks/bench_bpe.mojo
./.venv/bin/python benchmarks/bench_minbpe.py          # vendored copy, auto-detected

# --- M2: RegexTokenizer (requires `regex` installed) ---
./.venv/bin/mojo run -I src benchmarks/bench_regex.mojo
./.venv/bin/python benchmarks/bench_minbpe_regex.py    # vendored copy, auto-detected
```
