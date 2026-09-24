#!/usr/bin/env python3
"""Step 1: patch 145935 3Dmigoto dump for RenderDoc Apply Changes."""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(
    0,
    str(
        Path(r"C:\Users\Catfood\.cursor\skills\renderdoc-decompiled-shader-readable\scripts")
    ),
)
from patch_3dmigoto_for_renderdoc import patch_text  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
PASTE = ROOT / "shaders" / "zmd_ps_20260922_145935_paste_dump.hlsl"
OUT = ROOT / "shaders" / "zmd_ps_20260922_145935_step1_renderdoc.hlsl"

# 3Dmigoto expands ubfe(8, offset, src) as a dead if (8==0) / shift dance.
# Prefer asuint bitcast + mask (not (uint)float numeric convert).
UBFE8 = re.compile(
    r"if \(8 == 0\) (\w+(?:\.\w+)?) = 0; else if \(8\+(\d+) < 32\) \{\s+"
    r"\1 = \(uint\)([^;]+) << \(32-\(8 \+ \2\)\); \1 = \(uint\)\1 >> \(32-8\);\s+"
    r"\} else \1 = \(uint\)\3 >> \2;"
)
UBFE8_LOOSE = re.compile(
    r"if \(8 == 0\) (\w+(?:\.\w+)?) = 0; else if \(8\+(\d+) < 32\) \{[^}]+\} "
    r"else \1 = \(uint\)([^;]+) >> \2;"
)


def fix_ubfe8(text: str) -> tuple[str, int]:
    def repl(m: re.Match[str]) -> str:
        dest, offset, src_expr = m.group(1), m.group(2), m.group(3).strip()
        return f"{dest} = (asuint({src_expr}) >> {offset}) & 0xffu;"

    text, n = UBFE8.subn(repl, text)
    if n == 0:
        text, n = UBFE8_LOOSE.subn(repl, text)
    return text, n


def main() -> int:
    if not PASTE.exists():
        print(f"[error] Missing paste: {PASTE}", file=sys.stderr)
        return 2

    src = PASTE.read_text(encoding="utf-8", errors="replace")
    text = patch_text(src)
    text = text.replace("SV_IsFrontFace0", "SV_IsFrontFace")
    text, n_ubfe = fix_ubfe8(text)

    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"[ok] Wrote: {OUT} ({OUT.stat().st_size} bytes)")
    print(f"  ubfe8 replacements: {n_ubfe}")
    print(f"  leftover if (8 == 0): {text.count('if (8 == 0)')}")
    print(f"  leftover #define cmp: {text.count('#define cmp')}")
    print(f"  leftover SV_Position0: {text.count('SV_Position0')}")
    print(f"  leftover SV_Target0: {text.count('SV_Target0')}")
    print(f"  leftover SV_IsFrontFace0: {text.count('SV_IsFrontFace0')}")
    print(f"  SampleGrad: {text.count('SampleGrad')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
