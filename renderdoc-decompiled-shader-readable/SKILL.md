---
name: renderdoc-decompiled-shader-readable
description: >-
  Turns 3Dmigoto/RenderDoc decompiled HLSL into human-readable shaders that still
  compile via RenderDoc Apply Changes. Use when the user pastes a 3Dmigoto dump,
  asks to make a shader readable, fix RenderDoc Apply Changes compile errors,
  add STEP_*/DEBUG_VIS analysis switches, or mentions decompiled PS/VS HLSL,
  #define cmp -, SV_Position0, or ubfe/SampleGrad truncation warnings.
---

# RenderDoc Decompiled Shader → Readable + Compilable

Goal: take a **3Dmigoto / RenderDoc decompiled** shader and produce HLSL that is
(1) **human-readable**, (2) **mathematically faithful** to the binary, and
(3) **compiles with RenderDoc Apply Changes**.

## Non-negotiables

1. **Binary match first, readability second.** Never “clean up” math until a
   register-faithful version has been Apply-verified against the original frame.
2. **Keep bindings and signatures.** Explicit `register(tN/sN/bN)`, input/output
   semantics and types must stay link-compatible with the bound VS/PS.
3. **Validate in RenderDoc** after each major rewrite (Apply Changes → compare
   to pre-edit capture).
4. **The paste is the source of truth.** Always process **the dump the user
   just pasted**. Do not skip Step 1 because an existing `*_readable.hlsl`
   “looks the same”, and do not overwrite with an old analysis rewrite first.

## Hard gates (do not skip)

| After… | Agent must… |
|--------|-------------|
| Step 1 written | **Stop.** Tell user to Apply Changes and compare. Wait for confirmation (`没问题` / `继续` / match OK). |
| User confirms match | Only then Step 3 (if asked) → Step 4 → Step 5 → Step 6. |
| User says “继续” | Advance **one** unfinished workflow step (4 → 5 → 6). |
| User asks 人类可读 / 优化 rx / 翻译 cb | Run **Step 6** (after Step 5 or Step 4 OK). |
| Visual mismatch | Revert toward register/`r0` form; fix; re-Apply. No further renaming. |

## Anti-patterns (this skill fails when…)

- Jumping straight to `LoadMaterial` / `Eval*` / `STEP_*` before Apply-verified Step 1.
- Treating a new paste as “same as last hand SSS / grass” and shipping the old readable file.
- Removing VT / volume / other paths without an explicit user ask (Step 3 only).
- “Helpful” rewrite of dense blocks (cubic volume taps, VT page-table) that diverge from dump registers.
- Replacing `exp2(k*log2(x))` with `pow`, or inventing `lerp` that is not identical to dump mad.

## Workflow (copy and track)

```
Progress:
- [ ] 1. Ingest dump + minimal RenderDoc patch
- [ ] 2. User Apply Changes — must match original visually  ← STOP until OK
- [ ] 3. Optional: remove dead paths (user-requested only)
- [ ] 4. Incremental readable rewrite
- [ ] 5. Optional: STEP_*/DEBUG_VIS analysis harness
- [ ] 6. Optional: human-readable semantic pass (no rN / named CBs)
```

### Step 1 — Minimal patch (must compile)

Start from **the pasted dump** (write it to the target `.hlsl` if needed). Prefer the
bundled script, then **hand-fix leftovers** the script does not cover:

```bash
python <this-skill>/scripts/patch_3dmigoto_for_renderdoc.py input.hlsl -o out_renderdoc.hlsl
```

Required fixes (see [reference.md](reference.md)):

| Dump artifact | RenderDoc-safe replacement |
|---|---|
| `#define cmp -` | `float cmp(bool v) { return v ? -1.0 : 0.0; }` (+ float2/3/4 overloads) |
| `SV_Position0` / `SV_Target0` / `SV_VertexID0` / `SV_InstanceID0` | drop the trailing `0` |
| `Texture2DArray.SampleGrad(..., float3/scalar)` | pass **`.xy`** from full ddx/ddy regs (X3206 + faithfulness) |
| Page-table / packed uint loads | `asuint(...)` + `ubfe`/shifts/`&`, not `(uint)floatValue` |
| DXBC `ubfe` as huge `if (10==0)` | replace with bitfield extract via `asuint` |

**Do not** in this step: rename resources, reshape CBs, extract helpers, add STEP_*,
delete VT/volume, or port logic from another readable file.

Deliverable: register-faithful HLSL (`r0/r1…` OK) + short note of patches only.

### Step 2 — Prove faithfulness

- User pastes into RenderDoc → **Apply Changes**.
- Compare to unmodified draw (side-by-side / histogram / pixel history).
- Agent waits for explicit OK before Step 4/5.

Common divergence causes: wrong `SampleGrad` arity, `(uint)` vs `asuint`,
reordered `mad`/`lerp`, `pow` instead of `exp2(k*log2(x))`, broken TEXCOORD
split (`float2 v6` + `float w6`), over-cleaned volume/VT math.

### Step 3 — Optional path removal

Only when the user asks (e.g. drop volumetric light / VT):

- Delete code **and** unused `Texture*` / `SamplerState` / `cbuffer` decls.
- **Keep unused interpolators** in `main` if the VS still writes them.
- Re-Apply and confirm the remaining look is intended.

### Step 4 — Incremental readability

Only after Step 2 OK. Prefer clarity **without** changing ops:

1. Section comments on the verified register version (optional quick pass).
2. Named locals (`modelUV`, `fresnel`) — same expressions.
3. CB field aliases / `struct Material` + `LoadMaterial()` — keep `float4 cbN[]`.
4. Extract `Eval*` helpers — body math unchanged.
5. Readable texture/sampler **names** (registers stay the same).

**Dense / fragile blocks** (VT page table, 8-tap cubic volume, bit packing): prefer
keeping **register-faithful code inside the helper** (copy verified Step 1 body)
rather than re-deriving weights from scratch.

Prefer `exp2(k*log2(x))` over `pow` when the dump used log/exp.
Prefer `a + t*(b-a)` / `lerp` only when algebraically identical to the dump.

### Step 5 — Analysis harness (optional)

When studying stages (often with “继续” after Step 4), add file-top switches:

```hlsl
#define STEP1_... 1
#define DEBUG_VIS 0  // 0=final, 1..N=intermediate
```

Each STEP:

- Default **on** = original behavior.
- **Off** = true identity / no contribution — **not** “peak of the curve”.

**Critical:** if a term is `mix * exp2(k * log(falloff))`, disabling the falloff
stage must set that term’s factor to **0**, not `log=0` (→ `exp2(0)=1` → blown
white). Document next to the switch.

`DEBUG_VIS` = **pre-combine** intermediates (e.g. ramp before mask, color before volume).

**DEBUG_VIS tip:** capture rim / fresnel values **at the rim site** — later fog/lights
often clobber the same `rN` before return (e.g. `1-|N·V|` all-white bug).

### Step 6 — Human-readable semantic pass (optional)

When the user asks for **人类可读** / **优化 rx** / **翻译 cb** / a compact TA file
(often after Step 5, or after Step 4 if no analysis harness):

Deliverable: `*_readable.hlsl` (or similar) that a TA can read top-to-bottom.

**Goals**

1. **No `r0`/`r1`… soup** in the body — semantic locals only (`viewDir`, `N`,
   `litDirect`, `rimTerm`, `gi`, …).
2. **No bare `cb0[186].z` in the body** — alias once at top of `main` (or in a
   small param block), then use names (`sunDir`, `albedoLitScale`, …).
3. Keep `float4 cbN[]` packing + `register(tN/sN/bN)` — aliases only, no
   `packoffset` reshape unless proven safe.
4. **Do not const-copy interpolators** `v0..vN` into locals for the whole shader —
   that previously dropped rim / facing. Comment them; use `v*` directly.
5. Line budget: if user asks (e.g. ≤500), drop paths they named (probe / detail /
   tiled lights / fog) with identity comments; keep the recipe they care about
   (material → normal → F0 → sun/Ramp → rim → IBL → grade → exposure).

**Alias block pattern (top of `main`)**

```hlsl
// Named CB aliases (inferred). Left = meaning; right = dump slot.
float3 sunDir         = cb0[6].xyz;    // key / sun direction
float3 cameraPos      = cb0[44].xyz;
float  exposure       = cb0[109].x;
float3 rimColor       = cb0[194].xyz;
float  rimIntensity   = cb0[194].w;
float  albedoLitScale = cb0[186].z;
float  envIblScale    = cb0[186].w;
// …material cb5 → normalStrength, brdfLutBlend, gradeSat, …
```

**Body uses only names** — helpers take named args (`EvalViewDir(worldPos,
cameraPos, camForward, viewBend)`), not raw `cb0[…]` inside.

**Naming heuristics (infer; comment uncertainty)**

| Dump use | Prefer name |
|----------|-------------|
| Main/key light direction | `sunDir` / `mainLightDir` |
| Camera world position | `cameraPos` |
| Exposure / tonemap scale | `exposure` |
| Rim colour / intensity / width | `rimColor`, `rimIntensity`, `rimWidth` |
| Albedo / env / IBL scales | `albedoLitScale`, `envIblScale`, `skyLitScale` |
| Screen AO blend | `screenAoBlend` |
| Material normal strength | `normalStrength` |
| Color-grade enable/sat/contrast | `gradeEnable`, `gradeSat`, `gradeContrast` |

**Anti-patterns for Step 6**

- Leaving half-finished `rN` + “wrong; correct is…” comments in the body.
- Inventing `lerp`/`pow` while renaming.
- Claiming binary-perfect match after heavy path removal — call it **recipe-faithful**,
  keep Step 5 as the Apply-faithful reference.

After Step 6: tell user to Apply the readable file and spot-check rim / Ramp /
exposure; full lights/fog still live in `*_step5_analysis.hlsl`.

## Output expectations

Each step deliver a `.hlsl` ready to paste into RenderDoc, plus a short note:

- What was patched / rewritten this step
- What was removed (if anything)
- How to use STEP_*/DEBUG_VIS (if added)
- For Step 6: alias table summary + which paths were dropped
- What the user should do next (Apply / confirm / continue)
- Risks (shared shader object affects all draws using it)

## Additional resources

- Pitfalls, signatures, bit ops, STEP identities, Step 6 naming: [reference.md](reference.md)
- Patch script: [scripts/patch_3dmigoto_for_renderdoc.py](scripts/patch_3dmigoto_for_renderdoc.py)
  (cmp + SV_* only; always hand-fix ubfe / SampleGrad / asuint)
