"""Generate the eye PS Step 4 readable file from the Apply-verified Step 1 file.

Only identifiers and comments change: resource/sampler names, named cbuffer
aliases and section headers. Every operation, operand order, swizzle and branch
is copied verbatim from Step 1.
"""
import re
import sys
from pathlib import Path

SRC = Path("shaders/zmd_eye_ps_20260924_141546_step1_renderdoc.hlsl")
DST = Path("shaders/zmd_eye_ps_20260924_141546_step4_readable.hlsl")

HEADER = """// ZMD eye PS - Step 4: readable bindings, CB aliases and section map
// Source: zmd_eye_ps_20260924_141546_step1_renderdoc.hlsl (Apply-verified, event 1129)
//
// This pass changes no shader math. Resource registers, cbuffer packing,
// interpolators, branches and operation order are unchanged. Names are inferred
// from usage; the UV-circle cornea dome, view-dependent iris UV offset and the
// normal-projected matcap identify the material as an eye shader.
//
// Main texture recipe:
//   IrisBaseColorMap(t11) with parallax UV -> DiffuseRamp(t10)
//   -> volume probe GI(t4..t9) -> ScreenAOMap(t3) -> EyeHighlightMatcap(t12)
//   -> tiled lights(t0/t2/t13) -> grade -> exposure -> fog(t14)
"""

RESOURCES = [
    ("t14", "VolumetricFog3D"),
    ("t13", "LightCookieAtlas"),
    ("t12", "EyeHighlightMatcap"),
    ("t11", "IrisBaseColorMap"),
    ("t10", "DiffuseRamp"),
    ("t9", "VolumeCoarseSH"),
    ("t8", "VolumeCoarseWeights"),
    ("t7", "VolumeMidSH"),
    ("t6", "VolumeMidWeights"),
    ("t5", "VolumeFineSH"),
    ("t4", "VolumeFineWeights"),
    ("t3", "ScreenAOMap"),
    ("t2", "ShadowMap"),
    ("t1", "InstanceDataSB"),
    ("t0", "LightTileMaskSB"),
]

SAMPLERS = [
    ("s4_s", "sampMatcap"),
    ("s3_s", "sampIrisBase"),
    ("s2_s", "sampShadowCmp"),
    ("s1_s", "sampVolumeWeights"),
    ("s0_s", "sampLinear"),
]

# (cbuffer, index, alias, trailing comment)
CB_ALIASES = [
    ("cb0", 0, "viewRow0", "world-to-view row"),
    ("cb0", 1, "viewRow1", "world-to-view row"),
    ("cb0", 2, "viewRow2", "world-to-view row"),
    ("cb0", 6, "sunDir", "main light direction"),
    ("cb0", 44, "cameraPos", "world-space camera position"),
    ("cb0", 85, "tileDepthJitter", "tile depth-slice jitter"),
    ("cb0", 86, "viewBend", ".w bends view vector toward the view axis"),
    ("cb0", 108, "mipBiasFrame", ".x texture bias, .w frame bits"),
    ("cb0", 109, "exposure", ".x scene exposure"),
    ("cb0", 110, "lightListBase", ".y tiled-light list base"),
    ("cb0", 111, "exposureAlt", "alternate exposure"),
    ("cb0", 153, "fogStartFade", None),
    ("cb0", 154, "fogDirParams", None),
    ("cb0", 155, "fogColorParams", None),
    ("cb0", 156, "fogHeightA", None),
    ("cb0", 157, "fogHeightB", None),
    ("cb0", 158, "fogHeightC", None),
    ("cb0", 159, "fogLayerA", None),
    ("cb0", 160, "fogAddParams", None),
    ("cb0", 161, "fogAmbient", ".w minimum transmittance"),
    ("cb0", 162, "fogLayerB", None),
    ("cb0", 163, "fogVolumeParams", ".z enables the froxel volume path"),
    ("cb0", 164, "fogSliceParams", None),
    ("cb0", 165, "fogJitterScale", None),
    ("cb0", 166, "fogStartDist", None),
    ("cb0", 167, "fogJitterAmount", None),
    ("cb0", 186, "lightScales", ".y GI, .z albedo lighting, .w environment"),
    ("cb0", 187, "featureToggles", ".x rim/GI gain blend, .y volume+AO, .z screen AO"),
    ("cb0", 188, "ambientFallback", "ambient fallback colour"),
    ("cb0", 191, "mainLightColorOverride", None),
    ("cb0", 192, "ambientFacingDir", None),
    ("cb0", 193, "ambientFacingRemap", None),
    ("cb0", 197, "sunDirOffset", ".w ramp UV bias"),
    ("cb0", 198, "blendWeights", "global feature blend weights"),
    ("cb0", 199, "specGlobalScale", "additive highlight scales"),
    ("cb0", 210, "volumeOrigin", ".w enables cascades"),
    ("cb0", 211, "volumeGridSize", None),
    ("cb0", 212, "volumeCascadeDist", ".y fine, .z mid, .w coarse"),
    ("cb0", 213, "volumeSHAmbientR", None),
    ("cb0", 214, "volumeSHAmbientG", None),
    ("cb0", 215, "volumeSHAmbientB", None),
    ("cb2", 1, "tileGridParams", None),
    ("cb2", 2, "tileDepthParams", None),
    ("cb3", 0, "mainLightDirRaw", None),
    ("cb3", 3, "mainLightColorRaw", None),
    ("cb4", 34, "screenAoBlend", ".x AO blend"),
    ("cb4", 400, "shadowTexelSize", ".xy texel size, .zw map size"),
    ("cb5", 0, "materialParams", ".z dims the graded base colour (0.96 scale)"),
    ("cb5", 1, "twoSidedAndOpacity", ".y backface normal flip, .z alpha source blend"),
    ("cb5", 2, "alphaMode", ".x selects texture alpha"),
    ("cb5", 3, "gradeParams", ".x enable, .y exposure, .z saturation, .w contrast"),
    ("cb5", 4, "baseColorGrade", ".x rim threshold, .y rim gain, .z scale, .w saturation"),
    ("cb5", 5, "baseColorTint", ".xyzw iris tint, .w also attenuates the highlight"),
    ("cb5", 7, "gradeTintColor", ".w tint blend"),
    ("cb5", 8, "gradeRimColor", None),
    ("cb5", 11, "irisParallaxDepth", ".y view-dependent iris UV offset depth"),
    ("cb5", 14, "irisAlphaTintColor", "highlight tint gated by base-map alpha"),
    ("cb5", 15, "scleraTintColor", "highlight tint gated by the outside-iris mask"),
    ("cb5", 16, "corneaBulgeStrength", ".y dome normal strength built from the UV circle"),
    ("cb5", 17, "matcapTint", ".xyz tint by matcap alpha, .w matcap rgb weight"),
]

# Anchor line -> section header inserted above it.
SECTIONS = [
    ("  r0.xyz = cameraPos.xyz + -v2.xyz;",
     "1. View vector and per-instance basis"),
    ("  r2.xy = frac(v1.xy);",
     "2. Iris UV circle, view-dependent parallax offset and base colour"),
    ("  r2.xy = r2.xy * float2(2,2) + float2(-1,-1);",
     "3. Cornea dome normal from the UV circle and the shading normal"),
    ("  r2.y = cmp(featureToggles.y < 0.5);",
     "4. Three-cascade volume probe GI"),
    ("    r19.xyzw = volumeSHAmbientR.xyzw * r17.yyyx;",
     "5. Ambient SH evaluation, GI luminance and hue ramp"),
    ("  r2.z = -materialParams.z * 0.959999979 + 0.959999979;",
     "6. Base colour grade (dim, saturation)"),
    ("  r5.w = max(9.99999994e-09, v5.z);",
     "7. Motion vectors -> o1.xy"),
    ("  r17.xyz = mainLightDirRaw.xyz + sunDirOffset.xyz;",
     "8. Main light direction and colour, tangent-space light vector"),
    ("  r13.z = 0;",
     "9. Screen-space AO lookup"),
    ("  r2.w = dot(r17.xyz, r17.xyz);",
     "10. Diffuse ramp lookup (N.L -> ramp UV)"),
    ("  r6.w = min(1, r25.w);",
     "11. Ambient / GI composite and albedo lighting"),
    ("  r6.xyz = r11.yyy * r8.xyz;",
     "12. Matcap eye highlight (view-space normal projection)"),
    ("  r2.x = max(r19.x, r19.y);",
     "13. Rim / facing term"),
    ("  r8.yzw = specGlobalScale.zzz * r23.xyz;",
     "14. Additive highlight terms"),
    ("  r2.xy = (uint2)r13.xy;",
     "15. Tiled light loop (8 slices x 32 lights, shadow + cookie)"),
    ("  r2.z = cmp(0.5 < gradeParams.x);",
     "16. Colour grade (saturation, contrast, tint, rim colour)"),
    ("  r3.xyz = r10.xyz / exposure.xxx;",
     "17. Exposure and alpha output"),
    ("  r2.z = cmp(blendWeights.w < 0.5);",
     "18. Height fog and froxel volumetric fog"),
]


def replace_word(text, old, new):
    # register(tN) / register(sN) must keep the original slot name.
    return re.sub(r"(?<![0-9A-Za-z_])" + re.escape(old) + r"(?![0-9A-Za-z_])(?!\))", new, text)


def main():
    text = SRC.read_text(encoding="utf-8")

    # Drop the Step 1 header block; keep the 3Dmigoto provenance line.
    lines = text.split("\n")
    while lines and lines[0].startswith("// Step 1") or lines[0].startswith("// Patches:") \
            or lines[0].startswith("// Source:"):
        lines.pop(0)
    text = "\n".join(lines)

    for reg, name in RESOURCES:
        text = replace_word(text, reg, name)
    for reg, name in SAMPLERS:
        text = replace_word(text, reg, name)

    for cb, idx, alias, _ in CB_ALIASES:
        pattern = r"%s\[%d\](?=\.)" % (cb, idx)
        text = re.sub(pattern, alias, text)

    # Alias declarations, injected after the dump's scratch declarations.
    decl_anchor = "  float4 fDest;\n"
    if text.count(decl_anchor) != 1:
        sys.exit("fDest anchor not unique")
    decls = ["", "  // Named CB aliases (inferred); original float4 packing is untouched."]
    for cb, idx, alias, note in CB_ALIASES:
        line = "  const float4 %s = %s[%d];" % (alias, cb, idx)
        if note:
            line = "%-58s// %s" % (line, note)
        decls.append(line)
    text = text.replace(decl_anchor, decl_anchor + "\n".join(decls) + "\n", 1)

    for anchor, title in SECTIONS:
        if text.count(anchor + "\n") != 1:
            sys.exit("section anchor not unique: %r" % anchor)
        indent = " " * (len(anchor) - len(anchor.lstrip()))
        header = "\n%s// ===== %s =====\n" % (indent, title)
        text = text.replace(anchor + "\n", header + anchor + "\n", 1)

    DST.write_text(HEADER + text, encoding="utf-8")
    print("wrote", DST, len(text.split("\n")), "lines")


if __name__ == "__main__":
    main()
