#!/usr/bin/env python3
"""
把 3Dmigoto HLSL dump 补成 RenderDoc Apply Changes 能编的文件。

只覆盖 Step 1 的一部分自动化。之后仍需手改：
  - 页表 / 打包读取用 asuint + ubfe（不要 (uint)float）
  - Texture2DArray.SampleGrad：用完整 ddx/ddy 寄存器的 .xy
  - 这里不要给资源改名、抽 helper、加 STEP_*

自动处理：
1) 把 '#define cmp -' 换成 cmp(bool*) helper（真 -> -1，假 -> 0）
2) 语义名去掉末尾 0：SV_Position0 / SV_Target0 / SV_VertexID0 / SV_InstanceID0

用法：
  python patch_3dmigoto_for_renderdoc.py input.hlsl -o out.hlsl
  python patch_3dmigoto_for_renderdoc.py - -o out.hlsl < dump.hlsl
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

CMP_HELPERS = """// 给 RenderDoc 用的 cmp（3Dmigoto：真 -> -1，假 -> 0）
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
        description="把 3Dmigoto HLSL dump 补成 RenderDoc Apply Changes 能编的文件。"
    )
    parser.add_argument("input", help="输入 HLSL 路径，或 '-' 表示 stdin")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="输出路径（默认：<stem>_renderdoc.hlsl）",
    )
    args = parser.parse_args()

    if args.input == "-":
        if args.output is None:
            print("[错误] 输入为 '-' 时必须指定 --output。", file=sys.stderr)
            return 1
        src = sys.stdin.read()
        if not src.strip():
            print("[错误] stdin 为空。", file=sys.stderr)
            return 1
        out_path = args.output
    else:
        in_path = Path(args.input)
        if not in_path.exists():
            print(f"[错误] 找不到输入：{in_path}", file=sys.stderr)
            return 1
        out_path = args.output or in_path.with_name(
            f"{in_path.stem}_renderdoc{in_path.suffix}"
        )
        src = in_path.read_text(encoding="utf-8", errors="replace")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(patch_text(src), encoding="utf-8", newline="\n")
    print(f"[完成] 已写入：{out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
