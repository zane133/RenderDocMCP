# -*- coding: utf-8 -*-
"""Patch materials on an already-imported textured scene and re-render.

Fixes the two things that make foliage cards disappear:
  - backface culling (cross-billboard reeds need both faces)
  - over-bright EEVEE lighting washing cream albedo into the sky

Usage:
  blender --background textured.blend --python fix_and_rerender.py -- <manifest.json> <out.png>
"""
import json
import math
import os
import sys


def parse_argv():
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    return (argv[0] if argv else None,
            argv[1] if len(argv) > 1 else None)


def solve3(a, b):
    m = [list(a[r]) + [b[r]] for r in range(3)]
    for col in range(3):
        piv = max(range(col, 3), key=lambda r: abs(m[r][col]))
        if abs(m[piv][col]) < 1e-12:
            return [0.0, 0.0, 0.0]
        m[col], m[piv] = m[piv], m[col]
        d = m[col][col]
        m[col] = [v / d for v in m[col]]
        for r in range(3):
            if r == col:
                continue
            f = m[r][col]
            m[r] = [m[r][c] - f * m[col][c] for c in range(4)]
    return [m[r][3] for r in range(3)]


def normalize(v):
    n = math.sqrt(sum(c * c for c in v))
    return ([c / n for c in v], n) if n > 1e-12 else (v, 0.0)


def main():
    import bpy
    from mathutils import Matrix

    manifest_path, out_png = parse_argv()
    man = json.load(open(manifest_path))

    # --- material fixes ---
    fixed = 0
    reed_mats = 0
    for mat in bpy.data.materials:
        try:
            mat.use_backface_culling = False
        except Exception:
            pass
        for prop, value in (("blend_method", "CLIP"),
                            ("shadow_method", "CLIP"),
                            ("alpha_threshold", 0.25)):
            try:
                setattr(mat, prop, value)
            except Exception:
                pass
        # Soften the hard cut threshold in the node tree if present.
        if mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type == "MATH" and n.operation == "GREATER_THAN":
                    n.inputs[1].default_value = 0.25
                if n.type == "BSDF_PRINCIPLED":
                    if "Roughness" in n.inputs:
                        n.inputs["Roughness"].default_value = 0.85
                    if "Specular IOR Level" in n.inputs:
                        n.inputs["Specular IOR Level"].default_value = 0.05
                    elif "Specular" in n.inputs:
                        n.inputs["Specular"].default_value = 0.05
        if "5446" in mat.name or "4939" in mat.name:
            reed_mats += 1
        fixed += 1

    reed_objs = sum(
        1 for o in bpy.data.objects
        if o.type == "MESH" and any("5446" in (s.material.name if s.material else "")
                                    for s in o.material_slots)
    )
    print("materials fixed=%d reed_mats=%d reed_objects=%d" % (fixed, reed_mats, reed_objs))
    print("total mesh objects=%d" % sum(1 for o in bpy.data.objects if o.type == "MESH"))

    # --- camera from fitted VP ---
    fit = man["viewproj_fit"]
    m = fit["matrix"]
    scale = float(man.get("unit_scale", 1.0))
    right, sx = normalize(m[0][:3])
    up, sy = normalize(m[1][:3])
    fwd, _ = normalize(m[3][:3])
    eye = solve3([m[0][:3], m[1][:3], m[3][:3]],
                 [-m[0][3], -m[1][3], -m[3][3]])
    eye = [c * scale for c in eye]
    print("eye(scaled)=%s sx=%.3f sy=%.3f" % (["%.6f" % c for c in eye], sx, sy))

    cam_data = bpy.data.cameras.new("CaptureCamera2")
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.angle = 2.0 * math.atan(1.0 / sx) if sx > 0 else math.radians(60.0)
    cam_data.clip_start = 0.05
    cam_data.clip_end = 100000.0
    cam = bpy.data.objects.new("CaptureCamera2", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.matrix_world = Matrix((
        (right[0], up[0], -fwd[0], eye[0]),
        (right[1], up[1], -fwd[1], eye[1]),
        (right[2], up[2], -fwd[2], eye[2]),
        (0.0, 0.0, 0.0, 1.0),
    ))
    scene = bpy.context.scene
    scene.camera = cam
    aspect = (sy / sx) if sx > 0 else (16.0 / 9.0)
    scene.render.resolution_x = 1280
    scene.render.resolution_y = max(1, int(round(1280 / aspect)))
    scene.render.resolution_percentage = 100

    for name in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = name
            break
        except Exception:
            continue
    try:
        scene.eevee.taa_render_samples = 32
    except Exception:
        pass

    # Darker sky so cream reeds read as white against it.
    world = scene.world or bpy.data.worlds.new("Sky")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg is not None:
        bg.inputs[0].default_value = (0.18, 0.22, 0.28, 1.0)
        bg.inputs[1].default_value = 0.6

    # Soft sun
    for obj in list(bpy.data.objects):
        if obj.type == "LIGHT":
            bpy.data.objects.remove(obj, do_unlink=True)
    sun_data = bpy.data.lights.new("Sun", type="SUN")
    sun_data.energy = 2.5
    sun_data.angle = math.radians(5.0)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(40.0), 0.0, math.radians(130.0))
    scene.collection.objects.link(sun)

    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    print("rendered ->", out_png)

    # Also hide everything except reed draw 5446 for a diagnostic shot.
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        keep = any("5446" in (s.material.name if s.material else "")
                   for s in obj.material_slots)
        obj.hide_render = not keep
    reed_png = out_png.replace(".png", "_reeds_only.png")
    scene.render.filepath = reed_png
    bpy.ops.render.render(write_still=True)
    print("rendered reeds-only ->", reed_png)


if __name__ == "__main__":
    main()
