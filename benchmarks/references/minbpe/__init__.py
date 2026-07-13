# Vendored subset of Karpathy/minbpe (see README.md).
# Provides the byte-level BasicTokenizer (M1 benchmark) and RegexTokenizer
# (M2 benchmark). Both depend only on the bundled base.py and the
# third-party `regex` package (see requirements.txt); tiktoken/torch/gpt4
# extras are intentionally excluded.
from .base import Tokenizer, get_stats, merge
from .basic import BasicTokenizer
from .regex import RegexTokenizer
