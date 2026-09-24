// ZMD / Endfield PS - Step 4: readable resource names, CB aliases, section map
// Source dump: 3Dmigoto 2026-09-22 14:59:35
//
// Same toon-skin family as 14:03:15, but bindings shifted and detail is texture-
// driven (DetailColorAtlas + animated NormalMap) instead of the procedural splat.
// Recipe (inferred):
//   BaseColorMap (+ DetailColorAtlas) -> ShadowColorLUT (shadowed / SSS colour)
//   SkinDiffuseRamp = toon N.L band; FaceSdfMap drives the hard face shadow
//   ViewShiftedSpecMap + SkinSpecMatcap.w = specular / matcap; rim closes it out
// Names marked (inferred) are read off usage, not a symbol table.
// Step 1 (zmd_ps_20260922_145935_step1_renderdoc.hlsl) was Apply-verified by the
// user. This pass changes NO math: every edit is a rename or a comment.
//   - Texture / SamplerState symbols renamed, register(tN/sN) untouched
//   - `const float4 <name> = cbN[i];` aliases so existing swizzles still apply
//   - section comments in main
// Interpolators v0..v10 are deliberately NOT copied into locals.
//
// Known faithfulness risks inherited from the dump (NOT changed here):
//   1. LightTileMaskSB is declared `float val[1]` by 3Dmigoto but holds uint
//      bitmasks; `(int)mask` reinterprets rather than bit-casts.
//   2. Cube-face cookie unwrap may use `(uint)cmpResult` numeric convert.
//
// Interpolators:
//   v0  SV_Position          v1  base UV (.xy)
//   v2  world position       v3  geometric normal / tangent basis (.xyz)
//   v4  bitangent (.xyz, .w handedness)
//   v5  current-frame clip pos   v6  previous-frame clip pos
//   v7  (present; unused in this dump body)
//   v8  (present; unused in this dump body)
//   v9  instance index (nointerpolation)
//   v10 SV_IsFrontFace
//
// Bindings:
//   t0  LightTileMaskSB      per-tile light bitmasks (8 words per tile)
//   t1  InstanceDataSB       per-instance floats
//   t2  ShadowMap            SampleCmpLevelZero
//   t3  ScreenData           Load at pixel: .x AO, .y mask
//   t4/t5   VolumeFine_Weights / VolumeFine_SH
//   t6/t7   VolumeMid_Weights / VolumeMid_SH
//   t8/t9   VolumeCoarse_Weights / VolumeCoarse_SH
//   t10 SkinDiffuseRamp      toon N.L ramp, V = 0.5
//   t11 ViewShiftedSpecMap   view·TBN offset into UV (inferred)
//   t12 DetailColorAtlas     half-res colour tile (inferred)
//   t13 ShadowColorLUT       32-slice colour cube atlas
//   t14 NormalMap            animated detail/stroke normal
//   t15 SkinSpecMatcap       .z mask @ UV, .w matcap @ view N (inferred)
//   t16 BaseColorMap
//   t17 FaceSdfMap           SDF face shadow, U mirrored by sun facing
//   t18 MaskMap              packed masks: wrap / N-bend / edge / rim
//   t19 LightCookieAtlas
//   t20 VolumetricFog3D
Texture3D<float4> VolumetricFog3D : register(t20);

Texture2D<float4> LightCookieAtlas : register(t19);

Texture2D<float4> MaskMap : register(t18);

Texture2D<float4> FaceSdfMap : register(t17);

Texture2D<float4> BaseColorMap : register(t16);

Texture2D<float4> SkinSpecMatcap : register(t15);

Texture2D<float4> NormalMap : register(t14);

Texture2D<float4> ShadowColorLUT : register(t13);

Texture2D<float4> DetailColorAtlas : register(t12);

Texture2D<float4> ViewShiftedSpecMap : register(t11);

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

SamplerState sampMask : register(s6);

SamplerState sampFaceSdf : register(s5);

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
  const float4 timeParams = cb0[102];               // .x drives NormalMap UV animation phase
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
  const float4 sunDirOffset = cb0[197];             // added to cb3[0] before normalising
  const float4 blendWeights = cb0[198];             // per-feature lerp weights
  const float4 specParams = cb0[199];               // .w GGX/spec weight into ViewShiftedSpecMap
  const float4 extraRimColor = cb0[200];            // secondary rim/fill colour * mask (inferred)
  const float4 rampSoftness = cb0[201];             // .z softens the toon ramp threshold (inferred)
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
  const float4 matParams = cb5[0];                  // .x smoothness .y specular .z metallic .w unused here
  const float4 matTwoSided = cb5[1];                // .y backface normal flip
  const float4 gradeParams = cb5[3];                // .x enable .y exposure .z sat .w contrast
  const float4 gradeRimParams = cb5[4];             // .x NdotV width .y strength
  const float4 baseColorTint = cb5[5];
  const float4 gradeTintColor = cb5[7];             // .w tint blend
  const float4 gradeRimColor = cb5[8];
  const float4 matDetail = cb5[11];                 // .xy edge-tint range, .z atlas tile, .w detail blend
  const float4 sssEdgeTintColor = cb5[12];          // skin edge tint colour, multiplies base colour
  const float4 matSpecUvScale = cb5[16];            // .xy scales view·TBN offset into ViewShiftedSpecMap

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
    r3.xy = int2(2,1) + asint(cb1[r2.w+5].xx);
    r4.x = InstanceDataSB[r3.x].val[0/4];
    r4.y = InstanceDataSB[r3.x].val[0/4+1];
    r4.z = InstanceDataSB[r3.x].val[0/4+2];
    r4.w = InstanceDataSB[r3.x].val[0/4+3];
    r3.x = InstanceDataSB[r3.y].val[0/4];
    r3.y = InstanceDataSB[r3.y].val[0/4+1];
    r3.z = InstanceDataSB[r3.y].val[0/4+2];
    r5.x = InstanceDataSB[cb1[r2.w+5].x].val[0/4];
    r5.y = InstanceDataSB[cb1[r2.w+5].x].val[0/4+1];
    r5.z = InstanceDataSB[cb1[r2.w+5].x].val[0/4+2];
    r5.w = InstanceDataSB[cb1[r2.w+5].x].val[0/4+3];
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

  // ===== 3. Base colour + DetailColorAtlas blend, then sRGB -> ShadowColorLUT UV =====
  // Detail tile from matDetail.z (half-res atlas); blend = matDetail.w * atlas.a.
  // r5.xyz = sRGB(base.zxy), r9.xzw = atlas UV / slice for ShadowColorLUT.
  r3.xyzw = BaseColorMap.SampleBias(sampBaseColor, v1.xy, mipBiasParams.x).wxyz;
  r4.w = matDetail.z * 0.5;
  r5.x = cmp(r4.w >= -r4.w);
  r5.y = frac(abs(r4.w));
  r5.x = r5.x ? r5.y : -r5.y;
  r4.w = floor(r4.w);
  r5.y = 0.5 * r4.w;
  r5.xy = v1.xy * float2(0.5,0.5) + r5.xy;
  r5.xyzw = DetailColorAtlas.SampleBias(sampBaseColor, r5.xy, mipBiasParams.x).xyzw;
  r9.xyz = baseColorTint.xyz * r3.yzw;
  r4.w = matDetail.w * r5.w;
  r3.yzw = -r3.yzw * baseColorTint.xyz + r5.xyz;
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

  // ===== 4. MaskMap + geometric / two-sided normal, sun in local frame =====
  // .y bends shading N toward the radial vector; .x/.z later scale wrap / edge.
  r10.xyzw = MaskMap.SampleBias(sampMask, v1.xy, mipBiasParams.x).xyzw;
  r6.xz = v2.xz + -r6.yx;
  r6.yw = float2(6.10351562e-05,6.10351562e-05);
  r5.y = dot(r6.xyz, r6.xyz);
  r5.y = rsqrt(r5.y);
  r6.xyz = r6.xyz * r5.yyy;
  r5.y = matTwoSided.y * 2 + -1;
  r5.y = v10.x ? 1 : r5.y;
  r5.z = dot(v3.xyz, v3.xyz);
  r5.z = rsqrt(r5.z);
  r11.xyz = v3.xyz * r5.zzz;
  r12.xyz = r11.xyz * r5.yyy;
  r13.xy = (uint2)v0.xy;
  r14.x = dot(sunDir.xyz, r7.xyz);
  r14.y = dot(sunDir.xyz, r8.xyz);
  r14.z = dot(sunDir.xyz, r4.xyz);
  r5.z = dot(r14.xyz, r14.xyz);
  r5.z = max(1.17549435e-38, r5.z);
  r5.z = rsqrt(r5.z);
  r5.zw = r14.xz * r5.zz;
  r5.z = dot(r5.zw, r5.zw);
  r5.z = rsqrt(r5.z);
  r7.w = r5.w * r5.z;
  r8.w = -exposureAlt.x + 1;
  r8.w = blendWeights.w * r8.w + exposureAlt.x;
  r8.w = exposure.x * r8.w;
  r12.w = 6.10351562e-05;
  r9.y = dot(r12.xzw, r12.xzw);
  r9.y = rsqrt(r9.y);
  r14.xyz = r12.xwz * r9.yyy + -r6.xyz;
  r14.xyz = r10.yyy * r14.xyz + r6.xyz;
  r9.y = dot(r14.xyz, r14.xyz);
  r9.y = rsqrt(r9.y);
  r14.xyz = r14.xyz * r9.yyy;

  // ===== 5. Volume probe GI: three 3D cascades, each weights + SH textures =====
  r9.y = cmp(featureToggles.y < 0.5);
  if (r9.y != 0) {
    r15.xyz = sunDir.xzy * -volumeCascadeDist.www + volumeOrigin.xzy;
    r15.xyz = v2.xzy + -r15.xyz;
    r9.y = max(abs(r15.x), abs(r15.y));
    r9.y = -464 + r9.y;
    r9.y = saturate(0.03125 * r9.y);
    r11.w = -208 + abs(r15.z);
    r11.w = saturate(0.03125 * r11.w);
    r9.y = max(r11.w, r9.y);
    r11.w = cmp(0.000000 != volumeOrigin.w);
    r12.w = cmp(r9.y < 1);
    r11.w = r11.w ? r12.w : 0;
    if (r11.w != 0) {
      r15.xyz = sunDir.xzy * -volumeCascadeDist.yyy + volumeOrigin.xzy;
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
        r16.xyz = volumeGridSize.xyz * r15.xyz;
        r16.xyz = floor(r16.xyz);
        r15.xyz = r15.xyz * volumeGridSize.xyz + -r16.xyz;

        // --- 5a. Fine cascade (x2 grid): weights t4, SH bands t5 ---
        r16.xyw = VolumeFine_Weights.SampleLevel(sampVolumeWeights, r15.xyz, 0).yzx;
        r12.w = 1 + -r11.w;
        r17.x = volumeGridSize.y * 0.5;
        r17.y = -volumeGridSize.y * 0.5 + 1;
        r15.y = max(r17.x, r15.y);
        r15.y = min(r15.y, r17.y);
        r15.w = 0.333333343 * r15.y;
        r17.xyzw = VolumeFine_SH.SampleLevel(sampLinear, r15.xwz, 0).xyzw;
        r15.y = r17.w * r12.w + r9.y;
        r18.xyz = float3(0,0.666666687,0) + r15.xwz;
        r18.xyz = VolumeFine_SH.SampleLevel(sampLinear, r18.xyz, 0).xyz;
        r18.xyz = r18.xyz * float3(4,4,4) + float3(-2,-2,-2);
        r18.xyz = r18.xyz * r16.yyy;
        r18.w = r16.y;
        r18.xyzw = r18.xyzw * r12.wwww;
        r15.xzw = float3(0,0.333333343,0) + r15.xwz;
        r15.xzw = VolumeFine_SH.SampleLevel(sampLinear, r15.xzw, 0).xyz;
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
      r15.xzw = sunDir.xzy * -volumeCascadeDist.zzz + volumeOrigin.xzy;
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
        r17.xyz = volumeGridSize.xyz * r15.xzw;
        r17.xyz = floor(r17.xyz);
        r17.xyz = r15.xzw * volumeGridSize.xyz + -r17.xyz;

        // --- 5b. Mid cascade (x0.5 grid): weights t6, SH bands t7 ---
        r20.xyw = VolumeMid_Weights.SampleLevel(sampVolumeWeights, r17.xyz, 0).yzx;
        r15.x = 1 + -r12.w;
        r11.w = r15.x * r11.w;
        r15.x = volumeGridSize.y * 0.5;
        r15.z = -volumeGridSize.y * 0.5 + 1;
        r15.x = max(r17.y, r15.x);
        r15.x = min(r15.x, r15.z);
        r17.w = 0.333333343 * r15.x;
        r21.xyzw = VolumeMid_SH.SampleLevel(sampLinear, r17.xwz, 0).xyzw;
        r15.y = r21.w * r11.w + r15.y;
        r15.xzw = float3(0,0.666666687,0) + r17.xwz;
        r15.xzw = VolumeMid_SH.SampleLevel(sampLinear, r15.xzw, 0).xyz;
        r15.xzw = r15.xzw * float3(4,4,4) + float3(-2,-2,-2);
        r22.xyz = r15.xzw * r20.yyy;
        r22.w = r20.y;
        r18.xyzw = r22.xyzw * r11.wwww + r18.xyzw;
        r15.xzw = float3(0,0.333333343,0) + r17.xwz;
        r15.xzw = VolumeMid_SH.SampleLevel(sampLinear, r15.xzw, 0).xyz;
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
        r17.xyz = volumeGridSize.xyz * r15.xzw;
        r20.xyz = volumeGridSize.xyz * float3(0.5,0.5,0.5);
        r17.xyz = floor(r17.xyz);
        r15.xzw = r15.xzw * volumeGridSize.xyz + -r17.xyz;
        r17.xyz = -volumeGridSize.xyz * float3(0.5,0.5,0.5) + float3(1,1,1);
        r15.xzw = max(r15.xzw, r20.xyz);
        r21.xyz = min(r15.xzw, r17.xyz);

        // --- 5c. Coarse cascade (x0.125 grid): weights t8, SH bands t9 ---
        r22.xyw = VolumeCoarse_Weights.SampleLevel(sampVolumeWeights, r21.xyz, 0).yzx;
        r11.w = 1 + -r9.y;
        r11.w = r12.w * r11.w;
        r12.w = max(r21.y, r20.y);
        r12.w = min(r12.w, r17.y);
        r21.w = 0.333333343 * r12.w;
        r17.xyzw = VolumeCoarse_SH.SampleLevel(sampLinear, r21.xwz, 0).xyzw;
        r15.xzw = float3(0,0.666666687,0) + r21.xwz;
        r15.xzw = VolumeCoarse_SH.SampleLevel(sampLinear, r15.xzw, 0).xyz;
        r15.xzw = r15.xzw * float3(4,4,4) + float3(-2,-2,-2);
        r20.xyz = r15.xzw * r22.yyy;
        r20.w = r22.y;
        r18.xyzw = r20.xyzw * r11.wwww + r18.xyzw;
        r15.xzw = float3(0,0.333333343,0) + r21.xwz;
        r15.xzw = VolumeCoarse_SH.SampleLevel(sampLinear, r15.xzw, 0).xyz;
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

    // --- 5d. Add the constant SH ambient (cb0[213..215] = R/G/B bands) ---
    r17.xyzw = volumeSHAmbientR.xyzw * r15.yyyx;
    r17.y = r17.w * 0.5 + r17.y;
    r15.zw = volumeSHAmbientR.wy * r15.yx;
    r17.w = r15.w * 0.375 + r15.z;
    r16.xyzw = r17.xyzw + r16.xyzw;
    r17.xyzw = volumeSHAmbientG.xyzw * r15.yyyx;
    r17.y = r17.w * 0.5 + r17.y;
    r15.zw = volumeSHAmbientG.wy * r15.yx;
    r17.w = r15.w * 0.375 + r15.z;
    r17.xyzw = r19.xyzw + r17.xyzw;
    r19.xyzw = volumeSHAmbientB.xyzw * r15.yyyx;
    r19.y = r19.w * 0.5 + r19.y;
    r15.xy = volumeSHAmbientB.wy * r15.yx;
    r19.w = r15.y * 0.375 + r15.x;
    r15.xyzw = r19.xyzw + r18.xyzw;
    r14.w = 1;
    r18.x = dot(r16.xyzw, r14.xyzw);
    r18.y = dot(r17.xyzw, r14.xyzw);
    r18.z = dot(r15.xyzw, r14.xyzw);
    r18.xyz = max(float3(0,0,0), r18.xyz);
    r19.xyw = r18.yzx * r8.www;

    // --- 5e. Dominant GI direction from the luminance-weighted SH ---
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

    // --- 5f. RGB -> hue/sat/val sort, rebuild a saturation-boosted GI colour ---
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
    r16.xyz = ambientFallback.xyz;
  }
  r5.zw = r5.ww * r5.zz + float2(0.5,-0.75);
  r5.z = saturate(r5.z);
  r9.y = 1 + -r5.z;
  r5.z = r10.y * r9.y + r5.z;
  r5.z = r10.x * r5.z;

  // ===== 6. Skin edge tint: (1 - N.V) curve tints base toward sssEdgeTintColor =====
  // Strength remapped by matDetail.xy and SkinParamsMap.z.
  r9.y = saturate(dot(r12.xyz, r2.xyz));
  r9.y = r9.y * 0.850000024 + 0.150000006;
  r9.y = 1 + -r9.y;
  r10.x = matDetail.x + -matDetail.y;
  r10.x = r10.z * r10.x + matDetail.y;
  r10.x = r10.x * r5.z;
  r9.y = saturate(r10.x * r9.y);
  r10.x = 1 + -r9.y;
  r15.xyz = sssEdgeTintColor.xyz * r9.yyy + r10.xxx;
  r17.xyz = r15.xyz * r3.yzw;
  r9.y = matParams.y * r10.y;

  // ===== 7. Detail/stroke path (instance height gate vs cb1[+12]) =====
  // Animated NormalMap + SkinSpecMatcap.z mask; builds shading N (r18) and
  // coverage (r10.x). Falls back to geometric N when the gate is off.
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
    r10.x = timeParams.x * 0.800000012;
    r18.y = frac(r10.x);
    r18.xz = float2(0,0);
    r18.xy = v1.xy + r18.xy;
    r19.xyzw = NormalMap.SampleBias(sampBaseColor, r18.xy, mipBiasParams.x).xyzw;
    r10.x = timeParams.x * 0.800000012 + 0.00499999989;
    r18.w = frac(r10.x);
    r18.xy = v1.xy + r18.zw;
    r18.x = NormalMap.SampleBias(sampBaseColor, r18.xy, mipBiasParams.x).w;
    r10.x = SkinSpecMatcap.SampleBias(sampBaseColor, v1.xy, mipBiasParams.x).z;
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
    r11.w = -r10.y * matParams.y + 3;
    r9.y = r2.w * r11.w + r9.y;
    r2.w = 0.300000012;
  } else {
    r2.w = -matParams.x + 1;
    r18.xyz = r12.xyz;
    r10.x = 0;
  }

  // ===== 8. Metallic split: diffuse albedo vs F0 (0.04 * specular) =====
  r11.w = -matParams.z * 0.959999979 + 0.959999979;
  r19.xyz = r17.xyz * r11.www;
  r9.y = 0.0399999991 * r9.y;
  r3.yzw = r3.yzw * r15.xyz + -r9.yyy;
  r3.yzw = matParams.zzz * r3.yzw + r9.yyy;

  // ===== 9. ShadowColorLUT: two adjacent slices blended by fractional slice =====
  // Output r9 = shadowed / subsurface colour for this base colour.
  r15.xyz = ShadowColorLUT.SampleLevel(sampShadowLUT, r9.xz, 0).xyz;
  r9.xy = float2(0.03125,0.015625) + r9.xw;
  r9.xyz = ShadowColorLUT.SampleLevel(sampShadowLUT, r9.xy, 0).xyz;
  r4.w = r5.x * 31 + -r4.w;
  r9.xyz = r9.xyz + -r15.xyz;
  r9.xyz = r4.www * r9.xyz + r15.xyz;
  r9.xyz = r9.xyz * r11.www;
  r4.w = r2.w * r2.w;
  r4.w = max(0.0078125, r4.w);

  // ===== 10. Motion vectors (v5 curr / v6 prev) -> o1.xy, o1.w = stroke flag =====
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

  // ===== 11. Main light direction and colour (cb3 blended by blendWeights) =====
  r15.xzw = mainLightDirRaw.xyz + sunDirOffset.xyz;
  r20.xyz = featureToggles.www * r15.xzw + -mainLightDirRaw.xyz;
  r15.xzw = -mainLightColor.xyz + skyColor.xyz;
  r15.xzw = blendWeights.yyy * r15.xzw + mainLightColor.xyz;
  r5.x = -mainLightColor.w + 1;
  r5.x = blendWeights.w * r5.x + mainLightColor.w;
  r21.xyz = r15.xzw * r5.xxx;
  r13.z = 0;

  // ===== 12. Screen data at this pixel: .x AO (blended by screenAoBlend), .y mask =====
  r22.xy = ScreenData.Load(r13.xyz).xy;
  r9.w = -1 + r22.x;
  r9.w = screenAoBlend.x * r9.w + 1;
  r12.w = 1 + -r9.w;
  r9.w = featureToggles.z * r12.w + r9.w;
  r22.xzw = lightScales.zzz * r9.xyz;
  r23.xyz = float3(0.649999976,0.649999976,0.649999976) * r22.xzw;
  r24.x = dot(r20.xyz, r7.xyz);
  r24.z = dot(r20.xyz, r4.xyz);
  r24.y = 6.10351562e-05;
  r12.w = dot(r24.xyz, r24.xyz);
  r12.w = rsqrt(r12.w);
  r24.xy = r24.xz * r12.ww;
  r12.w = cmp(0 < r24.x);
  r12.w = r12.w ? 1.000000 : 0;
  r13.z = 1 + -v1.x;
  r14.w = v1.x + -r13.z;
  r25.x = r12.w * r14.w + r13.z;
  r25.y = v1.y;

  // ===== 13. Face SDF shadow map: U mirrored by sun facing =====
  // SDF threshold (.z) is remapped against the light yaw to give the hard,
  // stable anime face shadow; the result also bends the shading normal.
  r25.xyzw = FaceSdfMap.SampleLevel(sampFaceSdf, r25.xy, 0).xyzw;
  r13.z = r25.x + r25.y;
  r14.w = -r25.z * 2 + 1;
  r16.w = r25.z * 2 + -1;
  r16.w = r16.w + -r14.w;
  r25.x = r12.w * r16.w + r14.w;
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
  r14.w = dot(sunDir.xz, sunDir.xz);
  r14.w = rsqrt(r14.w);
  r25.xy = sunDir.xz * r14.ww;
  r14.w = dot(r24.xz, r25.xy);
  r14.w = saturate(-r14.w);
  r16.w = saturate(-r24.y);
  r14.w = r16.w * r14.w;
  r24.xz = -blendWeights.xy + float2(1,1);
  r14.w = r24.x * r14.w;
  r12.w = 0.5 + r12.w;
  r12.w = r14.w * r12.w + r24.y;
  r14.w = 0.5 * r12.w;
  r12.w = -r12.w * 0.5 + 0.5;
  r12.w = max(0.00100000005, r12.w);
  r12.w = min(0.999000013, r12.w);
  r16.w = rampSoftness.z * 0.5;
  r17.w = -rampSoftness.z * 0.5 + 0.5;
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
  r14.w = sunDirOffset.w * blendWeights.x + r14.w;
  r14.w = max(-1, r14.w);
  r14.w = min(1, r14.w);
  r14.w = r14.w + -r12.w;
  r12.w = r10.y * r14.w + r12.w;
  r24.x = r12.w * 0.5 + 0.5;
  r24.y = 0.5;

  // ===== 14. Toon skin diffuse ramp: U = N.L remapped, V = 0.5 =====
  // Ramp chroma later tints the lit result (red terminator on skin).
  r26.xyzw = SkinDiffuseRamp.SampleLevel(sampLinear, r24.xy, 0).xyzw;
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
  r14.x = dot(r14.xyz, ambientFacingDir.xyz);
  r14.x = saturate(ambientFacingRemap.x + r14.x);
  r14.x = r14.x * ambientFacingRemap.y + ambientFacingRemap.z;
  r14.y = featureToggles.y * r14.w;
  r24.xyw = float3(1,1,1) + -r16.xyz;
  r16.xyz = r14.yyy * r24.xyw + r16.xyz;
  r14.xyz = r16.xyz * r14.xxx;

  // ===== 15. Ambient/GI intensity shaping, then combine ramp + shadow colour =====
  r16.x = r8.w * 0.350000024 + 0.649999976;
  r16.yz = max(float2(1.25,0), r8.ww);
  r16.xyz = min(float3(1.5,1.75,1.5), r16.xyz);
  r16.y = r16.y + -r16.x;
  r16.x = featureToggles.x * r16.y + r16.x;
  r24.xyw = r16.xxx * r14.xyz;
  r24.xyw = lightScales.www * r24.xyw;
  r16.x = dot(r21.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r21.xyz = r15.xzw * r5.xxx + -r16.xxx;
  r21.xyz = r14.www * r21.xyz + r16.xxx;
  r14.xyz = r16.zzz * r14.xyz;
  r15.xzw = r15.xzw * blendWeights.yyy + r24.zzz;
  r14.xyz = r14.xyz * r15.xzw + r21.xyz;
  r14.xyz = r14.xyz * lightScales.yyy + -r24.xyw;
  r14.xyz = r9.www * r14.xyz + r24.xyw;
  r5.x = dot(r23.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r15.xzw = r22.xzw * float3(0.649999976,0.649999976,0.649999976) + -r5.xxx;
  r15.xzw = r15.xzw * float3(1.20000005,1.20000005,1.20000005) + r5.xxx;
  r5.x = r5.w * r10.y + r10.z;
  r5.x = saturate(r3.x * r5.x + r26.w);
  r16.xyz = r9.xyz * lightScales.zzz + -r15.xzw;
  r15.xzw = r5.xxx * r16.xyz + r15.xzw;
  r16.xyz = r17.xyz * r11.www + -r15.xzw;
  r15.xzw = r14.www * r16.xyz + r15.xzw;
  r5.x = 1 + -r12.w;
  r16.xyz = r26.xyz * r12.www + r5.xxx;
  r16.xyz = r16.xyz * r15.xzw;
  r5.x = dot(r19.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r21.xyz = r17.xyz * r11.www + -r5.xxx;
  r21.xyz = r21.xyz * float3(1.20000005,1.20000005,1.20000005) + r5.xxx;
  r21.xyz = -r9.xyz * lightScales.zzz + r21.xyz;
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
  r14.w = -lightScales.z + 1;
  r5.x = r5.x * r14.w + lightScales.z;
  r5.x = r12.w * r5.x;
  r16.xyz = r14.xyz * r5.xxx;
  r5.x = -0.5 + r20.y;
  r21.y = r9.w * r5.x + 0.5;
  r5.x = saturate(dot(r18.xyz, r2.xyz));
  r21.xz = sunDir.xz;
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

  // ===== 16. ViewShiftedSpecMap + optional SkinSpecMatcap.w highlight =====
  r7.xy = r7.xy * matSpecUvScale.xy + v1.xy;
  r7.xyz = ViewShiftedSpecMap.SampleBias(sampBaseColor, r7.xy, mipBiasParams.x).xyz;
  if (r15.y != 0) {
    r8.xyz = viewRow1.xyz * r18.yyy;
    r8.xyz = viewRow0.xyz * r18.xxx + r8.xyz;
    r8.xyz = viewRow2.xyz * r18.zzz + r8.xyz;
    r8.z = dot(r8.xyz, r8.xyz);
    r8.z = rsqrt(r8.z);
    r8.xy = r8.xy * r8.zz;
    r8.xy = r8.xy * float2(0.5,0.5) + float2(0.5,0.5);
    r8.x = SkinSpecMatcap.SampleBias(sampLinear, r8.xy, mipBiasParams.x).w;
    r5.w = r8.x * r5.w;
    r8.x = max(0.5, r8.w);
    r8.x = min(1.5, r8.x);
    r8.x = lightScales.w * r8.x;
    r5.w = r8.x * r5.w;
    r8.x = r10.x * r10.x;
    r8.xyz = r8.xxx * r5.www;
  } else {
    r8.xyz = float3(0,0,0);
  }

  // ===== 17. GGX specular for the main light =====
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
  r7.xyz = r20.xyz * specParams.www + r7.xyz;
  r7.xyz = r7.xyz + r8.xyz;
  r7.xyz = r14.xyz * r15.xzw + r7.xyz;
  r5.w = dot(r7.xyz, float3(0.212672904,0.715152204,0.0721750036));
  r8.x = -0.5 + r5.w;
  r8.x = max(0, r8.x);
  r8.x = min(0.5, r8.x);
  r14.y = 0;

  // ===== 18. Toon rim + extraRimColor fill (rimColor/extraRimColor) =====
  r14.xz = rimAxisParams.yx;
  r8.yzw = sunDir.zxy * r14.xyz;
  r8.yzw = sunDir.yzx * r14.yzx + -r8.yzw;
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
  r14.xyz = rimAxisParams.www * float3(10,-0.600000024,-0.399999976) + float3(-3,0.800000012,0.899999976);
  r5.w = r14.z + -r14.y;
  r8.x = -r14.y + r12.w;
  r5.w = 1 / r5.w;
  r5.w = saturate(r8.x * r5.w);
  r8.x = r5.w * -2 + 3;
  r5.w = r5.w * r5.w;
  r5.w = r8.x * r5.w;
  r5.w = r5.w * r7.w;
  r8.x = dot(sunDir.xyz, r8.yzw);
  r8.x = cmp(r8.x < -0.00999999978);
  r8.x = r8.x ? 1.000000 : 0;
  r8.x = max(r8.x, r7.w);
  r14.x = saturate(r14.x);
  r8.x = r8.x * r10.w + -r5.w;
  r5.w = r14.x * r8.x + r5.w;
  r14.xyz = rimColor.xyz * r5.www;
  r14.xyz = rimColor.www * r14.xyz;
  r5.w = dot(r6.xyz, r8.yzw);
  r5.w = saturate(1 + r5.w);
  r3.x = min(r5.w, r3.x);
  r3.x = min(r3.x, r22.y);
  r14.xyz = r14.xyz * r3.xxx;
  r16.xyz = r17.xyz * r11.www + float3(-0.25,-0.25,-0.25);
  r16.xyz = rimAxisParams.zzz * r16.xyz + float3(0.25,0.25,0.25);
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
  r16.xyz = extraRimColor.xyz * r3.xxx;
  r16.xyz = extraRimColor.www * r16.xyz;
  r16.xyz = r16.xyz * r19.xyz;
  r8.xyz = r14.xyz * r8.xyz + r16.xyz;
  r7.xyz = r8.xyz + r7.xyz;

  // ===== 19. Tiled lights: pixel -> 32x32 tile, depth slice -> mask buffer offset =====
  r8.xy = (uint2)r13.xy;
  r8.zw = float2(0.03125,0.03125) * r8.xy;
  r8.zw = floor(r8.zw);
  r3.x = r8.w * tileGridParams.y + r8.z;
  r3.x = 8 * r3.x;
  r3.x = (int)r3.x;
  r5.w = -taaPrevJitter.y * tileDepthParams.w + v0.w;
  r5.w = floor(r5.w);
  r8.z = tileGridParams.w + -1;
  r8.w = max(0, r5.w);
  r8.z = min(r8.w, r8.z);
  r8.w = 8 * r8.z;
  r8.w = (int)r8.w;
  r5.w = cmp(r8.z >= r5.w);
  r8.z = (int)r8.w + asint(lightListBase.y);
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
  r9.w = cmp(matParams.z >= 0.5);
  r9.w = r9.w ? 1.000000 : 0;
  r16.w = 1;
  r17.xyz = r7.xyz;
  r10.y = 0;

  // ===== 20. Tiled light loop: 8 words x 32 bits =====
  while (true) {
    r11.w = cmp(7 < (int)r10.y);
    if (r11.w != 0) break;
    r11.w = (int)r3.x + (int)r10.y;
    r11.w = LightTileMaskSB[r11.w].val[0/4];
    r13.z = (int)r8.z + (int)r10.y;
    r13.z = LightTileMaskSB[r13.z].val[0/4];
    r11.w = (int)r11.w & (int)r13.z;
    r11.w = r5.w ? r11.w : 0;
    r13.z = (uint)r10.y << 5;
    r20.xyz = r17.xyz;
    r14.w = r11.w;

    // --- 20a. Iterate set bits; cb3[light*8 + k + 6] is the light record ---
    while (true) {
      if (r14.w == 0) break;
      r15.y = firstbitlow((uint)r14.w);
      r17.w = 1 << (int)r15.y;
      r17.w = (int)r14.w ^ (int)r17.w;
      r15.y = (int)r13.z + (int)r15.y;
      bitmask.x = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.x = (((uint)r15.y << 3) & bitmask.x) | ((uint)1 & ~bitmask.x);
      bitmask.y = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.y = (((uint)r15.y << 3) & bitmask.y) | ((uint)5 & ~bitmask.y);
      bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.z = (((uint)r15.y << 3) & bitmask.z) | ((uint)6 & ~bitmask.z);
      bitmask.w = ((~(-1 << 29)) << 3) & 0xffffffff;  r21.w = (((uint)r15.y << 3) & bitmask.w) | ((uint)7 & ~bitmask.w);

      // --- 20b. Type 1 = box/OBB bounds: f16x2 packed matrix -> edge fade ---
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

      // --- 20c. Light dispatch: .w selects punctual / tube / capsule / special ---
      r16.z = cmp(cb3[r16.y+6].w < 1.5);
      if (r16.z != 0) {
        bitmask.z = ((~(-1 << 29)) << 3) & 0xffffffff;  r16.z = (((uint)r15.y << 3) & bitmask.z) | ((uint)3 & ~bitmask.z);
        r18.w = cmp(16 == asint(cb3[r16.z+6].w));
        r19.w = cb3[r16.z+6].z + blendWeights.z;
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

            // --- 20d. Light cookie: 2D projection or cube-face unwrap -> atlas ---
            r18.w = LightCookieAtlas.SampleLevel(sampLinear, r22.zw, 0).x;
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
                  r22.z = (asuint(cb3[r22.x+6].w) >> 16) & 0xffu;
                  r22.w = (asuint(cb3[r22.x+6].w) >> 8) & 0xffu;
                  r21.z = r24.x ? r21.z : r22.z;
                  r22.x = 255 & asint(cb3[r22.x+6].w);
                  r22.x = r24.y ? r22.w : r22.x;
                  r22.z = (asuint(cb3[r16.z+6].x) >> 8) & 0xffu;
                  r22.w = 255 & asint(cb3[r16.z+6].x);
                  r22.z = r24.z ? r22.z : r22.w;
                  r22.x = r26.z ? r22.x : r22.z;
                  r21.y = r21.y ? r21.z : r22.x;
                  r21.z = cmp((int)r21.y < 80);
                  r15.y = r21.z ? r21.y : -1;
                }
                r21.y = cmp((int)r15.y >= 0);
                if (r21.y != 0) {

                  // --- 20e. Shadow: 9-tap cubic PCF against ShadowMap ---
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
                  r26.xy = r21.xy * shadowTexelSize.zw + float2(0.5,0.5);
                  r26.xy = floor(r26.xy);
                  r21.xy = r21.xy * shadowTexelSize.zw + -r26.xy;
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
                  r30.xyz = shadowTexelSize.xxx * r30.yxz;
                  r29.xyz = r29.zyw / r28.xyz;
                  r29.xyz = float3(-2.5,-0.5,1.5) + r29.xyz;
                  r29.xyz = shadowTexelSize.yyy * r29.xyz;
                  r30.w = r29.x;
                  r31.xyzw = r26.xyxy * shadowTexelSize.xyxy + r30.ywxw;
                  r21.xy = r26.xy * shadowTexelSize.xy + r30.zw;
                  r29.w = r30.y;
                  r30.yw = r29.yz;
                  r32.xyzw = r26.xyxy * shadowTexelSize.xyxy + r30.xyzy;
                  r29.xyzw = r26.xyxy * shadowTexelSize.xyxy + r29.wywz;
                  r26.xyzw = r26.xyxy * shadowTexelSize.xyxy + r30.xwzw;
                  r30.xyzw = r28.xxxy * r27.zwyz;
                  r23.w = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r31.xy, r21.z).x;
                  r24.w = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r31.zw, r21.z).x;
                  r24.w = r30.y * r24.w;
                  r23.w = r30.x * r23.w + r24.w;
                  r21.x = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r21.xy, r21.z).x;
                  r21.x = r30.z * r21.x + r23.w;
                  r21.y = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r29.xy, r21.z).x;
                  r21.x = r30.w * r21.y + r21.x;
                  r30.xyzw = r28.yyzz * r27.xyzw;
                  r21.y = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r32.xy, r21.z).x;
                  r21.x = r30.x * r21.y + r21.x;
                  r21.y = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r32.zw, r21.z).x;
                  r21.x = r30.y * r21.y + r21.x;
                  r21.y = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r29.zw, r21.z).x;
                  r21.x = r30.z * r21.y + r21.x;
                  r21.y = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r26.xy, r21.z).x;
                  r21.x = r30.w * r21.y + r21.x;
                  r22.xzw = (int3)r22.xzw | (int3)r24.xyz;
                  r21.y = (int)r22.z | (int)r22.x;
                  r21.y = (int)r22.w | (int)r21.y;
                  r22.x = (int)r21.z & 0x7fffffff;
                  r22.x = cmp(0x7f800000 < (uint)r22.x);
                  r21.y = (int)r21.y | (int)r22.x;
                  r22.x = r28.z * r27.y;
                  r21.z = ShadowMap.SampleCmpLevelZero(sampShadowCmp, r26.zw, r21.z).x;
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
                  r26.xyz = sunDir.xyz * r25.zxy;
                  r26.xyz = sunDir.zxy * r25.xyz + -r26.xyz;
                  r27.xyz = sunDir.zxy * r26.xyz;
                  r26.xyz = sunDir.yzx * r26.yzx + -r27.xyz;
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
                  r27.y = dot(sunDir.xyz, -r26.xyz);
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

  // ===== 21. Per-material colour grade + graded rim (gradeParams, gradeRimParams, cb5[7..8]) =====
  r0.x = cmp(0.5 < gradeParams.x);
  if (r0.x != 0) {
    r0.x = dot(r17.xyz, float3(0.212672904,0.715152204,0.0721750036));
    r3.xyz = r17.xyz + -r0.xxx;
    r0.xyz = gradeParams.zzz * r3.xyz + r0.xxx;
    r0.xyz = float3(-0.5,-0.5,-0.5) + r0.xyz;
    r0.xyz = gradeParams.www * r0.xyz + float3(0.5,0.5,0.5);
    r3.xyz = gradeParams.yyy * r0.xyz;
    r0.xyz = -r0.xyz * gradeParams.yyy + gradeTintColor.xyz;
    r0.xyz = gradeTintColor.www * r0.xyz + r3.xyz;
    r2.w = -gradeRimParams.x + 1;
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
    r3.xyz = gradeRimColor.xyz * r2.www;
    r17.xyz = r3.xyz * gradeRimParams.yyy + r0.xyz;
  }

  // ===== 22. Undo exposure before fog =====
  r0.xyz = r17.xyz / exposure.xxx;

  // ===== 23. Height fog; fogVolumeParams.z > 0 takes the 3D froxel path =====
  r2.w = cmp(blendWeights.w < 0.5);
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
    r3.xyz = fogColorParams.xyz * r1.www;
    r3.xyz = float3(1.44269502,1.44269502,1.44269502) * r3.xyz;
    r3.xyz = exp2(r3.xyz);
    r1.w = dot(-r2.xyz, fogDirParams.xyz);
    r2.w = fogColorParams.w * fogColorParams.w + 1;
    r3.w = dot(r1.ww, fogColorParams.ww);
    r2.w = -r3.w + r2.w;
    r3.w = cmp(0 < fogVolumeParams.z);
    if (r3.w != 0) {
      r13.w = 7 & asint(mipBiasParams.w);
      r4.xyz = mad((int3)r13.xyw, int3(0x19660d,0x19660d,0x19660d), int3(0x3c6ef35f,0x3c6ef35f,0x3c6ef35f));
      r3.w = mad((int)r4.y, (int)r4.z, (int)r4.x);
      r4.x = mad((int)r4.z, (int)r3.w, (int)r4.y);
      r4.y = mad((int)r3.w, (int)r4.x, (int)r4.z);
      r5.x = mad((int)r4.x, (int)r4.y, (int)r3.w);
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
      r3.w = cmp(5.96046448e-08 < abs(r2.x));
      r4.z = exp2(-r2.x);
      r4.z = 1 + -r4.z;
      r4.z = r4.z / r2.x;
      r2.x = -r2.x * 0.240226507 + 0.693147182;
      r2.x = r3.w ? r4.z : r2.x;
      r2.y = -fogLayerB.z + r2.y;
      r2.y = fogLayerB.x * r2.y;
      r2.y = max(-127, r2.y);
      r2.y = exp2(-r2.y);
      r2.y = fogLayerB.y * r2.y;
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
      r1.x = max(fogAmbient.w, r1.x);
      r1.yz = saturate(r0.ww * fogAddParams.yw + fogAddParams.xz);
      r1.x = r1.x + r1.y;
      r1.x = r1.x + r1.z;
      r1.x = min(1, r1.x);
      r5.y = mad((int)r4.y, (int)r5.x, (int)r4.x);
      r1.yz = (uint2)r5.xy >> int2(16,16);
      r1.yz = (uint2)r1.yz;
      r1.yz = r1.yz * float2(3.05180438e-05,3.05180438e-05) + float2(-1,-1);
      r1.yz = r1.yz * fogJitterAmount.ww + r8.xy;
      r2.xy = fogJitterScale.xy * r1.yz;
      r1.y = v0.w * fogSliceParams.x + fogSliceParams.y;
      r1.y = log2(r1.y);
      r1.y = fogSliceParams.z * r1.y;
      r2.z = r1.y / fogVolumeParams.z;
      r4.xyzw = VolumetricFog3D.SampleLevel(sampLinear, r2.xyz, 0).xyzw;
      r1.y = -fogStartDist.z + v0.w;
      r1.y = saturate(1000000 * r1.y);
      r4.xyzw = float4(-0,-0,-0,-1) + r4.xyzw;
      r4.xyzw = r1.yyyy * r4.xyzw + float4(0,0,0,1);
      r1.y = 1 + -r1.x;
      r2.xyz = fogAmbient.xyz * r1.yyy;
      r2.xyz = r2.xyz * r4.www + r4.xyz;
      r1.x = r4.w * r1.x;
    } else {
      r1.y = -cameraPos.y + v2.y;
      r1.z = fogLayerA.z * r1.y;
      r1.y = fogLayerB.x * r1.y;
      r1.yz = max(float2(-127,-127), r1.yz);
      r3.w = -fogLayerA.x + cameraPos.y;
      r3.w = fogLayerA.z * r3.w;
      r3.w = max(-127, r3.w);
      r3.w = exp2(-r3.w);
      r3.w = fogLayerA.y * r3.w;
      r4.x = cmp(5.96046448e-08 < abs(r1.z));
      r4.y = exp2(-r1.z);
      r4.y = 1 + -r4.y;
      r4.y = r4.y / r1.z;
      r1.z = -r1.z * 0.240226507 + 0.693147182;
      r1.z = r4.x ? r4.y : r1.z;
      r4.x = -fogLayerB.z + cameraPos.y;
      r4.x = fogLayerB.x * r4.x;
      r4.x = max(-127, r4.x);
      r4.x = exp2(-r4.x);
      r4.x = fogLayerB.y * r4.x;
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
      r1.y = max(fogAmbient.w, r1.y);
      r4.xy = saturate(r0.ww * fogAddParams.yw + fogAddParams.xz);
      r0.w = r4.x + r1.y;
      r0.w = r0.w + r4.y;
      r1.x = min(1, r0.w);
      r0.w = 1 + -r1.x;
      r2.xyz = fogAmbient.xyz * r0.www;
    }
    r4.xyz = r3.xyz * r1.xxx;
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
    r3.xyz = float3(1,1,1) + -r3.xyz;
    r1.yzw = r3.xyz * r1.yzw;
    r1.xyz = r1.yzw * r1.xxx + r2.xyz;
    r0.xyz = r0.xyz * r4.xyz + r1.xyz;
  }

  // ===== 24. Output: o0 = colour, o1 = motion vectors + flags =====
  o0.xyz = r0.xyz;
  o0.w = 1;
  o1.z = 1;
  return;
}