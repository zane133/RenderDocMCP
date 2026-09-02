# Reference — RenderDoc MCP tools

Output shapes match the RenderDocMCP server (mcp_server/server.py +
renderdoc_extension/services/). Field names are what the bridge returns.

## Capture lifecycle

- `list_captures(directory)` → `[{filename, path, size_bytes, modified_time}]`
- `open_capture(capture_path)` → closes any current capture, loads the .rdc
- `get_capture_status` → check a capture is loaded before analysis

## Frame overview

`get_frame_summary` →

```json
{ "api": "Vulkan", "total_actions": 1515,
  "statistics": {"draw_calls": 1162, "dispatches": 126, "clears": 8,
                 "copies": 20, "presents": 1, "markers": 55},
  "top_level_markers": [{"name": "...", "event_id": 12, "child_count": 94}],
  "resource_counts": {"textures": 704, "buffers": 726} }
```

## Draw tree

`get_draw_calls(include_children, marker_filter, exclude_markers, event_id_min,
event_id_max, only_actions, flags_filter)` → `{"actions": [tree]}`

- Actions are hierarchical; markers (PushMarker/SetMarker) are parents of draws.
- `marker_filter` / `exclude_markers` are partial matches on marker names.
- `flags_filter` values: Drawcall, Dispatch, Clear, Copy, Present, and marker
  flags; combine with `only_actions` to strip markers from the tree.
- **Always filter** (marker_filter or event ranges) on large frames.

## Locating draws

- `find_draws_by_shader(shader_name, stage)` — partial match on shader name /
  entry point; returns event IDs + match reasons. Stage: vertex/hull/domain/
  geometry/pixel/compute.
- `find_draws_by_texture(texture_name)` — partial match on texture resource
  names; searches SRVs, UAVs, render targets.
- `find_draws_by_resource(resource_id)` — exact resource ID match; searches
  shaders, SRVs, UAVs, RTs, depth.
- `get_draw_call_details(event_id)` →
  `{event_id, name, flags, num_indices, num_instances, base_vertex,
  vertex_offset, instance_offset, index_offset, outputs:[{index, resource_id}],
  depth_output}`

## Pipeline state

`get_pipeline_state(event_id)` → `{event_id, api, shaders, viewports,
render_targets, depth_target, input_assembly}`

- `shaders` is keyed by stage; each entry:
  `{resource_id, entry_point, resources[], uavs[], samplers[], constant_buffers[]}`
- SRV/UAV entries: `{slot, name, resource_id, resource_name, type, width,
  height, depth, array_size, mip_levels, format, dimension, msaa_samples,
  first_mip, num_mips, first_slice, num_slices}`
- Samplers: `{slot, name, address_u/v/w, filter, max_anisotropy, min_lod,
  max_lod, mip_lod_bias, border_color, compare_function}`
- CBs: `{slot, name, byte_size, variable_count, variables:[{name, byte_offset,
  type}]}`
- RTs: `[{index, resource_id}]`; `depth_target` is a resource ID.

## Shader info

`get_shader_info(event_id, stage)` → `{resource_id, entry_point, stage,
disassembly, constant_buffers, resources}`

- **`disassembly` is assembly, not HLSL** — DXBC asm on D3D11/12, SPIR-V/GLSL
  on Vulkan. It is the source of truth for math; reconstruct HLSL from it.
- `constant_buffers`: `{name, slot, size, variables}` where variables carry
  **values** (serialized) — use them to name constants in readable HLSL.
- `resources`: `{name, type, binding, access}` — the register ↔ name map.

## Textures / buffers

- `get_texture_info(resource_id)` → dimensions, format, mips, array size,
  dimension, MSAA samples.
- `get_texture_data(resource_id, mip, slice, sample, depth_slice)` →
  `{width, height, depth, mip, slice, sample, depth_slice, format, dimension,
  is_3d, total_depth, data_length, content_base64}` — pixels are **raw bytes**
  (base64), not PNG. Decode and interpret by `format` (e.g. RGBA8 → 4 bytes/px);
  write with Pillow if available.
  - Cube maps: slice 0..5 = X+, X-, Y+, Y-, Z+, Z-.
  - 3D textures: pass `depth_slice` to get one 2D slice.
  - Out-of-range mip/slice/sample is an error — check `get_texture_info` first.
- `get_buffer_contents(resource_id, offset, length)` → base64 bytes.

## Timings

`get_action_timings(event_ids, marker_filter, exclude_markers)` →
`{available, unit, timings:[{event_id, name, duration_seconds,
duration_ms}], total_duration_ms, count}` — or
`{available: false, error: "GPU timing counters not supported..."}` when the
driver/capture cannot provide counters. Report unavailable honestly.

## Gotchas

- Marker event IDs exist, but for pipeline/shader queries use a **draw's** event
  ID inside that marker.
- CB reflection values only exist when the capture has the binding; a missing
  stage returns "No X shader bound" — expected, not a bug.
- Do not trust disassembly register names as HLSL; rebuild semantics from the
  input signature (see shader-restoration.md).
