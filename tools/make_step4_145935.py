"""Build the Step 4 readable file for the 2026-09-22 14:59:35 dump.

Every transform here is value-preserving text substitution:
  - resource symbol renames (registers untouched)
  - `const float4 name = cbN[i];` aliases, so all existing swizzles still apply
  - section comments
No operation, operand order or literal is changed.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

SHADERS = Path(__file__).resolve().parent.parent / "shaders"
SRC = SHADERS / "zmd_ps_20260922_145935_step1_renderdoc.hlsl"
DST = SHADERS / "zmd_ps_20260922_145935_step4_readable.hlsl"

# Binding map inferred from usage vs the 14:03:15 skin PS (slots shifted).
TEXTURES = {
    "t20": "VolumetricFog3D",
    "t19": "LightCookieAtlas",
    "t18": "MaskMap",             # .xyzw packed masks: wrap / N-bend / edge / rim
    "t17": "FaceSdfMap",          # SDF face shadow: UV mirrored by sun facing, .z = threshold
    "t16": "BaseColorMap",
    "t15": "SkinSpecMatcap",      # .z detail mask at UV; .w view-space matcap (inferred)
    "t14": "NormalMap",           # animated UV detail/stroke normal
    "t13": "ShadowColorLUT",
    "t12": "DetailColorAtlas",    # half-res atlas tile from matDetail.z (inferred)
    "t11": "ViewShiftedSpecMap",  # view·TBN * matSpecUvScale + UV (inferred)
    "t10": "SkinDiffuseRamp",
    "t9": "VolumeCoarse_SH",
    "t8": "VolumeCoarse_Weights",
    "t7": "VolumeMid_SH",
    "t6": "VolumeMid_Weights",
    "t5": "VolumeFine_SH",
    "t4": "VolumeFine_Weights",
    "t3": "ScreenData",
    "t2": "ShadowMap",
    "t1": "InstanceDataSB",
    "t0": "LightTileMaskSB",
}

SAMPLERS = {
    "s0_s": "sampLinear",
    "s1_s": "sampVolumeWeights",
    "s2_s": "sampShadowCmp",
    "s3_s": "sampShadowLUT",
    "s4_s": "sampBaseColor",
    "s5_s": "sampFaceSdf",
    "s6_s": "sampMask",
}

# (alias, cbuffer, index, trailing comment)
CB_ALIASES = [
    ("-- view / camera --", None, None, None),
    ("viewRow0", 0, 0, "world->view matrix rows; .z column = view axis"),
    ("viewRow1", 0, 1, None),
    ("viewRow2", 0, 2, None),
    ("sunDir", 0, 6, "main light direction"),
    ("cameraPos", 0, 44, None),
    ("taaPrevJitter", 0, 85, "used with cb2[2].w for tile depth slice"),
    ("viewBend", 0, 86, ".w lerps view vector toward the view axis"),
    ("timeParams", 0, 102, ".x drives NormalMap UV animation phase"),
    ("mipBiasParams", 0, 108, ".x SampleBias, .w frame counter bits"),
    ("exposure", 0, 109, ".x exposure (divided out again before fog)"),
    ("lightListBase", 0, 110, ".y base index into the tile mask buffer"),
    ("exposureAlt", 0, 111, "blended against exposure by blendWeights.w"),
    ("-- GI / ambient / rim scales --", None, None, None),
    ("lightScales", 0, 186, ".y giScale .z albedoLitScale .w envIblScale"),
    ("featureToggles", 0, 187, ".y<0.5 volume probe, .z AO blend, .w sun blend"),
    ("ambientFallback", 0, 189, "flat ambient when probe path is off"),
    ("skyColor", 0, 190, None),
    ("ambientFacingDir", 0, 192, "horizontal direction dotted against N (inferred)"),
    ("ambientFacingRemap", 0, 193, ".x bias .y scale .z offset"),
    ("rimColor", 0, 194, "toon rim: .xyz colour .w intensity"),
    ("rimAxisParams", 0, 195, ".yx axis vs sunDir, .z albedoMix, .w width"),
    ("sunDirOffset", 0, 197, "added to cb3[0] before normalising"),
    ("blendWeights", 0, 198, "per-feature lerp weights"),
    ("specParams", 0, 199, ".w GGX/spec weight into ViewShiftedSpecMap"),
    ("extraRimColor", 0, 200, "secondary rim/fill colour * mask (inferred)"),
    ("rampSoftness", 0, 201, ".z softens the toon ramp threshold (inferred)"),
    ("-- volume probe cascades --", None, None, None),
    ("volumeOrigin", 0, 210, ".w != 0 enables the cascades"),
    ("volumeGridSize", 0, 211, None),
    ("volumeCascadeDist", 0, 212, ".y fine .z mid .w coarse fade distance"),
    ("volumeSHAmbientR", 0, 213, "constant SH added to each cascade"),
    ("volumeSHAmbientG", 0, 214, None),
    ("volumeSHAmbientB", 0, 215, None),
    ("-- height + volumetric fog --", None, None, None),
    ("fogStartFade", 0, 153, None),
    ("fogDirParams", 0, 154, ".xyz fog direction, .w distance scale"),
    ("fogColorParams", 0, 155, ".xyz extinction colour, .w phase g"),
    ("fogHeightA", 0, 156, None),
    ("fogHeightB", 0, 157, None),
    ("fogHeightC", 0, 158, None),
    ("fogLayerA", 0, 159, None),
    ("fogAddParams", 0, 160, None),
    ("fogAmbient", 0, 161, ".w minimum transmittance"),
    ("fogLayerB", 0, 162, None),
    ("fogVolumeParams", 0, 163, ".z > 0 selects the 3D froxel path"),
    ("fogSliceParams", 0, 164, "depth -> froxel slice curve"),
    ("fogJitterScale", 0, 165, None),
    ("fogStartDist", 0, 166, None),
    ("fogJitterAmount", 0, 167, None),
    ("-- tiles / shadows / material --", None, None, None),
    ("tileGridParams", 2, 1, None),
    ("tileDepthParams", 2, 2, None),
    ("mainLightDirRaw", 3, 0, "before sunDirOffset / normalise"),
    ("mainLightColor", 3, 3, ".w intensity"),
    ("screenAoBlend", 4, 34, ".x blends ScreenData.x toward 1"),
    ("shadowTexelSize", 4, 400, ".xy texel size, .zw map size"),
    ("matParams", 5, 0, ".x smoothness .y specular .z metallic .w unused here"),
    ("matTwoSided", 5, 1, ".y backface normal flip"),
    ("gradeParams", 5, 3, ".x enable .y exposure .z sat .w contrast"),
    ("gradeRimParams", 5, 4, ".x NdotV width .y strength"),
    ("baseColorTint", 5, 5, None),
    ("gradeTintColor", 5, 7, ".w tint blend"),
    ("gradeRimColor", 5, 8, None),
    ("matDetail", 5, 11, ".xy edge-tint range, .z atlas tile, .w detail blend"),
    ("sssEdgeTintColor", 5, 12, "skin edge tint colour, multiplies base colour"),
    ("matSpecUvScale", 5, 16, ".xy scales view·TBN offset into ViewShiftedSpecMap"),
]

# (unique substring of the anchor line, occurrence index, comment lines)
SECTIONS = [
    ("r0.xyz = cb0[44].xyz + -v2.xyz;", 0,
     ["===== 1. View vector: worldPos -> camera, bent toward the view axis ====="]),
    ("r2.w = (uint)v9.x << 4;", 0,
     ["===== 2. Per-instance record: TEXCOORD8 -> cb1 offset (16 float4 stride) =====",
      "cb1[+4].w bit 4 selects an InstanceDataSB indirection for the pivot."]),
    ("r3.xyzw = t16.SampleBias(s4_s, v1.xy, cb0[108].x).wxyz;", 0,
     ["===== 3. Base colour + DetailColorAtlas blend, then sRGB -> ShadowColorLUT UV =====",
      "Detail tile from matDetail.z (half-res atlas); blend = matDetail.w * atlas.a.",
      "r5.xyz = sRGB(base.zxy), r9.xzw = atlas UV / slice for ShadowColorLUT."]),
    ("r10.xyzw = t18.SampleBias(s6_s, v1.xy, cb0[108].x).xyzw;", 0,
     ["===== 4. MaskMap + geometric / two-sided normal, sun in local frame =====",
      ".y bends shading N toward the radial vector; .x/.z later scale wrap / edge."]),
    ("r9.y = cmp(cb0[187].y < 0.5);", 0,
     ["===== 5. Volume probe GI: three 3D cascades, each weights + SH textures ====="]),
    ("r16.xyw = t4.SampleLevel(s1_s, r15.xyz, 0).yzx;", 0,
     ["--- 5a. Fine cascade (x2 grid): weights t4, SH bands t5 ---"]),
    ("r20.xyw = t6.SampleLevel(s1_s, r17.xyz, 0).yzx;", 0,
     ["--- 5b. Mid cascade (x0.5 grid): weights t6, SH bands t7 ---"]),
    ("r22.xyw = t8.SampleLevel(s1_s, r21.xyz, 0).yzx;", 0,
     ["--- 5c. Coarse cascade (x0.125 grid): weights t8, SH bands t9 ---"]),
    ("r17.xyzw = cb0[213].xyzw * r15.yyyx;", 0,
     ["--- 5d. Add the constant SH ambient (cb0[213..215] = R/G/B bands) ---"]),
    ("r20.xyz = float3(0.715200007,0.715200007,0.715200007) * r17.xyz;", 0,
     ["--- 5e. Dominant GI direction from the luminance-weighted SH ---"]),
    ("r9.y = cmp(r19.x >= r19.y);", 0,
     ["--- 5f. RGB -> hue/sat/val sort, rebuild a saturation-boosted GI colour ---"]),
    ("r9.y = saturate(dot(r12.xyz, r2.xyz));", 0,
     ["===== 6. Skin edge tint: (1 - N.V) curve tints base toward sssEdgeTintColor =====",
      "Strength remapped by matDetail.xy and SkinParamsMap.z."]),
    ("r10.x = cb1[r2.w+12].z + -v2.y;", 0,
     ["===== 7. Detail/stroke path (instance height gate vs cb1[+12]) =====",
      "Animated NormalMap + SkinSpecMatcap.z mask; builds shading N (r18) and",
      "coverage (r10.x). Falls back to geometric N when the gate is off."]),
    ("r11.w = -cb5[0].z * 0.959999979 + 0.959999979;", 0,
     ["===== 8. Metallic split: diffuse albedo vs F0 (0.04 * specular) ====="]),
    ("r15.xyz = t13.SampleLevel(s3_s, r9.xz, 0).xyz;", 0,
     ["===== 9. ShadowColorLUT: two adjacent slices blended by fractional slice =====",
      "Output r9 = shadowed / subsurface colour for this base colour."]),
    ("r5.x = max(9.99999994e-09, v5.z);", 0,
     ["===== 10. Motion vectors (v5 curr / v6 prev) -> o1.xy, o1.w = stroke flag ====="]),
    ("r15.xzw = cb3[0].xyz + cb0[197].xyz;", 0,
     ["===== 11. Main light direction and colour (cb3 blended by blendWeights) ====="]),
    ("r22.xy = t3.Load(r13.xyz).xy;", 0,
     ["===== 12. Screen data at this pixel: .x AO (blended by screenAoBlend), .y mask ====="]),
    ("r25.xyzw = t17.SampleLevel(s5_s, r25.xy, 0).xyzw;", 0,
     ["===== 13. Face SDF shadow map: U mirrored by sun facing =====",
      "SDF threshold (.z) is remapped against the light yaw to give the hard,",
      "stable anime face shadow; the result also bends the shading normal."]),
    ("r26.xyzw = t10.SampleLevel(s0_s, r24.xy, 0).xyzw;", 0,
     ["===== 14. Toon skin diffuse ramp: U = N.L remapped, V = 0.5 =====",
      "Ramp chroma later tints the lit result (red terminator on skin)."]),
    ("r16.x = r8.w * 0.350000024 + 0.649999976;", 0,
     ["===== 15. Ambient/GI intensity shaping, then combine ramp + shadow colour ====="]),
    ("r7.xy = r7.xy * cb5[16].xy + v1.xy;", 0,
     ["===== 16. ViewShiftedSpecMap + optional SkinSpecMatcap.w highlight ====="]),
    ("r5.w = cmp(r12.w != r14.w);", 0,
     ["===== 17. GGX specular for the main light ====="]),
    ("r14.xz = cb0[195].yx;", 0,
     ["===== 18. Toon rim + extraRimColor fill (cb0[194]/cb0[200]) ====="]),
    ("r8.xy = (uint2)r13.xy;", 0,
     ["===== 19. Tiled lights: pixel -> 32x32 tile, depth slice -> mask buffer offset ====="]),
    ("while (true) {", 0,
     ["===== 20. Tiled light loop: 8 words x 32 bits ====="]),
    ("while (true) {", 1,
     ["--- 20a. Iterate set bits; cb3[light*8 + k + 6] is the light record ---"]),
    ("r18.w = (uint)cb3[r21.y+6].w;", 0,
     ["--- 20b. Type 1 = box/OBB bounds: f16x2 packed matrix -> edge fade ---"]),
    ("r16.z = cmp(cb3[r16.y+6].w < 1.5);", 0,
     ["--- 20c. Light dispatch: .w selects punctual / tube / capsule / special ---"]),
    ("r18.w = t19.SampleLevel(s0_s, r22.zw, 0).x;", 0,
     ["--- 20d. Light cookie: 2D projection or cube-face unwrap -> atlas ---"]),
    ("r21.xyz = -cb3[r21.x+6].xyz + v2.xyz;", 0,
     ["--- 20e. Shadow: 9-tap cubic PCF against ShadowMap ---"]),
    ("r0.x = cmp(0.5 < cb5[3].x);", 0,
     ["===== 21. Per-material colour grade + graded rim (cb5[3], cb5[4], cb5[7..8]) ====="]),
    ("r0.xyz = r17.xyz / cb0[109].xxx;", 0,
     ["===== 22. Undo exposure before fog ====="]),
    ("r2.w = cmp(cb0[198].w < 0.5);", 0,
     ["===== 23. Height fog; fogVolumeParams.z > 0 takes the 3D froxel path ====="]),
    ("o0.xyz = r0.xyz;", 0,
     ["===== 24. Output: o0 = colour, o1 = motion vectors + flags ====="]),
]

HEADER = """// ZMD / Endfield PS - Step 4: readable resource names, CB aliases, section map
// Source dump: 3Dmigoto 2026-09-22 14:59:35
//
// Same toon-skin family as 14:03:15, but bindings shifted and detail is texture-
// driven (DetailColorAtlas + animated NormalMap) instead of the procedural splat.
// Recipe (inferred):
//   BaseColorMap (+ DetailColorAtlas) -> ShadowColorLUT (shadowed / SSS colour)
//   SkinDiffuseRamp = toon N.L band; FaceSdfMap drives the hard face shadow
//   ViewShiftedSpecMap + SkinSpecMatcap.w = specular / matcap; rim closes it out
// Names marked (inferred) are read off usage, not a symbol table.
// Step 1 (zmd_ps_20260922_145935_step1_renderdoc.hlsl) was Apply-verified by the
// user. This pass changes NO math: every edit is a rename or a comment.
//   - Texture / SamplerState symbols renamed, register(tN/sN) untouched
//   - `const float4 <name> = cbN[i];` aliases so existing swizzles still apply
//   - section comments in main
// Interpolators v0..v10 are deliberately NOT copied into locals.
//
// Known faithfulness risks inherited from the dump (NOT changed here):
//   1. LightTileMaskSB is declared `float val[1]` by 3Dmigoto but holds uint
//      bitmasks; `(int)mask` reinterprets rather than bit-casts.
//   2. Cube-face cookie unwrap may use `(uint)cmpResult` numeric convert.
//
// Interpolators:
//   v0  SV_Position          v1  base UV (.xy)
//   v2  world position       v3  geometric normal / tangent basis (.xyz)
//   v4  bitangent (.xyz, .w handedness)
//   v5  current-frame clip pos   v6  previous-frame clip pos
//   v7  (present; unused in this dump body)
//   v8  (present; unused in this dump body)
//   v9  instance index (nointerpolation)
//   v10 SV_IsFrontFace
//
// Bindings:
//   t0  LightTileMaskSB      per-tile light bitmasks (8 words per tile)
//   t1  InstanceDataSB       per-instance floats
//   t2  ShadowMap            SampleCmpLevelZero
//   t3  ScreenData           Load at pixel: .x AO, .y mask
//   t4/t5   VolumeFine_Weights / VolumeFine_SH
//   t6/t7   VolumeMid_Weights / VolumeMid_SH
//   t8/t9   VolumeCoarse_Weights / VolumeCoarse_SH
//   t10 SkinDiffuseRamp      toon N.L ramp, V = 0.5
//   t11 ViewShiftedSpecMap   view·TBN offset into UV (inferred)
//   t12 DetailColorAtlas     half-res colour tile (inferred)
//   t13 ShadowColorLUT       32-slice colour cube atlas
//   t14 NormalMap            animated detail/stroke normal
//   t15 SkinSpecMatcap       .z mask @ UV, .w matcap @ view N (inferred)
//   t16 BaseColorMap
//   t17 FaceSdfMap           SDF face shadow, U mirrored by sun facing
//   t18 MaskMap              packed masks: wrap / N-bend / edge / rim
//   t19 LightCookieAtlas
//   t20 VolumetricFog3D
"""


def fail(msg: str) -> None:
    print(f"[error] {msg}", file=sys.stderr)
    raise SystemExit(1)


def insert_sections(lines: list[str]) -> list[str]:
    targets: dict[int, list[str]] = {}
    for needle, occurrence, comment in SECTIONS:
        hits = [i for i, line in enumerate(lines) if needle in line]
        if len(hits) <= occurrence:
            fail(f"anchor not found (occurrence {occurrence}): {needle!r}")
        index = hits[occurrence]
        if index in targets:
            fail(f"two sections anchored on the same line: {needle!r}")
        targets[index] = comment

    out: list[str] = []
    for i, line in enumerate(lines):
        if i in targets:
            indent = line[: len(line) - len(line.lstrip())]
            if out and out[-1].strip():
                out.append("")
            out.extend(f"{indent}// {c}" for c in targets[i])
        out.append(line)
    return out


def rename_resources(text: str) -> str:
    def texture_decl(match: re.Match[str]) -> str:
        return f"{match.group(1)} {TEXTURES[match.group(2)]} : register"

    text = re.sub(r"(Texture(?:2D|3D)<float4>) (t\d+) : register", texture_decl, text)
    text = text.replace("StructuredBuffer<t1_t> t1 :", "StructuredBuffer<t1_t> InstanceDataSB :")
    text = text.replace("StructuredBuffer<t0_t> t0 :", "StructuredBuffer<t0_t> LightTileMaskSB :")
    text = re.sub(
        r"\b(t\d+)\.(Sample|Load)",
        lambda m: f"{TEXTURES[m.group(1)]}.{m.group(2)}",
        text,
    )
    text = re.sub(r"\b(t[01])\[", lambda m: f"{TEXTURES[m.group(1)]}[", text)
    for old, new in SAMPLERS.items():
        text = text.replace(old, new)

    leftovers = re.findall(r"\bt\d+(?=\.(?:Sample|Load)|\[)", text)
    if leftovers:
        fail(f"un-renamed texture references remain: {sorted(set(leftovers))}")
    return text


def build_alias_block() -> str:
    out = [
        "  // CB aliases (inferred). float4 cbN[] packing is untouched, so every",
        "  // existing swizzle below still reads the exact same components.",
    ]
    for name, bank, index, note in CB_ALIASES:
        if bank is None:
            out.append(f"  // {name}")
            continue
        decl = f"  const float4 {name} = cb{bank}[{index}];"
        out.append(f"{decl:<52}// {note}" if note else decl)
    return "\n".join(out)


def apply_cb_aliases(head: str, body: str) -> tuple[str, str]:
    for name, bank, index, _ in CB_ALIASES:
        if bank is None:
            continue
        pattern = rf"cb{bank}\[{index}\]"
        if not re.search(pattern, body):
            fail(f"alias {name} matches nothing: cb{bank}[{index}]")
        body = re.sub(pattern, name, body)
    return head, body


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    text = "\n".join(insert_sections(text.split("\n")))
    text = rename_resources(text)

    marker = "  float4 fDest;\n"
    if text.count(marker) != 1:
        fail("could not locate the end of the register declarations")
    head, body = text.split(marker, 1)
    head, body = apply_cb_aliases(head, body)

    text = head + marker + "\n" + build_alias_block() + "\n" + body
    text = HEADER + text.split("\n", 1)[1]

    DST.write_text(text, encoding="utf-8", newline="\n")
    print(f"[ok] {DST.name}: {text.count(chr(10)) + 1} lines")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
