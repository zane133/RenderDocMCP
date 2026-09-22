// EID 7918 pixel shader - Stage 4f material loader pass.
// Source: current D:\Capture\BG3\handSSSS.rdc, shader hash
// 1288ff5a-12d0d3f6-882c1fc8-590970d9, ps_5_0, 283 DXBC instructions.
//
// Stage 4e was Apply-verified against the original draw. This revision only
// moves the exact cb1[0..13] alias assignments into LoadDyeMaterial(). The
// packed cbuffer, dye math, VT math, and operation order remain unchanged.

cbuffer cbuffer11 : register(b11)
{
    float4 cb11[3];
};

cbuffer cbuffer0 : register(b0)
{
    float4 cb0[7];
};

cbuffer cbuffer1 : register(b1)
{
    float4 cb1[14];
};

SamplerState virtualTextureSampler : register(s0);
SamplerState materialSampler : register(s15);

Texture2D<float4> virtualPageTable : register(t0);
Texture2DArray<float4> normalAtlas : register(t1);
Texture2DArray<float4> baseColorAtlas : register(t2);
Texture2DArray<float4> physicalAtlas : register(t3);
Texture2D<float4> dyeIdMask : register(t4);
Texture2D<float4> clothDetailTexture : register(t5);

struct StructuredElement125
{
    uint val[32]; // 32 dwords = the captured 128-byte structured stride.
};

StructuredBuffer<StructuredElement125> virtualTextureMetadata : register(t125);

// MSKcloth ID anchors. These are routing IDs, not display colours.
static const float3 ID_CLOTH_PRIMARY     = float3(1.0, 0.5, 0.0); // #FF8000
static const float3 ID_CLOTH_SECONDARY   = float3(1.0, 0.0, 0.0); // #FF0000
static const float3 ID_CLOTH_TERTIARY    = float3(1.0, 0.5, 0.5); // #FF8080
static const float3 ID_ACCENT_COLOR      = float3(1.0, 0.0, 0.5); // #FF0080
static const float3 ID_LEATHER_PRIMARY   = float3(0.5, 0.0, 1.0); // #8000FF
static const float3 ID_LEATHER_SECONDARY = float3(0.0, 0.0, 1.0); // #0000FF
static const float3 ID_LEATHER_TERTIARY  = float3(0.5, 0.5, 1.0); // #8080FF
static const float3 ID_CUSTOM_1          = float3(0.0, 0.5, 1.0); // #0080FF
static const float3 ID_METAL_PRIMARY     = float3(0.0, 1.0, 0.5); // #00FF80
static const float3 ID_METAL_SECONDARY   = float3(0.0, 1.0, 0.0); // #00FF00
static const float3 ID_METAL_TERTIARY    = float3(0.5, 1.0, 0.5); // #80FF80
static const float3 ID_CUSTOM_2          = float3(0.5, 1.0, 0.0); // #80FF00

static const float ID_DISTANCE_SCALE = 0.577350;
static const float ID_WEIGHT_BIAS = 0.25;
static const float ID_WEIGHT_SCALE = 4.0;

// Semantic aliases over the original packed float4 cb1[14]. Keeping the
// source array intact preserves the exact b1 layout and pack offsets.
struct DyeMaterial
{
    float4 clothPrimary;
    float4 clothSecondary;
    float4 clothTertiary;
    float4 accentColor;
    float4 leatherPrimary;
    float4 leatherSecondary;
    float4 leatherTertiary;
    float4 custom1;
    float4 metalPrimary;
    float4 metalSecondary;
    float4 metalTertiary;
    float4 custom2;
    float4 materialOverrideA;
    float4 materialOverrideB;
};

DyeMaterial LoadDyeMaterial()
{
    DyeMaterial material;
    material.clothPrimary = cb1[0];
    material.clothSecondary = cb1[1];
    material.clothTertiary = cb1[2];
    material.accentColor = cb1[3];
    material.leatherPrimary = cb1[4];
    material.leatherSecondary = cb1[5];
    material.leatherTertiary = cb1[6];
    material.custom1 = cb1[7];
    material.metalPrimary = cb1[8];
    material.metalSecondary = cb1[9];
    material.metalTertiary = cb1[10];
    material.custom2 = cb1[11];
    material.materialOverrideA = cb1[12];
    material.materialOverrideB = cb1[13];
    return material;
}

uint ubfe(uint width, uint offset, uint src)
{
    if (width == 0u)
        return 0u;
    if (width >= 32u)
        return src >> offset;
    return (src >> offset) & ((1u << width) - 1u);
}

struct PSInput
{
    float4 position : SV_Position;
    linear float2 materialUV : TEXCOORD0;
    linear float3 tangentFrameZ : TEXCOORD1;
    linear float3 tangentFrameX : TEXCOORD2;
    linear float3 tangentFrameY : TEXCOORD3;
    linear float3 detailProjectionNormal : TEXCOORD4;
    linear float3 detailProjectionPosition : TEXCOORD5;
};

struct PSOutput
{
    float4 encodedNormal : SV_Target0;
    float4 baseColorPhysical : SV_Target1;
    float4 materialParams : SV_Target2;
    float4 reservedTarget : SV_Target3;
    float4 virtualTexturePayload : SV_Target4;
};

PSOutput main(PSInput input)
{
    float4 r0 = 0.0;
    float4 r1 = 0.0;
    float4 r2 = 0.0;
    float4 r3 = 0.0;
    float4 r4 = 0.0;
    float4 r5 = 0.0;
    float4 r6 = 0.0;
    float4 r7 = 0.0;
    float4 r8 = 0.0;
    float4 r9 = 0.0;
    float4 r10 = 0.0;
    float4 r11 = 0.0;
    float4 r12 = 0.0;
    PSOutput output = (PSOutput)0;

    DyeMaterial material = LoadDyeMaterial();

    // 0..52: virtual-texture page lookup and normal-map sample.
    r0.xyz = ddx_coarse(input.materialUV.xyxx).xyz;
    r0.xyz = r0.xyz * cb0[4].zwz;

    uint virtualTextureMetadataIndex = asuint(cb0[6].y);
    r1 = asfloat(uint4(
        virtualTextureMetadata[virtualTextureMetadataIndex].val[1],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[2],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[3],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[4]));

    r2.xy = r0.zy * r1.yz;
    r0.w = dot(r2.xy, r2.xy);
    r2.xyz = ddy_coarse(input.materialUV.xyxx).xyz;
    r2.xyz = r2.xyz * cb0[4].zwz;
    r1.yz = r1.yz * r2.zy;
    r1.y = dot(r1.yz, r1.yz);
    r1.z = max(r0.w, r1.y);
    r0.w = min(r0.w, r1.y);
    r0.w = log2(r0.w);
    r1.y = log2(r1.z);
    r1.z = r1.y * 0.5;
    r0.w = (-r0.w * 0.5) + r1.z;
    r0.w = min(r1.x, r0.w);
    r0.w = (r1.y * 0.5) - r0.w;
    r0.w = r0.w - 0.5;
    r0.w = max(r0.w, 0.0);
    r0.w = min(r0.w, cb0[5].x);
    r0.w = r0.w + 0.5;
    r0.w = floor(r0.w);
    r3.zw = asfloat(int2((int)r0.w, (int)r0.w));
    r1.x = exp2(-r0.w);

    r4.xyz = asfloat(uint3(
        virtualTextureMetadata[virtualTextureMetadataIndex].val[12],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[13],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[14]));
    r4.w = r4.y * r4.x;
    r1.yz = frac(input.materialUV.xy);
    r1.y = r1.y * cb0[4].z + cb0[4].x;
    r1.z = r1.z * cb0[4].w + cb0[4].y;
    r4.x = r4.x * r1.y;
    r4.w = r4.w * r1.z;
    r4.xw = r1.xx * r4.xw;
    r4.xw = floor(r4.xw);
    r3.xy = asfloat(int2((int)r4.x, (int)r4.w));

    float4 page0 = virtualPageTable.Load(int3(asint(r3.x), asint(r3.y), asint(r3.z)));
    r3.xyz = page0.xyz;
    r5.x = (float)ubfe(10u, 14u, asuint(r3.y));
    r5.y = (float)ubfe(10u, 4u, asuint(r3.y));
    r5.z = (float)ubfe(7u, 24u, asuint(r3.y));
    r5.w = (float)ubfe(7u, 24u, asuint(r3.x));
    r6.x = (float)(asuint(r3.y) & 15u);
    r6.y = (float)(asuint(r3.x) & 15u);
    r6.z = (float)(asuint(r3.z) & 15u);
    r6.xyz = exp2(r6.xyz);
    r7.xyz = r4.y * r6.xyz;
    r2.w = (r4.z != 2202.0) ? 1.0 : 0.0;
    r6.w = r7.x;
    r3.y = r1.y * r6.x;
    r3.w = r1.z * r6.w;
    r3.yw = frac(r3.yw);

    r4.xy = asfloat(uint2(
        virtualTextureMetadata[virtualTextureMetadataIndex].val[8],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[9]));
    r3.y = r3.y * r4.x + r5.x;
    r3.w = r3.w * r4.y + r5.y;

    r8 = asfloat(uint4(
        virtualTextureMetadata[virtualTextureMetadataIndex].val[20],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[21],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[22],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[23]));
    r5.x = r3.y * r8.x + r8.z;
    r5.y = r3.w * r8.y + r8.w;
    r9.x = r4.x * r6.x;
    r9.y = r4.y * r6.w;
    r9.z = r4.x * r6.x;
    r8.xyz = r8.xyx * r9.xyz;
    r8.xyz = r1.w * r8.xyz;
    r9.xyz = r0.zyz * r8.zyz;
    r8.xyz = r2.zyz * r8.xyz;

    float4 normalSample = normalAtlas.SampleGrad(virtualTextureSampler, r5.xyz, r9.xy, r8.xy);
    r8.xyz = normalSample.yzw;

    // 53..72: unpack tangent normal, transform, encode normal target.
    r8.xyz = r8.zyx * 2.0 - 1.0;
    r8.xyz = (r2.w != 0.0) ? float3(1.0, -1.0, -1.0) : r8.xyz;
    r8.w = -r8.z;
    r3.y = dot(r8.xyw, r8.xyw);
    r3.y = rsqrt(r3.y);
    r8.xyz = r3.y * r8.wxy;
    r9.xyz = r8.z * input.tangentFrameZ.xyz;
    r8.yzw = r8.y * input.tangentFrameY.xyz + r9.xyz;
    r8.yzw = r8.x * input.tangentFrameX.xyz + r8.yzw;
    r8.x = saturate(r8.x);
    r3.y = dot(r8.yzw, r8.yzw);
    r3.y = rsqrt(r3.y);
    r8.yzw = r3.y * r8.yzw;
    r9.xyz = r8.z * cb11[1].xyz;
    r9.xyz = cb11[0].xyz * r8.y + r9.xyz;
    r8.yzw = cb11[2].xyz * r8.w + r9.xyz;
    r3.y = 1.0 - r8.w;
    float normalEncodeDenominator = r3.y;
    r3.y = r8.y / normalEncodeDenominator;
    r3.w = r8.z / normalEncodeDenominator;
    output.encodedNormal.xy = r3.yw * 0.281262 + 0.5;
    output.encodedNormal.zw = 0.0;

    // 73..135: sample MSKcloth and evaluate the 12 captured dye IDs.
    float4 maskTextureSample = dyeIdMask.Sample(materialSampler, input.materialUV.xy);
    float3 dyeIdRGB = maskTextureSample.xyz;

    // Green edge of the ID cube: Metal Primary/Secondary/Tertiary + Custom 2.
    float4 metalCustomDistances;
    metalCustomDistances.x = length(dyeIdRGB - ID_METAL_PRIMARY);
    metalCustomDistances.y = length(dyeIdRGB - ID_METAL_SECONDARY);
    metalCustomDistances.z = length(dyeIdRGB - ID_METAL_TERTIARY);
    metalCustomDistances.w = length(dyeIdRGB - ID_CUSTOM_2);
    float4 metalCustomWeights = max(
        (-metalCustomDistances * ID_DISTANCE_SCALE) + ID_WEIGHT_BIAS,
        0.0) * ID_WEIGHT_SCALE;

    float3 dyeTint = metalCustomWeights.y * material.metalSecondary.xyz;
    dyeTint = metalCustomWeights.x * material.metalPrimary.xyz + dyeTint;
    float3 upperIdTint = metalCustomWeights.w * material.custom2.xyz;
    upperIdTint = metalCustomWeights.z * material.metalTertiary.xyz + upperIdTint;
    dyeTint = upperIdTint + dyeTint;

    // Blue edge: Leather Primary/Secondary/Tertiary + Custom 1.
    float4 leatherCustomDistances;
    leatherCustomDistances.x = length(dyeIdRGB - ID_LEATHER_PRIMARY);
    leatherCustomDistances.y = length(dyeIdRGB - ID_LEATHER_SECONDARY);
    leatherCustomDistances.z = length(dyeIdRGB - ID_LEATHER_TERTIARY);
    leatherCustomDistances.w = length(dyeIdRGB - ID_CUSTOM_1);
    float4 leatherCustomWeights = max(
        (-leatherCustomDistances * ID_DISTANCE_SCALE) + ID_WEIGHT_BIAS,
        0.0) * ID_WEIGHT_SCALE;

    float3 leatherCustomTint = leatherCustomWeights.w * material.custom1.xyz;
    leatherCustomTint = leatherCustomWeights.z * material.leatherTertiary.xyz + leatherCustomTint;
    dyeTint = dyeTint + leatherCustomTint;

    // Red edge: Cloth Primary/Secondary/Tertiary + Accent.
    float4 clothAccentDistances;
    clothAccentDistances.x = length(dyeIdRGB - ID_CLOTH_PRIMARY);
    clothAccentDistances.y = length(dyeIdRGB - ID_CLOTH_SECONDARY);
    clothAccentDistances.z = length(dyeIdRGB - ID_CLOTH_TERTIARY);
    clothAccentDistances.w = length(dyeIdRGB - ID_ACCENT_COLOR);
    float4 clothAccentWeights = max(
        (-clothAccentDistances * ID_DISTANCE_SCALE) + ID_WEIGHT_BIAS,
        0.0) * ID_WEIGHT_SCALE;

    float3 clothAccentTint = clothAccentWeights.w * material.accentColor.xyz;
    clothAccentTint = clothAccentWeights.z * material.clothTertiary.xyz + clothAccentTint;
    float3 leatherPrimarySecondaryTint = leatherCustomWeights.y * material.leatherSecondary.xyz;
    leatherPrimarySecondaryTint =
        leatherCustomWeights.x * material.leatherPrimary.xyz + leatherPrimarySecondaryTint;
    clothAccentTint = clothAccentTint + leatherPrimarySecondaryTint;
    clothAccentTint = dyeTint + clothAccentTint;
    float3 clothPrimarySecondaryTint = clothAccentWeights.y * material.clothSecondary.xyz;
    clothPrimarySecondaryTint =
        clothAccentWeights.x * material.clothPrimary.xyz + clothPrimarySecondaryTint;
    r8.yzw = clothAccentTint + clothPrimarySecondaryTint;

    // 136..168: virtual-texture base-color and physical-map samples.
    r7.w = r6.y;
    r6.xz = r6.zz;
    r3.y = r1.y * r7.w;
    r3.w = r1.z * r7.y;
    r7.x = r4.x * r7.w;
    r7.y = r4.y * r7.y;
    r7.w = r4.x * r7.w;
    r6.y = r7.z;
    r3.yw = frac(r3.yw);

    r9.x = (float)ubfe(10u, 14u, asuint(r3.x));
    r9.y = (float)ubfe(10u, 4u, asuint(r3.x));
    r9.z = (float)ubfe(7u, 24u, asuint(r3.z));
    r9.w = (float)ubfe(10u, 14u, asuint(r3.z));
    r3.x = (float)ubfe(10u, 4u, asuint(r3.z));
    r10.y = r3.x;
    r10.x = r9.w;
    r3.x = r3.y * r4.x + r9.x;
    r3.y = r3.w * r4.y + r9.y;

    r11 = asfloat(uint4(
        virtualTextureMetadata[virtualTextureMetadataIndex].val[16],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[17],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[18],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[19]));
    r5.x = r3.x * r11.x + r11.z;
    r5.y = r3.y * r11.y + r11.w;
    r3.x = r7.x * r11.x;
    r3.y = r7.y * r11.y;
    r3.z = r7.w * r11.x;
    r3.xyz = r1.w * r3.xyz;
    r7.xyz = r0.zyz * r3.zyz;
    r3.xyz = r2.zyz * r3.xyz;

    float4 baseSample = baseColorAtlas.SampleGrad(
        virtualTextureSampler, float3(r5.x, r5.y, r5.w), r7.xy, r3.xy);
    r3.xyz = baseSample.xyz;
    r3.xyz = (r2.w != 0.0) ? float3(1.0, 0.0, 0.0) : r3.xyz;
    r5.xyz = r8.yzw * r3.xyz;
    r3.xyz = (-r3.xyz * r8.yzw) + material.materialOverrideA.xyz;

    r4.z = r1.y * r6.z;
    r4.w = r1.z * r6.y;
    r6.x = r4.x * r6.x;
    r6.y = r4.y * r6.y;
    r6.z = r4.x * r6.z;
    r4.zw = frac(r4.zw);
    r4.z = r4.z * r4.x + r10.x;
    r4.w = r4.w * r4.y + r10.y;

    r7 = asfloat(uint4(
        virtualTextureMetadata[virtualTextureMetadataIndex].val[24],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[25],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[26],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[27]));
    r9.x = r4.z * r7.x + r7.z;
    r9.y = r4.w * r7.y + r7.w;
    r6.x = r6.x * r7.x;
    r6.y = r6.y * r7.y;
    r6.z = r6.z * r7.x;
    r6.xyz = r1.w * r6.xyz;
    r8.y = r0.z * r6.z;
    r8.z = r0.y * r6.y;
    r8.w = r0.z * r6.z;
    r6.xyz = r2.zyz * r6.xyz;

    float4 physicalSampleA = physicalAtlas.SampleGrad(virtualTextureSampler, r9.xyz, r8.yz, r6.xy);
    r4.z = physicalSampleA.x;
    r4.w = physicalSampleA.z;

    // 169..224: dye/material thresholds and the first material targets.
    r3.w = (r2.w != 0.0) ? 0.0 : r4.w;
    r4.z = saturate(r4.z);
    output.materialParams.z = (r2.w != 0.0) ? 1.0 : r4.z;
    r2.w = max(abs(r3.w), 0.0001);
    output.baseColorPhysical.w = r3.w;
    r2.w = log2(r2.w);
    r6.x = material.clothTertiary.w;
    r6.y = material.accentColor.w;
    r4.z = r2.w * r6.x;
    r4.w = r2.w * r6.y;
    r4.zw = exp2(r4.zw);
    r4.zw = (-r4.zw) + r8.xx;
    r4.zw = saturate(r4.zw + 1.0);
    r4.zw = 1.0 - r4.zw;

    r2.w = dot(input.detailProjectionNormal.xyz, input.detailProjectionNormal.xyz);
    r2.w = rsqrt(r2.w);
    r8.yzw = r2.w * input.detailProjectionNormal.xyz;
    r2.w = max(abs(r8.y), 0.0001);
    r2.w = log2(r2.w);
    r2.w = r2.w * 160.0;
    r2.w = exp2(r2.w);

    float4 detailSampleA = clothDetailTexture.Sample(materialSampler, input.materialUV.xy);
    r3.w = detailSampleA.z;
    r3.w = r3.w - 0.5;
    r8.y = r8.y;
    r8.z = r3.w * 0.3 + r8.z;
    r8.w = r3.w * 0.6 + r8.w;
    r8.yzw = max(abs(r8.yzw), 0.0001);
    r8.yzw = log2(r8.yzw);
    r8.yzw = r8.yzw * 160.0;
    r8.yzw = exp2(r8.yzw);
    r3.w = dot(r8.yzw, 1.0.xxx);
    r9.x = r8.w / r3.w;
    r9.y = r8.w / r3.w;
    r9.z = r8.z / r3.w;
    r9.w = r8.z / r3.w;
    r2.w = r2.w / r3.w;
    r2.w = (r2.w >= 0.5) ? 1.0 : 0.0;
    r6.z = r2.w * input.detailProjectionPosition.z;
    r6.w = r2.w * input.detailProjectionPosition.y;
    r9 = float4(
        (r9.x >= 0.5) ? 1.0 : 0.0,
        (r9.y >= 0.5) ? 1.0 : 0.0,
        (r9.z >= 0.5) ? 1.0 : 0.0,
        (r9.w >= 0.5) ? 1.0 : 0.0);
    r9 = r9 * input.detailProjectionPosition.xyxz;
    r8.y = r9.x * 2.8;
    r8.z = r9.y * -2.8;
    r6.z = r6.z * 2.8 + r8.y;
    r6.w = r6.w * -2.8 + r8.z;
    r6.z = r9.z * 2.8 + r6.z;
    r6.w = r9.w * 2.8 + r6.w;

    float4 detailSampleB = clothDetailTexture.Sample(materialSampler, r6.zw);
    r8.yzw = detailSampleB.xyz;
    r2.w = r8.w - 0.7;
    r6.z = max(abs(r8.z), 0.0001);
    r6.w = max(abs(r8.y), 0.0001);
    r6.zw = log2(r6.zw);
    r2.w = max(r2.w, 0.00001);
    r4.zw = r2.ww + r4.zw;
    r9.x = material.leatherPrimary.w;
    r9.y = material.leatherSecondary.w;
    r4.z = (r9.x >= r4.z) ? 1.0 : 0.0;
    r4.w = (r9.y >= r4.w) ? 1.0 : 0.0;
    r10.x = r6.z * material.clothPrimary.w;
    r10.y = r6.w * material.clothSecondary.w;
    r6.z = exp2(r10.x);
    r6.w = exp2(r10.y);
    r4.zw = r4.zw * r6.zw;
    r3.xyz = r4.z * r3.xyz + r5.xyz;
    r5.xyz = (-r3.xyz) + material.materialOverrideB.xyz;
    output.baseColorPhysical.xyz = saturate(r4.w * r5.xyz + r3.xyz);

    // 225..269: second physical-map lookup and packed GBuffer fields.
    r3.zw = asfloat(int2((int)r0.w, (int)r0.w));
    r0.w = r0.w * 0.25;
    r5 = asfloat(uint4(
        virtualTextureMetadata[virtualTextureMetadataIndex].val[12],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[13],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[14],
        virtualTextureMetadata[virtualTextureMetadataIndex].val[15]));
    r10.y = r5.y * r5.x;
    r10.x = r5.x;
    r4.z = r1.y * r10.x;
    r4.w = r1.z * r10.y;
    r4.zw = r1.xx * r4.zw;
    r4.zw = floor(r4.zw);
    r3.xy = asfloat(int2((int)r4.z, (int)r4.w));
    r4.z = r4.z * 0.003906;
    r4.w = r4.w * 0.031250;

    r1.x = virtualPageTable.Load(int3(asint(r3.x), asint(r3.y), asint(r3.z))).z;
    r3.x = (float)(asuint(r1.x) & 15u);
    r3.y = (float)ubfe(10u, 14u, asuint(r1.x));
    r3.z = (float)ubfe(10u, 4u, asuint(r1.x));
    r3.w = (float)ubfe(7u, 24u, asuint(r1.x));
    r1.x = r3.x;
    r10.x = exp2(r1.x);
    r10.z = exp2(r1.x);
    r10.y = r5.y * r10.z;
    r8.y = r4.x * r10.x;
    r8.z = r4.y * r10.y;
    r8.w = r4.x * r10.z;
    r1.xy = r1.yz * r10.xy;
    r1.xy = frac(r1.xy);
    r1.x = r1.x * r4.x + r3.y;
    r1.y = r1.y * r4.y + r3.z;
    r3.y = r1.x * r7.x + r7.z;
    r3.z = r1.y * r7.y + r7.w;
    r1.x = r7.x * r8.y;
    r1.y = r7.y * r8.z;
    r1.z = r7.x * r8.w;
    r1.xyz = r1.w * r1.xyz;
    r0.xyz = r0.xyz * r1.xyz;
    r1.xyz = r1.xyz * r2.xyz;

    float4 physicalSampleB = physicalAtlas.SampleGrad(
        virtualTextureSampler, float3(r3.y, r3.z, r3.w), r0.xy, r1.xy);
    r0.x = physicalSampleB.y;
    r0.y = physicalSampleB.z;
    r0.z = (r5.z != 2202.0) ? 1.0 : 0.0;
    r0.xy = (r0.z != 0.0) ? 0.0.xx : r0.xy;
    r0.y = max(abs(r0.y), 0.0001);
    r0.y = log2(r0.y);
    r0.z = r0.y * r6.y;
    r0.y = r0.y * r6.x;
    r0.yz = exp2(r0.yz);
    r0.yz = (-r0.yz) + r8.xx;
    r0.yz = saturate(r0.yz + 1.0);
    r0.yz = (-r0.yz) + r2.ww;
    r0.yz = r0.yz + 1.0;
    r0.y = (r9.x >= r0.y) ? 1.0 : 0.0;
    r0.z = (r9.y >= r0.z) ? 1.0 : 0.0;
    r0.x = r6.z * r0.y + r0.x;
    output.materialParams.x = saturate((-r6.w * r0.z) + r0.x);

    uint packedMaterial = (asuint(cb0[6].z) & 7u) << 4u;
    r0.x = (float)packedMaterial;
    output.materialParams.w = r0.x * 0.003922;
    output.materialParams.y = saturate(material.leatherTertiary.w);
    output.reservedTarget = 0.0;

    // 271..282: pack remaining virtual-texture/material metadata.
    bool2 nonNegativeZW = r4.zw >= -r4.zw;
    r1.xy = frac(abs(r4.zw));
    r1.zw = floor(r4.zw);
    r2.x = nonNegativeZW.x ? r1.x : -r1.x;
    r2.y = nonNegativeZW.y ? r1.y : -r1.y;
    r2.y = r2.y * 256.0 + r1.z;
    r0.x = floor(r0.w);
    r2.w = r5.w * 4.0 + r0.x;
    bool nonNegativeW = r0.w >= -r0.w;
    r0.y = frac(abs(r0.w));
    r0.x = nonNegativeW ? r0.y : -r0.y;
    r2.z = r0.x * 256.0 + r1.w;
    output.virtualTexturePayload =
        r2 * float4(1.003922, 0.003922, 0.003922, 0.003922);

    return output;
}

