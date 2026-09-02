# Reference — RenderDoc / 3Dmigoto shader restoration

## RenderDoc Apply Changes constraints

- Compiler is effectively FXC/DXBC-oriented for D3D11 captures.
- Resource binding is by **register**, not HLSL name — renaming `t1` → `texNoise` is fine if `: register(t1)` stays.
- Changing `cbuffer` packing (`float4 cb1[15]` → individually named fields without `packoffset`) can silently break layouts. Prefer:

  ```hlsl
  cbuffer MaterialCB : register(b1) { float4 cb1[15]; }
  // then alias: float fresnelWrap = cb1[2].w;
  ```

- Input signature must match the paired stage. 3Dmigoto often splits one VS `float3 o6` into PS `float2 v6 : TEXCOORD5` + `float w6 : TEXCOORD6`. Keep that split.
- Unused parameters (`SV_Position`, extra TEXCOORDs) may still be required for signature matching after path removal.

## `#define cmp -`

3Dmigoto emits comparisons as `cmp(expr)` expecting **true → -1, false → 0** (DXBC-style).

```hlsl
// BAD — breaks types / warnings
#define cmp -

// GOOD
float  cmp(bool  v) { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }
float3 cmp(bool3 v) { return v ? -1.0.xxx : 0.0.xxx; }
float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }
```

Patterns:

```hlsl
r = cmp(a < b);
if (r != 0) discard;           // discard when a < b

keep = cmp(0 != flag) ? 0 : 1; // kill color when flag != 0
```

## Semantics

| Dump | Apply Changes |
|------|-----------------|
| `SV_Position0` | `SV_Position` |
| `SV_Target0` | `SV_Target` |
| `SV_VertexID0` | `SV_VertexID` |
| `SV_InstanceID0` | `SV_InstanceID` |

## SampleGrad / derivatives

DXBC `sample_d` on `texture2darray` may show 3-component ddx/ddy. HLSL
`Texture2DArray::SampleGrad` wants **float2** ddx/ddy:

```hlsl
// warning X3206: implicit truncation
t.SampleGrad(s, uvw, ddx3, ddy3);

// dump often emits scalars — not DXBC-faithful
t.SampleGrad(s, uvw, r4.x, r2.x);

// OK: use the full derivative regs computed just above
t.SampleGrad(s, uvw, r4.xy, r2.xy);
```

## Bitfields (`ubfe`) and typeless loads

For page tables / packed R32 data:

```hlsl
uint packed = asuint(tex.Load(int3(x, y, mip)).x);
uint a = (packed >> 14) & 1023u; // ubfe width=10, offset=14
uint b = packed & 15u;

// or helper matching DXBC ubfe(width, offset, src):
uint ubfe(uint width, uint offset, uint src) { ... }
```

Avoid `(uint)floatReg` — that is a **numeric** convert, not a bitcast.

3Dmigoto `t125[i].val[32/4]` style indices are **byteOffset/4** — keep as-is (or
comment the byte origin); do not “simplify” to wrong indices.

## Faithful math helpers

```hlsl
// Dump: exp2(k * log2(x)) with x already max(abs(x), eps)
float Pow2(float x, float k) { return exp2(k * log2(x)); }
```

Only replace with `pow(x,k)` if you have verified identical results on the draw.

`mad(a,b,c)` ↔ `a*b+c`.  
`a + t*(b-a)` ↔ `lerp(a,b,t)` only when identical.

## Fragile blocks — keep register body

When extracting helpers for:

- Virtual texture page-table + atlas `SampleGrad`
- Volumetric / 3D texture cubic B-spline (many taps + weight regs)

…copy the **Apply-verified Step 1 register path** into the helper. Do not
re-derive cubic weights from memory; small mad order mistakes break the look.

Rename textures/samplers around that body; leave the math lines dump-shaped.

## STEP disable identities (analysis harness)

| Kind of term | Wrong “off” | Right “off” |
|--------------|-------------|-------------|
| Multiplicative mask | leave at peak (1) everywhere without documenting | `1` if “no attenuation”, or keep computing but skip multiply — be explicit |
| Additive `mix * exp2(k*log(f))` | `log=0` → factor `1` → **full mix everywhere** | factor **`0`** |
| Fresnel / wrap | — | `1.0` |
| Opacity / discard | — | `opacity=1`, skip discard |
| Color stage | — | white/grey to inspect alpha only |
| VT branch | — | fall back to non-VT sample (e.g. `t4`) |
| Volume add | — | `transmittance=1`, `volumeRgb=0` |

Always comment the chosen identity next to `#define STEP…`.

## Suggested readable structure

```hlsl
// 1. Resources + registers
// 2. cmp / ubfe / math helpers
// 3. Material struct + LoadMaterial() from cb arrays
// 4. Stage functions (Eval*) — fragile blocks = register body
// 5. main: STEP switches → recipe → DEBUG_VIS output
```

## Session checklist

- [ ] Worked from **this paste**, not an old readable file
- [ ] Step 1 only: cmp / SV_* / asuint+ubfe / SampleGrad `.xy`
- [ ] Stopped for user Apply + visual match before Step 4/5
- [ ] Compiles; X3206 gone or understood
- [ ] Signature still matches VS (`float2`+`float` TEXCOORD split kept)
- [ ] No path removal unless user asked
- [ ] STEP off does not blow white; DEBUG_VIS is pre-combine
- [ ] Dense VT/volume helpers still match Step 1 math
