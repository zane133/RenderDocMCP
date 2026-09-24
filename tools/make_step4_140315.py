"""Build the Step 4 readable file for the 2026-09-22 14:03:15 dump.

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
SRC = SHADERS / "zmd_ps_20260922_140315_step1_renderdoc.hlsl"
DST = SHADERS / "zmd_ps_20260922_140315_step4_readable.hlsl"

TEXTURES = {
    "t16": "VolumetricFog3D",
    "t15": "LightCookieAtlas",
    "t14": "NormalMap",
    "t13": "BaseColorMap",
    "t12": "SkinSpecMatcap",
    "t11": "ShadowColorLUT",
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
    "s5_s": "sampNormal",
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
    ("timeParams", 0, 102, ".x drives stroke-noise animation phase"),
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
    ("strandUvScale", 0, 196, ".z stroke-field UV scale"),
    ("sunDirOffset", 0, 197, "added to cb3[0] before normalising"),
    ("blendWeights", 0, 198, "per-feature lerp weights"),
    ("specParams", 0, 199, ".w matcap specular weight"),
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
    ("matParams", 5, 0, ".x smoothness .y specular .z metallic .w normal strength"),
    ("matTwoSided", 5, 1, ".y backface normal flip"),
    ("gradeParams", 5, 3, ".x enable .y exposure .z sat .w contrast"),
    ("gradeRimParams", 5, 4, ".x NdotV width .y strength"),
    ("baseColorTint", 5, 5, None),
    ("gradeTintColor", 5, 7, ".w tint blend"),
    ("gradeRimColor", 5, 8, None),
    ("sssEdgeTintAmount", 5, 11, "strength of the 1-N.V skin edge tint"),
    ("sssEdgeTintColor", 5, 12, "skin edge tint colour, multiplies base colour"),
]

# (unique substring of the anchor line, occurrence index, comment lines)
SECTIONS = [
    ("r0.xyz = cb0[44].xyz + -v2.xyz;", 0,
     ["===== 1. View vector: worldPos -> camera, bent toward the view axis ====="]),
    ("r2.w = (uint)v9.x << 4;", 0,
     ["===== 2. Per-instance record: TEXCOORD8 -> cb1 offset (16 float4 stride) =====",
      "cb1[+4].w bit 4 selects an InstanceDataSB indirection for the pivot."]),
    ("r4.xyzw = t13.SampleBias(s4_s, v1.xy, cb0[108].x).xyzw;", 0,
     ["===== 3. Base colour, then linear->sRGB encode into ShadowColorLUT coords =====",
      "The LUT is a 32-slice colour cube in a 2D atlas, addressed by the skin base",
      "colour itself: r5.xyz = sRGB(baseColor.zxy), r6.x/.w = atlas UV, r3.w = slice."]),
    ("r5.yzw = t14.SampleBias(s5_s, v1.xy, cb0[108].x).xyw;", 0,
     ["===== 4. Normal map: .xy rescaled by matParams.w, Z reconstructed ====="]),
    ("r8.xyz = v4.yzx * v3.zxy;", 0,
     ["===== 5. TBN -> world normal (r8), two-sided flip (r3.x), geometric N (r9) ====="]),
    ("r6.y = cmp(cb0[187].y < 0.5);", 0,
     ["===== 6. Volume probe GI: three 3D cascades, each weights + SH textures ====="]),
    ("r13.xyw = t4.SampleLevel(s1_s, r12.xyz, 0).yzx;", 0,
     ["--- 6a. Fine cascade (x2 grid): weights t4, SH bands t5 ---"]),
    ("r16.xyw = t6.SampleLevel(s1_s, r14.xyz, 0).yzx;", 0,
     ["--- 6b. Mid cascade (x0.5 grid): weights t6, SH bands t7 ---"]),
    ("r18.xyw = t8.SampleLevel(s1_s, r14.xyz, 0).yzx;", 0,
     ["--- 6c. Coarse cascade (x0.125 grid): weights t8, SH bands t9 ---"]),
    ("r16.xyzw = cb0[213].xyzw * r14.yyyx;", 0,
     ["--- 6d. Add the constant SH ambient (cb0[213..215] = R/G/B bands) ---"]),
    ("r17.xyz = float3(0.715200007,0.715200007,0.715200007) * r12.xyz;", 0,
     ["--- 6e. Dominant GI direction from the luminance-weighted SH ---"]),
    ("r6.y = cmp(r16.y >= r16.z);", 0,
     ["--- 6f. RGB -> hue/sat/val sort, rebuild a saturation-boosted GI colour ---"]),
    ("r7.w = dot(r8.xyz, r2.xyz);", 0,
     ["===== 7. Skin edge tint: (1 - N.V) curve tints base colour toward",
      "sssEdgeTintColor. This is the cheap fake-SSS reddening at grazing angles."]),
    ("r9.w = cb1[r2.w+12].z + -v2.y;", 0,
     ["===== 8. Splat mask: instance height gradient vs cb1[+12] =====",
      "cb1[+12]: .x constant amount, .y gradient amount, .z height, .w floor."]),
    ("r15.xyzw = float4(1,-1,1,1) * v8.xyxz;", 0,
     ["===== 9. Procedural splat field (inferred: fuzz / stubble strands) =====",
      "Triplanar (weights from v7^10), two frequencies (30 and 45.3456), each with",
      "3 planes of a hash-cell splat: hash 123.34/456.21 + 114.514, cell jitter,",
      "1.25/0.75 elongation, smoothstep falloff, animated by timeParams.x.",
      "Output r15.xy = flow direction, r2.w = coverage mask."]),
    ("r15.zw = float2(1,0) * r8.zy;", 0,
     ["===== 10. Bend the shading normal along the splat flow (r5.yzw) =====",
      "The mask also pushes roughness up by 0.1 and pulls specular toward 1."]),
    ("r9.w = -cb5[0].z * 0.959999979 + 0.959999979;", 0,
     ["===== 11. Metallic split: r4 = F0 (diffuse->spec), r3.x = 0.04 * specular ====="]),
    ("r12.xyz = t11.SampleLevel(s3_s, r6.xz, 0).xyz;", 0,
     ["===== 12. ShadowColorLUT: two adjacent slices blended by r3.x =====",
      "r6.xzw becomes the shadowed / subsurface colour for this base colour."]),
    ("r3.w = max(9.99999994e-09, v5.z);", 0,
     ["===== 13. Motion vectors (v5 curr / v6 prev) -> o1.xy, o1.w = stroke flag ====="]),
    ("r12.xzw = cb3[0].xyz + cb0[197].xyz;", 0,
     ["===== 14. Main light direction and colour (cb3 blended by blendWeights) ====="]),
    ("r21.xy = t3.Load(r10.xyz).xy;", 0,
     ["===== 15. Screen data at this pixel: .x AO (blended by screenAoBlend), .y mask ====="]),
    ("r23.xyzw = t10.SampleLevel(s0_s, r23.xy, 0).xyzw;", 0,
     ["===== 16. Toon skin diffuse ramp: U = N.L remapped to 0..1, V = 0.5 =====",
      "r11.w = max(rgb) - min(rgb) of the ramp, i.e. how saturated the ramp is",
      "here. It later drives how strongly the ramp colour tints the lit result,",
      "which is what produces the red terminator band on skin."]),
    ("r13.x = r3.y * 0.350000024 + 0.649999976;", 0,
     ["===== 17. Ambient/GI intensity shaping, then combine ramp + shadow colour ====="]),
    ("r18.xyz = cb0[1].xyz * r5.zzz;", 0,
     ["===== 18. Skin matcap highlight: view-space normal -> SkinSpecMatcap.w ====="]),
    ("r2.w = cmp(r13.z != r13.w);", 0,
     ["===== 19. GGX specular for the main light (r13.z = D denominator) ====="]),
    ("r18.xz = cb0[195].yx;", 0,
     ["===== 20. Toon rim: axis from rimAxisParams x sunDir, width from .w =====",
      "Masked by the splat coverage and the screen AO so fuzz does not double-rim."]),
    ("r2.w = max(r16.x, r16.y);", 0,
     ["===== 21. Main light colour shaping (normalise, AO, facing, horizon fade) ====="]),
    ("r3.yw = (uint2)r10.xy;", 0,
     ["===== 22. Tiled lights: pixel -> 32x32 tile, depth slice -> mask buffer offset ====="]),
    ("while (true) {", 0,
     ["===== 23. Tiled light loop: 8 words x 32 bits ====="]),
    ("while (true) {", 1,
     ["--- 23a. Iterate set bits; cb3[light*8 + k + 6] is the light record ---"]),
    ("r16.w = (uint)cb3[r18.y+6].w;", 0,
     ["--- 23b. Type 1 = box/OBB bounds: f16x2 packed matrix -> edge fade ---"]),
    ("r14.z = cmp(cb3[r14.y+6].w < 1.5);", 0,
     ["--- 23c. Light dispatch: .w selects punctual / tube / capsule / special ---"]),
    ("r16.w = t15.SampleLevel(s0_s, r19.zw, 0).x;", 0,
     ["--- 23d. Light cookie: 2D projection or cube-face unwrap -> atlas ---"]),
    ("r19.xzw = -cb3[r18.x+6].xyz + v2.xyz;", 0,
     ["--- 23e. Shadow: 9-tap cubic PCF against ShadowMap ---"]),
    ("r0.x = cmp(0.5 < cb5[3].x);", 0,
     ["===== 24. Per-material colour grade + graded rim (cb5[3], cb5[4], cb5[7..8]) ====="]),
    ("r0.xyz = r16.xyz / cb0[109].xxx;", 0,
     ["===== 25. Undo exposure before fog ====="]),
    ("r2.w = cmp(cb0[198].w < 0.5);", 0,
     ["===== 26. Height fog; fogVolumeParams.z > 0 takes the 3D froxel path ====="]),
    ("o0.xyz = r0.xyz;", 0,
     ["===== 27. Output: o0 = colour, o1 = motion vectors + flags ====="]),
]

HEADER = """// ZMD / Endfield PS - Step 4: readable resource names, CB aliases, section map
// Source dump: 3Dmigoto 2026-09-22 14:03:15
//
// Draw identified by the user as TOON SKIN. The recipe reads as:
//   base colour -> ShadowColorLUT gives the shadowed / subsurface colour
//   SkinDiffuseRamp turns N.L into the toon band; the ramp's own saturation
//   drives the red terminator; SkinSpecMatcap adds the view-space highlight;
//   a fresnel term tints grazing angles (fake SSS) and a rim closes it out.
// Names below marked (inferred) are read off usage, not off a symbol table.
// Step 1 (zmd_ps_20260922_140315_step1_renderdoc.hlsl) was Apply-verified by the
// user. This pass changes NO math: every edit is a rename or a comment.
//   - Texture / SamplerState symbols renamed, register(tN/sN) untouched
//   - `const float4 <name> = cbN[i];` aliases so existing swizzles still apply
//   - section comments in main
// Interpolators v0..v10 are deliberately NOT copied into locals - doing that in
// the previous shader silently dropped the rim term.
//
// Known faithfulness risks inherited from the dump (NOT changed here, flag if a
// draw ever looks wrong):
//   1. LightTileMaskSB is declared `float val[1]` by 3Dmigoto but holds uint
//      bitmasks; `(int)mask` reinterprets rather than bit-casts.
//   2. In the cube-face cookie unwrap, `(uint)r20.w` converts cmp()'s -1.0 to 0
//      instead of 0xFFFFFFFF. DXBC meant `asuint((int)r20.w)`.
//
// Interpolators:
//   v0  SV_Position          v1  base UV (.xy)
//   v2  world position       v3  tangent (.xyz)
//   v4  bitangent (.xyz, .w handedness)
//   v5  current-frame clip pos   v6  previous-frame clip pos
//   v7  triplanar blend basis    v8  splat-field object position
//   v9  instance index (nointerpolation)
//   v10 SV_IsFrontFace
//
// Bindings:
//   t0  LightTileMaskSB      per-tile light bitmasks (8 words per tile)
//   t1  InstanceDataSB       per-instance floats (pivot at val[3])
//   t2  ShadowMap            SampleCmpLevelZero
//   t3  ScreenData           Load at pixel: .x AO, .y mask
//   t4/t5   VolumeFine_Weights / VolumeFine_SH
//   t6/t7   VolumeMid_Weights / VolumeMid_SH
//   t8/t9   VolumeCoarse_Weights / VolumeCoarse_SH
//   t10 SkinDiffuseRamp      toon N.L ramp, V = 0.5 (red terminator)
//   t11 ShadowColorLUT       32-slice colour cube in a 2D atlas, keyed by
//                            base colour -> shadowed / subsurface colour
//   t12 SkinSpecMatcap       .w = view-space-normal highlight (inferred)
//   t13 BaseColorMap
//   t14 NormalMap            .xyw
//   t15 LightCookieAtlas
//   t16 VolumetricFog3D
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
    # method calls and structured-buffer indexing
    text = re.sub(r"\b(t\d+)\.(Sample|Load)", lambda m: f"{TEXTURES[m.group(1)]}.{m.group(2)}", text)
    text = re.sub(r"\b(t[01])\[", lambda m: f"{TEXTURES[m.group(1)]}[", text)
    for old, new in SAMPLERS.items():
        text = text.replace(old, new)

    leftovers = re.findall(r"\bt\d+(?=\.(?:Sample|Load)|\[)", text)
    if leftovers:
        fail(f"un-renamed texture references remain: {sorted(set(leftovers))}")
    return text


def build_alias_block() -> str:
    out = ["  // CB aliases (inferred). float4 cbN[] packing is untouched, so every",
           "  // existing swizzle below still reads the exact same components."]
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
