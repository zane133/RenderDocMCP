"""Build and reversibly verify the Step 4 readable hair shader."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "shaders" / "zmd_hair_ps_20260922_171627_step1_renderdoc.hlsl"
DST = ROOT / "shaders" / "zmd_hair_ps_20260922_171627_step4_readable.hlsl"

TEXTURES = {
    "t18": "VolumetricFog3D",
    "t17": "LightCookieAtlas",
    "t16": "HairNormalMap",
    "t15": "HairParameterMap",
    "t14": "BaseColorMap",
    "t13": "HairSpecularLUT",
    "t12": "DiffuseRamp",
    "t11": "StrandMaskMap",
    "t10": "VolumeCoarseSH",
    "t9": "VolumeCoarseWeights",
    "t8": "VolumeMidSH",
    "t7": "VolumeMidWeights",
    "t6": "VolumeFineSH",
    "t5": "VolumeFineWeights",
    "t4": "ScreenData",
    "t3": "ShadowMap",
    "t2": "SceneDepth",
    "t1": "InstanceDataSB",
    "t0": "LightTileMaskSB",
}

SAMPLERS = {
    "s6_s": "sampHairNormal",
    "s5_s": "sampHairParams",
    "s4_s": "sampBaseAndStrand",
    "s3_s": "sampShadowCmp",
    "s2_s": "sampVolumeWeights",
    "s1_s": "sampLinear",
    "s0_s": "sampSceneDepth",
}

# Alias whole float4 slots so every original swizzle remains unchanged.
ALIASES = [
    ("viewRow0", 0, 0, "world-to-view row"),
    ("viewRow1", 0, 1, "world-to-view row"),
    ("viewRow2", 0, 2, "world-to-view row"),
    ("sunDir", 0, 6, "main light direction"),
    ("cameraPos", 0, 44, "world-space camera position"),
    ("screenUvScale", 0, 82, ".zw converts SV_Position to screen UV"),
    ("depthDecode", 0, 84, ".zw decode SceneDepth"),
    ("tileDepthJitter", 0, 85, "tile depth-slice jitter"),
    ("viewBend", 0, 86, ".w bends view vector toward view axis"),
    ("viewportClamp", 0, 87, "screen-space clamp/scales"),
    ("mipBiasFrame", 0, 108, ".x texture bias, .w frame bits"),
    ("exposure", 0, 109, ".x scene exposure"),
    ("lightListBase", 0, 110, ".y tiled-light list base"),
    ("exposureAlt", 0, 111, "alternate exposure"),
    ("fogStartFade", 0, 153, None),
    ("fogDirParams", 0, 154, None),
    ("fogColorParams", 0, 155, None),
    ("fogHeightA", 0, 156, None),
    ("fogHeightB", 0, 157, None),
    ("fogHeightC", 0, 158, None),
    ("fogLayerA", 0, 159, None),
    ("fogAddParams", 0, 160, None),
    ("fogAmbient", 0, 161, ".w minimum transmittance"),
    ("fogLayerB", 0, 162, None),
    ("fogVolumeParams", 0, 163, ".z enables froxel volume path"),
    ("fogSliceParams", 0, 164, None),
    ("fogJitterScale", 0, 165, None),
    ("fogStartDist", 0, 166, None),
    ("fogJitterAmount", 0, 167, None),
    ("lightScales", 0, 186, ".y GI, .z albedo lighting, .w environment"),
    ("featureToggles", 0, 187, "volume/AO/sun feature blends"),
    ("ambientFallback", 0, 188, "ambient fallback colour"),
    ("mainLightColorOverride", 0, 191, None),
    ("ambientFacingDir", 0, 192, None),
    ("ambientFacingRemap", 0, 193, None),
    ("rimColor", 0, 194, ".xyz colour, .w intensity"),
    ("rimParams", 0, 195, ".yx axis, .z albedo mix, .w width"),
    ("sunDirOffset", 0, 197, None),
    ("blendWeights", 0, 198, "global feature blend weights"),
    ("specGlobalScale", 0, 199, ".w specular scale"),
    ("volumeOrigin", 0, 210, ".w enables cascades"),
    ("volumeGridSize", 0, 211, None),
    ("volumeCascadeDist", 0, 212, ".y fine, .z mid, .w coarse"),
    ("volumeSHAmbientR", 0, 213, None),
    ("volumeSHAmbientG", 0, 214, None),
    ("volumeSHAmbientB", 0, 215, None),
    ("tileGridParams", 2, 1, None),
    ("tileDepthParams", 2, 2, None),
    ("mainLightDirRaw", 3, 0, None),
    ("mainLightColorRaw", 3, 3, None),
    ("screenAoBlend", 4, 34, ".x AO blend"),
    ("shadowTexelSize", 4, 400, ".xy texel size, .zw map size"),
    ("normalAndMaterial", 5, 0, ".w normal strength"),
    ("twoSidedAndOpacity", 5, 1, ".y backface flip, .z alpha source blend"),
    ("alphaMode", 5, 2, ".x selects texture alpha"),
    ("gradeParams", 5, 3, ".x enable, .y exposure, .z saturation, .w contrast"),
    ("baseColorGrade", 5, 4, ".x rim threshold, .y rim gain, .zw colour grade"),
    ("baseColorTint", 5, 5, None),
    ("gradeTintColor", 5, 7, ".w tint blend"),
    ("gradeRimColor", 5, 8, None),
    ("secondaryNormalStrength", 5, 11, ".y secondary normal strength"),
    ("primaryLobe", 5, 12, ".xy tangent shifts, .z strength, .w alignment power"),
    ("strandDirection", 5, 13, ".x secondary power control, .y direction blend"),
    ("secondaryLobeColor", 5, 14, "secondary anisotropic lobe colour"),
    ("secondaryLobe", 5, 15, ".xy tangent shifts, .zw power controls"),
    ("strandMaskControls", 5, 16, ".xy contrast/mix controls"),
    ("strandMaskUv", 5, 17, ".xy scale, .zw offset"),
]

SECTIONS = [
    ("r0.xyz = cb0[44].xyz + -v2.xyz;",
     "1. View vector and per-instance hair basis"),
    ("r8.xyzw = t14.SampleBias",
     "2. Base colour and packed hair parameters"),
    ("r11.xyzw = t16.SampleBias",
     "3. Primary normal map, two-sided normal and tangent frame"),
    ("r11.xy = v1.xy * cb5[17].xy",
     "4. Strand mask / secondary normal layer"),
    ("r7.w = cmp(cb0[187].y < 0.5);",
     "5. Three-cascade volume probe GI"),
    ("r7.w = cb1[r2.w+12].z + -v2.y;",
     "6. Per-instance height fade and material coverage"),
    ("o1.xy = r20.xy * float2(0.5,0.5)",
     "7. Motion-vector output"),
    ("r20.xyz = cb3[0].xyz + cb0[197].xyz;",
     "8. Main light, AO and toon diffuse ramp"),
    ("r29.xyzw = t12.SampleLevel",
     "9. DiffuseRamp lookup and ambient/GI shaping"),
    ("r3.xy = cb5[12].xy * float2(2,2)",
     "10. Hair anisotropic specular: shifted primary and secondary tangent lobes"),
    ("r16.xyz = t13.SampleLevel",
     "11. HairSpecularLUT lookup for the primary lobe"),
    ("r3.xy = (uint2)r17.xy;",
     "12. Tiled-light lookup"),
    ("while (true) {",
     "13. Tiled-light loops, cookies and cubic PCF shadows"),
    ("r0.x = cmp(0.5 < cb5[3].x);",
     "14. Per-material colour grade"),
    ("r0.xyz = r9.xzw / cb0[109].xxx;",
     "15. Undo exposure and apply height/froxel fog"),
    ("o1.zw = float2(1,0.400000006);",
     "16. Final MRT flags"),
]

HEADER = """// ZMD hair PS - Step 4: readable bindings, CB aliases and section map
// Source: zmd_hair_ps_20260922_171627_step1_renderdoc.hlsl (Apply-verified)
//
// This pass changes no shader math. Resource registers, cbuffer packing,
// interpolators, branches and operation order are unchanged. Names are inferred
// from usage; the two shifted-tangent lobes and HairSpecularLUT identify the
// material as an anisotropic hair shader.
//
// Main texture recipe:
//   BaseColorMap(t14) + HairParameterMap(t15) + HairNormalMap(t16)
//   StrandMaskMap(t11) -> DiffuseRamp(t12) -> HairSpecularLUT(t13)
//   -> rim / tiled lights / grade / fog
"""


def rename_resources(text: str) -> str:
    for old, new in TEXTURES.items():
        text = re.sub(rf"\b{old}\b", new, text)
        text = text.replace(f"register({new})", f"register({old})")
    for old, new in SAMPLERS.items():
        text = re.sub(rf"\b{old}\b", new, text)
    return text


def alias_block() -> str:
    lines = [
        "  // Named CB aliases (inferred); original float4 packing is untouched."
    ]
    for name, bank, index, note in ALIASES:
        line = f"  const float4 {name} = cb{bank}[{index}];"
        if note:
            line = f"{line:<57}// {note}"
        lines.append(line)
    return "\n".join(lines)


def apply_aliases(text: str) -> str:
    marker = "  float4 fDest;\n"
    head, body = text.split(marker, 1)
    for name, bank, index, _ in ALIASES:
        slot = rf"cb{bank}\[{index}\]"
        if re.search(slot, body):
            body = re.sub(slot, name, body)
    return head + marker + "\n" + alias_block() + "\n" + body


def add_sections(text: str) -> str:
    lines = text.splitlines()
    used: set[int] = set()
    for needle, title in SECTIONS:
        hits = [i for i, line in enumerate(lines) if needle in line and i not in used]
        if not hits:
            raise RuntimeError(f"section anchor not found: {needle}")
        index = hits[0]
        used.add(index)
        indent = lines[index][: len(lines[index]) - len(lines[index].lstrip())]
        lines.insert(index, f"\n{indent}// ===== {title} =====")
        used = {i + 1 if i >= index else i for i in used}
    return "\n".join(lines) + "\n"


def verify(step1: str, step4: str) -> None:
    restored = step4
    for name, bank, index, _ in ALIASES:
        restored = re.sub(rf"\b{name}\b", f"cb{bank}[{index}]", restored)
    for old, new in TEXTURES.items():
        restored = re.sub(rf"\b{new}\b", old, restored)
    for old, new in SAMPLERS.items():
        restored = re.sub(rf"\b{new}\b", old, restored)

    alias_pattern = re.compile(
        r"\s*const float4 \S+ = cb\d\[\d+\];(?:\s*//.*)?"
    )
    clean = lambda s: [
        line for line in s.splitlines()
        if line.strip()
        and not line.lstrip().startswith("//")
        and not alias_pattern.fullmatch(line)
    ]
    got = clean(restored)
    want = clean(step1)
    if got != want:
        for index, (expected, actual) in enumerate(zip(want, got)):
            if expected != actual:
                raise RuntimeError(
                    f"reversible verification failed at code line {index}:\n"
                    f"step1: {expected}\nstep4: {actual}"
                )
        raise RuntimeError(
            f"reversible verification line count differs: {len(want)} != {len(got)}"
        )


def main() -> None:
    step1 = SRC.read_text(encoding="utf-8")
    text = add_sections(step1)
    text = rename_resources(text)
    text = apply_aliases(text)
    text = HEADER + text[text.find("\n") + 1:]
    verify(step1, text)
    DST.write_text(text, encoding="utf-8", newline="\n")
    print(f"[ok] wrote {DST.name}")
    print("[ok] reversible verification: all non-comment code matches Step 1")


if __name__ == "__main__":
    main()
