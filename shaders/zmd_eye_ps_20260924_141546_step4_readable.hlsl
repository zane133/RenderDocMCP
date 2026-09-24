// ZMD eye PS - Step 4: readable bindings, CB aliases and section map
// Source: zmd_eye_ps_20260924_141546_step1_renderdoc.hlsl (Apply-verified, event 1129)
//
// This pass changes no shader math. Resource registers, cbuffer packing,
// interpolators, branches and operation order are unchanged. Names are inferred
// from usage; the UV-circle cornea dome, view-dependent iris UV offset and the
// normal-projected matcap identify the material as an eye shader.
//
// Main texture recipe:
//   IrisBaseColorMap(t11) with parallax UV -> DiffuseRamp(t10)
//   -> volume probe GI(t4..t9) -> ScreenAOMap(t3) -> EyeHighlightMatcap(t12)
//   -> tiled lights(t0/t2/t13) -> grade -> exposure -> fog(t14)
// ---- Created with 3Dmigoto v1.4.6 on Thu Sep 24 14:15:46 2026
Texture3D<float4> VolumetricFog3D : register(t14);

Texture2D<float4> LightCookieAtlas : register(t13);

Texture2D<float4> EyeHighlightMatcap : register(t12);

Texture2D<float4> IrisBaseColorMap : register(t11);

Texture2D<float4> DiffuseRamp : register(t10);

Texture3D<float4> VolumeCoarseSH : register(t9);

Texture3D<float4> VolumeCoarseWeights : register(t8);

Texture3D<float4> VolumeMidSH : register(t7);

Texture3D<float4> VolumeMidWeights : register(t6);

Texture3D<float4> VolumeFineSH : register(t5);

Texture3D<float4> VolumeFineWeights : register(t4);

Texture2D<float4> ScreenAOMap : register(t3);

Texture2D<float4> ShadowMap : register(t2);

struct t1_t {
  float val[4];
};
StructuredBuffer<t1_t> InstanceDataSB : register(t1);

struct t0_t {
  float val[1];
};
StructuredBuffer<t0_t> LightTileMaskSB : register(t0);

SamplerState sampMatcap : register(s4);

SamplerState sampIrisBase : register(s3);

SamplerComparisonState sampShadowCmp : register(s2);

SamplerState sampVolumeWeights : register(s1);

SamplerState sampLinear : register(s0);

cbuffer cb6 : register(b6)
{
  float4 cb6[160];
}

cbuffer cb5 : register(b5)
{
  float4 cb5[18];
}

cbuffer cb4 : register(b4)
{
  float4 cb4[401];
}

cbuffer cb3 : register(b3)
{
  float4 cb3[2054];
}

cbuffer cb2 : register(b2)
{
  float4 cb2[3];
}

cbuffer cb1 : register(b1)
{
  float4 cb1[4086];
}

cbuffer cb0 : register(b0)
{
  float4 cb0[216];
}

// 3Dmigoto declarations
// RenderDoc-friendly cmp helpers (3Dmigoto: true -> -1, false -> 0)
float cmp(bool v)   { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }
float3 cmp(bool3 v) { return v ? -1.0.xxx : 0.0.xxx; }
float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }


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
  const float4 icb[] = { { 1.000000, 0, 0, 0},
                              { 0, 1.000000, 0, 0},
                              { 0, 0, 1.000000, 0},
                              { 0, 0, 0, 1.000000},
                              { 2, 1, -1.000000, 1.000000},
                              { 2, 1, 1.000000, 1.000000},
                              { 0, 2, 1.000000, -1.000000},
                              { 0, 2, 1.000000, 1.000000},
                              { 0, 1, 1.000000, 1.000000},
                              { 0, 1, -1.000000, 1.000000} };
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27;
  uint4 bitmask, uiDest;
  float4 fDest;

  // Named CB aliases (inferred); original float4 packing is untouched.
  const float4 viewRow0 = cb0[0];                         // world-to-view row
  const float4 viewRow1 = cb0[1];                         // world-to-view row
  const float4 viewRow2 = cb0[2];                         // world-to-view row
  const float4 sunDir = cb0[6];                           // main light direction
  const float4 cameraPos = cb0[44];                       // world-space camera position
  const float4 tileDepthJitter = cb0[85];                 // tile depth-slice jitter
  const float4 viewBend = cb0[86];                        // .w bends view vector toward the view axis
  const float4 mipBiasFrame = cb0[108];                   // .x texture bias, .w frame bits
  const float4 exposure = cb0[109];                       // .x scene exposure
  const float4 lightListBase = cb0[110];                  // .y tiled-light list base
  const float4 exposureAlt = cb0[111];                    // alternate exposure
  const float4 fogStartFade = cb0[153];
  const float4 fogDirParams = cb0[154];
  const float4 fogColorParams = cb0[155];
  const float4 fogHeightA = cb0[156];
  const float4 fogHeightB = cb0[157];
  const float4 fogHeightC = cb0[158];
  const float4 fogLayerA = cb0[159];
  const float4 fogAddParams = cb0[160];
  const float4 fogAmbient = cb0[161];                     // .w minimum transmittance
  const float4 fogLayerB = cb0[162];
  const float4 fogVolumeParams = cb0[163];                // .z enables the froxel volume path
  const float4 fogSliceParams = cb0[164];
  const float4 fogJitterScale = cb0[165];
  const float4 fogStartDist = cb0[166];
  const float4 fogJitterAmount = cb0[167];
  const float4 lightScales = cb0[186];                    // .y GI, .z albedo lighting, .w environment
  const float4 featureToggles = cb0[187];                 // .x rim/GI gain blend, .y volume+AO, .z screen AO
  const float4 ambientFallback = cb0[188];                // ambient fallback colour
  const float4 mainLightColorOverride = cb0[191];
  const float4 ambientFacingDir = cb0[192];
  const float4 ambientFacingRemap = cb0[193];
  const float4 sunDirOffset = cb0[197];                   // .w ramp UV bias
  const float4 blendWeights = cb0[198];                   // global feature blend weights
  const float4 specGlobalScale = cb0[199];                // additive highlight scales
  const float4 volumeOrigin = cb0[210];                   // .w enables cascades
  const float4 volumeGridSize = cb0[211];
  const float4 volumeCascadeDist = cb0[212];              // .y fine, .z mid, .w coarse
  const float4 volumeSHAmbientR = cb0[213];
  const float4 volumeSHAmbientG = cb0[214];
  const float4 volumeSHAmbientB = cb0[215];
  const float4 tileGridParams = cb2[1];
  const float4 tileDepthParams = cb2[2];
  const float4 mainLightDirRaw = cb3[0];
  const float4 mainLightColorRaw = cb3[3];
  const float4 screenAoBlend = cb4[34];                   // .x AO blend
  const float4 shadowTexelSize = cb4[400];                // .xy texel size, .zw map size
  const float4 materialParams = cb5[0];                   // .z dims the graded base colour (0.96 scale)
  const float4 twoSidedAndOpacity = cb5[1];               // .y backface normal flip, .z alpha source blend
  const float4 alphaMode = cb5[2];                        // .x selects texture alpha
  const float4 gradeParams = cb5[3];                      // .x enable, .y exposure, .z saturation, .w contrast
  const float4 baseColorGrade = cb5[4];                   // .x rim threshold, .y rim gain, .z scale, .w saturation
  const float4 baseColorTint = cb5[5];                    // .xyzw iris tint, .w also attenuates the highlight
  const float4 gradeTintColor = cb5[7];                   // .w tint blend
  const float4 gradeRimColor = cb5[8];
  const float4 irisParallaxDepth = cb5[11];               // .y view-dependent iris UV offset depth
  const float4 irisAlphaTintColor = cb5[14];              // highlight tint gated by base-map alpha
  const float4 scleraTintColor = cb5[15];                 // highlight tint gated by the outside-iris mask
  const float4 corneaBulgeStrength = cb5[16];             // .y dome normal strength built from the UV circle
  const float4 matcapTint = cb5[17];                      // .xyz tint by matcap alpha, .w matcap rgb weight


  // ===== 1. View vector and per-instance basis =====
  r0.xyz = cameraPos.xyz + -v2.xyz;
  r1.x = viewRow0.z;
  r1.y = viewRow1.z;
  r1.z = viewRow2.z;
  r2.xyz = r1.xyz + -r0.xyz;
  r0.xyz = viewBend.www * r2.xyz + r0.xyz;
  r0.w = dot(r0.xyz, r0.xyz);
  r1.w = max(9.99999994e-09, r0.w);
  r1.w = rsqrt(r1.w);
  r0.xyz = r1.www * r0.xyz;
  r2.x = (uint)v9.x << 4;
  r2.y = 16 & asint(cb1[r2.x+4].w);
  if (r2.y != 0) {
    r2.yz = int2(2,1) + asint(cb1[r2.x+5].xx);
    r3.x = InstanceDataSB[r2.y].val[0/4];
    r3.y = InstanceDataSB[r2.y].val[0/4+2];
    r3.z = InstanceDataSB[r2.y].val[0/4+1];
    r3.w = InstanceDataSB[r2.y].val[0/4+3];
    r2.y = InstanceDataSB[r2.z].val[0/4];
    r2.z = InstanceDataSB[r2.z].val[0/4+1];
    r2.w = InstanceDataSB[r2.z].val[0/4+2];
    r4.x = InstanceDataSB[cb1[r2.x+5].x].val[0/4];
    r4.y = InstanceDataSB[cb1[r2.x+5].x].val[0/4+1];
    r4.z = InstanceDataSB[cb1[r2.x+5].x].val[0/4+2];
    r4.w = InstanceDataSB[cb1[r2.x+5].x].val[0/4+3];
    r5.x = r3.w;
    r5.y = r4.w;
    r6.z = r3.x;
    r7.z = r3.z;
    r6.y = r2.y;
    r7.y = r2.z;
    r3.z = r2.w;
    r6.x = r4.x;
    r7.x = r4.y;
    r3.x = r4.z;
  } else {
    r5.xy = cb1[r2.x+3].zx;
    r6.xyz = cb1[r2.x+0].xyz;
    r7.xyz = cb1[r2.x+1].xyz;
    r3.xyz = cb1[r2.x+2].xzy;
  }

  // ===== 2. Iris UV circle, view-dependent parallax offset and base colour =====
  r2.xy = frac(v1.xy);
  r2.zw = float2(-0.5,-0.5) + r2.xy;
  r2.z = dot(r2.zw, r2.zw);
  r2.w = cmp(r2.z >= 0.25);
  r4.x = r2.w ? 1.000000 : 0;
  r4.y = dot(v3.xyz, v3.xyz);
  r4.z = sqrt(r4.y);
  r4.z = 1 / r4.z;
  r8.xyz = v4.yzx * v3.zxy;
  r8.xyz = v3.yzx * v4.zxy + -r8.xyz;
  r9.xyz = v4.xyz * r4.zzz;
  r4.w = cmp(0 < v4.w);
  r4.w = r4.w ? 1 : -1;
  r10.xyz = r8.xyz * r4.www;
  r10.xyz = r10.xyz * r4.zzz;
  r11.xyz = v3.xyz * r4.zzz;
  r9.x = dot(r9.xyz, r0.xyz);
  r9.y = dot(r10.xyz, r0.xyz);
  r9.z = dot(r11.xyz, r0.xyz);
  r4.z = dot(r9.xyz, r9.xyz);
  r4.z = rsqrt(r4.z);
  r4.zw = r9.xy * r4.zz;
  r4.zw = irisParallaxDepth.yy * r4.zw;
  r4.zw = float2(1,0.25) * r4.zw;
  r2.z = -0.25 + r2.z;
  r2.z = saturate(-5 * r2.z);
  r5.z = r2.z * -2 + 3;
  r2.z = r2.z * r2.z;
  r2.z = r5.z * r2.z;
  r4.zw = -r4.zw * r2.zz + v1.xy;
  r9.xyzw = IrisBaseColorMap.SampleBias(sampIrisBase, r4.zw, mipBiasFrame.x).xyzw;
  r10.xyzw = baseColorTint.xyzw * r9.xyzw;
  r9.xyz = baseColorGrade.zzz * r10.xyz;
  r5.xz = v2.xz + -r5.yx;
  r5.y = 6.10351562e-05;
  r2.z = dot(r5.xyz, r5.xyz);
  r2.z = rsqrt(r2.z);
  r5.xyz = r5.xyz * r2.zzz;
  r8.xyz = v4.www * r8.xyz;
  r2.z = rsqrt(r4.y);
  r4.yzw = v3.xyz * r2.zzz;
  r2.z = twoSidedAndOpacity.y * 2 + -1;
  r2.z = v10.x ? 1 : r2.z;
  r4.yzw = r4.yzw * r2.zzz;

  // ===== 3. Cornea dome normal from the UV circle and the shading normal =====
  r2.xy = r2.xy * float2(2,2) + float2(-1,-1);
  r2.z = dot(r2.xy, r2.xy);
  r2.z = min(1, r2.z);
  r2.z = 1 + -r2.z;
  r2.z = sqrt(r2.z);
  r11.z = max(1.00000002e-16, r2.z);
  r11.xy = -corneaBulgeStrength.yy * r2.xy;
  r2.xyz = float3(-0.125,-0.125,1) * r11.xyz;
  r12.xyz = -r11.xyz * float3(-0.125,-0.125,1) + float3(0,0,1);
  r2.xyz = r4.xxx * r12.xyz + r2.xyz;
  r12.xyz = r2.yyy * r8.xyz;
  r12.xyz = r2.xxx * v4.xyz + r12.xyz;
  r2.xyz = r2.zzz * v3.xyz + r12.xyz;
  r5.w = dot(r2.xyz, r2.xyz);
  r5.w = rsqrt(r5.w);
  r12.xyz = r5.www * r2.xyz;
  r13.xy = (uint2)v0.xy;
  r2.x = -exposureAlt.x + 1;
  r2.x = blendWeights.w * r2.x + exposureAlt.x;
  r2.x = exposure.x * r2.x;
  r12.w = 6.10351562e-05;
  r2.y = dot(r12.xzw, r12.xzw);
  r2.y = rsqrt(r2.y);
  r14.xyz = r12.xwz * r2.yyy;

  // ===== 4. Three-cascade volume probe GI =====
  r2.y = cmp(featureToggles.y < 0.5);
  if (r2.y != 0) {
    r15.xyz = sunDir.xzy * -volumeCascadeDist.www + volumeOrigin.xzy;
    r15.xyz = v2.xzy + -r15.xyz;
    r2.y = max(abs(r15.x), abs(r15.y));
    r2.y = -464 + r2.y;
    r2.z = -208 + abs(r15.z);
    r2.yz = saturate(float2(0.03125,0.03125) * r2.yz);
    r2.y = max(r2.y, r2.z);
    r2.z = cmp(0.000000 != volumeOrigin.w);
    r5.w = cmp(r2.y < 1);
    r2.z = r2.z ? r5.w : 0;
    if (r2.z != 0) {
      r15.xyz = sunDir.xzy * -volumeCascadeDist.yyy + volumeOrigin.xzy;
      r15.xyz = v2.xzy + -r15.xyz;
      r2.z = max(abs(r15.x), abs(r15.y));
      r2.z = -29 + r2.z;
      r2.z = saturate(0.5 * r2.z);
      r5.w = -13 + abs(r15.z);
      r5.w = saturate(0.5 * r5.w);
      r2.z = max(r5.w, r2.z);
      r5.w = cmp(r2.z < 1);
      if (r5.w != 0) {
        r15.xyz = v2.xyz * float3(2,2,2) + float3(0.5,0.5,0.5);
        r16.xyz = volumeGridSize.xyz * r15.xyz;
        r16.xyz = floor(r16.xyz);
        r15.xyz = r15.xyz * volumeGridSize.xyz + -r16.xyz;
        r16.xyw = VolumeFineWeights.SampleLevel(sampVolumeWeights, r15.xyz, 0).yzx;
        r5.w = 1 + -r2.z;
        r7.w = volumeGridSize.y * 0.5;
        r8.w = -volumeGridSize.y * 0.5 + 1;
        r7.w = max(r15.y, r7.w);
        r7.w = min(r7.w, r8.w);
        r15.w = 0.333333343 * r7.w;
        r17.xyzw = VolumeFineSH.SampleLevel(sampLinear, r15.xwz, 0).xyzw;
        r7.w = r17.w * r5.w + r2.y;
        r18.xyz = float3(0,0.666666687,0) + r15.xwz;
        r18.xyz = VolumeFineSH.SampleLevel(sampLinear, r18.xyz, 0).xyz;
        r18.xyz = r18.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r18.xyz = r18.xyz * r16.yyy;
        r18.w = r16.y;
        r18.xyzw = r18.xyzw * r5.wwww;
        r15.xyz = float3(0,0.333333343,0) + r15.xwz;
        r15.xyz = VolumeFineSH.SampleLevel(sampLinear, r15.xyz, 0).xyz;
        r15.xyz = r15.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r15.xyz = r15.xyz * r16.xxx;
        r15.w = r16.x;
        r15.xyzw = r15.xyzw * r5.wwww;
        r17.xyz = r17.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r16.xyz = r17.xyz * r16.www;
        r16.xyzw = r16.xyzw * r5.wwww;
      } else {
        r18.xyzw = float4(0,0,0,0);
        r15.xyzw = float4(0,0,0,0);
        r16.xyzw = float4(0,0,0,0);
        r7.w = r2.y;
      }
      r17.xyz = sunDir.xzy * -volumeCascadeDist.zzz + volumeOrigin.xzy;
      r17.xyz = v2.xzy + -r17.xyz;
      r5.w = max(abs(r17.x), abs(r17.y));
      r5.w = -116 + r5.w;
      r5.w = saturate(0.125 * r5.w);
      r8.w = -52 + abs(r17.z);
      r8.w = saturate(0.125 * r8.w);
      r5.w = max(r8.w, r5.w);
      r8.w = cmp(r5.w < 1);
      if (r8.w != 0) {
        r17.xyz = v2.xyz * float3(0.5,0.5,0.5) + float3(0.5,0.5,0.5);
        r19.xyz = volumeGridSize.xyz * r17.xyz;
        r19.xyz = floor(r19.xyz);
        r17.xyz = r17.xyz * volumeGridSize.xyz + -r19.xyz;
        r19.xyw = VolumeMidWeights.SampleLevel(sampVolumeWeights, r17.xyz, 0).yzx;
        r8.w = 1 + -r5.w;
        r2.z = r8.w * r2.z;
        r8.w = volumeGridSize.y * 0.5;
        r11.w = -volumeGridSize.y * 0.5 + 1;
        r8.w = max(r17.y, r8.w);
        r8.w = min(r8.w, r11.w);
        r17.w = 0.333333343 * r8.w;
        r20.xyzw = VolumeMidSH.SampleLevel(sampLinear, r17.xwz, 0).xyzw;
        r7.w = r20.w * r2.z + r7.w;
        r21.xyz = float3(0,0.666666687,0) + r17.xwz;
        r21.xyz = VolumeMidSH.SampleLevel(sampLinear, r21.xyz, 0).xyz;
        r21.xyz = r21.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r21.xyz = r21.xyz * r19.yyy;
        r21.w = r19.y;
        r18.xyzw = r21.xyzw * r2.zzzz + r18.xyzw;
        r17.xyz = float3(0,0.333333343,0) + r17.xwz;
        r17.xyz = VolumeMidSH.SampleLevel(sampLinear, r17.xyz, 0).xyz;
        r17.xyz = r17.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r17.xyz = r17.xyz * r19.xxx;
        r17.w = r19.x;
        r15.xyzw = r17.xyzw * r2.zzzz + r15.xyzw;
        r17.xyz = r20.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r19.xyz = r17.xyz * r19.www;
        r16.xyzw = r19.xyzw * r2.zzzz + r16.xyzw;
      }
      r2.z = cmp(0 < r5.w);
      if (r2.z != 0) {
        r17.xyz = v2.xyz * float3(0.125,0.125,0.125) + float3(0.5,0.5,0.5);
        r19.xyz = volumeGridSize.xyz * r17.xyz;
        r20.xyz = volumeGridSize.xyz * float3(0.5,0.5,0.5);
        r19.xyz = floor(r19.xyz);
        r17.xyz = r17.xyz * volumeGridSize.xyz + -r19.xyz;
        r19.xyz = -volumeGridSize.xyz * float3(0.5,0.5,0.5) + float3(1,1,1);
        r17.xyz = max(r17.xyz, r20.xyz);
        r17.xyz = min(r17.xyz, r19.xyz);
        r21.xyw = VolumeCoarseWeights.SampleLevel(sampVolumeWeights, r17.xyz, 0).yzx;
        r2.z = 1 + -r2.y;
        r2.z = r5.w * r2.z;
        r5.w = max(r17.y, r20.y);
        r5.w = min(r5.w, r19.y);
        r17.w = 0.333333343 * r5.w;
        r19.xyzw = VolumeCoarseSH.SampleLevel(sampLinear, r17.xwz, 0).xyzw;
        r20.xyz = float3(0,0.666666687,0) + r17.xwz;
        r20.xyz = VolumeCoarseSH.SampleLevel(sampLinear, r20.xyz, 0).xyz;
        r20.xyz = r20.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r20.xyz = r20.xyz * r21.yyy;
        r20.w = r21.y;
        r18.xyzw = r20.xyzw * r2.zzzz + r18.xyzw;
        r17.xyz = float3(0,0.333333343,0) + r17.xwz;
        r17.xyz = VolumeCoarseSH.SampleLevel(sampLinear, r17.xyz, 0).xyz;
        r17.xyz = r17.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r17.xyz = r17.xyz * r21.xxx;
        r17.w = r21.x;
        r15.xyzw = r17.xyzw * r2.zzzz + r15.xyzw;
        r17.xyz = r19.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r21.xyz = r17.xyz * r21.www;
        r16.xyzw = r21.xyzw * r2.zzzz + r16.xyzw;
        r7.w = r19.w * r2.z + r7.w;
      }
      r2.z = saturate(r7.w * 2 + -1);
      r17.x = r2.z + -r2.y;
      r2.y = r2.z + r2.y;
      r17.y = 0.5 * r2.y;
    } else {
      r18.xyzw = float4(0,0,0,0);
      r15.xyzw = float4(0,0,0,0);
      r16.xyzw = float4(0,0,0,0);
      r17.xy = float2(0,1);
    }

    // ===== 5. Ambient SH evaluation, GI luminance and hue ramp =====
    r19.xyzw = volumeSHAmbientR.xyzw * r17.yyyx;
    r19.y = r19.w * 0.5 + r19.y;
    r2.yz = volumeSHAmbientR.wy * r17.yx;
    r19.w = r2.z * 0.375 + r2.y;
    r16.xyzw = r19.xyzw + r16.xyzw;
    r19.xyzw = volumeSHAmbientG.xyzw * r17.yyyx;
    r19.y = r19.w * 0.5 + r19.y;
    r2.yz = volumeSHAmbientG.wy * r17.yx;
    r19.w = r2.z * 0.375 + r2.y;
    r15.xyzw = r19.xyzw + r15.xyzw;
    r19.xyzw = volumeSHAmbientB.xyzw * r17.yyyx;
    r19.y = r19.w * 0.5 + r19.y;
    r2.yz = volumeSHAmbientB.wy * r17.yx;
    r19.w = r2.z * 0.375 + r2.y;
    r17.xyzw = r19.xyzw + r18.xyzw;
    r14.w = 1;
    r18.x = dot(r16.xyzw, r14.xyzw);
    r18.y = dot(r15.xyzw, r14.xyzw);
    r18.z = dot(r17.xyzw, r14.xyzw);
    r18.xyz = max(float3(0,0,0), r18.xyz);
    r19.xyz = r18.xyz * r2.xxx;
    r20.xyz = float3(0.715200007,0.715200007,0.715200007) * r15.xyz;
    r20.xyz = r16.xyz * float3(0.212599993,0.212599993,0.212599993) + r20.xyz;
    r20.xyz = r17.xyz * float3(0.0722000003,0.0722000003,0.0722000003) + r20.xyz;
    r2.y = dot(r20.xyz, r20.xyz);
    r2.y = max(1.17549435e-38, r2.y);
    r2.y = rsqrt(r2.y);
    r20.xyz = r20.xyz * r2.yyy;
    r20.y = abs(r20.y);
    r20.w = 1;
    r16.x = dot(r16.xyzw, r20.xyzw);
    r16.y = dot(r15.xyzw, r20.xyzw);
    r16.z = dot(r17.xyzw, r20.xyzw);
    r15.xyz = max(float3(0,0,0), r16.xyz);
    r2.y = cmp(r19.y >= r19.z);
    r2.y = r2.y ? 1.000000 : 0;
    r16.xy = r19.zy;
    r16.zw = float2(-1,0.666666687);
    r17.xy = r18.yz * r2.xx + -r16.xy;
    r17.zw = float2(1,-1);
    r16.xyzw = r2.yyyy * r17.xyzw + r16.xyzw;
    r2.y = cmp(r19.x >= r16.x);
    r2.y = r2.y ? 1.000000 : 0;
    r17.xyz = r16.xyw;
    r17.w = r19.x;
    r16.xyw = r17.wyx;
    r16.xyzw = r16.xyzw + -r17.xyzw;
    r16.xyzw = r2.yyyy * r16.xyzw + r17.xyzw;
    r2.y = min(r16.w, r16.y);
    r2.y = r16.x + -r2.y;
    r2.z = r16.w + -r16.y;
    r5.w = r2.y * 6 + 9.99999975e-05;
    r2.z = r2.z / r5.w;
    r2.z = r16.z + r2.z;
    r2.z = frac(abs(r2.z));
    r5.w = 9.99999975e-05 + r16.x;
    r2.y = r2.y / r5.w;
    r17.xyzw = float4(-0.5,1,0.666666687,0.333333343) + r2.zzzz;
    r2.z = -0.449999988 + abs(r17.x);
    r2.z = saturate(-10.000001 * r2.z);
    r5.w = r2.z * -2 + 3;
    r2.z = r2.z * r2.z;
    r2.z = r5.w * r2.z;
    r2.z = r2.z * -0.349999994 + 0.699999988;
    r16.x = saturate(r16.x);
    r2.z = r16.x * r2.z;
    r2.y = min(r2.y, r2.z);
    r2.z = 2 + -r2.y;
    r2.z = 2 / r2.z;
    r16.xyz = frac(r17.yzw);
    r16.xyz = r16.xyz * float3(6,6,6) + float3(-3,-3,-3);
    r16.xyz = saturate(float3(-1,-1,-1) + abs(r16.xyz));
    r16.xyz = float3(-1,-1,-1) + r16.xyz;
    r16.xyz = r2.yyy * r16.xyz + float3(1,1,1);
    r16.xyz = r16.xyz * r2.zzz;
    r2.y = max(r15.x, r15.y);
    r2.y = max(r2.y, r15.z);
    r2.x = r2.y * r2.x;
    r2.y = 1;
  } else {
    r20.xyz = float3(0,0,0);
    r19.xyz = float3(1,1,1);
    r16.xyz = ambientFallback.xyz;
    r2.y = 0;
  }

  // ===== 6. Base colour grade (dim, saturation) =====
  r2.z = -materialParams.z * 0.959999979 + 0.959999979;
  r15.xyz = r10.xyz * r2.zzz;
  r5.w = dot(r9.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r9.xyz = r10.xyz * baseColorGrade.zzz + -r5.www;
  r9.xyz = baseColorGrade.www * r9.xyz + r5.www;
  r9.xyz = r9.xyz * r2.zzz;

  // ===== 7. Motion vectors -> o1.xy =====
  r5.w = max(9.99999994e-09, v5.z);
  r17.xy = v5.xy / r5.ww;
  r5.w = max(9.99999994e-09, v6.z);
  r17.zw = v6.xy / r5.ww;
  r17.xy = r17.xy + -r17.zw;
  r18.xy = float2(0.5,-0.5) * r17.xy;
  r18.xy = sqrt(abs(r18.xy));
  r18.xy = sqrt(r18.xy);
  r17.z = -r17.y;
  r17.yw = cmp(float2(0,0) < r17.xz);
  r17.xz = cmp(r17.xz < float2(0,0));
  r17.xy = (int2)-r17.yw + (int2)r17.xz;
  r17.xy = (int2)r17.xy;
  r17.xy = r18.xy * r17.xy;
  o1.xy = r17.xy * float2(0.5,0.5) + float2(0.5,0.5);

  // ===== 8. Main light direction and colour, tangent-space light vector =====
  r17.xyz = mainLightDirRaw.xyz + sunDirOffset.xyz;
  r17.xyz = featureToggles.www * r17.xyz + -mainLightDirRaw.xyz;
  r17.w = 6.10351562e-05;
  r5.w = dot(r17.xzw, r17.xzw);
  r5.w = rsqrt(r5.w);
  r18.xyz = r17.xwz * r5.www;
  r21.xyz = -mainLightColorRaw.xyz + mainLightColorOverride.xyz;
  r21.xyz = blendWeights.yyy * r21.xyz + mainLightColorRaw.xyz;
  r5.w = -mainLightColorRaw.w + 1;
  r5.w = blendWeights.w * r5.w + mainLightColorRaw.w;
  r22.xyz = r21.xyz * r5.www;
  r23.x = dot(r17.xyz, r6.xyz);
  r23.y = dot(r17.xyz, r7.xyz);
  r23.z = dot(r17.xzy, r3.xyz);
  r7.x = dot(r23.xyz, r23.xyz);
  r7.x = max(1.17549435e-38, r7.x);
  r7.x = rsqrt(r7.x);
  r7.xy = r23.xz * r7.xx;
  r6.w = r3.x;
  r17.x = dot(r6.xw, r7.xy);
  r3.xw = r6.zy;
  r17.y = dot(r3.wz, r7.xy);
  r17.z = dot(r3.xy, r7.xy);

  // ===== 9. Screen-space AO lookup =====
  r13.z = 0;
  r3.x = ScreenAOMap.Load(r13.xyz).x;
  r3.x = -1 + r3.x;
  r3.x = screenAoBlend.x * r3.x + 1;
  r3.y = 1 + -r3.x;
  r3.x = featureToggles.z * r3.y + r3.x;
  r3.yzw = lightScales.zzz * r9.xyz;
  r6.xyz = float3(0.649999976,0.649999976,0.649999976) * r3.yzw;
  r7.xyz = scleraTintColor.xyz * r4.xxx;
  r23.xyz = irisAlphaTintColor.xyz * r10.www;
  r2.w = r2.w ? 0 : 1;
  r24.xyz = scleraTintColor.xyz * r4.xxx + r2.www;
  r2.w = -r9.w * baseColorTint.w + 1;
  r25.xyz = irisAlphaTintColor.xyz * r10.www + r2.www;
  r24.xyz = r25.xyz * r24.xyz;

  // ===== 10. Diffuse ramp lookup (N.L -> ramp UV) =====
  r2.w = dot(r17.xyz, r17.xyz);
  r2.w = max(1.17549435e-38, r2.w);
  r2.w = rsqrt(r2.w);
  r17.xyz = r17.xyz * r2.www;
  r2.w = dot(r12.xyz, r17.xyz);
  r2.w = sunDirOffset.w * blendWeights.x + r2.w;
  r2.w = max(-1, r2.w);
  r2.w = min(1, r2.w);
  r17.x = r2.w * 0.5 + 0.5;
  r17.yw = float2(0.5,0.5);
  r25.xyzw = DiffuseRamp.SampleLevel(sampLinear, r17.xy, 0).xyzw;
  r2.w = max(r25.x, r25.y);
  r2.w = max(r2.w, r25.z);
  r4.x = min(r25.x, r25.y);
  r4.x = min(r4.x, r25.z);
  r2.w = -r4.x + r2.w;
  r4.x = dot(r12.xyz, sunDir.xyz);
  r17.z = r4.x * 0.5 + 0.5;
  r4.x = DiffuseRamp.SampleLevel(sampLinear, r17.zw, 0).w;

  // ===== 11. Ambient / GI composite and albedo lighting =====
  r6.w = min(1, r25.w);
  r7.w = dot(r14.xyz, ambientFacingDir.xyz);
  r7.w = saturate(ambientFacingRemap.x + r7.w);
  r7.w = r7.w * ambientFacingRemap.y + ambientFacingRemap.z;
  r8.w = featureToggles.y * r6.w;
  r14.xyz = float3(1,1,1) + -r16.xyz;
  r14.xyz = r8.www * r14.xyz + r16.xyz;
  r14.xyz = r14.xyz * r7.www;
  r7.w = r2.x * 0.350000024 + 0.649999976;
  r7.w = min(1.5, r7.w);
  r16.xy = max(float2(1.25,0), r2.xx);
  r16.xy = min(float2(1.75,1.5), r16.xy);
  r2.x = r16.x + -r7.w;
  r2.x = featureToggles.x * r2.x + r7.w;
  r16.xzw = r14.xyz * r2.xxx;
  r16.xzw = lightScales.www * r16.xzw;
  r2.x = dot(r22.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r17.xyz = r21.xyz * r5.www + -r2.xxx;
  r17.xyz = r6.www * r17.xyz + r2.xxx;
  r14.xyz = r16.yyy * r14.xyz;
  r22.xy = -blendWeights.yx + float2(1,1);
  r22.xzw = r21.xyz * blendWeights.yyy + r22.xxx;
  r14.xyz = r14.xyz * r22.xzw + r17.xyz;
  r14.xyz = r14.xyz * lightScales.yyy + -r16.xzw;
  r14.xyz = r3.xxx * r14.xyz + r16.xzw;
  r2.x = dot(r6.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r6.xyz = r3.yzw * float3(0.649999976,0.649999976,0.649999976) + -r2.xxx;
  r6.xyz = r6.xyz * float3(1.20000005,1.20000005,1.20000005) + r2.xxx;
  r2.x = saturate(r4.x + r25.w);
  r16.xyz = r9.xyz * lightScales.zzz + -r6.xyz;
  r6.xyz = r2.xxx * r16.xyz + r6.xyz;
  r16.xyz = r15.xyz * r24.xyz + -r6.xyz;
  r6.xyz = r6.www * r16.xyz + r6.xyz;
  r2.x = 1 + -r2.w;
  r16.xyz = r25.xyz * r2.www + r2.xxx;
  r16.xyz = r16.xyz * r6.xyz;
  r17.xyz = r15.xyz * r24.xyz + -r3.yzw;
  r3.yzw = r4.xxx * r17.xyz + r3.yzw;
  r2.x = dot(r6.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r2.w = dot(r16.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r2.w = max(0.00100000005, r2.w);
  r2.w = 1 / r2.w;
  r2.x = r2.x * r2.w;
  r2.x = max(0, r2.x);
  r2.x = min(1.5, r2.x);
  r6.xyz = r16.xyz * r2.xxx + -r3.yzw;
  r3.yzw = r3.xxx * r6.xyz + r3.yzw;
  r2.x = r6.w + -r4.x;
  r2.x = r3.x * r2.x + r4.x;

  // ===== 12. Matcap eye highlight (view-space normal projection) =====
  r6.xyz = r11.yyy * r8.xyz;
  r6.xyz = r11.xxx * v4.xyz + r6.xyz;
  r6.xyz = r11.zzz * v3.xyz + r6.xyz;
  r8.xyz = viewRow1.xyz * r6.yyy;
  r6.xyw = viewRow0.xyz * r6.xxx + r8.xyz;
  r6.xyz = viewRow2.xyz * r6.zzz + r6.xyw;
  r2.w = dot(r6.xyz, r6.xyz);
  r2.w = rsqrt(r2.w);
  r6.xy = r6.xy * r2.ww;
  r6.xy = r6.xy * float2(0.5,0.5) + float2(0.5,0.5);
  r6.xyzw = EyeHighlightMatcap.SampleBias(sampMatcap, r6.xy, mipBiasFrame.x).xyzw;
  r2.w = -twoSidedAndOpacity.z + 1;
  r2.w = r10.w * twoSidedAndOpacity.z + r2.w;
  r8.xyz = r14.xyz * r3.yzw;
  r11.xyz = matcapTint.xyz * r6.www;
  r6.xyz = r6.xyz * matcapTint.www + r11.xyz;
  r4.x = r2.x * 0.5 + 0.5;
  r6.w = -lightScales.z + 1;
  r2.x = r2.x * r6.w + lightScales.z;
  r2.x = r4.x * r2.x;
  r11.xyz = r14.xyz * r2.xxx;
  r6.xyz = r11.xyz * r6.xyz;
  r6.xyz = r8.xyz * r2.www + r6.xyz;
  r2.x = dot(r6.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r4.x = -0.5 + r2.x;
  r4.x = max(0, r4.x);
  r4.x = min(0.5, r4.x);
  r6.w = dot(r18.xyz, r12.xyz);
  r7.w = dot(r0.xyz, r12.xyz);
  r8.x = 1 + -r3.x;
  r4.x = r4.x * r4.x + 1;
  r6.xyz = r6.xyz + -r2.xxx;
  r6.xyz = r4.xxx * r6.xyz + r2.xxx;

  // ===== 13. Rim / facing term =====
  r2.x = max(r19.x, r19.y);
  r2.x = max(r2.x, r19.z);
  r2.x = 0.5 * r2.x;
  r2.x = max(1, r2.x);
  r2.x = 1 / r2.x;
  r8.yzw = r19.xyz * r2.xxx;
  r11.xyz = r21.xyz * r5.www + -r8.yzw;
  r8.yzw = r3.xxx * r11.xyz + r8.yzw;
  r2.x = dot(r20.xyz, r12.xyz);
  r4.x = r2.x * r2.y;
  r5.w = r6.w * 0.5 + -1;
  r5.w = -r6.w * r5.w + 0.5;
  r2.x = -r2.x * r2.y + r5.w;
  r2.x = saturate(r3.x * r2.x + r4.x);
  r8.yzw = r8.yzw * r2.xxx;
  r2.x = dot(sunDir.xz, sunDir.xz);
  r2.x = rsqrt(r2.x);
  r2.xy = sunDir.xz * r2.xx;
  r2.x = dot(r18.xz, r2.xy);
  r2.x = saturate(-r2.x);
  r2.x = r2.x * r3.x + r8.x;
  r2.x = r2.x * r22.y;
  r8.yzw = r8.yzw * r2.xxx;
  r2.x = 0.399999976 + -abs(r7.w);
  r2.x = saturate(5.00000048 * r2.x);
  r2.y = r2.x * -2 + 3;
  r2.x = r2.x * r2.x;
  r2.x = r2.y * r2.x;
  r8.yzw = r8.yzw * r2.xxx;
  r2.x = dot(r15.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r2.x = -0.100000001 + r2.x;
  r2.x = saturate(-16.666666 * r2.x);
  r2.y = r2.x * -2 + 3;
  r2.x = r2.x * r2.x;
  r2.x = r2.y * r2.x;
  r2.x = r2.x * r3.x + r8.x;
  r8.yzw = r8.yzw * r2.xxx;
  r11.xyz = max(float3(0.150000006,0.150000006,0.150000006), r15.xyz);
  r6.xyz = r8.yzw * r11.xyz + r6.xyz;

  // ===== 14. Additive highlight terms =====
  r8.yzw = specGlobalScale.zzz * r23.xyz;
  r7.xyz = r7.xyz * specGlobalScale.yyy + r8.yzw;
  r7.xyz = r10.xyz * specGlobalScale.xxx + r7.xyz;
  r6.xyz = r7.xyz * r2.www + r6.xyz;

  // ===== 15. Tiled light loop (8 slices x 32 lights, shadow + cookie) =====
  r2.xy = (uint2)r13.xy;
  r7.xy = float2(0.03125,0.03125) * r2.xy;
  r7.xy = floor(r7.xy);
  r3.x = r7.y * tileGridParams.y + r7.x;
  r3.x = 8 * r3.x;
  r3.x = (int)r3.x;
  r4.x = -tileDepthJitter.y * tileDepthParams.w + v0.w;
  r4.x = floor(r4.x);
  r5.w = tileGridParams.w + -1;
  r6.w = max(0, r4.x);
  r5.w = min(r6.w, r5.w);
  r6.w = 8 * r5.w;
  r6.w = (int)r6.w;
  r4.x = cmp(r5.w >= r4.x);
  r5.w = (int)r6.w + asint(lightListBase.y);
  r6.w = r8.x * -0.25 + 0.75;
  r7.xyz = r10.xyz * r2.zzz + float3(-0.5,-0.5,-0.5);
  r8.w = 1;
  r10.xyz = r6.xyz;
  r2.z = 0;
  while (true) {
    r9.w = cmp(7 < (int)r2.z);
    if (r9.w != 0) break;
    r9.w = (int)r2.z + (int)r3.x;
    r9.w = LightTileMaskSB[r9.w].val[0/4];
    r11.x = (int)r2.z + (int)r5.w;
    r11.x = LightTileMaskSB[r11.x].val[0/4];
    r9.w = (int)r9.w & (int)r11.x;
    r9.w = r4.x ? r9.w : 0;
    r11.x = (uint)r2.z << 5;
    r11.yzw = r10.xyz;
    r12.w = r9.w;
    while (true) {
      if (r12.w == 0) break;
      r13.z = firstbitlow((uint)r12.w);
      r14.x = 1 << (int)r13.z;
      r14.x = (int)r12.w ^ (int)r14.x;
      r13.z = (int)r11.x + (int)r13.z;
      bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r16.x = (((uint)r13.z << 3) & bitmask.x) | ((uint)1 & ~bitmask.x);
      bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r16.y = (((uint)r13.z << 3) & bitmask.y) | ((uint)5 & ~bitmask.y);
      bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r16.z = (((uint)r13.z << 3) & bitmask.z) | ((uint)6 & ~bitmask.z);
      bitmask.w = ((~(-1 << 29)) << 3) & 0xffffffff;  r16.w = (((uint)r13.z << 3) & bitmask.w) | ((uint)7 & ~bitmask.w);
      r14.y = (uint)cb3[r16.y+6].w;
      r14.y = cmp((int)r14.y == 1);
      if (r14.y != 0) {
        r8.xyz = -cb3[r16.x+6].xyz + v2.xyz;
        r14.yzw = int3(0xffff,0xffff,0xffff) & asint(cb3[r16.y+6].xzy);
        r17.xyz = int3(0xffff,0xffff,0xffff) & asint(cb3[r16.z+6].yxz);
        r18.xyz = asuint(cb3[r16.y+6].xzy) >> int3(16,16,16);
        r19.xyz = asuint(cb3[r16.z+6].yxz) >> int3(16,16,16);
        r14.yzw = f16tof32(r14.yzw);
        r17.xyz = f16tof32(r17.xyz);
        r18.xyz = f16tof32(r18.xyz);
        r19.xyw = f16tof32(r19.yxz);
        r20.xz = r14.yw;
        r20.yw = r18.xz;
        r14.y = dot(r8.xyzw, r20.xyzw);
        r18.x = r14.z;
        r18.z = r17.y;
        r18.w = r19.x;
        r14.z = dot(r8.xyzw, r18.xyzw);
        r19.xz = r17.xz;
        r8.x = dot(r8.xyzw, r19.xyzw);
        r8.y = max(abs(r14.y), abs(r14.z));
        r8.x = max(r8.y, abs(r8.x));
        r8.y = cb3[r16.w+6].x * 0.5 + 0.5;
        r8.x = r8.x + -r8.y;
        r8.y = -cb3[r16.w+6].x * 0.5 + 0.5;
        r8.x = saturate(r8.x / r8.y);
        r8.x = 1 + -r8.x;
        r8.x = r8.x * r8.x;
      } else {
        r8.x = 1;
      }
      r8.y = cmp(r8.x < 0.00100000005);
      if (r8.y != 0) {
        r12.w = r14.x;
        continue;
      }
      r8.y = (uint)r13.z << 3;
      r8.z = cmp(cb3[r8.y+6].w < 1.5);
      if (r8.z != 0) {
        bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r8.z = (((uint)r13.z << 3) & bitmask.z) | ((uint)3 & ~bitmask.z);
        r14.y = cmp(16 == asint(cb3[r8.z+6].w));
        r14.z = cb3[r8.z+6].z + blendWeights.z;
        r14.z = cmp(r14.z < 0.5);
        r14.y = (int)r14.z | (int)r14.y;
        if (r14.y == 0) {
          bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r14.y = (((uint)r13.z << 3) & bitmask.y) | ((uint)2 & ~bitmask.y);
          bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r14.z = (((uint)r13.z << 3) & bitmask.z) | ((uint)4 & ~bitmask.z);
          r13.z = (uint)cb3[r8.y+6].w;
          r13.z = (int)r13.z & 1;
          r14.w = cmp((int)r13.z == 0);
          r14.w = ~(int)r14.w;
          r15.w = cmp(0 < cb3[r14.y+6].z);
          r14.w = r14.w ? r15.w : 0;
          r15.w = cmp(4 == asint(cb3[r8.z+6].w));
          r16.y = r13.z ? 0 : 1;
          r17.x = cb3[r14.y+6].y * 0.5 + 0.5;
          r17.z = -abs(cb3[r14.y+6].x) + r17.x;
          r17.x = cb3[r14.y+6].y + -r17.z;
          r17.w = 1 + -abs(r17.z);
          r17.w = r17.w + -abs(r17.x);
          r17.w = max(0.00048828125, r17.w);
          r18.x = cmp(cb3[r14.y+6].x >= 0);
          r17.y = r18.x ? r17.w : -r17.w;
          r17.w = dot(r17.xyz, r17.xyz);
          r17.w = rsqrt(r17.w);
          r17.xyz = r17.xyz * r17.www;
          r17.w = cb3[r14.z+6].y + cb3[r14.z+6].y;
          r17.w = max(0.100000001, r17.w);
          r18.x = r15.w ? 1.000000 : 0;
          r17.w = -cb3[r16.z+6].w + r17.w;
          r16.z = r18.x * r17.w + cb3[r16.z+6].w;
          r18.xyz = cb3[r16.x+6].xyz + -v2.xyz;
          r17.w = dot(r18.yzx, -r17.xyz);
          r18.w = cmp(0.5 < cb3[r14.z+6].z);
          r18.w = r15.w ? r18.w : 0;
          r18.w = r18.w ? 1.000000 : 0;
          r18.w = r18.w * r16.y;
          r19.xyz = -r17.zxy * r17.www + -r18.xyz;
          r18.xyz = r18.www * r19.xyz + r18.xyz;
          r17.w = dot(r18.xyz, r18.xyz);
          r18.w = rsqrt(r17.w);
          r19.xyz = r18.xyz * r18.www;
          if (r14.w != 0) {
            r20.xyz = cb3[r14.y+6].zzz * r17.zxy;
            r21.xyz = -r20.xyz * float3(0.5,0.5,0.5) + r18.xyz;
            r20.xyz = r20.xyz * float3(0.5,0.5,0.5) + r18.xyz;
            r18.w = dot(r21.xyz, r21.xyz);
            r18.w = sqrt(r18.w);
            r19.w = dot(r20.xyz, r20.xyz);
            r19.w = sqrt(r19.w);
            r22.xyz = r19.xyz * r17.xyz;
            r22.xyz = r17.zxy * r19.yzx + -r22.xyz;
            r23.xyz = r22.xyz * r17.xyz;
            r22.xyz = r22.zxy * r17.yzx + -r23.xyz;
            r20.w = dot(r22.xyz, r22.xyz);
            r20.w = rsqrt(r20.w);
            r19.xyz = r22.xyz * r20.www;
            r20.w = dot(r21.xyz, r20.xyz);
            r20.w = r18.w * r19.w + r20.w;
            r20.w = r20.w * 0.5 + 1;
            r20.w = 1 / r20.w;
            r21.x = dot(r19.xyz, r21.xyz);
            r18.w = r21.x / r18.w;
            r20.x = dot(r19.xyz, r20.xyz);
            r19.w = r20.x / r19.w;
            r18.w = r19.w + r18.w;
            r18.w = saturate(0.5 * r18.w);
            r18.w = r20.w * r18.w;
          } else {
            r18.w = 1;
          }
          r19.w = cmp(r16.z < 0);
          if (r19.w != 0) {
            r19.w = cb3[r16.x+6].w * cb3[r16.x+6].w;
            r19.w = r19.w * r17.w;
            r19.w = -r19.w * r19.w + 1;
            r19.w = max(0, r19.w);
            r17.w = 1 + r17.w;
            r17.w = 1 / r17.w;
            r20.x = r14.w ? 1.000000 : 0;
            r20.y = r18.w + -r17.w;
            r17.w = r20.x * r20.y + r17.w;
            r19.w = r19.w * r19.w;
            r17.w = r19.w * r17.w;
          } else {
            r20.xyz = cb3[r16.x+6].www * r18.xyz;
            r19.w = dot(r20.xyz, r20.xyz);
            r19.w = min(1, r19.w);
            r19.w = 1 + -r19.w;
            r19.w = log2(r19.w);
            r16.z = r19.w * r16.z;
            r16.z = exp2(r16.z);
            r17.w = r18.w * r16.z;
          }
          r16.z = dot(r19.yzx, -r17.xyz);
          r16.z = -cb3[r14.y+6].z + r16.z;
          r16.z = saturate(cb3[r14.y+6].w * r16.z);
          r16.z = r16.z * r16.z + -1;
          r16.y = r16.y * r16.z + 1;
          r16.y = r17.w * r16.y;
          r16.z = (int)cb3[r16.w+6].w;
          r14.w = ~(int)r14.w;
          r16.w = cmp((int)r16.z >= 0);
          r14.w = r14.w ? r16.w : 0;
          if (r14.w != 0) {
            if (r13.z == 0) {
              r14.w = (uint)r16.z << 2;
              r17.xyz = cb6[r14.w+33].xyw * v2.yyy;
              r17.xyz = cb6[r14.w+32].xyw * v2.xxx + r17.xyz;
              r17.xyz = cb6[r14.w+34].xyw * v2.zzz + r17.xyz;
              r17.xyz = cb6[r14.w+35].xyw + r17.xyz;
              r17.xy = saturate(r17.xy / r17.zz);
              r17.xy = r17.xy * cb6[r16.z+0].zw + cb6[r16.z+0].xy;
            } else {
              r14.w = (uint)r16.z << 2;
              r20.x = dot(-r18.xyz, cb6[r14.w+32].xyz);
              r20.y = dot(-r18.xyz, cb6[r14.w+33].xyz);
              r20.z = dot(-r18.xyz, cb6[r14.w+34].xyz);
              r14.w = cmp(abs(r20.x) < abs(r20.y));
              // [patch] dump printed int 1 as 0.000000 (movc l(1), l(0))
              r14.w = r14.w ? 1 : 0;
              r16.w = dot(abs(r20.xy), icb[r14.w+0].xy);
              r16.w = cmp(r16.w < abs(r20.z));
              r14.w = r16.w ? 2 : r14.w;
              r16.w = dot(r20.xyz, icb[r14.w+0].xyz);
              r16.w = cmp(r16.w < 0);
              // [patch] bfi face=(axis<<1)|signBit; (uint)(-1.0) would clamp to 0
              bitmask.w = ((~(-1 << 31)) << 1) & 0xffffffff;  r14.w = (((uint)r14.w << 1) & bitmask.w) | ((r16.w != 0 ? 1u : 0u) & ~bitmask.w);
              r16.w = (uint)r14.w >> 1;
              r16.w = dot(r20.xyz, icb[r16.w+0].xyz);
              r17.z = 0.000244140625 / cb6[r16.z+0].w;
              r17.z = 0.5 + -r17.z;
              r17.w = (uint)r14.w;
              r18.x = cmp((uint)r14.w < 2);
              // [patch] dump printed int 2 as 0.000000 (icb[2].xz vs icb[0].xz)
              r18.x = r18.x ? 2 : 0;
              r18.x = dot(r20.xz, icb[r18.x+0].xz);
              r18.x = icb[r14.w+4].z * r18.x;
              r18.x = r18.x / abs(r16.w);
              r17.w = r18.x * r17.z + r17.w;
              r17.w = 0.5 + r17.w;
              r18.x = saturate(0.166666672 * r17.w);
              r17.w = -1 + (int)icb[r14.w+4].y;
              r17.w = dot(r20.yz, icb[r17.w+0].xy);
              r14.w = icb[r14.w+4].w * r17.w;
              r14.w = r14.w / abs(r16.w);
              r18.y = saturate(-r14.w * r17.z + 0.5);
              r17.xy = r18.xy * cb6[r16.z+0].zw + cb6[r16.z+0].xy;
            }
            r14.w = LightCookieAtlas.SampleLevel(sampLinear, r17.xy, 0).x;
            r16.y = r16.y * r14.w;
          }
          r8.x = r16.y * r8.x;
          r14.w = cmp(9.99999975e-05 < r8.x);
          if (r14.w != 0) {
            if (r15.w != 0) {
              r14.w = -cb3[r14.z+6].w + 1;
              r16.y = dot(r4.yzw, r19.xyz);
              r16.y = saturate(0.5 + r16.y);
              r16.z = r16.y * -2 + 3;
              r16.y = r16.y * r16.y;
              r16.y = r16.z * r16.y;
              r14.w = r16.y * cb3[r14.z+6].w + r14.w;
              r14.w = cb3[r14.z+6].x * r14.w;
              r14.w = r14.w * r8.x;
              r16.yzw = cb3[r8.y+6].xyz + -r11.yzw;
              r16.yzw = r14.www * r16.yzw + r11.yzw;
            }
            if (r15.w == 0) {
              r14.w = dot(r12.xyz, r19.xyz);
              r17.x = saturate(r14.w);
              if (cb3[r8.z+6].w != 0) {
                if (r13.z == 0) {
                  r13.z = (int)cb3[r8.z+6].x;
                } else {
                  r17.yzw = -cb3[r16.x+6].xyz + v2.xyz;
                  r18.xyz = cmp(abs(r17.zww) < abs(r17.yyz));
                  r18.x = r18.y ? r18.x : 0;
                  r17.yzw = cmp(float3(0,0,0) < r17.yzw);
                  r18.y = asuint(cb3[r14.y+6].w) >> 24;
                  r20.x = (asuint(cb3[r14.y+6].w) >> 16) & 0xffu; // [patch] ubfe(8,16): asuint bitcast, not (uint)float
                  r20.y = (asuint(cb3[r14.y+6].w) >> 8) & 0xffu; // [patch] ubfe(8,8): asuint bitcast, not (uint)float
                  r17.y = r17.y ? r18.y : r20.x;
                  r14.y = 255 & asint(cb3[r14.y+6].w);
                  r14.y = r17.z ? r20.y : r14.y;
                  r17.z = (asuint(cb3[r8.z+6].x) >> 8) & 0xffu; // [patch] ubfe(8,8): asuint bitcast, not (uint)float
                  r18.y = 255 & asint(cb3[r8.z+6].x);
                  r17.z = r17.w ? r17.z : r18.y;
                  r14.y = r18.z ? r14.y : r17.z;
                  r14.y = r18.x ? r17.y : r14.y;
                  r17.y = cmp((int)r14.y < 80);
                  r13.z = r17.y ? r14.y : -1;
                }
                r14.y = cmp((int)r13.z >= 0);
                if (r14.y != 0) {
                  r17.yzw = -cb3[r16.x+6].xyz + v2.xyz;
                  r14.y = (uint)r13.z << 2;
                  r16.x = dot(r17.yzw, r17.yzw);
                  r16.x = max(1.17549435e-38, r16.x);
                  r16.x = rsqrt(r16.x);
                  r17.yzw = r17.yzw * r16.xxx;
                  r17.yzw = -r17.yzw * cb4[r13.z+288].xxx + v2.xyz;
                  r16.x = cb4[r13.z+288].y * 5;
                  r17.yzw = r4.yzw * r16.xxx + r17.yzw;
                  r18.xyzw = cb4[r14.y+65].xyzw * r17.zzzz;
                  r18.xyzw = cb4[r14.y+64].xyzw * r17.yyyy + r18.xyzw;
                  r18.xyzw = cb4[r14.y+66].xyzw * r17.wwww + r18.xyzw;
                  r18.xyzw = cb4[r14.y+67].xyzw + r18.xyzw;
                  r17.yzw = r18.xyz / r18.www;
                  r18.xyz = cmp(float3(0,0,0) >= r17.yzw);
                  r20.xyz = cmp(r17.yzw >= float3(1,1,1));
                  r21.xy = cb4[r13.z+344].zw + -cb4[r13.z+344].xy;
                  r17.yz = r17.yz * r21.xy + cb4[r13.z+344].xy;
                  r21.xy = r17.yz * shadowTexelSize.zw + float2(0.5,0.5);
                  r21.xy = floor(r21.xy);
                  r17.yz = r17.yz * shadowTexelSize.zw + -r21.xy;
                  r22.xyzw = float4(0.5,1,0.5,1) + r17.yyzz;
                  r23.xyzw = r22.xxzz * r22.xxzz;
                  r21.zw = float2(1,1) + -r17.yz;
                  r22.xz = min(float2(0,0), r17.yz);
                  r24.xy = max(float2(0,0), r17.yz);
                  r25.xy = float2(0.159999996,0.159999996) * r21.zw;
                  r24.xy = -r24.xy * r24.xy + r22.yw;
                  r24.xy = float2(1,1) + r24.xy;
                  r24.xy = float2(0.159999996,0.159999996) * r24.xy;
                  r23.xz = float2(0.0799999982,0.0799999982) * r23.xz;
                  r17.yz = r23.yw * float2(0.5,0.5) + -r17.yz;
                  r26.xy = float2(0.159999996,0.159999996) * r17.yz;
                  r17.yz = -r22.xz * r22.xz + r21.zw;
                  r17.yz = float2(1,1) + r17.yz;
                  r27.xy = float2(0.159999996,0.159999996) * r17.yz;
                  r17.yz = float2(0.159999996,0.159999996) * r22.yw;
                  r26.z = r27.x;
                  r26.w = r17.y;
                  r25.z = r24.x;
                  r25.w = r23.x;
                  r22.xyzw = r26.zwxz + r25.zwxz;
                  r27.z = r26.y;
                  r27.w = r17.z;
                  r24.z = r25.y;
                  r24.w = r23.z;
                  r23.xyz = r27.zyw + r24.zyw;
                  r25.xyz = r25.xzw / r22.zwy;
                  r25.xyz = float3(-2.5,-0.5,1.5) + r25.xyz;
                  r25.xyz = shadowTexelSize.xxx * r25.yxz;
                  r24.xyz = r24.zyw / r23.xyz;
                  r24.xyz = float3(-2.5,-0.5,1.5) + r24.xyz;
                  r24.xyz = shadowTexelSize.yyy * r24.xyz;
                  r25.w = r24.x;
                  r26.xyzw = r21.xyxy * shadowTexelSize.xyxy + r25.ywxw;
                  r17.yz = r21.xy * shadowTexelSize.xy + r25.zw;
                  r24.w = r25.y;
                  r25.yw = r24.yz;
                  r27.xyzw = r21.xyxy * shadowTexelSize.xyxy + r25.xyzy;
                  r24.xyzw = r21.xyxy * shadowTexelSize.xyxy + r24.wywz;
                  r21.xyzw = r21.xyxy * shadowTexelSize.xyxy + r25.xwzw;
                  r25.xyzw = r23.xxxy * r22.zwyz;
                  r14.y = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r26.xy, r17.w).x;
                  r16.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r26.zw, r17.w).x;
                  r16.x = r25.y * r16.x;
                  r14.y = r25.x * r14.y + r16.x;
                  r16.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r17.yz, r17.w).x;
                  r14.y = r25.z * r16.x + r14.y;
                  r16.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r24.xy, r17.w).x;
                  r14.y = r25.w * r16.x + r14.y;
                  r25.xyzw = r23.yyzz * r22.xyzw;
                  r16.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r27.xy, r17.w).x;
                  r14.y = r25.x * r16.x + r14.y;
                  r16.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r27.zw, r17.w).x;
                  r14.y = r25.y * r16.x + r14.y;
                  r16.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r24.zw, r17.w).x;
                  r14.y = r25.z * r16.x + r14.y;
                  r16.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r21.xy, r17.w).x;
                  r14.y = r25.w * r16.x + r14.y;
                  r18.xyz = (int3)r18.xyz | (int3)r20.xyz;
                  r16.x = (int)r18.y | (int)r18.x;
                  r16.x = (int)r18.z | (int)r16.x;
                  r17.y = (int)r17.w & 0x7fffffff;
                  r17.y = cmp(0x7f800000 < (uint)r17.y);
                  r16.x = (int)r16.x | (int)r17.y;
                  r17.y = r23.z * r22.y;
                  r17.z = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r21.zw, r17.w).x;
                  r14.y = r17.y * r17.z + r14.y;
                  r14.y = -1 + r14.y;
                  r13.z = cb4[r13.z+288].w * r14.y + 1;
                  r13.z = r16.x ? 1 : r13.z;
                } else {
                  r14.y = dot(r5.xyz, r19.xyz);
                  r13.z = saturate(1 + r14.y);
                }
              } else {
                r13.z = 1;
              }
              if (cb3[r8.z+6].w == 0) {
                r17.yzw = cb3[r8.y+6].xyz * r8.xxx;
                r14.y = -cb3[r14.z+6].y + 1;
                r16.x = max(r17.y, r17.z);
                r16.x = max(r16.x, r17.w);
                r16.x = r16.x * r6.w;
                r16.x = max(1, r16.x);
                r16.x = 1 / r16.x;
                r14.y = r16.x * cb3[r14.z+6].y + r14.y;
                r17.yzw = cb3[r8.y+6].xyz * r14.yyy;
                r14.y = cb3[r14.z+6].x * 0.25;
                r16.x = saturate(0.5 + r14.w);
                r18.x = -cb3[r14.z+6].x * 0.25 + 1;
                r14.y = r16.x * r18.x + r14.y;
                r17.yzw = r17.yzw * r14.yyy;
                r18.xyz = r3.yzw;
                r20.xyz = r3.yzw;
              } else {
                r14.y = cmp(3 == asint(cb3[r8.z+6].w));
                if (r14.y != 0) {
                  r21.xyz = sunDir.xyz * r19.zxy;
                  r19.xyz = sunDir.zxy * r19.xyz + -r21.xyz;
                  r21.xyz = sunDir.zxy * r19.xyz;
                  r19.xyz = sunDir.yzx * r19.yzx + -r21.xyz;
                  r16.x = dot(r19.xyz, r19.xyz);
                  r16.x = rsqrt(r16.x);
                  r19.xyz = r19.xyz * r16.xxx;
                  r17.x = saturate(dot(r12.xyz, -r19.xyz));
                  r18.xyz = cb3[r14.z+6].yyy * r7.xyz + float3(0.5,0.5,0.5);
                  r20.xyz = float3(0,0,0);
                } else {
                  r8.z = cmp(1 == asint(cb3[r8.z+6].w));
                  if (r8.z != 0) {
                    r14.w = cb3[r14.z+6].x + r14.w;
                    r14.w = saturate(max(-1, r14.w));
                    r17.x = r14.w * r13.z;
                    r20.xyz = cb3[r14.z+6].yyy * r9.xyz;
                  } else {
                    r20.xyz = float3(0,0,0);
                  }
                  r18.xyz = r8.zzz ? r15.xyz : 0;
                }
                r8.x = r14.y ? 0 : r8.x;
                r17.yzw = cb3[r8.y+6].xyz;
              }
              r8.xyz = r17.yzw * r8.xxx;
              r14.yzw = -r20.xyz + r18.xyz;
              r14.yzw = r17.xxx * r14.yzw + r20.xyz;
              r8.xyz = r14.yzw * r8.xyz;
              r11.yzw = r8.xyz * r2.www + r11.yzw;
            }
          } else {
            r15.w = 0;
          }
          r11.yzw = r15.www ? r16.yzw : r11.yzw;
        }
      }
      r12.w = r14.x;
    }
    r10.xyz = r11.yzw;
    r2.z = (int)r2.z + 1;
  }

  // ===== 16. Colour grade (saturation, contrast, tint, rim colour) =====
  r2.z = cmp(0.5 < gradeParams.x);
  if (r2.z != 0) {
    r2.z = dot(r10.xyz, float3(0.212672904,0.715152204,0.0721750036));
    r3.xyz = r10.xyz + -r2.zzz;
    r3.xyz = gradeParams.zzz * r3.xyz + r2.zzz;
    r3.xyz = float3(-0.5,-0.5,-0.5) + r3.xyz;
    r3.xyz = gradeParams.www * r3.xyz + float3(0.5,0.5,0.5);
    r4.xyz = gradeParams.yyy * r3.xyz;
    r3.xyz = -r3.xyz * gradeParams.yyy + gradeTintColor.xyz;
    r3.xyz = gradeTintColor.www * r3.xyz + r4.xyz;
    r2.z = -baseColorGrade.x + 1;
    r7.w = saturate(r7.w);
    r2.w = 1 + -r7.w;
    r3.w = 1 + -r2.z;
    r2.z = r2.w + -r2.z;
    r2.w = 1 / r3.w;
    r2.z = saturate(r2.z * r2.w);
    r2.w = r2.z * -2 + 3;
    r2.z = r2.z * r2.z;
    r2.z = r2.w * r2.z;
    r4.xyz = gradeRimColor.xyz * r2.zzz;
    r10.xyz = r4.xyz * baseColorGrade.yyy + r3.xyz;
  }

  // ===== 17. Exposure and alpha output =====
  r3.xyz = r10.xyz / exposure.xxx;
  r2.z = cmp(1.000000 == alphaMode.x);
  o0.w = r2.z ? r10.w : 1;

  // ===== 18. Height fog and froxel volumetric fog =====
  r2.z = cmp(blendWeights.w < 0.5);
  if (r2.z != 0) {
    r0.w = r1.w * r0.w;
    r1.w = v2.y * fogHeightA.w + fogHeightB.w;
    r1.w = max(0.00999999978, r1.w);
    r2.z = r0.w * fogDirParams.w + -fogStartFade.w;
    r2.z = max(0, r2.z);
    r2.w = -1.44269502 * r1.w;
    r2.w = exp2(r2.w);
    r2.w = 1 + -r2.w;
    r1.w = r2.w / r1.w;
    r2.w = v2.y * fogHeightA.w + fogHeightC.w;
    r2.w = 1.44269502 * r2.w;
    r2.w = exp2(r2.w);
    r1.w = r2.w * r1.w;
    r1.w = -r2.z * r1.w;
    r4.xyz = fogColorParams.xyz * r1.www;
    r4.xyz = float3(1.44269502,1.44269502,1.44269502) * r4.xyz;
    r4.xyz = exp2(r4.xyz);
    r1.w = dot(-r0.xyz, fogDirParams.xyz);
    r2.z = fogColorParams.w * fogColorParams.w + 1;
    r2.w = dot(r1.ww, fogColorParams.ww);
    r2.z = r2.z + -r2.w;
    r2.w = cmp(0 < fogVolumeParams.z);
    if (r2.w != 0) {
      r13.w = 7 & asint(mipBiasFrame.w);
      r5.xyz = mad((int3)r13.xyw, int3(0x19660d,0x19660d,0x19660d), int3(0x3c6ef35f,0x3c6ef35f,0x3c6ef35f));
      r2.w = mad((int)r5.y, (int)r5.z, (int)r5.x);
      r3.w = mad((int)r5.z, (int)r2.w, (int)r5.y);
      r4.w = mad((int)r2.w, (int)r3.w, (int)r5.z);
      r5.x = mad((int)r3.w, (int)r4.w, (int)r2.w);
      r0.x = dot(-r0.xyz, -r1.xyz);
      r0.y = -cameraPos.y + v2.y;
      r0.z = cmp(5.96046448e-08 < r0.x);
      r0.x = 1 / r0.x;
      r0.x = r0.z ? r0.x : 0;
      r0.x = fogVolumeParams.w * r0.x;
      r0.z = 1 / r0.w;
      r1.x = r0.x * r0.z;
      r1.y = r1.x * r0.y + cameraPos.y;
      r0.y = -r1.x * r0.y + r0.y;
      r1.x = fogLayerA.z * r0.y;
      r0.y = fogLayerB.x * r0.y;
      r0.y = max(-127, r0.y);
      r1.z = -fogLayerA.x + r1.y;
      r1.z = fogLayerA.z * r1.z;
      r1.xz = max(float2(-127,-127), r1.xz);
      r1.z = exp2(-r1.z);
      r1.z = fogLayerA.y * r1.z;
      r2.w = cmp(5.96046448e-08 < abs(r1.x));
      r5.z = exp2(-r1.x);
      r5.z = 1 + -r5.z;
      r5.z = r5.z / r1.x;
      r1.x = -r1.x * 0.240226507 + 0.693147182;
      r1.x = r2.w ? r5.z : r1.x;
      r1.y = -fogLayerB.z + r1.y;
      r1.y = fogLayerB.x * r1.y;
      r1.y = max(-127, r1.y);
      r1.y = exp2(-r1.y);
      r1.y = fogLayerB.y * r1.y;
      r2.w = cmp(5.96046448e-08 < abs(r0.y));
      r5.z = exp2(-r0.y);
      r5.z = 1 + -r5.z;
      r5.z = r5.z / r0.y;
      r0.y = -r0.y * 0.240226507 + 0.693147182;
      r0.y = r2.w ? r5.z : r0.y;
      r0.y = r1.y * r0.y;
      r0.y = r1.z * r1.x + r0.y;
      r0.x = -r0.x * r0.z + 1;
      r0.x = r0.x * r0.w;
      r0.x = r0.y * r0.x;
      r0.x = exp2(-r0.x);
      r0.x = min(1, r0.x);
      r0.x = max(fogAmbient.w, r0.x);
      r0.yz = saturate(r0.ww * fogAddParams.yw + fogAddParams.xz);
      r0.x = r0.x + r0.y;
      r0.x = r0.x + r0.z;
      r0.x = min(1, r0.x);
      r5.y = mad((int)r4.w, (int)r5.x, (int)r3.w);
      r0.yz = (uint2)r5.xy >> int2(16,16);
      r0.yz = (uint2)r0.yz;
      r0.yz = r0.yz * float2(3.05180438e-05,3.05180438e-05) + float2(-1,-1);
      r0.yz = r0.yz * fogJitterAmount.ww + r2.xy;
      r1.xy = fogJitterScale.xy * r0.yz;
      r0.y = v0.w * fogSliceParams.x + fogSliceParams.y;
      r0.y = log2(r0.y);
      r0.y = fogSliceParams.z * r0.y;
      r1.z = r0.y / fogVolumeParams.z;
      r5.xyzw = VolumetricFog3D.SampleLevel(sampLinear, r1.xyz, 0).xyzw;
      r0.y = -fogStartDist.z + v0.w;
      r0.y = saturate(1000000 * r0.y);
      r5.xyzw = float4(-0,-0,-0,-1) + r5.xyzw;
      r5.xyzw = r0.yyyy * r5.xyzw + float4(0,0,0,1);
      r0.y = 1 + -r0.x;
      r1.xyz = fogAmbient.xyz * r0.yyy;
      r1.xyz = r1.xyz * r5.www + r5.xyz;
      r0.x = r5.w * r0.x;
    } else {
      r0.y = -cameraPos.y + v2.y;
      r0.z = fogLayerA.z * r0.y;
      r0.y = fogLayerB.x * r0.y;
      r0.yz = max(float2(-127,-127), r0.yz);
      r2.x = -fogLayerA.x + cameraPos.y;
      r2.x = fogLayerA.z * r2.x;
      r2.x = max(-127, r2.x);
      r2.x = exp2(-r2.x);
      r2.x = fogLayerA.y * r2.x;
      r2.y = cmp(5.96046448e-08 < abs(r0.z));
      r2.w = exp2(-r0.z);
      r2.w = 1 + -r2.w;
      r2.w = r2.w / r0.z;
      r0.z = -r0.z * 0.240226507 + 0.693147182;
      r0.z = r2.y ? r2.w : r0.z;
      r2.y = -fogLayerB.z + cameraPos.y;
      r2.y = fogLayerB.x * r2.y;
      r2.y = max(-127, r2.y);
      r2.y = exp2(-r2.y);
      r2.y = fogLayerB.y * r2.y;
      r2.w = cmp(5.96046448e-08 < abs(r0.y));
      r3.w = exp2(-r0.y);
      r3.w = 1 + -r3.w;
      r3.w = r3.w / r0.y;
      r0.y = -r0.y * 0.240226507 + 0.693147182;
      r0.y = r2.w ? r3.w : r0.y;
      r0.y = r2.y * r0.y;
      r0.y = r2.x * r0.z + r0.y;
      r0.y = r0.y * r0.w;
      r0.y = exp2(-r0.y);
      r0.y = min(1, r0.y);
      r0.y = max(fogAmbient.w, r0.y);
      r0.zw = saturate(r0.ww * fogAddParams.yw + fogAddParams.xz);
      r0.y = r0.y + r0.z;
      r0.y = r0.y + r0.w;
      r0.x = min(1, r0.y);
      r0.y = 1 + -r0.x;
      r1.xyz = fogAmbient.xyz * r0.yyy;
    }
    r0.yzw = r4.xyz * r0.xxx;
    r1.w = r1.w * r1.w + 1;
    r1.w = 0.0596831031 * r1.w;
    r2.xyw = fogHeightA.xyz * r1.www + fogHeightC.xyz;
    r1.w = -fogColorParams.w * fogColorParams.w + 1;
    r3.w = 12.566371 * r2.z;
    r2.z = sqrt(r2.z);
    r2.z = r3.w * r2.z;
    r2.z = max(0.00100000005, r2.z);
    r1.w = r1.w / r2.z;
    r2.xyz = saturate(fogHeightB.xyz * r1.www + r2.xyw);
    r2.xyz = float3(255,255,255) * r2.xyz;
    r4.xyz = float3(1,1,1) + -r4.xyz;
    r2.xyz = r4.xyz * r2.xyz;
    r1.xyz = r2.xyz * r0.xxx + r1.xyz;
    o0.xyz = r3.xyz * r0.yzw + r1.xyz;
  } else {
    o0.xyz = r3.xyz;
  }
  o1.zw = float2(1,0.400000006);
  return;
}
