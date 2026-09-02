"""Reproject exported meshes of one draw and compare to what it painted in-game.

Rasterises the exported OBJ triangles through the fitted view-projection matrix
and diffs the silhouette against a mask captured from the render target, so we
can tell whether the export is missing instances or just looks different.

Usage:
    py -3 verify_draw_coverage.py <mesh_dir> <eid> <mask.png> [out.png]

The mask is a PNG where painted pixels are pure magenta (255, 0, 200), as
produced by diffing two render-target snapshots.
"""

import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

RT_W, RT_H = 1232, 696
MAGENTA = (255, 0, 200)


def load_matrix(mesh_dir):
    with open(os.path.join(mesh_dir, "manifest.json")) as f:
        man = json.load(f)
    fit = man["viewproj_fit"]
    return man, fit["matrix"], man.get("unit_scale", 1.0)


def read_obj(path):
    verts, faces = [], []
    with open(path) as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(v) for v in line.split()[1:4]])
            elif line.startswith("f "):
                idx = [int(t.split("/")[0]) - 1 for t in line.split()[1:]]
                for k in range(1, len(idx) - 1):
                    faces.append((idx[0], idx[k], idx[k + 1]))
    return np.array(verts, dtype=float), faces


def project(verts, m, scale):
    # Exported positions are world * scale with no axis flips.
    w = verts / scale
    ones = np.ones((len(w), 1))
    h = np.hstack([w, ones])
    cx = h @ np.array(m[0])
    cy = h @ np.array(m[1])
    cw = h @ np.array(m[3])
    ok = np.abs(cw) > 1e-9
    px = np.full(len(w), np.nan)
    py = np.full(len(w), np.nan)
    px[ok] = (cx[ok] / cw[ok] * 0.5 + 0.5) * RT_W
    py[ok] = (0.5 - cy[ok] / cw[ok] * 0.5) * RT_H
    return px, py


def main(argv):
    mesh_dir, eid, mask_path = argv[1], int(argv[2]), argv[3]
    out_path = argv[4] if len(argv) > 4 else None

    man, m, scale = load_matrix(mesh_dir)
    files = sorted(glob.glob(os.path.join(mesh_dir, "eid_%d_i*.obj" % eid)))
    print("mesh_dir=%s\neid=%d  exported instances=%d  unit_scale=%s"
          % (mesh_dir, eid, len(files), scale))

    img = Image.new("1", (RT_W, RT_H), 0)
    draw = ImageDraw.Draw(img)
    tris = 0
    for path in files:
        verts, faces = read_obj(path)
        if not len(verts):
            continue
        px, py = project(verts, m, scale)
        for a, b, c in faces:
            if np.isnan(px[[a, b, c]]).any():
                continue
            draw.polygon([(px[a], py[a]), (px[b], py[b]), (px[c], py[c])], fill=1)
            tris += 1
    mine = np.asarray(img, dtype=bool)

    ref_rgb = np.asarray(Image.open(mask_path).convert("RGB"))
    ref = np.all(ref_rgb == np.array(MAGENTA), axis=2)

    inter = mine & ref
    print("rasterised triangles: %d" % tris)
    print("in-game painted pixels : %d" % ref.sum())
    print("reprojected mesh pixels: %d" % mine.sum())
    print("covered of in-game     : %.1f%%" % (100.0 * inter.sum() / max(1, ref.sum())))

    # Where is the shortfall? Split the frame into 8 columns.
    print("\n%-10s %-10s %-10s %s" % ("column", "in-game", "exported", "covered"))
    for i, (r, mn) in enumerate(zip(np.array_split(ref, 8, axis=1),
                                    np.array_split(mine, 8, axis=1))):
        cov = 100.0 * (r & mn).sum() / max(1, r.sum())
        print("%-10d %-10d %-10d %.1f%%" % (i, r.sum(), mn.sum(), cov))

    if out_path:
        vis = np.zeros((RT_H, RT_W, 3), dtype=np.uint8)
        vis[ref] = [80, 0, 60]        # painted in-game, not exported
        vis[mine] = [0, 200, 90]      # exported
        vis[inter] = [230, 230, 230]  # both
        Image.fromarray(vis).save(out_path)
        print("\nwrote %s (white=match, dark purple=missing, green=extra)" % out_path)


if __name__ == "__main__":
    main(sys.argv)
