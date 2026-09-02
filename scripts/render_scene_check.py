# -*- coding: utf-8 -*-
"""
Add the capture's camera to an imported RenderDoc scene and render a preview,
so the reconstruction can be compared against the capture thumbnail.

The camera comes from the view-projection matrix fitted during export:
  clip.x = sx * dot(right,   world - eye)
  clip.y = sy * dot(up,      world - eye)
  clip.w =      dot(forward, world - eye)

Usage:
  blender --background scene.blend --python render_scene_check.py -- <manifest.json> <out.png>
"""
import json
import math
import os
import sys


def parse_argv():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    manifest = argv[0] if argv else None
    out_png = argv[1] if len(argv) > 1 else None
    engine = argv[2].lower() if len(argv) > 2 else "workbench"
    return manifest, out_png, engine


def setup_engine(scene, engine):
    """Workbench for geometry checks, EEVEE when the textures matter."""
    import bpy

    if engine != "eevee":
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "RANDOM"
        scene.display.shading.show_shadows = False
        return

    for name in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = name
            break
        except Exception:
            continue
    try:
        scene.eevee.taa_render_samples = 16
    except Exception:
        pass

    world = bpy.data.worlds.new("Sky") if not bpy.data.worlds else bpy.data.worlds[0]
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg is not None:
        bg.inputs[0].default_value = (0.55, 0.68, 0.85, 1.0)
        bg.inputs[1].default_value = 2.0

    sun_data = bpy.data.lights.new("Sun", type="SUN")
    sun_data.energy = 4.0
    sun_data.angle = math.radians(2.0)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(50.0), 0.0, math.radians(140.0))
    scene.collection.objects.link(sun)


def normalize(v):
    n = math.sqrt(sum(c * c for c in v))
    if n < 1e-12:
        return v, 0.0
    return [c / n for c in v], n


def solve3(a, b):
    """Solve a·x = b for 3x3 a using Gaussian elimination."""
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


def main():
    import bpy
    from mathutils import Matrix, Vector

    manifest_path, out_png, engine = parse_argv()
    if not manifest_path or not os.path.isfile(manifest_path):
        raise SystemExit("need manifest.json path")
    man = json.load(open(manifest_path))
    fit = man.get("viewproj_fit") or {}
    m = fit.get("matrix")
    if not m:
        raise SystemExit("manifest has no fitted view-projection matrix")

    scale = float(man.get("unit_scale", 1.0))
    flip_x = bool(man.get("flip_x"))
    flip_yz = bool(man.get("flip_yz"))

    right, sx = normalize(m[0][:3])
    up, sy = normalize(m[1][:3])
    fwd, _ = normalize(m[3][:3])

    # eye: the world point with clip.x = clip.y = clip.w = 0
    a3 = [m[0][:3], m[1][:3], m[3][:3]]
    b3 = [-m[0][3], -m[1][3], -m[3][3]]
    eye = solve3(a3, b3)

    def to_export_space(v):
        x, y, z = v
        if flip_x:
            x = -x
        if flip_yz:
            x, y, z = x, -z, y
        return [x, y, z]

    def to_export_point(v):
        return [c * scale for c in to_export_space(v)]

    right = to_export_space(right)
    up = to_export_space(up)
    fwd = to_export_space(fwd)
    eye = to_export_point(eye)

    cam_data = bpy.data.cameras.new("CaptureCamera")
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.angle = 2.0 * math.atan(1.0 / sx) if sx > 0 else math.radians(60.0)
    cam_data.clip_start = 0.05
    cam_data.clip_end = 100000.0
    cam = bpy.data.objects.new("CaptureCamera", cam_data)
    bpy.context.scene.collection.objects.link(cam)

    # Blender camera looks down -Z with +Y up
    basis = Matrix((
        (right[0], up[0], -fwd[0], eye[0]),
        (right[1], up[1], -fwd[1], eye[1]),
        (right[2], up[2], -fwd[2], eye[2]),
        (0.0, 0.0, 0.0, 1.0),
    ))
    cam.matrix_world = basis
    bpy.context.scene.camera = cam

    scene = bpy.context.scene
    aspect = (sy / sx) if sx > 0 else (16.0 / 9.0)
    scene.render.resolution_x = 1024
    scene.render.resolution_y = max(1, int(round(1024 / aspect)))
    scene.render.resolution_percentage = 100
    setup_engine(scene, engine)
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = out_png or os.path.join(
        os.path.dirname(manifest_path), "_camera_check.png"
    )

    print("camera fov_x=%.1f deg aspect=%.3f eye=%s" % (
        math.degrees(cam_data.angle), aspect, ["%.3f" % c for c in eye]))
    print("right=%s up=%s fwd=%s" % (
        ["%.3f" % c for c in right], ["%.3f" % c for c in up], ["%.3f" % c for c in fwd]))

    bpy.ops.render.render(write_still=True)
    print("rendered ->", scene.render.filepath)


if __name__ == "__main__":
    main()
