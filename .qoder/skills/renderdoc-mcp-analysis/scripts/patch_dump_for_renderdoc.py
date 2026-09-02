#!/usr/bin/env python3
"""
Patch a 3Dmigoto HLSL dump into a RenderDoc Apply Changes-friendly file.

This script is Step 4 *partial* automation only. Always hand-fix after:
  - asuint + ubfe for page-table / packed loads (not (uint)float)
  - Texture2DArray.SampleGrad: use .xy from full ddx/ddy registers
  - Do NOT rename resources, extract helpers, or add STEP_* here

Automated fixes:
1) Replace '#define cmp -' with cmp(bool*) helpers (true -> -1, false -> 0).
2) Normalize semantics: SV_Position0/SV_Target0/SV_VertexID0/SV_InstanceID0.

Usage:
  python patch_dump_for_renderdoc.py input.hlsl -o out.hlsl
  python patch_dump_for_renderdoc.py - -o out.hlsl < dump.hlsl
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

CMP_HELPERS = """// RenderDoc-friendly cmp helpers (3Dmigoto: true -> -1, false -> 0)
float cmp(bool v)   { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }
float3 cmp(bool3 v) { return v ? -1.0.xxx : 0.0.xxx; }
float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }
"""


def patch_text(src: str) -> str:
    text = src

    if "#define cmp -" in text:
        text = text.replace("#define cmp -", CMP_HELPERS, 1)

    for old, new in (
        ("SV_InstanceID0", "SV_InstanceID"),
        ("SV_VertexID0", "SV_VertexID"),
        ("SV_Position0", "SV_Position"),
        ("SV_Target0", "SV_Target"),
    ):
        text = text.replace(old, new)

    return text


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Patch 3Dmigoto HLSL dump for RenderDoc Apply Changes."
    )
    parser.add_argument("input", help="Input HLSL path, or '-' for stdin")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output path (default: <stem>_renderdoc.hlsl)",
    )
    args = parser.parse_args()

    if args.input == "-":
        if args.output is None:
            print("[error] When input is '-', --output is required.", file=sys.stderr)
            return 1
        src = sys.stdin.read()
        if not src.strip():
            print("[error] stdin is empty.", file=sys.stderr)
            return 1
        out_path = args.output
    else:
        in_path = Path(args.input)
        if not in_path.exists():
            print(f"[error] Input not found: {in_path}", file=sys.stderr)
            return 1
        out_path = args.output or in_path.with_name(
            f"{in_path.stem}_renderdoc{in_path.suffix}"
        )
        src = in_path.read_text(encoding="utf-8", errors="replace")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(patch_text(src), encoding="utf-8", newline="\n")
    print(f"[ok] Wrote: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
