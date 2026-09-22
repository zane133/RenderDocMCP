// =============================================================================
// ZMD / Endfield Character PS — semantic readable (no rN / no bare cbx in body)
// =============================================================================
// Dump: 2026-09-22 09:43:01
// Full register path: zmd_ps_20260922_094301_step5_analysis.hlsl
//
// Removed: volume probes, detail, tiled lights, volumetric fog.
// Keep: material → normal → F0 → sun/Ramp → rim → IBL → grade → exposure
// Interpolators stay v0..v10 (do not const-copy them).
// CB arrays kept for packing; names are aliases only (inferred).
// =============================================================================

#define STEP_RIM          1
#define STEP_IBL_EMISSIVE 1
#define STEP_COLOR_GRADE  1
#define DEBUG_VIS         0
// 0 final | 1 base | 2 N | 3 mask | 4 litDirect | 5 rim | 6 preExposure | 7 1-|N·V|

TextureCube<float4> ReflectionCube  : register(t18);
Texture2D<float4>   EmissiveMap     : register(t17);
Texture2D<float4>   NormalMap       : register(t16);
Texture2D<float4>   MaterialMask    : register(t15);
Texture2D<float4>   BaseColorMap    : register(t14);
Texture2D<float4>   SpecularBRDFLUT : register(t11);
Texture2D<float4>   RampMap         : register(t10);
Texture2D<float4>   ScreenData      : register(t3);

struct InstanceElem { float val[4]; };
StructuredBuffer<InstanceElem> InstanceDataSB : register(t1);

SamplerState sampEmissive  : register(s6);
SamplerState sampNormal    : register(s5);
SamplerState sampMaterial  : register(s4);
SamplerState sampBaseColor : register(s3);
SamplerState sampLinear    : register(s0);

cbuffer cb5 : register(b5) { float4 cb5[9]; }   // material / grade
cbuffer cb4 : register(b4) { float4 cb4[401]; }  // screen AO helper
cbuffer cb3 : register(b3) { float4 cb3[2054]; } // main light / sky
cbuffer cb1 : register(b1) { float4 cb1[4093]; } // per-instance
cbuffer cb0 : register(b0) { float4 cb0[216]; }  // frame / lighting

static const float3 kLuma = float3(0.212672904, 0.715152204, 0.0721750036);

float  cmp(bool  v) { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }
float  Smooth01(float x) { x = saturate(x); return x * x * (3.0 - 2.0 * x); }

float3 EvalViewDir(float3 worldPos, float3 cameraPos, float3 camForward, float viewBend)
{
  float3 toCam = cameraPos - worldPos;
  toCam = viewBend * (camForward - toCam) + toCam;
  return normalize(toCam);
}

float3 EvalNormalTS(float2 uv, float mip, float normalStrength, out float nZ)
{
  float3 n = NormalMap.SampleBias(sampNormal, uv, mip).xyw; // DXT5nm
  n.x *= n.z;
  n.xy = n.xy * 2.0 - 1.0;
  nZ = sqrt(max(1e-16, 1.0 - saturate(dot(n.xy, n.xy))));
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
  float face = frontFace ? 1.0 : (backfaceSign * 2.0 - 1.0);
  return normalize(N) * face;
}

void EvalF0(float3 albedo, float metallic, float roughness,
            inout float3 colSat, out float dielectF, out float3 diffuse, out float3 specF0)
{
  float f0 = 0.04 * roughness;
  dielectF = (1.0 - metallic) * 0.96;
  diffuse = albedo * dielectF;
  specF0 = metallic * (albedo - f0) + f0;
  colSat *= dielectF;
}

float2 EvalMotion(float3 curr, float3 prev)
{
  float2 a = curr.xy / max(1e-8, curr.z);
  float2 b = prev.xy / max(1e-8, prev.z);
  float2 d = a - b;
  float2 mag = sqrt(sqrt(abs(float2(0.5, -0.5) * d)));
  float2 axis = float2(d.x, -d.y);
  float2 pos = cmp(float2(0, 0) < axis);
  float2 neg = cmp(axis < float2(0, 0));
  float2 s = (float2)((int2)(-(int2)pos + (int2)neg));
  return mag * s * 0.5 + 0.5;
}

void EvalIblF(float nDotV, float roughness, float3 specF0, out float3 F, out float Fsum)
{
  float x = nDotV * nDotV;
  float z = x * nDotV;
  float ry = roughness * roughness;
  float rz = ry * ry * ry;
  float3 ry1 = float3(ry, 1, rz);

  float2 num1 = float2(
    dot(float2(3.32707, 1), float2(x, 9.0632)),
    dot(float2(-9.04755974, 1), float2(x, 0.99044)));
  float3 den1 = float3(
    dot(float3(3.59684992, -1.36772001, 1), float3(x, z, 9.04401016)),
    dot(float3(-16.3174, 1, 9.22949028), float3(x, z, 1)),
    dot(float3(1, 19.7886009, -20.2122993), float3(5.56588984, x, z)));
  float f1 = dot(num1, float2(ry, 1)) / dot(den1, ry1);

  float2 num2 = float2(
    dot(float2(-1.28514, 1), float2(x, 0.99044)),
    dot(float2(1, -0.755907), float2(1.29678, x)));
  float3 den2 = float3(
    dot(float3(2.92338, 59.4188, 1), float3(x, 9.04401, 1)),
    dot(float3(1, -27.0302, 222.592), float3(20.3225, x, 121.563)),
    dot(float3(626.13, 316.627, 1), float3(x, 9.04401, 1)));
  float f2 = dot(num2, float2(ry, 1)) / max(1e-6, dot(den2, ry1));

  F = specF0 * f1 + f2;
  Fsum = f1 + f2;
}

float3 EvalColorGrade(
  float3 color, float ndotv,
  float enable, float sat, float contrast, float scale,
  float rimWidth, float rimAmt, float3 tint, float tintMix, float3 rimCol)
{
  if (enable <= 0.5)
    return color;
  float luma = dot(color, kLuma);
  float3 c = lerp(luma.xxx, color, sat);
  c = (c - 0.5) * contrast + 0.5;
  c = lerp(c * scale, tint, tintMix);
  float edge = 1.0 - rimWidth;
  float t = Smooth01(saturate(((1.0 - saturate(ndotv)) - edge) / max(1e-5, rimWidth)));
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
  float4 v7 : TEXCOORD6,  // VS link
  float4 v8 : TEXCOORD7,  // VS link
  nointerpolation uint v9 : TEXCOORD8,
  uint v10 : SV_IsFrontFace,
  out float4 o0 : SV_Target,
  out float4 o1 : SV_Target1)
{
  // =========================================================================
  // Named CB aliases (inferred). Left side = meaning; right = dump slot.
  // =========================================================================
  // --- camera / frame (cb0) ---
  float3 cameraPos      = cb0[44].xyz;                         // world camera
  float3 camForward     = float3(cb0[0].z, cb0[1].z, cb0[2].z);
  float  viewBend       = cb0[86].w;                           // bend view toward cam Z
  float  mipBias        = cb0[108].x;
  float  exposure       = cb0[109].x;
  float  exposureDay    = cb0[111].x;                          // lerp target with stylize.w

  float3 sunDir         = cb0[6].xyz;                          // key / sun direction
  float3 lightOffset    = cb0[197].xyz;                        // bent main-light offset
  float  wrapBias       = cb0[197].w;                          // add into Ramp wrap
  float3 mainLightBase  = cb3[0].xyz;                          // scene main-light vector
  float  lightVecBlend  = cb0[187].w;                          // mix offset into main light

  float3 skyBaseCol     = cb3[3].xyz;                          // sky color
  float  skyBaseW       = cb3[3].w;                            // sky intensity
  float3 skyOverride    = cb0[191].xyz;                        // stylized sky override
  // cb0[198]: stylize pack — .x wrap kill, .y sky mix, .w day/fog/exposure mix
  float  wrapKill       = cb0[198].x;
  float  skyMix         = cb0[198].y;
  float  dayMix         = cb0[198].w;

  float3 facingDir      = cb0[192].xyz;                        // character facing key
  float  facingBias     = cb0[193].x;
  float  facingScale    = cb0[193].y;
  float  facingAdd      = cb0[193].z;

  // lighting scales (cb0[186..187])
  float  skyLitScale    = cb0[186].y;
  float  albedoLitScale = cb0[186].z;                          // also directKeep floor
  float  envIblScale    = cb0[186].w;
  float  envHiBlend     = cb0[187].x;                          // lo↔hi exposure scale
  float  probeWeight    = cb0[187].y;                          // tint→white mix * AO
  float  screenAoBlend  = cb0[187].z;
  float3 probeTint      = cb0[188].xyz;                        // probe-off GI tint
  float  specIntensity  = cb0[199].w;
  float  screenAoScale  = cb4[34].x;

  // rim / 边缘光
  float3 rimColor       = cb0[194].xyz;
  float  rimIntensity   = cb0[194].w;
  float2 rimAxisZW      = cb0[195].yx;                         // builds rim axis × sun
  float  rimAlbedoMix   = cb0[195].z;
  float  rimWidth       = cb0[195].w;

  // --- material (cb5) ---
  float  normalStrength = cb5[0].w;
  float  brdfLutBlend   = cb5[1].x;                            // LUT ↔ analytic F0
  float  backfaceSign   = cb5[1].y;
  float  alphaBlendAmt  = cb5[1].z;
  float  emissiveGain   = cb5[1].w;
  float  useAlbedoAlpha = cb5[2].x;
  float4 baseColorTint  = cb5[5];
  float  albedoSatScale = cb5[4].z;
  float  albedoSatAmt   = cb5[4].w;
  float3 emissiveTint   = cb5[6].xyz;

  // color grade (cb5[3..8])
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
  float2 instXZ = cb1[iBase + 3].zx; // instance pivot XZ
  if ((16 & asint(cb1[iBase + 4].w)) != 0) {
    int i0 = 2 + asint(cb1[iBase + 5].x);
    int i1 = asint(cb1[iBase + 5].x);
    instXZ = float2(InstanceDataSB[i0].val[3], InstanceDataSB[i1].val[3]);
  }
  float3 sideDir = normalize(float3(v2.x - instXZ.y, 6.10351562e-05, v2.z - instXZ.x));

  // ---- 3) Material maps ----
  // mask: .x metallic | .y roughness | .z AO | .w extra
  float4 baseColor = BaseColorMap.SampleBias(sampBaseColor, v1.xy, mipBias) * baseColorTint;
  float4 mask = MaterialMask.SampleBias(sampMaterial, v1.xy, mipBias);
  float oneMinusW = 1.0 - mask.w;
  float oneMinusX = 1.0 - mask.x;

  float3 satColor = baseColor.xyz * albedoSatScale;
  float satLuma = dot(satColor, kLuma);
  satColor = satLuma + albedoSatAmt * (baseColor.xyz * albedoSatScale - satLuma);

  float nZ;
  float3 nTS = EvalNormalTS(v1.xy, mipBias, normalStrength, nZ);
  float3 emissive = EmissiveMap.SampleBias(sampEmissive, v1.xy, mipBias).xyz;
  float3 N = EvalWorldNormal(nTS, nZ, v3.xyz, v4, v10 != 0, backfaceSign);

  float dielectF;
  float3 diffuse, specF0;
  EvalF0(baseColor.xyz, mask.x, mask.y, satColor, dielectF, diffuse, specF0);

  float a = max(0.0078125, oneMinusW * oneMinusW);
  float a2 = a * a;
  float roughness = oneMinusW; // detail off

  float expH = exposure * lerp(exposureDay, 1.0, dayMix);

  o1.xy = EvalMotion(v5.xyz, v6.xyz);
  o1.zw = float2(1, 0.4);

  // ---- 4) Sun + Ramp lighting ----
  float3 lightVec = mainLightBase + lightOffset;
  lightVec = lightVecBlend * lightVec - mainLightBase;
  float3 lightDir = normalize(float3(lightVec.x, 6.10351562e-05, lightVec.z));

  float3 skyCol = lerp(skyBaseCol, skyOverride, skyMix);
  float  skyW   = lerp(skyBaseW, 1.0, dayMix);
  float3 skyLit = skyCol * skyW;

  float2 screen = ScreenData.Load(int3((int2)v0.xy, 0)).xy;
  float aoScreen = (screen.x - 1.0) * screenAoScale + 1.0;
  aoScreen = aoScreen + screenAoBlend * (1.0 - aoScreen);

  float nDotL = dot(N, lightVec);
  float backlit = saturate(-dot(lightDir.xz, normalize(sunDir.xz)));

  float wrap = nDotL;
  {
    float t = -nDotL * (nDotL * 0.5 - 1.0) - nDotL;
    float y = Smooth01(saturate((-abs(sunDir.y) + 0.75) * 2.0));
    wrap = y * backlit * (1.0 - wrapKill) * (t + 0.5)
         + nDotL + wrapBias * wrapKill;
    wrap = clamp(wrap, -1.0, 1.0);
  }
  float wrapU = wrap * 0.5 + 0.5;
  float nDotSunU = dot(N, sunDir) * 0.5 + 0.5;

  float4 ramp = RampMap.SampleLevel(sampLinear, float2(wrapU, 0.5), 0);
  float rampW = RampMap.SampleLevel(sampLinear, float2(nDotSunU, 0.5), 0).w;
  float rampChroma = max(max(ramp.x, ramp.y), ramp.z) - min(min(ramp.x, ramp.y), ramp.z);

  float aoProd = screen.y * mask.z;
  float ao = min(min(screen.y, mask.z), ramp.w);
  float aoRamp = aoProd * rampW;

  float facing = saturate(dot(N, facingDir) + facingBias);
  facing = facing * facingScale + facingAdd;

  float3 envTint = lerp(probeTint, 1.0.xxx, probeWeight * ao) * facing;

  float scaleLo = min(1.5, expH * 0.35 + 0.65);
  float3 scaleHi = clamp(expH.xxx, float3(1.25, 0.0, 0.5), float3(1.75, 1.5, 1.5));
  float envScale = lerp(scaleLo, scaleHi.x, envHiBlend);
  float3 envA = envTint * envScale * envIblScale;

  float3 skyShaped = lerp(dot(skyLit, kLuma).xxx, skyLit, ao);
  float3 skyMixCol = skyCol * skyMix + (1.0 - skyMix);
  skyShaped = envTint * scaleHi.y * skyMixCol + skyShaped;
  float3 lightCol = lerp(envA, skyShaped * skyLitScale, aoScreen);

  float3 albedoLit = satColor * albedoLitScale;
  float alu = dot(albedoLit * 0.65, kLuma);
  float3 albedoBoost = (albedoLit * 0.65 - alu) * 1.2 + alu;
  float3 mid = lerp(albedoBoost, albedoLit, saturate(rampW * aoProd + ramp.w));
  mid = lerp(mid, baseColor.xyz * dielectF, ao);

  float3 rampLit = (1.0 - rampChroma + ramp.xyz * rampChroma) * mid;

  float diffLuma = dot(diffuse, kLuma);
  float3 diffShift = (baseColor.xyz * dielectF - diffLuma) * 1.2 + diffLuma - albedoLit;
  float3 diffLit = aoRamp * diffShift + albedoLit;

  float ratio = saturate(min(1.5, dot(mid, kLuma) / max(0.001, dot(rampLit, kLuma))));
  diffLit = lerp(diffLit, rampLit * ratio, aoScreen);

  float shadow = lerp(aoRamp, ao, aoScreen);
  float directScale = shadow * (1.0 - albedoLitScale) + albedoLitScale;

  float nDotV = saturate(dot(N, viewDir));
  float3 sunFlat = float3(sunDir.x, lerp(0.5, lightVec.y, aoScreen), sunDir.z);
  sunFlat = normalize(sunFlat) * 2.0;
  float3 H = normalize(lightVec * aoScreen + sunFlat + viewDir * (2.0 + aoScreen));

  float nDotH = dot(N, H);
  float D = nDotH * a2 - nDotH;
  D = (D * nDotH + 1.0);
  D *= D;
  float specD = (a2 != D) ? (a2 / D) : 1.0;

  float invA = specD * (a * a + 9.99999975e-05);
  float lutX = invA + brdfLutBlend * (nDotV * nDotV - invA);
  float3 brdf = SpecularBRDFLUT.SampleLevel(sampLinear, float2(lutX, oneMinusW * oneMinusX), 0).xyz;
  float3 brdfF0 = brdf * specF0;
  specF0 = lerp(specF0, brdfF0, brdfLutBlend);
  float alphaBlend = lerp(1.0, baseColor.w, alphaBlendAmt);

  float specInt = saturate(min(20.0, max(0.0, specD * (0.5 / (nDotV * 2.0 + a + 1e-4)) - 6.10351562e-05)));
  float3 specLight = lightCol * (shadow * 0.5 + 0.5) * directScale;
  float3 litDirect = diffLit * lightCol * alphaBlend
                   + brdfF0 * specInt * specLight * specIntensity;
  {
    float luma = dot(litDirect, kLuma);
    float soft = saturate(min(0.5, max(0.0, luma - 0.5)));
    litDirect = (litDirect - luma) * (soft * soft + 1.0) + luma;
  }

  // ---- 5) Rim ----
  float3 rimAxis = float3(rimAxisZW.x, 0, rimAxisZW.y);
  rimAxis = normalize(sunDir.yzx * rimAxis.yzx - sunDir.zxy * rimAxis);

  float ndotv = dot(viewDir, N);
  float fresnelRim = 1.0 - abs(ndotv);

  float2 rimEdge = rimWidth * float2(-0.6, -0.4) + float2(0.8, 0.9);
  float rimT = Smooth01(saturate((fresnelRim - rimEdge.x) / max(1e-5, rimEdge.y - rimEdge.x)));
  float rimMask = min(min(saturate(1.0 + dot(sideDir, rimAxis)), mask.z), screen.y);
  float3 rimAlbedo = (baseColor.xyz * dielectF - 0.25) * rimAlbedoMix + 0.25;
  rimAlbedo *= saturate(dot(rimAxis, N));
  float3 rimTerm = rimColor * rimIntensity * rimT * rimMask * rimAlbedo;

  // ---- 6) GI stand-in (probe off) ----
  float3 gi = float3(1, 1, 1);
  gi = lerp(gi, skyLit, aoScreen);
  {
    float nDotLflat = dot(lightDir, N);
    float wrapFlat = -nDotLflat * (nDotLflat * 0.5 - 1.0) + 0.5;
    gi *= saturate(aoScreen * wrapFlat);
    gi *= (backlit * aoScreen + (1.0 - aoScreen)) * (1.0 - wrapKill);
    gi *= Smooth01(saturate(5.0 * (0.4 - abs(ndotv))));
    gi *= min(screen.y, mask.z);
    float dark = Smooth01(saturate((-diffLuma + 0.1) * 16.666666));
    gi *= dark * aoScreen + (1.0 - aoScreen);
  }
  gi *= max(0.15.xxx, diffuse);

  float3 color = litDirect + gi;
#if STEP_RIM
  color += rimTerm;
#endif

  // ---- 7) Emissive + cube IBL ----
#if STEP_IBL_EMISSIVE
  color += emissive * emissiveTint * emissiveGain * alphaBlend;

  float3 F; float Fsum;
  EvalIblF(nDotV, max(0.001, roughness), specF0, F, Fsum);

  float3 R = reflect(-viewDir, N);
  float mip = log2(max(0.001, roughness)) * 1.2 + 5.0;
  float3 cube = ReflectionCube.SampleLevel(sampLinear, R, mip).xyz;
  float3 ibl = specF0 * ((1.0 - Fsum) / max(1e-5, Fsum));
  ibl = (ibl * F + F) * cube;
  ibl *= envIblScale * scaleHi.z * directScale;
  color += ibl * probeTint;
#endif

  // ---- 8) Grade + exposure ----
#if STEP_COLOR_GRADE
  color = EvalColorGrade(color, ndotv,
    gradeEnable, gradeSat, gradeContrast, gradeScale,
    gradeRimWidth, gradeRimAmt, gradeTint, gradeTintMix, gradeRimCol);
#endif

  o0.xyz = color / exposure;
  o0.w = (useAlbedoAlpha == 1.0) ? baseColor.w : 1.0;

#if DEBUG_VIS == 1
  o0 = float4(baseColor.xyz, 1);
#elif DEBUG_VIS == 2
  o0 = float4(N * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 3
  o0 = float4(mask.xyz, 1);
#elif DEBUG_VIS == 4
  o0 = float4(litDirect, 1);
#elif DEBUG_VIS == 5
  o0 = float4(rimTerm, 1);
#elif DEBUG_VIS == 6
  o0 = float4(color, 1);
#elif DEBUG_VIS == 7
  o0 = float4(fresnelRim.xxx, 1);
#endif
}
