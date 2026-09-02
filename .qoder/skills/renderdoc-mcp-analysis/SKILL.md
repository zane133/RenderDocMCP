---
name: renderdoc-mcp-analysis
description: >-
  Analyzes RenderDoc captures through the RenderDoc MCP server (frame overview
  and render-flow, draw-call tree with markers, pipeline state, shader
  disassembly with constant-buffer values, texture/buffer export, GPU timings),
  then turns decompiled shaders (3Dmigoto HLSL dumps or MCP disassembly) into
  human-readable HLSL that still compiles via RenderDoc Apply Changes. Use when
  the user wants to analyze a .rdc capture, understand a render pass or render
  flow, find draws using a shader/texture, make a decompiled shader readable,
  fix RenderDoc Apply Changes compile errors, or export textures/meshes/timings.
---

# RenderDoc MCP — Frame Analysis + Shader Readable

Goal: analyze a RenderDoc capture through the MCP server (frame structure,
passes, pipeline, shaders, resources, timings), then produce HLSL that is
(1) **human-readable**, (2) **mathematically faithful** to the binary, and
(3) **compiles with RenderDoc Apply Changes**.

## MCP tool map

| Need | Tool |
|---|---|
| Load a capture | `list_captures(dir)` → `open_capture(path)` → `get_capture_status` |
| Frame stats + top markers | `get_frame_summary` |
| Draw tree / markers | `get_draw_calls` (use `marker_filter`, `only_actions`, `flags_filter`) |
| Find draw by shader | `find_draws_by_shader(name, stage)` |
| Find draw by texture / resource | `find_draws_by_texture` / `find_draws_by_resource` |
| Draw details | `get_draw_call_details(event_id)` |
| Full pipeline at an event | `get_pipeline_state(event_id)` |
| Shader disasm + CB values | `get_shader_info(event_id, stage)` |
| Textures / buffers | `get_texture_info` / `get_texture_data` / `get_buffer_contents` |
| GPU timing | `get_action_timings` |

Tool output shapes and gotchas: [references/mcp-tools.md](references/mcp-tools.md).

## Non-negotiables

1. **Binary match first, readability second.** Never "clean up" math until a
   register-faithful version has been Apply-verified against the original frame.
2. **Bindings are by register, not name.** Renaming `t1` → `texNoise` is fine
   while `: register(t1)` stays; never reshape `cbuffer` packing.
3. **Validate in RenderDoc** after each major rewrite (Apply Changes → compare
   to pre-edit capture).
4. **The fresh data is the source of truth.** Process the dump the user just
   pasted / the disassembly just fetched. Do not reuse an older `*_readable.hlsl`
   that "looks the same".
5. **Context economy.** Filter draw trees (`marker_filter`, ranges, `only_actions`);
   never dump a whole 1000+ draw frame into context.

## Workflow (copy and track)

```
Progress:
- [ ] 0. Load capture
- [ ] 1. Frame overview + render flow
- [ ] 2. Locate target draw
- [ ] 3. Extract shader + pipeline data
- [ ] 4. Register-faithful HLSL  ← STOP: Apply Changes, must match
- [ ] 5. Readable rewrite (only after match OK)
- [ ] 6. Optional: STEP_*/DEBUG_VIS, asset export
```

### Step 0 — Load capture

`list_captures(<dir>)` to find the `.rdc`, then `open_capture(path)`; confirm
with `get_capture_status`.

### Step 1 — Frame overview + render flow

- `get_frame_summary`: API type, action counts, top-level markers with event IDs,
  resource counts.
- Walk `get_draw_calls` per top marker (or with `marker_filter`) to map pass
  structure; for each pass, count draws and read render targets via
  `get_pipeline_state` on a representative draw.
- If the user asks for an overview document, deliver a render-flow summary
  (marker → pass → ops) as a mermaid graph, like `render_flow.md`.
- Optional `get_action_timings` (with `marker_filter`) for hot passes. If
  `available: false`, GPU timing is unsupported on this capture — say so
  instead of guessing.

### Step 2 — Locate target draw

- Known shader: `find_draws_by_shader(name, stage)` → pick the event in the
  pass of interest.
- Known texture: `find_draws_by_texture` / `find_draws_by_resource`.
- `get_draw_call_details(event_id)` for indices/instances/outputs, and
  `get_pipeline_state(event_id)` for the full binding context (all stages,
  SRVs/UAVs/samplers/CBs, render targets, depth, viewports, IA topology).

### Step 3 — Extract shader data

- `get_shader_info(event_id, stage)` → `disassembly` (**assembly, not HLSL**),
  `constant_buffers` (with values), `resources` (bindings). Save the
  disassembly to a file to rewrite from.
- Build the resource/CB map (register ↔ name ↔ resource_id ↔ value) needed for
  the HLSL rewrite.

### Step 4 — Register-faithful HLSL (must compile)

Source A — user pasted a 3Dmigoto HLSL dump:

```bash
python <this-skill>/scripts/patch_dump_for_renderdoc.py input.hlsl -o out_renderdoc.hlsl
```

then hand-fix leftovers the script does not cover (see
[references/shader-restoration.md](references/shader-restoration.md)):
`ubfe`/`asuint`, `SampleGrad` `.xy`, broken TEXCOORD splits, etc.

Source B — only MCP disassembly available: reconstruct HLSL
register-by-register (`r0/r1…`), explicit `register(tN/sN/bN)`, semantics from
the draw's input signature; use CB values to name constants.

**Do not** in this step: rename resources, reshape CBs, extract helpers, add
STEP_*, delete VT/volume paths, or port logic from another readable file.

Deliverable: register-faithful HLSL + a short note of patches only.

**STOP — the user pastes it into RenderDoc, Apply Changes, and compares to the
original draw. Wait for explicit OK (`没问题` / `继续` / match OK) before Step 5.**

### Step 5 — Incremental readability (only after Step 4 OK)

Prefer clarity **without** changing ops:

1. Section comments on the verified register version.
2. Named locals (`modelUV`, `fresnel`) — same expressions.
3. CB field aliases / `struct Material` + `LoadMaterial()` — keep `float4 cbN[]`.
4. Extract `Eval*` helpers — body math unchanged.
5. Readable texture/sampler **names** (registers stay).

**Dense / fragile blocks** (VT page table, 8-tap cubic volume, bit packing):
keep the Apply-verified register body inside the helper; do not re-derive
weights from scratch.

Prefer `exp2(k*log2(x))` over `pow` when the dump used log/exp.
Prefer `a + t*(b-a)` / `lerp` only when algebraically identical to the dump.

### Step 6 — Optional

- **STEP_*/DEBUG_VIS harness** per
  [references/shader-restoration.md](references/shader-restoration.md):
  STEP off = true identity (factor `0`), never `log=0` (→ `exp2(0)=1` → blown
  white). DEBUG_VIS = pre-combine intermediates.
- **Asset export**: `get_texture_info` → `get_texture_data` (base64 → decode and
  write to a file), `get_buffer_contents`. If the RenderDocMCP project
  (`F:\13_MCP_AI\RenderDocMCP`) is present, its UI-python scripts handle bulk
  export: `qrenderdoc <cap.rdc> --ui-python scripts/export_scene_meshes.py`,
  then `scripts/export_draw_textures.py` (writes `draw_textures.json`), then
  `scripts/attach_materials_to_blend.py` for the Blender scene.

## Hard gates (do not skip)

| After… | Agent must… |
|--------|-------------|
| Step 4 written | **Stop.** Tell user to Apply Changes and compare. Wait for confirmation (`没问题` / `继续` / match OK). |
| User confirms match | Only then Step 5 → Step 6. |
| User says "继续" | Advance **one** unfinished workflow step (usually 5, then 6). |
| Visual mismatch | Revert toward register/`r0` form; fix; re-Apply. No further renaming. |

## Anti-patterns (this skill fails when…)

- Jumping straight to `LoadMaterial` / `Eval*` / `STEP_*` before Apply-verified Step 4.
- Treating a new paste/disassembly as "same as last hand SSS / grass" and
  shipping the old readable file.
- Removing VT / volume / other paths without an explicit user ask (Step 6 only).
- "Helpful" rewrite of dense blocks (cubic volume taps, VT page-table) that
  diverges from disassembly registers.
- Replacing `exp2(k*log2(x))` with `pow`, or inventing `lerp` that is not
  identical to the dump `mad`.
- Treating MCP `disassembly` as HLSL and "cleaning it up" directly.
- Unfiltered `get_draw_calls` on a large frame (context blow-up).

## Output expectations

Each step delivers a `.hlsl` ready to paste into RenderDoc (shader work) or a
short analysis doc, plus a note covering: what was patched/rewritten, what was
removed (if anything), how to use STEP_*/DEBUG_VIS (if added), what the user
should do next (Apply / confirm / continue), risks (shared shader object
affects all draws using it).

## Resources

- [references/mcp-tools.md](references/mcp-tools.md) — tool outputs, semantics, gotchas
- [references/shader-restoration.md](references/shader-restoration.md) — cmp/SV_*/SampleGrad/ubfe fixes, STEP identities, checklist
- [scripts/patch_dump_for_renderdoc.py](scripts/patch_dump_for_renderdoc.py) — cmp + SV_* automation (Step 4 partial; always hand-fix ubfe / SampleGrad / asuint)
