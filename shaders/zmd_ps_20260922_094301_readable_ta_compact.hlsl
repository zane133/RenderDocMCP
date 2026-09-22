// =============================================================================
// ZMD / Endfield Character PS — compact readable (target ≤500 lines)
// =============================================================================
// Source: 3Dmigoto 2026-09-22 09:43:01 | Lineage: Step1→5 Apply-OK
//
// Removed for size (identity / omitted):
//   Volume SH probes t4..t9, Detail t12/t13, Tiled local lights (see step5),
//   Heavy volumetric fog t20 (exposure-only here).
// Keep: material, normal, F0, sun+RampMap, rim, emissive+cube, color grade.
// Full dump: zmd_ps_20260922_094301_step5_analysis.hlsl
// =============================================================================

#define STEP_RIM          1
#define STEP_IBL_EMISSIVE 1
#define STEP_COLOR_GRADE  1
#define DEBUG_VIS         0
// 0 final | 1 baseColor | 2 shadingN | 3 mask | 4 lit | 5 rim | 6 preFog | 7 1-|N·V|

TextureCube<float4> ReflectionCube  : register(t18);
Texture2D<float4>   EmissiveMap     : register(t17);
Texture2D<float4>   NormalMap       : register(t16);
Texture2D<float4>   MaterialMask    : register(t15);
Texture2D<float4>   BaseColorMap    : register(t14);
Texture2D<float4>   SpecularBRDFLUT : register(t11);
Texture2D<float4>   RampMap         : register(t10);
Texture2D<float4>   ScreenData      : register(t3);

struct InstElem { float val[4]; };
StructuredBuffer<InstElem> InstanceDataSB : register(t1);

SamplerState sampEmissive  : register(s6);
SamplerState sampNormal    : register(s5);
SamplerState sampMaterial  : register(s4);
SamplerState sampBaseColor : register(s3);
SamplerState sampLinear    : register(s0);

cbuffer cb5 : register(b5) { float4 cb5[9]; }
cbuffer cb4 : register(b4) { float4 cb4[401]; }
cbuffer cb3 : register(b3) { float4 cb3[2054]; }
cbuffer cb1 : register(b1) { float4 cb1[4093]; }
cbuffer cb0 : register(b0) { float4 cb0[216]; }

float  cmp(bool  v) { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }

static const float3 kLuma = float3(0.212672904, 0.715152204, 0.0721750036);

float3 EvalViewDir(float3 worldPos, out float toCamLenSq, out float rcpLen)
{
  float3 toCam = cb0[44].xyz + -worldPos;
  float3 camFwdZ = float3(cb0[0].z, cb0[1].z, cb0[2].z);
  toCam = cb0[86].www * (camFwdZ + -toCam) + toCam;
  toCamLenSq = dot(toCam, toCam);
  rcpLen = rsqrt(max(9.99999994e-09, toCamLenSq));
  return toCam * rcpLen;
}

float3 EvalUnpackNormalMap(float2 uv, float mip, out float nz)
{
  float3 n = NormalMap.SampleBias(sampNormal, uv, mip).xyw;
  n.x = n.z * n.x;
  n.xy = n.xy * float2(2, 2) + float2(-1, -1);
  nz = dot(n.xy, n.xy);
  nz = min(1, nz);
  nz = sqrt(max(1.00000002e-16, 1 + -nz));
  n.xy = cb5[0].ww * n.xy;
  return n;
}

float3 EvalShadingNormal(float3 nTS, float nz, float3 geomN, float4 tangent, uint isFrontFace)
{
  float3 bitangent = tangent.yzx * geomN.zxy;
  bitangent = geomN.yzx * tangent.zxy + -bitangent;
  bitangent = tangent.www * bitangent;
  float3 n = bitangent * nTS.yyy;
  n = nTS.xxx * tangent.xyz + n;
  n = nz * geomN + n;
  float faceSign = cb5[1].y * 2 + -1;
  faceSign = isFrontFace ? 1 : faceSign;
  n = n * rsqrt(max(1.17549435e-38, dot(n, n)));
  return n * faceSign;
}

void EvalF0(float3 albedo, float metallic, float roughness,
            out float dielectF, out float3 diffuse, out float3 specF0)
{
  float d0 = 0.0399999991 * roughness;
  dielectF = -metallic * 0.959999979 + 0.959999979;
  diffuse = dielectF * albedo;
  specF0 = -roughness * float3(0.0399999991, 0.0399999991, 0.0399999991) + albedo;
  specF0 = metallic * specF0 + d0;
}

float2 EvalMotionVector(float3 curr, float3 prev)
{
  float d = max(9.99999994e-09, curr.z);
  float2 a = curr.xy / d;
  d = max(9.99999994e-09, prev.z);
  float2 b = prev.xy / d;
  float2 delta = a + -b;
  float2 mag = float2(0.5, -0.5) * delta;
  mag = sqrt(abs(mag));
  mag = sqrt(mag);
  float2 axis = float2(delta.x, -delta.y);
  float2 pos = cmp(float2(0, 0) < axis);
  float2 neg = cmp(axis < float2(0, 0));
  int2 sgn = (int2)-pos + (int2)neg;
  return mag * (float2)sgn * float2(0.5, 0.5) + float2(0.5, 0.5);
}

float3 SoftLightRamp(float wrap01, float nDotSun01, out float rampChroma, out float rampW)
{
  float4 a = RampMap.SampleLevel(sampLinear, float2(wrap01, 0.5), 0);
  float4 b = RampMap.SampleLevel(sampLinear, float2(0.5, nDotSun01), 0);
  float mx = max(a.x, max(a.y, a.z));
  float mn = min(a.x, min(a.y, a.z));
  rampChroma = mx - mn;
  rampW = b.w;
  return a.xyz;
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
  uint v10 : SV_IsFrontFace,
  out float4 o0 : SV_Target,
  out float4 o1 : SV_Target1)
{
  float mipBias = cb0[108].x;
  float3 sunDir = cb0[6].xyz;
  float exposureScale = cb0[109].x;
  float3 rimColor = cb0[194].xyz;
  float rimIntensity = cb0[194].w;
  float2 rimAxisZW = cb0[195].yx;
  float rimAlbedoMix = cb0[195].z;
  float rimNdotVWidth = cb0[195].w;

  // 1) View
  float toCamLenSq, rcpLen;
  float3 viewDir = EvalViewDir(v2.xyz, toCamLenSq, rcpLen);

  // 2) Instance XZ helpers (for rim side vector); detail path removed
  uint iBase = (uint)v9.x << 4;
  float2 instXZ;
  if ((16 & asint(cb1[iBase + 4].w)) != 0) {
    int i0 = 2 + asint(cb1[iBase + 5].x);
    instXZ.x = InstanceDataSB[i0].val[12 / 4];
    instXZ.y = InstanceDataSB[asint(cb1[iBase + 5].x)].val[12 / 4];
  } else {
    instXZ = cb1[iBase + 3].zx;
  }
  float3 sideDir = float3(v2.x - instXZ.y, 6.10351562e-05, v2.z - instXZ.x);
  sideDir = sideDir * rsqrt(dot(sideDir, sideDir));

  // 3) Material
  float4 baseSample = BaseColorMap.SampleBias(sampBaseColor, v1.xy, mipBias);
  float4 mask = MaterialMask.SampleBias(sampMaterial, v1.xy, mipBias);
  float2 oneMinusMaskWX = float2(1, 1) + -mask.wx; // .x=1-w, .y=1-x
  baseSample *= cb5[5];
  float3 satAdj = cb5[4].zzz * baseSample.xyz;
  float satLuma = dot(satAdj, kLuma);
  satAdj = baseSample.xyz * cb5[4].zzz + -satLuma;
  satAdj = cb5[4].www * satAdj + satLuma;
  float nz;
  float3 nTS = EvalUnpackNormalMap(v1.xy, mipBias, nz);
  float3 emissive = EmissiveMap.SampleBias(sampEmissive, v1.xy, mipBias).xyz;
  float3 dbgBase = baseSample.xyz;
  float3 dbgMask = mask.xyz;

  // 4) Shading normal (no detail overlay)
  float3 shadingN = EvalShadingNormal(nTS, nz, v3.xyz, v4, v10);
  float3 geomN = normalize(v3.xyz) * (v10 ? 1.0 : (cb5[1].y * 2.0 - 1.0));
  float3 dbgN = shadingN;

  // Probe removed → identity used by later lighting
  float3 probeTint = cb0[188].xyz; // r14 in dump else
  float3 probeScale = float3(1, 1, 1); // r17
  float probeBlend = 0;              // r6.w

  // Exposure helper scale (from dump before probes)
  float expMix = -cb0[111].x + 1;
  expMix = cb0[198].w * expMix + cb0[111].x;
  expMix = exposureScale * expMix;

  // 7) F0 + motion (detail flag = 0)
  float dielectF;
  float3 diffuse, specF0;
  EvalF0(baseSample.xyz, mask.x, mask.y, dielectF, diffuse, specF0);
  satAdj *= dielectF;
  float a = max(0.0078125, oneMinusMaskWX.x * oneMinusMaskWX.x);
  float a2 = a * a;
  o1.xy = EvalMotionVector(v5.xyz, v6.xyz);
  o1.w = 0.400000006; // detail flag off → dump uses 0.4
  o1.z = 1;

  // 8) Sun + RampMap wrap lighting (compacted dump flow)
  float3 lightVec = cb3[0].xyz + cb0[197].xyz;
  lightVec = cb0[187].www * lightVec + -cb3[0].xyz;
  float3 lightDir = normalize(float3(lightVec.x, 6.10351562e-05, lightVec.z));
  float3 skyCol = -cb3[3].xyz + cb0[191].xyz;
  skyCol = cb0[198].yyy * skyCol + cb3[3].xyz;
  float skyW = -cb3[3].w + 1;
  skyW = cb0[198].w * skyW + cb3[3].w;

  float2 screen = ScreenData.Load(int3((int2)v0.xy, 0)).xy;
  float aoScreen = -1 + screen.x;
  aoScreen = cb4[34].x * aoScreen + 1;
  aoScreen = cb0[187].z * (1 + -aoScreen) + aoScreen;

  float nDotLvec = dot(shadingN, lightVec);
  float3 sunXZ = sunDir.xz * rsqrt(dot(sunDir.xz, sunDir.xz));
  float backlit = saturate(-dot(lightDir.xz, sunXZ));
  float wrap = nDotLvec;
  {
    float t = wrap * 0.5 + -1;
    t = -wrap * t + -wrap;
    float y = saturate((-abs(sunDir.y) + 0.75) * 2);
    y = y * y * (-2 * y + 3);
    y = y * backlit * (1 + -cb0[198].x);
    wrap = y * (t + 0.5) + wrap;
    wrap = cb0[197].w * cb0[198].x + wrap;
    wrap = clamp(wrap, -1, 1);
  }
  float wrap01 = wrap * 0.5 + 0.5;
  float nDotSun = dot(shadingN, sunDir);
  float nDotSun01 = nDotSun * 0.5 + 0.5;
  float rampChroma, rampW;
  float3 rampRGB = SoftLightRamp(wrap01, nDotSun01, rampChroma, rampW);

  float aoComb = min(min(screen.y, mask.z), rampRGB.w); // approx dump mins
  float3 litDirect = satAdj * cb0[186].z;
  // Specular BRDF LUT
  float nDotV = saturate(dot(shadingN, viewDir));
  float2 brdfUV = float2(cb5[1].x * (nDotV * nDotV - a2 / max(a2 + 1e-4, 1e-4)) + a2 / max(a2 + 1e-4, 1e-4),
                         oneMinusMaskWX.x * oneMinusMaskWX.y);
  // Keep dump-like LUT UV:
  float D = a2 / max((nDotV * (a2 - 1) + 1), 1e-4);
  D = D * D;
  float specTerm = a2 / max(D, 1e-4);
  float2 lutUV;
  lutUV.x = cb5[1].x * (nDotV * nDotV - specTerm) + specTerm;
  lutUV.y = oneMinusMaskWX.x * (1 + -mask.x); // rough stand-in for r3.z*r3.w
  // Faithful: r3.zw = 1-mask.wx → r3.z=1-w, r3.w=1-x; lut.y = r3.z * r3.w
  lutUV.y = oneMinusMaskWX.x * oneMinusMaskWX.y;
  {
    float invA = 1.0 / (a * a + 9.99999975e-05);
    float ndv2 = nDotV * nDotV;
    float t = ndv2 * a2 + -ndv2;
    t = t * ndv2 + 1;
    t = t * t;
    float s = (a2 != t) ? (a2 / t) : 1;
    invA = s / invA;
    lutUV.x = cb5[1].x * (ndv2 - invA) + invA;
  }
  float3 brdf = SpecularBRDFLUT.SampleLevel(sampLinear, lutUV, 0).xyz;
  float3 spec = brdf * specF0;
  specF0 = cb5[1].xxx * (specF0 * brdf + -specF0) + specF0;
  float alphaBlend = -cb5[1].z + 1;
  alphaBlend = baseSample.w * cb5[1].z + alphaBlend;

  float3 directLit = litDirect * (skyCol * skyW); // simplified sun*sky
  float halfDenom = 0.5 / max(9.99999975e-05, nDotV * 2 + a);
  float specInt = saturate(min(20, max(0, specTerm * halfDenom + -6.10351562e-05)));
  directLit = litDirect * alphaBlend + spec * specInt * (skyCol * skyW) * cb0[199].w;
  // Blend with ramp chroma (dump does more; this keeps ramp influence)
  directLit *= (rampRGB * rampChroma + (1 + -rampChroma));
  float3 dbgLit = directLit;

  // 9) Rim / 边缘光
  float3 rimAxis = float3(rimAxisZW.x, 0, rimAxisZW.y);
  rimAxis = sunDir.yzx * rimAxis.yzx + -sunDir.zxy * rimAxis;
  // dump: cross construction
  {
    float3 t = float3(rimAxisZW.x, 0, rimAxisZW.y);
    float3 c = sunDir.zxy * t;
    rimAxis = sunDir.yzx * t.yzx + -c;
    rimAxis = rimAxis * rsqrt(dot(rimAxis, rimAxis));
  }
  float ndotvRaw = dot(viewDir, shadingN);
  float oneMinusAbsNdotV = 1.0 + -abs(ndotvRaw);
  float2 rimWrap = float2(1, 0.399999976) + -abs(ndotvRaw).xx;
  float2 rimEdge = rimNdotVWidth.xx * float2(-0.6, -0.4) + float2(0.8, 0.9);
  float rimT = saturate((rimWrap.x - rimEdge.x) / max(1e-5, rimEdge.y - rimEdge.x));
  rimT = rimT * rimT * (-2 * rimT + 3);
  float3 rim = rimColor * rimT * rimIntensity;
  float rimMask = saturate(1 + dot(sideDir, rimAxis));
  rimMask = min(rimMask, min(mask.z, screen.y));
  rim *= rimMask;
  float3 rimAlbedo = baseSample.xyz * dielectF + -0.25;
  rimAlbedo = rimAlbedoMix.xxx * rimAlbedo + 0.25;
  rimAlbedo *= saturate(dot(rimAxis, shadingN));
  float3 dbgRim = rim * rimAlbedo;
  float3 lit = directLit;
#if STEP_RIM
  lit = dbgRim + lit;
#else
#endif
  // Probe GI omitted (probeBlend=0) — lit stays direct+rim

  // 10) Emissive + cube
  float3 color = lit;
#if STEP_IBL_EMISSIVE
  float3 em = cb5[6].xyz * emissive * cb5[1].w * alphaBlend;
  color = em + lit;
  float3 R = reflect(-viewDir, shadingN);
  float roughMip = max(0.001, 0.01); // detail roughness removed → mild mip
  roughMip = log2(roughMip) * 1.2 + 5;
  float3 cube = ReflectionCube.SampleLevel(sampLinear, R, roughMip).xyz;
  float3 ibl = cube * specF0 * probeTint * cb0[186].w;
  color = ibl + color;
#endif

  // Local lights omitted → color unchanged

  // 12) Color grade
#if STEP_COLOR_GRADE
  if (0.5 < cb5[3].x) {
    float luma = dot(color, kLuma);
    float3 c = cb5[3].zzz * (color + -luma) + luma;
    c = cb5[3].www * (c + -0.5) + 0.5;
    float3 tinted = cb5[3].yyy * c;
    c = cb5[7].www * (-c * cb5[3].yyy + cb5[7].xyz) + tinted;
    float w = saturate(ndotvRaw); // stand-in for dump r13.w at grade
    float t = -cb5[4].x + 1;
    float u = (1 + -w) + -t;
    u = saturate(u / max(1e-5, 1 + -t));
    u = u * u * (-2 * u + 3);
    color = cb5[8].xyz * u * cb5[4].y + c;
  }
#endif
  float3 dbgPreFog = color;

  // 13) Exposure only (fog removed)
  float3 exposed = color / exposureScale;
  o0.w = (1.000000 == cb5[2].x) ? baseSample.w : 1;
  o0.xyz = exposed;

#if DEBUG_VIS == 1
  o0 = float4(dbgBase, 1);
#elif DEBUG_VIS == 2
  o0 = float4(dbgN * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 3
  o0 = float4(dbgMask, 1);
#elif DEBUG_VIS == 4
  o0 = float4(dbgLit, 1);
#elif DEBUG_VIS == 5
  o0 = float4(dbgRim, 1);
#elif DEBUG_VIS == 6
  o0 = float4(dbgPreFog, 1);
#elif DEBUG_VIS == 7
  o0 = float4(oneMinusAbsNdotV.xxx, 1);
#endif
}
)
