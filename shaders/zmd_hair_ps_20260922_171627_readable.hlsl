// =============================================================================
// ZMD / Endfield Toon Hair PS — TA semantic readable
// =============================================================================
// Dump: 2026-09-22 17:16:27
// Apply-faithful reference: zmd_hair_ps_20260922_171627_step5_analysis.hlsl
//
// Recipe-faithful, not binary-perfect.
// Removed by user: height / volumetric fog.
// Removed for this TA pass: volume SH probes, tiled local lights, cookies, PCF.
// Kept: base + hair params + dual-layer normal -> strand mask -> toon Ramp
//       -> dual anisotropic lobes (HairSpecularLUT + secondary) -> rim
//       -> grade / exposure.
//
// Interpolators stay v0..v10. Helpers take named args, not raw cbN[i] inside.
// =============================================================================

#define STEP_HEIGHT_FADE   1
#define STEP_DIFFUSE_RAMP  1
#define STEP_HAIR_SPEC     1  // 0 zeros LUT/secondary add (not exp2(0)=1)
#define STEP_RIM           1
#define STEP_COLOR_GRADE   1

#define DEBUG_VIS 0
// 0 final | 1 base | 2 HairParameterMap | 3 N | 4 strand mask
// 5 Ramp RGB | 6 Ramp chroma | 7 hair spec | 8 lit before rim
// 9 rim | 10 1-|N·V| | 11 graded

Texture2D<float4> HairNormalMap    : register(t16);
Texture2D<float4> HairParameterMap : register(t15);
Texture2D<float4> BaseColorMap     : register(t14);
Texture2D<float4> HairSpecularLUT  : register(t13);
Texture2D<float4> DiffuseRamp      : register(t12);
Texture2D<float4> StrandMaskMap    : register(t11);
Texture2D<float4> ScreenData       : register(t4);
Texture2D<float4> SceneDepth       : register(t2);

struct InstanceElem { float val[4]; };
StructuredBuffer<InstanceElem> InstanceDataSB : register(t1);

SamplerState sampHairNormal    : register(s6);
SamplerState sampHairParams    : register(s5);
SamplerState sampBaseAndStrand : register(s4);
SamplerState sampLinear        : register(s1);
SamplerState sampSceneDepth    : register(s0);

cbuffer cb5 : register(b5) { float4 cb5[18]; }
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

float ReconstructZ(float2 xy)
{
  return max(1.00000002e-16, sqrt(1.0 - min(1.0, dot(xy, xy))));
}

float Pow2Exp(float x, float k)
{
  return exp2(k * log2(max(9.99999975e-05, x)));
}

float3 EvalViewDir(float3 worldPos, float3 cameraPos, float3 cameraForward,
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

struct HairInstance
{
  float2 xyX;      // (basisX.x, basisY.x)
  float2 xyY;      // (basisX.y, basisY.y)
  float2 xyZ;      // (basisX.z, basisY.z)
  float3 basisZ;
  float2 centerZX; // dump r6.xy = cb1[+3].zx
  uint   cbBase;
};

HairInstance LoadHairInstance(uint instanceIndex)
{
  HairInstance frame;
  frame.cbBase = instanceIndex << 4;

  if ((16 & asint(cb1[frame.cbBase + 4].w)) != 0)
  {
    int data0 = asint(cb1[frame.cbBase + 5].x);
    int data1 = data0 + 1;
    int data2 = data0 + 2;
    float4 row2 = float4(
      InstanceDataSB[data2].val[0], InstanceDataSB[data2].val[1],
      InstanceDataSB[data2].val[2], InstanceDataSB[data2].val[3]);
    float3 row1 = float3(
      InstanceDataSB[data1].val[0], InstanceDataSB[data1].val[1],
      InstanceDataSB[data1].val[2]);
    float4 row0 = float4(
      InstanceDataSB[data0].val[0], InstanceDataSB[data0].val[1],
      InstanceDataSB[data0].val[2], InstanceDataSB[data0].val[3]);
    frame.xyZ = row2.xy;
    frame.xyY = row1.xy;
    frame.xyX = row0.xy;
    frame.basisZ = float3(row0.z, row1.z, row2.z);
    frame.centerZX = float2(row2.w, row0.w);
  }
  else
  {
    frame.centerZX = cb1[frame.cbBase + 3].zx;
    frame.xyZ = float2(cb1[frame.cbBase + 0].z, cb1[frame.cbBase + 1].z);
    frame.xyY = float2(cb1[frame.cbBase + 0].y, cb1[frame.cbBase + 1].y);
    frame.xyX = float2(cb1[frame.cbBase + 0].x, cb1[frame.cbBase + 1].x);
    frame.basisZ = cb1[frame.cbBase + 2].xyz;
  }
  return frame;
}

float3 EvalStrandDir(HairInstance frame, float directionBlend)
{
  float2 k = float2(directionBlend, 1.0);
  return float3(
    dot(frame.xyZ, k),
    dot(frame.xyX, k),
    dot(frame.xyY, k));
}

float3 InstanceMul(HairInstance frame, float3 localVector)
{
  return float3(
    dot(float3(frame.xyX.x, frame.xyX.y, frame.basisZ.x), localVector),
    dot(float3(frame.xyY.x, frame.xyY.y, frame.basisZ.y), localVector),
    dot(float3(frame.xyZ.x, frame.xyZ.y, frame.basisZ.z), localVector));
}

float3 TangentFromMap(float2 packed, float strength, float3 geomN,
                      float3 bitangent, float3 handedTangent)
{
  float2 xy = strength * packed;
  float z = ReconstructZ(packed);
  return SafeNormalize(xy.y * handedTangent + xy.x * bitangent + z * geomN);
}

float AnisoSinTerm(float tDotH)
{
  float s = sqrt(max(0.0, -tDotH * tDotH + 1.0));
  return Pow2Exp(s, 200.0);
}

float3 EvalColorGrade(
  float3 color, float nDotV,
  float enable, float gradeScale, float saturation, float contrast,
  float rimWidth, float rimGain, float3 tint, float tintMix, float3 rimColor)
{
  if (enable <= 0.5)
    return color;

  float luma = dot(color, kLuma);
  float3 graded = saturation * (color - luma) + luma;
  graded = contrast * (graded - 0.5) + 0.5;
  float3 scaled = gradeScale * graded;
  graded = tintMix * (tint - scaled) + scaled;

  float width = 1.0 - rimWidth;
  float t = saturate((1.0 - saturate(nDotV) - width) / max(1e-5, 1.0 - width));
  t = Smooth01(t);
  return rimColor * t * rimGain + graded;
}

void main(
  float4 v0 : SV_Position,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  float4 v3 : TEXCOORD2,
  float4 v4 : TEXCOORD3,
  float4 v5 : TEXCOORD4,
  float4 v6 : TEXCOORD5,
  float4 v7 : TEXCOORD6,
  float4 v8 : TEXCOORD7,
  nointerpolation uint v9 : TEXCOORD8,
  uint v10 : SV_IsFrontFace0,
  out float4 o0 : SV_Target,
  out float4 o1 : SV_Target1)
{
  // Named CB aliases. Left = meaning; right = dump slot.
  float3 cameraForward   = float3(cb0[0].z, cb0[1].z, cb0[2].z);
  float2 viewRow0xy      = cb0[0].xy;
  float2 viewRow1xy      = cb0[1].xy;
  float2 viewRow2xy      = cb0[2].xy;
  float3 sunDir          = cb0[6].xyz;
  float3 cameraPos       = cb0[44].xyz;
  float2 screenUvScale   = cb0[82].zw;
  float2 depthDecode     = cb0[84].zw;
  float  viewBend        = cb0[86].w;
  float4 viewportClamp   = cb0[87];
  float  mipBias         = cb0[108].x;
  float  exposure        = cb0[109].x;
  float  exposureAlt     = cb0[111].x;
  float  giScale         = cb0[186].y;
  float  albedoLitScale  = cb0[186].z;
  float  envIblScale     = cb0[186].w;
  float4 featureToggles  = cb0[187];
  float3 ambientFallback = cb0[188].xyz;
  float3 lightColorOver  = cb0[191].xyz;
  float3 ambientFaceDir  = cb0[192].xyz;
  float3 ambientFaceRemap= cb0[193].xyz;
  float3 rimColor        = cb0[194].xyz;
  float  rimIntensity    = cb0[194].w;
  float2 rimAxisXZ       = cb0[195].yx;
  float  rimAlbedoMix    = cb0[195].z;
  float  rimWidth        = cb0[195].w;
  float3 sunDirOffset    = cb0[197].xyz;
  float  sunWrapBias     = cb0[197].w;
  float4 blendWeights    = cb0[198];
  float  specGlobalScale = cb0[199].w;

  float  normalStrength  = cb5[0].w;
  float  backfaceSign    = cb5[1].y;
  float  alphaBlend      = cb5[1].z;
  float  alphaMode       = cb5[2].x;
  float  gradeEnable     = cb5[3].x;
  float  gradeScale      = cb5[3].y;
  float  gradeSaturation = cb5[3].z;
  float  gradeContrast   = cb5[3].w;
  float  gradeRimWidth   = cb5[4].x;
  float  gradeRimGain    = cb5[4].y;
  float  albedoSat       = cb5[4].z;
  float  albedoContrast  = cb5[4].w;
  float4 baseColorTint   = cb5[5];
  float3 gradeTint       = cb5[7].xyz;
  float  gradeTintMix    = cb5[7].w;
  float3 gradeRimColor   = cb5[8].xyz;
  float  secondaryNScale = cb5[11].y;
  float2 primaryShift    = cb5[12].xy;
  float  primaryStrength = cb5[12].z;
  float  alignPower      = cb5[12].w;
  float  secondaryPower  = cb5[13].x;
  float  strandDirBlend  = cb5[13].y;
  float3 secondaryColor  = cb5[14].xyz;
  float4 secondaryLobe   = cb5[15];
  float2 strandMaskCtrl  = cb5[16].xy;
  float4 strandMaskUv    = cb5[17];

  float3 mainLightBase   = cb3[0].xyz;
  float4 mainLightColor  = cb3[3];
  float  screenAoScale   = cb4[34].x;

  float3 viewDir = EvalViewDir(v2.xyz, cameraPos, cameraForward, viewBend);
  HairInstance frame = LoadHairInstance(v9);

  // 1) Maps
  float4 baseSample = BaseColorMap.SampleBias(sampBaseAndStrand, v1.xy, mipBias);
  float4 hairParams = HairParameterMap.SampleBias(sampHairParams, v1.xy, mipBias);
  float4 baseColor  = baseColorTint * baseSample;
  float  hairSpecMask = hairParams.y; // primary lobe intensity
  float  hairAo       = hairParams.z;
  float  hairSpecB    = hairParams.w; // secondary lobe colour scale
  float  tangentBlend = hairParams.x;

  float luma = dot(baseColor.xyz * albedoSat, kLuma);
  float3 gradedAlbedo = albedoContrast * (baseColor.xyz * albedoSat - luma) + luma;

  float4 nSample = HairNormalMap.SampleBias(sampHairNormal, v1.xy, mipBias);
  nSample = nSample * 2.0 - 1.0;

  float strandMask = StrandMaskMap.Sample(
    sampBaseAndStrand, v1.xy * strandMaskUv.xy + strandMaskUv.zw).x;

  float3 radialDir = SafeNormalize(float3(
    v2.x - frame.centerZX.y, kEps, v2.z - frame.centerZX.x));

  float3 handedT = (v3.yzx * v4.zxy - v4.yzx * v3.zxy) * v4.w;
  float  faceSign = (v10 != 0) ? 1.0 : (backfaceSign * 2.0 - 1.0);
  float3 N = TangentFromMap(
    nSample.xy, normalStrength, v3.xyz, v4.xyz, handedT) * faceSign;
  float3 geomN = SafeNormalize(v3.xyz) * faceSign;

  float3 hairN = TangentFromMap(
    nSample.zw, secondaryNScale, v3.xyz, v4.xyz, handedT);

  float3 strandDir = SafeNormalize(EvalStrandDir(frame, strandDirBlend));
  float3 hairT = strandDir * hairN;
  hairT = hairN.zxy * strandDir.yzx - hairT;
  hairT = hairT + tangentBlend * (v4.yzx - hairT);
  float3 tmpT = hairT * hairN.zxy;
  hairT = hairN.yzx * hairT.yzx - tmpT;
  hairT = hairT * (tangentBlend * (v4.w - 1.0) + 1.0);

  float3 basisX = float3(frame.xyX.x, frame.xyY.x, frame.xyZ.x);
  float2 hairN_XZ = float2(dot(hairN, basisX), dot(hairN, frame.basisZ));
  float2 view_XZ  = float2(dot(viewDir, basisX), dot(viewDir, frame.basisZ));
  hairN_XZ *= rsqrt(dot(hairN_XZ, hairN_XZ));
  view_XZ  *= rsqrt(dot(view_XZ, view_XZ));
  float alignment = saturate(dot(hairN_XZ, view_XZ));
  alignment = exp2(alignPower * log2(alignment));

  // 2) Per-instance height coverage
  float4 heightCtl = cb1[frame.cbBase + 12];
  float height = Smooth01(saturate((heightCtl.z - v2.y + 0.2) * 2.85714269));
  height = max(heightCtl.w, heightCtl.y * height);
  float specHeightScale = 1.0;
#if STEP_HEIGHT_FADE
  if ((heightCtl.x + height) > 0.00999999978)
  {
    float coverage = max(heightCtl.x, height);
    float albedoScale = coverage * 0.800000012 + (1.0 - coverage);
    specHeightScale = coverage * 2.0 + (1.0 - coverage);
    gradedAlbedo *= albedoScale;
    baseColor.xyz *= albedoScale;
  }
#endif

  float3 dielectricAlbedo = baseColor.xyz * 0.959999979;
  float  specF0 = 0.0399999991 * hairSpecMask;
  float3 dielectricGraded = gradedAlbedo * 0.959999979;

  o1.xy = EvalMotion(v5.xyz, v6.xyz);

  // 3) Main light + screen AO + toon ramp (volume-probe path dropped: identity)
  float3 lightVector = featureToggles.w * (mainLightBase + sunDirOffset)
                     - mainLightBase;
  float3 lightDirH = SafeNormalize(float3(lightVector.x, kEps, lightVector.z));
  float3 lightCol = blendWeights.y * (lightColorOver - mainLightColor.xyz)
                  + mainLightColor.xyz;
  float lightIntensity = blendWeights.w * (1.0 - mainLightColor.w)
                       + mainLightColor.w;
  float3 lightColI = lightCol * lightIntensity;

  float2 screen = ScreenData.Load(int3((int2)v0.xy, 0)).xy;
  float screenAo = (screen.x - 1.0) * screenAoScale + 1.0;
  screenAo = featureToggles.z * (1.0 - screenAo) + screenAo;

  float nDotLraw = dot(N, lightVector);
  float2 sunXZ = sunDir.xz * rsqrt(dot(sunDir.xz, sunDir.xz));
  float sunFacing = saturate(-dot(lightDirH.xz, sunXZ));
  float wrap = nDotLraw * 0.5 - 1.0;
  wrap = -nDotLraw * wrap - nDotLraw;
  float sunYw = Smooth01(saturate((-abs(sunDir.y) + 0.75) * 2.0));
  sunYw = sunYw * sunFacing * (1.0 - blendWeights.x);
  nDotLraw = sunYw * (wrap + 0.5) + nDotLraw;
  nDotLraw = sunWrapBias * blendWeights.x + nDotLraw;
  nDotLraw = clamp(nDotLraw, -1.0, 1.0);
  float rampU = nDotLraw * 0.5 + 0.5;

  float4 ramp = DiffuseRamp.SampleLevel(sampLinear, float2(rampU, 0.5), 0);
  float3 rampRgb = ramp.xyz;
  float rampChroma =
    max(max(ramp.x, ramp.y), ramp.z) - min(min(ramp.x, ramp.y), ramp.z);
#if !STEP_DIFFUSE_RAMP
  rampChroma = 0;
  rampRgb = float3(1, 1, 1);
#endif

  float nDotSun = dot(N, sunDir);
  float rampMaskW = DiffuseRamp.SampleLevel(
    sampLinear, float2(nDotSun * 0.5 + 0.5, 0.5), 0).w;
  float aoHair = screen.y * hairAo;
  float aoMin = min(min(screen.y, hairAo), ramp.w);
  float rampAo = rampMaskW * aoHair;

  float ambFace = saturate(ambientFaceRemap.x + dot(N, ambientFaceDir));
  ambFace = ambFace * ambientFaceRemap.y + ambientFaceRemap.z;

  // Volume-off identity: probe colour = 1, GI dir = 0, mix = 0.
  float3 giColor = ambientFallback;
  giColor = featureToggles.y * aoMin * (1.0 - giColor) + giColor;
  giColor *= ambFace;

  float exposureMix = blendWeights.w * (1.0 - exposureAlt) + exposureAlt;
  exposureMix *= exposure;
  float giLo = min(1.5, exposureMix * 0.350000024 + 0.649999976);
  float giHi = min(1.75, max(1.25, exposureMix));
  float giW = featureToggles.x * (giHi - giLo) + giLo;
  float3 envTerm = giColor * giW * envIblScale;

  float lightLuma = dot(lightColI, kLuma);
  float3 lightShaped = aoMin * (lightCol * lightIntensity - lightLuma) + lightLuma;
  float3 giLit = min(1.5, max(0.0, exposureMix)) * giColor;
  giLit = giLit * (lightCol * blendWeights.y + (1.0 - blendWeights.y)) + lightShaped;
  giLit = screenAo * (giLit * giScale - envTerm) + envTerm;

  float3 litAlbedo = dielectricGraded * albedoLitScale;
  float lumA = dot(litAlbedo * 0.649999976, kLuma);
  float3 wrapped = (litAlbedo * 0.649999976 - lumA) * 1.20000005 + lumA;
  float rampKey = saturate(rampMaskW * aoHair + ramp.w);
  wrapped = rampKey * (dielectricGraded * albedoLitScale - wrapped) + wrapped;
  wrapped = aoMin * (dielectricAlbedo - wrapped) + wrapped;

  float3 rampTint = rampRgb * rampChroma + (1.0 - rampChroma);
  float3 rampLit = rampTint * wrapped;
  float3 boosted = (dielectricAlbedo - dot(dielectricAlbedo, kLuma)) * 1.20000005
                 + dot(dielectricAlbedo, kLuma);
  boosted = rampAo * (boosted - dielectricGraded * albedoLitScale)
          + dielectricGraded * albedoLitScale;

  float lumWrap = dot(wrapped, kLuma);
  float lumRamp = max(0.00100000005, dot(rampLit, kLuma));
  float lumRatio = min(1.5, max(0.0, lumWrap / lumRamp));
  float3 diffuseLit = screenAo * (rampLit * lumRatio - boosted) + boosted;
  float specOcclusion = screenAo * (aoMin - rampMaskW * aoHair) + rampAo;

  // 4) Dual anisotropic lobes
  float2 shift = primaryShift * 2.0 - 1.0;
  float3 T1 = SafeNormalize(hairN * shift.x + hairT);
  float3 halfVec = InstanceMul(frame, hairT);
  halfVec = SafeNormalize(halfVec + halfVec + lightVector * screenAo) + viewDir;
  halfVec *= rsqrt(max(kEps, dot(halfVec, halfVec)));
  float t1h = dot(T1, halfVec);
  float lutU = saturate(AnisoSinTerm(t1h) * hairSpecMask);
  float lutV = ((t1h > 0.0) ? 1.0 : 0.0) * (alignment * alignment);
  float3 specLut = HairSpecularLUT.SampleLevel(sampLinear, float2(lutU, lutV), 0).xyz;
  float3 primarySpec = specLut * lutU * alignment;
  float specPeak = max(max(primarySpec.x, primarySpec.y), primarySpec.z);

  float3 T2 = SafeNormalize(hairN * shift.y + hairT);
  float t2h = dot(T2, halfVec);
  float3 T3 = SafeNormalize(hairN * (secondaryLobe.y * 2.0 - 1.0) + hairT);
  float t3h = dot(T3, halfVec);

  float strandGate = 1.0 - strandMask;
  float uvJitter = ceil(max(0.0, frac(secondaryLobe.x * v1.x) - 0.5));
  strandGate = strandMaskCtrl.y * (strandGate - uvJitter) + uvJitter;
  strandGate = strandGate * secondaryLobe.w + (1.0 - secondaryLobe.w);
  strandGate = specPeak * (1.0 - strandGate) + strandGate;

  float secSin = sqrt(max(0.0, -t3h * t3h + 1.0));
  float secExp = trunc(200.0 * max(0.0, 1.0 - secondaryLobe.z));
  float secTerm = exp2(secExp * log2(max(9.99999975e-05, secSin)));
  float specAlbedoBoost = hairSpecMask * (secTerm * (strandGate - 1.0)) + 1.0;
#if !STEP_HAIR_SPEC
  specAlbedoBoost = 1.0;
#endif

  float3 litDiffuse = diffuseLit * giLit;
  float opacity = alphaBlend * baseColor.w + (1.0 - alphaBlend);
  float specContrast = strandMaskCtrl.x;
  specContrast = specAlbedoBoost * (1.0 - specContrast) + specContrast;
  float lumD = dot(litDiffuse * specAlbedoBoost, kLuma);
  float3 specAlbedo = specContrast * (litDiffuse * specAlbedoBoost - lumD) + lumD;

  primarySpec = primarySpec * specF0 * primaryStrength * specHeightScale;

  float t2sin = sqrt(max(0.0, -t2h * t2h + 1.0));
  float secPow = trunc(200.0 * max(0.0, 1.0 - secondaryPower));
  float secHighlight = Pow2Exp(t2sin, secPow) * alignment;
  float3 secondarySpec = secondaryColor * hairSpecB * secHighlight * specHeightScale;
  secondarySpec = specPeak * (-secondarySpec) + secondarySpec;
  float3 hairSpec = primarySpec * 5.0 + secondarySpec;

  float specLight = specOcclusion * 0.5 + 0.5;
  specLight *= specOcclusion * (1.0 - albedoLitScale) + albedoLitScale;
  hairSpec = giLit * specLight * hairSpec * specGlobalScale;
#if !STEP_HAIR_SPEC
  hairSpec = float3(0, 0, 0);
#endif

  float3 color = specAlbedo * opacity + hairSpec;
  float colorLuma = dot(color, kLuma);
  float contrastW = saturate(colorLuma - 0.5);
  contrastW = min(0.5, max(0.0, contrastW));
  contrastW = contrastW * contrastW + 1.0;
  color = contrastW * (color - colorLuma) + colorLuma;
  float3 litBeforeRim = color;
  float nDotV = dot(viewDir, N);

  // 5) Rim (depth-aware)
  float3 axisRef = float3(rimAxisXZ.x, 0.0, rimAxisXZ.y);
  float3 rimAxis = SafeNormalize(sunDir.yzx * axisRef.yzx - sunDir.zxy * axisRef);
  float2 nView = viewRow1xy * N.y + viewRow0xy * N.x + viewRow2xy * N.z;
  nView *= rsqrt(dot(nView, nView));
  nView *= float2(viewportClamp.y / viewportClamp.x, 1.0);
  float2 rimUv = screenUvScale * v0.xy
               + rimWidth * nView * 0.00600000005;
  rimUv = clamp(rimUv, viewportClamp.zw - 1.0, 2.0 - viewportClamp.zw);
  float sceneZ = SceneDepth.SampleLevel(sampSceneDepth, rimUv, 0).x;
  sceneZ = 1.0 / (depthDecode.x * sceneZ + depthDecode.y);
  float rimDepth = Smooth01(saturate((sceneZ - v0.w - 0.1) * 10.0));
  float3 rimLit = rimColor * rimIntensity * rimDepth;
  float rimMask = min(min(saturate(1.0 + dot(radialDir, rimAxis)), hairAo), screen.y);
  rimLit *= rimMask;
  float3 rimAlbedo = (dielectricAlbedo - 0.25) * rimAlbedoMix + 0.25;
  rimAlbedo *= saturate(dot(rimAxis, N));

  float3 fill = float3(1, 1, 1); // volume-off probe colour
  float fillMax = max(1.0, 0.5 * max(max(fill.x, fill.y), fill.z));
  fill = fill / fillMax;
  fill = screenAo * (lightCol * lightIntensity - fill) + fill;
  float giN = 0.0; // volume-off GI dir
  float nDotLh = dot(lightDirH, N);
  float wrapL = -nDotLh * (nDotLh * 0.5 - 1.0) + 0.5;
  float fillW = saturate(screenAo * (wrapL - giN) + giN);
  fill *= fillW;
  fill *= ((sunFacing * screenAo) + (1.0 - screenAo)) * (1.0 - blendWeights.x);
  fill *= Smooth01(saturate((0.399999976 - abs(nDotV)) * 5.00000048));
  fill *= min(screen.y, hairAo);
  fill *= screenAo * Smooth01(saturate((-16.666666) * (dot(dielectricAlbedo, kLuma) - 0.1)))
        + (1.0 - screenAo);
  fill *= max(float3(0.15, 0.15, 0.15), dielectricAlbedo);

  float3 rimTerm = rimLit * rimAlbedo + fill;
#if STEP_RIM
  color += rimTerm;
#endif

  // Local lights remain in step5_analysis only.
  // Fog removed by user (identity: exposed colour).

#if STEP_COLOR_GRADE
  color = EvalColorGrade(
    color, nDotV, gradeEnable, gradeScale, gradeSaturation, gradeContrast,
    gradeRimWidth, gradeRimGain, gradeTint, gradeTintMix, gradeRimColor);
#endif

  o0.xyz = color / exposure;
  o0.w = (alphaMode == 1.0) ? baseColor.w : 1.0;
  o1.zw = float2(1.0, 0.400000006);

#if DEBUG_VIS == 1
  o0 = float4(baseColor.xyz, 1);
#elif DEBUG_VIS == 2
  o0 = float4(hairParams.xyz, 1);
#elif DEBUG_VIS == 3
  o0 = float4(N * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 4
  o0 = float4(strandMask, strandMask, strandMask, 1);
#elif DEBUG_VIS == 5
  o0 = float4(rampRgb, 1);
#elif DEBUG_VIS == 6
  o0 = float4(rampChroma, rampChroma, rampChroma, 1);
#elif DEBUG_VIS == 7
  o0 = float4(hairSpec, 1);
#elif DEBUG_VIS == 8
  o0 = float4(litBeforeRim, 1);
#elif DEBUG_VIS == 9
  o0 = float4(rimTerm, 1);
#elif DEBUG_VIS == 10
  o0 = float4((1.0 - abs(nDotV)).xxx, 1);
#elif DEBUG_VIS == 11
  o0 = float4(color, 1);
#endif
}
