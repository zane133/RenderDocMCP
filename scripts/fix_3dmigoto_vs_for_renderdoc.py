#!/usr/bin/env python3
"""
Patch a 3Dmigoto vertex shader dump into a RenderDoc-friendly HLSL file.

What it fixes:
1) Replaces '#define cmp -' with cmp(bool*) helper overloads.
2) Normalizes common DX semantics:
   - SV_InstanceID0 -> SV_InstanceID
   - SV_VertexID0   -> SV_VertexID
   - SV_Position0   -> SV_Position
3) Ensures out float3 p6 is initialized before return to avoid
   "used uninitialized output" compile failures in stricter compilers.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


CMP_HELPERS = """// RenderDoc-friendly cmp helpers (3Dmigoto semantics: true -> -1, false -> 0)
float cmp(bool v)   { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }
float3 cmp(bool3 v) { return v ? -1.0.xxx : 0.0.xxx; }
float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }
"""


def patch_text(src: str) -> str:
    text = src

    # 1) cmp macro replacement
    if "#define cmp -" in text:
        text = text.replace("#define cmp -", CMP_HELPERS, 1)

    # 2) semantic normalization
    text = text.replace("SV_InstanceID0", "SV_InstanceID")
    text = text.replace("SV_VertexID0", "SV_VertexID")
    text = text.replace("SV_Position0", "SV_Position")

    # 3) initialize p6 before return if needed
    has_p6_out = re.search(r"\bout\s+float3\s+p6\s*:\s*TEXCOORD6\b", text) is not None
    has_p6_assign = re.search(r"\bp6\s*=", text) is not None
    if has_p6_out and not has_p6_assign:
        # Insert before the final `return;` inside main.
        # We keep it simple because 3Dmigoto output always ends with return;.
        idx = text.rfind("return;")
        if idx != -1:
            text = text[:idx] + "  p6 = float3(0.0, 0.0, 0.0);\n" + text[idx:]

    return text


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert 3Dmigoto VS dump to RenderDoc-friendly HLSL."
    )
    parser.add_argument(
        "input",
        help="Input HLSL path, or '-' to read from stdin",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output path (default: <input_stem>_renderdoc.hlsl)",
    )
    args = parser.parse_args()

    if args.input == "-":
        if args.output is None:
            print("[error] When input is '-', --output is required.", file=sys.stderr)
            return 1
        out_path = args.output
        src = sys.stdin.read()
        if not src.strip():
            print("[error] stdin is empty.", file=sys.stderr)
            return 1
    else:
        in_path = Path(args.input)
        if not in_path.exists():
            print(f"[error] Input file not found: {in_path}", file=sys.stderr)
            return 1
        out_path = args.output or in_path.with_name(f"{in_path.stem}_renderdoc{in_path.suffix}")
        src = in_path.read_text(encoding="utf-8", errors="replace")
    patched = patch_text(src)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(patched, encoding="utf-8", newline="\n")

    print(f"[ok] Wrote: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
