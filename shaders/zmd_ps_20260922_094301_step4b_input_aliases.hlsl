// ZMD / Endfield PS - Step 4b: REVERTED to 4a register form (rim/边缘光 fix)
// Source dump: 3Dmigoto 2026-09-22 09:43:01
// Previous 4b (interpolator const copies / material sample aliases) dropped rim
// in RenderDoc Apply. This file is byte-equivalent to step4a math, plus:
//   - note that PS t10 (LightingLUT) is the ramp used for wrap / 边缘光
//   - X4115 fix: cmp(-1/0) bit-insert uses asuint((int)...) not (uint)float
// Re-Apply and compare to original draw before any further renaming.
//
// Binding notes (from Colour Pass #3 draw matching this signature):
//   t0  LightTileMaskSB      - per-tile light bitmasks
//   t1  InstanceDataSB       - per-instance floats
//   t2  ShadowMap            - SampleCmp depth
//   t3  ScreenData           - Load at pixel (AO / exposure helper)
//   t4..t9 Volume cascades   - SH/irradiance 3D probes (fine/mid/coarse)
//   t10 LightingLUT         - PS t10 ramp (边缘光 / lighting wrap)
//   t11 SpecularBRDFLUT
//   t12 DetailNoise
//   t13 DetailNormal
//   t14 BaseColor
//   t15 MaterialMask         - metallic/roughness/etc packed
//   t16 NormalMap
//   t17 Emissive
//   t18 ReflectionCube
//   t19 LightCookieAtlas
//   t20 VolumetricFog3D
//

Texture3D<float4> VolumetricFog3D : register(t20);

Texture2D<float4> LightCookieAtlas : register(t19);

TextureCube<float4> ReflectionCube : register(t18);

Texture2D<float4> EmissiveMap : register(t17);

Texture2D<float4> NormalMap : register(t16);

Texture2D<float4> MaterialMask : register(t15);

Texture2D<float4> BaseColorMap : register(t14);

Texture2D<float4> DetailNormal : register(t13);

Texture2D<float4> DetailNoise : register(t12);

Texture2D<float4> SpecularBRDFLUT : register(t11);

Texture2D<float4> LightingLUT : register(t10);

Texture3D<float4> VolumeCoarse_SH : register(t9);

Texture3D<float4> VolumeCoarse_Weights : register(t8);

Texture3D<float4> VolumeMid_SH : register(t7);

Texture3D<float4> VolumeMid_Weights : register(t6);

Texture3D<float4> VolumeFine_SH : register(t5);

Texture3D<float4> VolumeFine_Weights : register(t4);

Texture2D<float4> ScreenData : register(t3);

Texture2D<float4> ShadowMap : register(t2);

struct t1_t {
  float val[4];
};
StructuredBuffer<t1_t> InstanceDataSB : register(t1);

struct t0_t {
  float val[1];
};
StructuredBuffer<t0_t> LightTileMaskSB : register(t0);

SamplerState sampEmissive : register(s6);

SamplerState sampNormal : register(s5);

SamplerState sampMaterial : register(s4);

SamplerState sampBaseColor : register(s3);

SamplerComparisonState sampShadowCmp : register(s2);

SamplerState sampVolumeWeights : register(s1);

SamplerState sampLinear : register(s0);

cbuffer cb6 : register(b6)
{
  float4 cb6[160];
}

cbuffer cb5 : register(b5)
{
  float4 cb5[9];
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
  float4 cb1[4093];
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
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27,r28,r29,r30,r31,r32;
  uint4 bitmask, uiDest;
  float4 fDest;

  // ===== 1. View / camera direction from worldPos =====
  r0.xyz = cb0[44].xyz + -v2.xyz;
  r1.x = cb0[0].z;
  r1.y = cb0[1].z;
  r1.z = cb0[2].z;
  r2.xyz = r1.xyz + -r0.xyz;
  r0.xyz = cb0[86].www * r2.xyz + r0.xyz;
  r0.w = dot(r0.xyz, r0.xyz);
  r1.w = max(9.99999994e-09, r0.w);
  r1.w = rsqrt(r1.w);
  r2.xyz = r1.www * r0.xyz;
  // ===== 2. Per-instance cb1 offset (TEXCOORD8) =====
  r2.w = (uint)v9.x << 4;
  r3.x = 16 & asint(cb1[r2.w+4].w);
  if (r3.x != 0) {
    r3.x = 2 + asint(cb1[r2.w+5].x);
    r3.x = InstanceDataSB[r3.x].val[12/4];
    r3.y = InstanceDataSB[cb1[r2.w+5].x].val[12/4];
  } else {
    r3.xy = cb1[r2.w+3].zx;
  }
  // ===== 3. Material sample: baseColor / mask / normal / emissive =====
  r4.xyzw = BaseColorMap.SampleBias(sampBaseColor, v1.xy, cb0[108].x).xyzw;
  r5.xyzw = MaterialMask.SampleBias(sampMaterial, v1.xy, cb0[108].x).xyzw;
  r3.zw = float2(1,1) + -r5.wx;
  r4.xyzw = cb5[5].xyzw * r4.xyzw;
  r6.xyz = cb5[4].zzz * r4.xyz;
  r6.x = dot(r6.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r6.yzw = r4.xyz * cb5[4].zzz + -r6.xxx;
  r6.xyz = cb5[4].www * r6.yzw + r6.xxx;
  r7.xyz = NormalMap.SampleBias(sampNormal, v1.xy, cb0[108].x).xyw;
  r7.x = r7.z * r7.x;
  r7.xy = r7.xy * float2(2,2) + float2(-1,-1);
  r6.w = dot(r7.xy, r7.xy);
  r6.w = min(1, r6.w);
  r6.w = 1 + -r6.w;
  r6.w = sqrt(r6.w);
  r6.w = max(1.00000002e-16, r6.w);
  r7.xy = cb5[0].ww * r7.xy;
  r8.xyz = EmissiveMap.SampleBias(sampEmissive, v1.xy, cb0[108].x).xyz;
  // ===== 4. Tangent-frame normal + world normal =====
  r9.xz = v2.xz + -r3.yx;
  r9.y = 6.10351562e-05;
  r3.x = dot(r9.xyz, r9.xyz);
  r3.x = rsqrt(r3.x);
  r9.xyz = r9.xyz * r3.xxx;
  r10.xyz = v4.yzx * v3.zxy;
  r10.xyz = v3.yzx * v4.zxy + -r10.xyz;
  r10.xyz = v4.www * r10.xyz;
  r7.yzw = r10.xyz * r7.yyy;
  r7.xyz = r7.xxx * v4.xyz + r7.yzw;
  r7.xyz = r6.www * v3.xyz + r7.xyz;
  r3.x = cb5[1].y * 2 + -1;
  r3.x = v10.x ? 1 : r3.x;
  r3.y = dot(r7.xyz, r7.xyz);
  r3.y = max(1.17549435e-38, r3.y);
  r3.y = rsqrt(r3.y);
  r7.xyz = r7.xyz * r3.yyy;
  r10.xyz = r7.xyz * r3.xxx;
  r3.y = dot(v3.xyz, v3.xyz);
  r3.y = rsqrt(r3.y);
  r11.xyz = v3.xyz * r3.yyy;
  r11.xyz = r11.xyz * r3.xxx;
  r12.xy = (uint2)v0.xy;
  r3.y = -cb0[111].x + 1;
  r3.y = cb0[198].w * r3.y + cb0[111].x;
  r3.y = cb0[109].x * r3.y;
  // ===== 5. Volumetric / probe SH cascade (t4..t9) optional path =====
  r6.w = cmp(cb0[187].y < 0.5);
  if (r6.w != 0) {
    r13.xyz = cb0[6].xzy * -cb0[212].www + cb0[210].xzy;
    r13.xyz = v2.xzy + -r13.xyz;
    r6.w = max(abs(r13.x), abs(r13.y));
    r6.w = -464 + r6.w;
    r6.w = saturate(0.03125 * r6.w);
    r7.w = -208 + abs(r13.z);
    r7.w = saturate(0.03125 * r7.w);
    r6.w = max(r7.w, r6.w);
    r7.w = cmp(0.000000 != cb0[210].w);
    r8.w = cmp(r6.w < 1);
    r7.w = r7.w ? r8.w : 0;
    if (r7.w != 0) {
      r13.xyz = cb0[6].xzy * -cb0[212].yyy + cb0[210].xzy;
      r13.xyz = v2.xzy + -r13.xyz;
      r7.w = max(abs(r13.x), abs(r13.y));
      r7.w = -29 + r7.w;
      r7.w = saturate(0.5 * r7.w);
      r8.w = -13 + abs(r13.z);
      r8.w = saturate(0.5 * r8.w);
      r7.w = max(r8.w, r7.w);
      r8.w = cmp(r7.w < 1);
      if (r8.w != 0) {
        r13.xyz = v2.xyz * float3(2,2,2) + float3(0.5,0.5,0.5);
        r14.xyz = cb0[211].xyz * r13.xyz;
        r14.xyz = floor(r14.xyz);
        r13.xyz = r13.xyz * cb0[211].xyz + -r14.xyz;
        r14.xyw = VolumeFine_Weights.SampleLevel(sampVolumeWeights, r13.xyz, 0).yzx;
        r8.w = 1 + -r7.w;
        r9.w = cb0[211].y * 0.5;
        r11.w = -cb0[211].y * 0.5 + 1;
        r9.w = max(r13.y, r9.w);
        r9.w = min(r9.w, r11.w);
        r13.w = 0.333333343 * r9.w;
        r15.xyzw = VolumeFine_SH.SampleLevel(sampLinear, r13.xwz, 0).xyzw;
        r9.w = r15.w * r8.w + r6.w;
        r16.xyz = float3(0,0.666666687,0) + r13.xwz;
        r16.xyz = VolumeFine_SH.SampleLevel(sampLinear, r16.xyz, 0).xyz;
        r16.xyz = r16.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r16.xyz = r16.xyz * r14.yyy;
        r16.w = r14.y;
        r16.xyzw = r16.xyzw * r8.wwww;
        r13.xyz = float3(0,0.333333343,0) + r13.xwz;
        r13.xyz = VolumeFine_SH.SampleLevel(sampLinear, r13.xyz, 0).xyz;
        r13.xyz = r13.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r13.xyz = r13.xyz * r14.xxx;
        r13.w = r14.x;
        r13.xyzw = r13.xyzw * r8.wwww;
        r15.xyz = r15.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r14.xyz = r15.xyz * r14.www;
        r14.xyzw = r14.xyzw * r8.wwww;
      } else {
        r16.xyzw = float4(0,0,0,0);
        r13.xyzw = float4(0,0,0,0);
        r14.xyzw = float4(0,0,0,0);
        r9.w = r6.w;
      }
      r15.xyz = cb0[6].xzy * -cb0[212].zzz + cb0[210].xzy;
      r15.xyz = v2.xzy + -r15.xyz;
      r8.w = max(abs(r15.x), abs(r15.y));
      r8.w = -116 + r8.w;
      r8.w = saturate(0.125 * r8.w);
      r11.w = -52 + abs(r15.z);
      r11.w = saturate(0.125 * r11.w);
      r8.w = max(r11.w, r8.w);
      r11.w = cmp(r8.w < 1);
      if (r11.w != 0) {
        r15.xyz = v2.xyz * float3(0.5,0.5,0.5) + float3(0.5,0.5,0.5);
        r17.xyz = cb0[211].xyz * r15.xyz;
        r17.xyz = floor(r17.xyz);
        r15.xyz = r15.xyz * cb0[211].xyz + -r17.xyz;
        r17.xyw = VolumeMid_Weights.SampleLevel(sampVolumeWeights, r15.xyz, 0).yzx;
        r11.w = 1 + -r8.w;
        r7.w = r11.w * r7.w;
        r11.w = cb0[211].y * 0.5;
        r18.x = -cb0[211].y * 0.5 + 1;
        r11.w = max(r15.y, r11.w);
        r11.w = min(r11.w, r18.x);
        r15.w = 0.333333343 * r11.w;
        r18.xyzw = VolumeMid_SH.SampleLevel(sampLinear, r15.xwz, 0).xyzw;
        r9.w = r18.w * r7.w + r9.w;
        r19.xyz = float3(0,0.666666687,0) + r15.xwz;
        r19.xyz = VolumeMid_SH.SampleLevel(sampLinear, r19.xyz, 0).xyz;
        r19.xyz = r19.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r19.xyz = r19.xyz * r17.yyy;
        r19.w = r17.y;
        r16.xyzw = r19.xyzw * r7.wwww + r16.xyzw;
        r15.xyz = float3(0,0.333333343,0) + r15.xwz;
        r15.xyz = VolumeMid_SH.SampleLevel(sampLinear, r15.xyz, 0).xyz;
        r15.xyz = r15.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r15.xyz = r15.xyz * r17.xxx;
        r15.w = r17.x;
        r13.xyzw = r15.xyzw * r7.wwww + r13.xyzw;
        r15.xyz = r18.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r17.xyz = r15.xyz * r17.www;
        r14.xyzw = r17.xyzw * r7.wwww + r14.xyzw;
      }
      r7.w = cmp(0 < r8.w);
      if (r7.w != 0) {
        r15.xyz = v2.xyz * float3(0.125,0.125,0.125) + float3(0.5,0.5,0.5);
        r17.xyz = cb0[211].xyz * r15.xyz;
        r18.xyz = cb0[211].xyz * float3(0.5,0.5,0.5);
        r17.xyz = floor(r17.xyz);
        r15.xyz = r15.xyz * cb0[211].xyz + -r17.xyz;
        r17.xyz = -cb0[211].xyz * float3(0.5,0.5,0.5) + float3(1,1,1);
        r15.xyz = max(r15.xyz, r18.xyz);
        r15.xyz = min(r15.xyz, r17.xyz);
        r19.xyw = VolumeCoarse_Weights.SampleLevel(sampVolumeWeights, r15.xyz, 0).yzx;
        r7.w = 1 + -r6.w;
        r7.w = r8.w * r7.w;
        r8.w = max(r15.y, r18.y);
        r8.w = min(r8.w, r17.y);
        r15.w = 0.333333343 * r8.w;
        r17.xyzw = VolumeCoarse_SH.SampleLevel(sampLinear, r15.xwz, 0).xyzw;
        r18.xyz = float3(0,0.666666687,0) + r15.xwz;
        r18.xyz = VolumeCoarse_SH.SampleLevel(sampLinear, r18.xyz, 0).xyz;
        r18.xyz = r18.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r18.xyz = r18.xyz * r19.yyy;
        r18.w = r19.y;
        r16.xyzw = r18.xyzw * r7.wwww + r16.xyzw;
        r15.xyz = float3(0,0.333333343,0) + r15.xwz;
        r15.xyz = VolumeCoarse_SH.SampleLevel(sampLinear, r15.xyz, 0).xyz;
        r15.xyz = r15.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r15.xyz = r15.xyz * r19.xxx;
        r15.w = r19.x;
        r13.xyzw = r15.xyzw * r7.wwww + r13.xyzw;
        r15.xyz = r17.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r19.xyz = r15.xyz * r19.www;
        r14.xyzw = r19.xyzw * r7.wwww + r14.xyzw;
        r9.w = r17.w * r7.w + r9.w;
      }
      r7.w = saturate(r9.w * 2 + -1);
      r15.x = r7.w + -r6.w;
      r6.w = r7.w + r6.w;
      r15.y = 0.5 * r6.w;
    } else {
      r16.xyzw = float4(0,0,0,0);
      r13.xyzw = float4(0,0,0,0);
      r14.xyzw = float4(0,0,0,0);
      r15.xy = float2(0,1);
    }
    r17.xyzw = cb0[213].xyzw * r15.yyyx;
    r17.y = r17.w * 0.5 + r17.y;
    r15.zw = cb0[213].wy * r15.yx;
    r17.w = r15.w * 0.375 + r15.z;
    r14.xyzw = r17.xyzw + r14.xyzw;
    r17.xyzw = cb0[214].xyzw * r15.yyyx;
    r17.y = r17.w * 0.5 + r17.y;
    r15.zw = cb0[214].wy * r15.yx;
    r17.w = r15.w * 0.375 + r15.z;
    r13.xyzw = r17.xyzw + r13.xyzw;
    r17.xyzw = cb0[215].xyzw * r15.yyyx;
    r17.y = r17.w * 0.5 + r17.y;
    r15.xy = cb0[215].wy * r15.yx;
    r17.w = r15.y * 0.375 + r15.x;
    r15.xyzw = r17.xyzw + r16.xyzw;
    r10.w = 1;
    r16.x = dot(r14.xyzw, r10.xyzw);
    r16.y = dot(r13.xyzw, r10.xyzw);
    r16.z = dot(r15.xyzw, r10.xyzw);
    r16.xyz = max(float3(0,0,0), r16.xyz);
    r17.xyz = r16.xyz * r3.yyy;
    r18.xyz = float3(0.715200007,0.715200007,0.715200007) * r13.xyz;
    r18.xyz = r14.xyz * float3(0.212599993,0.212599993,0.212599993) + r18.xyz;
    r18.xyz = r15.xyz * float3(0.0722000003,0.0722000003,0.0722000003) + r18.xyz;
    r6.w = dot(r18.xyz, r18.xyz);
    r6.w = max(1.17549435e-38, r6.w);
    r6.w = rsqrt(r6.w);
    r18.xyz = r18.xyz * r6.www;
    r18.y = abs(r18.y);
    r18.w = 1;
    r14.x = dot(r14.xyzw, r18.xyzw);
    r14.y = dot(r13.xyzw, r18.xyzw);
    r14.z = dot(r15.xyzw, r18.xyzw);
    r13.xyz = max(float3(0,0,0), r14.xyz);
    r6.w = cmp(r17.y >= r17.z);
    r6.w = r6.w ? 1.000000 : 0;
    r14.xy = r17.zy;
    r14.zw = float2(-1,0.666666687);
    r15.xy = r16.yz * r3.yy + -r14.xy;
    r15.zw = float2(1,-1);
    r14.xyzw = r6.wwww * r15.xyzw + r14.xyzw;
    r6.w = cmp(r17.x >= r14.x);
    r6.w = r6.w ? 1.000000 : 0;
    r15.xyz = r14.xyw;
    r15.w = r17.x;
    r14.xyw = r15.wyx;
    r14.xyzw = r14.xyzw + -r15.xyzw;
    r14.xyzw = r6.wwww * r14.xyzw + r15.xyzw;
    r6.w = min(r14.w, r14.y);
    r6.w = r14.x + -r6.w;
    r7.w = r14.w + -r14.y;
    r8.w = r6.w * 6 + 9.99999975e-05;
    r7.w = r7.w / r8.w;
    r7.w = r14.z + r7.w;
    r7.w = frac(abs(r7.w));
    r8.w = 9.99999975e-05 + r14.x;
    r6.w = r6.w / r8.w;
    r15.xyzw = float4(-0.5,1,0.666666687,0.333333343) + r7.wwww;
    r7.w = -0.449999988 + abs(r15.x);
    r7.w = saturate(-10.000001 * r7.w);
    r8.w = r7.w * -2 + 3;
    r7.w = r7.w * r7.w;
    r7.w = r8.w * r7.w;
    r7.w = r7.w * -0.349999994 + 0.699999988;
    r14.x = saturate(r14.x);
    r7.w = r14.x * r7.w;
    r6.w = min(r7.w, r6.w);
    r7.w = 2 + -r6.w;
    r7.w = 2 / r7.w;
    r14.xyz = frac(r15.yzw);
    r14.xyz = r14.xyz * float3(6,6,6) + float3(-3,-3,-3);
    r14.xyz = saturate(float3(-1,-1,-1) + abs(r14.xyz));
    r14.xyz = float3(-1,-1,-1) + r14.xyz;
    r14.xyz = r6.www * r14.xyz + float3(1,1,1);
    r14.xyz = r14.xyz * r7.www;
    r6.w = max(r13.x, r13.y);
    r6.w = max(r6.w, r13.z);
    r3.y = r6.w * r3.y;
    r6.w = 1;
  } else {
    r18.xyz = float3(0,0,0);
    r17.xyz = float3(1,1,1);
    r14.xyz = cb0[188].xyz;
    r6.w = 0;
  }
  // ===== 6. Detail / procedural overlay (noise + detail normal) =====
  r7.w = cb1[r2.w+12].z + -v2.y;
  r7.w = 0.200000003 + r7.w;
  r7.w = saturate(2.85714269 * r7.w);
  r8.w = r7.w * -2 + 3;
  r7.w = r7.w * r7.w;
  r7.w = r8.w * r7.w;
  r7.w = cb1[r2.w+12].y * r7.w;
  r7.w = max(cb1[r2.w+12].w, r7.w);
  r8.w = cb1[r2.w+12].x + r7.w;
  r8.w = cmp(0.00999999978 < r8.w);
  if (r8.w != 0) {
    r8.w = 1 + -r5.x;
    r13.xyz = r8.www * r4.xyz;
    r9.w = dot(r13.xyz, float3(0.212672904,0.715152204,0.0721750036));
    r9.w = -0.349999994 + r9.w;
    r9.w = saturate(-4 * r9.w);
    r10.w = r9.w * -2 + 3;
    r9.w = r9.w * r9.w;
    r11.w = r10.w * r9.w;
    r13.xyzw = float4(1,-1,1,1) * v8.xyxz;
    r13.xyzw = cb1[r2.w+4].wwww ? r13.xyzw : v8.xzxy;
    r15.xyzw = cb0[196].zzzz * r13.xyzw;
    r16.yz = cb1[r2.w+4].ww ? v7.zy : v7.yz;
    r16.x = v7.x;
    r19.xyz = float3(-0.200000003,-0.200000003,-0.200000003) + abs(r16.xyz);
    r20.xyz = r19.xyz * r19.xyz;
    r19.xyz = r20.xyz * r19.xyz;
    r19.xyz = max(float3(0,0,0), r19.xyz);
    r13.x = dot(r19.xyz, float3(1,1,1));
    r19.xyz = r19.xyz / r13.xxx;
    r21.xyzw = DetailNoise.SampleBias(sampBaseColor, r15.zy, cb0[108].x).xyzw;
    r22.xyzw = DetailNoise.SampleBias(sampBaseColor, r15.zw, cb0[108].x).xyzw;
    r22.xyzw = r22.xyzw * r19.zzzz;
    r21.xyzw = r21.xyzw * r19.yyyy + r22.xyzw;
    r22.xyzw = DetailNoise.SampleBias(sampBaseColor, r15.yw, cb0[108].x).xyzw;
    r19.xyzw = r22.xyzw * r19.xxxx + r21.xyzw;
    r16.yw = float2(0.800000012,0.449999988) + -r19.ww;
    r21.xyz = float3(0.200000003,0,1) * r10.yyx;
    r13.x = saturate(cb1[r2.w+12].x * r8.w + r21.x);
    r13.x = r13.x + -r16.y;
    r13.x = saturate(3.33333325 * r13.x);
    r14.w = r13.x * -2 + 3;
    r13.x = r13.x * r13.x;
    r13.x = r14.w * r13.x;
    r8.w = saturate(r8.w * r7.w);
    r8.w = r8.w + -r16.w;
    r8.w = saturate(1.53846145 * r8.w);
    r14.w = r8.w * -2 + 3;
    r8.w = r8.w * r8.w;
    r8.w = r14.w * r8.w;
    r8.w = max(r13.x, r8.w);
    r13.x = -0.5 + r5.x;
    r13.x = saturate(4 * r13.x);
    r14.w = r13.x * -2 + 3;
    r13.x = r13.x * r13.x;
    r13.x = r14.w * r13.x;
    r5.w = 0.199999988 + -r5.w;
    r5.w = saturate(-5.00000048 * r5.w);
    r14.w = r5.w * -2 + 3;
    r5.w = r5.w * r5.w;
    r5.w = r14.w * r5.w;
    r14.w = r5.w * r11.w + r13.x;
    r14.w = min(1, r14.w);
    r7.w = max(cb1[r2.w+12].x, r7.w);
    r16.yw = r19.xy * float2(2,2) + float2(-1,-1);
    r19.xyw = float3(20,20,20) * r15.yzw;
    r22.xyz = float3(34.3456001,34.3456001,34.3456001) * r15.yzw;
    r23.xyz = r20.xyz * r20.xyz;
    r23.xyz = r23.xyz * r23.xyz;
    r20.xyz = r23.xyz * r20.xyz;
    r17.w = dot(r20.xyz, float3(1,1,1));
    r20.xyz = r20.xyz / r17.www;
    r23.xyzw = floor(r19.yxyw);
    r24.xyzw = float4(123.339996,456.209991,123.339996,456.209991) * r23.xyzw;
    r24.xyzw = frac(r24.xyzw);
    r25.xyzw = float4(34.3450012,34.3450012,34.3450012,34.3450012) + r24.xyzw;
    r17.w = dot(r24.xy, r25.xy);
    r21.xw = r24.xy + r17.ww;
    r17.w = r21.x * r21.w;
    r18.w = r21.x + r21.w;
    r17.w = frac(r17.w);
    r26.w = frac(r18.w);
    r27.xyzw = float4(114.514,114.514,114.514,114.514) + r23.xyzw;
    r27.xyzw = float4(123.339996,456.209991,123.339996,456.209991) * r27.xyzw;
    r27.xyzw = frac(r27.xyzw);
    r28.xyzw = float4(34.3450012,34.3450012,34.3450012,34.3450012) + r27.xyzw;
    r18.w = dot(r27.xy, r28.xy);
    r21.xw = r27.xy + r18.ww;
    r18.w = r21.x * r21.w;
    r19.y = r21.x + r21.w;
    r24.x = frac(r18.w);
    r24.y = frac(r19.y);
    r18.w = r17.w * 0.399999976 + 0.600000024;
    r19.y = 0.25 * r18.w;
    r23.xyzw = r15.zyzw * float4(20,20,20,20) + -r23.xyzw;
    r21.xw = r24.xy * float2(2,2) + float2(-1,-1);
    r21.xw = r21.xw * float2(0.25,0.25) + r23.xy;
    r21.xw = float2(-0.5,-0.5) + r21.xw;
    r23.x = 1.25 * r21.x;
    r20.w = cmp(r21.w < 0);
    r20.w = r20.w ? 1.25 : 0.75;
    r23.y = r21.w * r20.w;
    r17.w = cb0[102].x * 3 + r17.w;
    r17.w = frac(r17.w);
    r21.xw = float2(-0.200000003,-0.850000024) + r17.ww;
    r21.xw = saturate(float2(50.0000114,-3.33333325) * r21.xw);
    r25.xy = r21.xw * float2(-2,-2) + float2(3,3);
    r21.xw = r21.xw * r21.xw;
    r21.xw = r25.xy * r21.xw;
    r17.w = r21.x * r21.w;
    r20.w = dot(r23.xy, r23.xy);
    r20.w = sqrt(r20.w);
    r18.w = -r18.w * 0.25 + r20.w;
    r20.w = 1 / -r19.y;
    r18.w = saturate(r20.w * r18.w);
    r20.w = r18.w * -2 + 3;
    r18.w = r18.w * r18.w;
    r18.w = r20.w * r18.w;
    r18.w = cmp(r18.w >= 0.00100000005);
    r18.w = r18.w ? 1.000000 : 0;
    r26.z = r18.w * r17.w;
    r21.xw = r23.xy / r19.yy;
    r21.xw = max(float2(-1,-1), r21.xw);
    r21.xw = min(float2(1,1), r21.xw);
    r17.w = cmp(r26.z >= 0.00100000005);
    r17.w = r17.w ? 1.000000 : 0;
    r21.xw = r21.xw * r17.ww;
    r17.w = r24.x * 0.25 + 0.25;
    r26.xy = r21.xw * r17.ww;
    r17.w = dot(r24.zw, r25.zw);
    r21.xw = r24.zw + r17.ww;
    r17.w = r21.x * r21.w;
    r18.w = r21.x + r21.w;
    r17.w = frac(r17.w);
    r24.w = frac(r18.w);
    r18.w = dot(r27.zw, r28.zw);
    r21.xw = r27.zw + r18.ww;
    r18.w = r21.x * r21.w;
    r19.y = r21.x + r21.w;
    r23.x = frac(r18.w);
    r23.y = frac(r19.y);
    r18.w = r17.w * 0.399999976 + 0.600000024;
    r19.y = 0.25 * r18.w;
    r21.xw = r23.xy * float2(2,2) + float2(-1,-1);
    r21.xw = r21.xw * float2(0.25,0.25) + r23.zw;
    r21.xw = float2(-0.5,-0.5) + r21.xw;
    r25.x = 1.25 * r21.x;
    r20.w = cmp(r21.w < 0);
    r20.w = r20.w ? 1.25 : 0.75;
    r25.y = r21.w * r20.w;
    r17.w = cb0[102].x * 3 + r17.w;
    r17.w = frac(r17.w);
    r21.xw = float2(-0.200000003,-0.850000024) + r17.ww;
    r21.xw = saturate(float2(50.0000114,-3.33333325) * r21.xw);
    r23.yz = r21.xw * float2(-2,-2) + float2(3,3);
    r21.xw = r21.xw * r21.xw;
    r21.xw = r23.yz * r21.xw;
    r17.w = r21.x * r21.w;
    r20.w = dot(r25.xy, r25.xy);
    r20.w = sqrt(r20.w);
    r18.w = -r18.w * 0.25 + r20.w;
    r20.w = 1 / -r19.y;
    r18.w = saturate(r20.w * r18.w);
    r20.w = r18.w * -2 + 3;
    r18.w = r18.w * r18.w;
    r18.w = r20.w * r18.w;
    r18.w = cmp(r18.w >= 0.00100000005);
    r18.w = r18.w ? 1.000000 : 0;
    r24.z = r18.w * r17.w;
    r21.xw = r25.xy / r19.yy;
    r21.xw = max(float2(-1,-1), r21.xw);
    r21.xw = min(float2(1,1), r21.xw);
    r17.w = cmp(r24.z >= 0.00100000005);
    r17.w = r17.w ? 1.000000 : 0;
    r21.xw = r21.xw * r17.ww;
    r17.w = r23.x * 0.25 + 0.25;
    r24.xy = r21.xw * r17.ww;
    r19.xy = floor(r19.xw);
    r21.xw = float2(123.339996,456.209991) * r19.xy;
    r21.xw = frac(r21.xw);
    r23.xy = float2(34.3450012,34.3450012) + r21.xw;
    r17.w = dot(r21.xw, r23.xy);
    r21.xw = r21.xw + r17.ww;
    r17.w = r21.x * r21.w;
    r18.w = r21.x + r21.w;
    r17.w = frac(r17.w);
    r23.w = frac(r18.w);
    r21.xw = float2(114.514,114.514) + r19.xy;
    r21.xw = float2(123.339996,456.209991) * r21.xw;
    r21.xw = frac(r21.xw);
    r25.xy = float2(34.3450012,34.3450012) + r21.xw;
    r18.w = dot(r21.xw, r25.xy);
    r21.xw = r21.xw + r18.ww;
    r18.w = r21.x * r21.w;
    r19.w = r21.x + r21.w;
    r25.x = frac(r18.w);
    r25.y = frac(r19.w);
    r18.w = r17.w * 0.399999976 + 0.600000024;
    r19.w = 0.25 * r18.w;
    r19.xy = r15.yw * float2(20,20) + -r19.xy;
    r21.xw = r25.xy * float2(2,2) + float2(-1,-1);
    r19.xy = r21.xw * float2(0.25,0.25) + r19.xy;
    r19.xy = float2(-0.5,-0.5) + r19.xy;
    r27.x = 1.25 * r19.x;
    r19.x = cmp(r19.y < 0);
    r19.x = r19.x ? 1.25 : 0.75;
    r27.y = r19.y * r19.x;
    r17.w = cb0[102].x * 3 + r17.w;
    r17.w = frac(r17.w);
    r19.xy = float2(-0.200000003,-0.850000024) + r17.ww;
    r19.xy = saturate(float2(50.0000114,-3.33333325) * r19.xy);
    r21.xw = r19.xy * float2(-2,-2) + float2(3,3);
    r19.xy = r19.xy * r19.xy;
    r19.xy = r21.xw * r19.xy;
    r17.w = r19.x * r19.y;
    r19.x = dot(r27.xy, r27.xy);
    r19.x = sqrt(r19.x);
    r18.w = -r18.w * 0.25 + r19.x;
    r19.x = 1 / -r19.w;
    r18.w = saturate(r19.x * r18.w);
    r19.x = r18.w * -2 + 3;
    r18.w = r18.w * r18.w;
    r18.w = r19.x * r18.w;
    r18.w = cmp(r18.w >= 0.00100000005);
    r18.w = r18.w ? 1.000000 : 0;
    r23.z = r18.w * r17.w;
    r19.xy = r27.xy / r19.ww;
    r19.xy = max(float2(-1,-1), r19.xy);
    r19.xy = min(float2(1,1), r19.xy);
    r17.w = cmp(r23.z >= 0.00100000005);
    r17.w = r17.w ? 1.000000 : 0;
    r19.xy = r19.xy * r17.ww;
    r17.w = r25.x * 0.25 + 0.25;
    r23.xy = r19.xy * r17.ww;
    r24.xyzw = r24.xyzw * r20.zzzz;
    r24.xyzw = r26.xyzw * r20.yyyy + r24.xyzw;
    r23.xyzw = r23.xyzw * r20.xxxx + r24.xyzw;
    r24.xyzw = floor(r22.yxyz);
    r25.xyzw = float4(123.339996,456.209991,123.339996,456.209991) * r24.xyzw;
    r25.xyzw = frac(r25.xyzw);
    r26.xyzw = float4(34.3450012,34.3450012,34.3450012,34.3450012) + r25.xyzw;
    r17.w = dot(r25.xy, r26.xy);
    r19.xy = r25.xy + r17.ww;
    r17.w = r19.x * r19.y;
    r18.w = r19.x + r19.y;
    r17.w = frac(r17.w);
    r27.w = frac(r18.w);
    r28.xyzw = float4(114.514,114.514,114.514,114.514) + r24.xyzw;
    r28.xyzw = float4(123.339996,456.209991,123.339996,456.209991) * r28.xyzw;
    r28.xyzw = frac(r28.xyzw);
    r29.xyzw = float4(34.3450012,34.3450012,34.3450012,34.3450012) + r28.xyzw;
    r18.w = dot(r28.xy, r29.xy);
    r19.xy = r28.xy + r18.ww;
    r18.w = r19.x * r19.y;
    r19.x = r19.x + r19.y;
    r25.x = frac(r18.w);
    r25.y = frac(r19.x);
    r18.w = r17.w * 0.399999976 + 0.600000024;
    r19.x = 0.25 * r18.w;
    r24.xyzw = r15.xyzw * float4(34.3456001,34.3456001,34.3456001,34.3456001) + -r24.xyzw;
    r19.yw = r25.xy * float2(2,2) + float2(-1,-1);
    r19.yw = r19.yw * float2(0.25,0.25) + r24.xy;
    r19.yw = float2(-0.5,-0.5) + r19.yw;
    r24.x = 1.25 * r19.y;
    r15.x = cmp(r19.w < 0);
    r15.x = r15.x ? 1.25 : 0.75;
    r24.y = r19.w * r15.x;
    r15.x = cb0[102].x * 4.34560013 + r17.w;
    r15.x = frac(r15.x);
    r19.yw = float2(-0.200000003,-0.850000024) + r15.xx;
    r19.yw = saturate(float2(50.0000114,-3.33333325) * r19.yw);
    r21.xw = r19.yw * float2(-2,-2) + float2(3,3);
    r19.yw = r19.yw * r19.yw;
    r19.yw = r21.xw * r19.yw;
    r15.x = r19.y * r19.w;
    r17.w = dot(r24.xy, r24.xy);
    r17.w = sqrt(r17.w);
    r17.w = -r18.w * 0.25 + r17.w;
    r18.w = 1 / -r19.x;
    r17.w = saturate(r18.w * r17.w);
    r18.w = r17.w * -2 + 3;
    r17.w = r17.w * r17.w;
    r17.w = r18.w * r17.w;
    r17.w = cmp(r17.w >= 0.00100000005);
    r17.w = r17.w ? 1.000000 : 0;
    r27.z = r17.w * r15.x;
    r19.xy = r24.xy / r19.xx;
    r19.xy = max(float2(-1,-1), r19.xy);
    r19.xy = min(float2(1,1), r19.xy);
    r15.x = cmp(r27.z >= 0.00100000005);
    r15.x = r15.x ? 1.000000 : 0;
    r19.xy = r19.xy * r15.xx;
    r15.x = r25.x * 0.25 + 0.25;
    r27.xy = r19.xy * r15.xx;
    r15.x = dot(r25.zw, r26.zw);
    r19.xy = r25.zw + r15.xx;
    r15.x = r19.x * r19.y;
    r17.w = r19.x + r19.y;
    r15.x = frac(r15.x);
    r25.w = frac(r17.w);
    r17.w = dot(r28.zw, r29.zw);
    r19.xy = r28.zw + r17.ww;
    r17.w = r19.x * r19.y;
    r18.w = r19.x + r19.y;
    r19.x = frac(r17.w);
    r19.y = frac(r18.w);
    r17.w = r15.x * 0.399999976 + 0.600000024;
    r18.w = 0.25 * r17.w;
    r19.yw = r19.xy * float2(2,2) + float2(-1,-1);
    r19.yw = r19.yw * float2(0.25,0.25) + r24.zw;
    r19.yw = float2(-0.5,-0.5) + r19.yw;
    r24.x = 1.25 * r19.y;
    r19.y = cmp(r19.w < 0);
    r19.y = r19.y ? 1.25 : 0.75;
    r24.y = r19.w * r19.y;
    r15.x = cb0[102].x * 4.34560013 + r15.x;
    r15.x = frac(r15.x);
    r19.yw = float2(-0.200000003,-0.850000024) + r15.xx;
    r19.yw = saturate(float2(50.0000114,-3.33333325) * r19.yw);
    r21.xw = r19.yw * float2(-2,-2) + float2(3,3);
    r19.yw = r19.yw * r19.yw;
    r19.yw = r21.xw * r19.yw;
    r15.x = r19.y * r19.w;
    r19.y = dot(r24.xy, r24.xy);
    r19.y = sqrt(r19.y);
    r17.w = -r17.w * 0.25 + r19.y;
    r19.y = 1 / -r18.w;
    r17.w = saturate(r19.y * r17.w);
    r19.y = r17.w * -2 + 3;
    r17.w = r17.w * r17.w;
    r17.w = r19.y * r17.w;
    r17.w = cmp(r17.w >= 0.00100000005);
    r17.w = r17.w ? 1.000000 : 0;
    r25.z = r17.w * r15.x;
    r19.yw = r24.xy / r18.ww;
    r19.yw = max(float2(-1,-1), r19.yw);
    r19.yw = min(float2(1,1), r19.yw);
    r15.x = cmp(r25.z >= 0.00100000005);
    r15.x = r15.x ? 1.000000 : 0;
    r19.yw = r19.yw * r15.xx;
    r15.x = r19.x * 0.25 + 0.25;
    r25.xy = r19.yw * r15.xx;
    r19.xy = floor(r22.xz);
    r21.xw = float2(123.339996,456.209991) * r19.xy;
    r21.xw = frac(r21.xw);
    r22.xy = float2(34.3450012,34.3450012) + r21.xw;
    r15.x = dot(r21.xw, r22.xy);
    r21.xw = r21.xw + r15.xx;
    r15.x = r21.x * r21.w;
    r17.w = r21.x + r21.w;
    r15.x = frac(r15.x);
    r22.w = frac(r17.w);
    r21.xw = float2(114.514,114.514) + r19.xy;
    r21.xw = float2(123.339996,456.209991) * r21.xw;
    r21.xw = frac(r21.xw);
    r24.xy = float2(34.3450012,34.3450012) + r21.xw;
    r17.w = dot(r21.xw, r24.xy);
    r21.xw = r21.xw + r17.ww;
    r17.w = r21.x * r21.w;
    r18.w = r21.x + r21.w;
    r24.x = frac(r17.w);
    r24.y = frac(r18.w);
    r17.w = r15.x * 0.399999976 + 0.600000024;
    r18.w = 0.25 * r17.w;
    r19.xy = r15.yw * float2(34.3456001,34.3456001) + -r19.xy;
    r21.xw = r24.xy * float2(2,2) + float2(-1,-1);
    r19.xy = r21.xw * float2(0.25,0.25) + r19.xy;
    r19.xy = float2(-0.5,-0.5) + r19.xy;
    r26.x = 1.25 * r19.x;
    r19.x = cmp(r19.y < 0);
    r19.x = r19.x ? 1.25 : 0.75;
    r26.y = r19.y * r19.x;
    r15.x = cb0[102].x * 4.34560013 + r15.x;
    r15.x = frac(r15.x);
    r19.xy = float2(-0.200000003,-0.850000024) + r15.xx;
    r19.xy = saturate(float2(50.0000114,-3.33333325) * r19.xy);
    r21.xw = r19.xy * float2(-2,-2) + float2(3,3);
    r19.xy = r19.xy * r19.xy;
    r19.xy = r21.xw * r19.xy;
    r15.x = r19.x * r19.y;
    r19.x = dot(r26.xy, r26.xy);
    r19.x = sqrt(r19.x);
    r17.w = -r17.w * 0.25 + r19.x;
    r19.x = 1 / -r18.w;
    r17.w = saturate(r19.x * r17.w);
    r19.x = r17.w * -2 + 3;
    r17.w = r17.w * r17.w;
    r17.w = r19.x * r17.w;
    r17.w = cmp(r17.w >= 0.00100000005);
    r17.w = r17.w ? 1.000000 : 0;
    r22.z = r17.w * r15.x;
    r19.xy = r26.xy / r18.ww;
    r19.xy = max(float2(-1,-1), r19.xy);
    r19.xy = min(float2(1,1), r19.xy);
    r15.x = cmp(r22.z >= 0.00100000005);
    r15.x = r15.x ? 1.000000 : 0;
    r19.xy = r19.xy * r15.xx;
    r15.x = r24.x * 0.25 + 0.25;
    r22.xy = r19.xy * r15.xx;
    r24.xyzw = r25.xyzw * r20.zzzz;
    r24.xyzw = r27.xyzw * r20.yyyy + r24.xyzw;
    r20.xyzw = r22.xyzw * r20.xxxx + r24.xyzw;
    r19.xy = max(r23.zw, r20.zw);
    r20.zw = -r14.ww * r7.ww + float2(1,1.00999999);
    r15.x = -0.100000001 + r19.y;
    r15.x = cmp(r15.x >= r20.z);
    r15.x = r15.x ? 1.000000 : 0;
    r15.x = r19.x * r15.x;
    r2.w = cmp(cb1[r2.w+12].x >= 0.00999999978);
    r2.w = r2.w ? 1.000000 : 0;
    r2.w = r15.x * r2.w;
    r15.x = cmp(0.00100000005 < r2.w);
    r19.xy = r23.xy + r20.xy;
    r17.w = cb0[196].z * cb0[102].x;
    r20.y = 0.75 * r17.w;
    r17.w = dot(r16.xz, r16.xz);
    r17.w = max(1.17549435e-38, r17.w);
    r17.w = rsqrt(r17.w);
    r16.xz = r17.ww * r16.xz;
    r16.xz = float2(-0.200000003,-0.200000003) + abs(r16.xz);
    r21.xw = r16.xz * r16.xz;
    r16.xz = r21.xw * r16.xz;
    r16.xz = max(float2(0,0), r16.xz);
    r17.w = dot(r16.xz, float2(1,1));
    r16.xz = r16.xz / r17.ww;
    r22.xyz = DetailNormal.SampleBias(sampBaseColor, r15.zw, cb0[108].x).xyz;
    r15.yzw = DetailNormal.SampleBias(sampBaseColor, r15.yw, cb0[108].x).xyz;
    r15.yzw = r15.yzw * r16.xxx;
    r15.yzw = r22.xyz * r16.zzz + r15.yzw;
    r16.yw = r15.xx ? r19.xy : r16.yw;
    r15.xy = r15.yz * float2(2,2) + float2(-1,-1);
    r20.x = 0;
    r22.xyzw = r13.zwyw * cb0[196].zzzz + r20.xyxy;
    r13.y = DetailNormal.SampleBias(sampBaseColor, r22.xy, cb0[108].x).w;
    r13.z = DetailNormal.SampleBias(sampBaseColor, r22.zw, cb0[108].x).w;
    r13.z = r13.z * r16.x;
    r13.y = r13.y * r16.z + r13.z;
    r13.yz = r15.xy * r13.yy + r16.yw;
    r13.w = cmp(r19.z >= r20.w);
    r13.w = r13.w ? 1.000000 : 0;
    r2.w = max(r13.w, r2.w);
    r13.w = 1 + -r15.w;
    r7.w = r14.w * r7.w + -r13.w;
    r7.w = saturate(9.99999809 * r7.w);
    r13.w = r7.w * -2 + 3;
    r7.w = r7.w * r7.w;
    r7.w = r13.w * r7.w;
    r2.w = max(r7.w, r2.w);
    r15.xy = -r10.zy * float2(1,0) + r21.yz;
    r7.w = dot(r15.xy, r15.xy);
    r13.w = cmp(6.10351562e-05 < r7.w);
    r7.w = rsqrt(r7.w);
    r15.xy = r15.xy * r7.ww;
    r15.xy = -r15.xy;
    r16.z = r13.w ? r15.x : -1;
    r16.y = r13.w ? r15.y : 0;
    r7.w = min(0.0500000007, r3.z);
    r13.w = r7.w + -r3.z;
    r13.w = r2.w * r13.w + r3.z;
    r9.w = -r10.w * r9.w + 1;
    r9.w = r9.w * r8.w;
    r5.w = -r5.w * r11.w + 1;
    r5.w = r9.w * r5.w;
    r5.w = r5.w * -0.5 + 1;
    r16.x = 0;
    r7.xyz = -r7.xyz * r3.xxx + r16.zxy;
    r7.xyz = r13.yyy * r7.xyz + r10.xyz;
    r15.xyz = r16.xyz * r10.zxy;
    r15.xyz = r10.yzx * r16.yzx + -r15.xyz;
    r15.xyz = r15.xyz + -r7.xyz;
    r7.xyz = r13.zzz * r15.xyz + r7.xyz;
    r3.x = dot(r7.xyz, r7.xyz);
    r3.x = rsqrt(r3.x);
    r7.xyz = r7.xyz * r3.xxx + -r10.xyz;
    r7.xyz = r2.www * r7.xyz + r10.xyz;
    r3.x = dot(r7.xyz, r7.xyz);
    r3.x = rsqrt(r3.x);
    r7.xyz = r7.xyz * r3.xxx;
    r3.x = r8.w * r11.w;
    r3.x = -r3.x * 0.200000003 + r13.w;
    r8.w = min(0.200000003, r13.w);
    r3.z = max(r8.w, r3.x);
    r6.xyz = r6.xyz * r5.www;
    r3.x = dot(r4.xyz, float3(0.212672904,0.715152204,0.0721750036));
    r3.x = -0.699999988 + r3.x;
    r3.x = saturate(-2.50000024 * r3.x);
    r8.w = r3.x * -2 + 3;
    r3.x = r3.x * r3.x;
    r3.x = r8.w * r3.x;
    r3.x = r3.x * 0.5 + 1;
    r8.w = r2.w * r13.x;
    r13.xyz = r4.xyz * r3.xxx + -r4.xyz;
    r13.xyz = r8.www * r13.xyz + r4.xyz;
    r4.xyz = r13.xyz * r5.www;
  } else {
    r7.xyz = r10.xyz;
    r7.w = 0.00999999978;
    r2.w = 0;
  }
  // ===== 7. Diffuse / specular F0 split + motion vectors (o1) =====
  r3.x = 0.0399999991 * r5.y;
  r5.w = -r5.x * 0.959999979 + 0.959999979;
  r13.xyz = r5.www * r4.xyz;
  r15.xyz = -r5.yyy * float3(0.0399999991,0.0399999991,0.0399999991) + r4.xyz;
  r15.xyz = r5.xxx * r15.xyz + r3.xxx;
  r6.xyz = r6.xyz * r5.www;
  r3.x = r3.z * r3.z;
  r3.x = max(0.0078125, r3.x);
  r5.y = r3.x * r3.x;
  r8.w = max(9.99999994e-09, v5.z);
  r16.xy = v5.xy / r8.ww;
  r8.w = max(9.99999994e-09, v6.z);
  r16.zw = v6.xy / r8.ww;
  r16.xy = r16.xy + -r16.zw;
  r19.xy = float2(0.5,-0.5) * r16.xy;
  r19.xy = sqrt(abs(r19.xy));
  r19.xy = sqrt(r19.xy);
  r16.z = -r16.y;
  r16.yw = cmp(float2(0,0) < r16.xz);
  r16.xz = cmp(r16.xz < float2(0,0));
  r16.xy = (int2)-r16.yw + (int2)r16.xz;
  r16.xy = (int2)r16.xy;
  r16.xy = r19.xy * r16.xy;
  o1.xy = r16.xy * float2(0.5,0.5) + float2(0.5,0.5);
  r8.w = cmp(0.5 < r2.w);
  o1.w = r8.w ? 0.699999988 : 0.400000006;
  // ===== 8. Main lighting: sun / LUT / IBL prep =====
  r16.xyz = cb3[0].xyz + cb0[197].xyz;
  r16.xyz = cb0[187].www * r16.xyz + -cb3[0].xyz;
  r16.w = 6.10351562e-05;
  r8.w = dot(r16.xzw, r16.xzw);
  r8.w = rsqrt(r8.w);
  r19.xyz = r16.xwz * r8.www;
  r20.xyz = -cb3[3].xyz + cb0[191].xyz;
  r20.xyz = cb0[198].yyy * r20.xyz + cb3[3].xyz;
  r8.w = -cb3[3].w + 1;
  r8.w = cb0[198].w * r8.w + cb3[3].w;
  r21.xyz = r20.xyz * r8.www;
  r12.z = 0;
  r22.xy = ScreenData.Load(r12.xyz).xy;
  r9.w = -1 + r22.x;
  r9.w = cb4[34].x * r9.w + 1;
  r10.w = 1 + -r9.w;
  r9.w = cb0[187].z * r10.w + r9.w;
  r10.w = dot(r10.xyz, r16.xyz);
  r22.xzw = cb0[186].zzz * r6.xyz;
  r23.xyz = float3(0.649999976,0.649999976,0.649999976) * r22.xzw;
  r11.w = dot(r13.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r12.z = dot(cb0[6].xz, cb0[6].xz);
  r12.z = rsqrt(r12.z);
  r24.xy = cb0[6].xz * r12.zz;
  r12.z = dot(r19.xz, r24.xy);
  r12.z = saturate(-r12.z);
  r24.xy = -cb0[198].xy + float2(1,1);
  r13.w = r10.w * 0.5 + -1;
  r13.w = -r10.w * r13.w + -r10.w;
  r14.w = -abs(cb0[6].y) + 0.75;
  r14.w = saturate(r14.w + r14.w);
  r15.w = r14.w * -2 + 3;
  r14.w = r14.w * r14.w;
  r14.w = r15.w * r14.w;
  r14.w = r14.w * r12.z;
  r14.w = r14.w * r24.x;
  r13.w = 0.5 + r13.w;
  r10.w = r14.w * r13.w + r10.w;
  r10.w = cb0[197].w * cb0[198].x + r10.w;
  r10.w = max(-1, r10.w);
  r10.w = min(1, r10.w);
  r25.x = r10.w * 0.5 + 0.5;
  r25.yw = float2(0.5,0.5);
  r26.xyzw = LightingLUT.SampleLevel(sampLinear, r25.xy, 0).xyzw;
  r10.w = max(r26.x, r26.y);
  r10.w = max(r10.w, r26.z);
  r13.w = min(r26.x, r26.y);
  r13.w = min(r13.w, r26.z);
  r10.w = -r13.w + r10.w;
  r13.w = dot(r10.xyz, cb0[6].xyz);
  r25.z = r13.w * 0.5 + 0.5;
  r13.w = LightingLUT.SampleLevel(sampLinear, r25.zw, 0).w;
  r14.w = r22.y * r5.z;
  r15.w = min(r22.y, r5.z);
  r16.w = min(r15.w, r26.w);
  r17.w = r14.w * r13.w;
  r18.w = dot(r10.xyz, cb0[192].xyz);
  r18.w = saturate(cb0[193].x + r18.w);
  r18.w = r18.w * cb0[193].y + cb0[193].z;
  r19.w = cb0[187].y * r16.w;
  r25.xyz = float3(1,1,1) + -r14.xyz;
  r25.xyz = r19.www * r25.xyz + r14.xyz;
  r25.xyz = r25.xyz * r18.www;
  r18.w = r3.y * 0.350000024 + 0.649999976;
  r18.w = min(1.5, r18.w);
  r27.xyz = max(float3(1.25,0,0.5), r3.yyy);
  r27.xyz = min(float3(1.75,1.5,1.5), r27.xyz);
  r3.y = r27.x + -r18.w;
  r3.y = cb0[187].x * r3.y + r18.w;
  r28.xyz = r25.xyz * r3.yyy;
  r28.xyz = cb0[186].www * r28.xyz;
  r3.y = dot(r21.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r21.xyz = r20.xyz * r8.www + -r3.yyy;
  r21.xyz = r16.www * r21.xyz + r3.yyy;
  r25.xyz = r27.yyy * r25.xyz;
  r24.yzw = r20.xyz * cb0[198].yyy + r24.yyy;
  r21.xyz = r25.xyz * r24.yzw + r21.xyz;
  r21.xyz = r21.xyz * cb0[186].yyy + -r28.xyz;
  r21.xyz = r9.www * r21.xyz + r28.xyz;
  r3.y = dot(r23.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r23.xyz = r22.xzw * float3(0.649999976,0.649999976,0.649999976) + -r3.yyy;
  r23.xyz = r23.xyz * float3(1.20000005,1.20000005,1.20000005) + r3.yyy;
  r3.y = saturate(r13.w * r14.w + r26.w);
  r24.yzw = r6.xyz * cb0[186].zzz + -r23.xyz;
  r23.xyz = r3.yyy * r24.yzw + r23.xyz;
  r24.yzw = r4.xyz * r5.www + -r23.xyz;
  r23.xyz = r16.www * r24.yzw + r23.xyz;
  r3.y = 1 + -r10.w;
  r24.yzw = r26.xyz * r10.www + r3.yyy;
  r24.yzw = r24.yzw * r23.xyz;
  r25.xyz = r4.xyz * r5.www + -r11.www;
  r25.xyz = r25.xyz * float3(1.20000005,1.20000005,1.20000005) + r11.www;
  r25.xyz = -r6.xyz * cb0[186].zzz + r25.xyz;
  r22.xzw = r17.www * r25.xyz + r22.xzw;
  r3.y = dot(r23.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r10.w = dot(r24.yzw, float3(0.212672904,0.715152204,0.0721750036));
  r10.w = max(0.00100000005, r10.w);
  r10.w = 1 / r10.w;
  r3.y = r10.w * r3.y;
  r3.y = max(0, r3.y);
  r3.y = min(1.5, r3.y);
  r23.xyz = r24.yzw * r3.yyy + -r22.xzw;
  r22.xzw = r9.www * r23.xyz + r22.xzw;
  r3.y = -r13.w * r14.w + r16.w;
  r3.y = r9.w * r3.y + r17.w;
  r10.w = -cb0[186].z + 1;
  r10.w = r3.y * r10.w + cb0[186].z;
  r13.w = -0.5 + r16.y;
  r23.y = r9.w * r13.w + 0.5;
  r25.x = saturate(dot(r7.xyz, r2.xyz));
  r23.xz = cb0[6].xz;
  r13.w = dot(r23.xyz, r23.xyz);
  r13.w = max(1.17549435e-38, r13.w);
  r13.w = rsqrt(r13.w);
  r23.xyz = r23.xyz * r13.www;
  r23.xyz = r23.xyz + r23.xyz;
  r16.xyz = r16.xyz * r9.www + r23.xyz;
  r13.w = 2 + r9.w;
  r16.xyz = r2.xyz * r13.www + r16.xyz;
  r13.w = dot(r16.xyz, r16.xyz);
  r13.w = rsqrt(r13.w);
  r16.xyz = r16.xyz * r13.www;
  r13.w = dot(r7.xyz, r16.xyz);
  r14.w = r13.w * r5.y + -r13.w;
  r13.w = r14.w * r13.w + 1;
  r13.w = r13.w * r13.w;
  r14.w = cmp(r5.y != r13.w);
  r5.y = r5.y / r13.w;
  r5.y = r14.w ? r5.y : 1;
  r16.x = r25.x * r25.x;
  r13.w = r3.x * r3.x + 9.99999975e-05;
  r13.w = 1 / r13.w;
  r13.w = r5.y / r13.w;
  r14.w = r25.x * r25.x + -r13.w;
  r23.x = cb5[1].x * r14.w + r13.w;
  r23.y = r3.z * r3.w;
  r23.xyz = SpecularBRDFLUT.SampleLevel(sampLinear, r23.xy, 0).xyz;
  r24.yzw = r23.xyz * r15.xyz;
  r23.xyz = r15.xyz * r23.xyz + -r15.xyz;
  r15.xyz = cb5[1].xxx * r23.xyz + r15.xyz;
  r3.w = -cb5[1].z + 1;
  r3.w = r4.w * cb5[1].z + r3.w;
  r23.xyz = r22.xzw * r21.xyz;
  r13.w = r25.x * 2 + r3.x;
  r13.w = 9.99999975e-05 + r13.w;
  r13.w = 0.5 / r13.w;
  r5.y = r5.y * r13.w + -6.10351562e-05;
  r5.y = max(0, r5.y);
  r5.y = min(20, r5.y);
  r26.xyz = r24.yzw * r5.yyy;
  r3.y = r3.y * 0.5 + 0.5;
  r3.y = r3.y * r10.w;
  r21.xyz = r21.xyz * r3.yyy;
  r21.xyz = r26.xyz * r21.xyz;
  r21.xyz = cb0[199].www * r21.xyz;
  r21.xyz = r23.xyz * r3.www + r21.xyz;
  r3.y = dot(r21.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r5.y = -0.5 + r3.y;
  r5.y = max(0, r5.y);
  r5.y = min(0.5, r5.y);
  r23.y = 0;
  r23.xz = cb0[195].yx;
  r26.xyz = cb0[6].zxy * r23.xyz;
  r23.xyz = cb0[6].yzx * r23.yzx + -r26.xyz;
  r13.w = dot(r23.xyz, r23.xyz);
  r13.w = rsqrt(r13.w);
  r23.xyz = r23.xyz * r13.www;
  r13.w = dot(r2.xyz, r10.xyz);
  r26.xy = float2(1,0.399999976) + -abs(r13.ww);
  r14.w = dot(r19.xyz, r10.xyz);
  r17.w = 1 + -r9.w;
  r7.w = r7.w + -r3.z;
  r2.w = r2.w * r7.w + r3.z;
  r19.y = r2.w * r2.w;
  r16.z = r16.x * r25.x;
  r7.w = r19.y * r19.y;
  r19.z = r7.w * r19.y;
  r25.yzw = float3(0.0365463011,9.0632,0.990440011);
  r27.x = dot(float2(3.32707,1), r25.xy);
  r27.y = dot(float2(-9.04755974,1), r25.xz);
  r19.x = 1;
  r7.w = dot(r27.xy, r19.xy);
  r16.yw = float2(9.04401016,1);
  r28.x = dot(float3(3.59684992,-1.36772001,1), r16.xzw);
  r28.y = dot(float3(-16.3174,1,9.22949028), r16.xyz);
  r29.x = 5.56588984;
  r29.yz = r16.xz;
  r28.z = dot(float3(1,19.7886009,-20.2122993), r29.xyz);
  r18.w = dot(r28.xyz, r19.xyz);
  r7.w = r7.w / r18.w;
  r27.x = dot(float2(-1.28514004,1), r25.xw);
  r16.x = 1.29677999;
  r16.y = r25.x;
  r27.y = dot(float2(1,-0.755906999), r16.xy);
  r18.w = dot(r27.xy, r19.xy);
  r28.x = dot(float3(2.9233799,59.4188004,1), r16.yzw);
  r16.xw = float2(20.3225002,121.563004);
  r28.y = dot(float3(1,-27.0301991,222.591995), r16.xyz);
  r28.z = dot(float3(626.130005,316.627014,1), r16.yzw);
  r16.x = dot(r28.xyz, r19.xyz);
  r16.x = r18.w / r16.x;
  r16.yzw = r15.xyz * r7.www + r16.xxx;
  r7.w = r16.x + r7.w;
  r5.y = r5.y * r5.y + 1;
  r19.xyz = r21.xyz + -r3.yyy;
  r19.xyz = r5.yyy * r19.xyz + r3.yyy;
  r21.xy = cb0[195].ww * float2(-0.600000024,-0.399999976) + float2(0.800000012,0.899999976);
  r3.y = r21.y + -r21.x;
  r5.y = r26.x + -r21.x;
  r3.y = 1 / r3.y;
  r3.y = saturate(r5.y * r3.y);
  r5.y = r3.y * -2 + 3;
  r3.y = r3.y * r3.y;
  r3.y = r5.y * r3.y;
  r21.xyz = cb0[194].xyz * r3.yyy;
  r21.xyz = cb0[194].www * r21.xyz;
  r3.y = dot(r9.xyz, r23.xyz);
  r3.y = saturate(1 + r3.y);
  r3.y = min(r3.y, r5.z);
  r3.y = min(r3.y, r22.y);
  r21.xyz = r21.xyz * r3.yyy;
  r25.yzw = r4.xyz * r5.www + float3(-0.25,-0.25,-0.25);
  r25.yzw = cb0[195].zzz * r25.yzw + float3(0.25,0.25,0.25);
  r3.y = saturate(dot(r23.xyz, r10.xyz));
  r23.xyz = r25.yzw * r3.yyy;
  r3.y = max(r17.x, r17.y);
  r3.y = max(r3.y, r17.z);
  r3.y = 0.5 * r3.y;
  r3.y = max(1, r3.y);
  r3.y = 1 / r3.y;
  r17.xyz = r17.xyz * r3.yyy;
  r20.xyz = r20.xyz * r8.www + -r17.xyz;
  r17.xyz = r9.www * r20.xyz + r17.xyz;
  r3.y = dot(r18.xyz, r10.xyz);
  r5.y = r3.y * r6.w;
  r5.z = r14.w * 0.5 + -1;
  r5.z = -r14.w * r5.z + 0.5;
  r3.y = -r3.y * r6.w + r5.z;
  r3.y = saturate(r9.w * r3.y + r5.y);
  r17.xyz = r17.xyz * r3.yyy;
  r3.y = r12.z * r9.w + r17.w;
  r3.y = r3.y * r24.x;
  r17.xyz = r17.xyz * r3.yyy;
  r3.y = saturate(5.00000048 * r26.y);
  r5.y = r3.y * -2 + 3;
  r3.y = r3.y * r3.y;
  r3.y = r5.y * r3.y;
  r17.xyz = r17.xyz * r3.yyy;
  r17.xyz = r17.xyz * r15.www;
  r3.y = -0.100000001 + r11.w;
  r3.y = saturate(-16.666666 * r3.y);
  r5.y = r3.y * -2 + 3;
  r3.y = r3.y * r3.y;
  r3.y = r5.y * r3.y;
  r3.y = r3.y * r9.w + r17.w;
  r17.xyz = r17.xyz * r3.yyy;
  r18.xyz = max(float3(0.150000006,0.150000006,0.150000006), r13.xyz);
  r17.xyz = r18.xyz * r17.xyz;
  r17.xyz = r21.xyz * r23.xyz + r17.xyz;
  r17.xyz = r19.xyz + r17.xyz;
  r5.yz = (uint2)r12.xy;
  r18.xy = float2(0.03125,0.03125) * r5.yz;
  r18.xy = floor(r18.xy);
  r3.y = r18.y * cb2[1].y + r18.x;
  r3.y = 8 * r3.y;
  r3.y = (int)r3.y;
  r6.w = -cb0[85].y * cb2[2].w + v0.w;
  r6.w = floor(r6.w);
  r8.w = cb2[1].w + -1;
  r9.w = max(0, r6.w);
  r8.w = min(r9.w, r8.w);
  r9.w = 8 * r8.w;
  r9.w = (int)r9.w;
  // ===== 9. Emissive + reflection cube =====
  r8.xyz = cb5[6].xyz * r8.xyz;
  r8.xyz = cb5[1].www * r8.xyz;
  r8.xyz = r8.xyz * r3.www + r17.xyz;
  r11.w = dot(-r2.xyz, r7.xyz);
  r11.w = r11.w + r11.w;
  r17.xyz = r7.xyz * -r11.www + -r2.xyz;
  r2.w = max(0.00100000005, r2.w);
  r2.w = log2(r2.w);
  r2.w = r2.w * 1.20000005 + 5;
  r17.xyz = ReflectionCube.SampleLevel(sampLinear, r17.xyz, r2.w).xyz;
  r2.w = 1 + -r7.w;
  r2.w = r2.w / r7.w;
  r15.xyz = r15.xyz * r2.www;
  r15.xyz = r15.xyz * r16.yzw + r16.yzw;
  r15.xyz = r17.xyz * r15.xyz;
  r2.w = cb0[186].w * r27.z;
  r2.w = r2.w * r10.w;
  r15.xyz = r15.xyz * r2.www;
  r8.xyz = r15.xyz * r14.xyz + r8.xyz;
  r2.w = cmp(r8.w >= r6.w);
  r6.w = (int)r9.w + asint(cb0[110].y);
  r7.w = r17.w * -0.25 + 0.75;
  r4.xyz = r4.xyz * r5.www + float3(-0.5,-0.5,-0.5);
  r5.w = 0.00999999978 + -r3.x;
  r5.x = cmp(r5.x >= 0.5);
  r5.x = r5.x ? 1.000000 : 0;
  // ===== 10. Clustered / tiled local lights loop =====
  r14.w = 1;
  r15.xyz = r8.xyz;
  r8.w = 0;
  while (true) {
    r9.w = cmp(7 < (int)r8.w);
    if (r9.w != 0) break;
    r9.w = (int)r3.y + (int)r8.w;
    r9.w = LightTileMaskSB[r9.w].val[0/4];
    r10.w = (int)r6.w + (int)r8.w;
    r10.w = LightTileMaskSB[r10.w].val[0/4];
    r9.w = (int)r9.w & (int)r10.w;
    r9.w = r2.w ? r9.w : 0;
    r10.w = (uint)r8.w << 5;
    r16.xyz = r15.xyz;
    r11.w = r9.w;
    while (true) {
      if (r11.w == 0) break;
      r12.z = firstbitlow((uint)r11.w);
      r15.w = 1 << (int)r12.z;
      r15.w = (int)r11.w ^ (int)r15.w;
      r12.z = (int)r10.w + (int)r12.z;
      bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r17.x = (((uint)r12.z << 3) & bitmask.x) | ((uint)1 & ~bitmask.x);
      bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r17.y = (((uint)r12.z << 3) & bitmask.y) | ((uint)5 & ~bitmask.y);
      bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r17.z = (((uint)r12.z << 3) & bitmask.z) | ((uint)6 & ~bitmask.z);
      bitmask.w = ((~(-1 << 29)) << 3) & 0xffffffff;  r17.w = (((uint)r12.z << 3) & bitmask.w) | ((uint)7 & ~bitmask.w);
      r16.w = (uint)cb3[r17.y+6].w;
      r16.w = cmp((int)r16.w == 1);
      if (r16.w != 0) {
        r14.xyz = -cb3[r17.x+6].xyz + v2.xyz;
        r18.xyz = int3(0xffff,0xffff,0xffff) & asint(cb3[r17.y+6].xzy);
        r19.xyz = int3(0xffff,0xffff,0xffff) & asint(cb3[r17.z+6].yxz);
        r20.xyz = asuint(cb3[r17.y+6].xzy) >> int3(16,16,16);
        r21.xyz = asuint(cb3[r17.z+6].yxz) >> int3(16,16,16);
        r18.xyz = f16tof32(r18.xyz);
        r19.xyz = f16tof32(r19.xyz);
        r20.xyz = f16tof32(r20.xyz);
        r21.xyw = f16tof32(r21.yxz);
        r23.xz = r18.xz;
        r23.yw = r20.xz;
        r16.w = dot(r14.xyzw, r23.xyzw);
        r20.x = r18.y;
        r20.z = r19.y;
        r20.w = r21.x;
        r17.y = dot(r14.xyzw, r20.xyzw);
        r21.xz = r19.xz;
        r14.x = dot(r14.xyzw, r21.xyzw);
        r14.y = max(abs(r17.y), abs(r16.w));
        r14.x = max(r14.y, abs(r14.x));
        r14.y = cb3[r17.w+6].x * 0.5 + 0.5;
        r14.x = r14.x + -r14.y;
        r14.y = -cb3[r17.w+6].x * 0.5 + 0.5;
        r14.x = saturate(r14.x / r14.y);
        r14.x = 1 + -r14.x;
        r14.x = r14.x * r14.x;
      } else {
        r14.x = 1;
      }
      r14.y = cmp(r14.x < 0.00100000005);
      if (r14.y != 0) {
        r11.w = r15.w;
        continue;
      }
      r14.y = (uint)r12.z << 3;
      r14.z = cmp(cb3[r14.y+6].w < 1.5);
      if (r14.z != 0) {
        bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r14.z = (((uint)r12.z << 3) & bitmask.z) | ((uint)3 & ~bitmask.z);
        r16.w = cmp(16 == asint(cb3[r14.z+6].w));
        r17.y = cb3[r14.z+6].z + cb0[198].z;
        r17.y = cmp(r17.y < 0.5);
        r16.w = (int)r16.w | (int)r17.y;
        if (r16.w == 0) {
          bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r18.x = (((uint)r12.z << 3) & bitmask.x) | ((uint)2 & ~bitmask.x);
          bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r18.y = (((uint)r12.z << 3) & bitmask.y) | ((uint)4 & ~bitmask.y);
          r12.z = (uint)cb3[r14.y+6].w;
          r12.z = (int)r12.z & 1;
          r16.w = cmp((int)r12.z == 0);
          r16.w = ~(int)r16.w;
          r17.y = cmp(0 < cb3[r18.x+6].z);
          r16.w = r16.w ? r17.y : 0;
          r17.y = cmp(4 == asint(cb3[r14.z+6].w));
          r18.z = r12.z ? 0 : 1;
          r18.w = cb3[r18.x+6].y * 0.5 + 0.5;
          r19.z = -abs(cb3[r18.x+6].x) + r18.w;
          r19.x = cb3[r18.x+6].y + -r19.z;
          r18.w = 1 + -abs(r19.z);
          r18.w = r18.w + -abs(r19.x);
          r18.w = max(0.00048828125, r18.w);
          r19.w = cmp(cb3[r18.x+6].x >= 0);
          r19.y = r19.w ? r18.w : -r18.w;
          r18.w = dot(r19.xyz, r19.xyz);
          r18.w = rsqrt(r18.w);
          r19.xyz = r19.xyz * r18.www;
          r18.w = cb3[r18.y+6].y + cb3[r18.y+6].y;
          r18.w = max(0.100000001, r18.w);
          r19.w = r17.y ? 1.000000 : 0;
          r18.w = -cb3[r17.z+6].w + r18.w;
          r17.z = r19.w * r18.w + cb3[r17.z+6].w;
          r20.xyz = cb3[r17.x+6].xyz + -v2.xyz;
          r18.w = dot(r20.yzx, -r19.xyz);
          r19.w = cmp(0.5 < cb3[r18.y+6].z);
          r19.w = r17.y ? r19.w : 0;
          r19.w = r19.w ? 1.000000 : 0;
          r19.w = r19.w * r18.z;
          r21.xyz = -r19.zxy * r18.www + -r20.xyz;
          r20.xyz = r19.www * r21.xyz + r20.xyz;
          r18.w = dot(r20.xyz, r20.xyz);
          r19.w = rsqrt(r18.w);
          r21.xyz = r20.xyz * r19.www;
          if (r16.w != 0) {
            r23.xyz = cb3[r18.x+6].zzz * r19.zxy;
            r25.yzw = -r23.xyz * float3(0.5,0.5,0.5) + r20.xyz;
            r23.xyz = r23.xyz * float3(0.5,0.5,0.5) + r20.xyz;
            r19.w = dot(r25.yzw, r25.yzw);
            r19.w = sqrt(r19.w);
            r20.w = dot(r23.xyz, r23.xyz);
            r20.w = sqrt(r20.w);
            r26.yzw = r21.xyz * r19.xyz;
            r26.yzw = r19.zxy * r21.yzx + -r26.yzw;
            r27.xyz = r26.yzw * r19.xyz;
            r26.yzw = r26.wyz * r19.yzx + -r27.xyz;
            r21.w = dot(r26.yzw, r26.yzw);
            r21.w = rsqrt(r21.w);
            r21.xyz = r26.yzw * r21.www;
            r21.w = dot(r25.yzw, r23.xyz);
            r21.w = r19.w * r20.w + r21.w;
            r21.w = r21.w * 0.5 + 1;
            r21.w = 1 / r21.w;
            r22.y = dot(r21.xyz, r25.yzw);
            r19.w = r22.y / r19.w;
            r22.y = dot(r21.xyz, r23.xyz);
            r20.w = r22.y / r20.w;
            r19.w = r20.w + r19.w;
            r19.w = saturate(0.5 * r19.w);
            r19.w = r21.w * r19.w;
          } else {
            r19.w = 1;
          }
          r20.w = cmp(r17.z < 0);
          if (r20.w != 0) {
            r20.w = cb3[r17.x+6].w * cb3[r17.x+6].w;
            r20.w = r20.w * r18.w;
            r20.w = -r20.w * r20.w + 1;
            r20.w = max(0, r20.w);
            r18.w = 1 + r18.w;
            r18.w = 1 / r18.w;
            r21.w = r16.w ? 1.000000 : 0;
            r22.y = r19.w + -r18.w;
            r18.w = r21.w * r22.y + r18.w;
            r20.w = r20.w * r20.w;
            r18.w = r20.w * r18.w;
          } else {
            r23.xyz = cb3[r17.x+6].www * r20.xyz;
            r20.w = dot(r23.xyz, r23.xyz);
            r20.w = min(1, r20.w);
            r20.w = 1 + -r20.w;
            r20.w = log2(r20.w);
            r17.z = r20.w * r17.z;
            r17.z = exp2(r17.z);
            r18.w = r19.w * r17.z;
          }
          r17.z = dot(r21.yzx, -r19.xyz);
          r17.z = -cb3[r18.x+6].z + r17.z;
          r17.z = saturate(cb3[r18.x+6].w * r17.z);
          r17.z = r17.z * r17.z + -1;
          r17.z = r18.z * r17.z + 1;
          r17.z = r18.w * r17.z;
          r18.z = (int)cb3[r17.w+6].w;
          r16.w = ~(int)r16.w;
          r18.w = cmp((int)r18.z >= 0);
          r16.w = r16.w ? r18.w : 0;
          if (r16.w != 0) {
            if (r12.z == 0) {
              r16.w = (uint)r18.z << 2;
              r19.xyz = cb6[r16.w+33].xyw * v2.yyy;
              r19.xyz = cb6[r16.w+32].xyw * v2.xxx + r19.xyz;
              r19.xyz = cb6[r16.w+34].xyw * v2.zzz + r19.xyz;
              r19.xyz = cb6[r16.w+35].xyw + r19.xyz;
              r19.xy = saturate(r19.xy / r19.zz);
              r19.xy = r19.xy * cb6[r18.z+0].zw + cb6[r18.z+0].xy;
            } else {
              r16.w = (uint)r18.z << 2;
              r23.x = dot(-r20.xyz, cb6[r16.w+32].xyz);
              r23.y = dot(-r20.xyz, cb6[r16.w+33].xyz);
              r23.z = dot(-r20.xyz, cb6[r16.w+34].xyz);
              r16.w = cmp(abs(r23.x) < abs(r23.y));
              r16.w = r16.w ? 0.000000 : 0;
              r18.w = dot(abs(r23.xy), icb[r16.w+0].xy);
              r18.w = cmp(r18.w < abs(r23.z));
              r16.w = r18.w ? 2 : r16.w;
              r18.w = dot(r23.xyz, icb[r16.w+0].xyz);
              r18.w = cmp(r18.w < 0);
              bitmask.w = ((~(-1 << 31)) << 1) & 0xffffffff;  r16.w = (((uint)r16.w << 1) & bitmask.w) | (asuint((int)r18.w) & ~bitmask.w); // X4115: cmp true=-1
              r18.w = (uint)r16.w >> 1;
              r18.w = dot(r23.xyz, icb[r18.w+0].xyz);
              r19.z = 0.000244140625 / cb6[r18.z+0].w;
              r19.z = 0.5 + -r19.z;
              r19.w = (uint)r16.w;
              r20.x = cmp((uint)r16.w < 2);
              r20.x = r20.x ? 0.000000 : 0;
              r20.x = dot(r23.xz, icb[r20.x+0].xz);
              r20.x = icb[r16.w+4].z * r20.x;
              r20.x = r20.x / abs(r18.w);
              r19.w = r20.x * r19.z + r19.w;
              r19.w = 0.5 + r19.w;
              r20.x = saturate(0.166666672 * r19.w);
              r19.w = -1 + (int)icb[r16.w+4].y;
              r19.w = dot(r23.yz, icb[r19.w+0].xy);
              r16.w = icb[r16.w+4].w * r19.w;
              r16.w = r16.w / abs(r18.w);
              r20.y = saturate(-r16.w * r19.z + 0.5);
              r19.xy = r20.xy * cb6[r18.z+0].zw + cb6[r18.z+0].xy;
            }
            r16.w = LightCookieAtlas.SampleLevel(sampLinear, r19.xy, 0).x;
            r17.z = r17.z * r16.w;
          }
          r14.x = r17.z * r14.x;
          r16.w = cmp(9.99999975e-05 < r14.x);
          if (r16.w != 0) {
            if (r17.y != 0) {
              r16.w = -cb3[r18.y+6].w + 1;
              r17.z = dot(r11.xyz, r21.xyz);
              r17.z = saturate(0.5 + r17.z);
              r18.z = r17.z * -2 + 3;
              r17.z = r17.z * r17.z;
              r17.z = r18.z * r17.z;
              r16.w = r17.z * cb3[r18.y+6].w + r16.w;
              r16.w = cb3[r18.y+6].x * r16.w;
              r16.w = r16.w * r14.x;
              r19.xyz = cb3[r14.y+6].xyz + -r16.xyz;
              r19.xyz = r16.www * r19.xyz + r16.xyz;
            }
            if (r17.y == 0) {
              r16.w = dot(r10.xyz, r21.xyz);
              r17.z = saturate(r16.w);
              if (cb3[r14.z+6].w != 0) {
                if (r12.z == 0) {
                  r12.z = (int)cb3[r14.z+6].x;
                } else {
                  r20.xyz = -cb3[r17.x+6].xyz + v2.xyz;
                  r23.xyz = cmp(abs(r20.yzz) < abs(r20.xxy));
                  r18.z = r23.y ? r23.x : 0;
                  r20.xyz = cmp(float3(0,0,0) < r20.xyz);
                  r18.w = asuint(cb3[r18.x+6].w) >> 24;
                  r23.x = (asuint(cb3[r18.x+6].w) >> 16) & 0xffu;
                  r23.y = (asuint(cb3[r18.x+6].w) >> 8) & 0xffu;
                  r18.w = r20.x ? r18.w : r23.x;
                  r18.x = 255 & asint(cb3[r18.x+6].w);
                  r18.x = r20.y ? r23.y : r18.x;
                  r19.w = (asuint(cb3[r14.z+6].x) >> 8) & 0xffu;
                  r20.x = 255 & asint(cb3[r14.z+6].x);
                  r19.w = r20.z ? r19.w : r20.x;
                  r18.x = r23.z ? r18.x : r19.w;
                  r18.x = r18.z ? r18.w : r18.x;
                  r18.z = cmp((int)r18.x < 80);
                  r12.z = r18.z ? r18.x : -1;
                }
                r18.x = cmp((int)r12.z >= 0);
                if (r18.x != 0) {
                  r18.xzw = -cb3[r17.x+6].xyz + v2.xyz;
                  r17.x = (uint)r12.z << 2;
                  r19.w = dot(r18.xzw, r18.xzw);
                  r19.w = max(1.17549435e-38, r19.w);
                  r19.w = rsqrt(r19.w);
                  r18.xzw = r19.www * r18.xzw;
                  r18.xzw = -r18.xzw * cb4[r12.z+288].xxx + v2.xyz;
                  r19.w = cb4[r12.z+288].y * 5;
                  r18.xzw = r11.xyz * r19.www + r18.xzw;
                  r20.xyzw = cb4[r17.x+65].xyzw * r18.zzzz;
                  r20.xyzw = cb4[r17.x+64].xyzw * r18.xxxx + r20.xyzw;
                  r20.xyzw = cb4[r17.x+66].xyzw * r18.wwww + r20.xyzw;
                  r20.xyzw = cb4[r17.x+67].xyzw + r20.xyzw;
                  r18.xzw = r20.xyz / r20.www;
                  r20.xyz = cmp(float3(0,0,0) >= r18.xzw);
                  r23.xyz = cmp(r18.xzw >= float3(1,1,1));
                  r25.yz = cb4[r12.z+344].zw + -cb4[r12.z+344].xy;
                  r18.xz = r18.xz * r25.yz + cb4[r12.z+344].xy;
                  r25.yz = r18.xz * cb4[400].zw + float2(0.5,0.5);
                  r25.yz = floor(r25.yz);
                  r18.xz = r18.xz * cb4[400].zw + -r25.yz;
                  r27.xyzw = float4(0.5,1,0.5,1) + r18.xxzz;
                  r28.xyzw = r27.xxzz * r27.xxzz;
                  r26.yz = float2(1,1) + -r18.xz;
                  r27.xz = min(float2(0,0), r18.xz);
                  r29.xy = max(float2(0,0), r18.xz);
                  r30.xy = float2(0.159999996,0.159999996) * r26.yz;
                  r29.xy = -r29.xy * r29.xy + r27.yw;
                  r29.xy = float2(1,1) + r29.xy;
                  r29.xy = float2(0.159999996,0.159999996) * r29.xy;
                  r28.xz = float2(0.0799999982,0.0799999982) * r28.xz;
                  r18.xz = r28.yw * float2(0.5,0.5) + -r18.xz;
                  r31.xy = float2(0.159999996,0.159999996) * r18.xz;
                  r18.xz = -r27.xz * r27.xz + r26.yz;
                  r18.xz = float2(1,1) + r18.xz;
                  r32.xy = float2(0.159999996,0.159999996) * r18.xz;
                  r18.xz = float2(0.159999996,0.159999996) * r27.yw;
                  r31.z = r32.x;
                  r31.w = r18.x;
                  r30.z = r29.x;
                  r30.w = r28.x;
                  r27.xyzw = r31.zwxz + r30.zwxz;
                  r32.z = r31.y;
                  r32.w = r18.z;
                  r29.z = r30.y;
                  r29.w = r28.z;
                  r26.yzw = r32.zyw + r29.zyw;
                  r28.xyz = r30.xzw / r27.zwy;
                  r28.xyz = float3(-2.5,-0.5,1.5) + r28.xyz;
                  r28.xyz = cb4[400].xxx * r28.yxz;
                  r29.xyz = r29.zyw / r26.yzw;
                  r29.xyz = float3(-2.5,-0.5,1.5) + r29.xyz;
                  r29.xyz = cb4[400].yyy * r29.xyz;
                  r28.w = r29.x;
                  r30.xyzw = r25.yzyz * cb4[400].xyxy + r28.ywxw;
                  r18.xz = r25.yz * cb4[400].xy + r28.zw;
                  r29.w = r28.y;
                  r28.yw = r29.yz;
                  r31.xyzw = r25.yzyz * cb4[400].xyxy + r28.xyzy;
                  r29.xyzw = r25.yzyz * cb4[400].xyxy + r29.wywz;
                  r28.xyzw = r25.yzyz * cb4[400].xyxy + r28.xwzw;
                  r32.xyzw = r27.zwyz * r26.yyyz;
                  r17.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r30.xy, r18.w).x;
                  r19.w = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r30.zw, r18.w).x;
                  r19.w = r32.y * r19.w;
                  r17.x = r32.x * r17.x + r19.w;
                  r18.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r18.xz, r18.w).x;
                  r17.x = r32.z * r18.x + r17.x;
                  r18.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r29.xy, r18.w).x;
                  r17.x = r32.w * r18.x + r17.x;
                  r30.xyzw = r27.xyzw * r26.zzww;
                  r18.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r31.xy, r18.w).x;
                  r17.x = r30.x * r18.x + r17.x;
                  r18.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r31.zw, r18.w).x;
                  r17.x = r30.y * r18.x + r17.x;
                  r18.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r29.zw, r18.w).x;
                  r17.x = r30.z * r18.x + r17.x;
                  r18.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r28.xy, r18.w).x;
                  r17.x = r30.w * r18.x + r17.x;
                  r20.xyz = (int3)r20.xyz | (int3)r23.xyz;
                  r18.x = (int)r20.y | (int)r20.x;
                  r18.x = (int)r20.z | (int)r18.x;
                  r18.z = (int)r18.w & 0x7fffffff;
                  r18.z = cmp(0x7f800000 < (uint)r18.z);
                  r18.x = (int)r18.z | (int)r18.x;
                  r18.z = r27.y * r26.w;
                  r18.w = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r28.zw, r18.w).x;
                  r17.x = r18.z * r18.w + r17.x;
                  r17.x = -1 + r17.x;
                  r12.z = cb4[r12.z+288].w * r17.x + 1;
                  r12.z = r18.x ? 1 : r12.z;
                } else {
                  r17.x = dot(r9.xyz, r21.xyz);
                  r12.z = saturate(1 + r17.x);
                }
              } else {
                r12.z = 1;
              }
              if (cb3[r14.z+6].w == 0) {
                r18.xzw = cb3[r14.y+6].xyz * r14.xxx;
                r17.x = -cb3[r18.y+6].y + 1;
                r18.x = max(r18.x, r18.z);
                r18.x = max(r18.x, r18.w);
                r18.x = r18.x * r7.w;
                r18.x = max(1, r18.x);
                r18.x = 1 / r18.x;
                r17.x = r18.x * cb3[r18.y+6].y + r17.x;
                r18.xzw = cb3[r14.y+6].xyz * r17.xxx;
                r17.x = cb3[r18.y+6].x * 0.25;
                r19.w = saturate(0.5 + r16.w);
                r20.x = -cb3[r18.y+6].x * 0.25 + 1;
                r17.x = r19.w * r20.x + r17.x;
                r18.xzw = r18.xzw * r17.xxx;
                r20.xyz = r22.xzw;
                r23.xyz = r22.xzw;
                r17.x = 1;
                r19.w = 0;
              } else {
                r20.w = cmp(3 == asint(cb3[r14.z+6].w));
                if (r20.w != 0) {
                  r25.yz = cb3[r18.y+6].xx * float2(-0.600000024,-0.399999976) + float2(0.800000012,0.899999976);
                  r20.w = r25.z + -r25.y;
                  r21.w = r26.x + -r25.y;
                  r20.w = 1 / r20.w;
                  r20.w = saturate(r21.w * r20.w);
                  r21.w = r20.w * -2 + 3;
                  r20.w = r20.w * r20.w;
                  r20.w = r21.w * r20.w;
                  r20.w = r20.w * r12.z;
                  r14.x = r20.w * r14.x;
                  r25.yzw = cb0[6].xyz * r21.zxy;
                  r25.yzw = cb0[6].zxy * r21.xyz + -r25.yzw;
                  r26.yzw = cb0[6].zxy * r25.yzw;
                  r25.yzw = cb0[6].yzx * r25.zwy + -r26.yzw;
                  r20.w = dot(r25.yzw, r25.yzw);
                  r20.w = rsqrt(r20.w);
                  r25.yzw = r25.yzw * r20.www;
                  r17.z = saturate(dot(r10.xyz, -r25.yzw));
                  r20.xyz = cb3[r18.y+6].yyy * r4.xyz + float3(0.5,0.5,0.5);
                  r23.xyz = float3(0,0,0);
                  r17.x = 1;
                  r19.w = 0;
                } else {
                  r20.w = cmp(1 == asint(cb3[r14.z+6].w));
                  if (r20.w != 0) {
                    r16.w = cb3[r18.y+6].x + r16.w;
                    r16.w = saturate(max(-1, r16.w));
                    r17.z = r16.w * r12.z;
                    r23.xyz = cb3[r18.y+6].yyy * r6.xyz;
                    r17.x = 1;
                    r19.w = 0;
                  } else {
                    r12.z = cmp(2 == asint(cb3[r14.z+6].w));
                    if (r12.z != 0) {
                      r16.w = cb3[r18.y+6].x + 0.0500000007;
                      r16.w = -r16.w + r3.z;
                      r16.w = saturate(-10 * r16.w);
                      r21.w = r16.w * -2 + 3;
                      r16.w = r16.w * r16.w;
                      r16.w = r21.w * r16.w;
                      r21.w = -cb3[r18.y+6].z + 1;
                      r21.w = r5.x * cb3[r18.y+6].z + r21.w;
                      r17.x = r21.w * r16.w;
                    } else {
                      r17.x = 1;
                    }
                    r19.w = r12.z ? cb3[r18.y+6].y : 0;
                    r23.xyz = float3(0,0,0);
                  }
                  r20.xyz = r20.www ? r13.xyz : 0;
                }
                r18.xzw = cb3[r14.y+6].xyz;
              }
              r12.z = cmp(3 != asint(cb3[r14.z+6].w));
              if (r12.z != 0) {
                r12.z = r19.w * r5.w + r3.x;
                r21.xyz = r0.xyz * r1.www + r21.xyz;
                r14.y = dot(r21.xyz, r21.xyz);
                r14.y = rsqrt(r14.y);
                r21.xyz = r21.xyz * r14.yyy;
                r14.y = dot(r7.xyz, r21.xyz);
                r14.z = r12.z * r12.z;
                r16.w = r14.y * r14.z + -r14.y;
                r14.y = r16.w * r14.y + 1;
                r14.y = r14.y * r14.y;
                r16.w = cmp(r14.y != r14.z);
                r14.y = r14.z / r14.y;
                r14.y = r16.w ? r14.y : 1;
                r12.z = r25.x * 2 + r12.z;
                r12.z = 9.99999975e-05 + r12.z;
                r12.z = 0.5 / r12.z;
                r12.z = r14.y * r12.z + -6.10351562e-05;
                r12.z = max(0, r12.z);
                r12.z = min(20, r12.z);
                r21.xyz = r24.yzw * r12.zzz;
                r21.xyz = r21.xyz * r17.xxx;
                r21.xyz = cb3[r17.w+6].zzz * r21.xyz;
              } else {
                r21.xyz = float3(0,0,0);
              }
              r14.xyz = r18.xzw * r14.xxx;
              r18.xyz = -r23.xyz + r20.xyz;
              r18.xyz = r17.zzz * r18.xyz + r23.xyz;
              r18.xyz = r18.xyz * r14.xyz;
              r14.xyz = r14.xyz * r21.xyz;
              r14.xyz = r14.xyz * r17.zzz;
              r14.xyz = r18.xyz * r3.www + r14.xyz;
              r16.xyz = r16.xyz + r14.xyz;
            }
          } else {
            r17.y = 0;
          }
          r16.xyz = r17.yyy ? r19.xyz : r16.xyz;
        }
      }
      r11.w = r15.w;
    }
    r15.xyz = r16.xyz;
    r8.w = (int)r8.w + 1;
  }
  // ===== 11. Optional material color grade (cb5[3..8]) =====
  r0.x = cmp(0.5 < cb5[3].x);
  if (r0.x != 0) {
    r0.x = dot(r15.xyz, float3(0.212672904,0.715152204,0.0721750036));
    r3.xyz = r15.xyz + -r0.xxx;
    r0.xyz = cb5[3].zzz * r3.xyz + r0.xxx;
    r0.xyz = float3(-0.5,-0.5,-0.5) + r0.xyz;
    r0.xyz = cb5[3].www * r0.xyz + float3(0.5,0.5,0.5);
    r3.xyz = cb5[3].yyy * r0.xyz;
    r0.xyz = -r0.xyz * cb5[3].yyy + cb5[7].xyz;
    r0.xyz = cb5[7].www * r0.xyz + r3.xyz;
    r2.w = -cb5[4].x + 1;
    r13.w = saturate(r13.w);
    r3.x = 1 + -r13.w;
    r3.y = 1 + -r2.w;
    r2.w = r3.x + -r2.w;
    r3.x = 1 / r3.y;
    r2.w = saturate(r3.x * r2.w);
    r3.x = r2.w * -2 + 3;
    r2.w = r2.w * r2.w;
    r2.w = r3.x * r2.w;
    r3.xyz = cb5[8].xyz * r2.www;
    r15.xyz = r3.xyz * cb5[4].yyy + r0.xyz;
  }
  // ===== 12. Exposure + volumetric fog / atmosphere (o0) =====
  r0.xyz = r15.xyz / cb0[109].xxx;
  r2.w = cmp(1.000000 == cb5[2].x);
  o0.w = r2.w ? r4.w : 1;
  r2.w = cmp(cb0[198].w < 0.5);
  if (r2.w != 0) {
    r0.w = r1.w * r0.w;
    r1.w = v2.y * cb0[156].w + cb0[157].w;
    r1.w = max(0.00999999978, r1.w);
    r2.w = r0.w * cb0[154].w + -cb0[153].w;
    r2.w = max(0, r2.w);
    r3.x = -1.44269502 * r1.w;
    r3.x = exp2(r3.x);
    r3.x = 1 + -r3.x;
    r1.w = r3.x / r1.w;
    r3.x = v2.y * cb0[156].w + cb0[158].w;
    r3.x = 1.44269502 * r3.x;
    r3.x = exp2(r3.x);
    r1.w = r3.x * r1.w;
    r1.w = -r2.w * r1.w;
    r3.xyz = cb0[155].xyz * r1.www;
    r3.xyz = float3(1.44269502,1.44269502,1.44269502) * r3.xyz;
    r3.xyz = exp2(r3.xyz);
    r1.w = dot(-r2.xyz, cb0[154].xyz);
    r2.w = cb0[155].w * cb0[155].w + 1;
    r3.w = dot(r1.ww, cb0[155].ww);
    r2.w = -r3.w + r2.w;
    r3.w = cmp(0 < cb0[163].z);
    if (r3.w != 0) {
      r12.w = 7 & asint(cb0[108].w);
      r4.xyz = mad((int3)r12.xyw, int3(0x19660d,0x19660d,0x19660d), int3(0x3c6ef35f,0x3c6ef35f,0x3c6ef35f));
      r3.w = mad((int)r4.y, (int)r4.z, (int)r4.x);
      r4.x = mad((int)r4.z, (int)r3.w, (int)r4.y);
      r4.y = mad((int)r3.w, (int)r4.x, (int)r4.z);
      r6.x = mad((int)r4.x, (int)r4.y, (int)r3.w);
      r1.x = dot(-r2.xyz, -r1.xyz);
      r1.y = -cb0[44].y + v2.y;
      r1.z = cmp(5.96046448e-08 < r1.x);
      r1.x = 1 / r1.x;
      r1.x = r1.z ? r1.x : 0;
      r1.x = cb0[163].w * r1.x;
      r1.z = 1 / r0.w;
      r2.x = r1.x * r1.z;
      r2.y = r2.x * r1.y + cb0[44].y;
      r1.y = -r2.x * r1.y + r1.y;
      r2.x = cb0[159].z * r1.y;
      r1.y = cb0[162].x * r1.y;
      r1.y = max(-127, r1.y);
      r2.z = -cb0[159].x + r2.y;
      r2.z = cb0[159].z * r2.z;
      r2.xz = max(float2(-127,-127), r2.xz);
      r2.z = exp2(-r2.z);
      r2.z = cb0[159].y * r2.z;
      r3.w = cmp(5.96046448e-08 < abs(r2.x));
      r4.z = exp2(-r2.x);
      r4.z = 1 + -r4.z;
      r4.z = r4.z / r2.x;
      r2.x = -r2.x * 0.240226507 + 0.693147182;
      r2.x = r3.w ? r4.z : r2.x;
      r2.y = -cb0[162].z + r2.y;
      r2.y = cb0[162].x * r2.y;
      r2.y = max(-127, r2.y);
      r2.y = exp2(-r2.y);
      r2.y = cb0[162].y * r2.y;
      r3.w = cmp(5.96046448e-08 < abs(r1.y));
      r4.z = exp2(-r1.y);
      r4.z = 1 + -r4.z;
      r4.z = r4.z / r1.y;
      r1.y = -r1.y * 0.240226507 + 0.693147182;
      r1.y = r3.w ? r4.z : r1.y;
      r1.y = r2.y * r1.y;
      r1.y = r2.z * r2.x + r1.y;
      r1.x = -r1.x * r1.z + 1;
      r1.x = r1.x * r0.w;
      r1.x = r1.y * r1.x;
      r1.x = exp2(-r1.x);
      r1.x = min(1, r1.x);
      r1.x = max(cb0[161].w, r1.x);
      r1.yz = saturate(r0.ww * cb0[160].yw + cb0[160].xz);
      r1.x = r1.x + r1.y;
      r1.x = r1.x + r1.z;
      r1.x = min(1, r1.x);
      r6.y = mad((int)r4.y, (int)r6.x, (int)r4.x);
      r1.yz = (uint2)r6.xy >> int2(16,16);
      r1.yz = (uint2)r1.yz;
      r1.yz = r1.yz * float2(3.05180438e-05,3.05180438e-05) + float2(-1,-1);
      r1.yz = r1.yz * cb0[167].ww + r5.yz;
      r2.xy = cb0[165].xy * r1.yz;
      r1.y = v0.w * cb0[164].x + cb0[164].y;
      r1.y = log2(r1.y);
      r1.y = cb0[164].z * r1.y;
      r2.z = r1.y / cb0[163].z;
      r4.xyzw = VolumetricFog3D.SampleLevel(sampLinear, r2.xyz, 0).xyzw;
      r1.y = -cb0[166].z + v0.w;
      r1.y = saturate(1000000 * r1.y);
      r4.xyzw = float4(-0,-0,-0,-1) + r4.xyzw;
      r4.xyzw = r1.yyyy * r4.xyzw + float4(0,0,0,1);
      r1.y = 1 + -r1.x;
      r2.xyz = cb0[161].xyz * r1.yyy;
      r2.xyz = r2.xyz * r4.www + r4.xyz;
      r1.x = r4.w * r1.x;
    } else {
      r1.y = -cb0[44].y + v2.y;
      r1.z = cb0[159].z * r1.y;
      r1.y = cb0[162].x * r1.y;
      r1.yz = max(float2(-127,-127), r1.yz);
      r3.w = -cb0[159].x + cb0[44].y;
      r3.w = cb0[159].z * r3.w;
      r3.w = max(-127, r3.w);
      r3.w = exp2(-r3.w);
      r3.w = cb0[159].y * r3.w;
      r4.x = cmp(5.96046448e-08 < abs(r1.z));
      r4.y = exp2(-r1.z);
      r4.y = 1 + -r4.y;
      r4.y = r4.y / r1.z;
      r1.z = -r1.z * 0.240226507 + 0.693147182;
      r1.z = r4.x ? r4.y : r1.z;
      r4.x = -cb0[162].z + cb0[44].y;
      r4.x = cb0[162].x * r4.x;
      r4.x = max(-127, r4.x);
      r4.x = exp2(-r4.x);
      r4.x = cb0[162].y * r4.x;
      r4.y = cmp(5.96046448e-08 < abs(r1.y));
      r4.z = exp2(-r1.y);
      r4.z = 1 + -r4.z;
      r4.z = r4.z / r1.y;
      r1.y = -r1.y * 0.240226507 + 0.693147182;
      r1.y = r4.y ? r4.z : r1.y;
      r1.y = r4.x * r1.y;
      r1.y = r3.w * r1.z + r1.y;
      r1.y = r1.y * r0.w;
      r1.y = exp2(-r1.y);
      r1.y = min(1, r1.y);
      r1.y = max(cb0[161].w, r1.y);
      r4.xy = saturate(r0.ww * cb0[160].yw + cb0[160].xz);
      r0.w = r4.x + r1.y;
      r0.w = r0.w + r4.y;
      r1.x = min(1, r0.w);
      r0.w = 1 + -r1.x;
      r2.xyz = cb0[161].xyz * r0.www;
    }
    r4.xyz = r3.xyz * r1.xxx;
    r0.w = r1.w * r1.w + 1;
    r0.w = 0.0596831031 * r0.w;
    r1.yzw = cb0[156].xyz * r0.www + cb0[158].xyz;
    r0.w = -cb0[155].w * cb0[155].w + 1;
    r3.w = 12.566371 * r2.w;
    r2.w = sqrt(r2.w);
    r2.w = r3.w * r2.w;
    r2.w = max(0.00100000005, r2.w);
    r0.w = r0.w / r2.w;
    r1.yzw = saturate(cb0[157].xyz * r0.www + r1.yzw);
    r1.yzw = float3(255,255,255) * r1.yzw;
    r3.xyz = float3(1,1,1) + -r3.xyz;
    r1.yzw = r3.xyz * r1.yzw;
    r1.xyz = r1.yzw * r1.xxx + r2.xyz;
    o0.xyz = r0.xyz * r4.xyz + r1.xyz;
  } else {
    o0.xyz = r0.xyz;
  }
  o1.z = 1;
  return;
}
