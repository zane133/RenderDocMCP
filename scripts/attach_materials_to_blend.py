# -*- coding: utf-8 -*-
"""Attach materials from manifest onto an already-imported dense scene.

Much faster than re-importing 1900 OBJs: opens the dense .blend, builds one
material per draw id, assigns by object name (eid_NNNN_i*), then saves.

Usage:
  blender --background dense.blend --python attach_materials_to_blend.py -- \\
      <mesh_dir> <out.blend>
"""
from __future__ import print_function

import json
import os
import re
import sys
import traceback

SCRIPT_DIR = r"F:\13_MCP_AI\RenderDocMCP\scripts"
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

STATUS = r"F:\13_MCP_AI\RenderDocMCP\exports\got_frame2925_probe\_attach_status.txt"
EID_RE = re.compile(r"eid_(\d+)", re.I)


def status(msg):
    print(msg)
    sys.stdout.flush()
    with open(STATUS, "w") as f:
        f.write(msg)


def parse_argv():
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    mesh_dir = argv[0] if argv else None
    out_blend = argv[1] if len(argv) > 1 else None
    return mesh_dir, out_blend


def main():
    import bpy
    # Reuse the material builder from the importer.
    import import_scene_to_blend as imp

    mesh_dir, out_blend = parse_argv()
    if not mesh_dir or not out_blend:
        raise SystemExit("need <mesh_dir> <out.blend>")
    mesh_dir = os.path.abspath(mesh_dir)
    out_blend = os.path.abspath(out_blend)

    man = json.load(open(os.path.join(mesh_dir, "manifest.json")))
    materials_info = man.get("materials") or {}
    status("building %d materials from %s" % (len(materials_info), mesh_dir))

    mat_cache = {}
    for eid, info in materials_info.items():
        mat_cache[eid] = imp.build_material("mat_eid_" + eid, info, mesh_dir)
    status("built %d materials; assigning to objects..." % len(mat_cache))

    assigned = 0
    skipped = 0
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        m = EID_RE.search(obj.name)
        if not m:
            skipped += 1
            continue
        eid = m.group(1)
        mat = mat_cache.get(eid)
        if mat is None:
            skipped += 1
            continue
        try:
            obj.data.materials.clear()
        except Exception:
            while obj.data.materials:
                obj.data.materials.pop(index=0)
        obj.data.materials.append(mat)
        try:
            obj.data.use_auto_smooth = False
        except Exception:
            pass
        assigned += 1

    status("assigned=%d skipped=%d; saving %s" % (assigned, skipped, out_blend))
    try:
        bpy.ops.file.make_paths_absolute()
    except Exception as e:
        print("make_paths_absolute:", e)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend, compress=True)
    status("DONE assigned=%d materials=%d -> %s" % (assigned, len(mat_cache), out_blend))


try:
    main()
except Exception:
    status(traceback.format_exc())
    raise
