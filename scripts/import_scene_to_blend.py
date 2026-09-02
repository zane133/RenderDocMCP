# -*- coding: utf-8 -*-
"""
Import RenderDoc-exported OBJ meshes into a Blender .blend file.

Usage (Blender 3.6+):
  blender --background --python import_scene_to_blend.py -- <mesh_dir> [out.blend]
"""
import json
import os
import sys


def parse_argv():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    mesh_dir = argv[0] if len(argv) > 0 else None
    out_blend = argv[1] if len(argv) > 1 else None
    return mesh_dir, out_blend


ALPHA_THRESHOLD = 0.25


def _load_image(mesh_dir, rel):
    import bpy

    if not rel:
        return None
    path = os.path.join(mesh_dir, rel.replace("/", os.sep))
    if not os.path.isfile(path):
        return None
    return bpy.data.images.load(path, check_existing=True)


def _set_cutout_flags(mat):
    """Alpha-clip settings differ across 3.6 / 4.2 / 5.x; set what exists."""
    # Cross-billboard foliage needs both faces; culling hides half the cards.
    try:
        mat.use_backface_culling = False
    except Exception:
        pass
    for prop, value in (("blend_method", "CLIP"), ("shadow_method", "CLIP"),
                        ("surface_render_method", "DITHERED")):
        try:
            setattr(mat, prop, value)
        except Exception:
            pass
    for prop, value in (("alpha_threshold", ALPHA_THRESHOLD),
                        ("use_transparent_shadow", True)):
        try:
            setattr(mat, prop, value)
        except Exception:
            pass


def build_material(name, mat_info, mesh_dir):
    """One Principled material per draw: base colour, hard alpha cut, normal."""
    import bpy

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    try:
        mat.use_backface_culling = False
    except Exception:
        pass
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (600, 0)
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (280, 0)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    for socket, value in (("Roughness", 0.65), ("Metallic", 0.0)):
        if socket in bsdf.inputs:
            bsdf.inputs[socket].default_value = value

    albedo_node = None
    img = _load_image(mesh_dir, mat_info.get("albedo"))
    if img is not None:
        albedo_node = nodes.new("ShaderNodeTexImage")
        albedo_node.image = img
        albedo_node.location = (-420, 240)
        links.new(albedo_node.outputs["Color"], bsdf.inputs["Base Color"])

    alpha_out = None
    if mat_info.get("alpha"):
        if mat_info.get("alpha_from") == "albedo_alpha" and albedo_node is not None:
            alpha_out = albedo_node.outputs["Alpha"]
        else:
            mask = _load_image(mesh_dir, mat_info["alpha"])
            if mask is not None:
                mask_node = nodes.new("ShaderNodeTexImage")
                mask_node.image = mask
                mask_node.location = (-420, -40)
                try:
                    mask.colorspace_settings.name = "Non-Color"
                except Exception:
                    pass
                sep = nodes.new("ShaderNodeSeparateColor")
                sep.location = (-200, -40)
                links.new(mask_node.outputs["Color"], sep.inputs["Color"])
                alpha_out = sep.outputs["Red"]

    if alpha_out is not None:
        # Threshold in the node tree so the cutout looks the same in every engine.
        cut = nodes.new("ShaderNodeMath")
        cut.operation = "GREATER_THAN"
        cut.inputs[1].default_value = ALPHA_THRESHOLD
        cut.location = (40, -40)
        links.new(alpha_out, cut.inputs[0])
        links.new(cut.outputs["Value"], bsdf.inputs["Alpha"])
        _set_cutout_flags(mat)

    nrm_img = _load_image(mesh_dir, mat_info.get("normal"))
    if nrm_img is not None:
        try:
            nrm_img.colorspace_settings.name = "Non-Color"
        except Exception:
            pass
        nrm_node = nodes.new("ShaderNodeTexImage")
        nrm_node.image = nrm_img
        nrm_node.location = (-420, -340)
        nmap = nodes.new("ShaderNodeNormalMap")
        nmap.location = (40, -340)
        color_out = nrm_node.outputs["Color"]
        if mat_info.get("normal_kind") == "bc5":
            # BC5 keeps only X/Y; rebuild a usable Z instead of sampling black.
            sep = nodes.new("ShaderNodeSeparateColor")
            sep.location = (-220, -340)
            comb = nodes.new("ShaderNodeCombineColor")
            comb.location = (-100, -340)
            links.new(color_out, sep.inputs["Color"])
            links.new(sep.outputs["Red"], comb.inputs["Red"])
            links.new(sep.outputs["Green"], comb.inputs["Green"])
            comb.inputs["Blue"].default_value = 1.0
            color_out = comb.outputs["Color"]
        links.new(color_out, nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def main():
    import bpy

    mesh_dir, out_blend = parse_argv()
    if not mesh_dir or not os.path.isdir(mesh_dir):
        raise SystemExit(
            "Usage: blender --background --python import_scene_to_blend.py -- <mesh_dir> [out.blend]"
        )

    mesh_dir = os.path.abspath(mesh_dir)
    if not out_blend:
        out_blend = os.path.join(
            os.path.dirname(mesh_dir),
            os.path.basename(mesh_dir).replace("_meshes", "") + "_scene.blend",
        )
    out_blend = os.path.abspath(out_blend)

    bpy.ops.wm.read_factory_settings(use_empty=True)

    man_path = os.path.join(mesh_dir, "manifest.json")
    mesh_infos = []
    files = []
    materials_info = {}
    if os.path.isfile(man_path):
        with open(man_path, "r") as f:
            man = json.load(f)
        mesh_infos = man.get("meshes", [])
        files = [m["file"] for m in mesh_infos]
        materials_info = man.get("materials", {})
    if not files:
        files = sorted(fn for fn in os.listdir(mesh_dir) if fn.lower().endswith(".obj"))
        mesh_infos = [{"file": fn} for fn in files]

    info_by_file = {m["file"]: m for m in mesh_infos}

    collection = bpy.data.collections.new("RenderDoc_Scene")
    bpy.context.scene.collection.children.link(collection)

    imported = 0
    textured = 0
    mat_cache = {}
    for fn in files:
        path = os.path.join(mesh_dir, fn)
        if not os.path.isfile(path):
            continue
        before = set(bpy.data.objects.keys())
        # Import raw coordinates: the exporter already writes Blender's Z-up space,
        # so the importer's default Y-up conversion would rotate the scene by 90°.
        try:
            bpy.ops.wm.obj_import(filepath=path, up_axis="Z", forward_axis="Y")
        except TypeError:
            bpy.ops.wm.obj_import(filepath=path)
        except Exception:
            bpy.ops.import_scene.obj(filepath=path, axis_forward="Y", axis_up="Z")
        after = set(bpy.data.objects.keys())
        info = info_by_file.get(fn, {})
        eid = str(info.get("event_id", ""))
        mat = None
        if eid in materials_info:
            if eid not in mat_cache:
                mat_cache[eid] = build_material(
                    "mat_eid_" + eid, materials_info[eid], mesh_dir
                )
            mat = mat_cache[eid]
        for name in after - before:
            obj = bpy.data.objects[name]
            for col in list(obj.users_collection):
                col.objects.unlink(obj)
            collection.objects.link(obj)
            if mat is not None:
                obj.data.materials.clear()
                obj.data.materials.append(mat)
                textured += 1
            imported += 1
        if imported % 100 == 0 or imported == len(files):
            print("  imported %d/%d ..." % (imported, len(files)))

    # Prefer material preview shading when opening in UI
    try:
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type == "VIEW_3D":
                    for space in area.spaces:
                        if space.type == "VIEW_3D":
                            space.shading.type = "MATERIAL"
    except Exception:
        pass

    os.makedirs(os.path.dirname(out_blend) or ".", exist_ok=True)
    # Keep textures on disk: packing 90+ atlases into the .blend is slow and
    # made the previous interrupted save corrupt the file.
    try:
        bpy.ops.file.make_paths_absolute()
    except Exception as e:
        print("make_paths_absolute warning:", e)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend, compress=True)
    print("Imported %d meshes (%d with materials, %d unique materials) -> %s"
          % (imported, textured, len(mat_cache), out_blend))


if __name__ == "__main__":
    main()
