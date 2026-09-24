"""Step 3-style path removal on top of the Step 5 harness (user-requested).

Removes, and nothing else:
  - the height / volumetric fog block (§23) -> output is the exposed colour
  - the volume probe SH cascades (§5) -> the dump's own else branch (flat ambient)
plus every declaration and CB alias that only those paths used.

All remaining math is untouched, so the file is still register-faithful for the
paths it keeps.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

SHADERS = Path(__file__).resolve().parent.parent / "shaders"
SRC = SHADERS / "zmd_ps_20260922_145935_step5_analysis.hlsl"
DST = SHADERS / "zmd_ps_20260922_145935_step5b_trimmed.hlsl"

DEAD_TEXTURES = [
    "VolumetricFog3D",
    "VolumeCoarse_SH",
    "VolumeCoarse_Weights",
    "VolumeMid_SH",
    "VolumeMid_Weights",
    "VolumeFine_SH",
    "VolumeFine_Weights",
]
DEAD_SAMPLERS = ["sampVolumeWeights"]
DEAD_ALIASES = [
    "volumeOrigin",
    "volumeGridSize",
    "volumeCascadeDist",
    "volumeSHAmbientR",
    "volumeSHAmbientG",
    "volumeSHAmbientB",
    "fogStartFade",
    "fogDirParams",
    "fogColorParams",
    "fogHeightA",
    "fogHeightB",
    "fogHeightC",
    "fogLayerA",
    "fogAddParams",
    "fogAmbient",
    "fogLayerB",
    "fogVolumeParams",
    "fogSliceParams",
    "fogJitterScale",
    "fogStartDist",
    "fogJitterAmount",
]

PROBE_REPLACEMENT = """  // ===== 5. Ambient GI - volume probe cascades REMOVED (user request) =====
  // The dump branched on featureToggles.y < 0.5 into three SH cascades
  // (VolumeFine/Mid/Coarse, t4..t9) and additionally scaled r8.w by the cascade
  // luminance. What stays here is the dump's own else branch, so this is the
  // exact identity for the probe-off case: flat ambient, r8.w untouched.
  r16.xyz = ambientFallback.xyz;
"""

FOG_REPLACEMENT = """  // ===== 23. Height / volumetric fog REMOVED (user request) =====
  // The dump ran this only when blendWeights.w < 0.5; the identity for the
  // skipped case is simply to leave r0.xyz as the de-exposed colour.
"""


def fail(msg: str) -> None:
    print(f"[error] {msg}", file=sys.stderr)
    raise SystemExit(1)


def find(lines: list[str], needle: str, label: str) -> int:
    hits = [i for i, l in enumerate(lines) if needle in l]
    if len(hits) != 1:
        fail(f"{label}: expected 1 match for {needle!r}, got {len(hits)}")
    return hits[0]


def block_end(lines: list[str], open_index: int) -> int:
    """Index of the line closing the brace opened on `open_index`."""
    depth = 0
    for i in range(open_index, len(lines)):
        depth += lines[i].count("{") - lines[i].count("}")
        if i > open_index or "{" in lines[open_index]:
            if depth == 0:
                return i
    fail(f"unbalanced braces from line {open_index}")
    raise AssertionError  # unreachable


def cut_probe(lines: list[str]) -> list[str]:
    start = find(lines, "===== 5. Volume probe GI", "probe section")
    open_i = find(lines, "  if (r9.y != 0) {", "probe if")
    end = block_end(lines, open_i)
    if "  }" not in lines[end]:
        fail(f"probe block end looks wrong: {lines[end]!r}")
    if "ambientFallback" not in "\n".join(lines[open_i:end]):
        fail("probe else branch not found inside the removed block")
    return lines[:start] + PROBE_REPLACEMENT.rstrip("\n").split("\n") + lines[end + 1 :]


def cut_fog(lines: list[str]) -> list[str]:
    start = find(lines, "===== 23. Height fog", "fog section")
    open_i = find(lines, "  if (r2.w != 0) {", "fog if")
    end = block_end(lines, open_i)
    tail = lines[end + 1 :]
    if not any("===== 24. Output" in l for l in tail[:4]):
        fail("fog block end does not land just before the output section")
    return lines[:start] + FOG_REPLACEMENT.rstrip("\n").split("\n") + tail


def drop_declarations(lines: list[str]) -> list[str]:
    dead_decl = re.compile(
        r"^\s*(?:Texture(?:2D|3D)<float4>|SamplerState)\s+(\w+)\s*:\s*register"
    )
    dead_alias = re.compile(r"^\s*const float4 (\w+) = cb\d+\[\d+\];")
    dead_comment = re.compile(
        r"^//\s+t(?:4/t5|6/t7|8/t9|20)\b|^//\s+-- (?:volume probe cascades|height \+ volumetric fog) --"
    )

    out: list[str] = []
    for line in lines:
        m = dead_decl.match(line)
        if m and m.group(1) in (*DEAD_TEXTURES, *DEAD_SAMPLERS):
            continue
        m = dead_alias.match(line)
        if m and m.group(1) in DEAD_ALIASES:
            continue
        if dead_comment.match(line):
            continue
        if line.strip() in ("// -- volume probe cascades --", "// -- height + volumetric fog --"):
            continue
        if re.match(r"^\s*//\s*-- (?:volume probe cascades|height \+ volumetric fog) --", line):
            continue
        if "#define STEP_VOLUME_PROBES" in line or "#define STEP_FOG" in line:
            continue
        out.append(line)
    return out


def collapse_blank_runs(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        if not line.strip() and out and not out[-1].strip():
            continue
        out.append(line)
    return out


def main() -> int:
    lines = SRC.read_text(encoding="utf-8").split("\n")
    lines = cut_fog(cut_probe(lines))
    lines = drop_declarations(lines)
    lines = collapse_blank_runs(lines)
    text = "\n".join(lines)

    text = text.replace(
        "// ZMD / Endfield PS - Step 5: STEP_*/DEBUG_VIS analysis harness",
        "// ZMD / Endfield PS - Step 5b: analysis harness, fog + volume probes removed",
        1,
    )
    text = text.replace(
        "// DEBUG_VIS: 0 = final o0;",
        "// Removed at user request: height/volumetric fog (t20) and the volume probe\n"
        "// SH cascades (t4..t9, sampler s1). Both were replaced by the dump's own\n"
        "// identity branch, so the rest of the shader is unchanged.\n"
        "// DEBUG_VIS: 0 = final o0;",
        1,
    )
    text = text.replace("// 11 preFog (after lights / grade, before /exposure)",
                        "// 11 graded colour (after lights / grade, before /exposure)", 1)
    text = text.replace("dbgPreFog", "dbgGraded")
    text = text.replace(
        "// (later fog / lights reuse the same rN — do not read them at the return).",
        "// (later lights reuse the same rN — do not read them at the return).",
        1,
    )
    text = text.replace(
        "// user. This pass changes NO math: every edit is a rename or a comment.",
        "// user. Apart from the two removed paths below, this file changes NO math.",
        1,
    )
    text = text.replace(
        "  // ===== 22. Undo exposure before fog =====",
        "  // ===== 22. Undo exposure (the dump divided it out here, ahead of fog) =====",
        1,
    )

    for name in (*DEAD_TEXTURES, *DEAD_SAMPLERS, *DEAD_ALIASES):
        if re.search(rf"\b{name}\b", text):
            fail(f"{name} still referenced after removal")
    for switch in ("STEP_VOLUME_PROBES", "STEP_FOG"):
        if switch in text:
            fail(f"{switch} still referenced")

    DST.write_text(text, encoding="utf-8", newline="\n")
    print(f"[ok] {DST.name}: {text.count(chr(10)) + 1} lines")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
