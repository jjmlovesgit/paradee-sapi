"""Generate a C++ phoneme vocabulary table from Paradee's config.json."""

import json
import sys
from pathlib import Path


def main() -> None:
    source = Path(sys.argv[1])
    target = Path(sys.argv[2])
    vocab = json.loads(source.read_text(encoding="utf-8"))["vocab"]
    if any(len(symbol) != 1 for symbol in vocab):
        raise ValueError("Native tokenizer expects single-codepoint vocab entries")
    lines = [
        "// Generated from Paradee v1.2 config.json; do not edit.",
        "#pragma once",
        "#include <cstdint>",
        "#include <unordered_map>",
        "inline const std::unordered_map<wchar_t, int64_t> kParadeeVocab = {",
    ]
    lines.extend(f"    {{static_cast<wchar_t>(0x{ord(symbol):04X}), {token}}}," for symbol, token in vocab.items())
    lines.append("};")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
