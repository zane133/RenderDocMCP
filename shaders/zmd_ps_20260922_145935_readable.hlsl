// =============================================================================
// ZMD / Endfield Toon Face/Skin PS — TA semantic readable
// =============================================================================
// Dump: 2026-09-22 14:59:35
// Apply-faithful reference: zmd_ps_20260922_145935_step5_analysis.hlsl
// User-trimmed reference: zmd_ps_20260922_145935_step5b_trimmed.hlsl
//
// This file is recipe-faithful, not binary-perfect.
// Removed by user: volume SH probes and height/volumetric fog.
// Removed for the TA semantic pass: tiled local lights, cookies and shadow PCF.
// Kept: detail colour -> Mask -> animated detail normal -> Face SDF ->
//       ShadowColorLUT -> toon Ramp -> shifted spec/matcap -> rim -> grade/exposure.
//
// Important corrections:
//   t17 = FaceSdfMap. It is mirrored by light side and drives face shadow/ramp.
//   t18 = MaskMap. .y controls normal/SDF blending; other channels shape masks.
//   Screen AO is not applied raw: the dump fades it in with a back-side weight
//   derived from the sun yaw in the instance frame, so a sun-facing head stays
//   unoccluded. ViewShiftedSpecMap is lit by the main light, not added flat.
// Interpolators stay v0..v10 to preserve the VS/PS link.
// =============================================================================

#define STEP_SSS_EDGE_TINT 1
#define STEP_DETAIL        1
#define STEP_FACE_SDF      1
#define STEP_SHADOW_LUT    1
#define STEP_DIFFUSE_RAMP  1
#define STEP_MATCAP        1
#define STEP_SPECULAR      1
#define STEP_RIM           1
#define STEP_COLOR_GRADE   1

#define DEBUG_VIS 0
// 0 final | 1 base | 2 MaskMap | 3 geometric N | 4 detail N
// 5 Face SDF raw | 6 Face SDF shadow | 7 SSS tint | 8 ShadowColorLUT
// 9 Ramp RGB | 10 Ramp chroma | 11 lit before rim | 12 rim | 13 graded

Texture2D<float4> MaskMap           : register(t18);
Texture2D<float4> FaceSdfMap        : register(t17);
Texture2D<float4> BaseColorMap      : register(t16);
Texture2D<float4> SkinSpecMatcap    : register(t15);
Texture2D<float4> NormalMap         : register(t14);
Texture2D<float4> ShadowColorLUT    : register(t13);
Texture2D<float4> DetailColorAtlas  : register(t12);
Texture2D<float4> ViewShiftedSpecMap: register(t11);
Texture2D<float4> SkinDiffuseRamp   : register(t10);
Texture2D<float4> ScreenData        : register(t3);

struct InstanceElem { float val[4]; };
StructuredBuffer<InstanceElem> InstanceDataSB : register(t1);

SamplerState sampMask      : register(s6);
SamplerState sampFaceSdf   : register(s5);
SamplerState sampBaseColor : register(s4);
SamplerState sampShadowLUT : register(s3);
SamplerState sampLinear    : register(s0);

cbuffer cb5 : register(b5) { float4 cb5[17]; }
cbuffer cb4 : register(b4) { float4 cb4[401]; }
cbuffer cb3 : register(b3) { float4 cb3[2054]; }
cbuffer cb1 : register(b1) { float4 cb1[4093]; }
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

float3 SafeNormalize(float3 v)
{
  return v * rsqrt(max(1.17549435e-38, dot(v, v)));
}

float3 EvalViewDir(float3 worldPos, float3 cameraPos, float3 cameraForward,
                   float viewBend)
{
  float3 toCamera = cameraPos - worldPos;
  toCamera = viewBend * (cameraForward - toCamera) + toCamera;
  return toCamera * rsqrt(max(9.99999994e-09, dot(toCamera, toCamera)));
}

float3 LinearToSrgb(float3 linearColor)
{
  float3 low  = 12.9200001 * linearColor;
  float3 high = exp2(0.416666657 * log2(abs(linearColor)));
  high = high * 1.05499995 - 0.0549999997;
  return saturate(
    (float3(0.00313080009, 0.00313080009, 0.00313080009) >= linearColor)
      ? low : high);
}

float3 EvalShadowColorLut(float3 baseColor, float dielectric)
{
  // Dump addresses the 32-slice atlas with sRGB(base.brg).
  float3 srgbBRG = LinearToSrgb(baseColor.zxy);
  float slice = 31.0 * srgbBRG.x;
  float sliceFloor = floor(slice);
  float2 uv = float2(
    sliceFloor * 0.03125 + srgbBRG.y * 0.0302734375 + 0.00048828125,
    srgbBRG.z * 0.96875 + 0.015625);
  float3 a = ShadowColorLUT.SampleLevel(sampShadowLUT, uv, 0).xyz;
  float3 b = ShadowColorLUT.SampleLevel(
    sampShadowLUT, uv + float2(0.03125, 0.015625), 0).xyz;
  return (a + (slice - sliceFloor) * (b - a)) * dielectric;
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

struct InstanceFrame
{
  float3 basisX;
  float3 basisY;
  float3 basisZ;
  float2 centerXZ;
  uint   cbBase;
};

InstanceFrame LoadInstanceFrame(uint instanceIndex)
{
  InstanceFrame frame;
  frame.cbBase = instanceIndex << 4;

  if ((16 & asint(cb1[frame.cbBase + 4].w)) != 0)
  {
    int data0 = asint(cb1[frame.cbBase + 5].x);
    int data1 = data0 + 1;
    int data2 = data0 + 2;

    float4 row0 = float4(
      InstanceDataSB[data0].val[0], InstanceDataSB[data0].val[1],
      InstanceDataSB[data0].val[2], InstanceDataSB[data0].val[3]);
    float3 row1 = float3(
      InstanceDataSB[data1].val[0], InstanceDataSB[data1].val[1],
      InstanceDataSB[data1].val[2]);
    float4 row2 = float4(
      InstanceDataSB[data2].val[0], InstanceDataSB[data2].val[1],
      InstanceDataSB[data2].val[2], InstanceDataSB[data2].val[3]);

    frame.basisX = float3(row0.x, row1.x, row2.x);
    frame.basisY = float3(row0.y, row1.y, row2.y);
    frame.basisZ = float3(row0.z, row1.z, row2.z);
    frame.centerXZ = float2(row0.w, row2.w);
  }
  else
  {
    frame.basisX = cb1[frame.cbBase + 0].xyz;
    frame.basisY = cb1[frame.cbBase + 1].xyz;
    frame.basisZ = cb1[frame.cbBase + 2].xyz;
    frame.centerXZ = cb1[frame.cbBase + 3].xz;
  }
  return frame;
}

float4 LoadInstanceDetail(uint cbBase)
{
  // Packed per-instance material controls; kept behind a semantic loader.
  return cb1[cbBase + 12];
}

float3 LocalToWorld(InstanceFrame frame, float3 localVector)
{
  return float3(
    dot(float3(frame.basisX.x, frame.basisY.x, frame.basisZ.x), localVector),
    dot(float3(frame.basisX.y, frame.basisY.y, frame.basisZ.y), localVector),
    dot(float3(frame.basisX.z, frame.basisY.z, frame.basisZ.z), localVector));
}

struct DetailResult
{
  float3 normal;
  float  coverage;
  float  alphaFactor;
  float  roughness;
  float  specular;
};

DetailResult EvalDetail(
  float2 uv, float3 geomNormal, float4 tangent, float faceSign,
  float timeValue, float mipBias, float maskNormalBlend, float materialSpecular,
  float materialSmoothness, float4 instanceDetail)
{
  DetailResult result;
  result.normal = geomNormal * faceSign;
  result.coverage = 0;
  result.alphaFactor = 1;
  result.roughness = 1.0 - materialSmoothness;
  result.specular = materialSpecular;

#if STEP_DETAIL
  float heightT = saturate(2.85714269 * (instanceDetail.z + 0.2));
  float heightWeight = Smooth01(heightT) * instanceDetail.y;
  heightWeight = max(instanceDetail.w, heightWeight);
  float gate = instanceDetail.x + heightWeight;

  if (gate > 0.00999999978)
  {
    float amount = max(instanceDetail.x, heightWeight);
    float phase0 = frac(timeValue * 0.800000012);
    float phase1 = frac(timeValue * 0.800000012 + 0.00499999989);
    float4 detail0 = NormalMap.SampleBias(
      sampBaseColor, uv + float2(0, phase0), mipBias);
    float detail1 = NormalMap.SampleBias(
      sampBaseColor, uv + float2(0, phase1), mipBias).w;
    float detailMask = SkinSpecMatcap.SampleBias(
      sampBaseColor, uv, mipBias).z;

    float2 detailPair = float2(detail1, detail0.w) * detailMask;
    float stroke = saturate(detailPair.x + detailPair.y);
    float strokeAmount = stroke * amount;

    float2 normalXY = detail0.xy * 2.0 - 1.0;
    float normalZ = sqrt(max(
      1.00000002e-16, 1.0 - min(1.0, dot(normalXY, normalXY))));

    float3 bitangent = tangent.yzx * geomNormal.zxy;
    bitangent = geomNormal.yzx * tangent.zxy - bitangent;
    bitangent *= tangent.w;
    float3 detailNormal =
      normalXY.x * tangent.xyz + normalXY.y * bitangent + normalZ * geomNormal;
    result.normal = SafeNormalize(detailNormal) * faceSign;

    float profile = Smooth01(saturate(1.25 * (normalXY.y * 0.5 + 0.5)));
    float opacityShape = saturate(detail1 * detailMask - detailPair.y);
    opacityShape = opacityShape * (1.0 - profile) + profile;
    opacityShape = opacityShape * 0.8 + (1.0 - opacityShape);
    opacityShape = maskNormalBlend * (0.9 - opacityShape) + opacityShape;
    result.alphaFactor = opacityShape * strokeAmount + (1.0 - strokeAmount);
    result.coverage = opacityShape;
    result.roughness = 0.300000012;
    result.specular =
      strokeAmount * (3.0 - maskNormalBlend * materialSpecular)
      + materialSpecular * (1.0 - maskNormalBlend);
  }
#endif
  return result;
}

struct FaceSdfResult
{
  float4 sampleValue;
  float3 bentNormal;
  float  shadow;
  float  rampU;
};

FaceSdfResult EvalFaceSdf(
  float2 uv, InstanceFrame frame, float3 geometricNormal, float faceSign,
  float3 lightVector, float3 sunDir, float normalBlend,
  float2 sdfBlend, float rampBias)
{
  FaceSdfResult result;

  // The dump picks the mirror side from the main-light vector in the instance
  // frame, not from the raw sun direction. Both the mirrored X and the local
  // yaw Z come from the same normalized vector.
  float3 localLightRaw = float3(
    dot(lightVector, frame.basisX), kEps, dot(lightVector, frame.basisZ));
  float localLightScale = rsqrt(dot(localLightRaw, localLightRaw));
  float localLightX = localLightRaw.x * localLightScale;
  float localLightZ = localLightRaw.z * localLightScale;

  bool lightOnPositiveSide = localLightX > 0;
  float2 sdfUv = float2(lightOnPositiveSide ? uv.x : (1.0 - uv.x), uv.y);
  result.sampleValue = FaceSdfMap.SampleLevel(sampFaceSdf, sdfUv, 0);

  // The dump mirrors the signed SDF direction together with U.
  float signedSdfX = result.sampleValue.z * 2.0 - 1.0;
  signedSdfX = lightOnPositiveSide ? signedSdfX : -signedSdfX;
  float3 sdfLocalDir = SafeNormalize(
    float3(signedSdfX, kEps, 1.0 - abs(signedSdfX)));
  float3 sdfWorldNormal = SafeNormalize(LocalToWorld(frame, sdfLocalDir));
  result.bentNormal = SafeNormalize(
    sdfWorldNormal + normalBlend * (geometricNormal * faceSign - sdfWorldNormal));

  // Backlight widening: only when the world light yaw opposes the sun yaw and
  // the head is turned away from the light (localLightZ negative).
  float2 lightXZ = lightVector.xz * rsqrt(
    dot(lightVector.xz, lightVector.xz) + kEps * kEps);
  float2 sunXZ = sunDir.xz * rsqrt(dot(sunDir.xz, sunDir.xz));
  float sideLight = saturate(-dot(lightXZ, sunXZ))
                  * saturate(-localLightZ) * (1.0 - sdfBlend.x);

  float sdfCenter = sideLight * (0.5 - 0.5 * localLightZ * localLightZ)
                  + localLightZ;
  float threshold = clamp(0.5 - 0.5 * sdfCenter, 0.001, 0.999);
  float lower = max(0.0, threshold * 2.0 - 1.0);
  float width = max(1e-5, min(1.0, threshold * 2.0) - lower);
  float sdfValue = 0.5 * (result.sampleValue.x + result.sampleValue.y);
  float sdfBand = Smooth01(saturate((sdfValue - lower) / width));
  float sdfStep = ceil(0.5 * sdfCenter) * (0.5 * sdfCenter);
  result.shadow = abs(-sdfBand - sdfStep) * 2.0 - 1.0;

  float geometricNdotL = clamp(
    dot(geometricNormal * faceSign, lightVector) + rampBias * sdfBlend.x,
    -1.0, 1.0);
  float rampValue = result.shadow + normalBlend * (geometricNdotL - result.shadow);
#if !STEP_FACE_SDF
  result.bentNormal = geometricNormal * faceSign;
  result.shadow = geometricNdotL;
  rampValue = geometricNdotL;
#endif
  result.rampU = rampValue * 0.5 + 0.5;
  return result;
}

float3 EvalColorGrade(
  float3 color, float detailCoverage,
  float enable, float scale, float saturation, float contrast,
  float rimWidth, float rimAmount, float3 tint, float tintMix,
  float3 gradeRimColor, float edgeMask)
{
  if (enable <= 0.5)
    return color;

  float luma = dot(color, kLuma);
  float3 graded = saturation * (color - luma) + luma;
  graded = (graded - 0.5) * contrast + 0.5;
  graded = tintMix * (tint - graded * scale) + graded * scale;

  float edgeStart = 1.0 - rimWidth;
  float edge = Smooth01(saturate(
    ((1.0 - saturate(detailCoverage)) - edgeStart) / max(1e-5, rimWidth)));
  return graded + gradeRimColor * edge * rimAmount * edgeMask;
}

void main(
  float4 v0 : SV_Position,
  float4 v1 : TEXCOORD0,  // base UV
  float4 v2 : TEXCOORD1,  // world position
  float4 v3 : TEXCOORD2,  // geometric normal
  float4 v4 : TEXCOORD3,  // tangent + handedness
  float4 v5 : TEXCOORD4,  // current clip position
  float4 v6 : TEXCOORD5,  // previous clip position
  float4 v7 : TEXCOORD6,  // VS link (kept)
  float4 v8 : TEXCOORD7,  // VS link (kept)
  nointerpolation uint v9 : TEXCOORD8,
  uint v10 : SV_IsFrontFace,
  out float4 o0 : SV_Target,
  out float4 o1 : SV_Target1)
{
  // Named CB aliases (inferred). Packed float4 arrays and registers are unchanged.
  float3 viewRow0        = cb0[0].xyz;
  float3 viewRow1        = cb0[1].xyz;
  float3 viewRow2        = cb0[2].xyz;
  float3 cameraPos       = cb0[44].xyz;
  float3 cameraForward   = float3(cb0[0].z, cb0[1].z, cb0[2].z);
  float  viewBend        = cb0[86].w;
  float  timeValue       = cb0[102].x;
  float  mipBias         = cb0[108].x;
  float  exposure        = cb0[109].x;
  float  exposureAlt     = cb0[111].x;

  float3 sunDir          = cb0[6].xyz;
  float3 mainLightBase   = cb3[0].xyz;
  float3 mainLightOffset = cb0[197].xyz;
  float  rampBias        = cb0[197].w;
  float  lightVectorMix  = cb0[187].w;

  float3 skyBaseColor    = cb3[3].xyz;
  float  skyBaseWeight   = cb3[3].w;
  float3 skyOverride     = cb0[190].xyz;
  float2 sdfBlend        = cb0[198].xy;
  float  skyMix          = cb0[198].y;
  float  dayMix          = cb0[198].w;

  float3 ambientFallback = cb0[189].xyz;
  float3 ambientFacingDir= cb0[192].xyz;
  float3 ambientRemap    = cb0[193].xyz;
  float  skyLitScale     = cb0[186].y;
  float  albedoLitScale  = cb0[186].z;
  float  envScale        = cb0[186].w;
  float  envHighBlend    = cb0[187].x;
  float  ambientWeight   = cb0[187].y;
  float  screenAoBlend   = cb0[187].z;
  float  screenAoScale   = cb4[34].x;
  float  specIntensity   = cb0[199].w;

  float3 rimColor        = cb0[194].xyz;
  float  rimIntensity    = cb0[194].w;
  float2 rimAxisXZ       = cb0[195].yx;
  float  rimAlbedoMix    = cb0[195].z;
  float  rimWidth        = cb0[195].w;
  float3 extraRimColor   = cb0[200].xyz;
  float  extraRimAmount  = cb0[200].w;

  float  smoothness      = cb5[0].x;
  float  specular        = cb5[0].y;
  float  metallic        = cb5[0].z;
  float  backfaceSign    = cb5[1].y;
  float3 baseColorTint   = cb5[5].xyz;
  float4 detailParams    = cb5[11]; // .xy SSS range, .z atlas tile, .w atlas blend
  float3 sssTintColor    = cb5[12].xyz;
  float2 specUvScale     = cb5[16].xy;

  float  gradeEnable     = cb5[3].x;
  float  gradeScale      = cb5[3].y;
  float  gradeSaturation = cb5[3].z;
  float  gradeContrast   = cb5[3].w;
  float  gradeRimWidth   = cb5[4].x;
  float  gradeRimAmount  = cb5[4].y;
  float3 gradeTint       = cb5[7].xyz;
  float  gradeTintMix    = cb5[7].w;
  float3 gradeRimColor   = cb5[8].xyz;

  float3 viewDir = EvalViewDir(v2.xyz, cameraPos, cameraForward, viewBend);
  InstanceFrame frame = LoadInstanceFrame(v9);

  float3 radialDir = SafeNormalize(float3(
    v2.x - frame.centerXZ.x, kEps, v2.z - frame.centerXZ.y));
  float faceSign = (v10 != 0) ? 1.0 : (backfaceSign * 2.0 - 1.0);
  float3 geometricNormal = SafeNormalize(v3.xyz);
  float3 signedGeomNormal = geometricNormal * faceSign;

  // 1) Base colour and half-size detail-colour atlas.
  float4 baseSample = BaseColorMap.SampleBias(sampBaseColor, v1.xy, mipBias);
  float detailTile = detailParams.z * 0.5;
  float signedTileFraction = frac(abs(detailTile));
  signedTileFraction = (detailTile >= -detailTile)
    ? signedTileFraction : -signedTileFraction;
  float2 detailUv = v1.xy * 0.5
                  + float2(signedTileFraction, 0.5 * floor(detailTile));
  float4 detailColor = DetailColorAtlas.SampleBias(
    sampBaseColor, detailUv, mipBias);
  float3 tintedBase = baseSample.xyz * baseColorTint;
  float detailBlend = detailParams.w * detailColor.w;
  float3 baseColor = tintedBase + detailBlend * (detailColor.xyz - tintedBase);
  float baseAlpha = baseSample.w;

  // 2) Packed mask. .y is the SDF/geometric-normal blend used by the dump.
  float4 mask = MaskMap.SampleBias(sampMask, v1.xy, mipBias);

  // Sun direction expressed in the instance frame, flattened to the XZ plane.
  // Its Z tells the dump whether the head faces towards or away from the sun,
  // and two masks are derived from it: a front-side weight that gates the SSS
  // tint, and a back-side weight that gates how much screen AO is allowed in.
  float3 localSunRaw = float3(
    dot(sunDir, frame.basisX),
    dot(sunDir, frame.basisY),
    dot(sunDir, frame.basisZ));
  float sunLocalZ = localSunRaw.z * rsqrt(max(
    1.17549435e-38, dot(localSunRaw.xz, localSunRaw.xz)));

  float frontSide = saturate(sunLocalZ + 0.5);
  float faceSideWeight = mask.x * (frontSide + mask.y * (1.0 - frontSide));
  float backSide = Smooth01(saturate(-2.0 * (sunLocalZ - 0.75)));
  backSide = max(mask.y, backSide * mask.z);

  float4 instanceDetail = LoadInstanceDetail(frame.cbBase);
  DetailResult detail = EvalDetail(
    v1.xy, geometricNormal, v4, faceSign, timeValue, mipBias,
    mask.y, specular, smoothness, instanceDetail);
  baseAlpha *= detail.alphaFactor;

  // 3) Cheap SSS edge tint, modulated by MaskMap.z and material range.
  float horizontalFacing = saturate(dot(signedGeomNormal, viewDir));
  float edgeAmount = 1.0 - (horizontalFacing * 0.850000024 + 0.150000006);
  float sssRange = detailParams.y + mask.z * (detailParams.x - detailParams.y);
  float sssMix = saturate(sssRange * faceSideWeight * edgeAmount);
#if !STEP_SSS_EDGE_TINT
  sssMix = 0;
#endif
  float3 sssTint = sssTintColor * sssMix + (1.0 - sssMix);
  float3 tintedAlbedo = baseColor * sssTint;

  float dielectric = (1.0 - metallic) * 0.959999979;
  float3 diffuse = tintedAlbedo * dielectric;
  float f0 = 0.0399999991 * detail.specular;
  float3 specF0 = metallic * (baseColor * sssTint - f0) + f0;

  float3 shadowLut = EvalShadowColorLut(baseColor, dielectric);
#if !STEP_SHADOW_LUT
  shadowLut = diffuse;
#endif

  // 4) Main-light vector and face SDF.
  float3 lightVector = mainLightBase + mainLightOffset;
  lightVector = lightVectorMix * lightVector - mainLightBase;
  FaceSdfResult faceSdf = EvalFaceSdf(
    v1.xy, frame, geometricNormal, faceSign, lightVector, sunDir,
    mask.y, sdfBlend, rampBias);

  // The bent normal drives fresnel, rim and ambient facing; the detail normal
  // stays separate and only feeds the GGX lobe and the matcap lookup.
  float3 N = faceSdf.bentNormal;
  float nDotVRaw = dot(N, viewDir);
  float specNdotV = saturate(dot(detail.normal, viewDir));

  // 5) Screen masks and toon ramp. FaceSdfResult.rampU is the face-shadow key.
  float2 screen = ScreenData.Load(int3((int2)v0.xy, 0)).xy;
  float screenAo = (screen.x - 1.0) * screenAoScale + 1.0;
  screenAo = screenAo + screenAoBlend * (1.0 - screenAo);

  // Screen shadow is faded in by backSide: a face turned towards the sun keeps
  // this at 1 and receives no screen-space occlusion at all.
  float screenShadow = screen.y * backSide + (1.0 - backSide);

  float4 ramp = SkinDiffuseRamp.SampleLevel(
    sampLinear, float2(faceSdf.rampU, 0.5), 0);
  float3 rampRgb = ramp.xyz;
  float rampChroma =
    max(max(ramp.x, ramp.y), ramp.z) - min(min(ramp.x, ramp.y), ramp.z);
#if !STEP_DIFFUSE_RAMP
  rampRgb = 1.0.xxx;
  rampChroma = 0;
#endif

  float exposureShaped =
    exposure * ((1.0 - exposureAlt) * dayMix + exposureAlt);
  float3 skyColor = skyBaseColor + skyMix * (skyOverride - skyBaseColor);
  float skyWeight = dayMix * (1.0 - skyBaseWeight) + skyBaseWeight;
  float3 skyLight = skyColor * skyWeight;

  float aoProduct = screenShadow * baseAlpha;
  float aoMinimum = min(min(screenShadow, baseAlpha), ramp.w);
  float facing = saturate(dot(N, ambientFacingDir) + ambientRemap.x);
  facing = facing * ambientRemap.y + ambientRemap.z;
  float3 ambientTint =
    (ambientFallback + ambientWeight * aoMinimum * (1.0 - ambientFallback))
    * facing;

  float lowScale = min(1.5, exposureShaped * 0.350000024 + 0.649999976);
  float highScale = min(1.75, max(1.25, exposureShaped));
  float lightingScale = lowScale + envHighBlend * (highScale - lowScale);
  float3 ambientA = ambientTint * lightingScale * envScale;

  float skyLuma = dot(skyLight, kLuma);
  float3 skyShaped = skyLuma + aoMinimum * (skyLight - skyLuma);
  float3 skyMixColor = skyColor * skyMix + (1.0 - skyMix);
  skyShaped = ambientTint * min(1.5, max(0.0, exposureShaped))
            * skyMixColor + skyShaped;
  float3 lightColor = ambientA
    + screenAo * (skyShaped * skyLitScale - ambientA);

  float3 albedoLit = shadowLut * albedoLitScale;
  float albedoLuma = dot(albedoLit * 0.649999976, kLuma);
  float3 albedoBoost =
    (albedoLit * 0.649999976 - albedoLuma) * 1.20000005 + albedoLuma;
  float rampMask = saturate(
    baseAlpha * (screenShadow * mask.y + (1.0 - mask.y)) + ramp.w);
  float3 middle = albedoBoost + rampMask * (albedoLit - albedoBoost);
  middle = middle + aoMinimum * (diffuse - middle);

  float3 rampLit = (rampRgb * rampChroma + (1.0 - rampChroma)) * middle;
  float diffuseLuma = dot(diffuse, kLuma);
  float3 diffuseShifted =
    (diffuse - diffuseLuma) * 1.20000005 + diffuseLuma - albedoLit;
  float3 diffuseLit = albedoLit + aoProduct * diffuseShifted;
  float ratio = min(1.5, max(
    0.0, dot(middle, kLuma) / max(0.001, dot(rampLit, kLuma))));
  diffuseLit = diffuseLit + screenAo * (rampLit * ratio - diffuseLit);

  float shadowMask = aoProduct + screenAo * (aoMinimum - aoProduct);
  float directScale =
    albedoLitScale + shadowMask * (1.0 - albedoLitScale);

  // 6) View-shifted spec texture, matcap and GGX.
  float2 shiftedSpecUv = v1.xy + float2(
    dot(viewDir, frame.basisX), dot(viewDir, frame.basisY)) * specUvScale;
  float3 shiftedSpec = ViewShiftedSpecMap.SampleBias(
    sampBaseColor, shiftedSpecUv, mipBias).xyz;

  float3 matcap = 0;
#if STEP_MATCAP
  if (detail.coverage > 0.00100000005)
  {
    float3 viewNormal = float3(
      dot(viewRow0, detail.normal),
      dot(viewRow1, detail.normal),
      dot(viewRow2, detail.normal));
    float2 matcapUv = SafeNormalize(viewNormal).xy * 0.5 + 0.5;
    float matcapMask = SkinSpecMatcap.SampleBias(
      sampLinear, matcapUv, mipBias).w;
    matcap = (detail.coverage * detail.coverage)
           * matcapMask * screenShadow
           * min(1.5, max(0.5, exposureShaped)) * envScale;
  }
#endif

  float roughness = detail.roughness;
  float alpha = max(0.0078125, roughness * roughness);
  float alpha2 = alpha * alpha;
  float3 sunFlat = SafeNormalize(float3(
    sunDir.x, screenAo * (lightVector.y - 0.5) + 0.5, sunDir.z)) * 2.0;
  float3 halfVector = SafeNormalize(
    lightVector * screenAo + sunFlat + viewDir * (2.0 + screenAo));
  float nDotH = dot(detail.normal, halfVector);
  float distributionDenom = nDotH * alpha2 - nDotH;
  distributionDenom = distributionDenom * nDotH + 1.0;
  distributionDenom *= distributionDenom;
  float distribution = (distributionDenom != alpha2)
    ? alpha2 / distributionDenom : 1.0;
  float specAmount = min(20.0, max(
    0.0,
    distribution * (0.5 / (specNdotV * 2.0 + alpha + 9.99999975e-05))
      - kEps));

  // Both the GGX lobe and the view-shifted spec texture are lit by the same
  // shadowed main-light colour; the texture is not an unlit additive layer.
  float3 specLight = lightColor * (shadowMask * 0.5 + 0.5) * directScale;

  float3 litBeforeRim = diffuseLit * lightColor + shiftedSpec * specLight + matcap;
#if STEP_SPECULAR
  litBeforeRim += specF0 * specAmount * specLight * specIntensity;
#endif
  {
    float luma = dot(litBeforeRim, kLuma);
    float soft = min(0.5, max(0.0, luma - 0.5));
    litBeforeRim = (litBeforeRim - luma) * (soft * soft + 1.0) + luma;
  }

  // 7) Main rim plus the SDF-aware secondary rim.
  float3 rimAxis = float3(rimAxisXZ.x, 0, rimAxisXZ.y);
  rimAxis = SafeNormalize(
    sunDir.yzx * rimAxis.yzx - sunDir.zxy * rimAxis);
  float fresnelRim = 1.0 - abs(nDotVRaw);
  float2 rimEdges =
    rimWidth * float2(-0.600000024, -0.399999976)
    + float2(0.800000012, 0.899999976);
  float rimCurve = Smooth01(saturate(
    (fresnelRim - rimEdges.x) / max(1e-5, rimEdges.y - rimEdges.x)));
  float rimMask = min(
    min(saturate(1.0 + dot(radialDir, rimAxis)), baseAlpha), screen.y);
  float3 rimAlbedo =
    (diffuse - 0.25) * rimAlbedoMix + 0.25;
  rimAlbedo *= saturate(dot(rimAxis, N));
  float3 mainRim =
    rimColor * rimIntensity * rimCurve * rimMask * rimAlbedo;

  float sdfEdge = Smooth01(saturate(
    abs(faceSdf.shadow) * 2.0 - 0.5)) * (1.0 - mask.y);
  float3 secondaryRim =
    extraRimColor * extraRimAmount * sdfEdge * diffuse;
  float3 rimTerm = mainRim + secondaryRim;

  float3 color = litBeforeRim;
#if STEP_RIM
  color += rimTerm;
#endif

  // Local lights / cookies / PCF intentionally remain in step5b_trimmed only.
#if STEP_COLOR_GRADE
  color = EvalColorGrade(
    color, detail.coverage,
    gradeEnable, gradeScale, gradeSaturation, gradeContrast,
    gradeRimWidth, gradeRimAmount, gradeTint, gradeTintMix,
    gradeRimColor, mask.x);
#endif

  float3 gradedColor = color;
  o0 = float4(gradedColor / exposure, 1.0);
  o1.xy = EvalMotion(v5.xyz, v6.xyz);
  o1.z = 1.0;
  o1.w = (detail.coverage > 0.5) ? 0.699999988 : 0.400000006;

#if DEBUG_VIS == 1
  o0 = float4(baseColor, 1);
#elif DEBUG_VIS == 2
  o0 = float4(mask.xyz, 1);
#elif DEBUG_VIS == 3
  o0 = float4(signedGeomNormal * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 4
  o0 = float4(detail.normal * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 5
  o0 = faceSdf.sampleValue;
#elif DEBUG_VIS == 6
  o0 = float4(faceSdf.shadow.xxx * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 7
  o0 = float4(sssTint, 1);
#elif DEBUG_VIS == 8
  o0 = float4(shadowLut, 1);
#elif DEBUG_VIS == 9
  o0 = float4(rampRgb, 1);
#elif DEBUG_VIS == 10
  o0 = float4(rampChroma.xxx, 1);
#elif DEBUG_VIS == 11
  o0 = float4(litBeforeRim, 1);
#elif DEBUG_VIS == 12
  o0 = float4(rimTerm, 1);
#elif DEBUG_VIS == 13
  o0 = float4(gradedColor, 1);
#endif
}
