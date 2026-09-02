// =============================================================================
// Hand SSS Pixel Shader — stripped (fresnel / thickness / opacity / grade / kill removed)
// Remaining: distance falloff × noise weight → alpha; baseColor × dist × colorMod → RGB
// =============================================================================

#define STEP_DIST_FALLOFF  1  // 0 → distFalloff = 1; colorMod dist term = 0
                              //     (do NOT use log=0 → exp2(0)=1 → blown white)
#define STEP_NOISE_WEIGHT  1  // 0 → noiseWeight = 1
#define STEP_COLOR_MOD     1  // 0 → colorMod = 1

#define DEBUG_VIS 0
// 0 final | 1 distFalloff | 2 noiseWeight | 3 alpha | 4 colorMod | 5 RGB

// =============================================================================
// Resources
// =============================================================================
Texture2D<float4> texNoise : register(t1); // SSS noise map (.x)

SamplerState sampLinear : register(s15);

cbuffer MaterialCB : register(b1) { float4 cb1[15]; }
cbuffer BatchCB    : register(b0) { float4 cb0[7]; }
cbuffer FrameCB    : register(b13) { float4 cb13[1]; }

static const float kEps = 9.99999975e-05;

// =============================================================================
// Material — aliases only; packing stays float4 cb1[]
// =============================================================================
struct Material
{
  float3 baseColor;
  float  opacityBase;      // still scales alpha (thickness path removed → factor 1)

  // noise UV: project world offset → UV, scroll by time, blend toward modelUV
  float2 noiseUVBase0;     // cb1[1].xy
  float2 noiseUVBase1;     // cb1[9].zw
  float  noiseUVLerp;      // cb1[10].w
  float  noiseUVScale;     // cb1[11].x
  float  noiseUVBlend;     // cb1[11].y  (0=projected, 1=modelUV)

  float3 sssAxis0;         // cb1[5]
  float3 sssAxis1;         // cb1[6]
  float3 sssAxis2;         // cb1[7]
  float3 sssAxis3;         // cb1[8]

  float3 colorLo;          // cb1[2].xyz
  float3 colorHi;          // cb1[3].xyz
  float3 colorTint;        // cb1[4].xyz
  float  colorTintFloor;   // cb1[7].w
  float  colorTintCeil;    // cb1[8].w
  float  colorTintMix0;    // cb1[10].x
  float  colorTintMix1;    // cb1[10].y
  float  colorTintMul;     // cb1[1].z

  float  distFalloffPow;
  float  noisePow;         // cb1[11].z  exp2(noisePow * log2(|noise|))
  float  noiseBlend;       // cb1[11].w  lerp(dist, noise*dist, blend)
  float  sssWeightScale;   // cb1[12].x

  float  colorFromNoiseLog; // cb1[12].z
  float  colorFromDistLog;  // cb1[12].w
  float  colorDistMix;
  float  distColorScale;

  float  timeParam;
  float  alphaScale;
};

Material LoadMaterial()
{
  Material m;
  m.baseColor         = cb1[0].xyz;
  m.opacityBase       = cb1[0].w;
  m.colorTintMul      = cb1[1].z;
  m.noiseUVBase0      = cb1[1].xy;
  m.colorLo           = cb1[2].xyz;
  m.colorHi           = cb1[3].xyz;
  m.colorTint         = cb1[4].xyz;
  m.sssAxis0          = cb1[5].xyz;
  m.sssAxis1          = cb1[6].xyz;
  m.colorTintFloor    = cb1[7].w;
  m.sssAxis2          = cb1[7].xyz;
  m.colorTintCeil     = cb1[8].w;
  m.sssAxis3          = cb1[8].xyz;
  m.noiseUVBase1      = cb1[9].zw;
  m.colorTintMix0     = cb1[10].x;
  m.colorTintMix1     = cb1[10].y;
  m.distFalloffPow    = cb1[10].z;
  m.noiseUVLerp       = cb1[10].w;
  m.noiseUVScale      = cb1[11].x;
  m.noiseUVBlend      = cb1[11].y;
  m.noisePow          = cb1[11].z;
  m.noiseBlend        = cb1[11].w;
  m.sssWeightScale    = cb1[12].x;
  m.colorFromNoiseLog = cb1[12].z;
  m.colorFromDistLog  = cb1[12].w;
  m.colorDistMix      = cb1[13].x;
  m.distColorScale    = cb1[13].z;
  m.timeParam         = cb13[0].x;
  m.alphaScale        = cb0[6].z;
  return m;
}

// =============================================================================
// Stage evals
// =============================================================================

void EvalDistanceFalloff(Material m, float3 pos, out float distLog, out float distFalloff)
{
  float3 center = m.colorHi + m.colorLo;

  float3 tint = m.colorTintFloor * m.colorTint;
  tint = max(0.0.xxx, tint);
  tint = min(m.colorTintCeil.xxx, tint);
  tint = tint - m.colorTintFloor;
  tint = m.colorTintMix0.xxx * tint + m.colorTintFloor.xxx;
  float3 tint2 = tint * m.colorTintMul.xxx + -tint;
  tint = m.colorTintMix1.xxx * tint2 + tint;
  tint = tint + center;

  float radius = length(center - tint);
  float distToCenter = length(center - pos);
  float distFactor = saturate((radius - distToCenter) / radius);
  distFactor = max(kEps, distFactor);

  distLog = log2(distFactor);
  distFalloff = exp2(m.distFalloffPow * distLog);
}

// Sample SSS noise map, shape with exp2/log2, blend with distance falloff → weight
void EvalNoiseWeight(
  Material m, float2 modelUV, float3 pos,
  float distFalloff,
  out float noiseLog, out float noiseWeight)
{
  float3 center = m.colorHi + m.colorLo;
  float3 fromCenter = pos - center;

  float2 noiseScroll = m.noiseUVLerp * (m.noiseUVBase1 - m.noiseUVBase0) + m.noiseUVBase0;

  float2 noiseUV;
  noiseUV.x = dot(center, m.sssAxis1) * dot(fromCenter, m.sssAxis0);
  noiseUV.y = dot(center, m.sssAxis3) * dot(fromCenter, m.sssAxis2);
  noiseUV = m.noiseUVScale.xx * noiseUV;
  noiseUV = m.timeParam.xx * noiseScroll + noiseUV;
  noiseUV = m.noiseUVBlend.xx * (modelUV - noiseUV) + noiseUV;

  float noiseSample = texNoise.Sample(sampLinear, noiseUV).x;
  noiseLog = log2(max(kEps, abs(noiseSample)));

  float noiseShaped = exp2(m.noisePow * noiseLog);
  // dump: lerp(distFalloff, noiseShaped*distFalloff, noiseBlend) then * scale
  noiseWeight = noiseShaped * distFalloff - distFalloff;
  noiseWeight = m.noiseBlend * noiseWeight + distFalloff;
  noiseWeight = saturate(m.sssWeightScale * noiseWeight);
}

float EvalColorMod(Material m, float noiseLog, float distLog, bool includeDist)
{
  float colorMod = exp2(m.colorFromNoiseLog * noiseLog);
  if (includeDist)
    colorMod = m.colorDistMix * exp2(m.colorFromDistLog * distLog) + colorMod;
  return colorMod;
}

float3 EvalSSSColor(Material m, float distFalloff, float colorMod)
{
  float3 rgb = m.baseColor;
  rgb *= (m.distColorScale * (distFalloff - 1.0) + 1.0);
  rgb *= colorMod;
  return rgb;
}

// =============================================================================
// main
// =============================================================================
void main(
  float4 svPos   : SV_Position, // unused; VS signature
  float4 tbnX    : TEXCOORD0,   // unused (fresnel removed); VS signature
  float4 tbnY    : TEXCOORD1,
  float4 tbnZ    : TEXCOORD2,
  float4 viewVec : TEXCOORD3,
  float4 pos     : TEXCOORD4,
  float2 modelUV : TEXCOORD5,
  float  depthW  : TEXCOORD6,   // unused; VS signature
  out float4 o0  : SV_Target)
{
  Material m = LoadMaterial();

  // --- Distance + noise weight ---
  float distLog, distFalloff;
  EvalDistanceFalloff(m, pos.xyz, distLog, distFalloff);
#if !STEP_DIST_FALLOFF
  distFalloff = 1.0;
#endif

  float noiseLog, noiseWeight;
  EvalNoiseWeight(m, modelUV, pos.xyz, distFalloff, noiseLog, noiseWeight);
#if !STEP_NOISE_WEIGHT
  noiseWeight = 1.0;
#endif

  // opacity=1, fresnel=1, thickness factor=1 → alpha = saturate(opacityBase * noiseWeight)
  float alpha    = saturate(m.opacityBase * noiseWeight);
  float outAlpha = m.alphaScale * alpha;

  // --- Color ---
  float colorMod;
#if STEP_COLOR_MOD
  colorMod = EvalColorMod(m, noiseLog, distLog, STEP_DIST_FALLOFF != 0);
#else
  colorMod = 1.0;
#endif

  float3 sssRgb = EvalSSSColor(m, distFalloff, colorMod);

  float4 outCol = float4(sssRgb, outAlpha);

#if DEBUG_VIS == 1
  outCol = float4(distFalloff.xxx, 1);
#elif DEBUG_VIS == 2
  outCol = float4(noiseWeight.xxx, 1);
#elif DEBUG_VIS == 3
  outCol = float4(alpha.xxx, 1);
#elif DEBUG_VIS == 4
  outCol = float4(colorMod.xxx, 1);
#elif DEBUG_VIS == 5
  outCol = float4(sssRgb, 1);
#endif

  o0 = max(0.0.xxxx, outCol);
}
