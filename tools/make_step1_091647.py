#!/usr/bin/env python3
"""Step 1: patch 20260924_091647 3Dmigoto dump for RenderDoc Apply Changes."""
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
PASTE = ROOT / "shaders" / "zmd_ps_20260924_091647_paste_dump.hlsl"
OUT = ROOT / "shaders" / "zmd_ps_20260924_091647_step1_renderdoc.hlsl"

# 3Dmigoto expands ubfe(8, offset, src) as a dead if (8==0) / shift dance.
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
        return (
            f"{dest} = (asuint({src_expr}) >> {offset}) & 0xffu; "
            f"// [patch] ubfe(8,{offset}): asuint bitcast, not (uint)float"
        )

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

    # Cube-shadow atlas: dump prints int literals as 0.000000; (uint)cmp(-1)
    # saturates to 0 in FXC, dropping the negative-face bit.
    n_axis = text.count(
        "r16.w = cmp(abs(r21.x) < abs(r21.y));\n"
        "              r16.w = r16.w ? 0.000000 : 0;"
    )
    text = text.replace(
        "r16.w = cmp(abs(r21.x) < abs(r21.y));\n"
        "              r16.w = r16.w ? 0.000000 : 0;",
        "r16.w = cmp(abs(r21.x) < abs(r21.y));\n"
        "              // [patch] dump printed int 1 as 0.000000 (movc l(1), l(0))\n"
        "              r16.w = r16.w ? 1 : 0;",
        1,
    )
    n_bfi = text.count(
        "bitmask.w = ((~(-1 << 31)) << 1) & 0xffffffff;  r16.w = (((uint)r16.w << 1) & bitmask.w) | ((uint)r20.w & ~bitmask.w);"
    )
    text = text.replace(
        "bitmask.w = ((~(-1 << 31)) << 1) & 0xffffffff;  r16.w = (((uint)r16.w << 1) & bitmask.w) | ((uint)r20.w & ~bitmask.w);",
        "// [patch] bfi face=(axis<<1)|signBit; (uint)(-1.0) would clamp to 0\n"
        "              bitmask.w = ((~(-1 << 31)) << 1) & 0xffffffff;  r16.w = (((uint)r16.w << 1) & bitmask.w) | ((r20.w != 0 ? 1u : 0u) & ~bitmask.w);",
        1,
    )
    n_u = text.count(
        "r22.y = cmp((uint)r16.w < 2);\n"
        "              r22.y = r22.y ? 0.000000 : 0;"
    )
    text = text.replace(
        "r22.y = cmp((uint)r16.w < 2);\n"
        "              r22.y = r22.y ? 0.000000 : 0;",
        "r22.y = cmp((uint)r16.w < 2);\n"
        "              // [patch] dump printed int 2 as 0.000000 (icb[2].xz vs icb[0].xz)\n"
        "              r22.y = r22.y ? 2 : 0;",
        1,
    )

    header = (
        "// Step 1 — RenderDoc Apply Changes (register-faithful).\n"
        "// Patches: cmp helpers, SV_* trailing 0, ubfe asuint, cube-face int/bfi dump artifacts.\n"
        "// Source: zmd_ps_20260924_091647_paste_dump.hlsl\n"
    )
    if not text.startswith("// Step 1"):
        text = header + text

    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"[ok] Wrote: {OUT} ({OUT.stat().st_size} bytes)")
    print(f"  ubfe8 replacements: {n_ubfe}")
    print(f"  cube axis 1/0: {n_axis}")
    print(f"  cube bfi sign: {n_bfi}")
    print(f"  cube u-select 2/0: {n_u}")
    print(f"  leftover if (8 == 0): {text.count('if (8 == 0)')}")
    print(f"  leftover #define cmp: {text.count('#define cmp')}")
    print(f"  leftover SV_Position0: {text.count('SV_Position0')}")
    print(f"  leftover SV_Target0: {text.count('SV_Target0')}")
    print(f"  leftover SV_IsFrontFace0: {text.count('SV_IsFrontFace0')}")
    print(f"  leftover 0.000000 : 0: {text.count('0.000000 : 0')}")
    print(f"  SampleGrad: {text.count('SampleGrad')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
