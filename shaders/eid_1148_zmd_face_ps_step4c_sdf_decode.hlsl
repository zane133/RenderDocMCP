// ZMD face pixel shader - Stage 4c face-SDF decode aliases.
// Capture: D:\Capture\ZMD\Endfield_2026.01.29_17.33_frame22692.rdc
// Event: 1148, original DXBC hash 5b6c9350-3ba6f256-113cc690-f28b38e0.
//
// This revision builds on the Apply-verified Stage 4b file. It adds names only
// inside the t17 face-SDF decode. Section names and channel roles marked
// "inferred" describe observed data flow, not recovered source symbols.
// Registers, expressions, bindings, operation order, and control flow are intact.
// ---- Created with 3Dmigoto v1.4.6 on Thu Sep  3 10:08:12 2026
Texture3D<float4> t20 : register(t20);

Texture2D<float4> t19 : register(t19);

Texture2D<float4> t18 : register(t18);

Texture2D<float4> t17 : register(t17);

Texture2D<float4> t16 : register(t16);

Texture2D<float4> t15 : register(t15);

Texture2D<float4> t14 : register(t14);

Texture2D<float4> t13 : register(t13);

Texture2D<float4> t12 : register(t12);

Texture2D<float4> t11 : register(t11);

Texture2D<float4> t10 : register(t10);

Texture3D<float4> t9 : register(t9);

Texture3D<float4> t8 : register(t8);

Texture3D<float4> t7 : register(t7);

Texture3D<float4> t6 : register(t6);

Texture3D<float4> t5 : register(t5);

Texture3D<float4> t4 : register(t4);

Texture2D<float4> t3 : register(t3);

Texture2D<float4> t2 : register(t2);

struct t1_t {
  float val[4];
};
StructuredBuffer<t1_t> t1 : register(t1);

struct t0_t {
  float val[1];
};
StructuredBuffer<t0_t> t0 : register(t0);

SamplerState s6_s : register(s6);

SamplerState s5_s : register(s5);

SamplerState s4_s : register(s4);

SamplerState s3_s : register(s3);

SamplerComparisonState s2_s : register(s2);

SamplerState s1_s : register(s1);

SamplerState s0_s : register(s0);

cbuffer cb6 : register(b6)
{
  float4 cb6[160];
}

cbuffer cb5 : register(b5)
{
  float4 cb5[17];
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
  uint v10 : SV_IsFrontFace0,
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

  // ---------------------------------------------------------------------------
  // 1. Camera-relative vectors and per-draw material basis.
  //    v9 selects a 16-float4 material record. When its indirection bit is set,
  //    the basis is fetched from structured buffer t1; otherwise it comes from
  //    the material record in cb1.
  // ---------------------------------------------------------------------------
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
  r2.w = (uint)v9.x << 4;
  r3.x = 16 & asint(cb1[r2.w+4].w);
  if (r3.x != 0) {
    r3.xy = int2(2,1) + asint(cb1[r2.w+5].xx);
    r4.x = t1[r3.x].val[0/4];
    r4.y = t1[r3.x].val[0/4+1];
    r4.z = t1[r3.x].val[0/4+2];
    r4.w = t1[r3.x].val[0/4+3];
    r3.x = t1[r3.y].val[0/4];
    r3.y = t1[r3.y].val[0/4+1];
    r3.z = t1[r3.y].val[0/4+2];
    r5.x = t1[cb1[r2.w+5].x].val[0/4];
    r5.y = t1[cb1[r2.w+5].x].val[0/4+1];
    r5.z = t1[cb1[r2.w+5].x].val[0/4+2];
    r5.w = t1[cb1[r2.w+5].x].val[0/4+3];
    r6.x = r4.w;
    r6.y = r5.w;
    r7.z = r4.x;
    r8.z = r4.y;
    r7.y = r3.x;
    r8.y = r3.y;
    r4.y = r3.z;
    r7.x = r5.x;
    r8.x = r5.y;
    r4.x = r5.z;
  } else {
    r6.xy = cb1[r2.w+3].zx;
    r7.xyz = cb1[r2.w+0].xyz;
    r8.xyz = cb1[r2.w+1].xyz;
    r4.xyz = cb1[r2.w+2].xyz;
  }
  // ---------------------------------------------------------------------------
  // 2. Face texture inputs (inferred).
  //    t16/t12 are sRGB BC7 maps; t18 is a linear BC7 mask/control map. This
  //    block blends the two color sources and prepares the 1024x32 LUT address.
  // ---------------------------------------------------------------------------
  r3.xyzw = t16.SampleBias(s4_s, v1.xy, cb0[108].x).wxyz;
  r4.w = cb5[11].z * 0.5;
  r5.x = cmp(r4.w >= -r4.w);
  r5.y = frac(abs(r4.w));
  r5.x = r5.x ? r5.y : -r5.y;
  r4.w = floor(r4.w);
  r5.y = 0.5 * r4.w;
  r5.xy = v1.xy * float2(0.5,0.5) + r5.xy;
  r5.xyzw = t12.SampleBias(s4_s, r5.xy, cb0[108].x).xyzw;
  r9.xyz = cb5[5].xyz * r3.yzw;
  r4.w = cb5[11].w * r5.w;
  r3.yzw = -r3.yzw * cb5[5].xyz + r5.xyz;
  r3.yzw = r4.www * r3.yzw + r9.xyz;
  r5.xyz = float3(12.9200001,12.9200001,12.9200001) * r3.wyz;
  r9.xyz = log2(abs(r3.wyz));
  r9.xyz = float3(0.416666657,0.416666657,0.416666657) * r9.xyz;
  r9.xyz = exp2(r9.xyz);
  r9.xyz = r9.xyz * float3(1.05499995,1.05499995,1.05499995) + float3(-0.0549999997,-0.0549999997,-0.0549999997);
  r10.xyz = cmp(float3(0.00313080009,0.00313080009,0.00313080009) >= r3.wyz);
  r5.xyz = saturate(r10.xyz ? r5.xyz : r9.xyz);
  r9.xw = float2(31,0.96875) * r5.xz;
  r4.w = floor(r9.x);
  r9.yz = r5.yz * float2(0.0302734375,0.96875) + float2(0.00048828125,0.015625);
  r9.x = r4.w * 0.03125 + r9.y;
  // t18 is the linear packed face mask/control map (inferred), not the SDF
  // threshold lookup itself. Its channels later gate normal and material terms.
  const float4 faceControlSample = t18.SampleBias(s6_s, v1.xy, cb0[108].x).xyzw;
  r10.xyzw = faceControlSample;
  // ---------------------------------------------------------------------------
  // 3. View, geometric normal, tangent basis, and screen-pixel setup.
  // ---------------------------------------------------------------------------
  r6.xz = v2.xz + -r6.yx;
  r6.yw = float2(6.10351562e-05,6.10351562e-05);
  r5.y = dot(r6.xyz, r6.xyz);
  r5.y = rsqrt(r5.y);
  r6.xyz = r6.xyz * r5.yyy;
  r5.y = cb5[1].y * 2 + -1;
  r5.y = v10.x ? 1 : r5.y;
  r5.z = dot(v3.xyz, v3.xyz);
  r5.z = rsqrt(r5.z);
  r11.xyz = v3.xyz * r5.zzz;
  r12.xyz = r11.xyz * r5.yyy;
  r13.xy = (uint2)v0.xy;
  r14.x = dot(cb0[6].xyz, r7.xyz);
  r14.y = dot(cb0[6].xyz, r8.xyz);
  r14.z = dot(cb0[6].xyz, r4.xyz);
  r5.z = dot(r14.xyz, r14.xyz);
  r5.z = max(1.17549435e-38, r5.z);
  r5.z = rsqrt(r5.z);
  r5.zw = r14.xz * r5.zz;
  r5.z = dot(r5.zw, r5.zw);
  r5.z = rsqrt(r5.z);
  r7.w = r5.w * r5.z;
  r8.w = -cb0[111].x + 1;
  r8.w = cb0[198].w * r8.w + cb0[111].x;
  r8.w = cb0[109].x * r8.w;
  r12.w = 6.10351562e-05;
  r9.y = dot(r12.xzw, r12.xzw);
  r9.y = rsqrt(r9.y);
  r14.xyz = r12.xwz * r9.yyy + -r6.xyz;
  r14.xyz = r10.yyy * r14.xyz + r6.xyz;
  r9.y = dot(r14.xyz, r14.xyz);
  r9.y = rsqrt(r9.y);
  r14.xyz = r14.xyz * r9.yyy;
  r9.y = cmp(cb0[187].y < 0.5);
  // ---------------------------------------------------------------------------
  // 4. Three nested irradiance-volume clipmaps (inferred).
  //    Pairs t4/t5, t6/t7, and t8/t9 are 3D irradiance + directional/visibility
  //    volumes at successively coarser world scales. Keep this block register-
  //    shaped: its atlas slicing and blend weights are especially fragile.
  // ---------------------------------------------------------------------------
  if (r9.y != 0) {
    r15.xyz = cb0[6].xzy * -cb0[212].www + cb0[210].xzy;
    r15.xyz = v2.xzy + -r15.xyz;
    r9.y = max(abs(r15.x), abs(r15.y));
    r9.y = -464 + r9.y;
    r9.y = saturate(0.03125 * r9.y);
    r11.w = -208 + abs(r15.z);
    r11.w = saturate(0.03125 * r11.w);
    r9.y = max(r11.w, r9.y);
    r11.w = cmp(0.000000 != cb0[210].w);
    r12.w = cmp(r9.y < 1);
    r11.w = r11.w ? r12.w : 0;
    if (r11.w != 0) {
      r15.xyz = cb0[6].xzy * -cb0[212].yyy + cb0[210].xzy;
      r15.xyz = v2.xzy + -r15.xyz;
      r11.w = max(abs(r15.x), abs(r15.y));
      r11.w = -29 + r11.w;
      r11.w = saturate(0.5 * r11.w);
      r12.w = -13 + abs(r15.z);
      r12.w = saturate(0.5 * r12.w);
      r11.w = max(r12.w, r11.w);
      r12.w = cmp(r11.w < 1);
      if (r12.w != 0) {
        r15.xyz = v2.xyz * float3(2,2,2) + float3(0.5,0.5,0.5);
        r16.xyz = cb0[211].xyz * r15.xyz;
        r16.xyz = floor(r16.xyz);
        r15.xyz = r15.xyz * cb0[211].xyz + -r16.xyz;
        r16.xyw = t4.SampleLevel(s1_s, r15.xyz, 0).yzx;
        r12.w = 1 + -r11.w;
        r17.x = cb0[211].y * 0.5;
        r17.y = -cb0[211].y * 0.5 + 1;
        r15.y = max(r17.x, r15.y);
        r15.y = min(r15.y, r17.y);
        r15.w = 0.333333343 * r15.y;
        r17.xyzw = t5.SampleLevel(s0_s, r15.xwz, 0).xyzw;
        r15.y = r17.w * r12.w + r9.y;
        r18.xyz = float3(0,0.666666687,0) + r15.xwz;
        r18.xyz = t5.SampleLevel(s0_s, r18.xyz, 0).xyz;
        r18.xyz = r18.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r18.xyz = r18.xyz * r16.yyy;
        r18.w = r16.y;
        r18.xyzw = r18.xyzw * r12.wwww;
        r15.xzw = float3(0,0.333333343,0) + r15.xwz;
        r15.xzw = t5.SampleLevel(s0_s, r15.xzw, 0).xyz;
        r15.xzw = r15.xzw * float3(4,4,4) + float3(-2,-2,-2);
        r19.xyz = r15.xzw * r16.xxx;
        r19.w = r16.x;
        r19.xyzw = r19.xyzw * r12.wwww;
        r15.xzw = r17.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r16.xyz = r15.xzw * r16.www;
        r16.xyzw = r16.xyzw * r12.wwww;
      } else {
        r18.xyzw = float4(0,0,0,0);
        r19.xyzw = float4(0,0,0,0);
        r16.xyzw = float4(0,0,0,0);
        r15.y = r9.y;
      }
      r15.xzw = cb0[6].xzy * -cb0[212].zzz + cb0[210].xzy;
      r15.xzw = v2.xzy + -r15.xzw;
      r12.w = max(abs(r15.x), abs(r15.z));
      r12.w = -116 + r12.w;
      r12.w = saturate(0.125 * r12.w);
      r15.x = -52 + abs(r15.w);
      r15.x = saturate(0.125 * r15.x);
      r12.w = max(r15.x, r12.w);
      r15.x = cmp(r12.w < 1);
      if (r15.x != 0) {
        r15.xzw = v2.xyz * float3(0.5,0.5,0.5) + float3(0.5,0.5,0.5);
        r17.xyz = cb0[211].xyz * r15.xzw;
        r17.xyz = floor(r17.xyz);
        r17.xyz = r15.xzw * cb0[211].xyz + -r17.xyz;
        r20.xyw = t6.SampleLevel(s1_s, r17.xyz, 0).yzx;
        r15.x = 1 + -r12.w;
        r11.w = r15.x * r11.w;
        r15.x = cb0[211].y * 0.5;
        r15.z = -cb0[211].y * 0.5 + 1;
        r15.x = max(r17.y, r15.x);
        r15.x = min(r15.x, r15.z);
        r17.w = 0.333333343 * r15.x;
        r21.xyzw = t7.SampleLevel(s0_s, r17.xwz, 0).xyzw;
        r15.y = r21.w * r11.w + r15.y;
        r15.xzw = float3(0,0.666666687,0) + r17.xwz;
        r15.xzw = t7.SampleLevel(s0_s, r15.xzw, 0).xyz;
        r15.xzw = r15.xzw * float3(4,4,4) + float3(-2,-2,-2);
        r22.xyz = r15.xzw * r20.yyy;
        r22.w = r20.y;
        r18.xyzw = r22.xyzw * r11.wwww + r18.xyzw;
        r15.xzw = float3(0,0.333333343,0) + r17.xwz;
        r15.xzw = t7.SampleLevel(s0_s, r15.xzw, 0).xyz;
        r15.xzw = r15.xzw * float3(4,4,4) + float3(-2,-2,-2);
        r17.xyz = r15.xzw * r20.xxx;
        r17.w = r20.x;
        r19.xyzw = r17.xyzw * r11.wwww + r19.xyzw;
        r15.xzw = r21.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r20.xyz = r15.xzw * r20.www;
        r16.xyzw = r20.xyzw * r11.wwww + r16.xyzw;
      }
      r11.w = cmp(0 < r12.w);
      if (r11.w != 0) {
        r15.xzw = v2.xyz * float3(0.125,0.125,0.125) + float3(0.5,0.5,0.5);
        r17.xyz = cb0[211].xyz * r15.xzw;
        r20.xyz = cb0[211].xyz * float3(0.5,0.5,0.5);
        r17.xyz = floor(r17.xyz);
        r15.xzw = r15.xzw * cb0[211].xyz + -r17.xyz;
        r17.xyz = -cb0[211].xyz * float3(0.5,0.5,0.5) + float3(1,1,1);
        r15.xzw = max(r15.xzw, r20.xyz);
        r21.xyz = min(r15.xzw, r17.xyz);
        r22.xyw = t8.SampleLevel(s1_s, r21.xyz, 0).yzx;
        r11.w = 1 + -r9.y;
        r11.w = r12.w * r11.w;
        r12.w = max(r21.y, r20.y);
        r12.w = min(r12.w, r17.y);
        r21.w = 0.333333343 * r12.w;
        r17.xyzw = t9.SampleLevel(s0_s, r21.xwz, 0).xyzw;
        r15.xzw = float3(0,0.666666687,0) + r21.xwz;
        r15.xzw = t9.SampleLevel(s0_s, r15.xzw, 0).xyz;
        r15.xzw = r15.xzw * float3(4,4,4) + float3(-2,-2,-2);
        r20.xyz = r15.xzw * r22.yyy;
        r20.w = r22.y;
        r18.xyzw = r20.xyzw * r11.wwww + r18.xyzw;
        r15.xzw = float3(0,0.333333343,0) + r21.xwz;
        r15.xzw = t9.SampleLevel(s0_s, r15.xzw, 0).xyz;
        r15.xzw = r15.xzw * float3(4,4,4) + float3(-2,-2,-2);
        r20.xyz = r15.xzw * r22.xxx;
        r20.w = r22.x;
        r19.xyzw = r20.xyzw * r11.wwww + r19.xyzw;
        r15.xzw = r17.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r22.xyz = r15.xzw * r22.www;
        r16.xyzw = r22.xyzw * r11.wwww + r16.xyzw;
        r15.y = r17.w * r11.w + r15.y;
      }
      r11.w = saturate(r15.y * 2 + -1);
      r15.x = r11.w + -r9.y;
      r9.y = r11.w + r9.y;
      r15.y = 0.5 * r9.y;
    } else {
      r18.xyzw = float4(0,0,0,0);
      r19.xyzw = float4(0,0,0,0);
      r16.xyzw = float4(0,0,0,0);
      r15.xy = float2(0,1);
    }
    r17.xyzw = cb0[213].xyzw * r15.yyyx;
    r17.y = r17.w * 0.5 + r17.y;
    r15.zw = cb0[213].wy * r15.yx;
    r17.w = r15.w * 0.375 + r15.z;
    r16.xyzw = r17.xyzw + r16.xyzw;
    r17.xyzw = cb0[214].xyzw * r15.yyyx;
    r17.y = r17.w * 0.5 + r17.y;
    r15.zw = cb0[214].wy * r15.yx;
    r17.w = r15.w * 0.375 + r15.z;
    r17.xyzw = r19.xyzw + r17.xyzw;
    r19.xyzw = cb0[215].xyzw * r15.yyyx;
    r19.y = r19.w * 0.5 + r19.y;
    r15.xy = cb0[215].wy * r15.yx;
    r19.w = r15.y * 0.375 + r15.x;
    r15.xyzw = r19.xyzw + r18.xyzw;
    r14.w = 1;
    r18.x = dot(r16.xyzw, r14.xyzw);
    r18.y = dot(r17.xyzw, r14.xyzw);
    r18.z = dot(r15.xyzw, r14.xyzw);
    r18.xyz = max(float3(0,0,0), r18.xyz);
    r19.xyw = r18.yzx * r8.www;
    r20.xyz = float3(0.715200007,0.715200007,0.715200007) * r17.xyz;
    r20.xyz = r16.xyz * float3(0.212599993,0.212599993,0.212599993) + r20.xyz;
    r20.xyz = r15.xyz * float3(0.0722000003,0.0722000003,0.0722000003) + r20.xyz;
    r9.y = dot(r20.xyz, r20.xyz);
    r9.y = max(1.17549435e-38, r9.y);
    r9.y = rsqrt(r9.y);
    r20.xyz = r20.xyz * r9.yyy;
    r20.y = abs(r20.y);
    r20.w = 1;
    r16.x = dot(r16.xyzw, r20.xyzw);
    r16.y = dot(r17.xyzw, r20.xyzw);
    r16.z = dot(r15.xyzw, r20.xyzw);
    r15.xyz = max(float3(0,0,0), r16.xyz);
    r9.y = cmp(r19.x >= r19.y);
    r9.y = r9.y ? 1.000000 : 0;
    r16.xy = r19.yx;
    r16.zw = float2(-1,0.666666687);
    r17.xy = r18.yz * r8.ww + -r16.xy;
    r17.zw = float2(1,-1);
    r16.xyzw = r9.yyyy * r17.xyzw + r16.xyzw;
    r9.y = cmp(r19.w >= r16.x);
    r9.y = r9.y ? 1.000000 : 0;
    r19.xyz = r16.xyw;
    r16.xyw = r19.wyx;
    r16.xyzw = r16.xyzw + -r19.xyzw;
    r16.xyzw = r9.yyyy * r16.xyzw + r19.xyzw;
    r9.y = min(r16.w, r16.y);
    r9.y = r16.x + -r9.y;
    r11.w = r16.w + -r16.y;
    r12.w = r9.y * 6 + 9.99999975e-05;
    r11.w = r11.w / r12.w;
    r11.w = r16.z + r11.w;
    r11.w = frac(abs(r11.w));
    r12.w = 9.99999975e-05 + r16.x;
    r9.y = r9.y / r12.w;
    r17.xyzw = float4(-0.5,1,0.666666687,0.333333343) + r11.wwww;
    r11.w = -0.449999988 + abs(r17.x);
    r11.w = saturate(-10.000001 * r11.w);
    r12.w = r11.w * -2 + 3;
    r11.w = r11.w * r11.w;
    r11.w = r12.w * r11.w;
    r11.w = r11.w * -0.349999994 + 0.699999988;
    r16.x = saturate(r16.x);
    r11.w = r16.x * r11.w;
    r9.y = min(r11.w, r9.y);
    r11.w = 2 + -r9.y;
    r11.w = 2 / r11.w;
    r16.xyz = frac(r17.yzw);
    r16.xyz = r16.xyz * float3(6,6,6) + float3(-3,-3,-3);
    r16.xyz = saturate(float3(-1,-1,-1) + abs(r16.xyz));
    r16.xyz = float3(-1,-1,-1) + r16.xyz;
    r16.xyz = r9.yyy * r16.xyz + float3(1,1,1);
    r16.xyz = r16.xyz * r11.www;
    r9.y = max(r15.x, r15.y);
    r9.y = max(r9.y, r15.z);
    r8.w = r9.y * r8.w;
  } else {
    r16.xyz = cb0[189].xyz;
  }
  // ---------------------------------------------------------------------------
  // 5. Face material response and optional micro-normal/mask layer (inferred).
  //    t14/t15 provide the animated/detail mask path and perturb the shading
  //    normal while adjusting the material lobes.
  // ---------------------------------------------------------------------------
  r5.zw = r5.ww * r5.zz + float2(0.5,-0.75);
  r5.z = saturate(r5.z);
  r9.y = 1 + -r5.z;
  r5.z = r10.y * r9.y + r5.z;
  r5.z = r10.x * r5.z;
  r9.y = saturate(dot(r12.xyz, r2.xyz));
  r9.y = r9.y * 0.850000024 + 0.150000006;
  r9.y = 1 + -r9.y;
  r10.x = cb5[11].x + -cb5[11].y;
  r10.x = r10.z * r10.x + cb5[11].y;
  r10.x = r10.x * r5.z;
  r9.y = saturate(r10.x * r9.y);
  r10.x = 1 + -r9.y;
  r15.xyz = cb5[12].xyz * r9.yyy + r10.xxx;
  r17.xyz = r15.xyz * r3.yzw;
  r9.y = cb5[0].y * r10.y;
  r10.x = cb1[r2.w+12].z + -v2.y;
  r10.x = 0.200000003 + r10.x;
  r10.x = saturate(2.85714269 * r10.x);
  r11.w = r10.x * -2 + 3;
  r10.x = r10.x * r10.x;
  r10.x = r11.w * r10.x;
  r10.x = cb1[r2.w+12].y * r10.x;
  r10.x = max(cb1[r2.w+12].w, r10.x);
  r11.w = cb1[r2.w+12].x + r10.x;
  r11.w = cmp(0.00999999978 < r11.w);
  if (r11.w != 0) {
    r2.w = max(cb1[r2.w+12].x, r10.x);
    r10.x = cb0[102].x * 0.800000012;
    r18.y = frac(r10.x);
    r18.xz = float2(0,0);
    r18.xy = v1.xy + r18.xy;
    r19.xyzw = t14.SampleBias(s4_s, r18.xy, cb0[108].x).xyzw;
    r10.x = cb0[102].x * 0.800000012 + 0.00499999989;
    r18.w = frac(r10.x);
    r18.xy = v1.xy + r18.zw;
    r18.x = t14.SampleBias(s4_s, r18.xy, cb0[108].x).w;
    r10.x = t15.SampleBias(s4_s, v1.xy, cb0[108].x).z;
    r18.y = r19.w;
    r18.yz = r18.xy * r10.xx;
    r19.xy = r19.xy * float2(2,2) + float2(-1,-1);
    r11.w = saturate(r18.y + r18.z);
    r12.w = r11.w * r2.w;
    r14.w = r19.z * r10.x;
    r14.w = r14.w * r2.w;
    r15.w = dot(r19.xy, r19.xy);
    r15.w = min(1, r15.w);
    r15.w = 1 + -r15.w;
    r15.w = sqrt(r15.w);
    r15.w = max(1.00000002e-16, r15.w);
    r16.w = r19.y * 0.5 + 0.5;
    r16.w = saturate(1.25 * r16.w);
    r17.w = r16.w * -2 + 3;
    r16.w = r16.w * r16.w;
    r18.y = r17.w * r16.w;
    r10.x = saturate(r18.x * r10.x + -r18.z);
    r16.w = -r17.w * r16.w + 1;
    r10.x = r10.x * r16.w + r18.y;
    r16.w = -r11.w * r2.w + 1;
    r17.w = 1 + -r10.x;
    r10.x = r10.x * 0.800000012 + r17.w;
    r17.w = 0.899999976 + -r10.x;
    r10.x = r10.y * r17.w + r10.x;
    r10.x = r10.x * r12.w + r16.w;
    r3.x = r10.x * r3.x;
    r18.xyz = v4.yzx * v3.zxy;
    r18.xyz = v3.yzx * v4.zxy + -r18.xyz;
    r18.xyz = v4.www * r18.xyz;
    r18.xyz = r19.yyy * r18.xyz;
    r18.xyz = r19.xxx * v4.xyz + r18.xyz;
    r18.xyz = r15.www * v3.xyz + r18.xyz;
    r10.x = dot(r18.xyz, r18.xyz);
    r10.x = rsqrt(r10.x);
    r18.xyz = r18.xyz * r10.xxx;
    r18.xyz = r18.xyz * r5.yyy;
    r10.x = saturate(r11.w * r2.w + r14.w);
    r11.w = saturate(r12.w * 2 + r14.w);
    r2.w = r11.w * r2.w;
    r11.w = -r10.y * cb5[0].y + 3;
    r9.y = r2.w * r11.w + r9.y;
    r2.w = 0.300000012;
  } else {
    r2.w = -cb5[0].x + 1;
    r18.xyz = r12.xyz;
    r10.x = 0;
  }
  // ---------------------------------------------------------------------------
  // 6. BRDF inputs, face lookup table, and auxiliary target packing.
  //    t13 is the 1024x32 sRGB lookup strip. o1.xy stores an encoded direction;
  //    o1.w selects one of two captured material-class values.
  // ---------------------------------------------------------------------------
  r11.w = -cb5[0].z * 0.959999979 + 0.959999979;
  r19.xyz = r17.xyz * r11.www;
  r9.y = 0.0399999991 * r9.y;
  r3.yzw = r3.yzw * r15.xyz + -r9.yyy;
  r3.yzw = cb5[0].zzz * r3.yzw + r9.yyy;
  r15.xyz = t13.SampleLevel(s3_s, r9.xz, 0).xyz;
  r9.xy = float2(0.03125,0.015625) + r9.xw;
  r9.xyz = t13.SampleLevel(s3_s, r9.xy, 0).xyz;
  r4.w = r5.x * 31 + -r4.w;
  r9.xyz = r9.xyz + -r15.xyz;
  r9.xyz = r4.www * r9.xyz + r15.xyz;
  r9.xyz = r9.xyz * r11.www;
  r4.w = r2.w * r2.w;
  r4.w = max(0.0078125, r4.w);
  r5.x = max(9.99999994e-09, v5.z);
  r15.xy = v5.xy / r5.xx;
  r5.x = max(9.99999994e-09, v6.z);
  r15.zw = v6.xy / r5.xx;
  r15.xy = r15.xy + -r15.zw;
  r20.xy = float2(0.5,-0.5) * r15.xy;
  r20.xy = sqrt(abs(r20.xy));
  r20.xy = sqrt(r20.xy);
  r15.z = -r15.y;
  r15.yw = cmp(float2(0,0) < r15.xz);
  r15.xz = cmp(r15.xz < float2(0,0));
  r15.xy = (int2)-r15.yw + (int2)r15.xz;
  r15.xy = (int2)r15.xy;
  r15.xy = r20.xy * r15.xy;
  o1.xy = r15.xy * float2(0.5,0.5) + float2(0.5,0.5);
  r15.xy = cmp(float2(0.5,0.00100000005) < r10.xx);
  o1.w = r15.x ? 0.699999988 : 0.400000006;
  // ---------------------------------------------------------------------------
  // 7. Environment/indirect-light preparation (inferred).
  //    t3 supplies a screen-space two-channel term, t17 a direction/response
  //    lookup, t10 a 256x1 color ramp, and t11 a face-specific sRGB contribution.
  // ---------------------------------------------------------------------------
  r15.xzw = cb3[0].xyz + cb0[197].xyz;
  r20.xyz = cb0[187].www * r15.xzw + -cb3[0].xyz;
  r15.xzw = -cb3[3].xyz + cb0[190].xyz;
  r15.xzw = cb0[198].yyy * r15.xzw + cb3[3].xyz;
  r5.x = -cb3[3].w + 1;
  r5.x = cb0[198].w * r5.x + cb3[3].w;
  r21.xyz = r15.xzw * r5.xxx;
  r13.z = 0;
  r22.xy = t3.Load(r13.xyz).xy;
  r9.w = -1 + r22.x;
  r9.w = cb4[34].x * r9.w + 1;
  r12.w = 1 + -r9.w;
  r9.w = cb0[187].z * r12.w + r9.w;
  r22.xzw = cb0[186].zzz * r9.xyz;
  r23.xyz = float3(0.649999976,0.649999976,0.649999976) * r22.xzw;
  r24.x = dot(r20.xyz, r7.xyz);
  r24.z = dot(r20.xyz, r4.xyz);
  r24.y = 6.10351562e-05;
  r12.w = dot(r24.xyz, r24.xyz);
  r12.w = rsqrt(r12.w);
  r24.xy = r24.xz * r12.ww;
  r12.w = cmp(0 < r24.x);
  r12.w = r12.w ? 1.000000 : 0;
  const float faceSdfMirrorSelector = r12.w;
  r13.z = 1 + -v1.x;
  r14.w = v1.x + -r13.z;
  r25.x = faceSdfMirrorSelector * r14.w + r13.z;
  r25.y = v1.y;
  // t17 is the face SDF/direction guide (inferred). U was mirrored above from
  // the projected light-side sign. R+G drives the SDF threshold; B is decoded
  // into a signed face-direction guide used to construct a shading normal.
  const float2 faceSdfUV = r25.xy;
  const float4 faceSdfGuideSample = t17.SampleLevel(s5_s, faceSdfUV, 0).xyzw;
  r25.xyzw = faceSdfGuideSample;
  const float faceSdfThreshold = r25.x + r25.y;
  r13.z = faceSdfThreshold;
  const float encodedFaceDirection = r25.z;
  r14.w = -encodedFaceDirection * 2 + 1;
  r16.w = encodedFaceDirection * 2 + -1;
  r16.w = r16.w + -r14.w;
  const float signedFaceDirection = faceSdfMirrorSelector * r16.w + r14.w;
  r25.x = signedFaceDirection;
  r25.z = 1 + -abs(r25.x);
  r25.y = 6.10351562e-05;
  r12.w = dot(r25.xyz, r25.xyz);
  r12.w = rsqrt(r12.w);
  r24.xzw = r25.xyz * r12.www;
  r25.x = r7.x;
  r25.y = r8.x;
  r25.z = r4.x;
  r25.x = dot(r25.xyz, r24.xzw);
  r26.x = r7.y;
  r26.y = r8.y;
  r26.z = r4.y;
  r25.y = dot(r26.xyz, r24.xzw);
  r4.x = r7.z;
  r4.y = r8.z;
  r25.z = dot(r4.xyz, r24.xzw);
  r4.x = dot(r25.xyz, r25.xyz);
  r4.x = max(1.17549435e-38, r4.x);
  r4.x = rsqrt(r4.x);
  r4.xyz = r25.xyz * r4.xxx;
  r11.xyz = r11.xyz * r5.yyy + -r4.xyz;
  r4.xyz = r10.yyy * r11.xyz + r4.xyz;
  r5.y = dot(r4.xyz, r4.xyz);
  r5.y = rsqrt(r5.y);
  r11.xyz = r5.yyy * r4.xyz;
  r12.w = r24.y * 0.5 + -1;
  r12.w = -r24.y * r12.w + -r24.y;
  r20.w = 6.10351562e-05;
  r14.w = dot(r20.xzw, r20.xzw);
  r14.w = rsqrt(r14.w);
  r24.xz = r20.xz * r14.ww;
  r14.w = dot(cb0[6].xz, cb0[6].xz);
  r14.w = rsqrt(r14.w);
  r25.xy = cb0[6].xz * r14.ww;
  r14.w = dot(r24.xz, r25.xy);
  r14.w = saturate(-r14.w);
  r16.w = saturate(-r24.y);
  r14.w = r16.w * r14.w;
  r24.xz = -cb0[198].xy + float2(1,1);
  r14.w = r24.x * r14.w;
  r12.w = 0.5 + r12.w;
  r12.w = r14.w * r12.w + r24.y;
  r14.w = 0.5 * r12.w;
  r12.w = -r12.w * 0.5 + 0.5;
  r12.w = max(0.00100000005, r12.w);
  r12.w = min(0.999000013, r12.w);
  r16.w = cb0[201].z * 0.5;
  r17.w = -cb0[201].z * 0.5 + 0.5;
  r17.w = max(0.00100000005, r17.w);
  r17.w = min(0.999000013, r17.w);
  r18.w = 1 + -r12.w;
  r18.w = -r18.w + r12.w;
  r18.w = max(0, r18.w);
  r12.w = r12.w + r12.w;
  r12.w = min(1, r12.w);
  r12.w = r12.w + -r18.w;
  r18.w = r13.z * 0.5 + -r18.w;
  r12.w = 1 / r12.w;
  r12.w = saturate(r18.w * r12.w);
  r18.w = r12.w * -2 + 3;
  r12.w = r12.w * r12.w;
  r19.w = ceil(r14.w);
  r14.w = r19.w * r14.w;
  r12.w = -r18.w * r12.w + -r14.w;
  r12.w = abs(r12.w) * 2 + -1;
  r14.w = dot(r12.xyz, r20.xyz);
  r14.w = cb0[197].w * cb0[198].x + r14.w;
  r14.w = max(-1, r14.w);
  r14.w = min(1, r14.w);
  r14.w = r14.w + -r12.w;
  r12.w = r10.y * r14.w + r12.w;
  r24.x = r12.w * 0.5 + 0.5;
  r24.y = 0.5;
  r26.xyzw = t10.SampleLevel(s0_s, r24.xy, 0).xyzw;
  r12.w = max(r26.x, r26.y);
  r12.w = max(r12.w, r26.z);
  r14.w = min(r26.x, r26.y);
  r14.w = min(r14.w, r26.z);
  r12.w = -r14.w + r12.w;
  r5.w = saturate(-2 * r5.w);
  r14.w = r5.w * -2 + 3;
  r5.w = r5.w * r5.w;
  r5.w = r14.w * r5.w;
  r5.w = r10.z * r5.w;
  r5.w = max(r10.y, r5.w);
  r10.z = 1 + -r5.w;
  r5.w = r22.y * r5.w + r10.z;
  r10.z = 1 + -r10.y;
  r14.w = min(r5.w, r3.x);
  r14.w = min(r14.w, r26.w);
  r18.w = r5.w * r3.x;
  r14.x = dot(r14.xyz, cb0[192].xyz);
  r14.x = saturate(cb0[193].x + r14.x);
  r14.x = r14.x * cb0[193].y + cb0[193].z;
  r14.y = cb0[187].y * r14.w;
  r24.xyw = float3(1,1,1) + -r16.xyz;
  r16.xyz = r14.yyy * r24.xyw + r16.xyz;
  r14.xyz = r16.xyz * r14.xxx;
  r16.x = r8.w * 0.350000024 + 0.649999976;
  r16.yz = max(float2(1.25,0), r8.ww);
  r16.xyz = min(float3(1.5,1.75,1.5), r16.xyz);
  r16.y = r16.y + -r16.x;
  r16.x = cb0[187].x * r16.y + r16.x;
  r24.xyw = r16.xxx * r14.xyz;
  r24.xyw = cb0[186].www * r24.xyw;
  r16.x = dot(r21.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r21.xyz = r15.xzw * r5.xxx + -r16.xxx;
  r21.xyz = r14.www * r21.xyz + r16.xxx;
  r14.xyz = r16.zzz * r14.xyz;
  r15.xzw = r15.xzw * cb0[198].yyy + r24.zzz;
  r14.xyz = r14.xyz * r15.xzw + r21.xyz;
  r14.xyz = r14.xyz * cb0[186].yyy + -r24.xyw;
  r14.xyz = r9.www * r14.xyz + r24.xyw;
  r5.x = dot(r23.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r15.xzw = r22.xzw * float3(0.649999976,0.649999976,0.649999976) + -r5.xxx;
  r15.xzw = r15.xzw * float3(1.20000005,1.20000005,1.20000005) + r5.xxx;
  r5.x = r5.w * r10.y + r10.z;
  r5.x = saturate(r3.x * r5.x + r26.w);
  r16.xyz = r9.xyz * cb0[186].zzz + -r15.xzw;
  r15.xzw = r5.xxx * r16.xyz + r15.xzw;
  r16.xyz = r17.xyz * r11.www + -r15.xzw;
  r15.xzw = r14.www * r16.xyz + r15.xzw;
  r5.x = 1 + -r12.w;
  r16.xyz = r26.xyz * r12.www + r5.xxx;
  r16.xyz = r16.xyz * r15.xzw;
  r5.x = dot(r19.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r21.xyz = r17.xyz * r11.www + -r5.xxx;
  r21.xyz = r21.xyz * float3(1.20000005,1.20000005,1.20000005) + r5.xxx;
  r21.xyz = -r9.xyz * cb0[186].zzz + r21.xyz;
  r21.xyz = r18.www * r21.xyz + r22.xzw;
  r5.x = dot(r15.xzw, float3(0.212672904,0.715152204,0.0721750036));
  r12.w = dot(r16.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r12.w = max(0.00100000005, r12.w);
  r12.w = 1 / r12.w;
  r5.x = r12.w * r5.x;
  r5.x = max(0, r5.x);
  r5.x = min(1.5, r5.x);
  r15.xzw = r16.xyz * r5.xxx + -r21.xyz;
  r15.xzw = r9.www * r15.xzw + r21.xyz;
  r5.x = -r3.x * r5.w + r14.w;
  r5.x = r9.w * r5.x + r18.w;
  r12.w = r5.x * 0.5 + 0.5;
  r14.w = -cb0[186].z + 1;
  r5.x = r5.x * r14.w + cb0[186].z;
  r5.x = r12.w * r5.x;
  r16.xyz = r14.xyz * r5.xxx;
  r5.x = -0.5 + r20.y;
  r21.y = r9.w * r5.x + 0.5;
  r5.x = saturate(dot(r18.xyz, r2.xyz));
  r21.xz = cb0[6].xz;
  r12.w = dot(r21.xyz, r21.xyz);
  r12.w = max(1.17549435e-38, r12.w);
  r12.w = rsqrt(r12.w);
  r21.xyz = r21.xyz * r12.www;
  r21.xyz = r21.xyz + r21.xyz;
  r20.xyz = r20.xyz * r9.www + r21.xyz;
  r12.w = 2 + r9.w;
  r20.xyz = r2.xyz * r12.www + r20.xyz;
  r12.w = dot(r20.xyz, r20.xyz);
  r12.w = rsqrt(r12.w);
  r20.xyz = r20.xyz * r12.www;
  r12.w = dot(r18.xyz, r20.xyz);
  r14.w = r4.w * r4.w;
  r18.w = r12.w * r14.w + -r12.w;
  r12.w = r18.w * r12.w + 1;
  r12.w = r12.w * r12.w;
  r7.x = dot(r2.xyz, r7.xyz);
  r7.y = dot(r2.xyz, r8.xyz);
  r7.xy = r7.xy * cb5[16].xy + v1.xy;
  r7.xyz = t11.SampleBias(s4_s, r7.xy, cb0[108].x).xyz;
  if (r15.y != 0) {
    r8.xyz = cb0[1].xyz * r18.yyy;
    r8.xyz = cb0[0].xyz * r18.xxx + r8.xyz;
    r8.xyz = cb0[2].xyz * r18.zzz + r8.xyz;
    r8.z = dot(r8.xyz, r8.xyz);
    r8.z = rsqrt(r8.z);
    r8.xy = r8.xy * r8.zz;
    r8.xy = r8.xy * float2(0.5,0.5) + float2(0.5,0.5);
    r8.x = t15.SampleBias(s0_s, r8.xy, cb0[108].x).w;
    r5.w = r8.x * r5.w;
    r8.x = max(0.5, r8.w);
    r8.x = min(1.5, r8.x);
    r8.x = cb0[186].w * r8.x;
    r5.w = r8.x * r5.w;
    r8.x = r10.x * r10.x;
    r8.xyz = r8.xxx * r5.www;
  } else {
    r8.xyz = float3(0,0,0);
  }
  r5.w = cmp(r12.w != r14.w);
  r8.w = r14.w / r12.w;
  r5.w = r5.w ? r8.w : 1;
  r8.w = r5.x * 2 + r4.w;
  r8.w = 9.99999975e-05 + r8.w;
  r8.w = 0.5 / r8.w;
  r5.w = r5.w * r8.w + -6.10351562e-05;
  r5.w = max(0, r5.w);
  r5.w = min(20, r5.w);
  r20.xyz = r5.www * r3.yzw;
  r20.xyz = r20.xyz * r16.xyz;
  r7.xyz = r7.xyz * r16.xyz;
  r7.xyz = r20.xyz * cb0[199].www + r7.xyz;
  r7.xyz = r7.xyz + r8.xyz;
  r7.xyz = r14.xyz * r15.xzw + r7.xyz;
  r5.w = dot(r7.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r8.x = -0.5 + r5.w;
  r8.x = max(0, r8.x);
  r8.x = min(0.5, r8.x);
  r14.y = 0;
  r14.xz = cb0[195].yx;
  r8.yzw = cb0[6].zxy * r14.xyz;
  r8.yzw = cb0[6].yzx * r14.yzx + -r8.yzw;
  r10.x = dot(r8.yzw, r8.yzw);
  r10.x = rsqrt(r10.x);
  r8.yzw = r10.xxx * r8.yzw;
  r10.x = dot(r2.xyz, r11.xyz);
  r12.w = 1 + -abs(r10.x);
  r7.w = -0.899999976 + abs(r7.w);
  r7.w = saturate(9.99999809 * r7.w);
  r14.x = r7.w * -2 + 3;
  r7.w = r7.w * r7.w;
  r7.w = r14.x * r7.w;
  r8.x = r8.x * r8.x + 1;
  r7.xyz = r7.xyz + -r5.www;
  r7.xyz = r8.xxx * r7.xyz + r5.www;
  r14.xyz = cb0[195].www * float3(10,-0.600000024,-0.399999976) + float3(-3,0.800000012,0.899999976);
  r5.w = r14.z + -r14.y;
  r8.x = -r14.y + r12.w;
  r5.w = 1 / r5.w;
  r5.w = saturate(r8.x * r5.w);
  r8.x = r5.w * -2 + 3;
  r5.w = r5.w * r5.w;
  r5.w = r8.x * r5.w;
  r5.w = r5.w * r7.w;
  r8.x = dot(cb0[6].xyz, r8.yzw);
  r8.x = cmp(r8.x < -0.00999999978);
  r8.x = r8.x ? 1.000000 : 0;
  r8.x = max(r8.x, r7.w);
  r14.x = saturate(r14.x);
  r8.x = r8.x * r10.w + -r5.w;
  r5.w = r14.x * r8.x + r5.w;
  r14.xyz = cb0[194].xyz * r5.www;
  r14.xyz = cb0[194].www * r14.xyz;
  r5.w = dot(r6.xyz, r8.yzw);
  r5.w = saturate(1 + r5.w);
  r3.x = min(r5.w, r3.x);
  r3.x = min(r3.x, r22.y);
  r14.xyz = r14.xyz * r3.xxx;
  r16.xyz = r17.xyz * r11.www + float3(-0.25,-0.25,-0.25);
  r16.xyz = cb0[195].zzz * r16.xyz + float3(0.25,0.25,0.25);
  r3.x = saturate(dot(r8.yzw, r11.xyz));
  r8.xyz = r16.xyz * r3.xxx;
  r3.x = 1 + -r17.w;
  r3.x = r17.w + -r3.x;
  r3.x = max(0, r3.x);
  r5.w = r17.w + r17.w;
  r5.w = min(1, r5.w);
  r5.w = r5.w + -r3.x;
  r3.x = r13.z * 0.5 + -r3.x;
  r5.w = 1 / r5.w;
  r3.x = saturate(r5.w * r3.x);
  r5.w = r3.x * -2 + 3;
  r3.x = r3.x * r3.x;
  r8.w = ceil(r16.w);
  r8.w = r16.w * r8.w;
  r3.x = -r5.w * r3.x + -r8.w;
  r3.x = saturate(abs(r3.x) * 2 + -0.5);
  r5.w = r3.x * -2 + 3;
  r3.x = r3.x * r3.x;
  r3.x = r5.w * r3.x;
  r3.x = r3.x * r10.z;
  r16.xyz = cb0[200].xyz * r3.xxx;
  r16.xyz = cb0[200].www * r16.xyz;
  r16.xyz = r16.xyz * r19.xyz;
  r8.xyz = r14.xyz * r8.xyz + r16.xyz;
  r7.xyz = r8.xyz + r7.xyz;
  r8.xy = (uint2)r13.xy;
  r8.zw = float2(0.03125,0.03125) * r8.xy;
  r8.zw = floor(r8.zw);
  r3.x = r8.w * cb2[1].y + r8.z;
  r3.x = 8 * r3.x;
  r3.x = (int)r3.x;
  r5.w = -cb0[85].y * cb2[2].w + v0.w;
  r5.w = floor(r5.w);
  r8.z = cb2[1].w + -1;
  r8.w = max(0, r5.w);
  r8.z = min(r8.w, r8.z);
  r8.w = 8 * r8.z;
  r8.w = (int)r8.w;
  r5.w = cmp(r8.z >= r5.w);
  r8.z = (int)r8.w + asint(cb0[110].y);
  r8.w = 1 + -r9.w;
  r8.w = r8.w * -0.25 + 0.75;
  r4.xyz = r4.xyz * r5.yyy + -r6.xwz;
  r4.xyz = r10.yyy * r4.xyz + r6.xwz;
  r5.y = dot(r4.xyz, r4.xyz);
  r5.y = rsqrt(r5.y);
  r4.xyz = r5.yyy * r4.xyz;
  r14.xyz = r17.xyz * r11.www + float3(-0.5,-0.5,-0.5);
  r5.y = 0.00999999978 + -r4.w;
  r6.w = r10.y * 0.899999976 + 0.100000001;
  r6.w = 1 / r6.w;
  r9.w = cmp(cb5[0].z >= 0.5);
  r9.w = r9.w ? 1.000000 : 0;
  r16.w = 1;
  r17.xyz = r7.xyz;
  r10.y = 0;
  // ---------------------------------------------------------------------------
  // 8. Clustered/tiled direct-light loop.
  //    t0 contains per-tile light bitmasks. Each set bit selects a packed light
  //    record from cb3; up to eight 32-bit mask words are visited for this pixel.
  // ---------------------------------------------------------------------------
  while (true) {
    r11.w = cmp(7 < (int)r10.y);
    if (r11.w != 0) break;
    r11.w = (int)r3.x + (int)r10.y;
    r11.w = t0[r11.w].val[0/4];
    r13.z = (int)r8.z + (int)r10.y;
    r13.z = t0[r13.z].val[0/4];
    r11.w = (int)r11.w & (int)r13.z;
    r11.w = r5.w ? r11.w : 0;
    r13.z = (uint)r10.y << 5;
    r20.xyz = r17.xyz;
    r14.w = r11.w;
    while (true) {
      if (r14.w == 0) break;
      r15.y = firstbitlow((uint)r14.w);
      r17.w = 1 << (int)r15.y;
      r17.w = (int)r14.w ^ (int)r17.w;
      r15.y = (int)r13.z + (int)r15.y;
      // 8a. Unpack the selected light record and reject pixels outside its volume.
      bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.x = (((uint)r15.y << 3) & bitmask.x) | ((uint)1 & ~bitmask.x);
      bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.y = (((uint)r15.y << 3) & bitmask.y) | ((uint)5 & ~bitmask.y);
      bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.z = (((uint)r15.y << 3) & bitmask.z) | ((uint)6 & ~bitmask.z);
      bitmask.w = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.w = (((uint)r15.y << 3) & bitmask.w) | ((uint)7 & ~bitmask.w);
      r18.w = (uint)cb3[r21.y+6].w;
      r18.w = cmp((int)r18.w == 1);
      if (r18.w != 0) {
        r16.xyz = -cb3[r21.x+6].xyz + v2.xyz;
        r22.xyz = int3(0xffff,0xffff,0xffff) & asint(cb3[r21.y+6].xzy);
        r23.xyz = int3(0xffff,0xffff,0xffff) & asint(cb3[r21.z+6].yxz);
        r24.xyz = asuint(cb3[r21.y+6].xzy) >> int3(16,16,16);
        r25.xyz = asuint(cb3[r21.z+6].yxz) >> int3(16,16,16);
        r22.xyz = f16tof32(r22.xyz);
        r23.xyz = f16tof32(r23.xyz);
        r24.xyz = f16tof32(r24.xyz);
        r26.xyw = f16tof32(r25.yxz);
        r27.xz = r22.xz;
        r27.yw = r24.xz;
        r18.w = dot(r16.xyzw, r27.xyzw);
        r24.x = r22.y;
        r24.z = r23.y;
        r24.w = r26.x;
        r19.w = dot(r16.xyzw, r24.xyzw);
        r26.xz = r23.xz;
        r16.x = dot(r16.xyzw, r26.xyzw);
        r16.y = max(abs(r19.w), abs(r18.w));
        r16.x = max(r16.y, abs(r16.x));
        r16.y = cb3[r21.w+6].x * 0.5 + 0.5;
        r16.x = r16.x + -r16.y;
        r16.y = -cb3[r21.w+6].x * 0.5 + 0.5;
        r16.x = saturate(r16.x / r16.y);
        r16.x = 1 + -r16.x;
        r16.x = r16.x * r16.x;
      } else {
        r16.x = 1;
      }
      r16.y = cmp(r16.x < 0.00100000005);
      if (r16.y != 0) {
        r14.w = r17.w;
        continue;
      }
      r16.y = (uint)r15.y << 3;
      r16.z = cmp(cb3[r16.y+6].w < 1.5);
      if (r16.z != 0) {
        bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r16.z = (((uint)r15.y << 3) & bitmask.z) | ((uint)3 & ~bitmask.z);
        r18.w = cmp(16 == asint(cb3[r16.z+6].w));
        r19.w = cb3[r16.z+6].z + cb0[198].z;
        r19.w = cmp(r19.w < 0.5);
        r18.w = (int)r18.w | (int)r19.w;
        if (r18.w == 0) {
          bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r22.x = (((uint)r15.y << 3) & bitmask.x) | ((uint)2 & ~bitmask.x);
          bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r22.y = (((uint)r15.y << 3) & bitmask.y) | ((uint)4 & ~bitmask.y);
          r15.y = (uint)cb3[r16.y+6].w;
          r15.y = (int)r15.y & 1;
          r18.w = cmp((int)r15.y == 0);
          r18.w = ~(int)r18.w;
          r19.w = cmp(0 < cb3[r22.x+6].z);
          r18.w = r18.w ? r19.w : 0;
          r19.w = cmp(4 == asint(cb3[r16.z+6].w));
          r20.w = r15.y ? 0 : 1;
          r21.y = cb3[r22.x+6].y * 0.5 + 0.5;
          r23.z = -abs(cb3[r22.x+6].x) + r21.y;
          r23.x = cb3[r22.x+6].y + -r23.z;
          r21.y = 1 + -abs(r23.z);
          r21.y = r21.y + -abs(r23.x);
          r21.y = max(0.00048828125, r21.y);
          r22.z = cmp(cb3[r22.x+6].x >= 0);
          r23.y = r22.z ? r21.y : -r21.y;
          r21.y = dot(r23.xyz, r23.xyz);
          r21.y = rsqrt(r21.y);
          r23.xyz = r23.xyz * r21.yyy;
          r21.y = cb3[r22.y+6].y + cb3[r22.y+6].y;
          r21.y = max(0.100000001, r21.y);
          r22.z = r19.w ? 1.000000 : 0;
          r21.y = -cb3[r21.z+6].w + r21.y;
          r21.y = r22.z * r21.y + cb3[r21.z+6].w;
          r24.xyz = cb3[r21.x+6].xyz + -v2.xyz;
          r21.z = dot(r24.yzx, -r23.xyz);
          r22.z = cmp(0.5 < cb3[r22.y+6].z);
          r22.z = r19.w ? r22.z : 0;
          r22.z = r22.z ? 1.000000 : 0;
          r22.z = r22.z * r20.w;
          r25.xyz = -r23.zxy * r21.zzz + -r24.xyz;
          r24.xyz = r22.zzz * r25.xyz + r24.xyz;
          r21.z = dot(r24.xyz, r24.xyz);
          r22.z = rsqrt(r21.z);
          r25.xyz = r24.xyz * r22.zzz;
          if (r18.w != 0) {
            r26.xyz = cb3[r22.x+6].zzz * r23.zxy;
            r27.xyz = -r26.xyz * float3(0.5,0.5,0.5) + r24.xyz;
            r26.xyz = r26.xyz * float3(0.5,0.5,0.5) + r24.xyz;
            r22.z = dot(r27.xyz, r27.xyz);
            r22.w = dot(r26.xyz, r26.xyz);
            r22.zw = sqrt(r22.zw);
            r28.xyz = r25.xyz * r23.xyz;
            r28.xyz = r23.zxy * r25.yzx + -r28.xyz;
            r29.xyz = r28.xyz * r23.xyz;
            r28.xyz = r28.zxy * r23.yzx + -r29.xyz;
            r23.w = dot(r28.xyz, r28.xyz);
            r23.w = rsqrt(r23.w);
            r25.xyz = r28.xyz * r23.www;
            r23.w = dot(r27.xyz, r26.xyz);
            r23.w = r22.z * r22.w + r23.w;
            r23.w = r23.w * 0.5 + 1;
            r23.w = 1 / r23.w;
            r24.w = dot(r25.xyz, r27.xyz);
            r22.z = r24.w / r22.z;
            r24.w = dot(r25.xyz, r26.xyz);
            r22.w = r24.w / r22.w;
            r22.z = r22.z + r22.w;
            r22.z = saturate(0.5 * r22.z);
            r22.z = r23.w * r22.z;
          } else {
            r22.z = 1;
          }
          r22.w = cmp(r21.y < 0);
          if (r22.w != 0) {
            r22.w = cb3[r21.x+6].w * cb3[r21.x+6].w;
            r22.w = r22.w * r21.z;
            r22.w = -r22.w * r22.w + 1;
            r22.w = max(0, r22.w);
            r21.z = 1 + r21.z;
            r21.z = 1 / r21.z;
            r23.w = r18.w ? 1.000000 : 0;
            r24.w = r22.z + -r21.z;
            r21.z = r23.w * r24.w + r21.z;
            r22.w = r22.w * r22.w;
            r21.z = r22.w * r21.z;
          } else {
            r26.xyz = cb3[r21.x+6].www * r24.xyz;
            r22.w = dot(r26.xyz, r26.xyz);
            r22.w = min(1, r22.w);
            r22.w = 1 + -r22.w;
            r22.w = log2(r22.w);
            r21.y = r22.w * r21.y;
            r21.y = exp2(r21.y);
            r21.z = r22.z * r21.y;
          }
          r21.y = dot(r25.yzx, -r23.xyz);
          r21.y = -cb3[r22.x+6].z + r21.y;
          r21.y = saturate(cb3[r22.x+6].w * r21.y);
          r21.y = r21.y * r21.y + -1;
          r20.w = r20.w * r21.y + 1;
          r20.w = r21.z * r20.w;
          r21.y = (int)cb3[r21.w+6].w;
          r18.w = ~(int)r18.w;
          r21.z = cmp((int)r21.y >= 0);
          r18.w = r18.w ? r21.z : 0;
          // 8b. Optional light cookie/projection. t19 is the captured 4x4 sRGB
          //     fallback cookie; cb6 supplies projector transforms and atlas data.
          if (r18.w != 0) {
            if (r15.y == 0) {
              r18.w = (uint)r21.y << 2;
              r23.xyz = cb6[r18.w+33].xyw * v2.yyy;
              r23.xyz = cb6[r18.w+32].xyw * v2.xxx + r23.xyz;
              r23.xyz = cb6[r18.w+34].xyw * v2.zzz + r23.xyz;
              r23.xyz = cb6[r18.w+35].xyw + r23.xyz;
              r22.zw = saturate(r23.xy / r23.zz);
              r22.zw = r22.zw * cb6[r21.y+0].zw + cb6[r21.y+0].xy;
            } else {
              r18.w = (uint)r21.y << 2;
              r23.x = dot(-r24.xyz, cb6[r18.w+32].xyz);
              r23.y = dot(-r24.xyz, cb6[r18.w+33].xyz);
              r23.z = dot(-r24.xyz, cb6[r18.w+34].xyz);
              r18.w = cmp(abs(r23.x) < abs(r23.y));
              r18.w = r18.w ? 0.000000 : 0;
              r21.z = dot(abs(r23.xy), icb[r18.w+0].xy);
              r21.z = cmp(r21.z < abs(r23.z));
              r18.w = r21.z ? 2 : r18.w;
              r21.z = dot(r23.xyz, icb[r18.w+0].xyz);
              r21.z = cmp(r21.z < 0);
              bitmask.w = ((~(-1 << 31)) << 1) & 0xffffffff;  r18.w = (((uint)r18.w << 1) & bitmask.w) | ((uint)r21.z & ~bitmask.w);
              r21.z = (uint)r18.w >> 1;
              r21.z = dot(r23.xyz, icb[r21.z+0].xyz);
              r23.w = 0.000244140625 / cb6[r21.y+0].w;
              r23.w = 0.5 + -r23.w;
              r24.x = (uint)r18.w;
              r24.y = cmp((uint)r18.w < 2);
              r24.y = r24.y ? 0.000000 : 0;
              r23.x = dot(r23.xz, icb[r24.y+0].xz);
              r23.x = icb[r18.w+4].z * r23.x;
              r23.x = r23.x / abs(r21.z);
              r23.x = r23.x * r23.w + r24.x;
              r23.x = 0.5 + r23.x;
              r24.x = saturate(0.166666672 * r23.x);
              r23.x = -1 + (int)icb[r18.w+4].y;
              r23.x = dot(r23.yz, icb[r23.x+0].xy);
              r18.w = icb[r18.w+4].w * r23.x;
              r18.w = r18.w / abs(r21.z);
              r24.y = saturate(-r18.w * r23.w + 0.5);
              r22.zw = r24.xy * cb6[r21.y+0].zw + cb6[r21.y+0].xy;
            }
            r18.w = t19.SampleLevel(s0_s, r22.zw, 0).x;
            r20.w = r20.w * r18.w;
          }
          r16.x = r20.w * r16.x;
          r18.w = cmp(9.99999975e-05 < r16.x);
          if (r18.w != 0) {
            if (r19.w != 0) {
              r18.w = -cb3[r22.y+6].w + 1;
              r20.w = dot(r12.xyz, r25.xyz);
              r20.w = saturate(0.5 + r20.w);
              r21.y = r20.w * -2 + 3;
              r20.w = r20.w * r20.w;
              r20.w = r21.y * r20.w;
              r18.w = r20.w * cb3[r22.y+6].w + r18.w;
              r18.w = cb3[r22.y+6].x * r18.w;
              r18.w = r18.w * r16.x;
              r23.xyz = cb3[r16.y+6].xyz + -r20.xyz;
              r23.xyz = r18.www * r23.xyz + r20.xyz;
            }
            if (r19.w == 0) {
              r18.w = dot(r11.xyz, r25.xyz);
              r20.w = saturate(r18.w);
              if (cb3[r16.z+6].w != 0) {
                if (r15.y == 0) {
                  r15.y = (int)cb3[r16.z+6].x;
                } else {
                  r24.xyz = -cb3[r21.x+6].xyz + v2.xyz;
                  r26.xyz = cmp(abs(r24.yzz) < abs(r24.xxy));
                  r21.y = r26.y ? r26.x : 0;
                  r24.xyz = cmp(float3(0,0,0) < r24.xyz);
                  r21.z = asuint(cb3[r22.x+6].w) >> 24;
                  if (8 == 0) r22.z = 0; else if (8+16 < 32) {                   r22.z = (uint)cb3[r22.x+6].w << (32-(8 + 16)); r22.z = (uint)r22.z >> (32-8);                  } else r22.z = (uint)cb3[r22.x+6].w >> 16;
                  if (8 == 0) r22.w = 0; else if (8+8 < 32) {                   r22.w = (uint)cb3[r22.x+6].w << (32-(8 + 8)); r22.w = (uint)r22.w >> (32-8);                  } else r22.w = (uint)cb3[r22.x+6].w >> 8;
                  r21.z = r24.x ? r21.z : r22.z;
                  r22.x = 255 & asint(cb3[r22.x+6].w);
                  r22.x = r24.y ? r22.w : r22.x;
                  if (8 == 0) r22.z = 0; else if (8+8 < 32) {                   r22.z = (uint)cb3[r16.z+6].x << (32-(8 + 8)); r22.z = (uint)r22.z >> (32-8);                  } else r22.z = (uint)cb3[r16.z+6].x >> 8;
                  r22.w = 255 & asint(cb3[r16.z+6].x);
                  r22.z = r24.z ? r22.z : r22.w;
                  r22.x = r26.z ? r22.x : r22.z;
                  r21.y = r21.y ? r21.z : r22.x;
                  r21.z = cmp((int)r21.y < 80);
                  r15.y = r21.z ? r21.y : -1;
                }
                r21.y = cmp((int)r15.y >= 0);
                // 8c. Shadow projection and filtered comparison sampling.
                //     t2 is the 5120x4096 R16 shadow atlas. The long block below
                //     constructs a nine-tap separable PCF footprint.
                if (r21.y != 0) {
                  r21.xyz = -cb3[r21.x+6].xyz + v2.xyz;
                  r22.x = (uint)r15.y << 2;
                  r22.z = dot(r21.xyz, r21.xyz);
                  r22.z = max(1.17549435e-38, r22.z);
                  r22.z = rsqrt(r22.z);
                  r21.xyz = r22.zzz * r21.xyz;
                  r21.xyz = -r21.xyz * cb4[r15.y+288].xxx + v2.xyz;
                  r22.z = cb4[r15.y+288].y * 5;
                  r21.xyz = r12.xyz * r22.zzz + r21.xyz;
                  r24.xyzw = cb4[r22.x+65].xyzw * r21.yyyy;
                  r24.xyzw = cb4[r22.x+64].xyzw * r21.xxxx + r24.xyzw;
                  r24.xyzw = cb4[r22.x+66].xyzw * r21.zzzz + r24.xyzw;
                  r24.xyzw = cb4[r22.x+67].xyzw + r24.xyzw;
                  r21.xyz = r24.xyz / r24.www;
                  r22.xzw = cmp(float3(0,0,0) >= r21.xyz);
                  r24.xyz = cmp(r21.xyz >= float3(1,1,1));
                  r26.xy = cb4[r15.y+344].zw + -cb4[r15.y+344].xy;
                  r21.xy = r21.xy * r26.xy + cb4[r15.y+344].xy;
                  r26.xy = r21.xy * cb4[400].zw + float2(0.5,0.5);
                  r26.xy = floor(r26.xy);
                  r21.xy = r21.xy * cb4[400].zw + -r26.xy;
                  r27.xyzw = float4(0.5,1,0.5,1) + r21.xxyy;
                  r28.xyzw = r27.xxzz * r27.xxzz;
                  r26.zw = float2(1,1) + -r21.xy;
                  r27.xz = min(float2(0,0), r21.xy);
                  r29.xy = max(float2(0,0), r21.xy);
                  r30.xy = float2(0.159999996,0.159999996) * r26.zw;
                  r29.xy = -r29.xy * r29.xy + r27.yw;
                  r29.xy = float2(1,1) + r29.xy;
                  r29.xy = float2(0.159999996,0.159999996) * r29.xy;
                  r28.xz = float2(0.0799999982,0.0799999982) * r28.xz;
                  r21.xy = r28.yw * float2(0.5,0.5) + -r21.xy;
                  r31.xy = float2(0.159999996,0.159999996) * r21.xy;
                  r21.xy = -r27.xz * r27.xz + r26.zw;
                  r21.xy = float2(1,1) + r21.xy;
                  r32.xy = float2(0.159999996,0.159999996) * r21.xy;
                  r21.xy = float2(0.159999996,0.159999996) * r27.yw;
                  r31.z = r32.x;
                  r31.w = r21.x;
                  r30.z = r29.x;
                  r30.w = r28.x;
                  r27.xyzw = r31.zwxz + r30.zwxz;
                  r32.z = r31.y;
                  r32.w = r21.y;
                  r29.z = r30.y;
                  r29.w = r28.z;
                  r28.xyz = r32.zyw + r29.zyw;
                  r30.xyz = r30.xzw / r27.zwy;
                  r30.xyz = float3(-2.5,-0.5,1.5) + r30.xyz;
                  r30.xyz = cb4[400].xxx * r30.yxz;
                  r29.xyz = r29.zyw / r28.xyz;
                  r29.xyz = float3(-2.5,-0.5,1.5) + r29.xyz;
                  r29.xyz = cb4[400].yyy * r29.xyz;
                  r30.w = r29.x;
                  r31.xyzw = r26.xyxy * cb4[400].xyxy + r30.ywxw;
                  r21.xy = r26.xy * cb4[400].xy + r30.zw;
                  r29.w = r30.y;
                  r30.yw = r29.yz;
                  r32.xyzw = r26.xyxy * cb4[400].xyxy + r30.xyzy;
                  r29.xyzw = r26.xyxy * cb4[400].xyxy + r29.wywz;
                  r26.xyzw = r26.xyxy * cb4[400].xyxy + r30.xwzw;
                  r30.xyzw = r28.xxxy * r27.zwyz;
                  r23.w = t2.SampleCmpLevelZero(s2_s, r31.xy, r21.z).x;
                  r24.w = t2.SampleCmpLevelZero(s2_s, r31.zw, r21.z).x;
                  r24.w = r30.y * r24.w;
                  r23.w = r30.x * r23.w + r24.w;
                  r21.x = t2.SampleCmpLevelZero(s2_s, r21.xy, r21.z).x;
                  r21.x = r30.z * r21.x + r23.w;
                  r21.y = t2.SampleCmpLevelZero(s2_s, r29.xy, r21.z).x;
                  r21.x = r30.w * r21.y + r21.x;
                  r30.xyzw = r28.yyzz * r27.xyzw;
                  r21.y = t2.SampleCmpLevelZero(s2_s, r32.xy, r21.z).x;
                  r21.x = r30.x * r21.y + r21.x;
                  r21.y = t2.SampleCmpLevelZero(s2_s, r32.zw, r21.z).x;
                  r21.x = r30.y * r21.y + r21.x;
                  r21.y = t2.SampleCmpLevelZero(s2_s, r29.zw, r21.z).x;
                  r21.x = r30.z * r21.y + r21.x;
                  r21.y = t2.SampleCmpLevelZero(s2_s, r26.xy, r21.z).x;
                  r21.x = r30.w * r21.y + r21.x;
                  r22.xzw = (int3)r22.xzw | (int3)r24.xyz;
                  r21.y = (int)r22.z | (int)r22.x;
                  r21.y = (int)r22.w | (int)r21.y;
                  r22.x = (int)r21.z & 0x7fffffff;
                  r22.x = cmp(0x7f800000 < (uint)r22.x);
                  r21.y = (int)r21.y | (int)r22.x;
                  r22.x = r28.z * r27.y;
                  r21.z = t2.SampleCmpLevelZero(s2_s, r26.zw, r21.z).x;
                  r21.x = r22.x * r21.z + r21.x;
                  r21.x = -1 + r21.x;
                  r15.y = cb4[r15.y+288].w * r21.x + 1;
                  r15.y = r21.y ? 1 : r15.y;
                } else {
                  r21.x = dot(r6.xyz, r25.xyz);
                  r15.y = saturate(1 + r21.x);
                }
              } else {
                r15.y = 1;
              }
              if (cb3[r16.z+6].w == 0) {
                r21.xyz = cb3[r16.y+6].xyz * r16.xxx;
                r22.x = -cb3[r22.y+6].y + 1;
                r21.x = max(r21.x, r21.y);
                r21.x = max(r21.x, r21.z);
                r21.x = r21.x * r8.w;
                r21.x = max(1, r21.x);
                r21.x = 1 / r21.x;
                r21.x = r21.x * cb3[r22.y+6].y + r22.x;
                r21.xyz = cb3[r16.y+6].xyz * r21.xxx;
                r22.x = cb3[r22.y+6].x * 0.5;
                r22.z = dot(r4.xyz, r25.xyz);
                r22.z = saturate(0.5 + r22.z);
                r22.w = -cb3[r22.y+6].x * 0.5 + 1;
                r22.x = r22.z * r22.w + r22.x;
                r21.xyz = r22.xxx * r21.xyz;
                r22.xzw = r15.xzw;
                r24.xyz = r15.xzw;
                r23.w = 1;
                r24.w = 0;
              } else {
                r26.x = cmp(3 == asint(cb3[r16.z+6].w));
                if (r26.x != 0) {
                  r26.xyz = cb0[6].xyz * r25.zxy;
                  r26.xyz = cb0[6].zxy * r25.xyz + -r26.xyz;
                  r27.xyz = cb0[6].zxy * r26.xyz;
                  r26.xyz = cb0[6].yzx * r26.yzx + -r27.xyz;
                  r26.w = dot(r26.xyz, r26.xyz);
                  r26.w = rsqrt(r26.w);
                  r26.xyz = r26.xyz * r26.www;
                  r27.xyz = cb3[r22.y+6].xxx * float3(10,-0.600000024,-0.399999976) + float3(-3,0.800000012,0.899999976);
                  r26.w = r27.z + -r27.y;
                  r27.y = -r27.y + r12.w;
                  r26.w = 1 / r26.w;
                  r26.w = saturate(r27.y * r26.w);
                  r27.y = r26.w * -2 + 3;
                  r26.w = r26.w * r26.w;
                  r26.w = r27.y * r26.w;
                  r26.w = r26.w * r7.w;
                  r27.y = dot(cb0[6].xyz, -r26.xyz);
                  r27.y = cmp(r27.y < -0.00999999978);
                  r27.y = r27.y ? 1.000000 : 0;
                  r27.y = max(r27.y, r7.w);
                  r27.x = saturate(r27.x);
                  r27.y = r27.y * r10.w + -r26.w;
                  r26.w = r27.x * r27.y + r26.w;
                  r26.w = r26.w * r15.y;
                  r16.x = r26.w * r16.x;
                  r20.w = saturate(dot(r11.xyz, -r26.xyz));
                  r22.xzw = cb3[r22.y+6].yyy * r14.xyz + float3(0.5,0.5,0.5);
                  r23.w = 1;
                  r24.xyzw = float4(0,0,0,0);
                } else {
                  r26.x = cmp(1 == asint(cb3[r16.z+6].w));
                  if (r26.x != 0) {
                    r26.y = -cb3[r22.y+6].w + r25.w;
                    r26.y = saturate(-5 * r26.y);
                    r26.z = r26.y * -2 + 3;
                    r26.y = r26.y * r26.y;
                    r26.y = r26.z * r26.y;
                    r18.w = cb3[r22.y+6].x + r18.w;
                    r18.w = max(-1, r18.w);
                    r18.w = min(1, r18.w);
                    r18.w = cb3[r22.y+6].z * r10.z + r18.w;
                    r18.w = saturate(r18.w * r6.w);
                    r26.z = r18.w * -2 + 3;
                    r18.w = r18.w * r18.w;
                    r18.w = r26.z * r18.w;
                    r15.y = r18.w * r15.y;
                    r20.w = max(r26.y, r15.y);
                    r24.xyz = cb3[r22.y+6].yyy * r9.xyz;
                    r23.w = 1;
                    r24.w = 0;
                  } else {
                    r15.y = cmp(2 == asint(cb3[r16.z+6].w));
                    if (r15.y != 0) {
                      r18.w = cb3[r22.y+6].x + 0.0500000007;
                      r18.w = -r18.w + r2.w;
                      r18.w = saturate(-10 * r18.w);
                      r26.y = r18.w * -2 + 3;
                      r18.w = r18.w * r18.w;
                      r18.w = r26.y * r18.w;
                      r26.y = -cb3[r22.y+6].z + 1;
                      r26.y = r9.w * cb3[r22.y+6].z + r26.y;
                      r23.w = r26.y * r18.w;
                    } else {
                      r23.w = 1;
                    }
                    r24.w = r15.y ? cb3[r22.y+6].y : 0;
                    r24.xyz = float3(0,0,0);
                  }
                  r22.xzw = r26.xxx ? r19.xyz : 0;
                }
                r21.xyz = cb3[r16.y+6].xyz;
              }
              r15.y = cmp(3 != asint(cb3[r16.z+6].w));
              if (r15.y != 0) {
                r15.y = r24.w * r5.y + r4.w;
                r25.xyz = r0.xyz * r1.www + r25.xyz;
                r16.y = dot(r25.xyz, r25.xyz);
                r16.y = rsqrt(r16.y);
                r25.xyz = r25.xyz * r16.yyy;
                r16.y = dot(r18.xyz, r25.xyz);
                r16.z = r15.y * r15.y;
                r18.w = r16.y * r16.z + -r16.y;
                r16.y = r18.w * r16.y + 1;
                r16.y = r16.y * r16.y;
                r18.w = cmp(r16.y != r16.z);
                r16.y = r16.z / r16.y;
                r16.y = r18.w ? r16.y : 1;
                r15.y = r5.x * 2 + r15.y;
                r15.y = 9.99999975e-05 + r15.y;
                r15.y = 0.5 / r15.y;
                r15.y = r16.y * r15.y + -6.10351562e-05;
                r15.y = max(0, r15.y);
                r15.y = min(20, r15.y);
                r25.xyz = r15.yyy * r3.yzw;
                r25.xyz = r25.xyz * r23.www;
                r25.xyz = cb3[r21.w+6].zzz * r25.xyz;
              } else {
                r25.xyz = float3(0,0,0);
              }
              r16.xyz = r21.xyz * r16.xxx;
              r21.xyz = -r24.xyz + r22.xzw;
              r21.xyz = r20.www * r21.xyz + r24.xyz;
              r22.xyz = r16.xyz * r25.xyz;
              r22.xyz = r22.xyz * r20.www;
              r16.xyz = r16.xyz * r21.xyz + r22.xyz;
              r20.xyz = r20.xyz + r16.xyz;
            }
          } else {
            r19.w = 0;
          }
          r20.xyz = r19.www ? r23.xyz : r20.xyz;
        }
      }
      r14.w = r17.w;
    }
    r17.xyz = r20.xyz;
    r10.y = (int)r10.y + 1;
  }
  // ---------------------------------------------------------------------------
  // 9. Post-light face color shaping (optional saturation/tint/rim controls).
  // ---------------------------------------------------------------------------
  r0.x = cmp(0.5 < cb5[3].x);
  if (r0.x != 0) {
    r0.x = dot(r17.xyz, float3(0.212672904,0.715152204,0.0721750036));
    r3.xyz = r17.xyz + -r0.xxx;
    r0.xyz = cb5[3].zzz * r3.xyz + r0.xxx;
    r0.xyz = float3(-0.5,-0.5,-0.5) + r0.xyz;
    r0.xyz = cb5[3].www * r0.xyz + float3(0.5,0.5,0.5);
    r3.xyz = cb5[3].yyy * r0.xyz;
    r0.xyz = -r0.xyz * cb5[3].yyy + cb5[7].xyz;
    r0.xyz = cb5[7].www * r0.xyz + r3.xyz;
    r2.w = -cb5[4].x + 1;
    r10.x = saturate(r10.x);
    r3.x = 1 + -r10.x;
    r3.y = 1 + -r2.w;
    r2.w = r3.x + -r2.w;
    r3.x = 1 / r3.y;
    r2.w = saturate(r3.x * r2.w);
    r3.x = r2.w * -2 + 3;
    r2.w = r2.w * r2.w;
    r2.w = r3.x * r2.w;
    r2.w = r2.w * r5.z;
    r3.xyz = cb5[8].xyz * r2.www;
    r17.xyz = r3.xyz * cb5[4].yyy + r0.xyz;
  }
  // ---------------------------------------------------------------------------
  // 10. Height fog / aerial perspective composite (inferred).
  //     The alternate branch optionally samples t20, the captured 1x1x1 volume.
  // ---------------------------------------------------------------------------
  r0.xyz = r17.xyz / cb0[109].xxx;
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
      r13.w = 7 & asint(cb0[108].w);
      r4.xyz = mad((int3)r13.xyw, int3(0x19660d,0x19660d,0x19660d), int3(0x3c6ef35f,0x3c6ef35f,0x3c6ef35f));
      r3.w = mad((int)r4.y, (int)r4.z, (int)r4.x);
      r4.x = mad((int)r4.z, (int)r3.w, (int)r4.y);
      r4.y = mad((int)r3.w, (int)r4.x, (int)r4.z);
      r5.x = mad((int)r4.x, (int)r4.y, (int)r3.w);
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
      r5.y = mad((int)r4.y, (int)r5.x, (int)r4.x);
      r1.yz = (uint2)r5.xy >> int2(16,16);
      r1.yz = (uint2)r1.yz;
      r1.yz = r1.yz * float2(3.05180438e-05,3.05180438e-05) + float2(-1,-1);
      r1.yz = r1.yz * cb0[167].ww + r8.xy;
      r2.xy = cb0[165].xy * r1.yz;
      r1.y = v0.w * cb0[164].x + cb0[164].y;
      r1.y = log2(r1.y);
      r1.y = cb0[164].z * r1.y;
      r2.z = r1.y / cb0[163].z;
      r4.xyzw = t20.SampleLevel(s0_s, r2.xyz, 0).xyzw;
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
    r0.xyz = r0.xyz * r4.xyz + r1.xyz;
  }
  // ---------------------------------------------------------------------------
  // 11. Final outputs: o0 = lit face color with opaque alpha; o1 retains the
  //     encoded auxiliary direction/class payload assembled above.
  // ---------------------------------------------------------------------------
  o0.xyz = r0.xyz;
  o0.w = 1;
  o1.z = 1;
  return;
}
