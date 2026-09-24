// =============================================================================
// ZMD / Endfield Eye PS — TA semantic readable
// =============================================================================
// Dump: 2026-09-24 14:15:46, event 1129
// Apply-faithful reference: zmd_eye_ps_20260924_141546_step5_analysis.hlsl
//
// Recipe-faithful, not binary-perfect.
// Kept:
//   iris UV circle -> view parallax -> tinted iris
//   cornea dome normal -> screen AO -> toon DiffuseRamp
//   ambient/direct eye lighting -> matcap highlight -> rim -> grade/exposure
// Removed for this compact TA pass:
//   volume SH probes t4..t9 -> ambientFallback stand-in
//   tiled local lights, cookies and cubic PCF
//   height/froxel fog
// Full implementations and exact register math remain in Step 5.
//
// Interpolators stay v0..v10; do not const-copy them.
// =============================================================================

#define STEP_IRIS_PARALLAX  1
#define STEP_CORNEA_DOME    1
#define STEP_SCREEN_AO      1
#define STEP_DIFFUSE_RAMP   1
#define STEP_MATCAP         1
#define STEP_ADD_HIGHLIGHT  1
#define STEP_RIM            1
#define STEP_COLOR_GRADE    1

#define DEBUG_VIS 0
// 0 final | 1 iris | 2 outside-iris mask | 3 world N | 4 cornea TS
// 5 Ramp RGB | 6 Ramp chroma | 7 matcap | 8 lit before rim
// 9 rim | 10 1-|N.V| | 11 graded

Texture2D<float4> EyeHighlightMatcap : register(t12);
Texture2D<float4> IrisBaseColorMap   : register(t11);
Texture2D<float4> DiffuseRamp        : register(t10);
Texture2D<float4> ScreenAOMap        : register(t3);

SamplerState sampMatcap   : register(s4);
SamplerState sampIrisBase : register(s3);
SamplerState sampLinear   : register(s0);

cbuffer cb5 : register(b5) { float4 cb5[18]; }
cbuffer cb4 : register(b4) { float4 cb4[401]; }
cbuffer cb3 : register(b3) { float4 cb3[2054]; }
cbuffer cb0 : register(b0) { float4 cb0[216]; }

static const float  kEps  = 6.10351562e-05;
static const float3 kLuma = float3(0.212672904, 0.715152204, 0.0721750036);

float  cmp(bool  v) { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }

float Smooth01(float x)
{
  x = saturate(x);
  return x * x * (3.0 - 2.0 * x);
}

float3 SafeNormalize(float3 value)
{
  return value * rsqrt(max(1.17549435e-38, dot(value, value)));
}

float3 EvalViewDir(
  float3 worldPos,
  float3 cameraPos,
  float3 cameraForward,
  float viewBendAmount)
{
  float3 toCamera = cameraPos - worldPos;
  toCamera = viewBendAmount * (cameraForward - toCamera) + toCamera;
  return toCamera * rsqrt(max(9.99999994e-09, dot(toCamera, toCamera)));
}

float2 EvalMotion(float3 currentClip, float3 previousClip)
{
  float2 current  = currentClip.xy / max(9.99999994e-09, currentClip.z);
  float2 previous = previousClip.xy / max(9.99999994e-09, previousClip.z);
  float2 delta = current - previous;
  float2 magnitude = sqrt(sqrt(abs(float2(0.5, -0.5) * delta)));
  float2 axis = float2(delta.x, -delta.y);
  float2 positive = cmp(float2(0, 0) < axis);
  float2 negative = cmp(axis < float2(0, 0));
  float2 signValue = (float2)((int2)(-(int2)positive + (int2)negative));
  return magnitude * signValue * 0.5 + 0.5;
}

float3 EvalColorGrade(
  float3 color,
  float nDotV,
  float enable,
  float gradeScale,
  float saturation,
  float contrast,
  float rimWidth,
  float rimGain,
  float3 tint,
  float tintMix,
  float3 gradeRimColor)
{
  if (enable <= 0.5)
    return color;

  float luminance = dot(color, kLuma);
  float3 graded = saturation * (color - luminance) + luminance;
  graded = (graded - 0.5) * contrast + 0.5;
  graded = tintMix * (tint - graded * gradeScale) + graded * gradeScale;

  float edgeStart = 1.0 - rimWidth;
  float edge = Smooth01(saturate(((1.0 - saturate(nDotV)) - edgeStart)
                               / max(1e-5, rimWidth)));
  return graded + gradeRimColor * edge * rimGain;
}

void main(
  float4 v0 : SV_Position,
  float4 v1 : TEXCOORD0,  // iris UV
  float4 v2 : TEXCOORD1,  // world position
  float4 v3 : TEXCOORD2,  // geometric normal
  float4 v4 : TEXCOORD3,  // tangent + handedness
  float4 v5 : TEXCOORD4,  // current motion clip position
  float4 v6 : TEXCOORD5,  // previous motion clip position
  float4 v7 : TEXCOORD6,  // unused here; VS signature retained
  float4 v8 : TEXCOORD7,  // unused here; VS signature retained
  nointerpolation uint v9 : TEXCOORD8,
  uint v10 : SV_IsFrontFace,
  out float4 o0 : SV_Target,
  out float4 o1 : SV_Target1)
{
  // =========================================================================
  // Named CB aliases (inferred). Original float4 packing remains unchanged.
  // =========================================================================
  float3 viewRow0        = cb0[0].xyz;
  float3 viewRow1        = cb0[1].xyz;
  float3 viewRow2        = cb0[2].xyz;
  float3 cameraPos       = cb0[44].xyz;
  float3 cameraForward   = float3(cb0[0].z, cb0[1].z, cb0[2].z);
  float  viewBend        = cb0[86].w;
  float  mipBias         = cb0[108].x;
  float  exposure        = cb0[109].x;
  float  exposureAlt     = cb0[111].x;
  float  globalBlend     = cb0[198].w;

  float3 sunDir          = cb0[6].xyz;
  float3 lightDirBase    = cb3[0].xyz;
  float3 lightDirOffset  = cb0[197].xyz;
  float  rampUvBias      = cb0[197].w;
  float  rampBiasBlend   = cb0[198].x;
  float  lightDirBlend   = cb0[187].w;

  float3 lightColorBase  = cb3[3].xyz;
  float  lightIntensity  = cb3[3].w;
  float3 lightColorAlt   = cb0[191].xyz;
  float  lightColorBlend = cb0[198].y;

  float3 ambientColor    = cb0[188].xyz;
  float3 ambientFacingDir = cb0[192].xyz;
  float  ambientFacingBias  = cb0[193].x;
  float  ambientFacingScale = cb0[193].y;
  float  ambientFacingAdd   = cb0[193].z;

  float  giScale          = cb0[186].y;
  float  albedoLitScale   = cb0[186].z;
  float  envScale         = cb0[186].w;
  float  ambientRampBlend = cb0[187].y;
  float  screenAoWeight   = cb0[187].z;
  float  screenAoBlend    = cb4[34].x;
  float3 specGlobalScale  = cb0[199].xyz;

  float  materialDim       = cb5[0].z;
  float  backfaceNormal    = cb5[1].y;
  float  alphaSourceBlend  = cb5[1].z;
  float  alphaMode         = cb5[2].x;
  float  gradeEnable       = cb5[3].x;
  float  gradeScale        = cb5[3].y;
  float  gradeSaturation   = cb5[3].z;
  float  gradeContrast     = cb5[3].w;
  float  gradeRimWidth     = cb5[4].x;
  float  gradeRimGain      = cb5[4].y;
  float  baseColorScale    = cb5[4].z;
  float  baseSaturation    = cb5[4].w;
  float4 baseColorTint     = cb5[5];
  float3 gradeTint         = cb5[7].xyz;
  float  gradeTintMix      = cb5[7].w;
  float3 gradeRimColor     = cb5[8].xyz;
  float  irisParallaxDepth = cb5[11].y;
  float3 irisHighlightTint = cb5[14].xyz;
  float3 scleraHighlightTint = cb5[15].xyz;
  float  corneaBulge       = cb5[16].y;
  float3 matcapAlphaTint   = cb5[17].xyz;
  float  matcapRgbWeight   = cb5[17].w;

  float3 viewDir = EvalViewDir(v2.xyz, cameraPos, cameraForward, viewBend);

  // =========================================================================
  // 1. Eye tangent frame and iris UV parallax
  // =========================================================================
  float geomNormalLength = sqrt(dot(v3.xyz, v3.xyz));
  float3 geomNormal = v3.xyz / geomNormalLength;
  float3 tangent = v4.xyz / geomNormalLength;
  float tangentSign = (0.0 < v4.w) ? 1.0 : -1.0;
  float3 rawBitangent = v3.yzx * v4.zxy - v4.yzx * v3.zxy;
  float3 viewBitangent = rawBitangent * tangentSign / geomNormalLength;

  float3 viewTS = float3(
    dot(tangent, viewDir),
    dot(viewBitangent, viewDir),
    dot(geomNormal, viewDir));
  viewTS.xy *= rsqrt(max(1.17549435e-38, dot(viewTS, viewTS)));

  float2 irisCellUv = frac(v1.xy);
  float2 irisCentered = irisCellUv - 0.5;
  float irisRadiusSq = dot(irisCentered, irisCentered);
  float outsideIrisMask = (irisRadiusSq >= 0.25) ? 1.0 : 0.0;

  float irisInteriorFade = Smooth01(saturate(-5.0 * (irisRadiusSq - 0.25)));
  float2 irisUvOffset = viewTS.xy * irisParallaxDepth * float2(1.0, 0.25);
  float2 irisUv = v1.xy - irisUvOffset * irisInteriorFade;
#if !STEP_IRIS_PARALLAX
  irisUv = v1.xy;
#endif

  float4 irisSample = IrisBaseColorMap.SampleBias(sampIrisBase, irisUv, mipBias);
  float4 irisBase = irisSample * baseColorTint;

  // =========================================================================
  // 2. Cornea dome normal
  // =========================================================================
  float2 corneaXY = irisCellUv * 2.0 - 1.0;
  float corneaZ = max(1.00000002e-16,
                      sqrt(1.0 - min(1.0, dot(corneaXY, corneaXY))));
  float3 corneaNormalTS = float3(
    -corneaXY * corneaBulge * 0.125,
    corneaZ);
  corneaNormalTS = outsideIrisMask * (float3(0, 0, 1) - corneaNormalTS)
                 + corneaNormalTS;
#if !STEP_CORNEA_DOME
  corneaNormalTS = float3(0, 0, 1);
#endif

  float faceSign = v10.x ? 1.0 : (backfaceNormal * 2.0 - 1.0);
  float3 shadingNormal = corneaNormalTS.x * v4.xyz
                       + corneaNormalTS.y * (v4.w * rawBitangent)
                       + corneaNormalTS.z * v3.xyz;
  shadingNormal = SafeNormalize(shadingNormal) * faceSign;

  // A second normalized form used by the original ambient-facing term.
  float3 ambientNormal = SafeNormalize(float3(
    shadingNormal.x,
    kEps,
    shadingNormal.z));

  // =========================================================================
  // 3. Base colour, motion and screen AO
  // =========================================================================
  float dimFactor = 0.96 * (1.0 - materialDim);
  float baseLuma = dot(irisBase.rgb * baseColorScale, kLuma);
  float3 baseColor = baseSaturation
                   * (irisBase.rgb * baseColorScale - baseLuma)
                   + baseLuma;
  baseColor *= dimFactor;

  o1.xy = EvalMotion(v5.xyz, v6.xyz);

  float screenAo = ScreenAOMap.Load(int3((uint2)v0.xy, 0)).x;
  screenAo = screenAoBlend * (screenAo - 1.0) + 1.0;
  screenAo = screenAoWeight * (1.0 - screenAo) + screenAo;
#if !STEP_SCREEN_AO
  screenAo = 1.0;
#endif

  // =========================================================================
  // 4. Main light and toon Ramp
  // =========================================================================
  float3 lightVector = lightDirBlend * (lightDirBase + lightDirOffset)
                     - lightDirBase;
  float3 lightDir = SafeNormalize(float3(lightVector.x, kEps, lightVector.z));
  float3 lightColor = lightColorBlend * (lightColorAlt - lightColorBase)
                    + lightColorBase;
  float lightWeight = globalBlend * (1.0 - lightIntensity) + lightIntensity;
  lightColor *= lightWeight;

  float nDotL = dot(shadingNormal, lightDir);
  nDotL = clamp(nDotL + rampUvBias * rampBiasBlend, -1.0, 1.0);
  float2 rampUv = float2(nDotL * 0.5 + 0.5, 0.5);
  float4 ramp = DiffuseRamp.SampleLevel(sampLinear, rampUv, 0);
  float rampMax = max(ramp.r, max(ramp.g, ramp.b));
  float rampMin = min(ramp.r, min(ramp.g, ramp.b));
  float rampChroma = rampMax - rampMin;
#if !STEP_DIFFUSE_RAMP
  ramp.rgb = float3(1, 1, 1);
  rampChroma = 0.0;
#endif

  float sunFacing = dot(shadingNormal, sunDir);
  float rampAlpha = DiffuseRamp.SampleLevel(
    sampLinear, float2(sunFacing * 0.5 + 0.5, 0.5), 0).a;

  // =========================================================================
  // 5. Ambient/direct eye lighting
  // =========================================================================
  float ambientFacing = saturate(dot(ambientNormal, ambientFacingDir)
                               + ambientFacingBias);
  ambientFacing = ambientFacing * ambientFacingScale + ambientFacingAdd;

  float3 ambient = ambientColor;
  ambient = ambientRampBlend * (1.0 - ambient) + ambient;
  ambient *= ambientFacing * envScale;

  float3 albedoLit = baseColor * albedoLitScale;
  float3 neutralShadow = dot(albedoLit * 0.65, kLuma);
  float rampMask = saturate(rampAlpha + ramp.a);
  float3 rampedAlbedo = rampMask * (albedoLit - neutralShadow) + neutralShadow;

  float3 directColor = rampChroma * ramp.rgb + (1.0 - rampChroma);
  directColor *= rampedAlbedo;
  directColor *= lightColor;

  float outsideTintMask = outsideIrisMask;
  float3 highlightMask =
    (scleraHighlightTint * outsideTintMask + (1.0 - outsideTintMask))
    * (irisHighlightTint * irisBase.a + (1.0 - irisSample.a * baseColorTint.a));

  float3 litDirect = directColor * highlightMask;
  float3 litAmbient = ambient * albedoLit * screenAo * giScale;
  float3 lit = litDirect + litAmbient;

  // =========================================================================
  // 6. Cornea matcap highlight
  // =========================================================================
  float3 matcapWorldNormal =
      corneaNormalTS.y * (v3.yzx * v4.zxy - v4.yzx * v3.zxy) * v4.w
    + corneaNormalTS.x * v4.xyz
    + corneaNormalTS.z * v3.xyz;

  float3 matcapViewNormal;
  matcapViewNormal.x = dot(viewRow0, matcapWorldNormal);
  matcapViewNormal.y = dot(viewRow1, matcapWorldNormal);
  matcapViewNormal.z = dot(viewRow2, matcapWorldNormal);
  matcapViewNormal = SafeNormalize(matcapViewNormal);

  float2 matcapUv = matcapViewNormal.xy * 0.5 + 0.5;
  float4 matcapSample =
    EyeHighlightMatcap.SampleBias(sampMatcap, matcapUv, mipBias);
  float3 matcapColor =
    matcapSample.rgb * matcapRgbWeight + matcapAlphaTint * matcapSample.a;
  float nDotV = dot(shadingNormal, viewDir);
  float matcapFacing = (nDotV * 0.5 + 0.5)
                     * (nDotV * (1.0 - albedoLitScale) + albedoLitScale);
  float3 matcapAdd = ambient * matcapColor * matcapFacing;
#if !STEP_MATCAP
  matcapAdd = float3(0, 0, 0);
#endif
  lit += matcapAdd;

  // =========================================================================
  // 7. Rim/facing and additive eye highlight
  // =========================================================================
  float oneMinusAbsNdotV = 1.0 - abs(nDotV);
  float rimShape = Smooth01(saturate(5.0 * (0.4 - abs(nDotV))));
  float darkIrisMask = Smooth01(
    saturate(-16.666666 * (dot(irisBase.rgb * dimFactor, kLuma) - 0.1)));
  float rimMask = (darkIrisMask * screenAo + (1.0 - screenAo))
                * rimShape;
  float3 rimAdd = max(float3(0.15, 0.15, 0.15),
                      irisBase.rgb * dimFactor)
                * ambient * rimMask;
  float3 litPreRim = lit;
#if STEP_RIM
  lit += rimAdd;
#endif

  float3 additiveHighlight =
      irisBase.rgb * specGlobalScale.xxx
    + scleraHighlightTint * outsideIrisMask * specGlobalScale.yyy
    + irisHighlightTint * irisBase.a * specGlobalScale.zzz;
#if STEP_ADD_HIGHLIGHT
  lit += additiveHighlight;
#endif

  // =========================================================================
  // 8. Grade, exposure and MRT output
  // =========================================================================
  float3 graded = lit;
#if STEP_COLOR_GRADE
  graded = EvalColorGrade(
    lit, abs(nDotV),
    gradeEnable, gradeScale, gradeSaturation, gradeContrast,
    gradeRimWidth, gradeRimGain,
    gradeTint, gradeTintMix, gradeRimColor);
#endif

  float exposureBlend = globalBlend * (1.0 - exposureAlt) + exposureAlt;
  float effectiveExposure = exposure * exposureBlend;
  o0.rgb = graded / effectiveExposure;
  o0.a = (alphaMode == 1.0) ? irisBase.a : 1.0;
  o1.zw = float2(1.0, 0.400000006);

#if DEBUG_VIS == 1
  o0 = float4(irisBase.rgb, 1);
#elif DEBUG_VIS == 2
  o0 = float4(outsideIrisMask.xxx, 1);
#elif DEBUG_VIS == 3
  o0 = float4(shadingNormal * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 4
  o0 = float4(corneaNormalTS * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 5
  o0 = float4(ramp.rgb, 1);
#elif DEBUG_VIS == 6
  o0 = float4(rampChroma.xxx, 1);
#elif DEBUG_VIS == 7
  o0 = float4(matcapAdd, 1);
#elif DEBUG_VIS == 8
  o0 = float4(litPreRim, 1);
#elif DEBUG_VIS == 9
  o0 = float4(rimAdd, 1);
#elif DEBUG_VIS == 10
  o0 = float4(oneMinusAbsNdotV.xxx, 1);
#elif DEBUG_VIS == 11
  o0 = float4(graded, 1);
#endif
}
