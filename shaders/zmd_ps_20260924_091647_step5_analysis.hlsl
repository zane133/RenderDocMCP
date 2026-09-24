// ZMD / Endfield PS - Step 5: STEP_*/DEBUG_VIS analysis harness
// Source: zmd_ps_20260924_091647_step4_readable.hlsl (Apply-verified)
// Dump: 3Dmigoto 2026-09-24 09:16:47
//
// STEP_* default 1 = original behavior. Off = documented identity/no contribution.
// DEBUG_VIS 0 = final; 1..11 = intermediates captured at their producing sites.
// Bindings, signatures, cbuffer packing, and default-on shader math are unchanged.
//
Texture3D<float4> VolumetricFog3D : register(t16);

Texture2D<float4> LightCookieAtlas : register(t15);

Texture2D<float4> NormalMap : register(t14);

Texture2D<float4> BaseColorMap : register(t13);

Texture2D<float4> SkinSpecMatcap : register(t12);

Texture2D<float4> ShadowColorLUT : register(t11);

Texture2D<float4> SkinDiffuseRamp : register(t10);

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

SamplerState sampNormal : register(s5);

SamplerState sampBaseColor : register(s4);

SamplerState sampShadowLUT : register(s3);

SamplerComparisonState sampShadowCmp : register(s2);

SamplerState sampVolumeWeights : register(s1);

SamplerState sampLinear : register(s0);

cbuffer cb6 : register(b6)
{
  float4 cb6[160];
}

cbuffer cb5 : register(b5)
{
  float4 cb5[13];
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

// ===== Analysis switches =====
#define STEP_VOLUME_PROBES  1  // 0 → else-branch identity (no SH probes)
#define STEP_SSS_EDGE_TINT  1  // 0 → multiply = 1 (do NOT leave the (1-N.V) curve peaked)
#define STEP_SPLAT          1  // 0 → skip fuzz/stubble; keep TBN shading normal
#define STEP_SHADOW_LUT     1  // 0 → use metallic-split diffuse instead of LUT hue
#define STEP_DIFFUSE_RAMP   1  // 0 → ramp chroma = 0 (white wrap, keep ramp.a mask)
#define STEP_MATCAP         1  // 0 → matcap add = 0
#define STEP_SPECULAR       1  // 0 → skip GGX add (matcap, if on, still applies)
#define STEP_RIM            1  // 0 → rim term factor 0 (do NOT peak the wrap)
#define STEP_LOCAL_LIGHTS   1  // 0 → skip tiled local-light loop
#define STEP_COLOR_GRADE    1  // 0 → skip cb5 grade
#define STEP_FOG            1  // 0 → exposed color only

#define DEBUG_VIS 0
// 0  final
// 1  baseColor (post tint, pre SSS)
// 2  shadingNormal TBN  *0.5+0.5
// 3  shadingNormal after splat *0.5+0.5
// 4  SSS edge tint multiply (r12)
// 5  ShadowColorLUT (r6.xzw)
// 6  SkinDiffuseRamp rgb
// 7  ramp chroma (max-min) as grey
// 8  lit before rim (after spec/matcap)
// 9  rim term only
// 10 1-|N·V| saved at rim site
// 11 preFog (after lights / grade, before /exposure)

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
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27,r28,r29,r30,r31;
  uint4 bitmask, uiDest;
  float4 fDest;

  // CB aliases (inferred). float4 cbN[] packing is untouched, so every
  // existing swizzle below still reads the exact same components.
  // -- view / camera --
  const float4 viewRow0 = cb0[0];                   // world->view matrix rows; .z column = view axis
  const float4 viewRow1 = cb0[1];
  const float4 viewRow2 = cb0[2];
  const float4 sunDir = cb0[6];                     // main light direction
  const float4 cameraPos = cb0[44];
  const float4 taaPrevJitter = cb0[85];             // used with cb2[2].w for tile depth slice
  const float4 viewBend = cb0[86];                  // .w lerps view vector toward the view axis
  const float4 timeParams = cb0[102];               // .x drives stroke-noise animation phase
  const float4 mipBiasParams = cb0[108];            // .x SampleBias, .w frame counter bits
  const float4 exposure = cb0[109];                 // .x exposure (divided out again before fog)
  const float4 lightListBase = cb0[110];            // .y base index into the tile mask buffer
  const float4 exposureAlt = cb0[111];              // blended against exposure by blendWeights.w
  // -- GI / ambient / rim scales --
  const float4 lightScales = cb0[186];              // .y giScale .z albedoLitScale .w envIblScale
  const float4 featureToggles = cb0[187];           // .y<0.5 volume probe, .z AO blend, .w sun blend
  const float4 ambientFallback = cb0[189];          // flat ambient when probe path is off
  const float4 skyColor = cb0[190];
  const float4 ambientFacingDir = cb0[192];         // horizontal direction dotted against N (inferred)
  const float4 ambientFacingRemap = cb0[193];       // .x bias .y scale .z offset
  const float4 rimColor = cb0[194];                 // toon rim: .xyz colour .w intensity
  const float4 rimAxisParams = cb0[195];            // .yx axis vs sunDir, .z albedoMix, .w width
  const float4 strandUvScale = cb0[196];            // .z stroke-field UV scale
  const float4 sunDirOffset = cb0[197];             // added to cb3[0] before normalising
  const float4 blendWeights = cb0[198];             // per-feature lerp weights
  const float4 specParams = cb0[199];               // .w matcap specular weight
  // -- volume probe cascades --
  const float4 volumeOrigin = cb0[210];             // .w != 0 enables the cascades
  const float4 volumeGridSize = cb0[211];
  const float4 volumeCascadeDist = cb0[212];        // .y fine .z mid .w coarse fade distance
  const float4 volumeSHAmbientR = cb0[213];         // constant SH added to each cascade
  const float4 volumeSHAmbientG = cb0[214];
  const float4 volumeSHAmbientB = cb0[215];
  // -- height + volumetric fog --
  const float4 fogStartFade = cb0[153];
  const float4 fogDirParams = cb0[154];             // .xyz fog direction, .w distance scale
  const float4 fogColorParams = cb0[155];           // .xyz extinction colour, .w phase g
  const float4 fogHeightA = cb0[156];
  const float4 fogHeightB = cb0[157];
  const float4 fogHeightC = cb0[158];
  const float4 fogLayerA = cb0[159];
  const float4 fogAddParams = cb0[160];
  const float4 fogAmbient = cb0[161];               // .w minimum transmittance
  const float4 fogLayerB = cb0[162];
  const float4 fogVolumeParams = cb0[163];          // .z > 0 selects the 3D froxel path
  const float4 fogSliceParams = cb0[164];           // depth -> froxel slice curve
  const float4 fogJitterScale = cb0[165];
  const float4 fogStartDist = cb0[166];
  const float4 fogJitterAmount = cb0[167];
  // -- tiles / shadows / material --
  const float4 tileGridParams = cb2[1];
  const float4 tileDepthParams = cb2[2];
  const float4 mainLightDirRaw = cb3[0];            // before sunDirOffset / normalise
  const float4 mainLightColor = cb3[3];             // .w intensity
  const float4 screenAoBlend = cb4[34];             // .x blends ScreenData.x toward 1
  const float4 shadowTexelSize = cb4[400];          // .xy texel size, .zw map size
  const float4 matParams = cb5[0];                  // .x smoothness .y specular .z metallic .w normal strength
  const float4 matTwoSided = cb5[1];                // .y backface normal flip
  const float4 gradeParams = cb5[3];                // .x enable .y exposure .z sat .w contrast
  const float4 gradeRimParams = cb5[4];             // .x NdotV width .y strength
  const float4 baseColorTint = cb5[5];
  const float4 gradeTintColor = cb5[7];             // .w tint blend
  const float4 gradeRimColor = cb5[8];
  const float4 sssEdgeTintAmount = cb5[11];         // strength of the 1-N.V skin edge tint
  const float4 sssEdgeTintColor = cb5[12];          // skin edge tint colour, multiplies base colour

  // ===== 1. View vector: worldPos -> camera, bent toward the view axis =====
  r0.xyz = cameraPos.xyz + -v2.xyz;
  r1.x = viewRow0.z;
  r1.y = viewRow1.z;
  r1.z = viewRow2.z;
  r2.xyz = r1.xyz + -r0.xyz;
  r0.xyz = viewBend.www * r2.xyz + r0.xyz;
  r0.w = dot(r0.xyz, r0.xyz);
  r1.w = max(9.99999994e-09, r0.w);
  r1.w = rsqrt(r1.w);
  r2.xyz = r1.www * r0.xyz;

  // ===== 2. Per-instance record: TEXCOORD8 -> cb1 offset (16 float4 stride) =====
  // cb1[+4].w bit 4 selects an InstanceDataSB indirection for the pivot.
  r2.w = (uint)v9.x << 4;
  r3.x = 16 & asint(cb1[r2.w+4].w);
  if (r3.x != 0) {
    r3.x = 2 + asint(cb1[r2.w+5].x);
    r3.x = InstanceDataSB[r3.x].val[12/4];
    r3.y = InstanceDataSB[cb1[r2.w+5].x].val[12/4];
  } else {
    r3.xy = cb1[r2.w+3].zx;
  }

  // ===== 3. Base colour, then linear->sRGB encode into ShadowColorLUT coords =====
  // The LUT is a 32-slice colour cube in a 2D atlas, addressed by the skin base
  // colour itself: r5.xyz = sRGB(baseColor.zxy), r6.x/.w = atlas UV, r3.w = slice.
  r4.xyzw = BaseColorMap.SampleBias(sampBaseColor, v1.xy, mipBiasParams.x).xyzw;
  r4.xyz = baseColorTint.xyz * r4.xyz;
  float3 dbgBaseColor = r4.xyz;
  r3.z = -matParams.x + 1;
  r5.xyz = float3(12.9200001,12.9200001,12.9200001) * r4.zxy;
  r6.xyz = log2(abs(r4.zxy));
  r6.xyz = float3(0.416666657,0.416666657,0.416666657) * r6.xyz;
  r6.xyz = exp2(r6.xyz);
  r6.xyz = r6.xyz * float3(1.05499995,1.05499995,1.05499995) + float3(-0.0549999997,-0.0549999997,-0.0549999997);
  r7.xyz = cmp(float3(0.00313080009,0.00313080009,0.00313080009) >= r4.zxy);
  r5.xyz = saturate(r7.xyz ? r5.xyz : r6.xyz);
  r6.xw = float2(31,0.96875) * r5.xz;
  r3.w = floor(r6.x);
  r6.yz = r5.yz * float2(0.0302734375,0.96875) + float2(0.00048828125,0.015625);
  r6.x = r3.w * 0.03125 + r6.y;

  // ===== 4. Normal map: .xy rescaled by matParams.w, Z reconstructed =====
  r5.yzw = NormalMap.SampleBias(sampNormal, v1.xy, mipBiasParams.x).xyw;
  r5.y = r5.w * r5.y;
  r5.yz = r5.yz * float2(2,2) + float2(-1,-1);
  r5.w = dot(r5.yz, r5.yz);
  r5.w = min(1, r5.w);
  r5.w = 1 + -r5.w;
  r5.w = sqrt(r5.w);
  r5.w = max(1.00000002e-16, r5.w);
  r5.yz = matParams.ww * r5.yz;
  r7.xz = v2.xz + -r3.yx;
  r7.y = 6.10351562e-05;
  r3.x = dot(r7.xyz, r7.xyz);
  r3.x = rsqrt(r3.x);
  r7.xyz = r7.xyz * r3.xxx;

  // ===== 5. TBN -> world normal (r8), two-sided flip (r3.x), geometric N (r9) =====
  r8.xyz = v4.yzx * v3.zxy;
  r8.xyz = v3.yzx * v4.zxy + -r8.xyz;
  r8.xyz = v4.www * r8.xyz;
  r8.xyz = r8.xyz * r5.zzz;
  r8.xyz = r5.yyy * v4.xyz + r8.xyz;
  r5.yzw = r5.www * v3.xyz + r8.xyz;
  r3.x = matTwoSided.y * 2 + -1;
  r3.x = v10.x ? 1 : r3.x;
  r3.y = dot(r5.yzw, r5.yzw);
  r3.y = max(1.17549435e-38, r3.y);
  r3.y = rsqrt(r3.y);
  r5.yzw = r5.yzw * r3.yyy;
  r8.xyz = r5.yzw * r3.xxx;
  float3 dbgShadingN = r8.xyz;
  r3.y = dot(v3.xyz, v3.xyz);
  r3.y = rsqrt(r3.y);
  r9.xyz = v3.xyz * r3.yyy;
  r9.xyz = r9.xyz * r3.xxx;
  r10.xy = (uint2)v0.xy;
  r3.y = -exposureAlt.x + 1;
  r3.y = blendWeights.w * r3.y + exposureAlt.x;
  r3.y = exposure.x * r3.y;
  r8.w = 6.10351562e-05;
  r6.y = dot(r8.xzw, r8.xzw);
  r6.y = rsqrt(r6.y);
  r11.xyz = r8.xwz * r6.yyy;

  // ===== 6. Volume probe GI: three 3D cascades, each weights + SH textures =====
  r6.y = cmp(featureToggles.y < 0.5);
#if !STEP_VOLUME_PROBES
  r6.y = 0; // identity: take else (no probe SH)
#endif
  if (r6.y != 0) {
    r12.xyz = sunDir.xzy * -volumeCascadeDist.www + volumeOrigin.xzy;
    r12.xyz = v2.xzy + -r12.xyz;
    r6.y = max(abs(r12.x), abs(r12.y));
    r6.y = -464 + r6.y;
    r6.y = saturate(0.03125 * r6.y);
    r7.w = -208 + abs(r12.z);
    r7.w = saturate(0.03125 * r7.w);
    r6.y = max(r7.w, r6.y);
    r7.w = cmp(0.000000 != volumeOrigin.w);
    r8.w = cmp(r6.y < 1);
    r7.w = r7.w ? r8.w : 0;
    if (r7.w != 0) {
      r12.xyz = sunDir.xzy * -volumeCascadeDist.yyy + volumeOrigin.xzy;
      r12.xyz = v2.xzy + -r12.xyz;
      r7.w = max(abs(r12.x), abs(r12.y));
      r7.w = -29 + r7.w;
      r7.w = saturate(0.5 * r7.w);
      r8.w = -13 + abs(r12.z);
      r8.w = saturate(0.5 * r8.w);
      r7.w = max(r8.w, r7.w);
      r8.w = cmp(r7.w < 1);
      if (r8.w != 0) {
        r12.xyz = v2.xyz * float3(2,2,2) + float3(0.5,0.5,0.5);
        r13.xyz = volumeGridSize.xyz * r12.xyz;
        r13.xyz = floor(r13.xyz);
        r12.xyz = r12.xyz * volumeGridSize.xyz + -r13.xyz;

        // --- 6a. Fine cascade (x2 grid): weights t4, SH bands t5 ---
        r13.xyw = VolumeFine_Weights.SampleLevel(sampVolumeWeights, r12.xyz, 0).yzx;
        r8.w = 1 + -r7.w;
        r9.w = volumeGridSize.y * 0.5;
        r14.x = -volumeGridSize.y * 0.5 + 1;
        r9.w = max(r12.y, r9.w);
        r9.w = min(r9.w, r14.x);
        r12.w = 0.333333343 * r9.w;
        r14.xyzw = VolumeFine_SH.SampleLevel(sampLinear, r12.xwz, 0).xyzw;
        r9.w = r14.w * r8.w + r6.y;
        r15.xyz = float3(0,0.666666687,0) + r12.xwz;
        r15.xyz = VolumeFine_SH.SampleLevel(sampLinear, r15.xyz, 0).xyz;
        r15.xyz = r15.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r15.xyz = r15.xyz * r13.yyy;
        r15.w = r13.y;
        r15.xyzw = r15.xyzw * r8.wwww;
        r12.xyz = float3(0,0.333333343,0) + r12.xwz;
        r12.xyz = VolumeFine_SH.SampleLevel(sampLinear, r12.xyz, 0).xyz;
        r12.xyz = r12.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r12.xyz = r12.xyz * r13.xxx;
        r12.w = r13.x;
        r12.xyzw = r12.xyzw * r8.wwww;
        r14.xyz = r14.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r13.xyz = r14.xyz * r13.www;
        r13.xyzw = r13.xyzw * r8.wwww;
      } else {
        r15.xyzw = float4(0,0,0,0);
        r12.xyzw = float4(0,0,0,0);
        r13.xyzw = float4(0,0,0,0);
        r9.w = r6.y;
      }
      r14.xyz = sunDir.xzy * -volumeCascadeDist.zzz + volumeOrigin.xzy;
      r14.xyz = v2.xzy + -r14.xyz;
      r8.w = max(abs(r14.x), abs(r14.y));
      r8.w = -116 + r8.w;
      r8.w = saturate(0.125 * r8.w);
      r14.x = -52 + abs(r14.z);
      r14.x = saturate(0.125 * r14.x);
      r8.w = max(r14.x, r8.w);
      r14.x = cmp(r8.w < 1);
      if (r14.x != 0) {
        r14.xyz = v2.xyz * float3(0.5,0.5,0.5) + float3(0.5,0.5,0.5);
        r16.xyz = volumeGridSize.xyz * r14.xyz;
        r16.xyz = floor(r16.xyz);
        r14.xyz = r14.xyz * volumeGridSize.xyz + -r16.xyz;

        // --- 6b. Mid cascade (x0.5 grid): weights t6, SH bands t7 ---
        r16.xyw = VolumeMid_Weights.SampleLevel(sampVolumeWeights, r14.xyz, 0).yzx;
        r17.x = 1 + -r8.w;
        r7.w = r17.x * r7.w;
        r17.x = volumeGridSize.y * 0.5;
        r17.y = -volumeGridSize.y * 0.5 + 1;
        r14.y = max(r17.x, r14.y);
        r14.y = min(r14.y, r17.y);
        r14.w = 0.333333343 * r14.y;
        r17.xyzw = VolumeMid_SH.SampleLevel(sampLinear, r14.xwz, 0).xyzw;
        r9.w = r17.w * r7.w + r9.w;
        r18.xyz = float3(0,0.666666687,0) + r14.xwz;
        r18.xyz = VolumeMid_SH.SampleLevel(sampLinear, r18.xyz, 0).xyz;
        r18.xyz = r18.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r18.xyz = r18.xyz * r16.yyy;
        r18.w = r16.y;
        r15.xyzw = r18.xyzw * r7.wwww + r15.xyzw;
        r14.xyz = float3(0,0.333333343,0) + r14.xwz;
        r14.xyz = VolumeMid_SH.SampleLevel(sampLinear, r14.xyz, 0).xyz;
        r14.xyz = r14.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r14.xyz = r14.xyz * r16.xxx;
        r14.w = r16.x;
        r12.xyzw = r14.xyzw * r7.wwww + r12.xyzw;
        r14.xyz = r17.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r16.xyz = r14.xyz * r16.www;
        r13.xyzw = r16.xyzw * r7.wwww + r13.xyzw;
      }
      r7.w = cmp(0 < r8.w);
      if (r7.w != 0) {
        r14.xyz = v2.xyz * float3(0.125,0.125,0.125) + float3(0.5,0.5,0.5);
        r16.xyz = volumeGridSize.xyz * r14.xyz;
        r17.xyz = volumeGridSize.xyz * float3(0.5,0.5,0.5);
        r16.xyz = floor(r16.xyz);
        r14.xyz = r14.xyz * volumeGridSize.xyz + -r16.xyz;
        r16.xyz = -volumeGridSize.xyz * float3(0.5,0.5,0.5) + float3(1,1,1);
        r14.xyz = max(r14.xyz, r17.xyz);
        r14.xyz = min(r14.xyz, r16.xyz);

        // --- 6c. Coarse cascade (x0.125 grid): weights t8, SH bands t9 ---
        r18.xyw = VolumeCoarse_Weights.SampleLevel(sampVolumeWeights, r14.xyz, 0).yzx;
        r7.w = 1 + -r6.y;
        r7.w = r8.w * r7.w;
        r8.w = max(r14.y, r17.y);
        r8.w = min(r8.w, r16.y);
        r14.w = 0.333333343 * r8.w;
        r16.xyzw = VolumeCoarse_SH.SampleLevel(sampLinear, r14.xwz, 0).xyzw;
        r17.xyz = float3(0,0.666666687,0) + r14.xwz;
        r17.xyz = VolumeCoarse_SH.SampleLevel(sampLinear, r17.xyz, 0).xyz;
        r17.xyz = r17.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r17.xyz = r17.xyz * r18.yyy;
        r17.w = r18.y;
        r15.xyzw = r17.xyzw * r7.wwww + r15.xyzw;
        r14.xyz = float3(0,0.333333343,0) + r14.xwz;
        r14.xyz = VolumeCoarse_SH.SampleLevel(sampLinear, r14.xyz, 0).xyz;
        r14.xyz = r14.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r14.xyz = r14.xyz * r18.xxx;
        r14.w = r18.x;
        r12.xyzw = r14.xyzw * r7.wwww + r12.xyzw;
        r14.xyz = r16.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r18.xyz = r14.xyz * r18.www;
        r13.xyzw = r18.xyzw * r7.wwww + r13.xyzw;
        r9.w = r16.w * r7.w + r9.w;
      }
      r7.w = saturate(r9.w * 2 + -1);
      r14.x = r7.w + -r6.y;
      r6.y = r7.w + r6.y;
      r14.y = 0.5 * r6.y;
    } else {
      r15.xyzw = float4(0,0,0,0);
      r12.xyzw = float4(0,0,0,0);
      r13.xyzw = float4(0,0,0,0);
      r14.xy = float2(0,1);
    }

    // --- 6d. Add the constant SH ambient (cb0[213..215] = R/G/B bands) ---
    r16.xyzw = volumeSHAmbientR.xyzw * r14.yyyx;
    r16.y = r16.w * 0.5 + r16.y;
    r14.zw = volumeSHAmbientR.wy * r14.yx;
    r16.w = r14.w * 0.375 + r14.z;
    r13.xyzw = r16.xyzw + r13.xyzw;
    r16.xyzw = volumeSHAmbientG.xyzw * r14.yyyx;
    r16.y = r16.w * 0.5 + r16.y;
    r14.zw = volumeSHAmbientG.wy * r14.yx;
    r16.w = r14.w * 0.375 + r14.z;
    r12.xyzw = r16.xyzw + r12.xyzw;
    r16.xyzw = volumeSHAmbientB.xyzw * r14.yyyx;
    r16.y = r16.w * 0.5 + r16.y;
    r14.xy = volumeSHAmbientB.wy * r14.yx;
    r16.w = r14.y * 0.375 + r14.x;
    r14.xyzw = r16.xyzw + r15.xyzw;
    r11.w = 1;
    r15.x = dot(r13.xyzw, r11.xyzw);
    r15.y = dot(r12.xyzw, r11.xyzw);
    r15.z = dot(r14.xyzw, r11.xyzw);
    r15.xyz = max(float3(0,0,0), r15.xyz);
    r16.xyz = r15.xyz * r3.yyy;

    // --- 6e. Dominant GI direction from the luminance-weighted SH ---
    r17.xyz = float3(0.715200007,0.715200007,0.715200007) * r12.xyz;
    r17.xyz = r13.xyz * float3(0.212599993,0.212599993,0.212599993) + r17.xyz;
    r17.xyz = r14.xyz * float3(0.0722000003,0.0722000003,0.0722000003) + r17.xyz;
    r6.y = dot(r17.xyz, r17.xyz);
    r6.y = max(1.17549435e-38, r6.y);
    r6.y = rsqrt(r6.y);
    r17.xyz = r17.xyz * r6.yyy;
    r17.y = abs(r17.y);
    r17.w = 1;
    r13.x = dot(r13.xyzw, r17.xyzw);
    r13.y = dot(r12.xyzw, r17.xyzw);
    r13.z = dot(r14.xyzw, r17.xyzw);
    r12.xyz = max(float3(0,0,0), r13.xyz);

    // --- 6f. RGB -> hue/sat/val sort, rebuild a saturation-boosted GI colour ---
    r6.y = cmp(r16.y >= r16.z);
    r6.y = r6.y ? 1.000000 : 0;
    r13.xy = r16.zy;
    r13.zw = float2(-1,0.666666687);
    r14.xy = r15.yz * r3.yy + -r13.xy;
    r14.zw = float2(1,-1);
    r13.xyzw = r6.yyyy * r14.xyzw + r13.xyzw;
    r6.y = cmp(r16.x >= r13.x);
    r6.y = r6.y ? 1.000000 : 0;
    r14.xyz = r13.xyw;
    r14.w = r16.x;
    r13.xyw = r14.wyx;
    r13.xyzw = r13.xyzw + -r14.xyzw;
    r13.xyzw = r6.yyyy * r13.xyzw + r14.xyzw;
    r6.y = min(r13.w, r13.y);
    r6.y = r13.x + -r6.y;
    r7.w = r13.w + -r13.y;
    r8.w = r6.y * 6 + 9.99999975e-05;
    r7.w = r7.w / r8.w;
    r7.w = r13.z + r7.w;
    r7.w = frac(abs(r7.w));
    r8.w = 9.99999975e-05 + r13.x;
    r6.y = r6.y / r8.w;
    r14.xyzw = float4(-0.5,1,0.666666687,0.333333343) + r7.wwww;
    r7.w = -0.449999988 + abs(r14.x);
    r7.w = saturate(-10.000001 * r7.w);
    r8.w = r7.w * -2 + 3;
    r7.w = r7.w * r7.w;
    r7.w = r8.w * r7.w;
    r7.w = r7.w * -0.349999994 + 0.699999988;
    r13.x = saturate(r13.x);
    r7.w = r13.x * r7.w;
    r6.y = min(r7.w, r6.y);
    r7.w = 2 + -r6.y;
    r7.w = 2 / r7.w;
    r13.xyz = frac(r14.yzw);
    r13.xyz = r13.xyz * float3(6,6,6) + float3(-3,-3,-3);
    r13.xyz = saturate(float3(-1,-1,-1) + abs(r13.xyz));
    r13.xyz = float3(-1,-1,-1) + r13.xyz;
    r13.xyz = r6.yyy * r13.xyz + float3(1,1,1);
    r13.xyz = r13.xyz * r7.www;
    r6.y = max(r12.x, r12.y);
    r6.y = max(r6.y, r12.z);
    r3.y = r6.y * r3.y;
    r6.y = 1;
  } else {
    r17.xyz = float3(0,0,0);
    r16.xyz = float3(1,1,1);
    r13.xyz = ambientFallback.xyz;
    r6.y = 0;
  }

  // ===== 7. Skin edge tint: (1 - N.V) curve tints base colour toward
  // sssEdgeTintColor. This is the cheap fake-SSS reddening at grazing angles.
  r7.w = dot(r8.xyz, r2.xyz);
  r8.w = saturate(r7.w);
  r9.w = r8.w * 0.850000024 + 0.150000006;
  r9.w = 1 + -r9.w;
  r9.w = saturate(sssEdgeTintAmount.x * r9.w);
  r11.w = 1 + -r9.w;
  r12.xyz = sssEdgeTintColor.xyz * r9.www + r11.www;
  r14.xyz = r12.xyz * r4.xyz;
  float3 dbgSssTint = r12.xyz;
#if !STEP_SSS_EDGE_TINT
  // identity: no tint. Do NOT leave r9.w at the peak of the (1-N.V) curve.
  r9.w = 0;
  r12.xyz = float3(1, 1, 1);
  r14.xyz = r4.xyz;
#endif

  // ===== 8. Splat mask: instance height gradient vs cb1[+12] =====
  // cb1[+12]: .x constant amount, .y gradient amount, .z height, .w floor.
  r9.w = cb1[r2.w+12].z + -v2.y;
  r9.w = 0.200000003 + r9.w;
  r9.w = saturate(2.85714269 * r9.w);
  r11.w = r9.w * -2 + 3;
  r9.w = r9.w * r9.w;
  r9.w = r11.w * r9.w;
  r9.w = cb1[r2.w+12].y * r9.w;
  r9.w = max(cb1[r2.w+12].w, r9.w);
  r11.w = cb1[r2.w+12].x + r9.w;
  r11.w = cmp(0.00999999978 < r11.w);
#if !STEP_SPLAT
  r11.w = 0; // identity: else branch (shading N = TBN, coverage 0)
#endif
  if (r11.w != 0) {
    r9.w = max(cb1[r2.w+12].x, r9.w);

    // ===== 9. Procedural splat field (inferred: fuzz / stubble strands) =====
    // Triplanar (weights from v7^10), two frequencies (30 and 45.3456), each with
    // 3 planes of a hash-cell splat: hash 123.34/456.21 + 114.514, cell jitter,
    // 1.25/0.75 elongation, smoothstep falloff, animated by timeParams.x.
    // Output r15.xy = flow direction, r2.w = coverage mask.
    r15.xyzw = float4(1,-1,1,1) * v8.xyxz;
    r15.xyzw = cb1[r2.w+4].wwww ? r15.xyzw : v8.xzxy;
    r15.xyzw = strandUvScale.zzzz * r15.xyzw;
    r18.xyz = float3(30,30,30) * r15.yzw;
    r19.xyz = float3(45.3456001,45.3456001,45.3456001) * r15.yzw;
    r20.yz = cb1[r2.w+4].ww ? v7.zy : v7.yz;
    r20.x = v7.x;
    r20.xyz = float3(-0.200000003,-0.200000003,-0.200000003) + abs(r20.xyz);
    r20.xyz = r20.xyz * r20.xyz;
    r21.xyz = r20.xyz * r20.xyz;
    r21.xyz = r21.xyz * r21.xyz;
    r20.xyz = r21.xyz * r20.xyz;
    r11.w = dot(r20.xyz, float3(1,1,1));
    r20.xyz = r20.xyz / r11.www;
    r21.xyzw = floor(r18.yxyz);
    r22.xyzw = float4(123.339996,456.209991,123.339996,456.209991) * r21.xyzw;
    r22.xyzw = frac(r22.xyzw);
    r23.xyzw = float4(34.3450012,34.3450012,34.3450012,34.3450012) + r22.xyzw;
    r11.w = dot(r22.xy, r23.xy);
    r18.yw = r22.xy + r11.ww;
    r11.w = r18.y * r18.w;
    r12.w = r18.y + r18.w;
    r11.w = frac(r11.w);
    r24.w = frac(r12.w);
    r25.xyzw = float4(114.514,114.514,114.514,114.514) + r21.xyzw;
    r25.xyzw = float4(123.339996,456.209991,123.339996,456.209991) * r25.xyzw;
    r25.xyzw = frac(r25.xyzw);
    r26.xyzw = float4(34.3450012,34.3450012,34.3450012,34.3450012) + r25.xyzw;
    r12.w = dot(r25.xy, r26.xy);
    r18.yw = r25.xy + r12.ww;
    r12.w = r18.y * r18.w;
    r13.w = r18.y + r18.w;
    r22.x = frac(r12.w);
    r22.y = frac(r13.w);
    r12.w = r11.w * 0.399999976 + 0.600000024;
    r13.w = 0.200000003 * r12.w;
    r21.xyzw = r15.zyzw * float4(30,30,30,30) + -r21.xyzw;
    r18.yw = r22.xy * float2(2,2) + float2(-1,-1);
    r18.yw = r18.yw * float2(0.25,0.25) + r21.xy;
    r18.yw = float2(-0.5,-0.5) + r18.yw;
    r21.x = 1.25 * r18.y;
    r14.w = cmp(r18.w < 0);
    r14.w = r14.w ? 1.25 : 0.75;
    r21.y = r18.w * r14.w;
    r11.w = timeParams.x * 3 + r11.w;
    r11.w = frac(r11.w);
    r18.yw = float2(-0.200000003,-0.449999988) + r11.ww;
    r18.yw = saturate(float2(50.0000114,-6.66666794) * r18.yw);
    r23.xy = r18.yw * float2(-2,-2) + float2(3,3);
    r18.yw = r18.yw * r18.yw;
    r18.yw = r23.xy * r18.yw;
    r11.w = r18.y * r18.w;
    r14.w = dot(r21.xy, r21.xy);
    r14.w = sqrt(r14.w);
    r12.w = -r12.w * 0.200000003 + r14.w;
    r14.w = 1 / -r13.w;
    r12.w = saturate(r14.w * r12.w);
    r14.w = r12.w * -2 + 3;
    r12.w = r12.w * r12.w;
    r12.w = r14.w * r12.w;
    r12.w = cmp(r12.w >= 0.00100000005);
    r12.w = r12.w ? 1.000000 : 0;
    r24.z = r12.w * r11.w;
    r18.yw = r21.xy / r13.ww;
    r18.yw = max(float2(-1,-1), r18.yw);
    r18.yw = min(float2(1,1), r18.yw);
    r11.w = cmp(r24.z >= 0.00100000005);
    r11.w = r11.w ? 1.000000 : 0;
    r18.yw = r18.yw * r11.ww;
    r11.w = r22.x * 0.199999988 + 0.800000012;
    r24.xy = r18.yw * r11.ww;
    r11.w = dot(r22.zw, r23.zw);
    r18.yw = r22.zw + r11.ww;
    r11.w = r18.y * r18.w;
    r12.w = r18.y + r18.w;
    r11.w = frac(r11.w);
    r22.w = frac(r12.w);
    r12.w = dot(r25.zw, r26.zw);
    r18.yw = r25.zw + r12.ww;
    r12.w = r18.y * r18.w;
    r13.w = r18.y + r18.w;
    r21.x = frac(r12.w);
    r21.y = frac(r13.w);
    r12.w = r11.w * 0.399999976 + 0.600000024;
    r13.w = 0.200000003 * r12.w;
    r18.yw = r21.xy * float2(2,2) + float2(-1,-1);
    r18.yw = r18.yw * float2(0.25,0.25) + r21.zw;
    r18.yw = float2(-0.5,-0.5) + r18.yw;
    r23.x = 1.25 * r18.y;
    r14.w = cmp(r18.w < 0);
    r14.w = r14.w ? 1.25 : 0.75;
    r23.y = r18.w * r14.w;
    r11.w = timeParams.x * 3 + r11.w;
    r11.w = frac(r11.w);
    r18.yw = float2(-0.200000003,-0.449999988) + r11.ww;
    r18.yw = saturate(float2(50.0000114,-6.66666794) * r18.yw);
    r21.yz = r18.yw * float2(-2,-2) + float2(3,3);
    r18.yw = r18.yw * r18.yw;
    r18.yw = r21.yz * r18.yw;
    r11.w = r18.y * r18.w;
    r14.w = dot(r23.xy, r23.xy);
    r14.w = sqrt(r14.w);
    r12.w = -r12.w * 0.200000003 + r14.w;
    r14.w = 1 / -r13.w;
    r12.w = saturate(r14.w * r12.w);
    r14.w = r12.w * -2 + 3;
    r12.w = r12.w * r12.w;
    r12.w = r14.w * r12.w;
    r12.w = cmp(r12.w >= 0.00100000005);
    r12.w = r12.w ? 1.000000 : 0;
    r22.z = r12.w * r11.w;
    r18.yw = r23.xy / r13.ww;
    r18.yw = max(float2(-1,-1), r18.yw);
    r18.yw = min(float2(1,1), r18.yw);
    r11.w = cmp(r22.z >= 0.00100000005);
    r11.w = r11.w ? 1.000000 : 0;
    r18.yw = r18.yw * r11.ww;
    r11.w = r21.x * 0.199999988 + 0.800000012;
    r22.xy = r18.yw * r11.ww;
    r18.xy = floor(r18.xz);
    r18.zw = float2(123.339996,456.209991) * r18.xy;
    r18.zw = frac(r18.zw);
    r21.xy = float2(34.3450012,34.3450012) + r18.zw;
    r11.w = dot(r18.zw, r21.xy);
    r18.zw = r18.zw + r11.ww;
    r11.w = r18.z * r18.w;
    r12.w = r18.z + r18.w;
    r11.w = frac(r11.w);
    r21.w = frac(r12.w);
    r18.zw = float2(114.514,114.514) + r18.xy;
    r18.zw = float2(123.339996,456.209991) * r18.zw;
    r18.zw = frac(r18.zw);
    r23.xy = float2(34.3450012,34.3450012) + r18.zw;
    r12.w = dot(r18.zw, r23.xy);
    r18.zw = r18.zw + r12.ww;
    r12.w = r18.z * r18.w;
    r13.w = r18.z + r18.w;
    r23.x = frac(r12.w);
    r23.y = frac(r13.w);
    r12.w = r11.w * 0.399999976 + 0.600000024;
    r13.w = 0.200000003 * r12.w;
    r18.xy = r15.yw * float2(30,30) + -r18.xy;
    r18.zw = r23.xy * float2(2,2) + float2(-1,-1);
    r18.xy = r18.zw * float2(0.25,0.25) + r18.xy;
    r18.xy = float2(-0.5,-0.5) + r18.xy;
    r25.x = 1.25 * r18.x;
    r14.w = cmp(r18.y < 0);
    r14.w = r14.w ? 1.25 : 0.75;
    r25.y = r18.y * r14.w;
    r11.w = timeParams.x * 3 + r11.w;
    r11.w = frac(r11.w);
    r18.xy = float2(-0.200000003,-0.449999988) + r11.ww;
    r18.xy = saturate(float2(50.0000114,-6.66666794) * r18.xy);
    r18.zw = r18.xy * float2(-2,-2) + float2(3,3);
    r18.xy = r18.xy * r18.xy;
    r18.xy = r18.zw * r18.xy;
    r11.w = r18.x * r18.y;
    r14.w = dot(r25.xy, r25.xy);
    r14.w = sqrt(r14.w);
    r12.w = -r12.w * 0.200000003 + r14.w;
    r14.w = 1 / -r13.w;
    r12.w = saturate(r14.w * r12.w);
    r14.w = r12.w * -2 + 3;
    r12.w = r12.w * r12.w;
    r12.w = r14.w * r12.w;
    r12.w = cmp(r12.w >= 0.00100000005);
    r12.w = r12.w ? 1.000000 : 0;
    r21.z = r12.w * r11.w;
    r18.xy = r25.xy / r13.ww;
    r18.xy = max(float2(-1,-1), r18.xy);
    r18.xy = min(float2(1,1), r18.xy);
    r11.w = cmp(r21.z >= 0.00100000005);
    r11.w = r11.w ? 1.000000 : 0;
    r18.xy = r18.xy * r11.ww;
    r11.w = r23.x * 0.199999988 + 0.800000012;
    r21.xy = r18.xy * r11.ww;
    r18.xyzw = r22.xyzw * r20.zzzz;
    r18.xyzw = r24.xyzw * r20.yyyy + r18.xyzw;
    r18.xyzw = r21.xyzw * r20.xxxx + r18.xyzw;
    r21.xyzw = floor(r19.yxyz);
    r22.xyzw = float4(123.339996,456.209991,123.339996,456.209991) * r21.xyzw;
    r22.xyzw = frac(r22.xyzw);
    r23.xyzw = float4(34.3450012,34.3450012,34.3450012,34.3450012) + r22.xyzw;
    r11.w = dot(r22.xy, r23.xy);
    r19.yw = r22.xy + r11.ww;
    r11.w = r19.y * r19.w;
    r12.w = r19.y + r19.w;
    r11.w = frac(r11.w);
    r24.w = frac(r12.w);
    r25.xyzw = float4(114.514,114.514,114.514,114.514) + r21.xyzw;
    r25.xyzw = float4(123.339996,456.209991,123.339996,456.209991) * r25.xyzw;
    r25.xyzw = frac(r25.xyzw);
    r26.xyzw = float4(34.3450012,34.3450012,34.3450012,34.3450012) + r25.xyzw;
    r12.w = dot(r25.xy, r26.xy);
    r19.yw = r25.xy + r12.ww;
    r12.w = r19.y * r19.w;
    r13.w = r19.y + r19.w;
    r22.x = frac(r12.w);
    r22.y = frac(r13.w);
    r12.w = r11.w * 0.399999976 + 0.600000024;
    r13.w = 0.200000003 * r12.w;
    r21.xyzw = r15.xyzw * float4(45.3456001,45.3456001,45.3456001,45.3456001) + -r21.xyzw;
    r15.xz = r22.xy * float2(2,2) + float2(-1,-1);
    r15.xz = r15.xz * float2(0.25,0.25) + r21.xy;
    r15.xz = float2(-0.5,-0.5) + r15.xz;
    r21.x = 1.25 * r15.x;
    r14.w = cmp(r15.z < 0);
    r14.w = r14.w ? 1.25 : 0.75;
    r21.y = r15.z * r14.w;
    r11.w = timeParams.x * 4.34560013 + r11.w;
    r11.w = frac(r11.w);
    r15.xz = float2(-0.200000003,-0.449999988) + r11.ww;
    r15.xz = saturate(float2(50.0000114,-6.66666794) * r15.xz);
    r19.yw = r15.xz * float2(-2,-2) + float2(3,3);
    r15.xz = r15.xz * r15.xz;
    r15.xz = r19.yw * r15.xz;
    r11.w = r15.x * r15.z;
    r14.w = dot(r21.xy, r21.xy);
    r14.w = sqrt(r14.w);
    r12.w = -r12.w * 0.200000003 + r14.w;
    r14.w = 1 / -r13.w;
    r12.w = saturate(r14.w * r12.w);
    r14.w = r12.w * -2 + 3;
    r12.w = r12.w * r12.w;
    r12.w = r14.w * r12.w;
    r12.w = cmp(r12.w >= 0.00100000005);
    r12.w = r12.w ? 1.000000 : 0;
    r24.z = r12.w * r11.w;
    r15.xz = r21.xy / r13.ww;
    r15.xz = max(float2(-1,-1), r15.xz);
    r15.xz = min(float2(1,1), r15.xz);
    r11.w = cmp(r24.z >= 0.00100000005);
    r11.w = r11.w ? 1.000000 : 0;
    r15.xz = r15.xz * r11.ww;
    r11.w = r22.x * 0.199999988 + 0.800000012;
    r24.xy = r15.xz * r11.ww;
    r11.w = dot(r22.zw, r23.zw);
    r15.xz = r22.zw + r11.ww;
    r11.w = r15.x * r15.z;
    r12.w = r15.x + r15.z;
    r11.w = frac(r11.w);
    r22.w = frac(r12.w);
    r12.w = dot(r25.zw, r26.zw);
    r15.xz = r25.zw + r12.ww;
    r12.w = r15.x * r15.z;
    r13.w = r15.x + r15.z;
    r21.x = frac(r12.w);
    r21.y = frac(r13.w);
    r12.w = r11.w * 0.399999976 + 0.600000024;
    r13.w = 0.200000003 * r12.w;
    r15.xz = r21.xy * float2(2,2) + float2(-1,-1);
    r15.xz = r15.xz * float2(0.25,0.25) + r21.zw;
    r15.xz = float2(-0.5,-0.5) + r15.xz;
    r23.x = 1.25 * r15.x;
    r14.w = cmp(r15.z < 0);
    r14.w = r14.w ? 1.25 : 0.75;
    r23.y = r15.z * r14.w;
    r11.w = timeParams.x * 4.34560013 + r11.w;
    r11.w = frac(r11.w);
    r15.xz = float2(-0.200000003,-0.449999988) + r11.ww;
    r15.xz = saturate(float2(50.0000114,-6.66666794) * r15.xz);
    r19.yw = r15.xz * float2(-2,-2) + float2(3,3);
    r15.xz = r15.xz * r15.xz;
    r15.xz = r19.yw * r15.xz;
    r11.w = r15.x * r15.z;
    r14.w = dot(r23.xy, r23.xy);
    r14.w = sqrt(r14.w);
    r12.w = -r12.w * 0.200000003 + r14.w;
    r14.w = 1 / -r13.w;
    r12.w = saturate(r14.w * r12.w);
    r14.w = r12.w * -2 + 3;
    r12.w = r12.w * r12.w;
    r12.w = r14.w * r12.w;
    r12.w = cmp(r12.w >= 0.00100000005);
    r12.w = r12.w ? 1.000000 : 0;
    r22.z = r12.w * r11.w;
    r15.xz = r23.xy / r13.ww;
    r15.xz = max(float2(-1,-1), r15.xz);
    r15.xz = min(float2(1,1), r15.xz);
    r11.w = cmp(r22.z >= 0.00100000005);
    r11.w = r11.w ? 1.000000 : 0;
    r15.xz = r15.xz * r11.ww;
    r11.w = r21.x * 0.199999988 + 0.800000012;
    r22.xy = r15.xz * r11.ww;
    r15.xz = floor(r19.xz);
    r19.xy = float2(123.339996,456.209991) * r15.xz;
    r19.xy = frac(r19.xy);
    r19.zw = float2(34.3450012,34.3450012) + r19.xy;
    r11.w = dot(r19.xy, r19.zw);
    r19.xy = r19.xy + r11.ww;
    r11.w = r19.x * r19.y;
    r12.w = r19.x + r19.y;
    r11.w = frac(r11.w);
    r19.w = frac(r12.w);
    r21.xy = float2(114.514,114.514) + r15.xz;
    r21.xy = float2(123.339996,456.209991) * r21.xy;
    r21.xy = frac(r21.xy);
    r21.zw = float2(34.3450012,34.3450012) + r21.xy;
    r12.w = dot(r21.xy, r21.zw);
    r21.xy = r21.xy + r12.ww;
    r12.w = r21.x * r21.y;
    r13.w = r21.x + r21.y;
    r21.x = frac(r12.w);
    r21.y = frac(r13.w);
    r12.w = r11.w * 0.399999976 + 0.600000024;
    r13.w = 0.200000003 * r12.w;
    r15.xy = r15.yw * float2(45.3456001,45.3456001) + -r15.xz;
    r15.zw = r21.xy * float2(2,2) + float2(-1,-1);
    r15.xy = r15.zw * float2(0.25,0.25) + r15.xy;
    r15.xy = float2(-0.5,-0.5) + r15.xy;
    r23.x = 1.25 * r15.x;
    r14.w = cmp(r15.y < 0);
    r14.w = r14.w ? 1.25 : 0.75;
    r23.y = r15.y * r14.w;
    r11.w = timeParams.x * 4.34560013 + r11.w;
    r11.w = frac(r11.w);
    r15.xy = float2(-0.200000003,-0.449999988) + r11.ww;
    r15.xy = saturate(float2(50.0000114,-6.66666794) * r15.xy);
    r15.zw = r15.xy * float2(-2,-2) + float2(3,3);
    r15.xy = r15.xy * r15.xy;
    r15.xy = r15.zw * r15.xy;
    r11.w = r15.x * r15.y;
    r14.w = dot(r23.xy, r23.xy);
    r14.w = sqrt(r14.w);
    r12.w = -r12.w * 0.200000003 + r14.w;
    r14.w = 1 / -r13.w;
    r12.w = saturate(r14.w * r12.w);
    r14.w = r12.w * -2 + 3;
    r12.w = r12.w * r12.w;
    r12.w = r14.w * r12.w;
    r12.w = cmp(r12.w >= 0.00100000005);
    r12.w = r12.w ? 1.000000 : 0;
    r19.z = r12.w * r11.w;
    r15.xy = r23.xy / r13.ww;
    r15.xy = max(float2(-1,-1), r15.xy);
    r15.xy = min(float2(1,1), r15.xy);
    r11.w = cmp(r19.z >= 0.00100000005);
    r11.w = r11.w ? 1.000000 : 0;
    r15.xy = r15.xy * r11.ww;
    r11.w = r21.x * 0.199999988 + 0.800000012;
    r19.xy = r15.xy * r11.ww;
    r15.xyzw = r22.xyzw * r20.zzzz;
    r15.xyzw = r24.xyzw * r20.yyyy + r15.xyzw;
    r15.xyzw = r19.xyzw * r20.xxxx + r15.xyzw;
    r15.zw = max(r18.zw, r15.zw);
    r11.w = -cb1[r2.w+12].x + 1;
    r12.w = -0.100000001 + r15.w;
    r11.w = cmp(r12.w >= r11.w);
    r11.w = r11.w ? 1.000000 : 0;
    r11.w = r15.z * r11.w;
    r2.w = cmp(cb1[r2.w+12].x >= 0.00999999978);
    r2.w = r2.w ? 1.000000 : 0;
    r2.w = r11.w * r2.w;
    r11.w = cmp(0.00100000005 < r2.w);
    r15.xy = r18.xy + r15.xy;
    r15.xy = r11.ww ? r15.xy : 0;

    // ===== 10. Bend the shading normal along the splat flow (r5.yzw) =====
    // The mask also pushes roughness up by 0.1 and pulls specular toward 1.
    r15.zw = float2(1,0) * r8.zy;
    r15.zw = r8.yx * float2(0,1) + -r15.zw;
    r11.w = dot(r15.zw, r15.zw);
    r12.w = cmp(6.10351562e-05 < r11.w);
    r11.w = rsqrt(r11.w);
    r15.zw = r15.zw * r11.ww;
    r15.zw = -r15.zw;
    r18.z = r12.w ? r15.z : -1;
    r18.y = r12.w ? r15.w : 0;
    r18.x = 0;
    r5.yzw = -r5.yzw * r3.xxx + r18.zxy;
    r5.yzw = r15.xxx * r5.yzw + r8.xyz;
    r15.xzw = r18.xyz * r8.zxy;
    r15.xzw = r8.yzx * r18.yzx + -r15.xzw;
    r15.xzw = r15.xzw + -r5.yzw;
    r5.yzw = r15.yyy * r15.xzw + r5.yzw;
    r3.x = dot(r5.yzw, r5.yzw);
    r3.x = rsqrt(r3.x);
    r5.yzw = r5.yzw * r3.xxx + -r8.xyz;
    r5.yzw = r2.www * r5.yzw + r8.xyz;
    r3.x = 0.5 + -r3.z;
    r3.x = r9.w * r3.x + r3.z;
    r11.w = 0.100000001 + -r3.x;
    r3.z = r2.w * r11.w + r3.x;
    r3.x = -matParams.y + 1;
    r3.x = r9.w * r3.x + matParams.y;
    r9.w = 1 + -r3.x;
    r3.x = r2.w * r9.w + r3.x;
  } else {
    r5.yzw = r8.xyz;
    r2.w = 0;
    r3.x = matParams.y;
  }
  float3 dbgShadingNSplat = r5.yzw;

  // ===== 11. Metallic split: r4 = F0 (diffuse->spec), r3.x = 0.04 * specular =====
  r9.w = -matParams.z * 0.959999979 + 0.959999979;
  r15.xyz = r14.xyz * r9.www;
  r3.x = 0.0399999991 * r3.x;
  r4.xyz = r4.xyz * r12.xyz + -r3.xxx;
  r4.xyz = matParams.zzz * r4.xyz + r3.xxx;

  // ===== 12. ShadowColorLUT: two adjacent slices blended by r3.x =====
  // r6.xzw becomes the shadowed / subsurface colour for this base colour.
  r12.xyz = ShadowColorLUT.SampleLevel(sampShadowLUT, r6.xz, 0).xyz;
  r6.xz = float2(0.03125,0.015625) + r6.xw;
  r6.xzw = ShadowColorLUT.SampleLevel(sampShadowLUT, r6.xz, 0).xyz;
  r3.x = r5.x * 31 + -r3.w;
  r6.xzw = r6.xzw + -r12.xyz;
  r6.xzw = r3.xxx * r6.xzw + r12.xyz;
  r6.xzw = r6.xzw * r9.www;
#if !STEP_SHADOW_LUT
  r6.xzw = r15.xyz; // identity: no LUT hue, keep metallic-split diffuse
#endif
  float3 dbgShadowLut = r6.xzw;
  r3.x = r3.z * r3.z;
  r3.x = max(0.0078125, r3.x);

  // ===== 13. Motion vectors (v5 curr / v6 prev) -> o1.xy, o1.w = stroke flag =====
  r3.w = max(9.99999994e-09, v5.z);
  r12.xy = v5.xy / r3.ww;
  r3.w = max(9.99999994e-09, v6.z);
  r12.zw = v6.xy / r3.ww;
  r12.xy = r12.xy + -r12.zw;
  r18.xy = float2(0.5,-0.5) * r12.xy;
  r18.xy = sqrt(abs(r18.xy));
  r18.xy = sqrt(r18.xy);
  r12.z = -r12.y;
  r12.yw = cmp(float2(0,0) < r12.xz);
  r12.xz = cmp(r12.xz < float2(0,0));
  r12.xy = (int2)-r12.yw + (int2)r12.xz;
  r12.xy = (int2)r12.xy;
  r12.xy = r18.xy * r12.xy;
  o1.xy = r12.xy * float2(0.5,0.5) + float2(0.5,0.5);
  r12.xy = cmp(float2(0.5,0.00100000005) < r2.ww);
  o1.w = r12.x ? 0.699999988 : 0.400000006;

  // ===== 14. Main light direction and colour (cb3 blended by blendWeights) =====
  r12.xzw = mainLightDirRaw.xyz + sunDirOffset.xyz;
  r18.xyz = featureToggles.www * r12.xzw + -mainLightDirRaw.xyz;
  r18.w = 6.10351562e-05;
  r3.w = dot(r18.xzw, r18.xzw);
  r3.w = rsqrt(r3.w);
  r12.xzw = r18.xwz * r3.www;
  r19.xyz = -mainLightColor.xyz + skyColor.xyz;
  r19.xyz = blendWeights.yyy * r19.xyz + mainLightColor.xyz;
  r3.w = -mainLightColor.w + 1;
  r3.w = blendWeights.w * r3.w + mainLightColor.w;
  r20.xyz = r19.xyz * r3.www;
  r10.z = 0;

  // ===== 15. Screen data at this pixel: .x AO (blended by screenAoBlend), .y mask =====
  r21.xy = ScreenData.Load(r10.xyz).xy;
  r5.x = -1 + r21.x;
  r5.x = screenAoBlend.x * r5.x + 1;
  r10.z = 1 + -r5.x;
  r5.x = featureToggles.z * r10.z + r5.x;
  r21.xzw = lightScales.zzz * r6.xzw;
  r22.xyz = float3(0.649999976,0.649999976,0.649999976) * r21.xzw;
  r10.z = dot(r15.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r11.w = dot(r8.xyz, r18.xyz);
  r11.w = sunDirOffset.w * blendWeights.x + r11.w;
  r11.w = max(-1, r11.w);
  r11.w = min(1, r11.w);
  r23.x = r11.w * 0.5 + 0.5;
  r23.y = 0.5;

  // ===== 16. Toon skin diffuse ramp: U = N.L remapped to 0..1, V = 0.5 =====
  // r11.w = max(rgb) - min(rgb) of the ramp, i.e. how saturated the ramp is
  // here. It later drives how strongly the ramp colour tints the lit result,
  // which is what produces the red terminator band on skin.
  r23.xyzw = SkinDiffuseRamp.SampleLevel(sampLinear, r23.xy, 0).xyzw;
  float3 dbgRamp = r23.xyz;
  r11.w = max(r23.x, r23.y);
  r11.w = max(r11.w, r23.z);
  r13.w = min(r23.x, r23.y);
  r13.w = min(r13.w, r23.z);
  r11.w = -r13.w + r11.w;
  float dbgRampChroma = r11.w;
#if !STEP_DIFFUSE_RAMP
  // identity: no chromatic wrap. Keep r23.w (ramp mask). Do NOT set log/chroma to a peak.
  r11.w = 0;
  r23.xyz = float3(1, 1, 1);
#endif
  r13.w = r21.y * r4.w;
  r14.w = min(r21.y, r4.w);
  r15.w = min(r14.w, r23.w);
  r11.x = dot(r11.xyz, ambientFacingDir.xyz);
  r11.x = saturate(ambientFacingRemap.x + r11.x);
  r11.x = r11.x * ambientFacingRemap.y + ambientFacingRemap.z;
  r11.y = featureToggles.y * r15.w;
  r24.xyz = float3(1,1,1) + -r13.xyz;
  r13.xyz = r11.yyy * r24.xyz + r13.xyz;
  r11.xyz = r13.xyz * r11.xxx;

  // ===== 17. Ambient/GI intensity shaping, then combine ramp + shadow colour =====
  r13.x = r3.y * 0.350000024 + 0.649999976;
  r13.yz = max(float2(1.25,0), r3.yy);
  r13.xyz = min(float3(1.5,1.75,1.5), r13.xyz);
  r13.y = r13.y + -r13.x;
  r13.x = featureToggles.x * r13.y + r13.x;
  r24.xyz = r13.xxx * r11.xyz;
  r24.xyz = lightScales.www * r24.xyz;
  r13.x = dot(r20.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r20.xyz = r19.xyz * r3.www + -r13.xxx;
  r20.xyz = r15.www * r20.xyz + r13.xxx;
  r11.xyz = r13.zzz * r11.xyz;
  r13.xy = -blendWeights.yx + float2(1,1);
  r25.xyz = r19.xyz * blendWeights.yyy + r13.xxx;
  r11.xyz = r11.xyz * r25.xyz + r20.xyz;
  r11.xyz = r11.xyz * lightScales.yyy + -r24.xyz;
  r11.xyz = r5.xxx * r11.xyz + r24.xyz;
  r13.x = dot(r22.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r20.xyz = r21.xzw * float3(0.649999976,0.649999976,0.649999976) + -r13.xxx;
  r20.xyz = r20.xyz * float3(1.20000005,1.20000005,1.20000005) + r13.xxx;
  r13.x = saturate(r4.w * r21.y + r23.w);
  r22.xyz = r6.xzw * lightScales.zzz + -r20.xyz;
  r20.xyz = r13.xxx * r22.xyz + r20.xyz;
  r22.xyz = r14.xyz * r9.www + -r20.xyz;
  r20.xyz = r15.www * r22.xyz + r20.xyz;
  r13.x = 1 + -r11.w;
  r22.xyz = r23.xyz * r11.www + r13.xxx;
  r22.xyz = r22.xyz * r20.xyz;
  r23.xyz = r14.xyz * r9.www + -r10.zzz;
  r23.xyz = r23.xyz * float3(1.20000005,1.20000005,1.20000005) + r10.zzz;
  r23.xyz = -r6.xzw * lightScales.zzz + r23.xyz;
  r21.xzw = r13.www * r23.xyz + r21.xzw;
  r11.w = dot(r20.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r13.x = dot(r22.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r13.x = max(0.00100000005, r13.x);
  r13.x = 1 / r13.x;
  r11.w = r13.x * r11.w;
  r11.w = max(0, r11.w);
  r11.w = min(1.5, r11.w);
  r20.xyz = r22.xyz * r11.www + -r21.xzw;
  r20.xyz = r5.xxx * r20.xyz + r21.xzw;
  r11.w = -r4.w * r21.y + r15.w;
  r11.w = r5.x * r11.w + r13.w;
  r13.x = -0.5 + r18.y;
  r22.y = r5.x * r13.x + 0.5;
  r13.x = saturate(dot(r5.yzw, r2.xyz));
  r22.xz = sunDir.xz;
  r13.z = dot(r22.xyz, r22.xyz);
  r13.z = max(1.17549435e-38, r13.z);
  r13.z = rsqrt(r13.z);
  r21.xzw = r22.xyz * r13.zzz;
  r21.xzw = r21.xzw + r21.xzw;
  r18.xyz = r18.xyz * r5.xxx + r21.xzw;
  r13.z = 2 + r5.x;
  r18.xyz = r2.xyz * r13.zzz + r18.xyz;
  r13.z = dot(r18.xyz, r18.xyz);
  r13.z = rsqrt(r13.z);
  r18.xyz = r18.xyz * r13.zzz;
  r13.z = dot(r5.yzw, r18.xyz);
  r13.w = r3.x * r3.x;
  r15.w = r13.z * r13.w + -r13.z;
  r13.z = r15.w * r13.z + 1;
  r13.z = r13.z * r13.z;
  if (r12.y != 0) {

    // ===== 18. Skin matcap highlight: view-space normal -> SkinSpecMatcap.w =====
    r18.xyz = viewRow1.xyz * r5.zzz;
    r18.xyz = viewRow0.xyz * r5.yyy + r18.xyz;
    r18.xyz = viewRow2.xyz * r5.www + r18.xyz;
    r12.y = dot(r18.xyz, r18.xyz);
    r12.y = rsqrt(r12.y);
    r18.xy = r18.xy * r12.yy;
    r18.xy = r18.xy * float2(0.5,0.5) + float2(0.5,0.5);
    r12.y = SkinSpecMatcap.SampleBias(sampLinear, r18.xy, mipBiasParams.x).w;
    r12.y = r12.y * r21.y;
    r3.y = max(0.5, r3.y);
    r3.y = min(1.5, r3.y);
    r3.y = lightScales.w * r3.y;
    r3.y = r12.y * r3.y;
    r2.w = r2.w * r2.w;
    r18.xyz = r3.yyy * r2.www;
  } else {
    r18.xyz = float3(0,0,0);
  }
#if !STEP_MATCAP
  r18.xyz = float3(0, 0, 0); // identity: no matcap add
#endif

  // ===== 19. GGX specular for the main light (r13.z = D denominator) =====
  r2.w = cmp(r13.z != r13.w);
  r3.y = r13.w / r13.z;
  r2.w = r2.w ? r3.y : 1;
  r3.y = r13.x * 2 + r3.x;
  r3.y = 9.99999975e-05 + r3.y;
  r3.y = 0.5 / r3.y;
  r2.w = r2.w * r3.y + -6.10351562e-05;
  r2.w = max(0, r2.w);
  r2.w = min(20, r2.w);
  r21.xzw = r4.xyz * r2.www;
  r2.w = r11.w * 0.5 + 0.5;
  r3.y = -lightScales.z + 1;
  r3.y = r11.w * r3.y + lightScales.z;
  r2.w = r3.y * r2.w;
  r22.xyz = r11.xyz * r2.www;
  r21.xzw = r22.xyz * r21.xzw;
#if STEP_SPECULAR
  r18.xyz = r21.xzw * specParams.www + r18.xyz;
#else
  // identity: skip GGX add; matcap (if on) remains in r18
#endif
  r11.xyz = r11.xyz * r20.xyz + r18.xyz;
  float3 dbgLitPreRim = r11.xyz;
  r2.w = dot(r11.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r3.y = -0.5 + r2.w;
  r3.y = max(0, r3.y);
  r3.y = min(0.5, r3.y);
  r18.y = 0;

  // ===== 20. Toon rim: axis from rimAxisParams x sunDir, width from .w =====
  // Masked by the splat coverage and the screen AO so fuzz does not double-rim.
  r18.xz = rimAxisParams.yx;
  r21.xzw = sunDir.zxy * r18.xyz;
  r18.xyz = sunDir.yzx * r18.yzx + -r21.xzw;
  r11.w = dot(r18.xyz, r18.xyz);
  r11.w = rsqrt(r11.w);
  r18.xyz = r18.xyz * r11.www;
  r13.zw = float2(1,0.399999976) + -abs(r7.ww);
  float dbgOneMinusAbsNdotV = r13.z; // capture at rim site; fog later clobbers r2
  r7.w = dot(r12.xzw, r8.xyz);
  r11.w = 1 + -r5.x;
  r3.y = r3.y * r3.y + 1;
  r11.xyz = r11.xyz + -r2.www;
  r11.xyz = r3.yyy * r11.xyz + r2.www;
  r12.yz = rimAxisParams.ww * float2(-0.600000024,-0.399999976) + float2(0.800000012,0.899999976);
  r2.w = r12.z + -r12.y;
  r3.y = r13.z + -r12.y;
  r2.w = 1 / r2.w;
  r2.w = saturate(r3.y * r2.w);
  r3.y = r2.w * -2 + 3;
  r2.w = r2.w * r2.w;
  r2.w = r3.y * r2.w;
  r21.xzw = rimColor.xyz * r2.www;
  r21.xzw = rimColor.www * r21.xzw;
  r2.w = dot(r7.xyz, r18.xyz);
  r2.w = saturate(1 + r2.w);
  r2.w = min(r2.w, r4.w);
  r2.w = min(r2.w, r21.y);
  r21.xyz = r21.xzw * r2.www;
  r22.xyz = r14.xyz * r9.www + float3(-0.25,-0.25,-0.25);
  r22.xyz = rimAxisParams.zzz * r22.xyz + float3(0.25,0.25,0.25);
  r2.w = saturate(dot(r18.xyz, r8.xyz));
  r18.xyz = r22.xyz * r2.www;

  // ===== 21. Main light colour shaping (normalise, AO, facing, horizon fade) =====
  r2.w = max(r16.x, r16.y);
  r2.w = max(r2.w, r16.z);
  r2.w = 0.5 * r2.w;
  r2.w = max(1, r2.w);
  r2.w = 1 / r2.w;
  r16.xyz = r16.xyz * r2.www;
  r19.xyz = r19.xyz * r3.www + -r16.xyz;
  r16.xyz = r5.xxx * r19.xyz + r16.xyz;
  r2.w = dot(r17.xyz, r8.xyz);
  r3.y = r2.w * r6.y;
  r3.w = r7.w * 0.5 + -1;
  r3.w = -r7.w * r3.w + 0.5;
  r2.w = -r2.w * r6.y + r3.w;
  r2.w = saturate(r5.x * r2.w + r3.y);
  r16.xyz = r16.xyz * r2.www;
  r2.w = dot(sunDir.xz, sunDir.xz);
  r2.w = rsqrt(r2.w);
  r3.yw = sunDir.xz * r2.ww;
  r2.w = dot(r12.xw, r3.yw);
  r2.w = saturate(-r2.w);
  r2.w = r2.w * r5.x + r11.w;
  r2.w = r2.w * r13.y;
  r12.xyz = r16.xyz * r2.www;
  r2.w = saturate(5.00000048 * r13.w);
  r3.y = r2.w * -2 + 3;
  r2.w = r2.w * r2.w;
  r2.w = r3.y * r2.w;
  r12.xyz = r12.xyz * r2.www;
  r12.xyz = r12.xyz * r14.www;
  r2.w = -0.100000001 + r10.z;
  r2.w = saturate(-16.666666 * r2.w);
  r3.y = r2.w * -2 + 3;
  r2.w = r2.w * r2.w;
  r2.w = r3.y * r2.w;
  r2.w = r2.w * r5.x + r11.w;
  r12.xyz = r12.xyz * r2.www;
  r16.xyz = max(float3(0.150000006,0.150000006,0.150000006), r15.xyz);
  r12.xyz = r16.xyz * r12.xyz;
  float3 dbgRim = r21.xyz * r18.xyz;
#if STEP_RIM
  r12.xyz = dbgRim + r12.xyz;
#else
  // identity: rim contribution 0 (not peak wrap)
#endif
  r11.xyz = r12.xyz + r11.xyz;

  // ===== 22. Tiled lights: pixel -> 32x32 tile, depth slice -> mask buffer offset =====
  r3.yw = (uint2)r10.xy;
  r12.xy = float2(0.03125,0.03125) * r3.yw;
  r12.xy = floor(r12.xy);
  r2.w = r12.y * tileGridParams.y + r12.x;
  r2.w = 8 * r2.w;
  r2.w = (int)r2.w;
  r4.w = -taaPrevJitter.y * tileDepthParams.w + v0.w;
  r4.w = floor(r4.w);
  r5.x = tileGridParams.w + -1;
  r6.y = max(0, r4.w);
  r5.x = min(r6.y, r5.x);
  r6.y = 8 * r5.x;
  r6.y = (int)r6.y;
  r4.w = cmp(r5.x >= r4.w);
  r5.x = (int)r6.y + asint(lightListBase.y);
  r6.y = r11.w * -0.25 + 0.75;
  r12.xyz = r14.xyz * r9.www + float3(-0.5,-0.5,-0.5);
  r7.w = 0.00999999978 + -r3.x;
  r9.w = cmp(matParams.z >= 0.5);
  r9.w = r9.w ? 1.000000 : 0;
  r14.w = 1;
  r16.xyz = r11.xyz;
  r10.z = 0;

  // ===== 23. Tiled light loop: 8 words x 32 bits =====
#if STEP_LOCAL_LIGHTS
  while (true) {
    r11.w = cmp(7 < (int)r10.z);
    if (r11.w != 0) break;
    r11.w = (int)r2.w + (int)r10.z;
    r11.w = LightTileMaskSB[r11.w].val[0/4];
    r12.w = (int)r5.x + (int)r10.z;
    r12.w = LightTileMaskSB[r12.w].val[0/4];
    r11.w = (int)r11.w & (int)r12.w;
    r11.w = r4.w ? r11.w : 0;
    r12.w = (uint)r10.z << 5;
    r17.xyz = r16.xyz;
    r13.y = r11.w;

    // --- 23a. Iterate set bits; cb3[light*8 + k + 6] is the light record ---
    while (true) {
      if (r13.y == 0) break;
      r13.w = firstbitlow((uint)r13.y);
      r15.w = 1 << (int)r13.w;
      r15.w = (int)r13.y ^ (int)r15.w;
      r13.w = (int)r12.w + (int)r13.w;
      bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r18.x = (((uint)r13.w << 3) & bitmask.x) | ((uint)1 & ~bitmask.x);
      bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r18.y = (((uint)r13.w << 3) & bitmask.y) | ((uint)5 & ~bitmask.y);
      bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r18.z = (((uint)r13.w << 3) & bitmask.z) | ((uint)6 & ~bitmask.z);
      bitmask.w = ((~(-1 << 29)) << 3) & 0xffffffff;  r18.w = (((uint)r13.w << 3) & bitmask.w) | ((uint)7 & ~bitmask.w);

      // --- 23b. Type 1 = box/OBB bounds: f16x2 packed matrix -> edge fade ---
      r16.w = (uint)cb3[r18.y+6].w;
      r16.w = cmp((int)r16.w == 1);
      if (r16.w != 0) {
        r14.xyz = -cb3[r18.x+6].xyz + v2.xyz;
        r19.xyz = int3(0xffff,0xffff,0xffff) & asint(cb3[r18.y+6].xzy);
        r21.xyz = int3(0xffff,0xffff,0xffff) & asint(cb3[r18.z+6].yxz);
        r22.xyz = asuint(cb3[r18.y+6].xzy) >> int3(16,16,16);
        r23.xyz = asuint(cb3[r18.z+6].yxz) >> int3(16,16,16);
        r19.xyz = f16tof32(r19.xyz);
        r21.xyz = f16tof32(r21.xyz);
        r22.xyz = f16tof32(r22.xyz);
        r23.xyw = f16tof32(r23.yxz);
        r24.xz = r19.xz;
        r24.yw = r22.xz;
        r16.w = dot(r14.xyzw, r24.xyzw);
        r22.x = r19.y;
        r22.z = r21.y;
        r22.w = r23.x;
        r17.w = dot(r14.xyzw, r22.xyzw);
        r23.xz = r21.xz;
        r14.x = dot(r14.xyzw, r23.xyzw);
        r14.y = max(abs(r17.w), abs(r16.w));
        r14.x = max(r14.y, abs(r14.x));
        r14.y = cb3[r18.w+6].x * 0.5 + 0.5;
        r14.x = r14.x + -r14.y;
        r14.y = -cb3[r18.w+6].x * 0.5 + 0.5;
        r14.x = saturate(r14.x / r14.y);
        r14.x = 1 + -r14.x;
        r14.x = r14.x * r14.x;
      } else {
        r14.x = 1;
      }
      r14.y = cmp(r14.x < 0.00100000005);
      if (r14.y != 0) {
        r13.y = r15.w;
        continue;
      }
      r14.y = (uint)r13.w << 3;

      // --- 23c. Light dispatch: .w selects punctual / tube / capsule / special ---
      r14.z = cmp(cb3[r14.y+6].w < 1.5);
      if (r14.z != 0) {
        bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r14.z = (((uint)r13.w << 3) & bitmask.z) | ((uint)3 & ~bitmask.z);
        r16.w = cmp(16 == asint(cb3[r14.z+6].w));
        r17.w = cb3[r14.z+6].z + blendWeights.z;
        r17.w = cmp(r17.w < 0.5);
        r16.w = (int)r16.w | (int)r17.w;
        if (r16.w == 0) {
          bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r19.x = (((uint)r13.w << 3) & bitmask.x) | ((uint)2 & ~bitmask.x);
          bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r19.y = (((uint)r13.w << 3) & bitmask.y) | ((uint)4 & ~bitmask.y);
          r13.w = (uint)cb3[r14.y+6].w;
          r13.w = (int)r13.w & 1;
          r16.w = cmp((int)r13.w == 0);
          r16.w = ~(int)r16.w;
          r17.w = cmp(0 < cb3[r19.x+6].z);
          r16.w = r16.w ? r17.w : 0;
          r17.w = cmp(4 == asint(cb3[r14.z+6].w));
          r18.y = r13.w ? 0 : 1;
          r19.z = cb3[r19.x+6].y * 0.5 + 0.5;
          r21.z = -abs(cb3[r19.x+6].x) + r19.z;
          r21.x = cb3[r19.x+6].y + -r21.z;
          r19.z = 1 + -abs(r21.z);
          r19.z = r19.z + -abs(r21.x);
          r19.z = max(0.00048828125, r19.z);
          r19.w = cmp(cb3[r19.x+6].x >= 0);
          r21.y = r19.w ? r19.z : -r19.z;
          r19.z = dot(r21.xyz, r21.xyz);
          r19.z = rsqrt(r19.z);
          r21.xyz = r21.xyz * r19.zzz;
          r19.z = cb3[r19.y+6].y + cb3[r19.y+6].y;
          r19.z = max(0.100000001, r19.z);
          r19.w = r17.w ? 1.000000 : 0;
          r19.z = -cb3[r18.z+6].w + r19.z;
          r18.z = r19.w * r19.z + cb3[r18.z+6].w;
          r22.xyz = cb3[r18.x+6].xyz + -v2.xyz;
          r19.z = dot(r22.yzx, -r21.xyz);
          r19.w = cmp(0.5 < cb3[r19.y+6].z);
          r19.w = r17.w ? r19.w : 0;
          r19.w = r19.w ? 1.000000 : 0;
          r19.w = r19.w * r18.y;
          r23.xyz = -r21.zxy * r19.zzz + -r22.xyz;
          r22.xyz = r19.www * r23.xyz + r22.xyz;
          r19.z = dot(r22.xyz, r22.xyz);
          r19.w = rsqrt(r19.z);
          r23.xyz = r22.xyz * r19.www;
          if (r16.w != 0) {
            r24.xyz = cb3[r19.x+6].zzz * r21.zxy;
            r25.xyz = -r24.xyz * float3(0.5,0.5,0.5) + r22.xyz;
            r24.xyz = r24.xyz * float3(0.5,0.5,0.5) + r22.xyz;
            r19.w = dot(r25.xyz, r25.xyz);
            r19.w = sqrt(r19.w);
            r20.w = dot(r24.xyz, r24.xyz);
            r20.w = sqrt(r20.w);
            r26.xyz = r23.xyz * r21.xyz;
            r26.xyz = r21.zxy * r23.yzx + -r26.xyz;
            r27.xyz = r26.xyz * r21.xyz;
            r26.xyz = r26.zxy * r21.yzx + -r27.xyz;
            r21.w = dot(r26.xyz, r26.xyz);
            r21.w = rsqrt(r21.w);
            r23.xyz = r26.xyz * r21.www;
            r21.w = dot(r25.xyz, r24.xyz);
            r21.w = r19.w * r20.w + r21.w;
            r21.w = r21.w * 0.5 + 1;
            r21.w = 1 / r21.w;
            r22.w = dot(r23.xyz, r25.xyz);
            r19.w = r22.w / r19.w;
            r22.w = dot(r23.xyz, r24.xyz);
            r20.w = r22.w / r20.w;
            r19.w = r20.w + r19.w;
            r19.w = saturate(0.5 * r19.w);
            r19.w = r21.w * r19.w;
          } else {
            r19.w = 1;
          }
          r20.w = cmp(r18.z < 0);
          if (r20.w != 0) {
            r20.w = cb3[r18.x+6].w * cb3[r18.x+6].w;
            r20.w = r20.w * r19.z;
            r20.w = -r20.w * r20.w + 1;
            r20.w = max(0, r20.w);
            r19.z = 1 + r19.z;
            r19.z = 1 / r19.z;
            r21.w = r16.w ? 1.000000 : 0;
            r22.w = r19.w + -r19.z;
            r19.z = r21.w * r22.w + r19.z;
            r20.w = r20.w * r20.w;
            r19.z = r20.w * r19.z;
          } else {
            r24.xyz = cb3[r18.x+6].www * r22.xyz;
            r20.w = dot(r24.xyz, r24.xyz);
            r20.w = min(1, r20.w);
            r20.w = 1 + -r20.w;
            r20.w = log2(r20.w);
            r18.z = r20.w * r18.z;
            r18.z = exp2(r18.z);
            r19.z = r19.w * r18.z;
          }
          r18.z = dot(r23.yzx, -r21.xyz);
          r18.z = -cb3[r19.x+6].z + r18.z;
          r18.z = saturate(cb3[r19.x+6].w * r18.z);
          r18.z = r18.z * r18.z + -1;
          r18.y = r18.y * r18.z + 1;
          r18.y = r19.z * r18.y;
          r18.z = (int)cb3[r18.w+6].w;
          r16.w = ~(int)r16.w;
          r19.z = cmp((int)r18.z >= 0);
          r16.w = r16.w ? r19.z : 0;
          if (r16.w != 0) {
            if (r13.w == 0) {
              r16.w = (uint)r18.z << 2;
              r21.xyz = cb6[r16.w+33].xyw * v2.yyy;
              r21.xyz = cb6[r16.w+32].xyw * v2.xxx + r21.xyz;
              r21.xyz = cb6[r16.w+34].xyw * v2.zzz + r21.xyz;
              r21.xyz = cb6[r16.w+35].xyw + r21.xyz;
              r19.zw = saturate(r21.xy / r21.zz);
              r19.zw = r19.zw * cb6[r18.z+0].zw + cb6[r18.z+0].xy;
            } else {
              r16.w = (uint)r18.z << 2;
              r21.x = dot(-r22.xyz, cb6[r16.w+32].xyz);
              r21.y = dot(-r22.xyz, cb6[r16.w+33].xyz);
              r21.z = dot(-r22.xyz, cb6[r16.w+34].xyz);
              r16.w = cmp(abs(r21.x) < abs(r21.y));
              // [patch] dump printed int 1 as 0.000000 (movc l(1), l(0))
              r16.w = r16.w ? 1 : 0;
              r20.w = dot(abs(r21.xy), icb[r16.w+0].xy);
              r20.w = cmp(r20.w < abs(r21.z));
              r16.w = r20.w ? 2 : r16.w;
              r20.w = dot(r21.xyz, icb[r16.w+0].xyz);
              r20.w = cmp(r20.w < 0);
              // [patch] bfi face=(axis<<1)|signBit; avoid (uint)(-1.0) clamp
              bitmask.w = ((~(-1 << 31)) << 1) & 0xffffffff;  r16.w = (((uint)r16.w << 1) & bitmask.w) | ((r20.w != 0 ? 1u : 0u) & ~bitmask.w);
              r20.w = (uint)r16.w >> 1;
              r20.w = dot(r21.xyz, icb[r20.w+0].xyz);
              r21.w = 0.000244140625 / cb6[r18.z+0].w;
              r21.w = 0.5 + -r21.w;
              r22.x = (uint)r16.w;
              r22.y = cmp((uint)r16.w < 2);
              // [patch] dump printed int 2 as 0.000000 (icb[2] vs icb[0])
              r22.y = r22.y ? 2 : 0;
              r21.x = dot(r21.xz, icb[r22.y+0].xz);
              r21.x = icb[r16.w+4].z * r21.x;
              r21.x = r21.x / abs(r20.w);
              r21.x = r21.x * r21.w + r22.x;
              r21.x = 0.5 + r21.x;
              r22.x = saturate(0.166666672 * r21.x);
              r21.x = -1 + (int)icb[r16.w+4].y;
              r21.x = dot(r21.yz, icb[r21.x+0].xy);
              r16.w = icb[r16.w+4].w * r21.x;
              r16.w = r16.w / abs(r20.w);
              r22.y = saturate(-r16.w * r21.w + 0.5);
              r19.zw = r22.xy * cb6[r18.z+0].zw + cb6[r18.z+0].xy;
            }

            // --- 23d. Light cookie: 2D projection or cube-face unwrap -> atlas ---
            r16.w = LightCookieAtlas.SampleLevel(sampLinear, r19.zw, 0).x;
            r18.y = r18.y * r16.w;
          }
          r14.x = r18.y * r14.x;
          r16.w = cmp(9.99999975e-05 < r14.x);
          if (r16.w != 0) {
            if (r17.w != 0) {
              r16.w = -cb3[r19.y+6].w + 1;
              r18.y = dot(r9.xyz, r23.xyz);
              r18.y = saturate(0.5 + r18.y);
              r18.z = r18.y * -2 + 3;
              r18.y = r18.y * r18.y;
              r18.y = r18.z * r18.y;
              r16.w = r18.y * cb3[r19.y+6].w + r16.w;
              r16.w = cb3[r19.y+6].x * r16.w;
              r16.w = r16.w * r14.x;
              r21.xyz = cb3[r14.y+6].xyz + -r17.xyz;
              r21.xyz = r16.www * r21.xyz + r17.xyz;
            }
            if (r17.w == 0) {
              r16.w = dot(r8.xyz, r23.xyz);
              r18.y = saturate(r16.w);
              if (cb3[r14.z+6].w != 0) {
                if (r13.w == 0) {
                  r13.w = (int)cb3[r14.z+6].x;
                } else {
                  r22.xyz = -cb3[r18.x+6].xyz + v2.xyz;
                  r24.xyz = cmp(abs(r22.yzz) < abs(r22.xxy));
                  r18.z = r24.y ? r24.x : 0;
                  r22.xyz = cmp(float3(0,0,0) < r22.xyz);
                  r19.z = asuint(cb3[r19.x+6].w) >> 24;
                  r24.x = (asuint(cb3[r19.x+6].w) >> 16) & 0xffu;
                  r24.y = (asuint(cb3[r19.x+6].w) >> 8) & 0xffu;
                  r19.z = r22.x ? r19.z : r24.x;
                  r19.x = 255 & asint(cb3[r19.x+6].w);
                  r19.x = r22.y ? r24.y : r19.x;
                  r19.w = (asuint(cb3[r14.z+6].x) >> 8) & 0xffu;
                  r20.w = 255 & asint(cb3[r14.z+6].x);
                  r19.w = r22.z ? r19.w : r20.w;
                  r19.x = r24.z ? r19.x : r19.w;
                  r18.z = r18.z ? r19.z : r19.x;
                  r19.x = cmp((int)r18.z < 80);
                  r13.w = r19.x ? r18.z : -1;
                }
                r18.z = cmp((int)r13.w >= 0);
                if (r18.z != 0) {

                  // --- 23e. Shadow: 9-tap cubic PCF against ShadowMap ---
                  r19.xzw = -cb3[r18.x+6].xyz + v2.xyz;
                  r18.x = (uint)r13.w << 2;
                  r18.z = dot(r19.xzw, r19.xzw);
                  r18.z = max(1.17549435e-38, r18.z);
                  r18.z = rsqrt(r18.z);
                  r19.xzw = r19.xzw * r18.zzz;
                  r19.xzw = -r19.xzw * cb4[r13.w+288].xxx + v2.xyz;
                  r18.z = cb4[r13.w+288].y * 5;
                  r19.xzw = r9.xyz * r18.zzz + r19.xzw;
                  r22.xyzw = cb4[r18.x+65].xyzw * r19.zzzz;
                  r22.xyzw = cb4[r18.x+64].xyzw * r19.xxxx + r22.xyzw;
                  r22.xyzw = cb4[r18.x+66].xyzw * r19.wwww + r22.xyzw;
                  r22.xyzw = cb4[r18.x+67].xyzw + r22.xyzw;
                  r19.xzw = r22.xyz / r22.www;
                  r22.xyz = cmp(float3(0,0,0) >= r19.xzw);
                  r24.xyz = cmp(r19.xzw >= float3(1,1,1));
                  r18.xz = cb4[r13.w+344].zw + -cb4[r13.w+344].xy;
                  r18.xz = r19.xz * r18.xz + cb4[r13.w+344].xy;
                  r19.xz = r18.xz * shadowTexelSize.zw + float2(0.5,0.5);
                  r19.xz = floor(r19.xz);
                  r18.xz = r18.xz * shadowTexelSize.zw + -r19.xz;
                  r25.xyzw = float4(0.5,1,0.5,1) + r18.xxzz;
                  r26.xyzw = r25.xxzz * r25.xxzz;
                  r25.xz = float2(1,1) + -r18.xz;
                  r27.xy = min(float2(0,0), r18.xz);
                  r27.zw = max(float2(0,0), r18.xz);
                  r28.xy = float2(0.159999996,0.159999996) * r25.xz;
                  r27.zw = -r27.zw * r27.zw + r25.yw;
                  r27.zw = float2(1,1) + r27.zw;
                  r29.xy = float2(0.159999996,0.159999996) * r27.zw;
                  r26.xz = float2(0.0799999982,0.0799999982) * r26.xz;
                  r18.xz = r26.yw * float2(0.5,0.5) + -r18.xz;
                  r30.xy = float2(0.159999996,0.159999996) * r18.xz;
                  r18.xz = -r27.xy * r27.xy + r25.xz;
                  r18.xz = float2(1,1) + r18.xz;
                  r27.xy = float2(0.159999996,0.159999996) * r18.xz;
                  r18.xz = float2(0.159999996,0.159999996) * r25.yw;
                  r30.z = r27.x;
                  r30.w = r18.x;
                  r28.z = r29.x;
                  r28.w = r26.x;
                  r25.xyzw = r30.zwxz + r28.zwxz;
                  r27.z = r30.y;
                  r27.w = r18.z;
                  r29.z = r28.y;
                  r29.w = r26.z;
                  r26.xyz = r29.zyw + r27.zyw;
                  r27.xyz = r28.xzw / r25.zwy;
                  r27.xyz = float3(-2.5,-0.5,1.5) + r27.xyz;
                  r27.xyz = shadowTexelSize.xxx * r27.yxz;
                  r28.xyz = r29.zyw / r26.xyz;
                  r28.xyz = float3(-2.5,-0.5,1.5) + r28.xyz;
                  r28.xyz = shadowTexelSize.yyy * r28.xyz;
                  r27.w = r28.x;
                  r29.xyzw = r19.xzxz * shadowTexelSize.xyxy + r27.ywxw;
                  r18.xz = r19.xz * shadowTexelSize.xy + r27.zw;
                  r28.w = r27.y;
                  r27.yw = r28.yz;
                  r30.xyzw = r19.xzxz * shadowTexelSize.xyxy + r27.xyzy;
                  r28.xyzw = r19.xzxz * shadowTexelSize.xyxy + r28.wywz;
                  r27.xyzw = r19.xzxz * shadowTexelSize.xyxy + r27.xwzw;
                  r31.xyzw = r26.xxxy * r25.zwyz;
                  r19.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r29.xy, r19.w).x;
                  r19.z = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r29.zw, r19.w).x;
                  r19.z = r31.y * r19.z;
                  r19.x = r31.x * r19.x + r19.z;
                  r18.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r18.xz, r19.w).x;
                  r18.x = r31.z * r18.x + r19.x;
                  r18.z = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r28.xy, r19.w).x;
                  r18.x = r31.w * r18.z + r18.x;
                  r29.xyzw = r26.yyzz * r25.xyzw;
                  r18.z = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r30.xy, r19.w).x;
                  r18.x = r29.x * r18.z + r18.x;
                  r18.z = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r30.zw, r19.w).x;
                  r18.x = r29.y * r18.z + r18.x;
                  r18.z = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r28.zw, r19.w).x;
                  r18.x = r29.z * r18.z + r18.x;
                  r18.z = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r27.xy, r19.w).x;
                  r18.x = r29.w * r18.z + r18.x;
                  r22.xyz = (int3)r22.xyz | (int3)r24.xyz;
                  r18.z = (int)r22.y | (int)r22.x;
                  r18.z = (int)r22.z | (int)r18.z;
                  r19.x = (int)r19.w & 0x7fffffff;
                  r19.x = cmp(0x7f800000 < (uint)r19.x);
                  r18.z = (int)r18.z | (int)r19.x;
                  r19.x = r26.z * r25.y;
                  r19.z = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r27.zw, r19.w).x;
                  r18.x = r19.x * r19.z + r18.x;
                  r18.x = -1 + r18.x;
                  r13.w = cb4[r13.w+288].w * r18.x + 1;
                  r13.w = r18.z ? 1 : r13.w;
                } else {
                  r18.x = dot(r7.xyz, r23.xyz);
                  r13.w = saturate(1 + r18.x);
                }
              } else {
                r13.w = 1;
              }
              if (cb3[r14.z+6].w == 0) {
                r19.xzw = cb3[r14.y+6].xyz * r14.xxx;
                r18.x = -cb3[r19.y+6].y + 1;
                r18.z = max(r19.x, r19.z);
                r18.z = max(r18.z, r19.w);
                r18.z = r18.z * r6.y;
                r18.z = max(1, r18.z);
                r18.z = 1 / r18.z;
                r18.x = r18.z * cb3[r19.y+6].y + r18.x;
                r19.xzw = cb3[r14.y+6].xyz * r18.xxx;
                r18.x = cb3[r19.y+6].x * 0.5;
                r18.z = saturate(0.5 + r16.w);
                r20.w = -cb3[r19.y+6].x * 0.5 + 1;
                r18.x = r18.z * r20.w + r18.x;
                r19.xzw = r19.xzw * r18.xxx;
                r22.xyz = r20.xyz;
                r24.xyz = r20.xyz;
                r18.xz = float2(1,0);
              } else {
                r20.w = cmp(3 == asint(cb3[r14.z+6].w));
                if (r20.w != 0) {
                  r25.xy = cb3[r19.y+6].xx * float2(-0.600000024,-0.399999976) + float2(0.800000012,0.899999976);
                  r20.w = r25.y + -r25.x;
                  r21.w = -r25.x + r13.z;
                  r20.w = 1 / r20.w;
                  r20.w = saturate(r21.w * r20.w);
                  r21.w = r20.w * -2 + 3;
                  r20.w = r20.w * r20.w;
                  r20.w = r21.w * r20.w;
                  r20.w = r20.w * r13.w;
                  r14.x = r20.w * r14.x;
                  r25.xyz = sunDir.xyz * r23.zxy;
                  r25.xyz = sunDir.zxy * r23.xyz + -r25.xyz;
                  r26.xyz = sunDir.zxy * r25.xyz;
                  r25.xyz = sunDir.yzx * r25.yzx + -r26.xyz;
                  r20.w = dot(r25.xyz, r25.xyz);
                  r20.w = rsqrt(r20.w);
                  r25.xyz = r25.xyz * r20.www;
                  r18.y = saturate(dot(r8.xyz, -r25.xyz));
                  r22.xyz = cb3[r19.y+6].yyy * r12.xyz + float3(0.5,0.5,0.5);
                  r24.xyz = float3(0,0,0);
                  r18.xz = float2(1,0);
                } else {
                  r20.w = cmp(1 == asint(cb3[r14.z+6].w));
                  if (r20.w != 0) {
                    r16.w = cb3[r19.y+6].x + r16.w;
                    r16.w = saturate(max(-1, r16.w));
                    r18.y = r16.w * r13.w;
                    r24.xyz = cb3[r19.y+6].yyy * r6.xzw;
                    r18.xz = float2(1,0);
                  } else {
                    r13.w = cmp(2 == asint(cb3[r14.z+6].w));
                    if (r13.w != 0) {
                      r16.w = cb3[r19.y+6].x + 0.0500000007;
                      r16.w = -r16.w + r3.z;
                      r16.w = saturate(-10 * r16.w);
                      r21.w = r16.w * -2 + 3;
                      r16.w = r16.w * r16.w;
                      r16.w = r21.w * r16.w;
                      r21.w = -cb3[r19.y+6].z + 1;
                      r21.w = r9.w * cb3[r19.y+6].z + r21.w;
                      r18.x = r21.w * r16.w;
                    } else {
                      r18.x = 1;
                    }
                    r18.z = r13.w ? cb3[r19.y+6].y : 0;
                    r24.xyz = float3(0,0,0);
                  }
                  r22.xyz = r20.www ? r15.xyz : 0;
                }
                r19.xzw = cb3[r14.y+6].xyz;
              }
              r13.w = cmp(3 != asint(cb3[r14.z+6].w));
              if (r13.w != 0) {
                r13.w = r18.z * r7.w + r3.x;
                r23.xyz = r0.xyz * r1.www + r23.xyz;
                r14.y = dot(r23.xyz, r23.xyz);
                r14.y = rsqrt(r14.y);
                r23.xyz = r23.xyz * r14.yyy;
                r14.y = dot(r5.yzw, r23.xyz);
                r14.z = r13.w * r13.w;
                r16.w = r14.y * r14.z + -r14.y;
                r14.y = r16.w * r14.y + 1;
                r14.y = r14.y * r14.y;
                r16.w = cmp(r14.y != r14.z);
                r14.y = r14.z / r14.y;
                r14.y = r16.w ? r14.y : 1;
                r13.w = r13.x * 2 + r13.w;
                r13.w = 9.99999975e-05 + r13.w;
                r13.w = 0.5 / r13.w;
                r13.w = r14.y * r13.w + -6.10351562e-05;
                r13.w = max(0, r13.w);
                r13.w = min(20, r13.w);
                r23.xyz = r13.www * r4.xyz;
                r23.xyz = r23.xyz * r18.xxx;
                r18.xzw = cb3[r18.w+6].zzz * r23.xyz;
              } else {
                r18.xzw = float3(0,0,0);
              }
              r14.xyz = r19.xzw * r14.xxx;
              r19.xyz = -r24.xyz + r22.xyz;
              r19.xyz = r18.yyy * r19.xyz + r24.xyz;
              r18.xzw = r14.xyz * r18.xzw;
              r18.xyz = r18.xzw * r18.yyy;
              r14.xyz = r14.xyz * r19.xyz + r18.xyz;
              r17.xyz = r17.xyz + r14.xyz;
            }
          } else {
            r17.w = 0;
          }
          r17.xyz = r17.www ? r21.xyz : r17.xyz;
        }
      }
      r13.y = r15.w;
    }
    r16.xyz = r17.xyz;
    r10.z = (int)r10.z + 1;
  }
#else
  // identity: r16 already = r11 (no local lights)
#endif

  // ===== 24. Per-material colour grade + graded rim (gradeParams, gradeRimParams, cb5[7..8]) =====
#if STEP_COLOR_GRADE
  r0.x = cmp(0.5 < gradeParams.x);
  if (r0.x != 0) {
    r0.x = dot(r16.xyz, float3(0.212672904,0.715152204,0.0721750036));
    r4.xyz = r16.xyz + -r0.xxx;
    r0.xyz = gradeParams.zzz * r4.xyz + r0.xxx;
    r0.xyz = float3(-0.5,-0.5,-0.5) + r0.xyz;
    r0.xyz = gradeParams.www * r0.xyz + float3(0.5,0.5,0.5);
    r4.xyz = gradeParams.yyy * r0.xyz;
    r0.xyz = -r0.xyz * gradeParams.yyy + gradeTintColor.xyz;
    r0.xyz = gradeTintColor.www * r0.xyz + r4.xyz;
    r2.w = -gradeRimParams.x + 1;
    r3.x = 1 + -r8.w;
    r3.z = 1 + -r2.w;
    r2.w = r3.x + -r2.w;
    r3.x = 1 / r3.z;
    r2.w = saturate(r3.x * r2.w);
    r3.x = r2.w * -2 + 3;
    r2.w = r2.w * r2.w;
    r2.w = r3.x * r2.w;
    r4.xyz = gradeRimColor.xyz * r2.www;
    r16.xyz = r4.xyz * gradeRimParams.yyy + r0.xyz;
  }
#endif // STEP_COLOR_GRADE
  float3 dbgPreFog = r16.xyz;

  // ===== 25. Undo exposure before fog =====
  r0.xyz = r16.xyz / exposure.xxx;

  // ===== 26. Height fog; fogVolumeParams.z > 0 takes the 3D froxel path =====
  r2.w = cmp(blendWeights.w < 0.5);
#if !STEP_FOG
  r2.w = 0; // identity: exposed color only
#endif
  if (r2.w != 0) {
    r0.w = r1.w * r0.w;
    r1.w = v2.y * fogHeightA.w + fogHeightB.w;
    r1.w = max(0.00999999978, r1.w);
    r2.w = r0.w * fogDirParams.w + -fogStartFade.w;
    r2.w = max(0, r2.w);
    r3.x = -1.44269502 * r1.w;
    r3.x = exp2(r3.x);
    r3.x = 1 + -r3.x;
    r1.w = r3.x / r1.w;
    r3.x = v2.y * fogHeightA.w + fogHeightC.w;
    r3.x = 1.44269502 * r3.x;
    r3.x = exp2(r3.x);
    r1.w = r3.x * r1.w;
    r1.w = -r2.w * r1.w;
    r4.xyz = fogColorParams.xyz * r1.www;
    r4.xyz = float3(1.44269502,1.44269502,1.44269502) * r4.xyz;
    r4.xyz = exp2(r4.xyz);
    r1.w = dot(-r2.xyz, fogDirParams.xyz);
    r2.w = fogColorParams.w * fogColorParams.w + 1;
    r3.x = dot(r1.ww, fogColorParams.ww);
    r2.w = -r3.x + r2.w;
    r3.x = cmp(0 < fogVolumeParams.z);
    if (r3.x != 0) {
      r10.w = 7 & asint(mipBiasParams.w);
      r5.xyz = mad((int3)r10.xyw, int3(0x19660d,0x19660d,0x19660d), int3(0x3c6ef35f,0x3c6ef35f,0x3c6ef35f));
      r3.x = mad((int)r5.y, (int)r5.z, (int)r5.x);
      r3.z = mad((int)r5.z, (int)r3.x, (int)r5.y);
      r4.w = mad((int)r3.x, (int)r3.z, (int)r5.z);
      r5.x = mad((int)r3.z, (int)r4.w, (int)r3.x);
      r1.x = dot(-r2.xyz, -r1.xyz);
      r1.y = -cameraPos.y + v2.y;
      r1.z = cmp(5.96046448e-08 < r1.x);
      r1.x = 1 / r1.x;
      r1.x = r1.z ? r1.x : 0;
      r1.x = fogVolumeParams.w * r1.x;
      r1.z = 1 / r0.w;
      r2.x = r1.x * r1.z;
      r2.y = r2.x * r1.y + cameraPos.y;
      r1.y = -r2.x * r1.y + r1.y;
      r2.x = fogLayerA.z * r1.y;
      r1.y = fogLayerB.x * r1.y;
      r1.y = max(-127, r1.y);
      r2.z = -fogLayerA.x + r2.y;
      r2.z = fogLayerA.z * r2.z;
      r2.xz = max(float2(-127,-127), r2.xz);
      r2.z = exp2(-r2.z);
      r2.z = fogLayerA.y * r2.z;
      r3.x = cmp(5.96046448e-08 < abs(r2.x));
      r5.z = exp2(-r2.x);
      r5.z = 1 + -r5.z;
      r5.z = r5.z / r2.x;
      r2.x = -r2.x * 0.240226507 + 0.693147182;
      r2.x = r3.x ? r5.z : r2.x;
      r2.y = -fogLayerB.z + r2.y;
      r2.y = fogLayerB.x * r2.y;
      r2.y = max(-127, r2.y);
      r2.y = exp2(-r2.y);
      r2.y = fogLayerB.y * r2.y;
      r3.x = cmp(5.96046448e-08 < abs(r1.y));
      r5.z = exp2(-r1.y);
      r5.z = 1 + -r5.z;
      r5.z = r5.z / r1.y;
      r1.y = -r1.y * 0.240226507 + 0.693147182;
      r1.y = r3.x ? r5.z : r1.y;
      r1.y = r2.y * r1.y;
      r1.y = r2.z * r2.x + r1.y;
      r1.x = -r1.x * r1.z + 1;
      r1.x = r1.x * r0.w;
      r1.x = r1.y * r1.x;
      r1.x = exp2(-r1.x);
      r1.x = min(1, r1.x);
      r1.x = max(fogAmbient.w, r1.x);
      r1.yz = saturate(r0.ww * fogAddParams.yw + fogAddParams.xz);
      r1.x = r1.x + r1.y;
      r1.x = r1.x + r1.z;
      r1.x = min(1, r1.x);
      r5.y = mad((int)r4.w, (int)r5.x, (int)r3.z);
      r1.yz = (uint2)r5.xy >> int2(16,16);
      r1.yz = (uint2)r1.yz;
      r1.yz = r1.yz * float2(3.05180438e-05,3.05180438e-05) + float2(-1,-1);
      r1.yz = r1.yz * fogJitterAmount.ww + r3.yw;
      r2.xy = fogJitterScale.xy * r1.yz;
      r1.y = v0.w * fogSliceParams.x + fogSliceParams.y;
      r1.y = log2(r1.y);
      r1.y = fogSliceParams.z * r1.y;
      r2.z = r1.y / fogVolumeParams.z;
      r3.xyzw = VolumetricFog3D.SampleLevel(sampLinear, r2.xyz, 0).xyzw;
      r1.y = -fogStartDist.z + v0.w;
      r1.y = saturate(1000000 * r1.y);
      r3.xyzw = float4(-0,-0,-0,-1) + r3.xyzw;
      r3.xyzw = r1.yyyy * r3.xyzw + float4(0,0,0,1);
      r1.y = 1 + -r1.x;
      r2.xyz = fogAmbient.xyz * r1.yyy;
      r2.xyz = r2.xyz * r3.www + r3.xyz;
      r1.x = r3.w * r1.x;
    } else {
      r1.y = -cameraPos.y + v2.y;
      r1.z = fogLayerA.z * r1.y;
      r1.y = fogLayerB.x * r1.y;
      r1.yz = max(float2(-127,-127), r1.yz);
      r3.x = -fogLayerA.x + cameraPos.y;
      r3.x = fogLayerA.z * r3.x;
      r3.x = max(-127, r3.x);
      r3.x = exp2(-r3.x);
      r3.x = fogLayerA.y * r3.x;
      r3.y = cmp(5.96046448e-08 < abs(r1.z));
      r3.z = exp2(-r1.z);
      r3.z = 1 + -r3.z;
      r3.z = r3.z / r1.z;
      r1.z = -r1.z * 0.240226507 + 0.693147182;
      r1.z = r3.y ? r3.z : r1.z;
      r3.y = -fogLayerB.z + cameraPos.y;
      r3.y = fogLayerB.x * r3.y;
      r3.y = max(-127, r3.y);
      r3.y = exp2(-r3.y);
      r3.y = fogLayerB.y * r3.y;
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
      r1.y = max(fogAmbient.w, r1.y);
      r3.xy = saturate(r0.ww * fogAddParams.yw + fogAddParams.xz);
      r0.w = r3.x + r1.y;
      r0.w = r0.w + r3.y;
      r1.x = min(1, r0.w);
      r0.w = 1 + -r1.x;
      r2.xyz = fogAmbient.xyz * r0.www;
    }
    r3.xyz = r4.xyz * r1.xxx;
    r0.w = r1.w * r1.w + 1;
    r0.w = 0.0596831031 * r0.w;
    r1.yzw = fogHeightA.xyz * r0.www + fogHeightC.xyz;
    r0.w = -fogColorParams.w * fogColorParams.w + 1;
    r3.w = 12.566371 * r2.w;
    r2.w = sqrt(r2.w);
    r2.w = r3.w * r2.w;
    r2.w = max(0.00100000005, r2.w);
    r0.w = r0.w / r2.w;
    r1.yzw = saturate(fogHeightB.xyz * r0.www + r1.yzw);
    r1.yzw = float3(255,255,255) * r1.yzw;
    r4.xyz = float3(1,1,1) + -r4.xyz;
    r1.yzw = r4.xyz * r1.yzw;
    r1.xyz = r1.yzw * r1.xxx + r2.xyz;
    r0.xyz = r0.xyz * r3.xyz + r1.xyz;
  }

  // ===== 27. Output: o0 = colour, o1 = motion vectors + flags =====
  o0.xyz = r0.xyz;
  o0.w = 1;
  o1.z = 1;

#if DEBUG_VIS == 1
  o0 = float4(dbgBaseColor, 1);
#elif DEBUG_VIS == 2
  o0 = float4(dbgShadingN * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 3
  o0 = float4(dbgShadingNSplat * 0.5 + 0.5, 1);
#elif DEBUG_VIS == 4
  o0 = float4(dbgSssTint, 1);
#elif DEBUG_VIS == 5
  o0 = float4(dbgShadowLut, 1);
#elif DEBUG_VIS == 6
  o0 = float4(dbgRamp, 1);
#elif DEBUG_VIS == 7
  o0 = float4(dbgRampChroma, dbgRampChroma, dbgRampChroma, 1);
#elif DEBUG_VIS == 8
  o0 = float4(dbgLitPreRim, 1);
#elif DEBUG_VIS == 9
  o0 = float4(dbgRim, 1);
#elif DEBUG_VIS == 10
  o0 = float4(dbgOneMinusAbsNdotV, dbgOneMinusAbsNdotV, dbgOneMinusAbsNdotV, 1);
#elif DEBUG_VIS == 11
  o0 = float4(dbgPreFog, 1);
#endif
  return;
}