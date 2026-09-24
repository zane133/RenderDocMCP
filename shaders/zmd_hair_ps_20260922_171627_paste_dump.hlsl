// ---- Created with 3Dmigoto v1.4.6 on Tue Sep 22 17:16:27 2026
Texture3D<float4> t18 : register(t18);

Texture2D<float4> t17 : register(t17);

Texture2D<float4> t16 : register(t16);

Texture2D<float4> t15 : register(t15);

Texture2D<float4> t14 : register(t14);

Texture2D<float4> t13 : register(t13);

Texture2D<float4> t12 : register(t12);

Texture2D<float4> t11 : register(t11);

Texture3D<float4> t10 : register(t10);

Texture3D<float4> t9 : register(t9);

Texture3D<float4> t8 : register(t8);

Texture3D<float4> t7 : register(t7);

Texture3D<float4> t6 : register(t6);

Texture3D<float4> t5 : register(t5);

Texture2D<float4> t4 : register(t4);

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

SamplerComparisonState s3_s : register(s3);

SamplerState s2_s : register(s2);

SamplerState s1_s : register(s1);

SamplerState s0_s : register(s0);

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
  float4 cb1[4093];
}

cbuffer cb0 : register(b0)
{
  float4 cb0[216];
}




// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
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
  out float4 o0 : SV_Target0,
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
    r7.xy = r4.xy;
    r4.y = r3.z;
    r4.x = r5.z;
  } else {
    r6.xy = cb1[r2.w+3].zx;
    r7.x = cb1[r2.w+0].z;
    r7.y = cb1[r2.w+1].z;
    r3.x = cb1[r2.w+0].y;
    r3.y = cb1[r2.w+1].y;
    r5.x = cb1[r2.w+0].x;
    r5.y = cb1[r2.w+1].x;
    r4.xyz = cb1[r2.w+2].xyz;
  }
  r8.xyzw = t14.SampleBias(s4_s, v1.xy, cb0[108].x).xyzw;
  r9.xyzw = t15.SampleBias(s5_s, v1.xy, cb0[108].x).xyzw;
  r8.xyzw = cb5[5].xyzw * r8.xyzw;
  r10.xyz = cb5[4].zzz * r8.xyz;
  r3.w = dot(r10.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r10.xyz = r8.xyz * cb5[4].zzz + -r3.www;
  r10.xyz = cb5[4].www * r10.xyz + r3.www;
  r11.xyzw = t16.SampleBias(s6_s, v1.xy, cb0[108].x).xyzw;
  r11.xyzw = r11.xyzw * float4(2,2,2,2) + float4(-1,-1,-1,-1);
  r3.w = dot(r11.xy, r11.xy);
  r3.w = min(1, r3.w);
  r3.w = 1 + -r3.w;
  r3.w = sqrt(r3.w);
  r3.w = max(1.00000002e-16, r3.w);
  r6.zw = cb5[0].ww * r11.xy;
  r11.xy = v1.xy * cb5[17].xy + cb5[17].zw;
  r4.w = t11.Sample(s4_s, r11.xy).x;
  r12.xz = v2.xz + -r6.yx;
  r12.y = 6.10351562e-05;
  r6.x = dot(r12.xyz, r12.xyz);
  r6.x = rsqrt(r6.x);
  r12.xyz = r12.xyz * r6.xxx;
  r13.xyz = v4.yzx * v3.zxy;
  r13.xyz = v3.yzx * v4.zxy + -r13.xyz;
  r13.xyz = v4.www * r13.xyz;
  r6.xyw = r13.xyz * r6.www;
  r6.xyz = r6.zzz * v4.xyz + r6.xyw;
  r6.xyz = r3.www * v3.xyz + r6.xyz;
  r3.w = cb5[1].y * 2 + -1;
  r3.w = v10.x ? 1 : r3.w;
  r6.w = dot(r6.xyz, r6.xyz);
  r6.w = max(1.17549435e-38, r6.w);
  r6.w = rsqrt(r6.w);
  r6.xyz = r6.xyz * r6.www;
  r6.xyz = r6.xyz * r3.www;
  r7.w = dot(v3.xyz, v3.xyz);
  r7.w = rsqrt(r7.w);
  r14.xyz = v3.xyz * r7.www;
  r14.xyz = r14.xyz * r3.www;
  r3.w = dot(r11.zw, r11.zw);
  r3.w = min(1, r3.w);
  r3.w = 1 + -r3.w;
  r3.w = sqrt(r3.w);
  r3.w = max(1.00000002e-16, r3.w);
  r11.xy = cb5[11].yy * r11.zw;
  r11.yzw = r11.yyy * r13.xyz;
  r11.xyz = r11.xxx * v4.xyz + r11.yzw;
  r11.xyz = r3.www * v3.xyz + r11.xyz;
  r3.w = dot(r11.xyz, r11.xyz);
  r3.w = rsqrt(r3.w);
  r11.xyz = r11.xyz * r3.www;
  r13.x = cb5[13].y;
  r13.yw = float2(1,0.5);
  r15.y = dot(r5.xy, r13.xy);
  r15.z = dot(r3.xy, r13.xy);
  r15.x = dot(r7.xy, r13.xy);
  r3.w = dot(r15.xyz, r15.xyz);
  r3.w = max(1.17549435e-38, r3.w);
  r3.w = rsqrt(r3.w);
  r15.xyz = r15.xyz * r3.www;
  r16.xyz = r15.xyz * r11.xyz;
  r15.xyz = r11.zxy * r15.yzx + -r16.xyz;
  r16.xyz = v4.yzx + -r15.xyz;
  r15.xyz = r9.xxx * r16.xyz + r15.xyz;
  r16.xyz = r15.xyz * r11.zxy;
  r15.xyz = r11.yzx * r15.yzx + -r16.xyz;
  r3.w = -1 + v4.w;
  r3.w = r9.x * r3.w + 1;
  r15.xyz = r15.xyz * r3.www;
  r5.z = r3.x;
  r5.w = r7.x;
  r16.x = dot(r2.xyz, r5.xzw);
  r16.z = dot(r2.xyz, r4.xyz);
  r13.x = dot(r11.xyz, r5.xzw);
  r13.y = dot(r11.xyz, r4.xyz);
  r3.w = dot(r13.xy, r13.xy);
  r3.w = rsqrt(r3.w);
  r13.xy = r13.xy * r3.ww;
  r3.w = dot(r16.xz, r16.xz);
  r3.w = rsqrt(r3.w);
  r17.xy = r16.xz * r3.ww;
  r3.w = saturate(dot(r13.xy, r17.xy));
  r3.w = log2(r3.w);
  r3.w = cb5[12].w * r3.w;
  r3.w = exp2(r3.w);
  r13.xy = cb0[82].zw * v0.xy;
  r17.xy = (uint2)v0.xy;
  r5.w = -cb0[111].x + 1;
  r5.w = cb0[198].w * r5.w + cb0[111].x;
  r5.w = cb0[109].x * r5.w;
  r7.w = cmp(cb0[187].y < 0.5);
  if (r7.w != 0) {
    r18.xyz = cb0[6].xzy * -cb0[212].www + cb0[210].xzy;
    r18.xyz = v2.xzy + -r18.xyz;
    r7.w = max(abs(r18.x), abs(r18.y));
    r7.w = -464 + r7.w;
    r7.w = saturate(0.03125 * r7.w);
    r9.x = -208 + abs(r18.z);
    r9.x = saturate(0.03125 * r9.x);
    r7.w = max(r9.x, r7.w);
    r9.x = cmp(0.000000 != cb0[210].w);
    r10.w = cmp(r7.w < 1);
    r9.x = r9.x ? r10.w : 0;
    if (r9.x != 0) {
      r18.xyz = cb0[6].xzy * -cb0[212].yyy + cb0[210].xzy;
      r18.xyz = v2.xzy + -r18.xyz;
      r9.x = max(abs(r18.x), abs(r18.y));
      r9.x = -29 + r9.x;
      r9.x = saturate(0.5 * r9.x);
      r10.w = -13 + abs(r18.z);
      r10.w = saturate(0.5 * r10.w);
      r9.x = max(r10.w, r9.x);
      r10.w = cmp(r9.x < 1);
      if (r10.w != 0) {
        r18.xyz = v2.xyz * float3(2,2,2) + float3(0.5,0.5,0.5);
        r19.xyz = cb0[211].xyz * r18.xyz;
        r19.xyz = floor(r19.xyz);
        r18.xyz = r18.xyz * cb0[211].xyz + -r19.xyz;
        r19.xyw = t5.SampleLevel(s2_s, r18.xyz, 0).yzx;
        r10.w = 1 + -r9.x;
        r11.w = cb0[211].y * 0.5;
        r12.w = -cb0[211].y * 0.5 + 1;
        r11.w = max(r18.y, r11.w);
        r11.w = min(r11.w, r12.w);
        r18.w = 0.333333343 * r11.w;
        r20.xyzw = t6.SampleLevel(s1_s, r18.xwz, 0).xyzw;
        r11.w = r20.w * r10.w + r7.w;
        r21.xyz = float3(0,0.666666687,0) + r18.xwz;
        r21.xyz = t6.SampleLevel(s1_s, r21.xyz, 0).xyz;
        r21.xyz = r21.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r21.xyz = r21.xyz * r19.yyy;
        r21.w = r19.y;
        r21.xyzw = r21.xyzw * r10.wwww;
        r18.xyz = float3(0,0.333333343,0) + r18.xwz;
        r18.xyz = t6.SampleLevel(s1_s, r18.xyz, 0).xyz;
        r18.xyz = r18.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r18.xyz = r18.xyz * r19.xxx;
        r18.w = r19.x;
        r18.xyzw = r18.xyzw * r10.wwww;
        r20.xyz = r20.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r19.xyz = r20.xyz * r19.www;
        r19.xyzw = r19.xyzw * r10.wwww;
      } else {
        r21.xyzw = float4(0,0,0,0);
        r18.xyzw = float4(0,0,0,0);
        r19.xyzw = float4(0,0,0,0);
        r11.w = r7.w;
      }
      r20.xyz = cb0[6].xzy * -cb0[212].zzz + cb0[210].xzy;
      r20.xyz = v2.xzy + -r20.xyz;
      r10.w = max(abs(r20.x), abs(r20.y));
      r10.w = -116 + r10.w;
      r10.w = saturate(0.125 * r10.w);
      r12.w = -52 + abs(r20.z);
      r12.w = saturate(0.125 * r12.w);
      r10.w = max(r12.w, r10.w);
      r12.w = cmp(r10.w < 1);
      if (r12.w != 0) {
        r20.xyz = v2.xyz * float3(0.5,0.5,0.5) + float3(0.5,0.5,0.5);
        r22.xyz = cb0[211].xyz * r20.xyz;
        r22.xyz = floor(r22.xyz);
        r20.xyz = r20.xyz * cb0[211].xyz + -r22.xyz;
        r22.xyw = t7.SampleLevel(s2_s, r20.xyz, 0).yzx;
        r12.w = 1 + -r10.w;
        r9.x = r12.w * r9.x;
        r12.w = cb0[211].y * 0.5;
        r14.w = -cb0[211].y * 0.5 + 1;
        r12.w = max(r20.y, r12.w);
        r12.w = min(r12.w, r14.w);
        r20.w = 0.333333343 * r12.w;
        r23.xyzw = t8.SampleLevel(s1_s, r20.xwz, 0).xyzw;
        r11.w = r23.w * r9.x + r11.w;
        r24.xyz = float3(0,0.666666687,0) + r20.xwz;
        r24.xyz = t8.SampleLevel(s1_s, r24.xyz, 0).xyz;
        r24.xyz = r24.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r24.xyz = r24.xyz * r22.yyy;
        r24.w = r22.y;
        r21.xyzw = r24.xyzw * r9.xxxx + r21.xyzw;
        r20.xyz = float3(0,0.333333343,0) + r20.xwz;
        r20.xyz = t8.SampleLevel(s1_s, r20.xyz, 0).xyz;
        r20.xyz = r20.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r20.xyz = r20.xyz * r22.xxx;
        r20.w = r22.x;
        r18.xyzw = r20.xyzw * r9.xxxx + r18.xyzw;
        r20.xyz = r23.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r22.xyz = r20.xyz * r22.www;
        r19.xyzw = r22.xyzw * r9.xxxx + r19.xyzw;
      }
      r9.x = cmp(0 < r10.w);
      if (r9.x != 0) {
        r20.xyz = v2.xyz * float3(0.125,0.125,0.125) + float3(0.5,0.5,0.5);
        r22.xyz = cb0[211].xyz * r20.xyz;
        r23.xyz = cb0[211].xyz * float3(0.5,0.5,0.5);
        r22.xyz = floor(r22.xyz);
        r20.xyz = r20.xyz * cb0[211].xyz + -r22.xyz;
        r22.xyz = -cb0[211].xyz * float3(0.5,0.5,0.5) + float3(1,1,1);
        r20.xyz = max(r20.xyz, r23.xyz);
        r20.xyz = min(r20.xyz, r22.xyz);
        r24.xyw = t9.SampleLevel(s2_s, r20.xyz, 0).yzx;
        r9.x = 1 + -r7.w;
        r9.x = r10.w * r9.x;
        r10.w = max(r20.y, r23.y);
        r10.w = min(r10.w, r22.y);
        r20.w = 0.333333343 * r10.w;
        r22.xyzw = t10.SampleLevel(s1_s, r20.xwz, 0).xyzw;
        r23.xyz = float3(0,0.666666687,0) + r20.xwz;
        r23.xyz = t10.SampleLevel(s1_s, r23.xyz, 0).xyz;
        r23.xyz = r23.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r23.xyz = r23.xyz * r24.yyy;
        r23.w = r24.y;
        r21.xyzw = r23.xyzw * r9.xxxx + r21.xyzw;
        r20.xyz = float3(0,0.333333343,0) + r20.xwz;
        r20.xyz = t10.SampleLevel(s1_s, r20.xyz, 0).xyz;
        r20.xyz = r20.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r20.xyz = r20.xyz * r24.xxx;
        r20.w = r24.x;
        r18.xyzw = r20.xyzw * r9.xxxx + r18.xyzw;
        r20.xyz = r22.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r24.xyz = r20.xyz * r24.www;
        r19.xyzw = r24.xyzw * r9.xxxx + r19.xyzw;
        r11.w = r22.w * r9.x + r11.w;
      }
      r9.x = saturate(r11.w * 2 + -1);
      r20.x = r9.x + -r7.w;
      r7.w = r9.x + r7.w;
      r20.y = 0.5 * r7.w;
    } else {
      r21.xyzw = float4(0,0,0,0);
      r18.xyzw = float4(0,0,0,0);
      r19.xyzw = float4(0,0,0,0);
      r20.xy = float2(0,1);
    }
    r22.xyzw = cb0[213].xyzw * r20.yyyx;
    r22.y = r22.w * 0.5 + r22.y;
    r20.zw = cb0[213].wy * r20.yx;
    r22.w = r20.w * 0.375 + r20.z;
    r19.xyzw = r22.xyzw + r19.xyzw;
    r22.xyzw = cb0[214].xyzw * r20.yyyx;
    r22.y = r22.w * 0.5 + r22.y;
    r20.zw = cb0[214].wy * r20.yx;
    r22.w = r20.w * 0.375 + r20.z;
    r18.xyzw = r22.xyzw + r18.xyzw;
    r22.xyzw = cb0[215].xyzw * r20.yyyx;
    r22.y = r22.w * 0.5 + r22.y;
    r20.xy = cb0[215].wy * r20.yx;
    r22.w = r20.y * 0.375 + r20.x;
    r20.xyzw = r22.xyzw + r21.xyzw;
    r6.w = 1;
    r21.x = dot(r19.xyzw, r6.xyzw);
    r21.y = dot(r18.xyzw, r6.xyzw);
    r21.z = dot(r20.xyzw, r6.xyzw);
    r21.xyz = max(float3(0,0,0), r21.xyz);
    r22.xyz = r21.xyz * r5.www;
    r23.xyz = float3(0.715200007,0.715200007,0.715200007) * r18.xyz;
    r23.xyz = r19.xyz * float3(0.212599993,0.212599993,0.212599993) + r23.xyz;
    r23.xyz = r20.xyz * float3(0.0722000003,0.0722000003,0.0722000003) + r23.xyz;
    r6.w = dot(r23.xyz, r23.xyz);
    r6.w = max(1.17549435e-38, r6.w);
    r6.w = rsqrt(r6.w);
    r23.xyz = r23.xyz * r6.www;
    r23.y = abs(r23.y);
    r23.w = 1;
    r19.x = dot(r19.xyzw, r23.xyzw);
    r19.y = dot(r18.xyzw, r23.xyzw);
    r19.z = dot(r20.xyzw, r23.xyzw);
    r18.xyz = max(float3(0,0,0), r19.xyz);
    r6.w = cmp(r22.y >= r22.z);
    r6.w = r6.w ? 1.000000 : 0;
    r19.xy = r22.zy;
    r19.zw = float2(-1,0.666666687);
    r20.xy = r21.yz * r5.ww + -r19.xy;
    r20.zw = float2(1,-1);
    r19.xyzw = r6.wwww * r20.xyzw + r19.xyzw;
    r6.w = cmp(r22.x >= r19.x);
    r6.w = r6.w ? 1.000000 : 0;
    r20.xyz = r19.xyw;
    r20.w = r22.x;
    r19.xyw = r20.wyx;
    r19.xyzw = r19.xyzw + -r20.xyzw;
    r19.xyzw = r6.wwww * r19.xyzw + r20.xyzw;
    r6.w = min(r19.w, r19.y);
    r6.w = r19.x + -r6.w;
    r7.w = r19.w + -r19.y;
    r9.x = r6.w * 6 + 9.99999975e-05;
    r7.w = r7.w / r9.x;
    r7.w = r19.z + r7.w;
    r7.w = frac(abs(r7.w));
    r9.x = 9.99999975e-05 + r19.x;
    r6.w = r6.w / r9.x;
    r20.xyzw = float4(-0.5,1,0.666666687,0.333333343) + r7.wwww;
    r7.w = -0.449999988 + abs(r20.x);
    r7.w = saturate(-10.000001 * r7.w);
    r9.x = r7.w * -2 + 3;
    r7.w = r7.w * r7.w;
    r7.w = r9.x * r7.w;
    r7.w = r7.w * -0.349999994 + 0.699999988;
    r19.x = saturate(r19.x);
    r7.w = r19.x * r7.w;
    r6.w = min(r7.w, r6.w);
    r7.w = 2 + -r6.w;
    r7.w = 2 / r7.w;
    r19.xyz = frac(r20.yzw);
    r19.xyz = r19.xyz * float3(6,6,6) + float3(-3,-3,-3);
    r19.xyz = saturate(float3(-1,-1,-1) + abs(r19.xyz));
    r19.xyz = float3(-1,-1,-1) + r19.xyz;
    r19.xyz = r6.www * r19.xyz + float3(1,1,1);
    r19.xyz = r19.xyz * r7.www;
    r6.w = max(r18.x, r18.y);
    r6.w = max(r6.w, r18.z);
    r5.w = r6.w * r5.w;
    r6.w = 1;
  } else {
    r23.xyz = float3(0,0,0);
    r22.xyz = float3(1,1,1);
    r19.xyz = cb0[188].xyz;
    r6.w = 0;
  }
  r7.w = cb1[r2.w+12].z + -v2.y;
  r7.w = 0.200000003 + r7.w;
  r7.w = saturate(2.85714269 * r7.w);
  r9.x = r7.w * -2 + 3;
  r7.w = r7.w * r7.w;
  r7.w = r9.x * r7.w;
  r7.w = cb1[r2.w+12].y * r7.w;
  r7.w = max(cb1[r2.w+12].w, r7.w);
  r9.x = cb1[r2.w+12].x + r7.w;
  r9.x = cmp(0.00999999978 < r9.x);
  if (r9.x != 0) {
    r2.w = max(cb1[r2.w+12].x, r7.w);
    r7.w = 1 + -r2.w;
    r9.x = r2.w * 0.800000012 + r7.w;
    r2.w = r2.w * 2 + r7.w;
    r10.xyz = r10.xyz * r9.xxx;
    r8.xyz = r9.xxx * r8.xyz;
  } else {
    r2.w = 1;
  }
  r18.xyz = float3(0.959999979,0.959999979,0.959999979) * r8.xyz;
  r7.w = 0.0399999991 * r9.y;
  r10.xyz = float3(0.959999979,0.959999979,0.959999979) * r10.xyz;
  r9.x = max(9.99999994e-09, v5.z);
  r20.xy = v5.xy / r9.xx;
  r9.x = max(9.99999994e-09, v6.z);
  r20.zw = v6.xy / r9.xx;
  r20.xy = r20.xy + -r20.zw;
  r21.xy = float2(0.5,-0.5) * r20.xy;
  r21.xy = sqrt(abs(r21.xy));
  r21.xy = sqrt(r21.xy);
  r20.z = -r20.y;
  r20.yw = cmp(float2(0,0) < r20.xz);
  r20.xz = cmp(r20.xz < float2(0,0));
  r20.xy = (int2)-r20.yw + (int2)r20.xz;
  r20.xy = (int2)r20.xy;
  r20.xy = r21.xy * r20.xy;
  o1.xy = r20.xy * float2(0.5,0.5) + float2(0.5,0.5);
  r20.xyz = cb3[0].xyz + cb0[197].xyz;
  r20.xyz = cb0[187].www * r20.xyz + -cb3[0].xyz;
  r20.w = 6.10351562e-05;
  r9.x = dot(r20.xzw, r20.xzw);
  r9.x = rsqrt(r9.x);
  r21.xyz = r20.xwz * r9.xxx;
  r24.xyz = -cb3[3].xyz + cb0[191].xyz;
  r24.xyz = cb0[198].yyy * r24.xyz + cb3[3].xyz;
  r9.x = -cb3[3].w + 1;
  r9.x = cb0[198].w * r9.x + cb3[3].w;
  r25.xyz = r24.xyz * r9.xxx;
  r17.z = 0;
  r26.xy = t4.Load(r17.xyz).xy;
  r10.w = -1 + r26.x;
  r10.w = cb4[34].x * r10.w + 1;
  r11.w = 1 + -r10.w;
  r10.w = cb0[187].z * r11.w + r10.w;
  r11.w = dot(r6.xyz, r20.xyz);
  r26.xzw = cb0[186].zzz * r10.xyz;
  r27.xyz = float3(0.649999976,0.649999976,0.649999976) * r26.xzw;
  r12.w = dot(r18.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r14.w = dot(cb0[6].xz, cb0[6].xz);
  r14.w = rsqrt(r14.w);
  r28.xy = cb0[6].xz * r14.ww;
  r14.w = dot(r21.xz, r28.xy);
  r14.w = saturate(-r14.w);
  r28.xy = -cb0[198].xy + float2(1,1);
  r15.w = r11.w * 0.5 + -1;
  r15.w = -r11.w * r15.w + -r11.w;
  r16.w = -abs(cb0[6].y) + 0.75;
  r16.w = saturate(r16.w + r16.w);
  r17.z = r16.w * -2 + 3;
  r16.w = r16.w * r16.w;
  r16.w = r17.z * r16.w;
  r16.w = r16.w * r14.w;
  r16.w = r16.w * r28.x;
  r15.w = 0.5 + r15.w;
  r11.w = r16.w * r15.w + r11.w;
  r11.w = cb0[197].w * cb0[198].x + r11.w;
  r11.w = max(-1, r11.w);
  r11.w = min(1, r11.w);
  r13.z = r11.w * 0.5 + 0.5;
  r29.xyzw = t12.SampleLevel(s1_s, r13.zw, 0).xyzw;
  r11.w = max(r29.x, r29.y);
  r11.w = max(r11.w, r29.z);
  r13.z = min(r29.x, r29.y);
  r13.z = min(r13.z, r29.z);
  r11.w = -r13.z + r11.w;
  r13.z = dot(r6.xyz, cb0[6].xyz);
  r30.x = r13.z * 0.5 + 0.5;
  r30.yw = float2(0.5,1);
  r13.z = t12.SampleLevel(s1_s, r30.xy, 0).w;
  r13.w = r26.y * r9.z;
  r15.w = min(r26.y, r9.z);
  r16.w = min(r15.w, r29.w);
  r17.z = r13.z * r13.w;
  r18.w = dot(r6.xyz, cb0[192].xyz);
  r18.w = saturate(cb0[193].x + r18.w);
  r18.w = r18.w * cb0[193].y + cb0[193].z;
  r19.w = cb0[187].y * r16.w;
  r31.xyz = float3(1,1,1) + -r19.xyz;
  r19.xyz = r19.www * r31.xyz + r19.xyz;
  r19.xyz = r19.xyz * r18.www;
  r18.w = r5.w * 0.350000024 + 0.649999976;
  r18.w = min(1.5, r18.w);
  r28.zw = max(float2(1.25,0), r5.ww);
  r28.zw = min(float2(1.75,1.5), r28.zw);
  r5.w = r28.z + -r18.w;
  r5.w = cb0[187].x * r5.w + r18.w;
  r31.xyz = r19.xyz * r5.www;
  r31.xyz = cb0[186].www * r31.xyz;
  r5.w = dot(r25.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r25.xyz = r24.xyz * r9.xxx + -r5.www;
  r25.xyz = r16.www * r25.xyz + r5.www;
  r19.xyz = r28.www * r19.xyz;
  r28.yzw = r24.xyz * cb0[198].yyy + r28.yyy;
  r19.xyz = r19.xyz * r28.yzw + r25.xyz;
  r19.xyz = r19.xyz * cb0[186].yyy + -r31.xyz;
  r19.xyz = r10.www * r19.xyz + r31.xyz;
  r5.w = dot(r27.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r25.xyz = r26.xzw * float3(0.649999976,0.649999976,0.649999976) + -r5.www;
  r25.xyz = r25.xyz * float3(1.20000005,1.20000005,1.20000005) + r5.www;
  r5.w = saturate(r13.z * r13.w + r29.w);
  r27.xyz = r10.xyz * cb0[186].zzz + -r25.xyz;
  r25.xyz = r5.www * r27.xyz + r25.xyz;
  r27.xyz = r8.xyz * float3(0.959999979,0.959999979,0.959999979) + -r25.xyz;
  r25.xyz = r16.www * r27.xyz + r25.xyz;
  r5.w = 1 + -r11.w;
  r27.xyz = r29.xyz * r11.www + r5.www;
  r27.xyz = r27.xyz * r25.xyz;
  r28.yzw = r8.xyz * float3(0.959999979,0.959999979,0.959999979) + -r12.www;
  r28.yzw = r28.yzw * float3(1.20000005,1.20000005,1.20000005) + r12.www;
  r28.yzw = -r10.xyz * cb0[186].zzz + r28.yzw;
  r26.xzw = r17.zzz * r28.yzw + r26.xzw;
  r5.w = dot(r25.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r11.w = dot(r27.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r11.w = max(0.00100000005, r11.w);
  r11.w = 1 / r11.w;
  r5.w = r11.w * r5.w;
  r5.w = max(0, r5.w);
  r5.w = min(1.5, r5.w);
  r25.xyz = r27.xyz * r5.www + -r26.xzw;
  r25.xyz = r10.www * r25.xyz + r26.xzw;
  r5.w = -r13.z * r13.w + r16.w;
  r5.w = r10.w * r5.w + r17.z;
  r11.w = -0.5 + r20.y;
  r16.y = r10.w * r11.w + 0.5;
  r5.z = r4.x;
  r5.x = dot(r5.xyz, r16.xyz);
  r3.z = r4.y;
  r5.y = dot(r3.xyz, r16.xyz);
  r7.z = r4.z;
  r5.z = dot(r7.xyz, r16.xyz);
  r3.xy = cb5[12].xy * float2(2,2) + float2(-1,-1);
  r4.xyz = r11.xyz * r3.xxx + r15.xyz;
  r3.x = dot(r4.xyz, r4.xyz);
  r3.x = rsqrt(r3.x);
  r4.xyz = r4.xyz * r3.xxx;
  r5.xyz = r5.xyz + r5.xyz;
  r5.xyz = r20.xyz * r10.www + r5.xyz;
  r3.x = dot(r5.xyz, r5.xyz);
  r3.x = rsqrt(r3.x);
  r5.xyz = r5.xyz * r3.xxx + r2.xyz;
  r3.x = dot(r5.xyz, r5.xyz);
  r3.x = max(6.10351562e-05, r3.x);
  r3.x = rsqrt(r3.x);
  r5.xyz = r5.xyz * r3.xxx;
  r3.x = dot(r4.xyz, r5.xyz);
  r3.z = -r3.x * r3.x + 1;
  r3.z = sqrt(r3.z);
  r3.z = max(9.99999975e-05, r3.z);
  r3.z = log2(r3.z);
  r3.z = 200 * r3.z;
  r3.z = exp2(r3.z);
  r7.x = saturate(r3.z * r9.y);
  r3.z = r3.w * r3.w;
  r3.x = cmp(0 < r3.x);
  r3.x = r3.x ? 1.000000 : 0;
  r7.y = r3.x * r3.z;
  r16.xyz = t13.SampleLevel(s1_s, r7.xy, 0).xyz;
  r7.xyz = r16.xyz * r7.xxx;
  r7.xyz = r7.xyz * r3.www;
  r3.x = max(r7.x, r7.y);
  r3.x = max(r3.x, r7.z);
  r16.xyz = r11.xyz * r3.yyy + r15.xyz;
  r3.y = dot(r16.xyz, r16.xyz);
  r3.y = rsqrt(r3.y);
  r16.xyz = r16.xyz * r3.yyy;
  r3.y = dot(r16.xyz, r5.xyz);
  r11.w = cb5[15].y * 2 + -1;
  r11.xyz = r11.xyz * r11.www + r15.xyz;
  r11.w = dot(r11.xyz, r11.xyz);
  r11.w = rsqrt(r11.w);
  r11.xyz = r11.xyz * r11.www;
  r5.x = dot(r11.xyz, r5.xyz);
  r5.yz = -cb5[15].wz + float2(1,1);
  r11.x = cb5[15].x * v1.x;
  r11.x = frac(r11.x);
  r11.x = -0.5 + r11.x;
  r11.x = max(0, r11.x);
  r11.x = ceil(r11.x);
  r4.w = 1 + -r4.w;
  r4.w = r4.w + -r11.x;
  r4.w = cb5[16].y * r4.w + r11.x;
  r11.x = 1 + -r5.y;
  r4.w = r4.w * r11.x + r5.y;
  r5.y = 1 + -r4.w;
  r4.w = r3.x * r5.y + r4.w;
  r5.x = -r5.x * r5.x + 1;
  r5.x = sqrt(r5.x);
  r5.xy = max(float2(9.99999975e-05,0), r5.xz);
  r5.y = 200 * r5.y;
  r5.y = trunc(r5.y);
  r5.x = log2(r5.x);
  r5.x = r5.y * r5.x;
  r5.x = exp2(r5.x);
  r4.w = -1 + r4.w;
  r4.w = r5.x * r4.w;
  r4.w = r9.y * r4.w + 1;
  r5.xyz = r25.xyz * r19.xyz;
  r11.xyz = r5.xyz * r4.www;
  r11.w = -cb5[1].z + 1;
  r11.w = r8.w * cb5[1].z + r11.w;
  r11.x = dot(r11.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r11.y = -cb5[16].x + 1;
  r11.y = r4.w * r11.y + cb5[16].x;
  r5.xyz = r5.xyz * r4.www + -r11.xxx;
  r5.xyz = r11.yyy * r5.xyz + r11.xxx;
  r7.xyz = r7.xyz * r7.www;
  r7.xyz = cb5[12].zzz * r7.xyz;
  r7.xyz = r7.xyz * r2.www;
  r3.y = -r3.y * r3.y + 1;
  r3.y = sqrt(r3.y);
  r3.y = max(9.99999975e-05, r3.y);
  r4.w = -cb5[13].x + 1;
  r4.w = max(0, r4.w);
  r4.w = 200 * r4.w;
  r4.w = trunc(r4.w);
  r3.y = log2(r3.y);
  r3.y = r4.w * r3.y;
  r3.y = exp2(r3.y);
  r3.y = r3.y * r3.w;
  r11.xyz = cb5[14].xyz * r9.www;
  r11.xyz = r11.xyz * r3.yyy;
  r11.xyz = r11.xyz * r2.www;
  r11.xyz = r3.xxx * -r11.xyz + r11.xyz;
  r7.xyz = r7.xyz * float3(5,5,5) + r11.xyz;
  r3.x = r5.w * 0.5 + 0.5;
  r3.y = -cb0[186].z + 1;
  r3.y = r5.w * r3.y + cb0[186].z;
  r3.x = r3.x * r3.y;
  r11.xyz = r19.xyz * r3.xxx;
  r7.xyz = r11.xyz * r7.xyz;
  r7.xyz = cb0[199].www * r7.xyz;
  r5.xyz = r5.xyz * r11.www + r7.xyz;
  r3.x = dot(r5.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r3.y = -0.5 + r3.x;
  r3.y = max(0, r3.y);
  r3.y = min(0.5, r3.y);
  r7.y = 0;
  r7.xz = cb0[195].yx;
  r11.xyz = cb0[6].zxy * r7.xyz;
  r7.xyz = cb0[6].yzx * r7.yzx + -r11.xyz;
  r4.w = dot(r7.xyz, r7.xyz);
  r4.w = rsqrt(r4.w);
  r7.xyz = r7.xyz * r4.www;
  r11.xy = cb0[1].xy * r6.yy;
  r11.xy = cb0[0].xy * r6.xx + r11.xy;
  r11.xy = cb0[2].xy * r6.zz + r11.xy;
  r4.w = dot(r11.xy, r11.xy);
  r4.w = rsqrt(r4.w);
  r11.xy = r11.xy * r4.ww;
  r30.z = cb0[87].y / cb0[87].x;
  r11.xy = r11.xy * r30.zw;
  r13.zw = cb0[87].zw + float2(-1,-1);
  r15.xy = -cb0[87].zw + float2(2,2);
  r4.w = dot(r21.xyz, r6.xyz);
  r5.w = dot(r2.xyz, r6.xyz);
  r9.w = 1 + -r10.w;
  r3.y = r3.y * r3.y + 1;
  r5.xyz = r5.xyz + -r3.xxx;
  r5.xyz = r3.yyy * r5.xyz + r3.xxx;
  r3.xy = cb0[195].ww * r11.xy;
  r3.xy = r3.xy * float2(0.00600000005,0.00600000005) + r13.xy;
  r3.xy = max(r3.xy, r13.zw);
  r3.xy = min(r3.xy, r15.xy);
  r3.x = t2.SampleLevel(s0_s, r3.xy, 0).x;
  r3.x = cb0[84].z * r3.x + cb0[84].w;
  r3.x = 1 / r3.x;
  r3.x = -v0.w + r3.x;
  r3.x = -0.100000001 + r3.x;
  r3.x = saturate(10 * r3.x);
  r3.y = r3.x * -2 + 3;
  r3.x = r3.x * r3.x;
  r3.x = r3.y * r3.x;
  r16.xyz = cb0[194].xyz * r3.xxx;
  r16.xyz = cb0[194].www * r16.xyz;
  r3.x = dot(r12.xyz, r7.xyz);
  r3.x = saturate(1 + r3.x);
  r3.x = min(r3.x, r9.z);
  r3.x = min(r3.x, r26.y);
  r16.xyz = r16.xyz * r3.xxx;
  r19.xyz = r8.xyz * float3(0.959999979,0.959999979,0.959999979) + float3(-0.25,-0.25,-0.25);
  r19.xyz = cb0[195].zzz * r19.xyz + float3(0.25,0.25,0.25);
  r3.x = saturate(dot(r7.xyz, r6.xyz));
  r7.xyz = r19.xyz * r3.xxx;
  r3.x = max(r22.x, r22.y);
  r3.x = max(r3.x, r22.z);
  r3.x = 0.5 * r3.x;
  r3.x = max(1, r3.x);
  r3.x = 1 / r3.x;
  r19.xyz = r22.xyz * r3.xxx;
  r20.xyz = r24.xyz * r9.xxx + -r19.xyz;
  r19.xyz = r10.www * r20.xyz + r19.xyz;
  r3.x = dot(r23.xyz, r6.xyz);
  r3.y = r3.x * r6.w;
  r9.x = r4.w * 0.5 + -1;
  r4.w = -r4.w * r9.x + 0.5;
  r3.x = -r3.x * r6.w + r4.w;
  r3.x = saturate(r10.w * r3.x + r3.y);
  r19.xyz = r19.xyz * r3.xxx;
  r3.x = r14.w * r10.w + r9.w;
  r3.x = r3.x * r28.x;
  r19.xyz = r19.xyz * r3.xxx;
  r3.x = 0.399999976 + -abs(r5.w);
  r3.x = saturate(5.00000048 * r3.x);
  r3.y = r3.x * -2 + 3;
  r3.x = r3.x * r3.x;
  r3.x = r3.y * r3.x;
  r19.xyz = r19.xyz * r3.xxx;
  r19.xyz = r19.xyz * r15.www;
  r3.x = -0.100000001 + r12.w;
  r3.x = saturate(-16.666666 * r3.x);
  r3.y = r3.x * -2 + 3;
  r3.x = r3.x * r3.x;
  r3.x = r3.y * r3.x;
  r3.x = r3.x * r10.w + r9.w;
  r19.xyz = r19.xyz * r3.xxx;
  r20.xyz = max(float3(0.150000006,0.150000006,0.150000006), r18.xyz);
  r19.xyz = r20.xyz * r19.xyz;
  r7.xyz = r16.xyz * r7.xyz + r19.xyz;
  r5.xyz = r7.xyz + r5.xyz;
  r3.xy = (uint2)r17.xy;
  r7.xy = float2(0.03125,0.03125) * r3.xy;
  r7.xy = floor(r7.xy);
  r4.w = r7.y * cb2[1].y + r7.x;
  r4.w = 8 * r4.w;
  r4.w = (int)r4.w;
  r6.w = -cb0[85].y * cb2[2].w + v0.w;
  r6.w = floor(r6.w);
  r7.x = cb2[1].w + -1;
  r7.y = max(0, r6.w);
  r7.x = min(r7.y, r7.x);
  r7.y = 8 * r7.x;
  r7.y = (int)r7.y;
  r6.w = cmp(r7.x >= r6.w);
  r7.x = (int)r7.y + asint(cb0[110].y);
  r7.y = r9.w * -0.25 + 0.75;
  r8.xyz = r8.xyz * float3(0.959999979,0.959999979,0.959999979) + float3(-0.5,-0.5,-0.5);
  r16.w = 1;
  r9.xzw = r5.xyz;
  r7.z = 0;
  while (true) {
    r10.w = cmp(7 < (int)r7.z);
    if (r10.w != 0) break;
    r10.w = (int)r4.w + (int)r7.z;
    r10.w = t0[r10.w].val[0/4];
    r11.z = (int)r7.z + (int)r7.x;
    r11.z = t0[r11.z].val[0/4];
    r10.w = (int)r10.w & (int)r11.z;
    r10.w = r6.w ? r10.w : 0;
    r11.z = (uint)r7.z << 5;
    r19.xyz = r9.xzw;
    r12.w = r10.w;
    while (true) {
      if (r12.w == 0) break;
      r14.w = firstbitlow((uint)r12.w);
      r15.z = 1 << (int)r14.w;
      r15.z = (int)r12.w ^ (int)r15.z;
      r14.w = (int)r11.z + (int)r14.w;
      bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r20.x = (((uint)r14.w << 3) & bitmask.x) | ((uint)1 & ~bitmask.x);
      bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r20.y = (((uint)r14.w << 3) & bitmask.y) | ((uint)5 & ~bitmask.y);
      bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r20.z = (((uint)r14.w << 3) & bitmask.z) | ((uint)6 & ~bitmask.z);
      bitmask.w = ((~(-1 << 29)) << 3) & 0xffffffff;  r20.w = (((uint)r14.w << 3) & bitmask.w) | ((uint)7 & ~bitmask.w);
      r15.w = (uint)cb3[r20.y+6].w;
      r15.w = cmp((int)r15.w == 1);
      if (r15.w != 0) {
        r16.xyz = -cb3[r20.x+6].xyz + v2.xyz;
        r21.xyz = int3(0xffff,0xffff,0xffff) & asint(cb3[r20.y+6].xzy);
        r22.xyz = int3(0xffff,0xffff,0xffff) & asint(cb3[r20.z+6].yxz);
        r23.xyz = asuint(cb3[r20.y+6].xzy) >> int3(16,16,16);
        r24.xyz = asuint(cb3[r20.z+6].yxz) >> int3(16,16,16);
        r21.xyz = f16tof32(r21.xyz);
        r22.xyz = f16tof32(r22.xyz);
        r23.xyz = f16tof32(r23.xyz);
        r24.xyw = f16tof32(r24.yxz);
        r26.xz = r21.xz;
        r26.yw = r23.xz;
        r15.w = dot(r16.xyzw, r26.xyzw);
        r23.x = r21.y;
        r23.z = r22.y;
        r23.w = r24.x;
        r17.z = dot(r16.xyzw, r23.xyzw);
        r24.xz = r22.xz;
        r16.x = dot(r16.xyzw, r24.xyzw);
        r15.w = max(abs(r17.z), abs(r15.w));
        r15.w = max(r15.w, abs(r16.x));
        r16.x = cb3[r20.w+6].x * 0.5 + 0.5;
        r15.w = -r16.x + r15.w;
        r16.x = -cb3[r20.w+6].x * 0.5 + 0.5;
        r15.w = saturate(r15.w / r16.x);
        r15.w = 1 + -r15.w;
        r15.w = r15.w * r15.w;
      } else {
        r15.w = 1;
      }
      r16.x = cmp(r15.w < 0.00100000005);
      if (r16.x != 0) {
        r12.w = r15.z;
        continue;
      }
      r16.x = (uint)r14.w << 3;
      r16.y = cmp(cb3[r16.x+6].w < 1.5);
      if (r16.y != 0) {
        bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r16.y = (((uint)r14.w << 3) & bitmask.y) | ((uint)3 & ~bitmask.y);
        r16.z = cmp(16 == asint(cb3[r16.y+6].w));
        r17.z = cb3[r16.y+6].z + cb0[198].z;
        r17.z = cmp(r17.z < 0.5);
        r16.z = (int)r16.z | (int)r17.z;
        if (r16.z == 0) {
          bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.x = (((uint)r14.w << 3) & bitmask.x) | ((uint)2 & ~bitmask.x);
          bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.y = (((uint)r14.w << 3) & bitmask.y) | ((uint)4 & ~bitmask.y);
          r14.w = (uint)cb3[r16.x+6].w;
          r14.w = (int)r14.w & 1;
          r16.z = cmp((int)r14.w == 0);
          r16.z = ~(int)r16.z;
          r17.z = cmp(0 < cb3[r21.x+6].z);
          r16.z = r16.z ? r17.z : 0;
          r17.z = cmp(4 == asint(cb3[r16.y+6].w));
          r18.w = r14.w ? 0 : 1;
          r19.w = cb3[r21.x+6].y * 0.5 + 0.5;
          r22.z = -abs(cb3[r21.x+6].x) + r19.w;
          r22.x = cb3[r21.x+6].y + -r22.z;
          r19.w = 1 + -abs(r22.z);
          r19.w = r19.w + -abs(r22.x);
          r19.w = max(0.00048828125, r19.w);
          r20.y = cmp(cb3[r21.x+6].x >= 0);
          r22.y = r20.y ? r19.w : -r19.w;
          r19.w = dot(r22.xyz, r22.xyz);
          r19.w = rsqrt(r19.w);
          r22.xyz = r22.xyz * r19.www;
          r19.w = cb3[r21.y+6].y + cb3[r21.y+6].y;
          r19.w = max(0.100000001, r19.w);
          r20.y = r17.z ? 1.000000 : 0;
          r19.w = -cb3[r20.z+6].w + r19.w;
          r19.w = r20.y * r19.w + cb3[r20.z+6].w;
          r23.xyz = cb3[r20.x+6].xyz + -v2.xyz;
          r20.y = dot(r23.yzx, -r22.xyz);
          r20.z = cmp(0.5 < cb3[r21.y+6].z);
          r20.z = r17.z ? r20.z : 0;
          r20.z = r20.z ? 1.000000 : 0;
          r20.z = r20.z * r18.w;
          r24.xyz = -r22.zxy * r20.yyy + -r23.xyz;
          r23.xyz = r20.zzz * r24.xyz + r23.xyz;
          r20.y = dot(r23.xyz, r23.xyz);
          r20.z = rsqrt(r20.y);
          r24.xyz = r23.xyz * r20.zzz;
          if (r16.z != 0) {
            r26.xyz = cb3[r21.x+6].zzz * r22.zxy;
            r27.xyz = -r26.xyz * float3(0.5,0.5,0.5) + r23.xyz;
            r26.xyz = r26.xyz * float3(0.5,0.5,0.5) + r23.xyz;
            r20.z = dot(r27.xyz, r27.xyz);
            r20.z = sqrt(r20.z);
            r21.z = dot(r26.xyz, r26.xyz);
            r21.z = sqrt(r21.z);
            r28.xyz = r24.xyz * r22.xyz;
            r28.xyz = r22.zxy * r24.yzx + -r28.xyz;
            r29.xyz = r28.xyz * r22.xyz;
            r28.xyz = r28.zxy * r22.yzx + -r29.xyz;
            r21.w = dot(r28.xyz, r28.xyz);
            r21.w = rsqrt(r21.w);
            r24.xyz = r28.xyz * r21.www;
            r21.w = dot(r27.xyz, r26.xyz);
            r21.w = r20.z * r21.z + r21.w;
            r21.w = r21.w * 0.5 + 1;
            r21.w = 1 / r21.w;
            r22.w = dot(r24.xyz, r27.xyz);
            r20.z = r22.w / r20.z;
            r22.w = dot(r24.xyz, r26.xyz);
            r21.z = r22.w / r21.z;
            r20.z = r21.z + r20.z;
            r20.z = saturate(0.5 * r20.z);
            r20.z = r21.w * r20.z;
          } else {
            r20.z = 1;
          }
          r21.z = cmp(r19.w < 0);
          if (r21.z != 0) {
            r21.z = cb3[r20.x+6].w * cb3[r20.x+6].w;
            r21.z = r21.z * r20.y;
            r21.z = -r21.z * r21.z + 1;
            r21.z = max(0, r21.z);
            r20.y = 1 + r20.y;
            r20.y = 1 / r20.y;
            r21.w = r16.z ? 1.000000 : 0;
            r22.w = r20.z + -r20.y;
            r20.y = r21.w * r22.w + r20.y;
            r21.z = r21.z * r21.z;
            r20.y = r21.z * r20.y;
          } else {
            r26.xyz = cb3[r20.x+6].www * r23.xyz;
            r21.z = dot(r26.xyz, r26.xyz);
            r21.z = min(1, r21.z);
            r21.z = 1 + -r21.z;
            r21.z = log2(r21.z);
            r19.w = r21.z * r19.w;
            r19.w = exp2(r19.w);
            r20.y = r20.z * r19.w;
          }
          r19.w = dot(r24.yzx, -r22.xyz);
          r19.w = -cb3[r21.x+6].z + r19.w;
          r19.w = saturate(cb3[r21.x+6].w * r19.w);
          r19.w = r19.w * r19.w + -1;
          r18.w = r18.w * r19.w + 1;
          r18.w = r20.y * r18.w;
          r19.w = (int)cb3[r20.w+6].w;
          r16.z = ~(int)r16.z;
          r20.y = cmp((int)r19.w >= 0);
          r16.z = r16.z ? r20.y : 0;
          if (r16.z != 0) {
            if (r14.w == 0) {
              r16.z = (uint)r19.w << 2;
              r22.xyz = cb6[r16.z+33].xyw * v2.yyy;
              r22.xyz = cb6[r16.z+32].xyw * v2.xxx + r22.xyz;
              r22.xyz = cb6[r16.z+34].xyw * v2.zzz + r22.xyz;
              r22.xyz = cb6[r16.z+35].xyw + r22.xyz;
              r20.yz = saturate(r22.xy / r22.zz);
              r20.yz = r20.yz * cb6[r19.w+0].zw + cb6[r19.w+0].xy;
            } else {
              r16.z = (uint)r19.w << 2;
              r22.x = dot(-r23.xyz, cb6[r16.z+32].xyz);
              r22.y = dot(-r23.xyz, cb6[r16.z+33].xyz);
              r22.z = dot(-r23.xyz, cb6[r16.z+34].xyz);
              r16.z = cmp(abs(r22.x) < abs(r22.y));
              r16.z = r16.z ? 0.000000 : 0;
              r21.z = dot(abs(r22.xy), icb[r16.z+0].xy);
              r21.z = cmp(r21.z < abs(r22.z));
              r16.z = r21.z ? 2 : r16.z;
              r21.z = dot(r22.xyz, icb[r16.z+0].xyz);
              r21.z = cmp(r21.z < 0);
              bitmask.z = ((~(-1 << 31)) << 1) & 0xffffffff;  r16.z = (((uint)r16.z << 1) & bitmask.z) | ((uint)r21.z & ~bitmask.z);
              r21.z = (uint)r16.z >> 1;
              r21.z = dot(r22.xyz, icb[r21.z+0].xyz);
              r21.w = 0.000244140625 / cb6[r19.w+0].w;
              r21.w = 0.5 + -r21.w;
              r22.w = (uint)r16.z;
              r23.x = cmp((uint)r16.z < 2);
              r23.x = r23.x ? 0.000000 : 0;
              r22.x = dot(r22.xz, icb[r23.x+0].xz);
              r22.x = icb[r16.z+4].z * r22.x;
              r22.x = r22.x / abs(r21.z);
              r22.x = r22.x * r21.w + r22.w;
              r22.x = 0.5 + r22.x;
              r23.x = saturate(0.166666672 * r22.x);
              r22.x = -1 + (int)icb[r16.z+4].y;
              r22.x = dot(r22.yz, icb[r22.x+0].xy);
              r16.z = icb[r16.z+4].w * r22.x;
              r16.z = r16.z / abs(r21.z);
              r23.y = saturate(-r16.z * r21.w + 0.5);
              r20.yz = r23.xy * cb6[r19.w+0].zw + cb6[r19.w+0].xy;
            }
            r16.z = t17.SampleLevel(s1_s, r20.yz, 0).x;
            r18.w = r18.w * r16.z;
          }
          r15.w = r18.w * r15.w;
          r16.z = cmp(9.99999975e-05 < r15.w);
          if (r16.z != 0) {
            if (r17.z != 0) {
              r16.z = -cb3[r21.y+6].w + 1;
              r18.w = dot(r14.xyz, r24.xyz);
              r18.w = saturate(0.5 + r18.w);
              r19.w = r18.w * -2 + 3;
              r18.w = r18.w * r18.w;
              r18.w = r19.w * r18.w;
              r16.z = r18.w * cb3[r21.y+6].w + r16.z;
              r16.z = cb3[r21.y+6].x * r16.z;
              r16.z = r16.z * r15.w;
              r22.xyz = cb3[r16.x+6].xyz + -r19.xyz;
              r22.xyz = r16.zzz * r22.xyz + r19.xyz;
            }
            if (r17.z == 0) {
              r16.z = dot(r6.xyz, r24.xyz);
              r18.w = saturate(r16.z);
              if (cb3[r16.y+6].w != 0) {
                if (r14.w == 0) {
                  r14.w = (int)cb3[r16.y+6].x;
                } else {
                  r23.xyz = -cb3[r20.x+6].xyz + v2.xyz;
                  r26.xyz = cmp(abs(r23.yzz) < abs(r23.xxy));
                  r19.w = r26.y ? r26.x : 0;
                  r23.xyz = cmp(float3(0,0,0) < r23.xyz);
                  r20.y = asuint(cb3[r21.x+6].w) >> 24;
                  if (8 == 0) r21.z = 0; else if (8+16 < 32) {                   r21.z = (uint)cb3[r21.x+6].w << (32-(8 + 16)); r21.z = (uint)r21.z >> (32-8);                  } else r21.z = (uint)cb3[r21.x+6].w >> 16;
                  if (8 == 0) r21.w = 0; else if (8+8 < 32) {                   r21.w = (uint)cb3[r21.x+6].w << (32-(8 + 8)); r21.w = (uint)r21.w >> (32-8);                  } else r21.w = (uint)cb3[r21.x+6].w >> 8;
                  r20.y = r23.x ? r20.y : r21.z;
                  r20.z = 255 & asint(cb3[r21.x+6].w);
                  r20.z = r23.y ? r21.w : r20.z;
                  if (8 == 0) r21.x = 0; else if (8+8 < 32) {                   r21.x = (uint)cb3[r16.y+6].x << (32-(8 + 8)); r21.x = (uint)r21.x >> (32-8);                  } else r21.x = (uint)cb3[r16.y+6].x >> 8;
                  r21.z = 255 & asint(cb3[r16.y+6].x);
                  r21.x = r23.z ? r21.x : r21.z;
                  r20.z = r26.z ? r20.z : r21.x;
                  r19.w = r19.w ? r20.y : r20.z;
                  r20.y = cmp((int)r19.w < 80);
                  r14.w = r20.y ? r19.w : -1;
                }
                r19.w = cmp((int)r14.w >= 0);
                if (r19.w != 0) {
                  r20.xyz = -cb3[r20.x+6].xyz + v2.xyz;
                  r19.w = (uint)r14.w << 2;
                  r21.x = dot(r20.xyz, r20.xyz);
                  r21.x = max(1.17549435e-38, r21.x);
                  r21.x = rsqrt(r21.x);
                  r20.xyz = r21.xxx * r20.xyz;
                  r20.xyz = -r20.xyz * cb4[r14.w+288].xxx + v2.xyz;
                  r21.x = cb4[r14.w+288].y * 5;
                  r20.xyz = r14.xyz * r21.xxx + r20.xyz;
                  r23.xyzw = cb4[r19.w+65].xyzw * r20.yyyy;
                  r23.xyzw = cb4[r19.w+64].xyzw * r20.xxxx + r23.xyzw;
                  r23.xyzw = cb4[r19.w+66].xyzw * r20.zzzz + r23.xyzw;
                  r23.xyzw = cb4[r19.w+67].xyzw + r23.xyzw;
                  r20.xyz = r23.xyz / r23.www;
                  r21.xzw = cmp(float3(0,0,0) >= r20.xyz);
                  r23.xyz = cmp(r20.xyz >= float3(1,1,1));
                  r26.xy = cb4[r14.w+344].zw + -cb4[r14.w+344].xy;
                  r20.xy = r20.xy * r26.xy + cb4[r14.w+344].xy;
                  r26.xy = r20.xy * cb4[400].zw + float2(0.5,0.5);
                  r26.xy = floor(r26.xy);
                  r20.xy = r20.xy * cb4[400].zw + -r26.xy;
                  r27.xyzw = float4(0.5,1,0.5,1) + r20.xxyy;
                  r28.xyzw = r27.xxzz * r27.xxzz;
                  r26.zw = float2(1,1) + -r20.xy;
                  r27.xz = min(float2(0,0), r20.xy);
                  r29.xy = max(float2(0,0), r20.xy);
                  r30.xy = float2(0.159999996,0.159999996) * r26.zw;
                  r29.xy = -r29.xy * r29.xy + r27.yw;
                  r29.xy = float2(1,1) + r29.xy;
                  r29.xy = float2(0.159999996,0.159999996) * r29.xy;
                  r28.xz = float2(0.0799999982,0.0799999982) * r28.xz;
                  r20.xy = r28.yw * float2(0.5,0.5) + -r20.xy;
                  r31.xy = float2(0.159999996,0.159999996) * r20.xy;
                  r20.xy = -r27.xz * r27.xz + r26.zw;
                  r20.xy = float2(1,1) + r20.xy;
                  r32.xy = float2(0.159999996,0.159999996) * r20.xy;
                  r20.xy = float2(0.159999996,0.159999996) * r27.yw;
                  r31.z = r32.x;
                  r31.w = r20.x;
                  r30.z = r29.x;
                  r30.w = r28.x;
                  r27.xyzw = r31.zwxz + r30.zwxz;
                  r32.z = r31.y;
                  r32.w = r20.y;
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
                  r20.xy = r26.xy * cb4[400].xy + r30.zw;
                  r29.w = r30.y;
                  r30.yw = r29.yz;
                  r32.xyzw = r26.xyxy * cb4[400].xyxy + r30.xyzy;
                  r29.xyzw = r26.xyxy * cb4[400].xyxy + r29.wywz;
                  r26.xyzw = r26.xyxy * cb4[400].xyxy + r30.xwzw;
                  r30.xyzw = r28.xxxy * r27.zwyz;
                  r19.w = t3.SampleCmpLevelZero(s3_s, r31.xy, r20.z).x;
                  r22.w = t3.SampleCmpLevelZero(s3_s, r31.zw, r20.z).x;
                  r22.w = r30.y * r22.w;
                  r19.w = r30.x * r19.w + r22.w;
                  r20.x = t3.SampleCmpLevelZero(s3_s, r20.xy, r20.z).x;
                  r19.w = r30.z * r20.x + r19.w;
                  r20.x = t3.SampleCmpLevelZero(s3_s, r29.xy, r20.z).x;
                  r19.w = r30.w * r20.x + r19.w;
                  r30.xyzw = r28.yyzz * r27.xyzw;
                  r20.x = t3.SampleCmpLevelZero(s3_s, r32.xy, r20.z).x;
                  r19.w = r30.x * r20.x + r19.w;
                  r20.x = t3.SampleCmpLevelZero(s3_s, r32.zw, r20.z).x;
                  r19.w = r30.y * r20.x + r19.w;
                  r20.x = t3.SampleCmpLevelZero(s3_s, r29.zw, r20.z).x;
                  r19.w = r30.z * r20.x + r19.w;
                  r20.x = t3.SampleCmpLevelZero(s3_s, r26.xy, r20.z).x;
                  r19.w = r30.w * r20.x + r19.w;
                  r21.xzw = (int3)r21.xzw | (int3)r23.xyz;
                  r20.x = (int)r21.z | (int)r21.x;
                  r20.x = (int)r21.w | (int)r20.x;
                  r20.y = (int)r20.z & 0x7fffffff;
                  r20.y = cmp(0x7f800000 < (uint)r20.y);
                  r20.x = (int)r20.y | (int)r20.x;
                  r20.y = r28.z * r27.y;
                  r20.z = t3.SampleCmpLevelZero(s3_s, r26.zw, r20.z).x;
                  r19.w = r20.y * r20.z + r19.w;
                  r19.w = -1 + r19.w;
                  r14.w = cb4[r14.w+288].w * r19.w + 1;
                  r14.w = r20.x ? 1 : r14.w;
                } else {
                  r19.w = dot(r12.xyz, r24.xyz);
                  r14.w = saturate(1 + r19.w);
                }
              } else {
                r14.w = 1;
              }
              if (cb3[r16.y+6].w == 0) {
                r20.xyz = cb3[r16.x+6].xyz * r15.www;
                r19.w = -cb3[r21.y+6].y + 1;
                r20.x = max(r20.x, r20.y);
                r20.x = max(r20.x, r20.z);
                r20.x = r20.x * r7.y;
                r20.x = max(1, r20.x);
                r20.x = 1 / r20.x;
                r19.w = r20.x * cb3[r21.y+6].y + r19.w;
                r20.xyz = cb3[r16.x+6].xyz * r19.www;
                r19.w = cb3[r21.y+6].x * 0.25;
                r21.x = saturate(0.5 + r16.z);
                r21.z = -cb3[r21.y+6].x * 0.25 + 1;
                r19.w = r21.x * r21.z + r19.w;
                r20.xyz = r20.xyz * r19.www;
                r21.xzw = r25.xyz;
                r23.xyz = r25.xyz;
              } else {
                r19.w = cmp(3 == asint(cb3[r16.y+6].w));
                if (r19.w != 0) {
                  r26.xy = cb3[r21.y+6].xx * r11.xy;
                  r26.xy = r26.xy * float2(0.00600000005,0.00600000005) + r13.xy;
                  r26.xy = max(r26.xy, r13.zw);
                  r26.xy = min(r26.xy, r15.xy);
                  r19.w = t2.SampleLevel(s0_s, r26.xy, 0).x;
                  r19.w = cb0[84].z * r19.w + cb0[84].w;
                  r19.w = 1 / r19.w;
                  r19.w = -v0.w + r19.w;
                  r19.w = -0.100000001 + r19.w;
                  r19.w = saturate(10 * r19.w);
                  r22.w = r19.w * -2 + 3;
                  r19.w = r19.w * r19.w;
                  r19.w = r22.w * r19.w;
                  r19.w = r19.w * r14.w;
                  r15.w = r19.w * r15.w;
                  r26.xyz = cb0[6].xyz * r24.zxy;
                  r26.xyz = cb0[6].zxy * r24.xyz + -r26.xyz;
                  r27.xyz = cb0[6].zxy * r26.xyz;
                  r26.xyz = cb0[6].yzx * r26.yzx + -r27.xyz;
                  r19.w = dot(r26.xyz, r26.xyz);
                  r19.w = rsqrt(r19.w);
                  r26.xyz = r26.xyz * r19.www;
                  r18.w = saturate(dot(r6.xyz, -r26.xyz));
                  r21.xzw = cb3[r21.y+6].yyy * r8.xyz + float3(0.5,0.5,0.5);
                  r23.xyz = float3(0,0,0);
                } else {
                  r19.w = cmp(1 == asint(cb3[r16.y+6].w));
                  if (r19.w != 0) {
                    r16.z = cb3[r21.y+6].x + r16.z;
                    r16.z = saturate(max(-1, r16.z));
                    r18.w = r16.z * r14.w;
                    r23.xyz = cb3[r21.y+6].yyy * r10.xyz;
                  } else {
                    r23.xyz = float3(0,0,0);
                  }
                  r21.xzw = r19.www ? r18.xyz : 0;
                }
                r20.xyz = cb3[r16.x+6].xyz;
              }
              r14.w = cmp(3 != asint(cb3[r16.y+6].w));
              if (r14.w != 0) {
                r16.xyz = r0.xyz * r1.www + r24.xyz;
                r14.w = dot(r16.xyz, r16.xyz);
                r14.w = max(6.10351562e-05, r14.w);
                r14.w = rsqrt(r14.w);
                r16.xyz = r16.xyz * r14.www;
                r14.w = dot(r4.xyz, r16.xyz);
                r16.x = -r14.w * r14.w + 1;
                r16.x = sqrt(r16.x);
                r16.x = max(9.99999975e-05, r16.x);
                r16.x = log2(r16.x);
                r16.x = 200 * r16.x;
                r16.x = exp2(r16.x);
                r16.x = saturate(r16.x * r9.y);
                r14.w = cmp(0 < r14.w);
                r14.w = r14.w ? 1.000000 : 0;
                r16.y = r14.w * r3.z;
                r24.xyz = t13.SampleLevel(s1_s, r16.xy, 0).xyz;
                r16.xyz = r24.xyz * r16.xxx;
                r16.xyz = r16.xyz * r3.www;
                r16.xyz = r16.xyz * r7.www;
                r16.xyz = cb5[12].zzz * r16.xyz;
                r16.xyz = r16.xyz * r2.www;
                r16.xyz = float3(5,5,5) * r16.xyz;
                r16.xyz = cb3[r20.w+6].zzz * r16.xyz;
              } else {
                r16.xyz = float3(0,0,0);
              }
              r20.xyz = r20.xyz * r15.www;
              r21.xyz = -r23.xyz + r21.xzw;
              r21.xyz = r18.www * r21.xyz + r23.xyz;
              r21.xyz = r21.xyz * r20.xyz;
              r16.xyz = r20.xyz * r16.xyz;
              r16.xyz = r16.xyz * r18.www;
              r16.xyz = r21.xyz * r11.www + r16.xyz;
              r19.xyz = r19.xyz + r16.xyz;
            }
          } else {
            r17.z = 0;
          }
          r19.xyz = r17.zzz ? r22.xyz : r19.xyz;
        }
      }
      r12.w = r15.z;
    }
    r9.xzw = r19.xyz;
    r7.z = (int)r7.z + 1;
  }
  r0.x = cmp(0.5 < cb5[3].x);
  if (r0.x != 0) {
    r0.x = dot(r9.xzw, float3(0.212672904,0.715152204,0.0721750036));
    r4.xyz = r9.xzw + -r0.xxx;
    r0.xyz = cb5[3].zzz * r4.xyz + r0.xxx;
    r0.xyz = float3(-0.5,-0.5,-0.5) + r0.xyz;
    r0.xyz = cb5[3].www * r0.xyz + float3(0.5,0.5,0.5);
    r4.xyz = cb5[3].yyy * r0.xyz;
    r0.xyz = -r0.xyz * cb5[3].yyy + cb5[7].xyz;
    r0.xyz = cb5[7].www * r0.xyz + r4.xyz;
    r2.w = -cb5[4].x + 1;
    r5.w = saturate(r5.w);
    r3.z = 1 + -r5.w;
    r3.w = 1 + -r2.w;
    r2.w = r3.z + -r2.w;
    r3.z = 1 / r3.w;
    r2.w = saturate(r3.z * r2.w);
    r3.z = r2.w * -2 + 3;
    r2.w = r2.w * r2.w;
    r2.w = r3.z * r2.w;
    r4.xyz = cb5[8].xyz * r2.www;
    r9.xzw = r4.xyz * cb5[4].yyy + r0.xyz;
  }
  r0.xyz = r9.xzw / cb0[109].xxx;
  r2.w = cmp(1.000000 == cb5[2].x);
  o0.w = r2.w ? r8.w : 1;
  r2.w = cmp(cb0[198].w < 0.5);
  if (r2.w != 0) {
    r0.w = r1.w * r0.w;
    r1.w = v2.y * cb0[156].w + cb0[157].w;
    r1.w = max(0.00999999978, r1.w);
    r2.w = r0.w * cb0[154].w + -cb0[153].w;
    r2.w = max(0, r2.w);
    r3.z = -1.44269502 * r1.w;
    r3.z = exp2(r3.z);
    r3.z = 1 + -r3.z;
    r1.w = r3.z / r1.w;
    r3.z = v2.y * cb0[156].w + cb0[158].w;
    r3.z = 1.44269502 * r3.z;
    r3.z = exp2(r3.z);
    r1.w = r3.z * r1.w;
    r1.w = -r2.w * r1.w;
    r4.xyz = cb0[155].xyz * r1.www;
    r4.xyz = float3(1.44269502,1.44269502,1.44269502) * r4.xyz;
    r4.xyz = exp2(r4.xyz);
    r1.w = dot(-r2.xyz, cb0[154].xyz);
    r2.w = cb0[155].w * cb0[155].w + 1;
    r3.z = dot(r1.ww, cb0[155].ww);
    r2.w = -r3.z + r2.w;
    r3.z = cmp(0 < cb0[163].z);
    if (r3.z != 0) {
      r17.w = 7 & asint(cb0[108].w);
      r5.xyz = mad((int3)r17.xyw, int3(0x19660d,0x19660d,0x19660d), int3(0x3c6ef35f,0x3c6ef35f,0x3c6ef35f));
      r3.z = mad((int)r5.y, (int)r5.z, (int)r5.x);
      r3.w = mad((int)r5.z, (int)r3.z, (int)r5.y);
      r4.w = mad((int)r3.z, (int)r3.w, (int)r5.z);
      r5.x = mad((int)r3.w, (int)r4.w, (int)r3.z);
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
      r3.z = cmp(5.96046448e-08 < abs(r2.x));
      r5.z = exp2(-r2.x);
      r5.z = 1 + -r5.z;
      r5.z = r5.z / r2.x;
      r2.x = -r2.x * 0.240226507 + 0.693147182;
      r2.x = r3.z ? r5.z : r2.x;
      r2.y = -cb0[162].z + r2.y;
      r2.y = cb0[162].x * r2.y;
      r2.y = max(-127, r2.y);
      r2.y = exp2(-r2.y);
      r2.y = cb0[162].y * r2.y;
      r3.z = cmp(5.96046448e-08 < abs(r1.y));
      r5.z = exp2(-r1.y);
      r5.z = 1 + -r5.z;
      r5.z = r5.z / r1.y;
      r1.y = -r1.y * 0.240226507 + 0.693147182;
      r1.y = r3.z ? r5.z : r1.y;
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
      r5.y = mad((int)r4.w, (int)r5.x, (int)r3.w);
      r1.yz = (uint2)r5.xy >> int2(16,16);
      r1.yz = (uint2)r1.yz;
      r1.yz = r1.yz * float2(3.05180438e-05,3.05180438e-05) + float2(-1,-1);
      r1.yz = r1.yz * cb0[167].ww + r3.xy;
      r2.xy = cb0[165].xy * r1.yz;
      r1.y = v0.w * cb0[164].x + cb0[164].y;
      r1.y = log2(r1.y);
      r1.y = cb0[164].z * r1.y;
      r2.z = r1.y / cb0[163].z;
      r3.xyzw = t18.SampleLevel(s1_s, r2.xyz, 0).xyzw;
      r1.y = -cb0[166].z + v0.w;
      r1.y = saturate(1000000 * r1.y);
      r3.xyzw = float4(-0,-0,-0,-1) + r3.xyzw;
      r3.xyzw = r1.yyyy * r3.xyzw + float4(0,0,0,1);
      r1.y = 1 + -r1.x;
      r2.xyz = cb0[161].xyz * r1.yyy;
      r2.xyz = r2.xyz * r3.www + r3.xyz;
      r1.x = r3.w * r1.x;
    } else {
      r1.y = -cb0[44].y + v2.y;
      r1.z = cb0[159].z * r1.y;
      r1.y = cb0[162].x * r1.y;
      r1.yz = max(float2(-127,-127), r1.yz);
      r3.x = -cb0[159].x + cb0[44].y;
      r3.x = cb0[159].z * r3.x;
      r3.x = max(-127, r3.x);
      r3.x = exp2(-r3.x);
      r3.x = cb0[159].y * r3.x;
      r3.y = cmp(5.96046448e-08 < abs(r1.z));
      r3.z = exp2(-r1.z);
      r3.z = 1 + -r3.z;
      r3.z = r3.z / r1.z;
      r1.z = -r1.z * 0.240226507 + 0.693147182;
      r1.z = r3.y ? r3.z : r1.z;
      r3.y = -cb0[162].z + cb0[44].y;
      r3.y = cb0[162].x * r3.y;
      r3.y = max(-127, r3.y);
      r3.y = exp2(-r3.y);
      r3.y = cb0[162].y * r3.y;
      r3.z = cmp(5.96046448e-08 < abs(r1.y));
      r3.w = exp2(-r1.y);
      r3.w = 1 + -r3.w;
      r3.w = r3.w / r1.y;
      r1.y = -r1.y * 0.240226507 + 0.693147182;
      r1.y = r3.z ? r3.w : r1.y;
      r1.y = r3.y * r1.y;
      r1.y = r3.x * r1.z + r1.y;
      r1.y = r1.y * r0.w;
      r1.y = exp2(-r1.y);
      r1.y = min(1, r1.y);
      r1.y = max(cb0[161].w, r1.y);
      r3.xy = saturate(r0.ww * cb0[160].yw + cb0[160].xz);
      r0.w = r3.x + r1.y;
      r0.w = r0.w + r3.y;
      r1.x = min(1, r0.w);
      r0.w = 1 + -r1.x;
      r2.xyz = cb0[161].xyz * r0.www;
    }
    r3.xyz = r4.xyz * r1.xxx;
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
    r4.xyz = float3(1,1,1) + -r4.xyz;
    r1.yzw = r4.xyz * r1.yzw;
    r1.xyz = r1.yzw * r1.xxx + r2.xyz;
    o0.xyz = r0.xyz * r3.xyz + r1.xyz;
  } else {
    o0.xyz = r0.xyz;
  }
  o1.zw = float2(1,0.400000006);
  return;
}
