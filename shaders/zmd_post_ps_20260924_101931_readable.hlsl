// ---- Created with 3Dmigoto v1.4.6 on Thu Sep 24 10:19:31 2026
// RenderDoc EID 2084 — post-process pixel shader
// STEP 6: human-readable semantic pass. No rN in the body, named CB aliases.
//
// Pipeline: CAS sharpen -> exposure -> bloom compose -> vignette -> colour LUT
//           -> linear-to-sRGB -> ordered dither.
//
// No paths were removed; every stage of the dump is still here.
// Apply-faithful reference with analysis switches: *_step5_analysis.hlsl
//
// CHANNEL ORDER NOTE
// After the sharpen stage the dump carries colour as (B, R, G) — see the .zxy
// swizzles on every neighbour tap. Everything between sharpen and the LUT
// lookup stays in that order, and the LUT resolves it back to RGB because the
// blue component selects the slice. Locals in BRG order are named *BRG.

Texture2D<float4> ColorInput : register(t0);
Texture2D<float4> BloomInput : register(t1);
Texture2D<float4> ColorLut   : register(t2);
SamplerState LinearSampler   : register(s0);

cbuffer PostProcessMaterial : register(b1)
{
  float4 cb1[25];
}

cbuffer FrameConstants : register(b0)
{
  float4 cb0[110];
}

// Reorder natural RGB into the dump's working (B, R, G) layout.
float3 ToBRG(float3 rgb) { return rgb.zxy; }

// CAS luminance proxy: g + 0.5*r + 0.5*b, in the dump's mad order.
float CasLuma(float3 rgb) { return rgb.b * 0.5 + (rgb.r * 0.5 + rgb.g); }

// --------------------------------------------------------------------------
// Contrast-adaptive sharpening over the centre tap and four axial neighbours.
// Returns the sharpened colour in BRG order; centre alpha comes back separately.
// --------------------------------------------------------------------------
float3 EvalSharpen(float2 uv, float2 invViewport, float sharpenStrength, out float centerAlpha)
{
  float4 center = ColorInput.SampleLevel(LinearSampler, uv, 0);
  centerAlpha = center.w;

  float2 left  = uv - float2(invViewport.x, 0);
  float2 up    = uv - float2(0, invViewport.y);
  float2 down  = uv + float2(0, invViewport.y);
  float2 right = uv + float2(invViewport.x, 0);

  float3 tapLeft  = ColorInput.SampleLevel(LinearSampler, left,  0).xyz;
  float3 tapUp    = ColorInput.SampleLevel(LinearSampler, up,    0).xyz;
  float3 tapDown  = ColorInput.SampleLevel(LinearSampler, down,  0).xyz;
  float3 tapRight = ColorInput.SampleLevel(LinearSampler, right, 0).xyz;

  float lumaCenter = CasLuma(center.xyz);
  float lumaLeft   = CasLuma(tapLeft);
  float lumaDown   = CasLuma(tapDown);
  float lumaRight  = CasLuma(tapRight);
  float lumaUp     = CasLuma(tapUp);

  // Local luminance range, used to soften sharpening across strong edges.
  float lumaMax = max(max(lumaRight, lumaUp), max(lumaDown, max(lumaLeft, lumaCenter)));
  float lumaMin = min(min(lumaRight, lumaUp), min(lumaDown, min(lumaLeft, lumaCenter)));

  float neighborLumaSum = ((lumaDown + lumaLeft) + lumaRight) + lumaUp;
  float lumaDelta       = neighborLumaSum * 0.25 + -lumaCenter;
  float invLumaRange    = 1 / (lumaMax - lumaMin);
  float edgeAttenuation = saturate(invLumaRange * abs(lumaDelta)) * -0.5 + 1;

  // Per-channel headroom: how much can be pulled without clipping either end.
  float3 maxNeighbor = max(max(max(tapRight, tapLeft), tapDown), tapUp);
  float3 minNeighbor = min(min(min(tapRight, tapLeft), tapDown), tapUp);

  float3 amplifyLimit = minNeighbor * (float3(0.25, 0.25, 0.25) / maxNeighbor);

  // Reciprocal-then-multiply, matching the dump's rounding.
  float3 invClipRange = float3(1, 1, 1)
                      / (minNeighbor * float3(4, 4, 4) + float3(-4, -4, -4));
  float3 clipHeadroom = (float3(1, 1, 1) - maxNeighbor) * invClipRange;
  float3 perChannel   = max(clipHeadroom, -amplifyLimit);

  // Sharpen weight is negative; clamped to CAS's [-0.1875, 0] range.
  float weight = max(perChannel.x, max(perChannel.y, perChannel.z));
  weight = max(-0.1875, min(0, weight));
  weight = sharpenStrength * weight * edgeAttenuation;

  float3 neighborSumBRG = ((ToBRG(tapDown) + ToBRG(tapLeft)) + ToBRG(tapUp)) + ToBRG(tapRight);
  float3 sharpenedBRG   = weight * neighborSumBRG + ToBRG(center.xyz);

  float normalize = 1 / (weight * 4 + 1);
  return normalize * sharpenedBRG;
}

// --------------------------------------------------------------------------
// Soft-knee highlight extraction. Returns the fraction of the exposed colour
// that counts as "highlight" and therefore gets handed over to the bloom texture.
// threshold: x = hard knee start, y = knee toe, z = knee width, w = knee scale.
// --------------------------------------------------------------------------
float HighlightFraction(float3 exposedBRG, float4 threshold)
{
  float peak      = max(max(exposedBRG.y, exposedBRG.z), exposedBRG.x);
  float overToe   = peak - threshold.y;
  float overStart = peak - threshold.x;

  float knee = min(threshold.z, max(0, overToe));
  knee = threshold.w * (knee * knee);
  knee = max(knee, overStart);

  return knee / max(9.99999975e-05, peak);
}

// Bloom texture shaping: compress anything above the visible knee with a
// pow(x, 0.33) curve, keep the raw value below it.
float3 ShapeBloomSource(float3 bloomBRG, float highlightMix)
{
  float3 compressed = exp2(float3(0.330000013, 0.330000013, 0.330000013) * log2(bloomBRG));
  compressed = compressed * float3(1.49380004, 1.49380004, 1.49380004)
             + float3(-0.699999988, -0.699999988, -0.699999988);

  bool3 useCompressed = float3(0.300000012, 0.300000012, 0.300000012) < bloomBRG * (1 - highlightMix);
  return useCompressed ? compressed : bloomBRG;
}

// --------------------------------------------------------------------------
// Aspect-corrected radial vignette. Returns the 0..1 brightness factor.
// shape: x = size, y = falloff power, z = corner roundness, w = aspect mix.
// --------------------------------------------------------------------------
float EvalVignetteFactor(float2 uv, float2 center, float enable, float4 shape, float aspect)
{
  float aspectBase = shape.w * (aspect - 1) + 1;
  float aspectTerm = enable * (aspect * 0.5625 + -aspectBase) + aspectBase;

  float xScale = enable * (saturate(shape.x * 1.04999995) * 1.5 + -1) + 1;
  float radius = enable * (1 - shape.x) + shape.x;

  float2 offset = abs(uv - center) * radius;

  float xTerm = saturate(offset.x * xScale * aspectTerm);

  float yScale = enable * (shape.x * 2 + -1) + 1;
  float yBias  = 5 * saturate(shape.x + -2.79999995);
  float yTerm  = saturate(offset.y * yScale + yBias);

  float2 shaped = exp2(shape.zz * log2(float2(xTerm, yTerm)));

  float falloff = max(0, 1 - dot(shaped, shaped));
  return exp2(shape.y * log2(falloff));
}

// --------------------------------------------------------------------------
// Flattened 3D colour LUT: log-encode, then bilerp two neighbouring blue slices.
// lutTexelSize = (1/lutWidth, 1/lutHeight); the slice stride along u is .y.
// --------------------------------------------------------------------------
float3 SampleGradingLut(float3 colorBRG, float2 lutTexelSize, float lutSliceCount, float lutInputScale)
{
  float3 scaled = lutInputScale * colorBRG;
  scaled = scaled * float3(5.55555582, 5.55555582, 5.55555582)
         + float3(0.0479959995, 0.0479959995, 0.0479959995);
  scaled = max(float3(0, 0, 0), scaled);

  float3 encoded = saturate(log2(scaled) * float3(0.0734997839, 0.0734997839, 0.0734997839)
                          + float3(0.386036009, 0.386036009, 0.386036009));

  // encoded is still BRG: .x drives the slice, .y is red (u), .z is green (v).
  float3 indexBRG = lutSliceCount * encoded;
  float  slice     = floor(indexBRG.x);
  float  sliceFrac = encoded.x * lutSliceCount + -slice;

  float2 halfTexel = lutTexelSize * float2(0.5, 0.5);
  float  u = slice * lutTexelSize.y + (indexBRG.y * lutTexelSize.x + halfTexel.x);
  float  v = indexBRG.z * lutTexelSize.y + halfTexel.y;

  float3 sliceLo = ColorLut.SampleLevel(LinearSampler, float2(u, v), 0).xyz;
  float3 sliceHi = ColorLut.SampleLevel(LinearSampler, float2(u + lutTexelSize.y, v), 0).xyz;
  return sliceFrac * (sliceHi - sliceLo) + sliceLo;
}

float3 LinearToSrgb(float3 linearColor)
{
  float3 curve = exp2(float3(0.416666657, 0.416666657, 0.416666657) * log2(abs(linearColor)));
  curve = curve * float3(1.05499995, 1.05499995, 1.05499995)
        + float3(-0.0549999997, -0.0549999997, -0.0549999997);

  float3 linearSegment = float3(12.9200001, 12.9200001, 12.9200001) * linearColor;
  bool3  useLinear = float3(0.00313080009, 0.00313080009, 0.00313080009) >= linearColor;
  return useLinear ? linearSegment : curve;
}

// Deterministic screen-space dither, +/- 0.175/255 to hide 8-bit banding.
float3 DitherOffset(float2 pixelPos)
{
  float hash = dot(float2(171, 231), pixelPos);
  float3 noise = frac(float3(0.00970873795, 0.0140845068, 0.010309278) * hash);
  return (noise + float3(-0.5, -0.5, -0.5)) * float3(0.0013725491, 0.0013725491, 0.0013725491);
}

void main(
  float4 v0 : SV_Position,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_Target)
{
  // Named CB aliases (inferred). Left = meaning; right = dump slot.
  float2 viewportSize        = cb0[82].xy;   // render target size in pixels
  float2 inverseViewportSize = cb0[82].zw;   // 1 / viewportSize
  float  exposure            = cb0[109].x;

  float2 vignetteCenter      = cb1[1].xy;
  float  vignetteEnable      = cb1[1].w;     // 0 = neutral form, 1 = authored form
  float4 vignetteShape       = cb1[2];       // x size, y falloff, z roundness, w aspect mix
  float3 vignetteColorBRG    = cb1[4].zxy;
  float2 lutTexelSize        = cb1[7].xy;
  float  lutSliceCount       = cb1[7].z;
  float  lutInputScale       = cb1[7].w;
  float  bloomBlend          = cb1[9].x;     // final lerp toward the bloom composite
  float  bloomHighlightMix   = cb1[9].z;     // how much highlight the bloom texture replaces
  float4 bloomThreshold      = cb1[10];
  float3 bloomTintBRG        = cb1[11].zxy;
  float  sharpenStrength     = cb1[24].x;

  // 1. Contrast-adaptive sharpen.
  float  centerAlpha;
  float3 sharpenedBRG = EvalSharpen(v1.xy, inverseViewportSize, sharpenStrength, centerAlpha);
  o0.w = min(1, centerAlpha);

  // 2. Exposure, then hand the highlights over to the bloom texture.
  float3 exposedBRG = exposure * sharpenedBRG;

  float  highlightFraction = HighlightFraction(exposedBRG, bloomThreshold);
  float3 withoutHighlights = exposedBRG - bloomHighlightMix * (exposedBRG * highlightFraction);

  float3 bloomBRG = ToBRG(BloomInput.SampleLevel(LinearSampler, v1.xy, 0).xyz);
  bloomBRG = ShapeBloomSource(bloomBRG, bloomHighlightMix);

  float3 bloomComposite = bloomBRG * bloomTintBRG + withoutHighlights;
  float3 colorBRG = bloomBlend * (bloomComposite - sharpenedBRG * exposure) + exposedBRG;

  // 3. Vignette: darken and tint toward the authored vignette colour.
  float aspect = viewportSize.x / viewportSize.y;
  float vignetteFactor = EvalVignetteFactor(v1.xy, vignetteCenter, vignetteEnable,
                                            vignetteShape, aspect);
  float3 vignetteTintBRG = vignetteFactor * (float3(1, 1, 1) - vignetteColorBRG) + vignetteColorBRG;
  colorBRG = vignetteTintBRG * colorBRG;

  // 4. Colour grade. The LUT lookup resolves BRG back into natural RGB.
  float3 graded = SampleGradingLut(colorBRG, lutTexelSize, lutSliceCount, lutInputScale);

  // 5. Display transfer plus dither.
  float3 display = LinearToSrgb(graded);
  o0.xyz = display + DitherOffset(viewportSize * v1.xy);
}
