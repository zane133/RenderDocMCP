// ---- Created with 3Dmigoto v1.4.6 on Wed Jul 29 17:39:52 2026
struct t125_t {
  float val[32];
};
StructuredBuffer<t125_t> t125 : register(t125);

Texture3D<float4> t24 : register(t24);

Texture2D<float4> t6 : register(t6);

Texture2D<float4> t5 : register(t5);

Texture2D<float4> t4 : register(t4);

Texture2DArray<float4> t3 : register(t3);

Texture2D<float4> t2 : register(t2);

Texture2D<float4> t1 : register(t1);

Texture2D<float4> t0 : register(t0);

SamplerState s15_s : register(s15);

SamplerState s14_s : register(s14);

SamplerState s8_s : register(s8);

SamplerState s0_s : register(s0);

cbuffer cb1 : register(b1)
{
  float4 cb1[15];
}

cbuffer cb0 : register(b0)
{
  float4 cb0[7];
}

cbuffer cb6 : register(b6)
{
  float4 cb6[33];
}

cbuffer cb9 : register(b9)
{
  float4 cb9[3];
}

cbuffer cb10 : register(b10)
{
  float4 cb10[1];
}

cbuffer cb13 : register(b13)
{
  float4 cb13[1];
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
  float2 v6 : TEXCOORD5,
  float w6 : TEXCOORD6,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.x = dot(-v4.xyz, -v4.xyz);
  r0.x = rsqrt(r0.x);
  r0.xyz = -v4.xyz * r0.xxx;
  r1.x = dot(v3.xyz, r0.xyz);
  r1.y = dot(v1.xyz, r0.xyz);
  r1.z = dot(v2.xyz, r0.xyz);
  r0.x = dot(r1.xyz, r1.xyz);
  r0.x = rsqrt(r0.x);
  r0.x = r1.y * r0.x;
  r0.x = min(1, abs(r0.x));
  r0.y = r0.x * -2 + 1;
  r0.x = cb1[2].w * r0.y + r0.x;
  r0.x = max(9.99999975e-05, abs(r0.x));
  r0.x = log2(r0.x);
  r0.x = cb1[3].w * r0.x;
  r0.x = exp2(r0.x);
  r0.x = -1 + r0.x;
  r0.x = cb1[4].w * r0.x + 1;
  r0.y = cb1[5].w * cb13[0].x;
  r1.x = frac(r0.y);
  r1.yw = float2(0,0);
  r0.y = t0.SampleLevel(s14_s, r1.xy, 0).x;
  r0.z = cb1[9].y + -cb1[9].x;
  r0.y = r0.y * r0.z + cb1[9].x;
  r0.y = -1 + r0.y;
  r0.z = cb1[6].w * r0.y + 1;
  r0.z = cb1[0].w * r0.z;
  r2.xyz = cb1[3].xyz + cb1[2].xyz;
  r3.xyz = cb1[7].www * cb1[4].xyz;
  r3.xyz = max(float3(0,0,0), r3.xyz);
  r3.xyz = min(cb1[8].www, r3.xyz);
  r3.xyz = -cb1[7].www + r3.xyz;
  r3.xyz = cb1[10].xxx * r3.xyz + cb1[7].www;
  r4.xyz = r3.xyz * cb1[1].zzz + -r3.xyz;
  r3.xyz = cb1[10].yyy * r4.xyz + r3.xyz;
  r3.xyz = r3.xyz + r2.xyz;
  r3.xyz = -r3.xyz + r2.xyz;
  r0.w = dot(r3.xyz, r3.xyz);
  r0.w = sqrt(r0.w);
  r3.xyz = -v5.xyz + r2.xyz;
  r1.x = dot(r3.xyz, r3.xyz);
  r1.x = sqrt(r1.x);
  r1.x = -r1.x + r0.w;
  r0.w = saturate(r1.x / r0.w);
  r0.w = max(9.99999975e-05, r0.w);
  r0.w = log2(r0.w);
  r1.x = cb1[10].z * r0.w;
  r1.x = exp2(r1.x);
  r3.xy = cb1[9].zw + -cb1[1].xy;
  r3.xy = cb1[10].ww * r3.xy + cb1[1].xy;
  r4.xyz = v5.xyz + -r2.xyz;
  r1.y = dot(r4.xyz, cb1[5].xyz);
  r2.w = dot(r2.xyz, cb1[6].xyz);
  r5.x = r2.w * r1.y;
  r1.y = dot(r4.xyz, cb1[7].xyz);
  r2.x = dot(r2.xyz, cb1[8].xyz);
  r5.y = r2.x * r1.y;
  r2.xy = cb1[11].xx * r5.xy;
  r2.xy = cb13[0].xx * r3.xy + r2.xy;
  r2.zw = v6.xy + -r2.xy;
  r2.xy = cb1[11].yy * r2.zw + r2.xy;
  r1.y = t1.Sample(s15_s, r2.xy).x;
  r1.y = max(9.99999975e-05, abs(r1.y));
  r1.y = log2(r1.y);
  r2.x = cb1[11].z * r1.y;
  r2.x = exp2(r2.x);
  r2.x = r2.x * r1.x + -r1.x;
  r2.x = cb1[11].w * r2.x + r1.x;
  r2.x = saturate(cb1[12].x * r2.x);
  r0.z = r2.x * r0.z;
  r2.x = cmp(0 < cb1[12].y);
  if (r2.x != 0) {
    r2.x = t125[cb0[6].y].val[32/4];
    r2.y = t125[cb0[6].y].val[32/4+1];
    r3.x = t125[cb0[6].y].val[48/4];
    r3.y = t125[cb0[6].y].val[48/4+1];
    r3.z = t125[cb0[6].y].val[48/4+2];
    r4.x = t125[cb0[6].y].val[4/4];
    r4.y = t125[cb0[6].y].val[4/4+1];
    r4.z = t125[cb0[6].y].val[4/4+2];
    r4.w = t125[cb0[6].y].val[4/4+3];
    r5.x = t125[cb0[6].y].val[64/4];
    r5.y = t125[cb0[6].y].val[64/4+1];
    r5.z = t125[cb0[6].y].val[64/4+2];
    r5.w = t125[cb0[6].y].val[64/4+3];
    r6.xyz = ddx_coarse(v6.xyx);
    r6.xyz = cb0[4].zwz * r6.xyz;
    r7.xyz = ddy_coarse(v6.xyx);
    r7.xyz = cb0[4].zwz * r7.xyz;
    r2.zw = frac(v6.xy);
    r2.zw = r2.zw * cb0[4].zw + cb0[4].xy;
    r8.xy = r6.zy * r4.yz;
    r4.yz = r7.zy * r4.yz;
    r6.w = dot(r8.xy, r8.xy);
    r4.y = dot(r4.yz, r4.yz);
    r4.z = max(r6.w, r4.y);
    r4.y = min(r6.w, r4.y);
    r4.z = log2(r4.z);
    r6.w = 0.5 * r4.z;
    r4.y = log2(r4.y);
    r4.y = -r4.y * 0.5 + r6.w;
    r4.x = min(r4.y, r4.x);
    r4.x = r4.z * 0.5 + -r4.x;
    r4.x = -0.5 + r4.x;
    r4.x = max(0, r4.x);
    r4.x = min(cb0[5].x, r4.x);
    r4.x = 0.5 + r4.x;
    r4.x = floor(r4.x);
    r3.w = r3.x * r3.y;
    r3.xw = r3.xw * r2.zw;
    r4.y = exp2(-r4.x);
    r3.xw = r4.yy * r3.xw;
    r3.xw = floor(r3.xw);
    r8.xy = (int2)r3.xw;
    r8.zw = (int2)r4.xx;
    r3.x = t2.Load(r8.xyz).x;
    if (10 == 0) r4.x = 0; else if (10+14 < 32) {     r4.x = (uint)r3.x << (32-(10 + 14)); r4.x = (uint)r4.x >> (32-10);    } else r4.x = (uint)r3.x >> 14;
    if (10 == 0) r4.y = 0; else if (10+4 < 32) {     r4.y = (uint)r3.x << (32-(10 + 4)); r4.y = (uint)r4.y >> (32-10);    } else r4.y = (uint)r3.x >> 4;
    if (7 == 0) r4.z = 0; else if (7+24 < 32) {     r4.z = (uint)r3.x << (32-(7 + 24)); r4.z = (uint)r4.z >> (32-7);    } else r4.z = (uint)r3.x >> 24;
    r3.x = (int)r3.x & 15;
    r3.x = (uint)r3.x;
    r8.xz = exp2(r3.xx);
    r8.y = r8.z * r3.y;
    r2.zw = r8.xy * r2.zw;
    r2.zw = frac(r2.zw);
    r3.xyw = (uint3)r4.xyz;
    r2.zw = r2.zw * r2.xy + r3.xy;
    r3.xy = r2.zw * r5.xy + r5.zw;
    r2.xyz = r8.xyz * r2.xyx;
    r2.xyz = r2.xyz * r5.xyx;
    r2.xyz = r2.xyz * r4.www;
    r4.xyz = r6.xyz * r2.xyz;
    r2.xyz = r7.xyz * r2.xyz;
    r2.x = t3.SampleGrad(s0_s, r3.xyw, r4.x, r2.x).w;
    r2.y = cmp(r3.z != 2202.000000);
    r2.x = r2.y ? 1 : r2.x;
  } else {
    r2.x = t4.Sample(s15_s, v6.xy).w;
  }
  r2.y = t5.Sample(s15_s, v6.xy).w;
  r2.z = r2.x * r2.y;
  r2.x = r2.x * r2.y + -0.00100000005;
  r2.x = cmp(r2.x < 0);
  if (r2.x != 0) discard;
  r0.z = r2.z * r0.z;
  r0.z = saturate(r0.x * r0.z);
  r2.w = cb0[6].z * r0.z;
  r0.z = cb1[12].z * r1.y;
  r0.z = exp2(r0.z);
  r0.w = cb1[12].w * r0.w;
  r0.w = exp2(r0.w);
  r0.z = cb1[13].x * r0.w + r0.z;
  r0.y = cb1[13].y * r0.y + 1;
  r3.xyz = cb1[0].xyz * r0.yyy;
  r0.y = -1 + r1.x;
  r0.y = cb1[13].z * r0.y + 1;
  r3.xyz = r3.xyz * r0.yyy;
  r0.yzw = r3.xyz * r0.zzz;
  r0.xyz = r0.yzw * r0.xxx;
  r3.xyz = cb1[13].www * r0.xyz;
  r1.z = dot(r3.xyz, float3(0.212599993,0.715200007,0.0722000003));
  r1.xyz = t6.SampleLevel(s14_s, r1.zw, 0).xyz;
  r1.xyz = r1.xyz * cb1[14].xxx + -r0.xyz;
  r0.xyz = cb1[14].yyy * r1.xyz + r0.xyz;
  r0.w = cmp(0 != cb13[0].y);
  r0.w = r0.w ? 0 : 1;
  r0.xyz = r0.xyz * r0.www;
  r0.w = cmp(cb6[25].w >= 0);
  if (r0.w != 0) {
    r1.xy = cb10[0].zw * v0.xy;
    r0.w = r1.x / cb6[32].w;
    r1.z = r1.y / cb6[22].w;
    r1.y = cmp(cb6[23].x >= w6.x);
    r3.x = cb6[23].z * w6.x + cb6[23].w;
    r3.y = cb6[24].z * w6.x + cb6[24].w;
    r3.y = log2(r3.y);
    r3.y = cb6[24].y * r3.y;
    r1.w = r1.y ? r3.x : r3.y;
    r1.y = asuint(cb9[2].z);
    r1.x = r1.y + r0.w;
    r1.xyz = float3(-0.5,-0.5,-0.5) + r1.xzw;
    r3.xyz = floor(r1.xyz);
    r1.xyz = -r3.xyz + r1.xyz;
    r4.xyz = float3(1,1,1) + -r1.xyz;
    r5.xyz = r4.xyz * r4.xyz;
    r6.xyz = r5.xyz * r4.xyz;
    r7.xyz = r1.xyz * r1.xyz;
    r8.xyz = float3(0.5,0.5,0.5) * r7.xyz;
    r9.xyz = float3(2,2,2) + -r1.xyz;
    r8.xyz = -r8.xyz * r9.xyz + float3(0.666666687,0.666666687,0.666666687);
    r5.xyz = float3(0.5,0.5,0.5) * r5.xyz;
    r4.xyz = float3(2,2,2) + -r4.xyz;
    r4.xyz = -r5.xyz * r4.xyz + float3(0.666666687,0.666666687,0.666666687);
    r1.xyz = r7.xyz * r1.xyz;
    r5.xyz = float3(0.166666672,0.166666672,0.166666672) * r1.xyz;
    r6.xyz = r6.xyz * float3(0.166666672,0.166666672,0.166666672) + r8.xyz;
    r1.xyz = r1.xyz * float3(0.166666672,0.166666672,0.166666672) + r4.xyz;
    r4.xyz = r8.xyz / r6.xyz;
    r4.xyz = r4.xyz + r3.xyz;
    r4.xyz = float3(-0.5,-0.5,-0.5) + r4.xyz;
    r4.xyz = cb6[22].xyz * r4.xyz;
    r1.xyz = r5.xyz / r1.xyz;
    r1.xyz = r1.xyz + r3.xyz;
    r1.xyz = float3(1.5,1.5,1.5) + r1.xyz;
    r1.xyz = cb6[22].xyz * r1.xyz;
    r3.xy = min(cb6[21].zw, r4.xy);
    r3.xy = max(cb6[21].xy, r3.xy);
    r3.z = r4.z;
    r5.xyzw = t24.SampleLevel(s8_s, r3.xyz, 0).xyzw;
    r1.w = r4.y;
    r7.xyzw = min(cb6[21].zwzw, r1.xwxy);
    r8.xy = max(cb6[21].xy, r7.xy);
    r8.z = r3.z;
    r9.xyzw = t24.SampleLevel(s8_s, r8.xyz, 0).xyzw;
    r5.xyzw = -r9.xyzw + r5.xyzw;
    r5.xyzw = r6.xxxx * r5.xyzw + r9.xyzw;
    r4.w = r1.y;
    r1.xy = min(cb6[21].zw, r4.xw);
    r4.xy = max(cb6[21].xy, r1.xy);
    r4.z = r8.z;
    r9.xyzw = t24.SampleLevel(s8_s, r4.xyz, 0).xyzw;
    r7.xy = max(cb6[21].xy, r7.zw);
    r7.z = r4.z;
    r10.xyzw = t24.SampleLevel(s8_s, r7.xyz, 0).xyzw;
    r9.xyzw = -r10.xyzw + r9.xyzw;
    r9.xyzw = r6.xxxx * r9.xyzw + r10.xyzw;
    r5.xyzw = -r9.xyzw + r5.xyzw;
    r5.xyzw = r6.yyyy * r5.xyzw + r9.xyzw;
    r3.w = r1.z;
    r1.xyzw = t24.SampleLevel(s8_s, r3.xyw, 0).xyzw;
    r8.w = r3.w;
    r3.xyzw = t24.SampleLevel(s8_s, r8.xyw, 0).xyzw;
    r1.xyzw = -r3.xyzw + r1.xyzw;
    r1.xyzw = r6.xxxx * r1.xyzw + r3.xyzw;
    r4.w = r8.w;
    r3.xyzw = t24.SampleLevel(s8_s, r4.xyw, 0).xyzw;
    r7.w = r4.w;
    r4.xyzw = t24.SampleLevel(s8_s, r7.xyw, 0).xyzw;
    r3.xyzw = -r4.xyzw + r3.xyzw;
    r3.xyzw = r6.xxxx * r3.xyzw + r4.xyzw;
    r1.xyzw = -r3.xyzw + r1.xyzw;
    r1.xyzw = r6.yyyy * r1.xyzw + r3.xyzw;
    r3.xyzw = r5.xyzw + -r1.xyzw;
    r1.xyzw = r6.zzzz * r3.xyzw + r1.xyzw;
    r1.xyz = float3(0.03125,0.03125,0.03125) * r1.xyz;
    r0.w = -r1.w * 3.05175781e-05 + 1;
  } else {
    r1.xyz = float3(0,0,0);
    r0.w = 1;
  }
  r2.xyz = r0.xyz * r0.www + r1.xyz;
  o0.xyzw = max(float4(0,0,0,0), r2.xyzw);
  return;
}
