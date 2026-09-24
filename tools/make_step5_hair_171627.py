"""Build Step 5 analysis harness from Apply-OK hair Step 4.

STEP_* default 1 = original. Off = true identity / no contribution.
DEBUG_VIS 0 = final; 1..N captured at the producing site.
"""

from __future__ import annotations

import sys
from pathlib import Path

SHADERS = Path(__file__).resolve().parent.parent / "shaders"
SRC = SHADERS / "zmd_hair_ps_20260922_171627_step4_readable.hlsl"
DST = SHADERS / "zmd_hair_ps_20260922_171627_step5_analysis.hlsl"

HEADER_OLD = (
    "// ZMD hair PS - Step 4: readable bindings, CB aliases and section map\n"
    "// Source: zmd_hair_ps_20260922_171627_step1_renderdoc.hlsl (Apply-verified)\n"
)
HEADER_NEW = (
    "// ZMD hair PS - Step 5: STEP_*/DEBUG_VIS analysis harness\n"
    "// Source: zmd_hair_ps_20260922_171627_step4_readable.hlsl (Apply-OK)\n"
    "// STEP_* default 1 = original. Off = identity / no contribution.\n"
    "// Hair spec off must zero the LUT/secondary add (do NOT leave log=0 -> exp2(0)=1).\n"
    "// DEBUG_VIS captures intermediates at the producing site (later fog/lights clobber rN).\n"
)

SWITCHES = """
// ===== Analysis switches =====
#define STEP_VOLUME_PROBES  1  // 0 -> else-branch identity (no SH probes)
#define STEP_HEIGHT_FADE    1  // 0 -> skip instance height coverage (r2.w = 1)
#define STEP_DIFFUSE_RAMP   1  // 0 -> ramp chroma = 0, keep ramp.a mask
#define STEP_HAIR_SPEC      1  // 0 -> zero LUT + secondary lobe; r4.w boost = 1
#define STEP_RIM            1  // 0 -> rim + extra fill factor 0 (do NOT peak wrap)
#define STEP_LOCAL_LIGHTS   1  // 0 -> skip tiled local-light loop
#define STEP_COLOR_GRADE    1  // 0 -> skip cb5 grade
#define STEP_FOG            1  // 0 -> exposed color only

#define DEBUG_VIS 0
// 0  final
// 1  baseColor after tint
// 2  HairParameterMap rgb
// 3  shadingNormal *0.5+0.5
// 4  strand mask (t11)
// 5  DiffuseRamp rgb
// 6  ramp chroma as grey
// 7  hair spec term (LUT + secondary, after specGlobalScale)
// 8  lit before rim
// 9  rim + extra fill term only
// 10 1-|N·V| saved at rim site
// 11 preFog (after lights / grade, before /exposure)

"""


def fail(msg: str) -> None:
    print(f"[error] {msg}", file=sys.stderr)
    raise SystemExit(1)


def once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        fail(f"{label}: expected 1 occurrence, got {n}")
    return text.replace(old, new, 1)


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    if HEADER_OLD not in text:
        fail("unexpected Step 4 header")
    text = text.replace(HEADER_OLD, HEADER_NEW, 1)

    text = once(
        text,
        "float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }\n\n\n\nvoid main(",
        "float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }\n"
        + SWITCHES
        + "\nvoid main(",
        "insert switches",
    )

    text = once(
        text,
        "  r8.xyzw = baseColorTint.xyzw * r8.xyzw;\n"
        "  r10.xyz = baseColorGrade.zzz * r8.xyz;\n",
        "  r8.xyzw = baseColorTint.xyzw * r8.xyzw;\n"
        "  float3 dbgBaseColor = r8.xyz;\n"
        "  r10.xyz = baseColorGrade.zzz * r8.xyz;\n",
        "dbgBaseColor",
    )

    text = once(
        text,
        "  r9.xyzw = HairParameterMap.SampleBias(sampHairParams, v1.xy, mipBiasFrame.x).xyzw;\n"
        "  r8.xyzw = baseColorTint.xyzw * r8.xyzw;\n",
        "  r9.xyzw = HairParameterMap.SampleBias(sampHairParams, v1.xy, mipBiasFrame.x).xyzw;\n"
        "  float3 dbgHairParams = r9.xyz;\n"
        "  r8.xyzw = baseColorTint.xyzw * r8.xyzw;\n",
        "dbgHairParams",
    )

    text = once(
        text,
        "  r6.xyz = r6.xyz * r3.www;\n"
        "  r7.w = dot(v3.xyz, v3.xyz);\n",
        "  r6.xyz = r6.xyz * r3.www;\n"
        "  float3 dbgShadingN = r6.xyz;\n"
        "  r7.w = dot(v3.xyz, v3.xyz);\n",
        "dbgShadingN",
    )

    text = once(
        text,
        "  r4.w = StrandMaskMap.Sample(sampBaseAndStrand, r11.xy).x;\n"
        "  r12.xz = v2.xz + -r6.yx;\n",
        "  r4.w = StrandMaskMap.Sample(sampBaseAndStrand, r11.xy).x;\n"
        "  float dbgStrandMask = r4.w;\n"
        "  r12.xz = v2.xz + -r6.yx;\n",
        "dbgStrandMask",
    )

    text = once(
        text,
        "  // ===== 5. Three-cascade volume probe GI =====\n"
        "  r7.w = cmp(featureToggles.y < 0.5);\n"
        "  if (r7.w != 0) {\n",
        "  // ===== 5. Three-cascade volume probe GI =====\n"
        "  r7.w = cmp(featureToggles.y < 0.5);\n"
        "#if !STEP_VOLUME_PROBES\n"
        "  r7.w = 0; // identity: take else (no probe SH)\n"
        "#endif\n"
        "  if (r7.w != 0) {\n",
        "STEP_VOLUME_PROBES",
    )

    text = once(
        text,
        "  r9.x = cb1[r2.w+12].x + r7.w;\n"
        "  r9.x = cmp(0.00999999978 < r9.x);\n"
        "  if (r9.x != 0) {\n",
        "  r9.x = cb1[r2.w+12].x + r7.w;\n"
        "  r9.x = cmp(0.00999999978 < r9.x);\n"
        "#if !STEP_HEIGHT_FADE\n"
        "  r9.x = 0; // identity: else branch, coverage scale = 1\n"
        "#endif\n"
        "  if (r9.x != 0) {\n",
        "STEP_HEIGHT_FADE",
    )

    text = once(
        text,
        "  r29.xyzw = DiffuseRamp.SampleLevel(sampLinear, r13.zw, 0).xyzw;\n"
        "  r11.w = max(r29.x, r29.y);\n"
        "  r11.w = max(r11.w, r29.z);\n"
        "  r13.z = min(r29.x, r29.y);\n"
        "  r13.z = min(r13.z, r29.z);\n"
        "  r11.w = -r13.z + r11.w;\n",
        "  r29.xyzw = DiffuseRamp.SampleLevel(sampLinear, r13.zw, 0).xyzw;\n"
        "  float3 dbgRamp = r29.xyz;\n"
        "  r11.w = max(r29.x, r29.y);\n"
        "  r11.w = max(r11.w, r29.z);\n"
        "  r13.z = min(r29.x, r29.y);\n"
        "  r13.z = min(r13.z, r29.z);\n"
        "  r11.w = -r13.z + r11.w;\n"
        "  float dbgRampChroma = r11.w;\n"
        "#if !STEP_DIFFUSE_RAMP\n"
        "  // identity: no chromatic wrap. Keep r29.w (ramp mask).\n"
        "  r11.w = 0;\n"
        "  r29.xyz = float3(1, 1, 1);\n"
        "#endif\n",
        "STEP_DIFFUSE_RAMP",
    )

    text = once(
        text,
        "  r4.w = r9.y * r4.w + 1;\n"
        "  r5.xyz = r25.xyz * r19.xyz;\n",
        "  r4.w = r9.y * r4.w + 1;\n"
        "#if !STEP_HAIR_SPEC\n"
        "  r4.w = 1; // identity: no spec-driven albedo contrast\n"
        "#endif\n"
        "  r5.xyz = r25.xyz * r19.xyz;\n",
        "STEP_HAIR_SPEC boost",
    )

    text = once(
        text,
        "  r7.xyz = specGlobalScale.www * r7.xyz;\n"
        "  r5.xyz = r5.xyz * r11.www + r7.xyz;\n",
        "  r7.xyz = specGlobalScale.www * r7.xyz;\n"
        "#if !STEP_HAIR_SPEC\n"
        "  // identity: no LUT / secondary-lobe add. Do NOT leave exp2(0)=1.\n"
        "  r7.xyz = float3(0, 0, 0);\n"
        "#endif\n"
        "  float3 dbgHairSpec = r7.xyz;\n"
        "  r5.xyz = r5.xyz * r11.www + r7.xyz;\n",
        "STEP_HAIR_SPEC add",
    )

    text = once(
        text,
        "  r5.w = dot(r2.xyz, r6.xyz);\n"
        "  r9.w = 1 + -r10.w;\n",
        "  r5.w = dot(r2.xyz, r6.xyz);\n"
        "  float dbgOneMinusAbsNdotV = 1.0 - abs(r5.w); // capture at rim site\n"
        "  r9.w = 1 + -r10.w;\n",
        "dbgOneMinusAbsNdotV",
    )

    text = once(
        text,
        "  r5.xyz = r3.yyy * r5.xyz + r3.xxx;\n"
        "  r3.xy = rimParams.ww * r11.xy;\n",
        "  r5.xyz = r3.yyy * r5.xyz + r3.xxx;\n"
        "  float3 dbgLitPreRim = r5.xyz;\n"
        "  r3.xy = rimParams.ww * r11.xy;\n",
        "dbgLitPreRim",
    )

    text = once(
        text,
        "  r7.xyz = r16.xyz * r7.xyz + r19.xyz;\n"
        "  r5.xyz = r7.xyz + r5.xyz;\n"
        "\n"
        "  // ===== 12. Tiled-light lookup =====\n",
        "  r7.xyz = r16.xyz * r7.xyz + r19.xyz;\n"
        "  float3 dbgRim = r7.xyz;\n"
        "#if STEP_RIM\n"
        "  r5.xyz = r7.xyz + r5.xyz;\n"
        "#else\n"
        "  // identity: rim + extra fill contribution 0 (not peak wrap)\n"
        "#endif\n"
        "\n"
        "  // ===== 12. Tiled-light lookup =====\n",
        "STEP_RIM",
    )

    text = once(
        text,
        "  // ===== 13. Tiled-light loops, cookies and cubic PCF shadows =====\n"
        "  while (true) {\n",
        "  // ===== 13. Tiled-light loops, cookies and cubic PCF shadows =====\n"
        "#if STEP_LOCAL_LIGHTS\n"
        "  while (true) {\n",
        "STEP_LOCAL_LIGHTS open",
    )
    text = once(
        text,
        "    r9.xzw = r19.xyz;\n"
        "    r7.z = (int)r7.z + 1;\n"
        "  }\n"
        "\n"
        "  // ===== 14. Per-material colour grade =====\n",
        "    r9.xzw = r19.xyz;\n"
        "    r7.z = (int)r7.z + 1;\n"
        "  }\n"
        "#else\n"
        "  // identity: r9.xzw already = r5 (no local lights)\n"
        "#endif\n"
        "\n"
        "  // ===== 14. Per-material colour grade =====\n",
        "STEP_LOCAL_LIGHTS close",
    )

    text = once(
        text,
        "  // ===== 14. Per-material colour grade =====\n"
        "  r0.x = cmp(0.5 < gradeParams.x);\n"
        "  if (r0.x != 0) {\n",
        "  // ===== 14. Per-material colour grade =====\n"
        "#if STEP_COLOR_GRADE\n"
        "  r0.x = cmp(0.5 < gradeParams.x);\n"
        "  if (r0.x != 0) {\n",
        "STEP_COLOR_GRADE open",
    )
    text = once(
        text,
        "    r9.xzw = r4.xyz * baseColorGrade.yyy + r0.xyz;\n"
        "  }\n"
        "\n"
        "  // ===== 15. Undo exposure and apply height/froxel fog =====\n"
        "  r0.xyz = r9.xzw / exposure.xxx;\n",
        "    r9.xzw = r4.xyz * baseColorGrade.yyy + r0.xyz;\n"
        "  }\n"
        "#endif // STEP_COLOR_GRADE\n"
        "  float3 dbgPreFog = r9.xzw;\n"
        "\n"
        "  // ===== 15. Undo exposure and apply height/froxel fog =====\n"
        "  r0.xyz = r9.xzw / exposure.xxx;\n",
        "STEP_COLOR_GRADE close",
    )

    text = once(
        text,
        "  r2.w = cmp(blendWeights.w < 0.5);\n"
        "  if (r2.w != 0) {\n"
        "    r0.w = r1.w * r0.w;\n",
        "  r2.w = cmp(blendWeights.w < 0.5);\n"
        "#if !STEP_FOG\n"
        "  r2.w = 0; // identity: exposed color only\n"
        "#endif\n"
        "  if (r2.w != 0) {\n"
        "    r0.w = r1.w * r0.w;\n",
        "STEP_FOG",
    )

    text = once(
        text,
        "  // ===== 16. Final MRT flags =====\n"
        "  o1.zw = float2(1,0.400000006);\n"
        "  return;\n"
        "}\n",
        "  // ===== 16. Final MRT flags =====\n"
        "  o1.zw = float2(1,0.400000006);\n"
        "\n"
        "#if DEBUG_VIS == 1\n"
        "  o0 = float4(dbgBaseColor, 1);\n"
        "#elif DEBUG_VIS == 2\n"
        "  o0 = float4(dbgHairParams, 1);\n"
        "#elif DEBUG_VIS == 3\n"
        "  o0 = float4(dbgShadingN * 0.5 + 0.5, 1);\n"
        "#elif DEBUG_VIS == 4\n"
        "  o0 = float4(dbgStrandMask, dbgStrandMask, dbgStrandMask, 1);\n"
        "#elif DEBUG_VIS == 5\n"
        "  o0 = float4(dbgRamp, 1);\n"
        "#elif DEBUG_VIS == 6\n"
        "  o0 = float4(dbgRampChroma, dbgRampChroma, dbgRampChroma, 1);\n"
        "#elif DEBUG_VIS == 7\n"
        "  o0 = float4(dbgHairSpec, 1);\n"
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
