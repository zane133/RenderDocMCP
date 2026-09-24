"""Build Step 5 analysis harness for the 2026-09-24 09:16:47 shader.

The Apply-verified Step 4 body matches the 2026-09-22 14:03:15 toon-skin
shader family. Reuse that family's analysis instrumentation, then carry forward
the current dump's verified cube-cookie bitfield fixes.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
TEMPLATE = SHADERS / "zmd_ps_20260922_140315_step5_analysis.hlsl"
STEP4 = SHADERS / "zmd_ps_20260924_091647_step4_readable.hlsl"
OUT = SHADERS / "zmd_ps_20260924_091647_step5_analysis.hlsl"

HEADER = """// ZMD / Endfield PS - Step 5: STEP_*/DEBUG_VIS analysis harness
// Source: zmd_ps_20260924_091647_step4_readable.hlsl (Apply-verified)
// Dump: 3Dmigoto 2026-09-24 09:16:47
//
// STEP_* default 1 = original behavior. Off = documented identity/no contribution.
// DEBUG_VIS 0 = final; 1..11 = intermediates captured at their producing sites.
// Bindings, signatures, cbuffer packing, and default-on shader math are unchanged.
//
"""


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise ValueError(f"{label}: expected one match, got {count}")
    return text.replace(old, new, 1)


def main() -> int:
    if not STEP4.exists():
        print(f"[error] Missing Apply-verified Step 4: {STEP4}", file=sys.stderr)
        return 2

    text = TEMPLATE.read_text(encoding="utf-8")
    resources = text.find("Texture3D<float4> VolumetricFog3D")
    if resources < 0:
        print("[error] Template resource declarations not found", file=sys.stderr)
        return 2
    text = HEADER + text[resources:]

    text = replace_once(
        text,
        "              r16.w = r16.w ? 0.000000 : 0;",
        "              // [patch] dump printed int 1 as 0.000000 (movc l(1), l(0))\n"
        "              r16.w = r16.w ? 1 : 0;",
        "cube major-axis selector",
    )
    text = replace_once(
        text,
        "              bitmask.w = ((~(-1 << 31)) << 1) & 0xffffffff;  "
        "r16.w = (((uint)r16.w << 1) & bitmask.w) | ((uint)r20.w & ~bitmask.w);",
        "              // [patch] bfi face=(axis<<1)|signBit; avoid (uint)(-1.0) clamp\n"
        "              bitmask.w = ((~(-1 << 31)) << 1) & 0xffffffff;  "
        "r16.w = (((uint)r16.w << 1) & bitmask.w) | "
        "((r20.w != 0 ? 1u : 0u) & ~bitmask.w);",
        "cube face sign bit",
    )
    text = replace_once(
        text,
        "              r22.y = r22.y ? 0.000000 : 0;",
        "              // [patch] dump printed int 2 as 0.000000 (icb[2] vs icb[0])\n"
        "              r22.y = r22.y ? 2 : 0;",
        "cube U-axis selector",
    )

    required = (
        "STEP_VOLUME_PROBES",
        "STEP_SSS_EDGE_TINT",
        "STEP_SPLAT",
        "STEP_SHADOW_LUT",
        "STEP_DIFFUSE_RAMP",
        "STEP_MATCAP",
        "STEP_SPECULAR",
        "STEP_RIM",
        "STEP_LOCAL_LIGHTS",
        "STEP_COLOR_GRADE",
        "STEP_FOG",
        "DEBUG_VIS",
    )
    for symbol in required:
        if f"#define {symbol}" not in text:
            print(f"[error] Missing analysis switch: {symbol}", file=sys.stderr)
            return 2

    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"[ok] {OUT.name}: {text.count(chr(10)) + 1} lines")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
