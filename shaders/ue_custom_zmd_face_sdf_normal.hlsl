// UE5 Custom node body. Main output: Float3, blended WORLD-space normal.
// Inputs: FaceSDFTex, FaceControlTex (Texture Objects), UV (float2),
// LightDirectionWS, FaceRightWS, FaceUpWS, FaceForwardWS, NormalWS (float3),
// ControlMipBias (float).
// Additional outputs: SDFNormalWS (Float3), FaceNormal (Float3),
// SDFRaw (Float4), FaceControl (Float4).
// Port of the user's GLSL normal-reconstruction snippet, not the SDF ramp.
// Face basis corresponds to source X=right, Y=up, Z=forward.
// Current mesh: UE local right=+X, up=+Z, forward=+Y; transform these to WS.
// Forward +Y verified from the unrotated actor and the front-view camera.
// Basis must be orthonormal (rotation / uniform scale, no shear).
// LightDirectionWS points TOWARD the light. NormalWS is the unmodified normal:
// use VertexNormalWS, NOT PixelNormalWS (which would create a feedback loop).
// For Tangent Space Normal enabled: TransformVector World -> Tangent before
// connecting to BSDF.Normal. Otherwise connect the world-space output directly.

const float eps = 6.103515625e-05;
const float minLengthSq = 1.17549435e-38;
float3 rightWS = normalize(FaceRightWS.xyz);
float3 upWS = normalize(FaceUpWS.xyz);
float3 forwardWS = normalize(FaceForwardWS.xyz);

// Inverse rotation: world light -> source face coordinates.
// Explicit basis dots avoid GLSL row/column matrix convention ambiguity.
float3 lightFlat = float3(dot(LightDirectionWS.xyz, rightWS), eps,
                         dot(LightDirectionWS.xyz, forwardWS));
float3 lightXZNorm = normalize(lightFlat);
bool fromRight = lightXZNorm.x > 0.0;
float2 sdfUV = float2(fromRight ? UV.x : 1.0 - UV.x, UV.y);
float4 sdfSample = FaceSDFTex.SampleLevel(FaceSDFTexSampler, sdfUV, 0.0);
// Control mask is NOT mirrored; bias 0 gives the implicit-LOD sample.
float4 controlSample = FaceControlTex.SampleBias(
    FaceControlTexSampler, UV, ControlMipBias);

float side = fromRight ? sdfSample.b * 2.0 - 1.0
                       : 1.0 - sdfSample.b * 2.0;
float3 nFace = normalize(float3(side, eps, 1.0 - abs(side)));
float3 sdfNormalUnnormalizedWS = nFace.x * rightWS
                              + nFace.y * upWS
                              + nFace.z * forwardWS;
float3 sdfNormal = sdfNormalUnnormalizedWS * rsqrt(max(
    dot(sdfNormalUnnormalizedWS, sdfNormalUnnormalizedWS), minLengthSq));

// G=0: reconstructed SDF normal; G=1: original mesh normal.
// Blend vectors FIRST, then normalize. No R/G SDF threshold or lighting fold.
float3 mixedNormal = lerp(sdfNormal, NormalWS.xyz, controlSample.g);
float mixedLengthSq = dot(mixedNormal, mixedNormal);
// The pasted normalize is undefined for exact cancellation; use SDF normal
// only in that degenerate case. Ordinary inputs retain the pasted result.
float3 blendedNormal = mixedLengthSq > minLengthSq
    ? mixedNormal * rsqrt(max(mixedLengthSq, minLengthSq)) : sdfNormal;

SDFNormalWS = sdfNormal;
FaceNormal = nFace;
SDFRaw = sdfSample;
FaceControl = controlSample;
return blendedNormal;
