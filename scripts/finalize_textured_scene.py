# -*- coding: utf-8 -*-
"""Rebuild foliage materials for visibility and re-render the full scene.

Reed cards use Repeat sampling + alpha clip (black atlas = cut). A little
emission keeps cream albedo readable under a dark sky.
"""
import json
import math
import os
import sys

STATUS = r"F:\13_MCP_AI\RenderDocMCP\exports\got_frame2925_probe\_final_render.txt"


def status(msg):
    print(msg)
    sys.stdout.flush()
    with open(STATUS, "w") as f:
        f.write(msg)


def parse_argv():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    return (argv[0] if argv else None,
            argv[1] if len(argv) > 1 else None,
            argv[2] if len(argv) > 2 else None)


def rebuild_material(mat, mat_info, mesh_dir):
    import bpy

    mat.use_nodes = True
    try:
        mat.use_backface_culling = False
    except Exception:
        pass
    for prop, value in (("blend_method", "CLIP"),
                        ("shadow_method", "CLIP"),
                        ("surface_render_method", "DITHERED"),
                        ("alpha_threshold", 0.15)):
        try:
            setattr(mat, prop, value)
        except Exception:
            pass

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (720, 0)
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (300, 80)
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = 0.9
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    elif "Specular" in bsdf.inputs:
        bsdf.inputs["Specular"].default_value = 0.0

    def load(rel, non_color=False):
        if not rel:
            return None
        path = os.path.join(mesh_dir, rel.replace("/", os.sep))
        if not os.path.isfile(path):
            return None
        img = bpy.data.images.load(path, check_existing=True)
        if non_color:
            try:
                img.colorspace_settings.name = "Non-Color"
            except Exception:
                pass
        return img

    albedo_img = load(mat_info.get("albedo"))
    albedo_node = None
    if albedo_img is not None:
        albedo_node = nodes.new("ShaderNodeTexImage")
        albedo_node.image = albedo_img
        albedo_node.extension = "REPEAT"
        albedo_node.interpolation = "Linear"
        albedo_node.location = (-420, 200)
        links.new(albedo_node.outputs["Color"], bsdf.inputs["Base Color"])

    # Alpha: prefer albedo alpha, else red channel of mask.
    alpha_src = None
    if mat_info.get("alpha_from") == "albedo_alpha" and albedo_node is not None:
        alpha_src = albedo_node.outputs["Alpha"]
    elif mat_info.get("alpha"):
        mask_img = load(mat_info["alpha"], non_color=True)
        if mask_img is not None:
            mask_node = nodes.new("ShaderNodeTexImage")
            mask_node.image = mask_img
            mask_node.extension = "REPEAT"
            mask_node.location = (-420, -40)
            sep = nodes.new("ShaderNodeSeparateColor")
            sep.location = (-200, -40)
            links.new(mask_node.outputs["Color"], sep.inputs["Color"])
            alpha_src = sep.outputs["Red"]
        elif albedo_node is not None:
            alpha_src = albedo_node.outputs["Alpha"]

    if alpha_src is not None and "Alpha" in bsdf.inputs:
        links.new(alpha_src, bsdf.inputs["Alpha"])

    # Prefer Principled's own emission sockets — a Mix Shader would discard alpha.
    if albedo_node is not None:
        if "Emission Color" in bsdf.inputs:
            links.new(albedo_node.outputs["Color"], bsdf.inputs["Emission Color"])
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = 0.4
        elif "Emission" in bsdf.inputs:
            links.new(albedo_node.outputs["Color"], bsdf.inputs["Emission"])
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = 0.4

    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])


def setup_camera(scene, man):
    import bpy
    from mathutils import Matrix

    m = man["viewproj_fit"]["matrix"]
    scale = float(man.get("unit_scale", 1.0))

    def norm(v):
        n = math.sqrt(sum(c * c for c in v))
        return ([c / n for c in v], n) if n > 1e-12 else (v, 0.0)

    def solve3(a, b):
        mm = [list(a[r]) + [b[r]] for r in range(3)]
        for col in range(3):
            piv = max(range(col, 3), key=lambda r: abs(mm[r][col]))
            if abs(mm[piv][col]) < 1e-12:
                return [0.0, 0.0, 0.0]
            mm[col], mm[piv] = mm[piv], mm[col]
            d = mm[col][col]
            mm[col] = [v / d for v in mm[col]]
            for r in range(3):
                if r == col:
                    continue
                f = mm[r][col]
                mm[r] = [mm[r][c] - f * mm[col][c] for c in range(4)]
        return [mm[r][3] for r in range(3)]

    right, sx = norm(m[0][:3])
    up, sy = norm(m[1][:3])
    fwd, _ = norm(m[3][:3])
    eye = [c * scale for c in solve3(
        [m[0][:3], m[1][:3], m[3][:3]],
        [-m[0][3], -m[1][3], -m[3][3]])]

    cam_data = bpy.data.cameras.new("CaptureCam")
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.angle = 2.0 * math.atan(1.0 / sx) if sx > 0 else math.radians(60)
    cam_data.clip_start = 0.05
    cam_data.clip_end = 1e5
    cam = bpy.data.objects.new("CaptureCam", cam_data)
    scene.collection.objects.link(cam)
    cam.matrix_world = Matrix((
        (right[0], up[0], -fwd[0], eye[0]),
        (right[1], up[1], -fwd[1], eye[1]),
        (right[2], up[2], -fwd[2], eye[2]),
        (0, 0, 0, 1),
    ))
    scene.camera = cam
    scene.render.resolution_x = 1280
    scene.render.resolution_y = max(1, int(round(1280 * (sx / sy if sy else 9/16))))
    return cam


def main():
    import bpy

    mesh_dir, out_blend, out_png = parse_argv()
    mesh_dir = os.path.abspath(mesh_dir)
    man = json.load(open(os.path.join(mesh_dir, "manifest.json")))
    materials_info = man.get("materials") or {}

    status("rebuilding %d materials" % len(materials_info))
    for mat in list(bpy.data.materials):
        eid = mat.name.replace("mat_eid_", "")
        info = materials_info.get(eid)
        if info:
            rebuild_material(mat, info, mesh_dir)

    scene = bpy.context.scene
    setup_camera(scene, man)
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

    world = scene.world or bpy.data.worlds.new("Sky")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        # Match the moody GoT sky a bit, but keep enough fill light.
        bg.inputs[0].default_value = (0.25, 0.30, 0.38, 1.0)
        bg.inputs[1].default_value = 1.2

    for obj in list(bpy.data.objects):
        if obj.type == "LIGHT":
            bpy.data.objects.remove(obj, do_unlink=True)
    sun = bpy.data.lights.new("Sun", type="SUN")
    sun.energy = 3.5
    sun.angle = math.radians(4)
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(45), 0, math.radians(135))
    scene.collection.objects.link(sun_obj)

    if out_blend:
        bpy.ops.file.make_paths_absolute()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out_blend), compress=True)
        status("saved %s" % out_blend)

    out_png = out_png or r"F:\13_MCP_AI\RenderDocMCP\exports\got_textured_final.png"
    scene.render.filepath = out_png
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    status("rendered %s" % out_png)

    # Reeds-only pass
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        keep = any(s.material and ("5446" in s.material.name or "4939" in s.material.name)
                   for s in obj.material_slots)
        obj.hide_render = not keep
    reed_png = out_png.replace(".png", "_reeds.png")
    scene.render.filepath = reed_png
    bpy.ops.render.render(write_still=True)
    status("DONE %s + %s" % (out_png, reed_png))


if __name__ == "__main__":
    main()
