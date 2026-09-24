// ---- Created with 3Dmigoto v1.4.6 on Thu Sep 24 10:19:31 2026
// RenderDoc EID 2084 — post-process pixel shader
// STEP 4: readable resources, inferred constant aliases, and stage boundaries.
// Register bindings, cbuffer packing, register math, and operation order are preserved.

Texture2D<float4> ColorInput : register(t0);
Texture2D<float4> BloomInput : register(t1);
Texture2D<float4> ColorLut   : register(t2);
SamplerState LinearSampler   : register(s0);

cbuffer PostProcessMaterial : register(b1)
{
  float4 cb1[25];
}

cbuffer FrameConstants : register(b0)
{
  float4 cb0[110];
}

// DXBC comparison mask: true -> -1.0, false -> 0.0.
float  cmp(bool  v) { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }
float3 cmp(bool3 v) { return v ? -1.0.xxx : 0.0.xxx; }
float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }

void main(
  float4 v0 : SV_Position,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_Target)
{
  float4 r0,r1,r2,r3,r4,r5,r6,r7;
  uint4 bitmask, uiDest;
  float4 fDest;

  // Inferred aliases only; original float4 array packing remains unchanged.
  float2 viewportSize        = cb0[82].xy;
  float2 inverseViewportSize = cb0[82].zw;
  float  exposure            = cb0[109].x;

  float2 vignetteCenter      = cb1[1].xy;
  float  vignetteEnable      = cb1[1].w;
  float4 vignetteShape       = cb1[2];
  float3 vignetteColor       = cb1[4].zxy;
  float4 lutParams           = cb1[7];     // xy=texel scale, z=slice count/scale, w=input scale
  float  bloomBlend          = cb1[9].x;
  float  bloomCurveMix       = cb1[9].z;
  float4 bloomThreshold      = cb1[10];
  float3 bloomTint           = cb1[11].zxy;
  float  sharpenStrength     = cb1[24].x;

  // --------------------------------------------------------------------------
  // 1. Contrast-adaptive sharpening: center plus four axial neighbours.
  //    The BGR-looking swizzles are dump register layout and remain untouched.
  // --------------------------------------------------------------------------
  r0.xyzw = ColorInput.SampleLevel(LinearSampler, v1.xy, 0).xyzw;
  r1.x = r0.x * 0.5 + r0.y;
  r1.x = r0.z * 0.5 + r1.x;
  r2.xw = float2(0,0);
  r2.yz = inverseViewportSize.yx;
  r3.xyzw = v1.xyxy + -r2.zwxy;
  r2.xyzw = v1.xyxy + r2.xyzw;
  r1.yzw = ColorInput.SampleLevel(LinearSampler, r3.xy, 0).xyz;
  r3.xyz = ColorInput.SampleLevel(LinearSampler, r3.zw, 0).xyz;
  r3.w = r1.y * 0.5 + r1.z;
  r3.w = r1.w * 0.5 + r3.w;
  r4.x = max(r3.w, r1.x);
  r4.yzw = ColorInput.SampleLevel(LinearSampler, r2.xy, 0).xyz;
  r2.xyz = ColorInput.SampleLevel(LinearSampler, r2.zw, 0).xyz;
  r2.w = r4.y * 0.5 + r4.z;
  r2.w = r4.w * 0.5 + r2.w;
  r4.x = max(r2.w, r4.x);
  r5.x = r2.x * 0.5 + r2.y;
  r5.x = r2.z * 0.5 + r5.x;
  r5.y = r3.x * 0.5 + r3.y;
  r5.y = r3.z * 0.5 + r5.y;
  r5.z = max(r5.x, r5.y);
  r4.x = max(r5.z, r4.x);
  r5.z = min(r3.w, r1.x);
  r3.w = r2.w + r3.w;
  r2.w = min(r5.z, r2.w);
  r3.w = r3.w + r5.x;
  r5.x = min(r5.x, r5.y);
  r3.w = r3.w + r5.y;
  r1.x = r3.w * 0.25 + -r1.x;
  r2.w = min(r5.x, r2.w);
  r2.w = r4.x + -r2.w;
  r2.w = 1 / r2.w;
  r1.x = saturate(r2.w * abs(r1.x));
  r1.x = r1.x * -0.5 + 1;
  r5.xyz = max(r2.xyz, r1.yzw);
  r5.xyz = max(r5.xyz, r4.yzw);
  r5.xyz = max(r5.xyz, r3.xyz);
  r6.xyz = float3(0.25,0.25,0.25) / r5.xyz;
  r5.xyz = float3(1,1,1) + -r5.xyz;
  r7.xyz = min(r2.xyz, r1.yzw);
  r1.yzw = r4.wyz + r1.wyz;
  r4.xyz = min(r7.xyz, r4.yzw);
  r4.xyz = min(r4.xyz, r3.xyz);
  r1.yzw = r1.yzw + r3.zxy;
  r1.yzw = r1.yzw + r2.zxy;
  r2.xyz = r4.xyz * r6.xyz;
  r3.xyz = r4.xyz * float3(4,4,4) + float3(-4,-4,-4);
  r3.xyz = float3(1,1,1) / r3.xyz;
  r3.xyz = r5.xyz * r3.xyz;
  r2.xyz = max(r3.xyz, -r2.xyz);
  r2.y = max(r2.y, r2.z);
  r2.x = max(r2.x, r2.y);
  r2.x = min(0, r2.x);
  r2.x = max(-0.1875, r2.x);
  r2.x = sharpenStrength * r2.x;
  r1.x = r2.x * r1.x;
  r0.xyz = r1.xxx * r1.yzw + r0.zxy;
  r1.x = r1.x * 4 + 1;
  r1.x = 1 / r1.x;
  r0.xyz = r1.xxx * r0.xyz;
  o0.w = min(1, r0.w);

  // --------------------------------------------------------------------------
  // 2. Exposure, soft-knee highlight extraction, and bloom composition.
  // --------------------------------------------------------------------------
  r1.xyz = exposure.xxx * r0.xyz;
  r0.w = max(r1.y, r1.z);
  r0.w = max(r0.w, r1.x);
  r2.xy = -bloomThreshold.yx + r0.ww;
  r0.w = max(9.99999975e-05, r0.w);
  r1.w = max(0, r2.x);
  r1.w = min(bloomThreshold.z, r1.w);
  r1.w = r1.w * r1.w;
  r1.w = bloomThreshold.w * r1.w;
  r1.w = max(r1.w, r2.y);
  r0.w = r1.w / r0.w;
  r2.xyz = r1.xyz * r0.www;
  r2.xyz = -r2.xyz * bloomCurveMix.xxx + r1.xyz;

  r3.xyz = BloomInput.SampleLevel(LinearSampler, v1.xy, 0).xyz;
  r4.xyz = log2(r3.zxy);
  r4.xyz = float3(0.330000013,0.330000013,0.330000013) * r4.xyz;
  r4.xyz = exp2(r4.xyz);
  r4.xyz = r4.xyz * float3(1.49380004,1.49380004,1.49380004) + float3(-0.699999988,-0.699999988,-0.699999988);
  r0.w = -bloomCurveMix + 1;
  r5.xyz = r3.zxy * r0.www;
  r5.xyz = cmp(float3(0.300000012,0.300000012,0.300000012) < r5.xyz);
  r3.xyz = r5.xyz ? r4.xyz : r3.zxy;
  r2.xyz = r3.xyz * bloomTint + r2.xyz;
  r0.xyz = -r0.xyz * exposure.xxx + r2.xyz;
  r0.xyz = bloomBlend.xxx * r0.xyz + r1.xyz;

  // --------------------------------------------------------------------------
  // 3. Aspect-correct radial vignette and vignette colour.
  // --------------------------------------------------------------------------
  r0.w = viewportSize.x / viewportSize.y;
  r1.x = -1 + r0.w;
  r1.x = vignetteShape.w * r1.x + 1;
  r0.w = r0.w * 0.5625 + -r1.x;
  r0.w = vignetteEnable * r0.w + r1.x;
  r1.x = saturate(vignetteShape.x * 1.04999995);
  r1.x = r1.x * 1.5 + -1;
  r1.x = vignetteEnable * r1.x + 1;
  r1.y = -vignetteShape.x + 1;
  r1.y = vignetteEnable * r1.y + vignetteShape.x;
  r1.zw = -vignetteCenter + v1.xy;
  r1.yz = abs(r1.zw) * r1.yy;
  r1.x = r1.y * r1.x;
  r1.x = saturate(r1.x * r0.w);
  r0.w = vignetteShape.x * 2 + -1;
  r0.w = vignetteEnable * r0.w + 1;
  r1.w = saturate(vignetteShape.x + -2.79999995);
  r1.w = 5 * r1.w;
  r1.y = saturate(r1.z * r0.w + r1.w);
  r1.xy = log2(r1.xy);
  r1.xy = vignetteShape.zz * r1.xy;
  r1.xy = exp2(r1.xy);
  r0.w = dot(r1.xy, r1.xy);
  r0.w = 1 + -r0.w;
  r0.w = max(0, r0.w);
  r0.w = log2(r0.w);
  r0.w = vignetteShape.y * r0.w;
  r0.w = exp2(r0.w);
  r1.xyz = -vignetteColor + float3(1,1,1);
  r1.xyz = r0.www * r1.xyz + vignetteColor;
  r0.xyz = r1.xyz * r0.xyz;

  // --------------------------------------------------------------------------
  // 4. Log-domain encode into a flattened 3D colour-LUT; interpolate slices.
  // --------------------------------------------------------------------------
  r0.xyz = lutParams.www * r0.xyz;
  r0.xyz = r0.xyz * float3(5.55555582,5.55555582,5.55555582) + float3(0.0479959995,0.0479959995,0.0479959995);
  r0.xyz = max(float3(0,0,0), r0.xyz);
  r0.xyz = log2(r0.xyz);
  r0.xyz = saturate(r0.xyz * float3(0.0734997839,0.0734997839,0.0734997839) + float3(0.386036009,0.386036009,0.386036009));
  r0.yzw = lutParams.zzz * r0.xyz;
  r0.y = floor(r0.y);
  r0.x = r0.x * lutParams.z + -r0.y;
  r1.xy = lutParams.xy * float2(0.5,0.5);
  r1.yz = r0.zw * lutParams.xy + r1.xy;
  r1.x = r0.y * lutParams.y + r1.y;
  r2.x = lutParams.y;
  r2.y = 0;
  r0.yz = r2.xy + r1.xz;
  r1.xyz = ColorLut.SampleLevel(LinearSampler, r1.xz, 0).xyz;
  r0.yzw = ColorLut.SampleLevel(LinearSampler, r0.yz, 0).xyz;
  r0.yzw = r0.yzw + -r1.xyz;
  r0.xyz = r0.xxx * r0.yzw + r1.xyz;

  // --------------------------------------------------------------------------
  // 5. Linear-to-sRGB transfer followed by a tiny deterministic dither.
  // --------------------------------------------------------------------------
  r1.xyz = log2(abs(r0.xyz));
  r1.xyz = float3(0.416666657,0.416666657,0.416666657) * r1.xyz;
  r1.xyz = exp2(r1.xyz);
  r1.xyz = r1.xyz * float3(1.05499995,1.05499995,1.05499995) + float3(-0.0549999997,-0.0549999997,-0.0549999997);
  r2.xyz = float3(12.9200001,12.9200001,12.9200001) * r0.xyz;
  r0.xyz = cmp(float3(0.00313080009,0.00313080009,0.00313080009) >= r0.xyz);
  r0.xyz = r0.xyz ? r2.xyz : r1.xyz;
  r1.xy = viewportSize * v1.xy;
  r0.w = dot(float2(171,231), r1.xy);
  r1.xyz = float3(0.00970873795,0.0140845068,0.010309278) * r0.www;
  r1.xyz = frac(r1.xyz);
  r1.xyz = float3(-0.5,-0.5,-0.5) + r1.xyz;
  o0.xyz = r1.xyz * float3(0.0013725491,0.0013725491,0.0013725491) + r0.xyz;
  return;
}
