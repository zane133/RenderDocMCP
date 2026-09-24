"""Build Step 5 analysis harness from the Apply-OK Step 4 readable file.

Inserts STEP_*/DEBUG_VIS switches only. Math with all STEP_*=1 and DEBUG_VIS=0
is identical to Step 4.
"""

from __future__ import annotations

import sys
from pathlib import Path

SHADERS = Path(__file__).resolve().parent.parent / "shaders"
SRC = SHADERS / "zmd_ps_20260922_145935_step4_readable.hlsl"
DST = SHADERS / "zmd_ps_20260922_145935_step5_analysis.hlsl"

HEADER_SWAP = (
    "// ZMD / Endfield PS - Step 4: readable resource names, CB aliases, section map\n"
    "// Source dump: 3Dmigoto 2026-09-22 14:59:35\n",
    "// ZMD / Endfield PS - Step 5: STEP_*/DEBUG_VIS analysis harness\n"
    "// Source dump: 3Dmigoto 2026-09-22 14:59:35  (toon skin)\n"
    "// Builds on Apply-OK Step 4 (zmd_ps_20260922_145935_step4_readable.hlsl).\n"
    "// STEP_*: default 1 = original. Off = true identity / no contribution.\n"
    "// DEBUG_VIS: 0 = final o0; 1..N = intermediates captured at the producing site\n"
    "// (later fog / lights reuse the same rN — do not read them at the return).\n",
)

SWITCHES = """
// ===== Analysis switches =====
#define STEP_VOLUME_PROBES  1  // 0 → else-branch identity (no SH probes)
#define STEP_SSS_EDGE_TINT  1  // 0 → multiply = 1 (do NOT leave the (1-N.V) curve peaked)
#define STEP_DETAIL         1  // 0 → skip animated NormalMap detail; keep geometric N
#define STEP_SHADOW_LUT     1  // 0 → use metallic-split diffuse instead of LUT hue
#define STEP_DIFFUSE_RAMP   1  // 0 → ramp chroma = 0 (white wrap, keep ramp.a mask)
#define STEP_MATCAP         1  // 0 → matcap add = 0
#define STEP_SPECULAR       1  // 0 → skip GGX add (ViewShiftedSpecMap + matcap may remain)
#define STEP_RIM            1  // 0 → rim+extraRim factor 0 (do NOT peak the wrap)
#define STEP_LOCAL_LIGHTS   1  // 0 → skip tiled local-light loop
#define STEP_COLOR_GRADE    1  // 0 → skip cb5 grade
#define STEP_FOG            1  // 0 → exposed color only

#define DEBUG_VIS 0
// 0  final
// 1  baseColor (post detail blend / tint, pre SSS edge)
// 2  shadingNormal geometric *0.5+0.5
// 3  shadingNormal after detail *0.5+0.5
// 4  SSS edge tint multiply
// 5  ShadowColorLUT
// 6  SkinDiffuseRamp rgb
// 7  ramp chroma (max-min) as grey
// 8  lit before rim (after spec/matcap)
// 9  rim + extraRim term only
// 10 1-|N·V| saved at rim site
// 11 preFog (after lights / grade, before /exposure)

"""


def fail(msg: str) -> None:
    print(f"[error] {msg}", file=sys.stderr)
    raise SystemExit(1)


def once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        fail(f"{label}: expected 1 occurrence, got {text.count(old)}")
    return text.replace(old, new, 1)


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    if HEADER_SWAP[0] not in text:
        fail("unexpected Step 4 header")
    text = text.replace(HEADER_SWAP[0], HEADER_SWAP[1], 1)

    text = once(
        text,
        "float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }\n\n\nvoid main(",
        "float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }\n"
        + SWITCHES
        + "\nvoid main(",
        "insert switches",
    )

    # 1 base color after detail blend
    text = once(
        text,
        "  r3.yzw = r4.www * r3.yzw + r9.xyz;\n"
        "  r5.xyz = float3(12.9200001,12.9200001,12.9200001) * r3.wyz;\n",
        "  r3.yzw = r4.www * r3.yzw + r9.xyz;\n"
        "  float3 dbgBaseColor = r3.yzw;\n"
        "  r5.xyz = float3(12.9200001,12.9200001,12.9200001) * r3.wyz;\n",
        "dbgBaseColor",
    )

    # 2 geometric shading N
    text = once(
        text,
        "  r12.xyz = r11.xyz * r5.yyy;\n"
        "  r13.xy = (uint2)v0.xy;\n",
        "  r12.xyz = r11.xyz * r5.yyy;\n"
        "  float3 dbgShadingN = r12.xyz;\n"
        "  r13.xy = (uint2)v0.xy;\n",
        "dbgShadingN",
    )

    # volume probes
    text = once(
        text,
        "  // ===== 5. Volume probe GI: three 3D cascades, each weights + SH textures =====\n"
        "  r9.y = cmp(featureToggles.y < 0.5);\n"
        "  if (r9.y != 0) {\n",
        "  // ===== 5. Volume probe GI: three 3D cascades, each weights + SH textures =====\n"
        "  r9.y = cmp(featureToggles.y < 0.5);\n"
        "#if !STEP_VOLUME_PROBES\n"
        "  r9.y = 0; // identity: take else (no probe SH)\n"
        "#endif\n"
        "  if (r9.y != 0) {\n",
        "STEP_VOLUME_PROBES",
    )

    # SSS edge tint
    text = once(
        text,
        "  r15.xyz = sssEdgeTintColor.xyz * r9.yyy + r10.xxx;\n"
        "  r17.xyz = r15.xyz * r3.yzw;\n"
        "  r9.y = matParams.y * r10.y;\n",
        "  r15.xyz = sssEdgeTintColor.xyz * r9.yyy + r10.xxx;\n"
        "  r17.xyz = r15.xyz * r3.yzw;\n"
        "  float3 dbgSssTint = r15.xyz;\n"
        "#if !STEP_SSS_EDGE_TINT\n"
        "  // identity: no tint. Do NOT leave r9.y at the peak of the (1-N.V) curve.\n"
        "  r9.y = 0;\n"
        "  r15.xyz = float3(1, 1, 1);\n"
        "  r17.xyz = r3.yzw;\n"
        "#endif\n"
        "  r9.y = matParams.y * r10.y;\n",
        "STEP_SSS_EDGE_TINT",
    )

    # detail path gate
    text = once(
        text,
        "  r11.w = cb1[r2.w+12].x + r10.x;\n"
        "  r11.w = cmp(0.00999999978 < r11.w);\n"
        "  if (r11.w != 0) {\n",
        "  r11.w = cb1[r2.w+12].x + r10.x;\n"
        "  r11.w = cmp(0.00999999978 < r11.w);\n"
        "#if !STEP_DETAIL\n"
        "  r11.w = 0; // identity: else branch (shading N = geometric, coverage 0)\n"
        "#endif\n"
        "  if (r11.w != 0) {\n",
        "STEP_DETAIL",
    )

    # shading N after detail (after else closes)
    text = once(
        text,
        "  } else {\n"
        "    r2.w = -matParams.x + 1;\n"
        "    r18.xyz = r12.xyz;\n"
        "    r10.x = 0;\n"
        "  }\n"
        "\n"
        "  // ===== 8. Metallic split:",
        "  } else {\n"
        "    r2.w = -matParams.x + 1;\n"
        "    r18.xyz = r12.xyz;\n"
        "    r10.x = 0;\n"
        "  }\n"
        "  float3 dbgShadingNDetail = r18.xyz;\n"
        "\n"
        "  // ===== 8. Metallic split:",
        "dbgShadingNDetail",
    )

    # shadow LUT
    text = once(
        text,
        "  r9.xyz = r4.www * r9.xyz + r15.xyz;\n"
        "  r9.xyz = r9.xyz * r11.www;\n"
        "  r4.w = r2.w * r2.w;\n",
        "  r9.xyz = r4.www * r9.xyz + r15.xyz;\n"
        "  r9.xyz = r9.xyz * r11.www;\n"
        "#if !STEP_SHADOW_LUT\n"
        "  r9.xyz = r19.xyz; // identity: no LUT hue, keep metallic-split diffuse\n"
        "#endif\n"
        "  float3 dbgShadowLut = r9.xyz;\n"
        "  r4.w = r2.w * r2.w;\n",
        "STEP_SHADOW_LUT",
    )

    # diffuse ramp
    text = once(
        text,
        "  r26.xyzw = SkinDiffuseRamp.SampleLevel(sampLinear, r24.xy, 0).xyzw;\n"
        "  r12.w = max(r26.x, r26.y);\n"
        "  r12.w = max(r12.w, r26.z);\n"
        "  r14.w = min(r26.x, r26.y);\n"
        "  r14.w = min(r14.w, r26.z);\n"
        "  r12.w = -r14.w + r12.w;\n",
        "  r26.xyzw = SkinDiffuseRamp.SampleLevel(sampLinear, r24.xy, 0).xyzw;\n"
        "  float3 dbgRamp = r26.xyz;\n"
        "  r12.w = max(r26.x, r26.y);\n"
        "  r12.w = max(r12.w, r26.z);\n"
        "  r14.w = min(r26.x, r26.y);\n"
        "  r14.w = min(r14.w, r26.z);\n"
        "  r12.w = -r14.w + r12.w;\n"
        "  float dbgRampChroma = r12.w;\n"
        "#if !STEP_DIFFUSE_RAMP\n"
        "  // identity: no chromatic wrap. Keep r26.w (ramp mask).\n"
        "  r12.w = 0;\n"
        "  r26.xyz = float3(1, 1, 1);\n"
        "#endif\n",
        "STEP_DIFFUSE_RAMP",
    )

    # matcap
    text = once(
        text,
        "  } else {\n"
        "    r8.xyz = float3(0,0,0);\n"
        "  }\n"
        "\n"
        "  // ===== 17. GGX specular for the main light =====\n",
        "  } else {\n"
        "    r8.xyz = float3(0,0,0);\n"
        "  }\n"
        "#if !STEP_MATCAP\n"
        "  r8.xyz = float3(0, 0, 0); // identity: no matcap add\n"
        "#endif\n"
        "\n"
        "  // ===== 17. GGX specular for the main light =====\n",
        "STEP_MATCAP",
    )

    # specular GGX add + lit pre-rim capture
    text = once(
        text,
        "  r20.xyz = r5.www * r3.yzw;\n"
        "  r20.xyz = r20.xyz * r16.xyz;\n"
        "  r7.xyz = r7.xyz * r16.xyz;\n"
        "  r7.xyz = r20.xyz * specParams.www + r7.xyz;\n"
        "  r7.xyz = r7.xyz + r8.xyz;\n"
        "  r7.xyz = r14.xyz * r15.xzw + r7.xyz;\n"
        "  r5.w = dot(r7.xyz, float3(0.212672904,0.715152204,0.0721750036));\n",
        "  r20.xyz = r5.www * r3.yzw;\n"
        "  r20.xyz = r20.xyz * r16.xyz;\n"
        "  r7.xyz = r7.xyz * r16.xyz;\n"
        "#if STEP_SPECULAR\n"
        "  r7.xyz = r20.xyz * specParams.www + r7.xyz;\n"
        "#else\n"
        "  // identity: skip GGX add; ViewShiftedSpecMap + matcap (if on) remain\n"
        "#endif\n"
        "  r7.xyz = r7.xyz + r8.xyz;\n"
        "  r7.xyz = r14.xyz * r15.xzw + r7.xyz;\n"
        "  float3 dbgLitPreRim = r7.xyz;\n"
        "  r5.w = dot(r7.xyz, float3(0.212672904,0.715152204,0.0721750036));\n",
        "STEP_SPECULAR",
    )

    # 1-|N·V| at rim site
    text = once(
        text,
        "  r10.x = dot(r2.xyz, r11.xyz);\n"
        "  r12.w = 1 + -abs(r10.x);\n"
        "  r7.w = -0.899999976 + abs(r7.w);\n",
        "  r10.x = dot(r2.xyz, r11.xyz);\n"
        "  r12.w = 1 + -abs(r10.x);\n"
        "  float dbgOneMinusAbsNdotV = r12.w; // capture at rim site; fog later clobbers regs\n"
        "  r7.w = -0.899999976 + abs(r7.w);\n",
        "dbgOneMinusAbsNdotV",
    )

    # rim combine
    text = once(
        text,
        "  r16.xyz = r16.xyz * r19.xyz;\n"
        "  r8.xyz = r14.xyz * r8.xyz + r16.xyz;\n"
        "  r7.xyz = r8.xyz + r7.xyz;\n"
        "\n"
        "  // ===== 19. Tiled lights:",
        "  r16.xyz = r16.xyz * r19.xyz;\n"
        "  r8.xyz = r14.xyz * r8.xyz + r16.xyz;\n"
        "  float3 dbgRim = r8.xyz;\n"
        "#if STEP_RIM\n"
        "  r7.xyz = r8.xyz + r7.xyz;\n"
        "#else\n"
        "  // identity: rim+extraRim contribution 0 (not peak wrap)\n"
        "#endif\n"
        "\n"
        "  // ===== 19. Tiled lights:",
        "STEP_RIM",
    )

    # local lights wrap
    text = once(
        text,
        "  // ===== 20. Tiled light loop: 8 words x 32 bits =====\n"
        "  while (true) {\n",
        "  // ===== 20. Tiled light loop: 8 words x 32 bits =====\n"
        "#if STEP_LOCAL_LIGHTS\n"
        "  while (true) {\n",
        "STEP_LOCAL_LIGHTS open",
    )
    text = once(
        text,
        "    r17.xyz = r20.xyz;\n"
        "    r10.y = (int)r10.y + 1;\n"
        "  }\n"
        "\n"
        "  // ===== 21. Per-material colour grade",
        "    r17.xyz = r20.xyz;\n"
        "    r10.y = (int)r10.y + 1;\n"
        "  }\n"
        "#else\n"
        "  // identity: r17 already = r7 (no local lights)\n"
        "#endif\n"
        "\n"
        "  // ===== 21. Per-material colour grade",
        "STEP_LOCAL_LIGHTS close",
    )

    # color grade
    text = once(
        text,
        "  // ===== 21. Per-material colour grade + graded rim (gradeParams, gradeRimParams, cb5[7..8]) =====\n"
        "  r0.x = cmp(0.5 < gradeParams.x);\n"
        "  if (r0.x != 0) {\n",
        "  // ===== 21. Per-material colour grade + graded rim (gradeParams, gradeRimParams, cb5[7..8]) =====\n"
        "#if STEP_COLOR_GRADE\n"
        "  r0.x = cmp(0.5 < gradeParams.x);\n"
        "  if (r0.x != 0) {\n",
        "STEP_COLOR_GRADE open",
    )
    text = once(
        text,
        "    r17.xyz = r3.xyz * gradeRimParams.yyy + r0.xyz;\n"
        "  }\n"
        "\n"
        "  // ===== 22. Undo exposure before fog =====\n"
        "  r0.xyz = r17.xyz / exposure.xxx;\n",
        "    r17.xyz = r3.xyz * gradeRimParams.yyy + r0.xyz;\n"
        "  }\n"
        "#endif // STEP_COLOR_GRADE\n"
        "  float3 dbgPreFog = r17.xyz;\n"
        "\n"
        "  // ===== 22. Undo exposure before fog =====\n"
        "  r0.xyz = r17.xyz / exposure.xxx;\n",
        "STEP_COLOR_GRADE close",
    )

    # fog
    text = once(
        text,
        "  // ===== 23. Height fog; fogVolumeParams.z > 0 takes the 3D froxel path =====\n"
        "  r2.w = cmp(blendWeights.w < 0.5);\n"
        "  if (r2.w != 0) {\n",
        "  // ===== 23. Height fog; fogVolumeParams.z > 0 takes the 3D froxel path =====\n"
        "  r2.w = cmp(blendWeights.w < 0.5);\n"
        "#if !STEP_FOG\n"
        "  r2.w = 0; // identity: exposed color only\n"
        "#endif\n"
        "  if (r2.w != 0) {\n",
        "STEP_FOG",
    )

    # debug vis return
    text = once(
        text,
        "  // ===== 24. Output: o0 = colour, o1 = motion vectors + flags =====\n"
        "  o0.xyz = r0.xyz;\n"
        "  o0.w = 1;\n"
        "  o1.z = 1;\n"
        "  return;\n"
        "}",
        "  // ===== 24. Output: o0 = colour, o1 = motion vectors + flags =====\n"
        "  o0.xyz = r0.xyz;\n"
        "  o0.w = 1;\n"
        "  o1.z = 1;\n"
        "\n"
        "#if DEBUG_VIS == 1\n"
        "  o0 = float4(dbgBaseColor, 1);\n"
        "#elif DEBUG_VIS == 2\n"
        "  o0 = float4(dbgShadingN * 0.5 + 0.5, 1);\n"
        "#elif DEBUG_VIS == 3\n"
        "  o0 = float4(dbgShadingNDetail * 0.5 + 0.5, 1);\n"
        "#elif DEBUG_VIS == 4\n"
        "  o0 = float4(dbgSssTint, 1);\n"
        "#elif DEBUG_VIS == 5\n"
        "  o0 = float4(dbgShadowLut, 1);\n"
        "#elif DEBUG_VIS == 6\n"
        "  o0 = float4(dbgRamp, 1);\n"
        "#elif DEBUG_VIS == 7\n"
        "  o0 = float4(dbgRampChroma, dbgRampChroma, dbgRampChroma, 1);\n"
        "#elif DEBUG_VIS == 8\n"
        "  o0 = float4(dbgLitPreRim, 1);\n"
        "#elif DEBUG_VIS == 9\n"
        "  o0 = float4(dbgRim, 1);\n"
        "#elif DEBUG_VIS == 10\n"
        "  o0 = float4(dbgOneMinusAbsNdotV, dbgOneMinusAbsNdotV, dbgOneMinusAbsNdotV, 1);\n"
        "#elif DEBUG_VIS == 11\n"
        "  o0 = float4(dbgPreFog, 1);\n"
        "#endif\n"
        "  return;\n"
        "}\n",
        "DEBUG_VIS",
    )

    DST.write_text(text, encoding="utf-8", newline="\n")
    print(f"[ok] {DST.name}: {text.count(chr(10)) + 1} lines")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
