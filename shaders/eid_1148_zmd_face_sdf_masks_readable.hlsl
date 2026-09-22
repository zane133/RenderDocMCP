// ZMD EID 1148 - readable extraction of the two face-mask textures.
//
// Original bindings:
//   t17 / s5 : face SDF + direction guide, sampled explicitly at mip 0.
//   t18 / s6 : packed face-control mask, sampled with the frame mip bias.
//
// FACE_MASK_VIEW:
//   0 = RT0: raw t17 RGBA,       RT1: raw t18 RGBA
//   1 = RT0: t17 R grayscale,    RT1: t17 G grayscale
//   2 = RT0: (R+G)*0.5 SDF,      RT1: t17 B direction encoding
//   3 = RT0: t18 R grayscale,    RT1: t18 G grayscale
//   4 = RT0: t18 B grayscale,    RT1: t18 A grayscale

#ifndef FACE_MASK_VIEW
#define FACE_MASK_VIEW 0
#endif

Texture2D<float4> FaceSdfGuideTexture : register(t17);
Texture2D<float4> FaceControlTexture  : register(t18);

SamplerState FaceSdfSampler     : register(s5);
SamplerState FaceControlSampler : register(s6);

cbuffer FrameConstants : register(b0)
{
    float4 FrameData[216];
}

struct FaceSdfSample
{
    float4 packed;
    float  threshold;       // Original shader: t17.r + t17.g
    float  value01;         // Threshold scaled by 0.5 at both SDF comparisons
    float  signedDirection; // B decoded according to the selected light side
    float3 directionTS;     // Direction guide reconstructed by the original PS
};

// Original mirror rule:
//   projectedLightX > 0 -> U
//   projectedLightX <= 0 -> 1-U
float2 BuildFaceSdfUV(float2 faceUV, float projectedLightX)
{
    float useOriginalU = projectedLightX > 0.0 ? 1.0 : 0.0;
    float mirroredU = 1.0 - faceUV.x;
    float selectedU = useOriginalU * (faceUV.x - mirroredU) + mirroredU;
    return float2(selectedU, faceUV.y);
}

FaceSdfSample SampleFaceSdf(float2 faceUV, float projectedLightX)
{
    FaceSdfSample result;

    float useOriginalU = projectedLightX > 0.0 ? 1.0 : 0.0;
    float2 sdfUV = BuildFaceSdfUV(faceUV, projectedLightX);
    result.packed = FaceSdfGuideTexture.SampleLevel(FaceSdfSampler, sdfUV, 0.0);

    result.threshold = result.packed.r + result.packed.g;
    result.value01 = result.threshold * 0.5;

    // The B channel stores one side. The opposite side negates it.
    float negativeSide = 1.0 - result.packed.b * 2.0;
    float positiveSide = result.packed.b * 2.0 - 1.0;
    result.signedDirection =
        useOriginalU * (positiveSide - negativeSide) + negativeSide;

    float directionZ = 1.0 - abs(result.signedDirection);
    result.directionTS = normalize(
        float3(result.signedDirection, 0.00006103515625, directionZ));

    return result;
}

float4 SampleFaceControl(float2 faceUV)
{
    // t18.g is used by the original shader as the dominant normal/SDF blend
    // control. R, B and A remain packed material/light controls.
    return FaceControlTexture.SampleBias(
        FaceControlSampler, faceUV, FrameData[108].x);
}

void main(
    float4 position      : SV_Position,
    float4 faceUV        : TEXCOORD0,
    float4 worldPosition : TEXCOORD1,
    float4 normal        : TEXCOORD2,
    float4 tangent       : TEXCOORD3,
    float4 data4         : TEXCOORD4,
    float4 data5         : TEXCOORD5,
    float4 data6         : TEXCOORD6,
    float4 data7         : TEXCOORD7,
    nointerpolation uint materialIndex : TEXCOORD8,
    uint frontFace       : SV_IsFrontFace,
    out float4 rt0       : SV_Target,
    out float4 rt1       : SV_Target1)
{
    // Raw extraction does not need the scene light direction. Sampling at the
    // unmirrored UV exposes the source channels exactly as stored in t17/t18.
    float4 sdfGuide = FaceSdfGuideTexture.SampleLevel(
        FaceSdfSampler, faceUV.xy, 0.0);
    float4 faceControl = SampleFaceControl(faceUV.xy);

#if FACE_MASK_VIEW == 1
    rt0 = sdfGuide.rrrr;
    rt1 = sdfGuide.gggg;
#elif FACE_MASK_VIEW == 2
    float sdfValue = (sdfGuide.r + sdfGuide.g) * 0.5;
    rt0 = float4(sdfValue.xxx, 1.0);
    rt1 = float4(sdfGuide.bbb, 1.0);
#elif FACE_MASK_VIEW == 3
    rt0 = faceControl.rrrr;
    rt1 = faceControl.gggg;
#elif FACE_MASK_VIEW == 4
    rt0 = faceControl.bbbb;
    rt1 = faceControl.aaaa;
#else
    rt0 = sdfGuide;
    rt1 = faceControl;
#endif
}
