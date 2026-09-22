// UE5 Material Custom Expression body.
// Inputs:
//   FaceSDFTex, FaceControlTex : Texture Object parameters
//   UV                         : face UV0
//   LightDirectionWS          : normalized direction from face toward light
//   FaceRightWS               : character face-right axis in world space
//   FaceForwardWS             : character face-forward axis in world space
//   NormalWS                  : unperturbed surface normal in world space
//   SDFOffset                 : shifts the light/shadow boundary
//   SDFSoftness               : extra interval padding (0 = recovered curve)
//   ControlMipBias            : mip bias used to sample the packed control map
//   InvertOutput              : 0 returns shadow mask, 1 returns lit mask
//
// Additional Outputs:
//   LitMask, SDFValue, DirectionTS, SDFRaw, FaceControl

float3 lightWS = normalize(LightDirectionWS.xyz);
float3 faceRightWS = normalize(FaceRightWS.xyz);
float3 faceForwardWS = normalize(FaceForwardWS.xyz);

float lightRight = dot(lightWS, faceRightWS);
float lightForward = dot(lightWS, faceForwardWS);
float2 projectedLight = float2(lightRight, lightForward);
projectedLight *= rsqrt(dot(projectedLight, projectedLight) + 3.725290298461914e-9);

// Recovered t17 rule: positive face-right light uses U; the opposite side
// samples 1-U. This lets one texture describe both lighting directions.
float useOriginalU = lightRight > 0.0 ? 1.0 : 0.0;
float mirroredU = 1.0 - UV.x;
float selectedU = useOriginalU * (UV.x - mirroredU) + mirroredU;
float2 sdfUV = float2(selectedU, UV.y);

float4 sdfPacked = FaceSDFTex.SampleLevel(
    FaceSDFTexSampler, sdfUV, 0.0);
float4 controlPacked = FaceControlTex.SampleBias(
    FaceControlTexSampler, UV, ControlMipBias);

// Recovered t17 channel decode.
float sdfValue = saturate((sdfPacked.r + sdfPacked.g) * 0.5);
float negativeDirection = 1.0 - sdfPacked.b * 2.0;
float positiveDirection = sdfPacked.b * 2.0 - 1.0;
float signedDirection = useOriginalU
    * (positiveDirection - negativeDirection) + negativeDirection;

float directionZ = 1.0 - abs(signedDirection);
float3 directionTS = normalize(
    float3(signedDirection, 0.00006103515625, directionZ));

// Recovered interval/fold from the original t17 -> t10 ramp-coordinate path.
// Game-global direction corrections (cb0[197]/cb0[198]) are not supplied by UE;
// projectedLight.y is the uncorrected face-forward component, SDFOffset an
// explicit UE artist adjustment. This is not the full original face lighting.
float forwardTerm = clamp(projectedLight.y + SDFOffset, -1.0, 1.0);
float halfForward = forwardTerm * 0.5;
float interval = clamp(-forwardTerm * 0.5 + 0.5, 0.001, 0.999);
float lower = max(0.0, interval - (1.0 - interval));
float upper = min(1.0, interval + interval);
float extraPadding = max(SDFSoftness, 0.0);
float curveT = saturate((sdfValue - lower + extraPadding)
    / (upper - lower + 2.0 * extraPadding));
float curve = curveT * curveT * (3.0 - 2.0 * curveT);
float sdfSigned = abs(-curve - ceil(halfForward) * halfForward) * 2.0 - 1.0;

// Original r10.y = t18.G blends the SDF signed response toward geometric N.L.
float3 surfaceNormalWS = normalize(NormalWS.xyz);
float normalSigned = clamp(dot(surfaceNormalWS, lightWS), -1.0, 1.0);
float mixedSigned = controlPacked.g * (normalSigned - sdfSigned) + sdfSigned;
float litMask = saturate(mixedSigned * 0.5 + 0.5);
float shadowMask = 1.0 - litMask;

LitMask = litMask;
SDFValue = sdfValue;
DirectionTS = directionTS;
SDFRaw = sdfPacked;
FaceControl = controlPacked;

return lerp(shadowMask, litMask, saturate(InvertOutput));
