"""Build Step 5 analysis harness from Apply-OK eye Step 4.

STEP_* default 1 = original. Off = true identity / no contribution.
DEBUG_VIS 0 = final; 1..N captured at the producing site.
"""

from __future__ import annotations

import sys
from pathlib import Path

SHADERS = Path(__file__).resolve().parent.parent / "shaders"
SRC = SHADERS / "zmd_eye_ps_20260924_141546_step4_readable.hlsl"
DST = SHADERS / "zmd_eye_ps_20260924_141546_step5_analysis.hlsl"

HEADER_OLD = (
    "// ZMD eye PS - Step 4: readable bindings, CB aliases and section map\n"
    "// Source: zmd_eye_ps_20260924_141546_step1_renderdoc.hlsl (Apply-verified, event 1129)\n"
)
HEADER_NEW = (
    "// ZMD eye PS - Step 5: STEP_*/DEBUG_VIS analysis harness\n"
    "// Source: zmd_eye_ps_20260924_141546_step4_readable.hlsl (Apply-OK, event 1129)\n"
    "// STEP_* default 1 = original. Off = identity / no contribution.\n"
    "// Rim off must zero the add (do NOT leave a wrap curve peaked).\n"
    "// DEBUG_VIS captures intermediates at the producing site (later fog/lights clobber rN).\n"
)

SWITCHES = """
// ===== Analysis switches =====
#define STEP_IRIS_PARALLAX  1  // 0 -> sample iris at v1.xy (no view offset)
#define STEP_CORNEA_DOME    1  // 0 -> tangent bump = (0,0,1) so shading N = v3
#define STEP_VOLUME_PROBES  1  // 0 -> else-branch identity (no SH probes)
#define STEP_SCREEN_AO      1  // 0 -> AO factor = 1
#define STEP_DIFFUSE_RAMP   1  // 0 -> ramp chroma = 0, keep ramp.a mask
#define STEP_MATCAP         1  // 0 -> matcap add = 0
#define STEP_ADD_HIGHLIGHT  1  // 0 -> iris/sclera additive term = 0
#define STEP_RIM            1  // 0 -> rim add = 0 (do NOT peak the wrap)
#define STEP_LOCAL_LIGHTS   1  // 0 -> skip tiled local-light loop
#define STEP_COLOR_GRADE    1  // 0 -> skip cb5 grade
#define STEP_FOG            1  // 0 -> exposed color only

#define DEBUG_VIS 0
// 0  final
// 1  iris base after tint
// 2  outside-iris circle mask
// 3  shadingNormal *0.5+0.5
// 4  cornea tangent bump *0.5+0.5
// 5  DiffuseRamp rgb
// 6  ramp chroma as grey
// 7  matcap add term
// 8  lit before rim
// 9  rim add term only
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
        "float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }\n\n\nvoid main(",
        "float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }\n"
        + SWITCHES
        + "\nvoid main(",
        "insert switches",
    )

    text = once(
        text,
        "  r4.zw = -r4.zw * r2.zz + v1.xy;\n"
        "  r9.xyzw = IrisBaseColorMap.SampleBias(sampIrisBase, r4.zw, mipBiasFrame.x).xyzw;\n",
        "  r4.zw = -r4.zw * r2.zz + v1.xy;\n"
        "#if !STEP_IRIS_PARALLAX\n"
        "  r4.zw = v1.xy; // identity: no view-dependent iris UV offset\n"
        "#endif\n"
        "  r9.xyzw = IrisBaseColorMap.SampleBias(sampIrisBase, r4.zw, mipBiasFrame.x).xyzw;\n",
        "STEP_IRIS_PARALLAX",
    )

    text = once(
        text,
        "  r10.xyzw = baseColorTint.xyzw * r9.xyzw;\n"
        "  r9.xyz = baseColorGrade.zzz * r10.xyz;\n",
        "  r10.xyzw = baseColorTint.xyzw * r9.xyzw;\n"
        "  float3 dbgIrisBase = r10.xyz;\n"
        "  float dbgIrisMask = r4.x;\n"
        "  r9.xyz = baseColorGrade.zzz * r10.xyz;\n",
        "dbgIrisBase",
    )

    text = once(
        text,
        "  r2.xyz = r4.xxx * r12.xyz + r2.xyz;\n"
        "  r12.xyz = r2.yyy * r8.xyz;\n",
        "  r2.xyz = r4.xxx * r12.xyz + r2.xyz;\n"
        "  float3 dbgCorneaTS = r2.xyz;\n"
        "#if !STEP_CORNEA_DOME\n"
        "  r2.xyz = float3(0, 0, 1); // identity: shading N = geometric v3\n"
        "#endif\n"
        "  r12.xyz = r2.yyy * r8.xyz;\n",
        "STEP_CORNEA_DOME",
    )

    text = once(
        text,
        "  r12.xyz = r5.www * r2.xyz;\n"
        "  r13.xy = (uint2)v0.xy;\n",
        "  r12.xyz = r5.www * r2.xyz;\n"
        "  float3 dbgShadingN = r12.xyz;\n"
        "  r13.xy = (uint2)v0.xy;\n",
        "dbgShadingN",
    )

    text = once(
        text,
        "  // ===== 4. Three-cascade volume probe GI =====\n"
        "  r2.y = cmp(featureToggles.y < 0.5);\n"
        "  if (r2.y != 0) {\n",
        "  // ===== 4. Three-cascade volume probe GI =====\n"
        "  r2.y = cmp(featureToggles.y < 0.5);\n"
        "#if !STEP_VOLUME_PROBES\n"
        "  r2.y = 0; // identity: take else (no probe SH)\n"
        "#endif\n"
        "  if (r2.y != 0) {\n",
        "STEP_VOLUME_PROBES",
    )

    text = once(
        text,
        "  r3.x = featureToggles.z * r3.y + r3.x;\n"
        "  r3.yzw = lightScales.zzz * r9.xyz;\n",
        "  r3.x = featureToggles.z * r3.y + r3.x;\n"
        "#if !STEP_SCREEN_AO\n"
        "  r3.x = 1; // identity: no AO darkening\n"
        "#endif\n"
        "  r3.yzw = lightScales.zzz * r9.xyz;\n",
        "STEP_SCREEN_AO",
    )

    text = once(
        text,
        "  r25.xyzw = DiffuseRamp.SampleLevel(sampLinear, r17.xy, 0).xyzw;\n"
        "  r2.w = max(r25.x, r25.y);\n"
        "  r2.w = max(r2.w, r25.z);\n"
        "  r4.x = min(r25.x, r25.y);\n"
        "  r4.x = min(r4.x, r25.z);\n"
        "  r2.w = -r4.x + r2.w;\n",
        "  r25.xyzw = DiffuseRamp.SampleLevel(sampLinear, r17.xy, 0).xyzw;\n"
        "  float3 dbgRamp = r25.xyz;\n"
        "  r2.w = max(r25.x, r25.y);\n"
        "  r2.w = max(r2.w, r25.z);\n"
        "  r4.x = min(r25.x, r25.y);\n"
        "  r4.x = min(r4.x, r25.z);\n"
        "  r2.w = -r4.x + r2.w;\n"
        "  float dbgRampChroma = r2.w;\n"
        "#if !STEP_DIFFUSE_RAMP\n"
        "  // identity: no chromatic wrap. Keep r25.w (ramp mask).\n"
        "  r2.w = 0;\n"
        "  r25.xyz = float3(1, 1, 1);\n"
        "#endif\n",
        "STEP_DIFFUSE_RAMP",
    )

    text = once(
        text,
        "  r6.xyz = r11.xyz * r6.xyz;\n"
        "  r6.xyz = r8.xyz * r2.www + r6.xyz;\n",
        "  r6.xyz = r11.xyz * r6.xyz;\n"
        "  float3 dbgMatcap = r6.xyz;\n"
        "#if !STEP_MATCAP\n"
        "  r6.xyz = float3(0, 0, 0); // identity: no matcap add\n"
        "#endif\n"
        "  r6.xyz = r8.xyz * r2.www + r6.xyz;\n",
        "STEP_MATCAP",
    )

    text = once(
        text,
        "  r7.w = dot(r0.xyz, r12.xyz);\n"
        "  r8.x = 1 + -r3.x;\n",
        "  r7.w = dot(r0.xyz, r12.xyz);\n"
        "  float dbgOneMinusAbsNdotV = 1.0 - abs(r7.w); // capture at rim site\n"
        "  r8.x = 1 + -r3.x;\n",
        "dbgOneMinusAbsNdotV",
    )

    text = once(
        text,
        "  r11.xyz = max(float3(0.150000006,0.150000006,0.150000006), r15.xyz);\n"
        "  r6.xyz = r8.yzw * r11.xyz + r6.xyz;\n",
        "  r11.xyz = max(float3(0.150000006,0.150000006,0.150000006), r15.xyz);\n"
        "  float3 dbgLitPreRim = r6.xyz;\n"
        "  float3 dbgRim = r8.yzw * r11.xyz;\n"
        "#if STEP_RIM\n"
        "  r6.xyz = r8.yzw * r11.xyz + r6.xyz;\n"
        "#else\n"
        "  // identity: rim contribution 0 (not peak wrap)\n"
        "#endif\n",
        "STEP_RIM",
    )

    text = once(
        text,
        "  r7.xyz = r10.xyz * specGlobalScale.xxx + r7.xyz;\n"
        "  r6.xyz = r7.xyz * r2.www + r6.xyz;\n",
        "  r7.xyz = r10.xyz * specGlobalScale.xxx + r7.xyz;\n"
        "#if !STEP_ADD_HIGHLIGHT\n"
        "  r7.xyz = float3(0, 0, 0); // identity: no iris/sclera additive\n"
        "#endif\n"
        "  r6.xyz = r7.xyz * r2.www + r6.xyz;\n",
        "STEP_ADD_HIGHLIGHT",
    )

    text = once(
        text,
        "  r10.xyz = r6.xyz;\n"
        "  r2.z = 0;\n"
        "  while (true) {\n"
        "    r9.w = cmp(7 < (int)r2.z);\n",
        "  r10.xyz = r6.xyz;\n"
        "  r2.z = 0;\n"
        "#if STEP_LOCAL_LIGHTS\n"
        "  while (true) {\n"
        "    r9.w = cmp(7 < (int)r2.z);\n",
        "STEP_LOCAL_LIGHTS open",
    )
    text = once(
        text,
        "    r10.xyz = r11.yzw;\n"
        "    r2.z = (int)r2.z + 1;\n"
        "  }\n"
        "\n"
        "  // ===== 16. Colour grade (saturation, contrast, tint, rim colour) =====\n",
        "    r10.xyz = r11.yzw;\n"
        "    r2.z = (int)r2.z + 1;\n"
        "  }\n"
        "#else\n"
        "  // identity: r10.xyz already = r6 (no local lights)\n"
        "#endif\n"
        "\n"
        "  // ===== 16. Colour grade (saturation, contrast, tint, rim colour) =====\n",
        "STEP_LOCAL_LIGHTS close",
    )

    text = once(
        text,
        "  // ===== 16. Colour grade (saturation, contrast, tint, rim colour) =====\n"
        "  r2.z = cmp(0.5 < gradeParams.x);\n"
        "  if (r2.z != 0) {\n",
        "  // ===== 16. Colour grade (saturation, contrast, tint, rim colour) =====\n"
        "#if STEP_COLOR_GRADE\n"
        "  r2.z = cmp(0.5 < gradeParams.x);\n"
        "  if (r2.z != 0) {\n",
        "STEP_COLOR_GRADE open",
    )
    text = once(
        text,
        "    r10.xyz = r4.xyz * baseColorGrade.yyy + r3.xyz;\n"
        "  }\n"
        "\n"
        "  // ===== 17. Exposure and alpha output =====\n"
        "  r3.xyz = r10.xyz / exposure.xxx;\n",
        "    r10.xyz = r4.xyz * baseColorGrade.yyy + r3.xyz;\n"
        "  }\n"
        "#endif // STEP_COLOR_GRADE\n"
        "  float3 dbgPreFog = r10.xyz;\n"
        "\n"
        "  // ===== 17. Exposure and alpha output =====\n"
        "  r3.xyz = r10.xyz / exposure.xxx;\n",
        "STEP_COLOR_GRADE close",
    )

    text = once(
        text,
        "  r2.z = cmp(blendWeights.w < 0.5);\n"
        "  if (r2.z != 0) {\n"
        "    r0.w = r1.w * r0.w;\n",
        "  r2.z = cmp(blendWeights.w < 0.5);\n"
        "#if !STEP_FOG\n"
        "  r2.z = 0; // identity: exposed color only\n"
        "#endif\n"
        "  if (r2.z != 0) {\n"
        "    r0.w = r1.w * r0.w;\n",
        "STEP_FOG",
    )

    text = once(
        text,
        "  o1.zw = float2(1,0.400000006);\n"
        "  return;\n"
        "}\n",
        "  o1.zw = float2(1,0.400000006);\n"
        "\n"
        "#if DEBUG_VIS == 1\n"
        "  o0 = float4(dbgIrisBase, 1);\n"
        "#elif DEBUG_VIS == 2\n"
        "  o0 = float4(dbgIrisMask, dbgIrisMask, dbgIrisMask, 1);\n"
        "#elif DEBUG_VIS == 3\n"
        "  o0 = float4(dbgShadingN * 0.5 + 0.5, 1);\n"
        "#elif DEBUG_VIS == 4\n"
        "  o0 = float4(dbgCorneaTS * 0.5 + 0.5, 1);\n"
        "#elif DEBUG_VIS == 5\n"
        "  o0 = float4(dbgRamp, 1);\n"
        "#elif DEBUG_VIS == 6\n"
        "  o0 = float4(dbgRampChroma, dbgRampChroma, dbgRampChroma, 1);\n"
        "#elif DEBUG_VIS == 7\n"
        "  o0 = float4(dbgMatcap, 1);\n"
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
