# -*- coding: utf-8 -*-
"""Save the pixel-shader textures for every draw listed in an existing manifest.

Runs inside the RenderDoc UI:
    qrenderdoc.exe <capture.rdc> --ui-python export_draw_textures.py

Environment:
    RD_TEX_MESH_DIR  mesh directory containing manifest.json (required)
    RD_TEX_MAX_DIM   downsample via mip so the longest side fits (default 2048)

Writes <mesh_dir>/draw_textures.json mapping event id -> saved texture records,
so materials can be rebuilt later without re-exporting geometry.
"""
from __future__ import print_function

import json
import math
import os
import sys
import time
import traceback

MESH_DIR = os.environ.get(
    "RD_TEX_MESH_DIR",
    r"F:\13_MCP_AI\RenderDocMCP\exports\got_frame2925_meshes",
)
MAX_DIM = int(os.environ.get("RD_TEX_MAX_DIM", "2048"))
SCRIPT_DIR = r"F:\13_MCP_AI\RenderDocMCP\scripts"
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

STATUS = os.path.join(MESH_DIR, "_textures_status.txt")
JSON_OUT = os.path.join(MESH_DIR, "draw_textures.json")


def write_status(text):
    with open(STATUS, "w") as f:
        f.write(text)


def is_useful(info):
    """Skip tiny LUTs, ramps and float scratch buffers."""
    w, h = info["width"], info["height"]
    if w < 32 or h < 32:
        return False
    fmt = info["format"].upper()
    for bad in ("R32G32B32A32", "R32_FLOAT", "D32", "D24", "R16G16B16A16_FLOAT"):
        if bad in fmt:
            return False
    return True


def main():
    import export_scene_meshes as exp

    rd = exp.rd
    exp.TEX_FORMAT = "png"  # keep the alpha channel: foliage is alpha-cut
    exp.TEX_MAX_DIM = MAX_DIM

    with open(os.path.join(MESH_DIR, "manifest.json")) as f:
        manifest = json.load(f)
    eids = sorted(set(m["event_id"] for m in manifest["meshes"]))
    write_status("waiting for capture; %d draws to process" % len(eids))

    for _ in range(600):
        if pyrenderdoc.IsCaptureLoaded():
            break
        time.sleep(0.5)

    out = {}
    cache = {}

    def cb(controller):
        for n, eid in enumerate(eids):
            recs = []
            try:
                controller.SetFrameEvent(eid, True)
                for info in exp.list_ps_textures(controller):
                    if not is_useful(info):
                        continue
                    info = dict(info)
                    info["slice"] = info.get("first_slice", 0)
                    rel = exp.save_texture_file(controller, info, MESH_DIR, cache)
                    if not rel:
                        continue
                    mip = 0
                    longest = max(info["width"], info["height"])
                    if MAX_DIM > 0 and longest > MAX_DIM:
                        mip = int(math.ceil(math.log(float(longest) / MAX_DIM, 2.0)))
                    recs.append({
                        "slot": info["slot"],
                        "name": info["name"],
                        "file": rel,
                        "width": info["width"] >> mip,
                        "height": info["height"] >> mip,
                        "format": info["format"],
                    })
            except Exception as e:
                recs.append({"error": str(e)})
            out[str(eid)] = recs
            write_status("processed %d/%d draws, %d unique textures"
                         % (n + 1, len(eids), len(cache)))

    pyrenderdoc.Replay().BlockInvoke(cb)

    with open(JSON_OUT, "w") as f:
        json.dump(out, f, indent=1)
    write_status("DONE %d draws, %d unique textures -> %s"
                 % (len(out), len(cache), JSON_OUT))


try:
    main()
except Exception:
    write_status(traceback.format_exc())
    raise
