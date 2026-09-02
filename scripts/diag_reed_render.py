# -*- coding: utf-8 -*-
"""Force reed materials to sample with Repeat + show texture as emission."""
import os
import sys
import math

STATUS = r"F:\13_MCP_AI\RenderDocMCP\exports\got_frame2925_probe\_reedfix.txt"


def status(msg):
    print(msg)
    sys.stdout.flush()
    with open(STATUS, "w") as f:
        f.write(msg)


def parse_argv():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    return argv[0] if argv else None, argv[1] if len(argv) > 1 else None


def fix_mat(mat, mode):
    """mode: 'cutout' | 'emission' | 'opaque_albedo'"""
    import bpy
    try:
        mat.use_backface_culling = False
    except Exception:
        pass
    for prop, value in (("blend_method", "CLIP" if mode == "cutout" else "OPAQUE"),
                        ("shadow_method", "CLIP" if mode == "cutout" else "OPAQUE"),
                        ("alpha_threshold", 0.1)):
        try:
            setattr(mat, prop, value)
        except Exception:
            pass

    if not mat.use_nodes:
        return
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Force every image texture to Repeat (out-of-range UVs otherwise go black).
    img_nodes = [n for n in nodes if n.type == "TEX_IMAGE"]
    for n in img_nodes:
        n.extension = "REPEAT"
        n.interpolation = "Closest"  # clearer for diagnosis

    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    out = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None)
    if bsdf is None or out is None or not img_nodes:
        return
    albedo = img_nodes[0]

    # Clear surface links and rebuild simply.
    for link in list(out.inputs["Surface"].links):
        links.remove(link)

    if mode == "emission":
        em = nodes.new("ShaderNodeEmission")
        em.location = (280, 200)
        links.new(albedo.outputs["Color"], em.inputs["Color"])
        em.inputs["Strength"].default_value = 1.0
        links.new(em.outputs["Emission"], out.inputs["Surface"])
    elif mode == "opaque_albedo":
        # Disconnect alpha so cards stay solid, colour from atlas.
        if "Alpha" in bsdf.inputs:
            for link in list(bsdf.inputs["Alpha"].links):
                links.remove(link)
            bsdf.inputs["Alpha"].default_value = 1.0
        links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    else:
        # cutout: wire alpha directly (no GREATER_THAN), lower threshold
        if "Alpha" in bsdf.inputs:
            for link in list(bsdf.inputs["Alpha"].links):
                links.remove(link)
            links.new(albedo.outputs["Alpha"], bsdf.inputs["Alpha"])
        links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])


def setup_camera(scene, manifest_path):
    import bpy
    from mathutils import Matrix
    import json
    man = json.load(open(manifest_path))
    m = man["viewproj_fit"]["matrix"]
    scale = float(man.get("unit_scale", 1.0))

    def norm(v):
        n = math.sqrt(sum(c*c for c in v))
        return [c/n for c in v] if n > 1e-12 else v, n

    def solve3(a, b):
        mm = [list(a[r]) + [b[r]] for r in range(3)]
        for col in range(3):
            piv = max(range(col, 3), key=lambda r: abs(mm[r][col]))
            if abs(mm[piv][col]) < 1e-12:
                return [0, 0, 0]
            mm[col], mm[piv] = mm[piv], mm[col]
            d = mm[col][col]
            mm[col] = [v/d for v in mm[col]]
            for r in range(3):
                if r == col:
                    continue
                f = mm[r][col]
                mm[r] = [mm[r][c] - f*mm[col][c] for c in range(4)]
        return [mm[r][3] for r in range(3)]

    right, sx = norm(m[0][:3])
    up, sy = norm(m[1][:3])
    fwd, _ = norm(m[3][:3])
    eye = [c*scale for c in solve3([m[0][:3], m[1][:3], m[3][:3]],
                                   [-m[0][3], -m[1][3], -m[3][3]])]
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.angle = 2.0 * math.atan(1.0/sx)
    cam_data.clip_start = 0.05
    cam_data.clip_end = 1e5
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.matrix_world = Matrix((
        (right[0], up[0], -fwd[0], eye[0]),
        (right[1], up[1], -fwd[1], eye[1]),
        (right[2], up[2], -fwd[2], eye[2]),
        (0, 0, 0, 1),
    ))
    scene.camera = cam
    scene.render.resolution_x = 1280
    scene.render.resolution_y = max(1, int(round(1280 * sx / sy)))
    return cam


def main():
    import bpy

    manifest, out_png = parse_argv()
    scene = bpy.context.scene
    setup_camera(scene, manifest)

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

    world = scene.world or bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.15, 0.18, 0.22, 1)
        bg.inputs[1].default_value = 0.4

    # Hide non-reed meshes for clean diagnosis.
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        keep = any(s.material and ("5446" in s.material.name or "4939" in s.material.name)
                   for s in obj.material_slots)
        obj.hide_render = not keep

    reed_mats = [m for m in bpy.data.materials if "5446" in m.name or "4939" in m.name]
    status("reed mats=%d" % len(reed_mats))

    base = out_png or r"F:\13_MCP_AI\RenderDocMCP\exports\got_reed_diag.png"
    for mode in ("emission", "opaque_albedo", "cutout"):
        for mat in reed_mats:
            fix_mat(mat, mode)
        path = base.replace(".png", "_%s.png" % mode)
        scene.render.filepath = path
        scene.render.image_settings.file_format = "PNG"
        bpy.ops.render.render(write_still=True)
        status("rendered %s -> %s" % (mode, path))

    status("DONE")


if __name__ == "__main__":
    main()
