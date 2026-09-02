# -*- coding: utf-8 -*-
"""
Export scene meshes from the current RenderDoc capture to OBJ + manifest.

Works in two modes:
  1) RenderDoc UI Python shell / --ui-script  (uses global `pyrenderdoc`)
  2) Headless:  python36 export_scene_meshes.py capture.rdc [out_dir]

Default source: Colour Pass #1 GBuffer draws (main opaque scene geometry).

Position priority (avoids flattened NDC):
  1) Unproject SV_POSITION via inverse ViewProj (cb11[8..11] for BG3-like VS)
  2) Object-space VS input / PostVS local pos, transformed by object matrix cb0[0..3]
  3) Local position only (unflattened, but stacked at origin)
"""
from __future__ import print_function, division

import json
import os
import struct
import sys
import time

if "renderdoc" not in sys.modules and "_renderdoc" not in sys.modules:
    rd_dir = r"C:\Program Files\RenderDoc"
    if os.path.isdir(rd_dir) and rd_dir not in sys.path:
        sys.path.insert(0, rd_dir)
    import renderdoc

rd = sys.modules.get("renderdoc") or renderdoc


MARKER_FILTER = os.environ.get("RD_EXPORT_MARKER", "Colour Pass #1 (")
MIN_INDICES = int(os.environ.get("RD_EXPORT_MIN_INDICES", "12"))
MAX_DRAWS = int(os.environ.get("RD_EXPORT_MAX_DRAWS", "0"))
# Comma separated event ids: export only these draws (used to top up a scene).
ONLY_EIDS = set(
    int(e) for e in os.environ.get("RD_EXPORT_EIDS", "").replace(" ", "").split(",") if e
)
INSTANCE_MODE = os.environ.get("RD_EXPORT_INSTANCES", "first")
# Default off: (x,-z,y) is a 90° X-tilt that often looks wrong for BG3 world meshes.
# Set RD_EXPORT_FLIP_YZ=1 if you need explicit Y-up → Z-up remapping.
FLIP_YZ = os.environ.get("RD_EXPORT_FLIP_YZ", "0") == "1"
# D3D vs Blender handedness: negate X to fix left/right mirroring.
FLIP_X = os.environ.get("RD_EXPORT_FLIP_X", "1") == "1"
EXPORT_TEXTURES = os.environ.get("RD_EXPORT_TEXTURES", "0") == "1"
# jpg|png — jpg is much smaller for giant atlases
TEX_FORMAT = os.environ.get("RD_EXPORT_TEX_FORMAT", "jpg").lower()
TEX_MAX_DIM = int(os.environ.get("RD_EXPORT_TEX_MAX_DIM", "8192"))  # 0 = no limit
# Multiplied into every exported position (game units -> metres).
UNIT_SCALE = float(os.environ.get("RD_EXPORT_SCALE", "1.0"))
# Fit the view-projection matrix from PostVS data and unproject SV_Position.
FIT_VIEWPROJ = os.environ.get("RD_EXPORT_FIT_VP", "1") == "1"
# Drop draws whose unprojected bbox exceeds this (pre-scale) — usually wrong camera.
MAX_WORLD_EXTENT = float(os.environ.get("RD_EXPORT_MAX_EXTENT", "1e6"))

# Skip draws whose geometry was already written (depth prepass + colour pass).
DEDUPE = os.environ.get("RD_EXPORT_DEDUPE", "1") == "1"
# Only keep draws whose positions came from a fitted view-projection.
STRICT_VP = os.environ.get("RD_EXPORT_STRICT_VP", "1") == "1"
# Drop meshes with no thickness in some axis (fullscreen quads, decals).
MIN_MESH_SIZE = float(os.environ.get("RD_EXPORT_MIN_SIZE", "1e-4"))

# Populated by fit_scene_viewproj(); shared by every draw in the capture.
GLOBAL_INV_VP = None
GLOBAL_VP_INFO = {}
DEDUPE_SEEN = {}
DRAW_FIT_CACHE = {}


class MeshData(rd.MeshFormat):
    indexOffset = 0
    name = ""


# ---------------- math ----------------

def mat4_identity():
    return [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]


def mat4_from_columns(c0, c1, c2, c3):
    """Build matrix whose columns are c0..c3 (each len>=4). Used as M * v_col."""
    return [
        [c0[0], c1[0], c2[0], c3[0]],
        [c0[1], c1[1], c2[1], c3[1]],
        [c0[2], c1[2], c2[2], c3[2]],
        [c0[3], c1[3], c2[3], c3[3]],
    ]


def mat4_mul_vec(m, v):
    x = m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2] + m[0][3] * v[3]
    y = m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2] + m[1][3] * v[3]
    z = m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2] + m[2][3] * v[3]
    w = m[3][0] * v[0] + m[3][1] * v[1] + m[3][2] * v[2] + m[3][3] * v[3]
    return (x, y, z, w)


def mat4_invert(m):
    """Invert 4x4; raise if singular."""
    a = [row[:] for row in m]
    inv = mat4_identity()
    for col in range(4):
        # partial pivot
        piv = col
        best = abs(a[col][col])
        for r in range(col + 1, 4):
            if abs(a[r][col]) > best:
                best = abs(a[r][col])
                piv = r
        if best < 1e-12:
            raise ValueError("singular matrix")
        if piv != col:
            a[col], a[piv] = a[piv], a[col]
            inv[col], inv[piv] = inv[piv], inv[col]
        div = a[col][col]
        for c in range(4):
            a[col][c] /= div
            inv[col][c] /= div
        for r in range(4):
            if r == col:
                continue
            f = a[r][col]
            for c in range(4):
                a[r][c] -= f * a[col][c]
                inv[r][c] -= f * inv[col][c]
    return inv


def transform_point(m, x, y, z):
    hx, hy, hz, hw = mat4_mul_vec(m, (x, y, z, 1.0))
    if abs(hw) > 1e-8:
        return (hx / hw, hy / hw, hz / hw)
    return (hx, hy, hz)


def transform_dir(m, x, y, z):
    hx, hy, hz, _hw = mat4_mul_vec(m, (x, y, z, 0.0))
    return (hx, hy, hz)


# ---------------- unpack / mesh attrs ----------------

def unpack_data(fmt, data, offset=0):
    if fmt.Special():
        raise RuntimeError("Packed formats are not supported")

    chars = {
        rd.CompType.UInt: "xBHxIxxxL",
        rd.CompType.SInt: "xbhxixxxl",
        rd.CompType.Float: "xxexfxxxd",
    }
    chars[rd.CompType.UNorm] = chars[rd.CompType.UInt]
    chars[rd.CompType.UScaled] = chars[rd.CompType.UInt]
    chars[rd.CompType.SNorm] = chars[rd.CompType.SInt]
    chars[rd.CompType.SScaled] = chars[rd.CompType.SInt]

    fmt_char = chars[fmt.compType][fmt.compByteWidth]
    value = struct.unpack_from(str(fmt.compCount) + fmt_char, data, offset)

    if fmt.compType == rd.CompType.UNorm:
        div = float((2 ** (fmt.compByteWidth * 8)) - 1)
        value = tuple(float(v) / div for v in value)
    elif fmt.compType == rd.CompType.SNorm:
        max_neg = -float(2 ** (fmt.compByteWidth * 8)) / 2
        div = float(-(max_neg - 1))
        value = tuple(float(v) if v == max_neg else float(v) / div for v in value)

    if fmt.BGRAOrder():
        value = tuple(value[i] for i in (2, 1, 0, 3))
    return value


def get_indices(controller, mesh):
    if mesh.indexResourceId != rd.ResourceId.Null():
        ib = controller.GetBufferData(mesh.indexResourceId, mesh.indexByteOffset, 0)
        fmt = {1: "B", 2: "H", 4: "I"}[mesh.indexByteStride]
        off = mesh.indexOffset * mesh.indexByteStride
        indices = struct.unpack_from(str(mesh.numIndices) + fmt, ib, off)
        return [i + mesh.baseVertex for i in indices]
    return list(range(mesh.numIndices))


def build_postvs_attrs(controller, postvs):
    vs = controller.GetPipelineState().GetShaderReflection(rd.ShaderStage.Vertex)
    if vs is None:
        return []

    outs = []
    pos_idx = 0
    for attr in vs.outputSignature:
        md = MeshData()
        md.indexResourceId = postvs.indexResourceId
        md.indexByteOffset = postvs.indexByteOffset
        md.indexByteStride = postvs.indexByteStride
        md.baseVertex = postvs.baseVertex
        md.indexOffset = 0
        md.numIndices = postvs.numIndices
        md.vertexByteOffset = postvs.vertexByteOffset
        md.vertexResourceId = postvs.vertexResourceId
        md.vertexByteStride = postvs.vertexByteStride

        md.format = rd.ResourceFormat()
        md.format.compByteWidth = rd.VarTypeByteSize(attr.varType)
        md.format.compCount = attr.compCount
        md.format.compType = rd.VarTypeCompType(attr.varType)
        md.format.type = rd.ResourceFormatType.Regular
        md.name = attr.semanticIdxName if attr.varName == "" else attr.varName
        md._systemValue = attr.systemValue

        if attr.systemValue == rd.ShaderBuiltin.Position:
            pos_idx = len(outs)
        outs.append(md)

    if pos_idx > 0:
        outs.insert(0, outs.pop(pos_idx))

    accum = 0
    for md in outs:
        md.vertexByteOffset = postvs.vertexByteOffset + accum
        fmt = md.format
        accum += (8 if fmt.compByteWidth > 4 else 4) * fmt.compCount
    return outs


def build_vs_input_attrs(controller, draw):
    state = controller.GetPipelineState()
    ib = state.GetIBuffer()
    vbs = state.GetVBuffers()
    attrs = state.GetVertexInputs()
    mesh_inputs = []
    for attr in attrs:
        if attr.perInstance:
            continue
        if not attr.used:
            continue
        md = MeshData()
        md.indexResourceId = ib.resourceId
        md.indexByteOffset = ib.byteOffset
        md.indexByteStride = ib.byteStride
        md.baseVertex = draw.baseVertex
        md.indexOffset = draw.indexOffset
        md.numIndices = draw.numIndices
        if not (draw.flags & rd.ActionFlags.Indexed):
            md.indexResourceId = rd.ResourceId.Null()
        md.vertexByteOffset = (
            attr.byteOffset
            + vbs[attr.vertexBuffer].byteOffset
            + draw.vertexOffset * vbs[attr.vertexBuffer].byteStride
        )
        md.format = attr.format
        md.vertexResourceId = vbs[attr.vertexBuffer].resourceId
        md.vertexByteStride = vbs[attr.vertexBuffer].byteStride
        md.name = attr.name
        mesh_inputs.append(md)
    return mesh_inputs


def fetch_attr_values(controller, attr, indices):
    if not indices:
        return []
    max_idx = max(indices)
    nbytes = attr.vertexByteOffset + attr.vertexByteStride * (max_idx + 1)
    raw = controller.GetBufferData(attr.vertexResourceId, 0, nbytes)
    out = []
    for idx in indices:
        off = attr.vertexByteOffset + attr.vertexByteStride * idx
        out.append(unpack_data(attr.format, raw, off))
    return out


def read_vs_cbuffer_floats(controller, bind_slot, float_count):
    """Read raw float array from VS cbuffer at fixed bind slot (e.g. 0 or 11)."""
    state = controller.GetPipelineState()
    vs = state.GetShaderReflection(rd.ShaderStage.Vertex)
    if vs is None:
        return None

    # Find reflection index matching fixedBindNumber / bindPoint
    ref_index = None
    for i, cb in enumerate(vs.constantBlocks):
        bind = getattr(cb, "fixedBindNumber", None)
        if bind is None:
            bind = getattr(cb, "bindPoint", i)
        if bind == bind_slot or i == bind_slot:
            # Prefer exact fixed bind match
            if bind == bind_slot:
                ref_index = i
                break
            if ref_index is None:
                ref_index = i
    if ref_index is None:
        return None

    try:
        bind = state.GetConstantBuffer(rd.ShaderStage.Vertex, ref_index, 0)
    except Exception:
        try:
            bind = state.GetConstantBlock(rd.ShaderStage.Vertex, ref_index, 0)
            # BoundCBuffer / ConstantBlock descriptor shapes differ by version
            rid = getattr(bind, "resourceId", None)
            if rid is None and hasattr(bind, "descriptor"):
                rid = bind.descriptor.resource
                byte_off = bind.descriptor.byteOffset
                byte_size = bind.descriptor.byteSize
            else:
                byte_off = getattr(bind, "byteOffset", 0)
                byte_size = getattr(bind, "byteSize", 0)
            if rid is None or rid == rd.ResourceId.Null():
                return None
            need = float_count * 4
            data = controller.GetBufferData(rid, byte_off, max(byte_size, need))
            return struct.unpack_from("%df" % float_count, data, 0)
        except Exception:
            return None

    if bind.resourceId == rd.ResourceId.Null():
        return None
    need = float_count * 4
    size = bind.byteSize if bind.byteSize > 0 else need
    data = controller.GetBufferData(bind.resourceId, bind.byteOffset, max(size, need))
    if len(data) < need:
        return None
    return struct.unpack_from("%df" % float_count, data, 0)


def try_viewproj_inverse(controller):
    """
    BG3 VS: clip = world.x*cb11[8] + world.y*cb11[9] + world.z*cb11[10] + cb11[11]
    Columns of ViewProj are cb11[8..11] (each float4).
    """
    floats = read_vs_cbuffer_floats(controller, 11, 14 * 4)  # cb11[0..13]
    if not floats:
        return None
    # float4 index 8 starts at float offset 8*4 = 32
    c0 = floats[32:36]
    c1 = floats[36:40]
    c2 = floats[40:44]
    c3 = floats[44:48]
    try:
        m = mat4_from_columns(c0, c1, c2, c3)
        return mat4_invert(m)
    except Exception:
        return None


def try_object_matrix(controller):
    """
    BG3 VS object matrix: world = v.x*cb0[0].xyz + v.y*cb0[1].xyz + v.z*cb0[2].xyz + cb0[3].xyz
    Store as columns with w=0/1.
    """
    floats = read_vs_cbuffer_floats(controller, 0, 7 * 4)
    if not floats:
        return None
    c0 = (floats[0], floats[1], floats[2], 0.0)
    c1 = (floats[4], floats[5], floats[6], 0.0)
    c2 = (floats[8], floats[9], floats[10], 0.0)
    c3 = (floats[12], floats[13], floats[14], 1.0)
    return mat4_from_columns(c0, c1, c2, c3)


def find_attr(attrs, predicate):
    for a in attrs:
        if predicate(a):
            return a
    return None


def is_clip_attr(attr):
    n = attr.name.upper()
    sv = getattr(attr, "_systemValue", None)
    if sv == rd.ShaderBuiltin.Position:
        return True
    return "SV_POSITION" in n or n in ("POSITION",) and attr.format.compCount == 4 and False


def is_local_pos_attr(attr):
    """Heuristic: float3 interpolator that is often object-local (BG3 o6 / ATTR6)."""
    n = attr.name.upper()
    if getattr(attr, "_systemValue", None) == rd.ShaderBuiltin.Position:
        return False
    if "SV_POSITION" in n:
        return False
    if attr.format.compCount < 3:
        return False
    # Prefer explicit names, else late ATTR / TEXCOORD high indices often carry local pos
    if any(k in n for k in ("LOCAL", "WORLD", "POSITION", "POS", "ATTR6", "TEXCOORD6", "TEX6")):
        if "NORMAL" in n or "TANGENT" in n or "BINORMAL" in n:
            return False
        return True
    if n in ("ATTR6", "TEXCOORD6", "TEX6", "O6"):
        return True
    return False


def _is_clip_or_builtin_pos(attr):
    n = attr.name.upper()
    if getattr(attr, "_systemValue", None) == rd.ShaderBuiltin.Position:
        return True
    return "SV_POSITION" in n


def score_world_pos_attr(controller, attr, sample_indices):
    """
    Score PostVS float3/4 interpolators that look like world/view positions.
    GoT often puts world XYZ in a TEXCOORDn (not named WORLD); BG3-style ATTR6 also scores.
    Rejects unit-ish normals and small UVs.
    """
    if _is_clip_or_builtin_pos(attr):
        return -1.0
    if attr.format.compCount < 3:
        return -1.0
    n = attr.name.upper()
    if any(k in n for k in ("NORMAL", "TANGENT", "BINORMAL", "BITANGENT")):
        return -1.0
    try:
        vals = fetch_attr_values(controller, attr, sample_indices)
    except Exception:
        return -1.0
    if not vals:
        return -1.0

    mags = []
    xs, ys, zs = [], [], []
    nan_count = 0
    for v in vals:
        if len(v) < 3:
            return -1.0
        if not (abs(v[0]) <= 1e20 and abs(v[1]) <= 1e20 and abs(v[2]) <= 1e20):
            nan_count += 1
            continue
        # NaN check
        if v[0] != v[0] or v[1] != v[1] or v[2] != v[2]:
            nan_count += 1
            continue
        mags.append((abs(v[0]) + abs(v[1]) + abs(v[2])) / 3.0)
        xs.append(v[0])
        ys.append(v[1])
        zs.append(v[2])
    if nan_count > len(vals) // 2 or not mags:
        return -1.0

    mags.sort()
    med = mags[len(mags) // 2]
    # normals / tangent frames ~0..1; UVs ~0..1; world usually >> 5
    if med < 5.0:
        return -1.0
    span = (max(xs) - min(xs)) + (max(ys) - min(ys)) + (max(zs) - min(zs))
    # Prefer named world/pos, else magnitude + spatial span
    bonus = 1000.0 if any(k in n for k in ("WORLD", "POSITION", "POS", "ATTR6")) else 0.0
    return bonus + med + span * 0.25


def pick_world_pos_attr(controller, attrs, indices):
    if not indices:
        return None
    # Sample up to 32 vertices across the mesh
    step = max(1, len(indices) // 32)
    sample = [indices[i] for i in range(0, len(indices), step)][:32]
    best = None
    best_score = 0.0
    for attr in attrs:
        sc = score_world_pos_attr(controller, attr, sample)
        if sc > best_score:
            best_score = sc
            best = attr
    return best


def is_uv_attr(attr):
    """Prefer 2-component UV channels; avoid matching every TEXCOORD float3/4."""
    n = attr.name.upper()
    if _is_clip_or_builtin_pos(attr):
        return False
    if attr.format.compCount != 2:
        # Explicit UV names may still be float2 packed oddly; require 2
        if n.startswith("UV") or n in ("TEX",):
            return attr.format.compCount >= 2
        return False
    return (
        "TEXCOORD" in n
        or n.startswith("UV")
        or n in ("TEX", "TEX0", "ATTR1", "O1")
    )


def is_nrm_attr(attr):
    n = attr.name.upper()
    if _is_clip_or_builtin_pos(attr):
        return False
    if attr.format.compCount < 3:
        return False
    return n.startswith("NORMAL") or "NORMAL" in n or n in ("ATTR2", "O2")

def to_blender_pos(x, y, z):
    if FLIP_X:
        x = -x
    if FLIP_YZ:
        x, y, z = x, -z, y
    if UNIT_SCALE != 1.0:
        return (x * UNIT_SCALE, y * UNIT_SCALE, z * UNIT_SCALE)
    return (x, y, z)


def to_blender_dir(x, y, z):
    if FLIP_X:
        x = -x
    if FLIP_YZ:
        return (x, -z, y)
    return (x, y, z)


# ---------------- view-projection fitting ----------------

def fit_matrix_lsq(src_pts, dst_pts):
    """
    Least-squares fit 4x4 M with dst = M * (src.xyz, 1).
    Returns (M, relative_residual). Each output row solves independently.
    """
    ata = [[0.0] * 4 for _ in range(4)]
    atb = [[0.0] * 4 for _ in range(4)]
    n = 0
    for src, dst in zip(src_pts, dst_pts):
        a = (src[0], src[1], src[2], 1.0)
        for i in range(4):
            for j in range(4):
                ata[i][j] += a[i] * a[j]
        for k in range(4):
            for i in range(4):
                atb[k][i] += a[i] * dst[k]
        n += 1
    if n < 8:
        return None, 1e9
    for i in range(4):
        ata[i][i] += 1e-6
    try:
        inv = mat4_invert(ata)
    except Exception:
        return None, 1e9

    m = []
    for k in range(4):
        m.append([sum(inv[i][j] * atb[k][j] for j in range(4)) for i in range(4)])

    num = 0.0
    den = 0.0
    for src, dst in zip(src_pts, dst_pts):
        p = mat4_mul_vec(m, (src[0], src[1], src[2], 1.0))
        for k in range(4):
            num += (p[k] - dst[k]) ** 2
            den += dst[k] ** 2
    if den <= 0.0:
        return None, 1e9
    return m, (num / den) ** 0.5


def _finite3(v):
    for i in range(3):
        c = v[i]
        if c != c or abs(c) > 1e18:
            return False
    return True


def _sample_indices(indices, count=64):
    if len(indices) <= count:
        return list(indices)
    step = max(1, len(indices) // count)
    return [indices[i] for i in range(0, len(indices), step)][:count]


def _is_projection_only(m):
    """True if the w row looks like (0,0,±1,0): src was already view space."""
    row = m[3]
    off = abs(row[0]) + abs(row[1]) + abs(row[3])
    return abs(abs(row[2]) - 1.0) < 0.05 and off < 0.05


def mat3_invert(m):
    a, b, c = m[0]
    d, e, f = m[1]
    g, h, i = m[2]
    det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    if abs(det) < 1e-18:
        raise ValueError("singular 3x3")
    inv_det = 1.0 / det
    return [
        [(e * i - f * h) * inv_det, (c * h - b * i) * inv_det, (b * f - c * e) * inv_det],
        [(f * g - d * i) * inv_det, (a * i - c * g) * inv_det, (c * d - a * f) * inv_det],
        [(d * h - e * g) * inv_det, (b * g - a * h) * inv_det, (a * e - b * d) * inv_det],
    ]


def build_unprojector(m):
    """
    Invert clip = M * (world,1) for world, by least squares over the 4 clip
    components. Needed because reverse-Z / infinite-far projections have a
    degenerate z row (clip.z constant), which makes M itself singular.
    """
    a = [[m[r][c] for c in range(3)] for r in range(4)]  # 4x3 linear part
    t = [m[r][3] for r in range(4)]                      # translation column

    ata = [[0.0] * 3 for _ in range(3)]
    for r in range(4):
        for i in range(3):
            for j in range(3):
                ata[i][j] += a[r][i] * a[r][j]
    try:
        inv3 = mat3_invert(ata)
    except ValueError:
        return None
    return {"a": a, "t": t, "inv3": inv3, "matrix": m}


def is_screen_space_clip(clip_values, tolerance=1e-3, max_flat_w=2.0):
    """
    Fullscreen quads, post-process passes and orthographic shadow projections
    emit a constant clip.w (1 for screen space, 1 for ortho), so unprojecting
    them would place a huge sheet right in front of the camera.

    A flat w alone is not enough: distant billboard cards (grass, foliage) are
    genuinely flat in depth too, so also require w to sit at the ~1 unit that
    only screen-space and orthographic projections produce.
    """
    ws = [abs(c[3]) for c in clip_values if len(c) >= 4 and c[3] == c[3]]
    if len(ws) < 3:
        return True
    lo, hi = min(ws), max(ws)
    if hi <= 0.0:
        return True
    if (hi - lo) / hi >= tolerance:
        return False
    ws.sort()
    return ws[len(ws) // 2] <= max_flat_w


def is_onscreen_clip(clip_values, min_fraction=0.5, guard=1.2):
    """Draws whose clip coords fall outside the viewport aren't part of the view."""
    inside = 0
    total = 0
    for c in clip_values:
        if len(c) < 4 or c[3] != c[3] or abs(c[3]) < 1e-9:
            continue
        total += 1
        if c[3] > 0 and abs(c[0] / c[3]) <= guard and abs(c[1] / c[3]) <= guard:
            inside += 1
    if total == 0:
        return False
    return inside >= min_fraction * total


def unproject_clip(solver, clip_values):
    """Solve world position from full clip (x,y,z,w). Returns list or None."""
    if not solver:
        return None
    a = solver["a"]
    t = solver["t"]
    inv3 = solver["inv3"]
    out = []
    for raw in clip_values:
        if len(raw) < 4:
            return None
        rhs = [0.0, 0.0, 0.0]
        ok = True
        for r in range(4):
            d = raw[r] - t[r]
            if d != d or abs(d) > 1e20:
                ok = False
                break
            for i in range(3):
                rhs[i] += a[r][i] * d
        if not ok:
            return None
        p = tuple(
            inv3[i][0] * rhs[0] + inv3[i][1] * rhs[1] + inv3[i][2] * rhs[2]
            for i in range(3)
        )
        if not _finite3(p):
            return None
        out.append(p)
    return out or None


def fit_viewproj_from_attrs(controller, attrs, clip_attr, indices, max_residual=1e-5):
    """
    Fit VP by pairing a candidate world-space interpolator with SV_Position.
    A near-zero residual proves the candidate really is a position in some
    affine space, and gives the matrix mapping it to clip space.
    """
    if clip_attr is None or clip_attr.format.compCount < 4:
        return None

    sample = _sample_indices(indices)
    if len(sample) < 8:
        return None

    try:
        clip = fetch_attr_values(controller, clip_attr, sample)
    except Exception:
        return None

    keep = []
    pairs_clip = []
    for i, c in enumerate(clip):
        if len(c) >= 4 and _finite3(c) and c[3] == c[3] and abs(c[3]) > 1e-6:
            pairs_clip.append(c)
            keep.append(sample[i])
    if len(pairs_clip) < 8:
        return None

    best = None
    for attr in attrs:
        if _is_clip_or_builtin_pos(attr) or attr.format.compCount < 3:
            continue
        try:
            vals = fetch_attr_values(controller, attr, keep)
        except Exception:
            continue
        src = []
        dst = []
        mags = []
        for v, c in zip(vals, pairs_clip):
            if not _finite3(v):
                continue
            src.append(v)
            dst.append(c)
            mags.append(abs(v[0]) + abs(v[1]) + abs(v[2]))
        if len(src) < 8:
            continue
        mags.sort()
        if mags[len(mags) // 2] < 1.0:
            continue  # normals / UVs, not positions

        m, res = fit_matrix_lsq(src, dst)
        if m is None or res > max_residual:
            continue
        # Prefer world space (full VP) over view space (projection only)
        rank = 1 if _is_projection_only(m) else 0
        if best is None or (rank, res) < (best["rank"], best["residual"]):
            best = {"rank": rank, "residual": res, "matrix": m, "attr": attr.name}
    if best is None:
        return None
    solver = build_unprojector(best["matrix"])
    if solver is None:
        return None
    best["solver"] = solver
    return best


def fit_draw_viewproj(controller, action, instance=0):
    postvs = controller.GetPostVSData(instance, 0, rd.MeshDataStage.VSOut)
    if postvs is None or postvs.numIndices == 0:
        return None
    attrs = build_postvs_attrs(controller, postvs)
    if not attrs:
        return None
    clip_attr = find_attr(attrs, _is_clip_or_builtin_pos)
    try:
        indices = get_indices(controller, attrs[0])
    except Exception:
        return None
    fit = fit_viewproj_from_attrs(controller, attrs, clip_attr, indices)
    if fit:
        fit["event_id"] = action.eventId
    return fit


def fit_scene_viewproj(controller, draws, max_probe=40):
    """Probe the biggest draws for a world-space VP fit; returns (solver, info)."""
    ranked = sorted(draws, key=lambda d: d.numIndices, reverse=True)[:max_probe]
    fits = []
    for action in ranked:
        try:
            controller.SetFrameEvent(action.eventId, True)
            fit = fit_draw_viewproj(controller, action)
        except Exception:
            fit = None
        if fit:
            fits.append(fit)
            if fit["rank"] == 0 and len(fits) >= 3:
                break
    if not fits:
        print("VP fit: no draw produced a usable world->clip matrix")
        return None, {}

    fits.sort(key=lambda f: (f["rank"], f["residual"]))
    best = fits[0]
    info = {
        "event_id": best["event_id"],
        "attr": best["attr"],
        "residual": best["residual"],
        "space": "view" if best["rank"] else "world",
        "candidates": len(fits),
    }
    info["matrix"] = [list(row) for row in best["matrix"]]
    print("VP fit: eid %d via %s residual=%.2e space=%s (%d candidates)" % (
        info["event_id"], info["attr"], info["residual"], info["space"], info["candidates"]))
    return best["solver"], info


# ---------------- textures / materials ----------------

def _rid_int(rid):
    s = str(rid)
    # ResourceId::12345 or <ResourceId 12345>
    digits = "".join(ch for ch in s if ch.isdigit())
    return digits or s.replace(":", "_").replace(" ", "_")


def list_ps_textures(controller):
    """Return list of bound PS texture SRVs with metadata."""
    state = controller.GetPipelineState()
    vs = None
    try:
        reflection = state.GetShaderReflection(rd.ShaderStage.Pixel)
    except Exception:
        reflection = None

    out = []
    try:
        srvs = state.GetReadOnlyResources(rd.ShaderStage.Pixel, False)
    except Exception:
        return out

    name_map = {}
    if reflection is not None:
        for res in reflection.readOnlyResources:
            name_map[res.fixedBindNumber] = res.name

    textures = {t.resourceId: t for t in controller.GetTextures()}

    for srv in srvs:
        rid = srv.descriptor.resource
        if rid == rd.ResourceId.Null():
            continue
        tex = textures.get(rid)
        if tex is None:
            continue
        slot = srv.access.index
        info = {
            "slot": slot,
            "name": name_map.get(slot, ""),
            "resource_id": rid,
            "width": int(tex.width),
            "height": int(tex.height),
            "array_size": int(getattr(tex, "arraysize", getattr(tex, "arraySize", 1)) or 1),
            "format": str(tex.format.Name() if hasattr(tex.format, "Name") else tex.format),
            "dimension": str(tex.type),
            "first_slice": int(srv.descriptor.firstSlice),
            "num_slices": int(srv.descriptor.numSlices) if srv.descriptor.numSlices > 0 else 1,
        }
        # arraysize attribute name differs across versions
        try:
            info["array_size"] = int(tex.arraysize)
        except Exception:
            try:
                info["array_size"] = int(tex.arraySize)
            except Exception:
                info["array_size"] = max(1, info["num_slices"])
        out.append(info)
    return out


def _is_color_tex(info):
    w, h = info["width"], info["height"]
    if w < 64 or h < 64:
        return False
    fmt = info["format"].upper()
    # Skip float LUTs / depth-ish
    if "R32G32B32A32" in fmt or "R32_FLOAT" in fmt or "D32" in fmt or "D24" in fmt:
        return False
    if "TYPELESS" in fmt and "BC" not in fmt and "R8G8B8A8" not in fmt and "B8G8R8" not in fmt:
        if "R16" in fmt or "R32" in fmt:
            return False
    return True


def _tex_score(info):
    if not _is_color_tex(info):
        return -1
    w, h = info["width"], info["height"]
    score = float(w * h)
    fmt = info["format"].upper()
    if "BC" in fmt or "SRGB" in fmt or "UNORM" in fmt:
        score *= 2.0
    # Prefer mid-size character textures slightly over giant atlases when both exist
    # but still allow atlases; mild penalty above 8k
    if max(w, h) > 8192:
        score *= 0.75
    # Prefer earlier PS slots a bit (often albedo)
    score += max(0, 10 - info["slot"]) * 1000
    return score


def pick_material_maps(tex_infos):
    """Pick albedo (+ optional normal) from PS bindings."""
    ranked = sorted(
        [t for t in tex_infos if _tex_score(t) > 0],
        key=_tex_score,
        reverse=True,
    )
    if not ranked:
        return None, None

    albedo = dict(ranked[0])
    albedo["slice"] = albedo.get("first_slice", 0)

    normal = None
    # Same texture array: treat next slices as normal/orm (common in BG3 atlas packs)
    if albedo["array_size"] > 1 or albedo["num_slices"] > 1:
        normal = dict(albedo)
        normal["slice"] = min(albedo["slice"] + 1, max(albedo["array_size"], albedo["num_slices"]) - 1)
        if normal["slice"] == albedo["slice"]:
            normal = None
    else:
        # Otherwise look for another high-scoring unique texture
        for t in ranked[1:]:
            if t["resource_id"] == albedo["resource_id"]:
                continue
            if max(t["width"], t["height"]) < 128:
                continue
            normal = dict(t)
            normal["slice"] = t.get("first_slice", 0)
            break
    return albedo, normal


def save_texture_file(controller, tex_info, out_dir, cache):
    """Save one texture slice; cache by (rid, slice). Returns relative filename or None."""
    rid = tex_info["resource_id"]
    slice_idx = int(tex_info.get("slice", 0))
    key = (_rid_int(rid), slice_idx)
    if key in cache:
        return cache[key]

    tex_dir = os.path.join(out_dir, "textures")
    if not os.path.isdir(tex_dir):
        os.makedirs(tex_dir)

    ext = "jpg" if TEX_FORMAT in ("jpg", "jpeg") else "png"
    fname = "tex_%s_s%d.%s" % (key[0], slice_idx, ext)
    path = os.path.join(tex_dir, fname)

    if os.path.isfile(path) and os.path.getsize(path) > 0:
        rel = os.path.join("textures", fname).replace("\\", "/")
        cache[key] = rel
        return rel

    texsave = rd.TextureSave()
    texsave.resourceId = rid
    texsave.mip = 0
    texsave.slice.sliceIndex = slice_idx
    texsave.alpha = rd.AlphaMapping.Preserve
    if ext == "jpg":
        texsave.destType = rd.FileType.JPG
        try:
            texsave.jpegQuality = 90
        except Exception:
            pass
    else:
        texsave.destType = rd.FileType.PNG

    # Optional downsample via mip if oversized (pick higher mip)
    w = tex_info.get("width", 0)
    h = tex_info.get("height", 0)
    if TEX_MAX_DIM > 0 and max(w, h) > TEX_MAX_DIM:
        # mip N reduces by 2^N
        import math
        need = int(math.ceil(math.log(float(max(w, h)) / float(TEX_MAX_DIM), 2.0)))
        texsave.mip = max(0, need)
        print("  texture %s oversized %dx%d -> mip %d" % (key[0], w, h, texsave.mip))

    try:
        ok = controller.SaveTexture(texsave, path)
        if ok is False or (os.path.isfile(path) and os.path.getsize(path) == 0):
            print("  SaveTexture failed for %s slice %d" % (key[0], slice_idx))
            cache[key] = None
            return None
    except Exception as e:
        print("  SaveTexture error %s: %s" % (key[0], e))
        cache[key] = None
        return None

    rel = os.path.join("textures", fname).replace("\\", "/")
    cache[key] = rel
    print("  saved %s (%dx%d slice %d)" % (rel, w, h, slice_idx))
    return rel


def write_mtl(path, mat_name, albedo_rel, normal_rel=None):
    with open(path, "w") as f:
        f.write("newmtl %s\n" % mat_name)
        f.write("Ka 1.000 1.000 1.000\n")
        f.write("Kd 1.000 1.000 1.000\n")
        f.write("Ks 0.000 0.000 0.000\n")
        f.write("d 1.0\n")
        f.write("illum 1\n")
        if albedo_rel:
            f.write("map_Kd %s\n" % albedo_rel)
            f.write("map_Ka %s\n" % albedo_rel)
        if normal_rel:
            # Some tools honor map_Bump / norm
            f.write("map_Bump %s\n" % normal_rel)
            f.write("norm %s\n" % normal_rel)


def write_obj(path, name, positions, normals, uvs, indices, reverse_winding=False,
              mtl_lib=None, mtl_name=None):
    with open(path, "w") as f:
        f.write("# RenderDoc scene export\n")
        if mtl_lib:
            f.write("mtllib %s\n" % mtl_lib)
        f.write("o %s\n" % name)
        if mtl_name:
            f.write("usemtl %s\n" % mtl_name)
        for p in positions:
            f.write("v %.6f %.6f %.6f\n" % p)
        has_uv = bool(uvs)
        has_n = bool(normals)
        if has_uv:
            for uv in uvs:
                f.write("vt %.6f %.6f\n" % (uv[0], 1.0 - uv[1] if len(uv) > 1 else 0.0))
        if has_n:
            for n in normals:
                f.write("vn %.6f %.6f %.6f\n" % (n[0], n[1], n[2] if len(n) > 2 else 0.0))
        for i in range(0, len(indices) - 2, 3):
            a, b, c = indices[i] + 1, indices[i + 1] + 1, indices[i + 2] + 1
            if reverse_winding:
                b, c = c, b
            if has_uv and has_n:
                f.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n" % (a, a, a, b, b, b, c, c, c))
            elif has_uv:
                f.write("f %d/%d %d/%d %d/%d\n" % (a, a, b, b, c, c))
            elif has_n:
                f.write("f {0}//{0} {1}//{1} {2}//{2}\n".format(a, b, c))
            else:
                f.write("f %d %d %d\n" % (a, b, c))


def action_name(controller, action):
    try:
        return action.GetName(controller.GetStructuredFile())
    except Exception:
        try:
            return action.customName or ("EID_%d" % action.eventId)
        except Exception:
            return "EID_%d" % action.eventId


def collect_draws(controller, actions, marker_filter, inside=False, out=None):
    if out is None:
        out = []
    for a in actions:
        name = action_name(controller, a)
        child_inside = inside
        if marker_filter and name and marker_filter in name:
            child_inside = True
        is_draw = bool(a.flags & rd.ActionFlags.Drawcall)
        if is_draw and (child_inside or not marker_filter):
            out.append(a)
        if a.children:
            collect_draws(controller, a.children, marker_filter, child_inside, out)
    return out


def export_draw(controller, action, instance, out_dir, manifest_meshes, texture_cache):
    controller.SetFrameEvent(action.eventId, True)
    postvs = controller.GetPostVSData(instance, 0, rd.MeshDataStage.VSOut)
    if postvs is None or postvs.numIndices == 0:
        return None

    attrs = build_postvs_attrs(controller, postvs)
    if not attrs:
        return None

    indices = get_indices(controller, attrs[0])
    if len(indices) < MIN_INDICES:
        return None

    clip_attr = find_attr(
        attrs,
        lambda a: getattr(a, "_systemValue", None) == rd.ShaderBuiltin.Position
        or "SV_POSITION" in a.name.upper(),
    )
    local_attr = find_attr(attrs, is_local_pos_attr)
    world_attr = pick_world_pos_attr(controller, attrs, indices)
    uv_attr = find_attr(attrs, is_uv_attr)
    nrm_attr = find_attr(attrs, is_nrm_attr)

    # Also try VS inputs for local POSITION
    vs_inputs = build_vs_input_attrs(controller, action)
    vin_pos = find_attr(
        vs_inputs,
        lambda a: "POSITION" in a.name.upper() or a.name.upper() in ("POS", "ATTR0", "POSITION0"),
    )

    inv_vp = try_viewproj_inverse(controller)
    obj_m = try_object_matrix(controller)

    pos_source = None
    positions = []

    # 0) Unproject SV_Position with a fitted VP. Per-draw fit first (handles
    #    shadow / alternate cameras), else the scene-wide matrix.
    if clip_attr is not None and FIT_VIEWPROJ:
        # All instances of a draw share one transform to clip space.
        if action.eventId in DRAW_FIT_CACHE:
            draw_fit = DRAW_FIT_CACHE[action.eventId]
        else:
            draw_fit = fit_viewproj_from_attrs(controller, attrs, clip_attr, indices)
            DRAW_FIT_CACHE[action.eventId] = draw_fit
        if draw_fit is not None and draw_fit["rank"] == 0:
            solver = draw_fit["solver"]
            source = "unproject_draw_vp:%s" % draw_fit["attr"]
        else:
            solver = GLOBAL_INV_VP
            source = "unproject_scene_vp"
        if solver is not None:
            clip_raw = fetch_attr_values(controller, clip_attr, indices)
            if is_screen_space_clip(clip_raw) or not is_onscreen_clip(clip_raw):
                return None
            world = unproject_clip(solver, clip_raw)
            if world:
                xs = [p[0] for p in world]
                ys = [p[1] for p in world]
                zs = [p[2] for p in world]
                extent = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
                if extent <= MAX_WORLD_EXTENT:
                    positions = [to_blender_pos(p[0], p[1], p[2]) for p in world]
                    pos_source = source

    # 1) Unproject clip -> world (correct for skinned + rigid when VP known)
    if not positions and clip_attr is not None and inv_vp is not None:
        clip_raw = fetch_attr_values(controller, clip_attr, indices)
        for raw in clip_raw:
            if len(raw) < 4:
                continue
            # world_h = inv(ViewProj) * clip_xyzw; world = xyz/w
            hx, hy, hz, hw = mat4_mul_vec(inv_vp, (raw[0], raw[1], raw[2], raw[3]))
            if abs(hw) > 1e-8:
                x, y, z = hx / hw, hy / hw, hz / hw
            else:
                x, y, z = hx, hy, hz
            if x != x or y != y or z != z:
                positions = []
                break
            positions.append(to_blender_pos(x, y, z))
        if positions:
            pos_source = "unproject_viewproj"

    # 2) World/view interpolator from PostVS (GoT TEXCOORDn world xyz, etc.)
    if not positions and world_attr is not None:
        pos_raw = fetch_attr_values(controller, world_attr, indices)
        for raw in pos_raw:
            x, y, z = raw[0], raw[1], raw[2] if len(raw) > 2 else 0.0
            if x != x or y != y or z != z:
                positions = []
                break
            positions.append(to_blender_pos(x, y, z))
        if positions:
            pos_source = "world_interp:%s" % world_attr.name

    # 3) Named local/world attr * object matrix (BG3-style).
    # Do NOT multiply VS-input SNorm POSITION by a guessed cb0 matrix — that flattens GoT meshes.
    if not positions and local_attr is not None:
        pos_raw = fetch_attr_values(controller, local_attr, indices)
        for raw in pos_raw:
            lx = raw[0]
            ly = raw[1]
            lz = raw[2] if len(raw) > 2 else 0.0
            if obj_m is not None:
                x, y, z = transform_point(obj_m, lx, ly, lz)
                pos_source = "object_matrix"
            else:
                x, y, z = lx, ly, lz
                pos_source = "local"
            if x != x or y != y or z != z:
                positions = []
                pos_source = None
                break
            positions.append(to_blender_pos(x, y, z))

    # 4) Last resort: VS-input / local without object matrix (may stack at origin)
    if not positions and vin_pos is not None:
        pos_raw = fetch_attr_values(controller, vin_pos, indices)
        for raw in pos_raw:
            x, y, z = raw[0], raw[1], raw[2] if len(raw) > 2 else 0.0
            if x != x or y != y or z != z:
                positions = []
                break
            positions.append(to_blender_pos(x, y, z))
        if positions:
            pos_source = "vs_input_local"

    if not positions:
        return None

    if STRICT_VP and FIT_VIEWPROJ and not str(pos_source).startswith("unproject"):
        return None

    if MIN_MESH_SIZE > 0:
        xs = [p[0] for p in positions]
        ys = [p[1] for p in positions]
        zs = [p[2] for p in positions]
        if min(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)) < MIN_MESH_SIZE:
            return None

    if DEDUPE:
        sig = (len(positions),) + tuple(
            (round(p[0], 2), round(p[1], 2), round(p[2], 2))
            for p in positions[:8] + positions[-8:]
        )
        if sig in DEDUPE_SEEN:
            return None
        DEDUPE_SEEN[sig] = action.eventId

    normals = []
    if nrm_attr is not None:
        nrm_raw = fetch_attr_values(controller, nrm_attr, indices)
        for n in nrm_raw:
            nx, ny, nz = n[0], n[1], n[2] if len(n) > 2 else 0.0
            if obj_m is not None and pos_source == "object_matrix":
                nx, ny, nz = transform_dir(obj_m, nx, ny, nz)
            normals.append(to_blender_dir(nx, ny, nz))

    uvs = []
    if uv_attr is not None:
        uv_raw = fetch_attr_values(controller, uv_attr, indices)
        for u in uv_raw:
            uvs.append((u[0], u[1] if len(u) > 1 else 0.0))
    face_indices = list(range(len(positions)))
    name = "eid_%d_i%d" % (action.eventId, instance)
    obj_name = name + ".obj"
    obj_path = os.path.join(out_dir, obj_name)

    mtl_lib = None
    mtl_name = None
    albedo_file = None
    normal_file = None
    if EXPORT_TEXTURES:
        try:
            tex_infos = list_ps_textures(controller)
            albedo_info, normal_info = pick_material_maps(tex_infos)
            if albedo_info is not None:
                albedo_file = save_texture_file(controller, albedo_info, out_dir, texture_cache)
            if normal_info is not None:
                normal_file = save_texture_file(controller, normal_info, out_dir, texture_cache)
            if albedo_file or normal_file:
                mtl_name = "mat_%s" % name
                mtl_lib = name + ".mtl"
                write_mtl(os.path.join(out_dir, mtl_lib), mtl_name, albedo_file, normal_file)
        except Exception as e:
            print("  texture export skipped for %s: %s" % (name, e))

    write_obj(
        obj_path, name, positions, normals, uvs, face_indices,
        reverse_winding=FLIP_X,
        mtl_lib=mtl_lib,
        mtl_name=mtl_name,
    )

    info = {
        "file": obj_name,
        "event_id": action.eventId,
        "instance": instance,
        "num_indices": len(indices),
        "num_vertices": len(positions),
        "has_normals": bool(normals),
        "has_uvs": bool(uvs),
        "pos_source": pos_source,
        "albedo": albedo_file,
        "normal": normal_file,
        "mtl": mtl_lib,
        "action": action_name(controller, action),
    }
    manifest_meshes.append(info)
    return info


def export_scene(controller, out_dir):
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)

    roots = controller.GetRootActions()
    draws = collect_draws(controller, roots, MARKER_FILTER)
    if not draws and MARKER_FILTER:
        print("Marker filter %r matched 0 draws; falling back to all draws" % MARKER_FILTER)
        draws = collect_draws(controller, roots, None)

    draws = [d for d in draws if d.numIndices >= MIN_INDICES]
    if MAX_DRAWS > 0:
        draws = draws[:MAX_DRAWS]

    # The scene matrix must be fitted from the whole frame, not just the subset.
    fit_draws = draws
    if ONLY_EIDS:
        draws = [d for d in draws if d.eventId in ONLY_EIDS]

    print("Exporting %d draws (marker=%r min_indices=%d textures=%s) -> %s" % (
        len(draws), MARKER_FILTER, MIN_INDICES, EXPORT_TEXTURES, out_dir))

    global GLOBAL_INV_VP, GLOBAL_VP_INFO, DEDUPE_SEEN, DRAW_FIT_CACHE
    DEDUPE_SEEN = {}
    DRAW_FIT_CACHE = {}
    if FIT_VIEWPROJ:
        GLOBAL_INV_VP, GLOBAL_VP_INFO = fit_scene_viewproj(controller, fit_draws)
    else:
        GLOBAL_INV_VP, GLOBAL_VP_INFO = None, {}

    manifest = {
        "marker_filter": MARKER_FILTER,
        "min_indices": MIN_INDICES,
        "instance_mode": INSTANCE_MODE,
        "flip_yz": FLIP_YZ,
        "flip_x": FLIP_X,
        "unit_scale": UNIT_SCALE,
        "viewproj_fit": GLOBAL_VP_INFO,
        "export_textures": EXPORT_TEXTURES,
        "meshes": [],
        "errors": [],
        "textures": [],
    }

    texture_cache = {}
    t0 = time.time()
    for i, action in enumerate(draws):
        # Don't trust ActionFlags.Instanced: ExecuteIndirect draws report an
        # instance count without the flag, and would lose every instance but 0.
        ninst = max(1, int(getattr(action, "numInstances", 1) or 1))
        instances = range(ninst) if INSTANCE_MODE == "all" else [0]
        for inst in instances:
            try:
                info = export_draw(
                    controller, action, inst, out_dir, manifest["meshes"], texture_cache
                )
                if info:
                    print("[%d/%d] EID %d inst %d -> %s (%s, %d tris)%s" % (
                        i + 1, len(draws), action.eventId, inst, info["file"],
                        info["pos_source"], info["num_indices"] // 3,
                        (" tex=" + info["albedo"]) if info.get("albedo") else ""))
            except Exception as e:
                msg = "EID %d inst %d: %s" % (action.eventId, inst, e)
                print("ERROR", msg)
                manifest["errors"].append(msg)

    manifest["count"] = len(manifest["meshes"])
    manifest["elapsed_sec"] = round(time.time() - t0, 2)
    sources = {}
    for m in manifest["meshes"]:
        sources[m["pos_source"]] = sources.get(m["pos_source"], 0) + 1
    manifest["pos_source_counts"] = sources
    manifest["textures"] = sorted(set(v for v in texture_cache.values() if v))
    man_path = os.path.join(out_dir, "manifest.json")
    with open(man_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print("Done: %d meshes, %d textures in %.1fs -> %s" % (
        manifest["count"], len(manifest["textures"]), manifest["elapsed_sec"], man_path))
    return manifest


def load_capture(filename):
    cap = rd.OpenCaptureFile()
    result = cap.OpenFile(filename, "", None)
    if result != rd.ResultCode.Succeeded:
        raise RuntimeError("Couldn't open file: " + str(result))
    if not cap.LocalReplaySupport():
        raise RuntimeError("Capture cannot be replayed locally")
    result, controller = cap.OpenCapture(rd.ReplayOptions(), None)
    if result != rd.ResultCode.Succeeded:
        raise RuntimeError("Couldn't initialise replay: " + str(result))
    return cap, controller


def resolve_out_dir(capture_path, explicit=None):
    if explicit:
        return explicit
    base = os.path.splitext(os.path.basename(capture_path or "scene"))[0]
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "exports", base + "_meshes")
    return os.path.normpath(root)


def run_ui(pyrenderdoc):
    status = ""
    try:
        status = pyrenderdoc.GetCaptureFilename()
    except Exception:
        pass
    out_dir = resolve_out_dir(status or "scene")
    print("UI export ->", out_dir)

    def cb(controller):
        export_scene(controller, out_dir)

    pyrenderdoc.Replay().BlockInvoke(cb)


def run_headless(argv):
    if len(argv) < 2:
        print("Usage: python export_scene_meshes.py <capture.rdc> [out_dir]")
        sys.exit(1)
    capture = argv[1]
    out_dir = resolve_out_dir(capture, argv[2] if len(argv) > 2 else None)

    rd.InitialiseReplay(rd.GlobalEnvironment(), [])
    cap, controller = load_capture(capture)
    try:
        export_scene(controller, out_dir)
    finally:
        controller.Shutdown()
        cap.Shutdown()
        rd.ShutdownReplay()


if "pyrenderdoc" in globals() and pyrenderdoc is not None:
    run_ui(pyrenderdoc)
elif __name__ == "__main__":
    run_headless(sys.argv)
