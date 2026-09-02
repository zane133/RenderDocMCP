"""Turn saved per-draw textures into material records inside a mesh manifest.

RenderDoc only tells us which textures a draw sampled, not what each one means,
so roles are inferred from format and channel statistics:

  albedo  colour-ish texture (BC1/BC3/BC7/RGBA8), largest area, not normal-like
  alpha   the albedo's own alpha when it is actually cut, else a single-channel
          mask whose red channel has real contrast (foliage cards)
  normal  only when the texture looks tangent-space (R,G around 128), because
          wiring the wrong map is worse than wiring none

Usage:
    py -3 attach_materials.py <mesh_dir>
"""

import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

# A mask that is almost entirely opaque or entirely empty is not a cutout.
CUT_MIN, CUT_MAX = 0.02, 0.98


def texture_stats(path):
    a = np.asarray(Image.open(path).convert("RGBA"))
    flat = a.reshape(-1, 4)
    mean = flat.mean(axis=0)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    return {
        "mean": [float(v) for v in mean],
        "alpha_cut_frac": float((al < 128).mean()),
        "alpha_min": int(al.min()),
        "red_cut_frac": float((r < 128).mean()),
        "single_channel": bool(g.mean() < 1.0 and b.mean() < 1.0 and r.mean() > 1.0),
        # Tangent-space maps sit around (128, 128, high); BC5 drops blue to 0.
        "normal_like": bool(
            abs(mean[0] - 128) < 28
            and abs(mean[1] - 128) < 28
            and (mean[2] >= 100 or mean[2] < 1)
        ),
    }


def classify(recs, stats):
    usable = []
    for r in recs:
        if "file" not in r:
            continue
        fmt = r["format"].upper()
        if "UINT" in fmt or "SINT" in fmt:
            continue
        s = stats[r["file"]]
        if s["mean"][0] < 1 and s["mean"][1] < 1 and s["mean"][2] < 1:
            continue  # unwritten / page-table texture
        usable.append((r, s))
    if not usable:
        return None

    usable.sort(key=lambda rs: (-(rs[0]["width"] * rs[0]["height"]), rs[0]["slot"]))

    albedo = None
    for r, s in usable:
        if s["single_channel"] or s["normal_like"]:
            continue
        albedo = (r, s)
        break
    if albedo is None:
        albedo = usable[0]

    mat = {"albedo": albedo[0]["file"], "albedo_format": albedo[0]["format"]}

    a_stats = albedo[1]
    if CUT_MIN <= a_stats["alpha_cut_frac"] <= CUT_MAX:
        mat["alpha"] = albedo[0]["file"]
        mat["alpha_from"] = "albedo_alpha"
    else:
        for r, s in usable:
            if r["file"] == albedo[0]["file"] or not s["single_channel"]:
                continue
            if CUT_MIN <= s["red_cut_frac"] <= CUT_MAX:
                mat["alpha"] = r["file"]
                mat["alpha_from"] = "mask_red"
                break

    for r, s in usable:
        if r["file"] == albedo[0]["file"] or s["single_channel"]:
            continue
        if s["normal_like"]:
            mat["normal"] = r["file"]
            mat["normal_kind"] = "bc5" if "BC5" in r["format"].upper() else "rgb"
            break
    return mat


def main(argv):
    mesh_dir = os.path.abspath(argv[1])
    man_path = os.path.join(mesh_dir, "manifest.json")
    with open(man_path) as f:
        manifest = json.load(f)
    with open(os.path.join(mesh_dir, "draw_textures.json")) as f:
        draw_tex = json.load(f)

    stats, missing = {}, 0
    for recs in draw_tex.values():
        for r in recs:
            if "file" not in r or r["file"] in stats:
                continue
            path = os.path.join(mesh_dir, r["file"].replace("/", os.sep))
            if not os.path.isfile(path):
                missing += 1
                continue
            stats[r["file"]] = texture_stats(path)
    print("analysed %d textures (%d missing)" % (len(stats), missing))

    materials = {}
    for eid, recs in draw_tex.items():
        recs = [r for r in recs if r.get("file") in stats]
        mat = classify(recs, stats)
        if mat:
            materials[eid] = mat

    cut = sum(1 for m in materials.values() if "alpha" in m)
    nrm = sum(1 for m in materials.values() if "normal" in m)
    print("materials: %d  (with alpha cutout: %d, with normal: %d)"
          % (len(materials), cut, nrm))

    manifest["materials"] = materials
    tagged = 0
    for m in manifest["meshes"]:
        mat = materials.get(str(m["event_id"]))
        if not mat:
            continue
        m["albedo"] = mat["albedo"]
        m["alpha"] = mat.get("alpha")
        m["normal"] = mat.get("normal")
        m["material"] = "mat_eid_%d" % m["event_id"]
        tagged += 1
    print("tagged %d/%d meshes" % (tagged, len(manifest["meshes"])))

    backup = man_path + ".nomat"
    if not os.path.isfile(backup):
        shutil.copy2(man_path, backup)
    with open(man_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print("updated %s" % man_path)

    for eid in ("5446", "5437", "4925"):
        if eid in materials:
            print("  eid %s -> %s" % (eid, json.dumps(materials[eid])))


if __name__ == "__main__":
    main(sys.argv)
