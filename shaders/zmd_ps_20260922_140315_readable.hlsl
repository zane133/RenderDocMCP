// =============================================================================
// ZMD / Endfield Toon Skin PS — semantic readable (no rN / no bare cb in body)
// =============================================================================
// Dump: 2026-09-22 14:03:15
// Apply-faithful reference: zmd_ps_20260922_140315_step5_analysis.hlsl
//
// This file is recipe-faithful, not binary-perfect.
// Removed (identity of the dump's else / STEP-off branches):
//   - volume SH probes t4..t9  (user: 探针)
//   - procedural splat / fuzz   (user: 绒毛) — also gates SkinSpecMatcap, so
//     matcap add is 0 without coverage
// Also dropped for TA line budget (full path lives in step5):
//   - tiled local lights, cookie, shadow PCF
//   - height / volumetric fog
// Keep: base → sRGB LUT UV → N → SSS edge tint → F0 → ShadowColorLUT →
//       SkinDiffuseRamp → GGX → rim → GI stand-in → grade → /exposure
// Interpolators stay v0..v10 (do not const-copy them).
// =============================================================================

#define STEP_SSS_EDGE_TINT 1  // 0 → multiply = 1
#define STEP_SHADOW_LUT    1  // 0 → use dielectric diffuse instead of LUT hue
#define STEP_DIFFUSE_RAMP  1  // 0 → ramp chroma 0 (keep ramp.a)
#define STEP_SPECULAR      1  // 0 → skip GGX add
#define STEP_RIM           1  // 0 → rim add 0
#define STEP_COLOR_GRADE   1
#define DEBUG_VIS          0
// 0 final | 1 base | 2 N | 3 SSS tint | 4 ShadowColorLUT | 5 ramp rgb
// 6 ramp chroma | 7 litDirect | 8 rim | 9 1-|N·V| | 10 GI

Texture2D<float4> NormalMap       : register(t14);
Texture2D<float4> BaseColorMap    : register(t13);
Texture2D<float4> ShadowColorLUT  : register(t11);
Texture2D<float4> SkinDiffuseRamp : register(t10);
Texture2D<float4> ScreenData      : register(t3);

struct InstanceElem { float val[4]; };
StructuredBuffer<InstanceElem> InstanceDataSB : register(t1);

SamplerState sampNormal    : register(s5);
SamplerState sampBaseColor : register(s4);
SamplerState sampShadowLUT : register(s3);
SamplerState sampLinear    : register(s0);

cbuffer cb5 : register(b5) { float4 cb5[13]; }
cbuffer cb4 : register(b4) { float4 cb4[401]; }
cbuffer cb3 : register(b3) { float4 cb3[2054]; }
cbuffer cb1 : register(b1) { float4 cb1[4093]; }
cbuffer cb0 : register(b0) { float4 cb0[216]; }

static const float3 kLuma = float3(0.212672904, 0.715152204, 0.0721750036);

float  cmp(bool  v) { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }
float3 cmp(bool3 v) { return v ? -1.0.xxx : 0.0.xxx; }
float  Smooth01(float x) { x = saturate(x); return x * x * (3.0 - 2.0 * x); }

float3 EvalViewDir(float3 worldPos, float3 cameraPos, float3 camForward, float viewBend)
{
  float3 toCam = cameraPos - worldPos;
  toCam = viewBend * (camForward - toCam) + toCam;
  return rsqrt(max(9.99999994e-09, dot(toCam, toCam))) * toCam;
}

float3 LinearToSrgb(float3 lin)
{
  float3 lo = 12.9200001 * lin;
  float3 hi = exp2(0.416666657 * log2(abs(lin))) * 1.05499995 - 0.0549999997;
  return saturate((float3(0.00313080009, 0.00313080009, 0.00313080009) >= lin) ? lo : hi);
}

float2 EvalShadowLutUV(float3 srgbBRG, out float sliceF)
{
  // srgbBRG = sRGB(base.zxy) = (B, R, G) encoded
  float slice = 31.0 * srgbBRG.x;
  sliceF = floor(slice);
  float u = sliceF * 0.03125 + (srgbBRG.y * 0.0302734375 + 0.00048828125);
  float v = srgbBRG.z * 0.96875 + 0.015625;
  return float2(u, v);
}

float3 EvalShadowColorLUT(float3 baseColor, float dielectric)
{
  float3 srgb = LinearToSrgb(baseColor.zxy);
  float sliceF;
  float2 uv = EvalShadowLutUV(srgb, sliceF);
  float3 a = ShadowColorLUT.SampleLevel(sampShadowLUT, uv, 0).xyz;
  float3 b = ShadowColorLUT.SampleLevel(sampShadowLUT, uv + float2(0.03125, 0.015625), 0).xyz;
  float t = srgb.x * 31.0 - sliceF;
  return (t * (b - a) + a) * dielectric;
}

float3 EvalNormalTS(float2 uv, float mip, float normalStrength, out float nZ)
{
  float3 n = NormalMap.SampleBias(sampNormal, uv, mip).xyw; // DXT5nm
  n.x *= n.z;
  n.xy = n.xy * 2.0 - 1.0;
  nZ = sqrt(max(1.00000002e-16, 1.0 - min(1.0, dot(n.xy, n.xy))));
  n.xy *= normalStrength;
  return n;
}

float3 EvalWorldNormal(float3 nTS, float nZ, float3 geomN, float4 tangent,
                       bool frontFace, float backfaceSign)
{
  float3 B = tangent.yzx * geomN.zxy;
  B = geomN.yzx * tangent.zxy - B;
  B *= tangent.w;
  float3 N = nTS.x * tangent.xyz + nTS.y * B + nZ * geomN;
  N *= rsqrt(max(1.17549435e-38, dot(N, N)));
  float face = frontFace ? 1.0 : (backfaceSign * 2.0 - 1.0);
  return N * face;
}

float2 EvalMotion(float3 curr, float3 prev)
{
  float2 a = curr.xy / max(9.99999994e-09, curr.z);
  float2 b = prev.xy / max(9.99999994e-09, prev.z);
  float2 d = a - b;
  float2 mag = sqrt(sqrt(abs(float2(0.5, -0.5) * d)));
  float2 axis = float2(d.x, -d.y);
  float2 pos = cmp(float2(0, 0) < axis);
  float2 neg = cmp(axis < float2(0, 0));
  float2 s = (float2)((int2)(-(int2)pos + (int2)neg));
  return mag * s * 0.5 + 0.5;
}

float3 EvalColorGrade(
  float3 color, float ndotvSat,
  float enable, float sat, float contrast, float scale,
  float rimWidth, float rimAmt, float3 tint, float tintMix, float3 rimCol)
{
  if (enable <= 0.5)
    return color;
  float luma = dot(color, kLuma);
  float3 c = sat * (color - luma) + luma;
  c = (c - 0.5) * contrast + 0.5;
  c = tintMix * (tint - c * scale) + c * scale;
  float edge = 1.0 - rimWidth;
  float t = Smooth01(saturate(((1.0 - ndotvSat) - edge) / max(1e-5, rimWidth)));
  return c + rimCol * t * rimAmt;
}

void main(
  float4 v0 : SV_Position,
  float4 v1 : TEXCOORD0,  // uv
  float4 v2 : TEXCOORD1,  // worldPos
  float4 v3 : TEXCOORD2,  // geomNormal
  float4 v4 : TEXCOORD3,  // tangent + sign
  float4 v5 : TEXCOORD4,  // motion curr
  float4 v6 : TEXCOORD5,  // motion prev
  float4 v7 : TEXCOORD6,  // splat triplanar (unused; VS still writes)
  float4 v8 : TEXCOORD7,  // splat object pos (unused; VS still writes)
  nointerpolation uint v9 : TEXCOORD8,
  uint v10 : SV_IsFrontFace,
  out float4 o0 : SV_Target,
  out float4 o1 : SV_Target1)
{
  // =========================================================================
  // Named CB aliases (inferred). Left = meaning; right = dump slot.
  // =========================================================================
  float3 cameraPos      = cb0[44].xyz;
  float3 camForward     = float3(cb0[0].z, cb0[1].z, cb0[2].z);
  float  viewBend       = cb0[86].w;
  float  mipBias        = cb0[108].x;
  float  exposure       = cb0[109].x;
  float  exposureAlt    = cb0[111].x;

  float3 sunDir         = cb0[6].xyz;
  float3 lightOffset    = cb0[197].xyz;
  float  wrapBias       = cb0[197].w;
  float3 mainLightBase  = cb3[0].xyz;
  float  lightVecBlend  = cb0[187].w;

  float3 skyBaseCol     = cb3[3].xyz;
  float  skyBaseW       = cb3[3].w;
  float3 skyOverride    = cb0[190].xyz;
  float  wrapKill       = cb0[198].x;
  float  skyMix         = cb0[198].y;
  float  dayMix         = cb0[198].w;

  float3 facingDir      = cb0[192].xyz;
  float  facingBias     = cb0[193].x;
  float  facingScale    = cb0[193].y;
  float  facingAdd      = cb0[193].z;
  float3 ambientFallback= cb0[189].xyz;

  float  skyLitScale    = cb0[186].y;
  float  albedoLitScale = cb0[186].z;
  float  envIblScale    = cb0[186].w;
  float  envHiBlend     = cb0[187].x;
  float  probeWeight    = cb0[187].y;   // with probes removed: tints fallback→white * AO
  float  aoFeatureBlend = cb0[187].z;
  float  specIntensity  = cb0[199].w;
  float  screenAoScale  = cb4[34].x;

  float3 rimColor       = cb0[194].xyz;
  float  rimIntensity   = cb0[194].w;
  float2 rimAxisZW      = cb0[195].yx;
  float  rimAlbedoMix   = cb0[195].z;
  float  rimWidth       = cb0[195].w;

  float  smoothness     = cb5[0].x;
  float  specular       = cb5[0].y;
  float  metallic       = cb5[0].z;
  float  normalStrength = cb5[0].w;
  float  backfaceSign   = cb5[1].y;
  float3 baseColorTint  = cb5[5].xyz;
  float  sssTintAmount  = cb5[11].x;
  float3 sssTintColor   = cb5[12].xyz;

  float  gradeEnable    = cb5[3].x;
  float  gradeScale     = cb5[3].y;
  float  gradeSat       = cb5[3].z;
  float  gradeContrast  = cb5[3].w;
  float  gradeRimWidth  = cb5[4].x;
  float  gradeRimAmt    = cb5[4].y;
  float3 gradeTint      = cb5[7].xyz;
  float  gradeTintMix   = cb5[7].w;
  float3 gradeRimCol    = cb5[8].xyz;

  // ---- 1) View ----
  float3 viewDir = EvalViewDir(v2.xyz, cameraPos, camForward, viewBend);

  // ---- 2) Instance side dir (rim mask) ----
  uint iBase = (uint)v9 << 4;
  float2 instXZ = cb1[iBase + 3].zx;
  if ((16 & asint(cb1[iBase + 4].w)) != 0) {
    int i0 = 2 + asint(cb1[iBase + 5].x);
    int i1 = asint(cb1[iBase + 5].x);
    instXZ = float2(InstanceDataSB[i0].val[3], InstanceDataSB[i1].val[3]);
  }
  float3 sideDir = normalize(float3(v2.x - instXZ.y, 6.10351562e-05, v2.z - instXZ.x));

  // ---- 3) Material ----
  float4 baseSample = BaseColorMap.SampleBias(sampBaseColor, v1.xy, mipBias);
  float3 baseColor = baseSample.xyz * baseColorTint;
  float  baseAlpha = baseSample.w;

  float nZ;
  float3 nTS = EvalNormalTS(v1.xy, mipBias, normalStrength, nZ);
  float3 N = EvalWorldNormal(nTS, nZ, v3.xyz, v4, v10 != 0, backfaceSign);
  // dump: normalize (Nx, eps, Nz) — used only for the facing key
  float3 Nxz = float3(N.x, 6.10351562e-05, N.z);
  Nxz *= rsqrt(dot(Nxz, Nxz));

  float nDotVRaw = dot(N, viewDir);
  float nDotVSat = saturate(nDotVRaw);
  float sssMix = saturate(sssTintAmount * (1.0 - (nDotVSat * 0.850000024 + 0.150000006)));
  float3 sssTint = sssTintColor * sssMix + (1.0 - sssMix);
#if !STEP_SSS_EDGE_TINT
  sssMix = 0;
  sssTint = 1.0.xxx;
#endif
  float3 tintedAlbedo = sssTint * baseColor;

  float dielectric = (1.0 - metallic) * 0.959999979;
  float3 diffuse = tintedAlbedo * dielectric;
  float  f0 = 0.0399999991 * specular;
  float3 specF0 = metallic * (baseColor * sssTint - f0) + f0;

  float rough = 1.0 - smoothness; // splat-off identity: no roughness lift
  float a = max(0.0078125, rough * rough);
  float a2 = a * a;

  float3 shadowLut = EvalShadowColorLUT(baseColor, dielectric);
#if !STEP_SHADOW_LUT
  shadowLut = diffuse;
#endif

  float expH = exposure * ((1.0 - exposureAlt) * dayMix + exposureAlt);

  o1.xy = EvalMotion(v5.xyz, v6.xyz);
  o1.zw = float2(1.0, 0.400000006); // splat coverage 0 → 0.4 flag

  // ---- 4) Sun + ramp ----
  float3 lightVec = mainLightBase + lightOffset;
  lightVec = lightVecBlend * lightVec - mainLightBase;
  // dump r12.xzw = normalize(Lx, Lz, eps).xwz → (Lx', eps, Lz')
  float3 Lxz = float3(lightVec.x, lightVec.z, 6.10351562e-05);
  Lxz *= rsqrt(dot(Lxz, Lxz));
  float3 lightDir = float3(Lxz.x, Lxz.z, Lxz.y); // (Lx', eps, Lz') for N·Lflat

  float3 skyCol = skyMix * (skyOverride - skyBaseCol) + skyBaseCol;
  float  skyW   = dayMix * (1.0 - skyBaseW) + skyBaseW;
  float3 skyLit = skyCol * skyW;

  float2 screen = ScreenData.Load(int3((int2)v0.xy, 0)).xy;
  float aoScreen = (screen.x - 1.0) * screenAoScale + 1.0;
  aoScreen = aoScreen + aoFeatureBlend * (1.0 - aoScreen);

  float nDotL = dot(N, lightVec);
  float wrapU = clamp(nDotL + wrapBias * wrapKill, -1.0, 1.0) * 0.5 + 0.5;
  float4 ramp = SkinDiffuseRamp.SampleLevel(sampLinear, float2(wrapU, 0.5), 0);
  float3 rampRgb = ramp.xyz;
  float  rampChroma = max(max(ramp.x, ramp.y), ramp.z) - min(min(ramp.x, ramp.y), ramp.z);
#if !STEP_DIFFUSE_RAMP
  rampChroma = 0;
  rampRgb = 1.0.xxx;
#endif

  float aoProd = screen.y * baseAlpha;
  float aoMin  = min(min(screen.y, baseAlpha), ramp.w);

  float facing = saturate(dot(Nxz, facingDir) + facingBias);
  facing = facing * facingScale + facingAdd;
  float3 envTint = (probeWeight * aoMin * (1.0.xxx - ambientFallback) + ambientFallback) * facing;

  float scaleLo = min(1.5, expH * 0.350000024 + 0.649999976);
  float envScale = (min(1.75, max(1.25, expH)) - scaleLo) * envHiBlend + scaleLo;
  float3 envA = envTint * envScale * envIblScale;

  float skyLuma = dot(skyLit, kLuma);
  float3 skyShaped = aoMin * (skyLit - skyLuma) + skyLuma;
  float3 skyMixCol = skyCol * skyMix + (1.0 - skyMix);
  skyShaped = envTint * min(1.5, max(0.0, expH)) * skyMixCol + skyShaped;
  float3 lightCol = aoScreen * (skyShaped * skyLitScale - envA) + envA;

  float3 albedoLit = shadowLut * albedoLitScale;
  float alu = dot(albedoLit * 0.649999976, kLuma);
  float3 albedoBoost = (albedoLit * 0.649999976 - alu) * 1.20000005 + alu;
  float3 mid = saturate(baseAlpha * screen.y + ramp.w) * (albedoLit - albedoBoost) + albedoBoost;
  mid = aoMin * (diffuse - mid) + mid;

  float3 rampLit = (rampRgb * rampChroma + (1.0 - rampChroma)) * mid;

  float diffLuma = dot(diffuse, kLuma);
  float3 diffShift = (diffuse - diffLuma) * 1.20000005 + diffLuma - albedoLit;
  float3 diffLit = aoProd * diffShift + albedoLit;

  float ratio = min(1.5, max(0.0, dot(mid, kLuma) / max(0.001, dot(rampLit, kLuma))));
  diffLit = aoScreen * (rampLit * ratio - diffLit) + diffLit;

  float shadow = aoScreen * (aoMin - aoProd) + aoProd;
  float directScale = shadow * (1.0 - albedoLitScale) + albedoLitScale;

  float3 sunFlat = float3(sunDir.x, aoScreen * (lightVec.y - 0.5) + 0.5, sunDir.z);
  sunFlat *= rsqrt(max(1.17549435e-38, dot(sunFlat, sunFlat)));
  sunFlat += sunFlat;
  float3 H = lightVec * aoScreen + sunFlat + viewDir * (2.0 + aoScreen);
  H *= rsqrt(dot(H, H));

  float nDotH = dot(N, H);
  float D = nDotH * a2 - nDotH;
  D = D * nDotH + 1.0;
  D *= D;
  float specD = (D != a2) ? (a2 / D) : 1.0;
  float specInt = min(20.0, max(0.0, specD * (0.5 / (nDotVSat * 2.0 + a + 9.99999975e-05)) - 6.10351562e-05));
  float3 specLight = lightCol * (shadow * 0.5 + 0.5) * directScale;
  float3 litDirect = diffLit * lightCol;
#if STEP_SPECULAR
  litDirect += specF0 * specInt * specLight * specIntensity;
#endif
  {
    float luma = dot(litDirect, kLuma);
    float soft = min(0.5, max(0.0, luma - 0.5));
    litDirect = (litDirect - luma) * (soft * soft + 1.0) + luma;
  }

  // ---- 5) Rim (capture 1-|N·V| here; later GI reuses the same math) ----
  float3 rimAxis = float3(rimAxisZW.x, 0, rimAxisZW.y);
  rimAxis = sunDir.yzx * rimAxis.yzx - sunDir.zxy * rimAxis;
  rimAxis *= rsqrt(dot(rimAxis, rimAxis));

  float fresnelRim = 1.0 - abs(nDotVRaw);
  float2 rimEdge = rimWidth * float2(-0.600000024, -0.399999976) + float2(0.800000012, 0.899999976);
  float rimT = Smooth01(saturate((fresnelRim - rimEdge.x) / (rimEdge.y - rimEdge.x)));
  float rimMask = min(min(saturate(1.0 + dot(sideDir, rimAxis)), baseAlpha), screen.y);
  float3 rimAlbedo = (diffuse - 0.25) * rimAlbedoMix + 0.25;
  rimAlbedo *= saturate(dot(rimAxis, N));
  float3 rimTerm = rimColor * rimIntensity * rimT * rimMask * rimAlbedo;

  // ---- 6) GI stand-in (probe path removed → dump else: dir=0, color=1) ----
  float3 gi = 1.0.xxx;
  gi = aoScreen * (skyLit - gi) + gi;
  {
    float nDotLflat = dot(lightDir, N);
    float wrapFlat = -nDotLflat * (nDotLflat * 0.5 - 1.0) + 0.5;
    gi *= saturate(aoScreen * wrapFlat);
    float backlit = saturate(-dot(lightDir.xz, sunDir.xz * rsqrt(dot(sunDir.xz, sunDir.xz))));
    gi *= (backlit * aoScreen + (1.0 - aoScreen)) * (1.0 - wrapKill);
    gi *= Smooth01(saturate(5.00000048 * (0.399999976 - abs(nDotVRaw))));
    gi *= min(screen.y, baseAlpha);
    float dark = Smooth01(saturate((-diffLuma + 0.100000001) * 16.666666));
    gi *= dark * aoScreen + (1.0 - aoScreen);
  }
  gi *= max(0.150000006.xxx, diffuse);

  float3 color = litDirect + gi;
#if STEP_RIM
  color += rimTerm;
#endif

#if STEP_COLOR_GRADE
  color = EvalColorGrade(color, nDotVSat,
    gradeEnable, gradeSat, gradeContrast, gradeScale,
    gradeRimWidth, gradeRimAmt, gradeTint, gradeTintMix, gradeRimCol);
#endif

  o0.xyz = color / exposure;
  o0.w = 1.0;

#if DEBUG_VIS == 1
  o0 = float4(baseColor, 1);
#elif DEBUG_VIS == 2
  o0 = float4(N * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 3
  o0 = float4(sssTint, 1);
#elif DEBUG_VIS == 4
  o0 = float4(shadowLut, 1);
#elif DEBUG_VIS == 5
  o0 = float4(ramp.xyz, 1);
#elif DEBUG_VIS == 6
  o0 = float4(rampChroma, rampChroma, rampChroma, 1);
#elif DEBUG_VIS == 7
  o0 = float4(litDirect, 1);
#elif DEBUG_VIS == 8
  o0 = float4(rimTerm, 1);
#elif DEBUG_VIS == 9
  o0 = float4(fresnelRim.xxx, 1);
#elif DEBUG_VIS == 10
  o0 = float4(gi, 1);
#endif
}
