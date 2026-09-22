// =============================================================================
// ZMD / Endfield Character PS — named-locals readable (TA compact)
// =============================================================================
// Dump: 3Dmigoto 2026-09-22 09:43:01
// Full dump-faithful: shaders/zmd_ps_20260922_094301_human_readable_full.hlsl
//
// Same recipe as the compact sketch (probes / detail / tiled lights / fog
// removed as identities). r0..r29 → semantic names; math order unchanged.
//
// Pipeline
//   1 viewDir | 2 instance XZ | 3 material | 4 TBN normal
//   5 [off] volume probes → identity
//   6 [off] detail        → identity
//   7 F0 split + motion
//   8 sun + RampMap wrap + BRDF LUT
//   9 rim | 10 emissive+cube | 11 [off] local lights | 12 grade | 13 exposure
//
// Do NOT const-copy interpolators (broke rim once).
// =============================================================================

#define STEP_RIM          1  // 0 → rim add = 0 (not peak wrap)
#define STEP_IBL_EMISSIVE 1  // 0 → no emissive / cube
#define STEP_COLOR_GRADE  1  // 0 → skip cb5 grade
#define DEBUG_VIS         0
// 0 final | 1 baseColor | 2 shadingN | 3 mask | 4 litDirect | 5 rim | 6 preExposure | 7 1-|N·V|

TextureCube<float4> ReflectionCube  : register(t18);
Texture2D<float4>   EmissiveMap     : register(t17);
Texture2D<float4>   NormalMap       : register(t16);
Texture2D<float4>   MaterialMask    : register(t15);
Texture2D<float4>   BaseColorMap    : register(t14);
Texture2D<float4>   SpecularBRDFLUT : register(t11);
Texture2D<float4>   RampMap         : register(t10);
Texture2D<float4>   ScreenData      : register(t3);

struct InstanceRow { float val[4]; };
StructuredBuffer<InstanceRow> InstanceDataSB : register(t1);

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

static const float3 kLuma = float3(0.212672904, 0.715152204, 0.0721750036);

// 3Dmigoto cmp: true → -1, false → 0
float  cmp(bool  v) { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }

float3 EvalViewDir(float3 worldPos)
{
  float3 toCam = cb0[44].xyz + -worldPos;
  float3 camFwdZ = float3(cb0[0].z, cb0[1].z, cb0[2].z);
  toCam = cb0[86].www * (camFwdZ + -toCam) + toCam;
  return toCam * rsqrt(max(9.99999994e-09, dot(toCam, toCam)));
}

float3 EvalUnpackNormalMap(float2 uv, float mip, out float nz)
{
  float3 n = NormalMap.SampleBias(sampNormal, uv, mip).xyw;
  n.x = n.z * n.x;
  n.xy = n.xy * float2(2, 2) + float2(-1, -1);
  nz = dot(n.xy, n.xy);
  nz = min(1, nz);
  nz = 1 + -nz;
  nz = sqrt(nz);
  nz = max(1.00000002e-16, nz);
  n.xy = cb5[0].ww * n.xy;
  return n;
}

void EvalShadingNormal(float3 nTS, float nz, float3 geomN, float4 tangent, uint isFrontFace,
                       out float3 nMapped, out float3 nWorld, out float3 geomNSigned, out float faceSign)
{
  float3 bitangent = tangent.yzx * geomN.zxy;
  bitangent = geomN.yzx * tangent.zxy + -bitangent;
  bitangent = tangent.www * bitangent;
  nMapped = bitangent * nTS.yyy;
  nMapped = nTS.xxx * tangent.xyz + nMapped;
  nMapped = nz * geomN + nMapped;
  faceSign = cb5[1].y * 2 + -1;
  faceSign = isFrontFace ? 1 : faceSign;
  nMapped = nMapped * rsqrt(max(1.17549435e-38, dot(nMapped, nMapped)));
  nWorld = nMapped * faceSign;
  geomNSigned = geomN * rsqrt(max(1.17549435e-38, dot(geomN, geomN)));
  geomNSigned = geomNSigned * faceSign;
}

void EvalDiffuseSpecF0(float3 albedo, float metallic, float roughness, inout float3 colSat,
                       out float dielectF, out float3 diffuse, out float3 specF0)
{
  float dielectricF0 = 0.0399999991 * roughness;
  dielectF = -metallic * 0.959999979 + 0.959999979;
  diffuse = dielectF * albedo;
  specF0 = -roughness * float3(0.0399999991, 0.0399999991, 0.0399999991) + albedo;
  specF0 = metallic * specF0 + dielectricF0;
  colSat = colSat * dielectF;
}

// Signed double-sqrt motion encode. Sign packing is dump-fragile — keep shape.
float2 EvalMotionVector(float3 curr, float3 prev)
{
  float r8w; float4 r16; float2 r19;
  r8w = max(9.99999994e-09, curr.z);
  r16.xy = curr.xy / r8w;
  r8w = max(9.99999994e-09, prev.z);
  r16.zw = prev.xy / r8w;
  r16.xy = r16.xy + -r16.zw;
  r19.xy = float2(0.5, -0.5) * r16.xy;
  r19.xy = sqrt(abs(r19.xy));
  r19.xy = sqrt(r19.xy);
  r16.z = -r16.y;
  r16.yw = cmp(float2(0, 0) < r16.xz);
  r16.xz = cmp(r16.xz < float2(0, 0));
  r16.xy = (int2)-r16.yw + (int2)r16.xz;
  r16.xy = (int2)r16.xy;
  r16.xy = r19.xy * r16.xy;
  return r16.xy * float2(0.5, 0.5) + float2(0.5, 0.5);
}

void EvalColorGrade(inout float3 lit, float wrap01)
{
  if (!(0.5 < cb5[3].x)) return;
  float lum = dot(lit, kLuma);
  float3 c = cb5[3].zzz * (lit + -lum) + lum;
  c = float3(-0.5, -0.5, -0.5) + c;
  c = cb5[3].www * c + float3(0.5, 0.5, 0.5);
  float3 scaled = cb5[3].yyy * c;
  c = -c * cb5[3].yyy + cb5[7].xyz;
  c = cb5[7].www * c + scaled;
  // dump: r13.w = saturate(r13.w); then smoothstep-ish on (wrap - thresh)
  float thresh = -cb5[4].x + 1;
  float wrap = saturate(wrap01);
  float t0 = 1 + -wrap;
  float t1 = 1 + -thresh;
  float t = saturate((1 / t1) * (t0 + -thresh));
  float s = t * -2 + 3;
  t = s * (t * t);
  lit = (cb5[8].xyz * t) * cb5[4].yyy + c;
}


void main(
  float4 v0 : SV_Position,
  float4 v1 : TEXCOORD0,   // uv
  float4 v2 : TEXCOORD1,   // worldPos
  float4 v3 : TEXCOORD2,   // geomN
  float4 v4 : TEXCOORD3,   // tangent.xyz + sign.w
  float4 v5 : TEXCOORD4,   // motion curr
  float4 v6 : TEXCOORD5,   // motion prev
  float4 v7 : TEXCOORD6,
  float4 v8 : TEXCOORD7,   // detail UV
  nointerpolation uint v9 : TEXCOORD8,
  uint v10 : SV_IsFrontFace,
  out float4 o0 : SV_Target,
  out float4 o1 : SV_Target1)
{
  const float  mipBias       = cb0[108].x;
  const float3 sunDir        = cb0[6].xyz;
  const float  exposureScale = cb0[109].x;
  const float3 rimColor      = cb0[194].xyz;
  const float  rimIntensity  = cb0[194].w;
  const float2 rimAxisZW     = cb0[195].yx;
  const float  rimAlbedoMix  = cb0[195].z;
  const float  rimNdotVWidth = cb0[195].w;
  const float3 fallbackGI    = cb0[188].xyz;

  // ===== 1. View =====
  float3 viewDir = EvalViewDir(v2.xyz);

  // ===== 2. Per-instance XZ =====
  uint iBase = (uint)v9.x << 4;
  float2 instXZ;
  if ((16 & asint(cb1[iBase + 4].w)) != 0) {
    int row = 2 + asint(cb1[iBase + 5].x);
    instXZ.x = InstanceDataSB[row].val[12 / 4];
    instXZ.y = InstanceDataSB[asint(cb1[iBase + 5].x)].val[12 / 4];
  } else {
    instXZ = cb1[iBase + 3].zx;
  }

  // ===== 3. Material =====
  // mask: .x metallic  .y roughness  .z AO  .w alpha-ish
  float4 baseColor = BaseColorMap.SampleBias(sampBaseColor, v1.xy, mipBias);
  float4 mask      = MaterialMask.SampleBias(sampMaterial, v1.xy, mipBias);
  float2 oneMinusWX = float2(1, 1) + -mask.wx;          // (1-w, 1-x)
  baseColor = cb5[5] * baseColor;

  float3 colSat = cb5[4].zzz * baseColor.xyz;
  float satLuma = dot(colSat, kLuma);
  colSat = baseColor.xyz * cb5[4].zzz + -satLuma;
  colSat = cb5[4].www * colSat + satLuma;

  float nz;
  float3 nTS = EvalUnpackNormalMap(v1.xy, mipBias, nz);
  float3 emissive = EmissiveMap.SampleBias(sampEmissive, v1.xy, mipBias).xyz;

  float3 dbgBaseColor = baseColor.xyz;
  float3 dbgMask = mask.xyz;

  // ===== 4. Side dir + world normal =====
  float3 sideDir = float3(v2.x - instXZ.y, 6.10351562e-05, v2.z - instXZ.x);
  sideDir = sideDir * rsqrt(dot(sideDir, sideDir));

  float3 nMapped, shadingN, geomNSigned;
  float faceSign;
  EvalShadingNormal(nTS, nz, v3.xyz, v4, v10.x, nMapped, shadingN, geomNSigned, faceSign);
  float3 dbgShadingN = shadingN;

  float2 pixelPos = (uint2)v0.xy;
  float probeBlend = -cb0[111].x + 1;
  probeBlend = cb0[198].w * probeBlend + cb0[111].x;
  probeBlend = exposureScale * probeBlend;

  // [REMOVED] volume SH + detail → else identities
  float3 probeGI  = float3(0, 0, 0);
  float3 giWeight = float3(1, 1, 1);
  float3 giTint   = fallbackGI;
  float  probeOn  = 0;
  float3 shadingNFinal = shadingN;
  float  detailRough   = 0.00999999978;
  float  detailFlag    = 0;

  // ===== 7. F0 split + motion =====
  float  dielectF;
  float3 diffuse, specF0;
  EvalDiffuseSpecF0(baseColor.xyz, mask.x, mask.y, colSat, dielectF, diffuse, specF0);

  float rough2 = oneMinusWX.y * oneMinusWX.y;
  rough2 = max(0.0078125, rough2);
  float rough4 = rough2 * rough2;

  o1.xy = EvalMotionVector(v5.xyz, v6.xyz);
  float detailHot = cmp(0.5 < detailFlag);
  o1.w = detailHot ? 0.699999988 : 0.400000006;

  // ===== 8. Sun + RampMap wrap lighting =====
  float3 ambRaw = cb3[0].xyz + cb0[197].xyz;
  float3 ambient = cb0[187].www * ambRaw + -cb3[0].xyz;

  float3 bentN = float3(ambient.x, 6.10351562e-05, ambient.z);
  bentN = bentN * rsqrt(dot(bentN, bentN));

  float3 skyA = -cb3[3].xyz + cb0[191].xyz;
  skyA = cb0[198].yyy * skyA + cb3[3].xyz;
  float skyW = -cb3[3].w + 1;
  skyW = cb0[198].w * skyW + cb3[3].w;
  float3 skyLit = skyA * skyW;

  float2 screenXY = ScreenData.Load(float3(pixelPos, 0)).xy;
  float screenAO = -1 + screenXY.x;
  screenAO = cb4[34].x * screenAO + 1;
  float aoBlend = 1 + -screenAO;
  screenAO = cb0[187].z * aoBlend + screenAO;

  float nDotAmb = dot(shadingN, ambient);
  float3 colSatScaled = cb0[186].zzz * colSat;
  float3 colSat65 = 0.649999976 * colSatScaled;
  float diffuseLuma = dot(diffuse, kLuma);

  float sunXZLen = rsqrt(dot(sunDir.xz, sunDir.xz));
  float2 sunXZ = sunDir.xz * sunXZLen;
  float sideSun = saturate(-dot(bentN.xz, sunXZ));
  float2 wrapBias = -cb0[198].xy + float2(1, 1);

  float wrapTerm = nDotAmb * 0.5 + -1;
  wrapTerm = -nDotAmb * wrapTerm + -nDotAmb;
  float sunUp = -abs(sunDir.y) + 0.75;
  sunUp = saturate(sunUp + sunUp);
  float sunUpS = sunUp * -2 + 3;
  sunUp = sunUpS * (sunUp * sunUp);
  float wrapW = sunUp * sideSun * wrapBias.x;
  wrapTerm = 0.5 + wrapTerm;
  nDotAmb = wrapW * wrapTerm + nDotAmb;
  nDotAmb = cb0[197].w * cb0[198].x + nDotAmb;
  nDotAmb = max(-1, nDotAmb);
  nDotAmb = min(1, nDotAmb);

  // RampMap (t10): U = wrap, V = 0.5
  float rampU = nDotAmb * 0.5 + 0.5;
  float4 rampA = RampMap.SampleLevel(sampLinear, float2(rampU, 0.5), 0);
  float rampChroma = max(rampA.x, max(rampA.y, rampA.z));
  rampChroma = rampChroma - min(rampA.x, min(rampA.y, rampA.z));
  float nDotSun = dot(shadingN, sunDir);
  float rampW = RampMap.SampleLevel(sampLinear, float2(nDotSun * 0.5 + 0.5, 0.5), 0).w;

  float specAO = screenXY.y * mask.z;
  float aoMask = min(screenXY.y, mask.z);
  float aoAll = min(aoMask, rampA.w);
  float rampBlend = specAO * rampW;

  float ndKey = dot(shadingN, cb0[192].xyz);
  ndKey = saturate(cb0[193].x + ndKey);
  ndKey = ndKey * cb0[193].y + cb0[193].z;

  float giMix = cb0[187].y * aoAll;
  float3 giCol = float3(1, 1, 1) + -giTint;
  giCol = giMix * giCol + giTint;
  giCol = giCol * ndKey;

  float hiA = probeBlend * 0.350000024 + 0.649999976;
  hiA = min(1.5, hiA);
  float3 hiB = max(float3(1.25, 0, 0.5), probeBlend);
  hiB = min(float3(1.75, 1.5, 1.5), hiB);

  float3 skyTint = giCol * (cb0[187].x * (hiB.x + -hiA) + hiA);
  skyTint = cb0[186].www * skyTint;

  float skyLuma = dot(skyLit, kLuma);
  float3 skySat = skyA * skyW + -skyLuma;
  skySat = aoAll * skySat + skyLuma;
  float3 giScaled = hiB.yyy * giCol;
  float3 invBias = skyA * cb0[198].yyy + wrapBias.yyy;
  float3 skyFinal = giScaled * invBias + skySat;
  skyFinal = skyFinal * cb0[186].yyy + -skyTint;
  skyFinal = screenAO * skyFinal + skyTint;

  float colSat65Luma = dot(colSat65, kLuma);
  float3 sat65 = colSatScaled * 0.649999976 + -colSat65Luma;
  sat65 = sat65 * 1.20000005 + colSat65Luma;
  float rampGate = saturate(rampW * specAO + rampA.w);
  float3 satMix = colSat * cb0[186].zzz + -sat65;
  sat65 = rampGate * satMix + sat65;
  float3 dielectCol = baseColor.xyz * dielectF + -sat65;
  sat65 = aoAll * dielectCol + sat65;

  float3 rampRGB = rampA.xyz * rampChroma + (1 + -rampChroma);
  rampRGB = rampRGB * sat65;

  float3 dielect2 = baseColor.xyz * dielectF + -diffuseLuma;
  dielect2 = dielect2 * 1.20000005 + diffuseLuma;
  dielect2 = -colSat * cb0[186].zzz + dielect2;
  colSatScaled = rampBlend * dielect2 + colSatScaled;

  float lumaSat = dot(sat65, kLuma);
  float lumaRamp = max(0.00100000005, dot(rampRGB, kLuma));
  float lumaScale = min(1.5, max(0, lumaSat * (1 / lumaRamp)));
  float3 direct = rampRGB * lumaScale + -colSatScaled;
  colSatScaled = screenAO * direct + colSatScaled;

  float aoSpec = -rampW * specAO + aoAll;
  aoSpec = screenAO * aoSpec + rampBlend;
  float keepZ = -cb0[186].z + 1;
  float specMask = aoSpec * keepZ + cb0[186].z;

  // half vector + BRDF LUT
  float ndv = saturate(dot(shadingNFinal, viewDir));
  float3 halfV = float3(sunDir.x, screenAO * (-0.5 + bentN.y) + 0.5, sunDir.z);
  halfV = halfV * rsqrt(max(1.17549435e-38, dot(halfV, halfV)));
  halfV = halfV + halfV;
  float3 halfAdd = ambient * screenAO + halfV;
  float3 halfTot = viewDir * (2 + screenAO) + halfAdd;
  halfTot = halfTot * rsqrt(dot(halfTot, halfTot));
  float ndh = dot(shadingNFinal, halfTot);

  float a2 = rough4;
  float d = ndh * a2 + -ndh;
  d = d * ndh + 1;
  d = d * d;
  float dOk = cmp(a2 != d);
  float vis = dOk ? (a2 / d) : 1;

  float ndv2 = ndv * ndv;
  float denom = 1 / (rough2 * rough2 + 9.99999975e-05);
  denom = vis / denom;
  float lutU = cb5[1].x * (ndv2 + -denom) + denom;
  float alphaMix = -cb5[1].z + 1;
  alphaMix = baseColor.w * cb5[1].z + alphaMix;
  float lutV = oneMinusWX.y * alphaMix;

  float3 brdf = SpecularBRDFLUT.SampleLevel(sampLinear, float2(lutU, lutV), 0).xyz;
  float3 specTint = brdf * specF0;
  float3 specMix = specF0 * brdf + -specF0;
  specF0 = cb5[1].xxx * specMix + specF0;

  float3 highlight = colSatScaled * skyLit;
  float specD = ndv * 2 + rough2;
  specD = 9.99999975e-05 + specD;
  specD = 0.5 / specD;
  float vis2 = max(0, min(20, vis * specD + -6.10351562e-05));
  float3 specTerm = specTint * vis2;

  float lumaGate = aoSpec * 0.5 + 0.5;
  lumaGate = lumaGate * specMask;
  skyLit = skyLit * lumaGate;
  skyLit = specTerm * skyLit;
  skyLit = cb0[199].www * skyLit;
  skyLit = highlight * alphaMix + skyLit;

  float skyLuma2 = dot(skyLit, kLuma);
  float lumaT = max(0, min(0.5, skyLuma2 + -0.5));
  float3 litDirect = (skyLit + -skyLuma2) * (lumaT * lumaT + 1) + skyLuma2;

  // ===== 9. Rim / 边缘光 =====
  float3 rimAxis = float3(rimAxisZW.x, 0, rimAxisZW.y);
  float3 rimCross = sunDir.zxy * rimAxis;
  float3 rimDir = sunDir.yzx * rimAxis.yzx + -rimCross;
  float gradeWrap = rsqrt(max(1.17549435e-38, dot(rimDir, rimDir))); // dump r13.w
  rimDir = rimDir * gradeWrap;

  float ndvRim = dot(viewDir, shadingN);
  float dbgOneMinusAbsNdotV = 1.0 + -abs(ndvRim);
  float2 rimWrap = float2(1, 0.399999976) + -abs(ndvRim);

  float bentShade = dot(bentN, shadingN);
  float invScreenAO = 1 + -screenAO;
  float roughBlend = detailRough + -oneMinusWX.y;
  roughBlend = detailFlag * roughBlend + oneMinusWX.y;
  float rough2b = roughBlend * roughBlend;
  float p = rough2b * rough2b;
  float q = p * rough2b;
  float ndvSq = ndv * ndv;
  float r16z = ndvSq * rough2;

  // rational fit (dump dots, register-faithful)
  float3 k = float3(0.0365463011, 9.0632, 0.990440011);
  float nAx = dot(float2(3.32707, 1), float2(k.x, rough2));
  float nAy = dot(float2(-9.04755974, 1), float2(k.x, k.z));
  float dA0 = dot(float3(3.59684992, -1.36772001, 1), float3(ndvSq, p, 1));
  float dA1 = dot(float3(-16.3174, 1, 9.22949028), float3(ndvSq, 1, q));
  float dA2 = dot(float3(1, 19.7886009, -20.2122993), float3(5.56588984, ndvSq, p));
  float ratioA = (nAx + nAy) / (dA0 + dA1 + dA2);

  float nBx = dot(float2(-1.28514004, 1), float2(k.x, k.y));
  float nBy = dot(float2(1, -0.755906999), float2(1.29677999, k.x));
  float dB0 = dot(float3(2.9233799, 59.4188004, 1), float3(ndvSq, p, 1));
  float dB1 = dot(float3(1, -27.0301991, 222.591995), float3(20.3225002, 1, q));
  float dB2 = dot(float3(626.130005, 316.627014, 1), float3(ndvSq, p, 1));
  float ratioB = (nBx + nBy) / (dB0 + dB1 + dB2);

  float3 abColor = specF0 * ratioA + ratioB;
  float abSum = ratioB + ratioA;
  litDirect = (skyLit + -skyLuma2) * (lumaT * lumaT + 1) + skyLuma2;

  float2 rimEnds = rimNdotVWidth.xx * float2(-0.600000024, -0.399999976)
                 + float2(0.800000012, 0.899999976);
  float rimT = saturate((rimWrap.x + -rimEnds.x) / (rimEnds.y + -rimEnds.x));
  float rimS = rimT * -2 + 3;
  rimT = rimS * (rimT * rimT);

  float3 rimTerm = rimColor * rimT;
  rimTerm = rimIntensity * rimTerm;
  float sideRim = saturate(1 + dot(sideDir, rimDir));
  sideRim = min(sideRim, mask.z);
  sideRim = min(sideRim, screenXY.y);
  rimTerm = rimTerm * sideRim;

  float3 rimAlbedo = baseColor.xyz * dielectF + -0.25;
  rimAlbedo = rimAlbedoMix * rimAlbedo + 0.25;
  float3 rimShade = rimAlbedo * saturate(dot(rimDir, shadingN));

  // GI combine (identity: giWeight starts at 1)
  float giMax = max(giWeight.x, max(giWeight.y, giWeight.z));
  giWeight = giWeight * (1 / max(1, 0.5 * giMax));
  float3 skyBlend = skyA * skyW + -giWeight;
  giWeight = screenAO * skyBlend + giWeight;

  float ndProbe = dot(probeGI, shadingN);
  float probeGate = ndProbe * probeOn;
  float bentWrap = bentShade * 0.5 + -1;
  bentWrap = -bentShade * bentWrap + 0.5;
  giWeight = giWeight * saturate(screenAO * (-probeGate + bentWrap) + probeGate);

  float aoRim = sideSun * screenAO + invScreenAO;
  aoRim = aoRim * wrapBias.x;
  giWeight = giWeight * aoRim;

  float fres = saturate(5.00000048 * rimWrap.y);
  float fresS = fres * -2 + 3;
  fres = fresS * (fres * fres);
  giWeight = giWeight * fres;
  giWeight = giWeight * aoAll;

  float dark = saturate(-16.666666 * (diffuseLuma + -0.100000001));
  float darkS = dark * -2 + 3;
  dark = darkS * (dark * dark);
  giWeight = giWeight * (dark * screenAO + invScreenAO);
  giWeight = max(0.150000006, diffuse) * giWeight;

  float3 dbgRim = rimTerm * rimShade;
  float3 dbgLitDirect = litDirect;
  float3 combine = giWeight;
#if STEP_RIM
  combine = dbgRim + combine;
#endif
  combine = litDirect + combine;

  // ===== 10. Emissive + reflection cube =====
  float3 color = combine;
#if STEP_IBL_EMISSIVE
  emissive = cb5[6].xyz * emissive;
  emissive = cb5[1].www * emissive;
  color = emissive * alphaMix + combine;

  float ndvCube = dot(-viewDir, shadingNFinal);
  ndvCube = ndvCube + ndvCube;
  float3 refl = shadingNFinal * -ndvCube + -viewDir;
  float mip = max(0.00100000005, detailFlag);
  mip = log2(mip);
  mip = mip * 1.20000005 + 5;
  float3 env = ReflectionCube.SampleLevel(sampLinear, refl, mip).xyz;

  float aDiv = (1 + -abSum) / abSum;
  float3 envSpec = (specF0 * aDiv) * abColor + abColor;
  envSpec = env * envSpec;
  float envW = (cb0[186].w * q) * (1 / lumaRamp);
  envSpec = envSpec * envW;
  color = envSpec * giTint + color;
#else
  color = combine;
#endif

  // [REMOVED] tiled local lights
  float3 lit = color;

  // ===== 12. Color grade (wrap01 = dump r13.w = gradeWrap) =====
#if STEP_COLOR_GRADE
  EvalColorGrade(lit, gradeWrap);
#endif

  float3 dbgPreExposure = lit;
  o0.xyz = lit / exposureScale;
  o0.w = (1.000000 == cb5[2].x) ? baseColor.w : 1;
  o1.z = 1;

#if DEBUG_VIS == 1
  o0 = float4(dbgBaseColor, 1);
#elif DEBUG_VIS == 2
  o0 = float4(dbgShadingN * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 3
  o0 = float4(dbgMask, 1);
#elif DEBUG_VIS == 4
  o0 = float4(dbgLitDirect, 1);
#elif DEBUG_VIS == 5
  o0 = float4(dbgRim, 1);
#elif DEBUG_VIS == 6
  o0 = float4(dbgPreExposure, 1);
#elif DEBUG_VIS == 7
  o0 = float4(dbgOneMinusAbsNdotV.xxx, 1);
#endif
}
