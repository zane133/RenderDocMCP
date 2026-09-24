// Ghost of Tsushima grass-wind study
// -----------------------------------
// This is a readable study/reference, NOT an Apply-compatible replacement for
// the captured shader. The first half reconstructs the important structure seen
// in the decompiled vertex shader. The second half is a recommended stateful
// spring model for reeds whose recovery currently feels artificial.

static const float PI = 3.14159265358979323846f;

struct GrassWindInput
{
    float3 positionWS;
    float3 normalWS;
    float3 tangentWS;
    float3 anchorWS;

    // 0 at the root, 1 at the tip. Store this in vertex colour or a spare UV.
    float bladeHeight;

    // Stable per clump/instance value. Never derive it from vertex position alone,
    // otherwise adjacent vertices can receive different phases and tear the blade.
    float instanceRandom;
};

struct GrassWindOutput
{
    float3 positionWS;
    float3 normalWS;
    float3 tangentWS;
};

float Hash11(float value)
{
    return frac(sin(value * 12.9898f) * 43758.5469f);
}

float3 SafeNormalize(float3 value, float3 fallback)
{
    float lengthSquared = dot(value, value);
    return lengthSquared > 1.0e-8f ? value * rsqrt(lengthSquared) : fallback;
}

// Rodrigues rotation. The captured shader expands this matrix into scalar
// multiplies, then applies the same rotation to position, normal and tangent.
float3 RotateAroundAxis(float3 value, float3 unitAxis, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    return value * c
         + cross(unitAxis, value) * s
         + unitAxis * dot(unitAxis, value) * (1.0f - c);
}

float3 WindDirectionToBendAxis(float3 windDirectionWS)
{
    float3 horizontalWind = SafeNormalize(
        float3(windDirectionWS.x, 0.0f, windDirectionWS.z),
        float3(1.0f, 0.0f, 0.0f));

    // A horizontal axis perpendicular to wind makes the blade lean with wind.
    return float3(-horizontalWind.z, 0.0f, horizontalWind.x);
}

// -----------------------------------------------------------------------------
// A. Readable reconstruction of the captured shader's important wind structure
// -----------------------------------------------------------------------------

struct ProceduralGrassWind
{
    float3 directionWS;
    float strengthRadians;
    float frequency;
    float spatialFrequency;
    float gustFrequency;
    float gustAmount;
};

float EvaluateGhostStyleBendAngle(
    GrassWindInput blade,
    ProceduralGrassWind wind,
    float timeSeconds)
{
    // The dump effectively uses a clamped height followed by a square. Squaring
    // anchors the root and lets most motion accumulate toward the tip.
    float heightWeight = saturate(blade.bladeHeight);
    heightWeight *= heightWeight;

    // Stable dephasing prevents every clump from moving as one rigid sine wave.
    float phaseOffset = blade.instanceRandom * (2.0f * PI);
    float spatialPhase = dot(blade.anchorWS.xz, float2(0.73f, 1.17f));
    float phase = timeSeconds * wind.frequency
                + spatialPhase * wind.spatialFrequency
                + phaseOffset;

    // The captured shader modulates a base bend with another low-amplitude sine.
    float microVariation = sin(phase * wind.gustFrequency + phaseOffset * 1.37f);
    float gustMultiplier = 1.0f + microVariation * wind.gustAmount;

    return heightWeight * wind.strengthRadians * gustMultiplier;
}

GrassWindOutput EvaluateGhostStyleGrassWind(
    GrassWindInput blade,
    ProceduralGrassWind wind,
    float timeSeconds)
{
    GrassWindOutput result;

    float bendAngle = EvaluateGhostStyleBendAngle(blade, wind, timeSeconds);
    float3 bendAxis = WindDirectionToBendAxis(wind.directionWS);
    float3 offsetFromRoot = blade.positionWS - blade.anchorWS;

    result.positionWS = blade.anchorWS
                      + RotateAroundAxis(offsetFromRoot, bendAxis, bendAngle);
    result.normalWS = SafeNormalize(
        RotateAroundAxis(blade.normalWS, bendAxis, bendAngle), blade.normalWS);
    result.tangentWS = SafeNormalize(
        RotateAroundAxis(blade.tangentWS, bendAxis, bendAngle), blade.tangentWS);
    return result;
}

// Evaluate twice for velocity/motion vectors, exactly like the captured shader:
//   current  = EvaluateGhostStyleGrassWind(blade, wind, time);
//   previous = EvaluateGhostStyleGrassWind(blade, wind, time - deltaTime);

// -----------------------------------------------------------------------------
// B. Recommended reed recovery: a stateful damped angular spring
// -----------------------------------------------------------------------------
// A vertex shader cannot remember angular velocity between frames. Run this once
// per reed clump in a compute shader, CPU job, Niagara/VFX simulation, or another
// persistent buffer update. The vertex shader then only reads bendAngle and axis.

struct ReedSpringState
{
    float bendAngle;
    float angularVelocity;
};

struct ReedSpringParameters
{
    // Natural frequency in cycles/second. Reeds usually want slower values than
    // short grass because their mass and lever arm are larger.
    float frequencyHz;

    // 1 = critical damping (fast return without overshoot).
    // 0.45..0.8 = visible but decaying overshoot, often natural for reeds.
    float dampingRatio;

    float maxBendRadians;
    float windTorqueScale;
};

ReedSpringState UpdateReedSpring(
    ReedSpringState state,
    ReedSpringParameters parameters,
    float signedWindLoad,
    float deltaTime)
{
    // Clamp large frame gaps. A large explicit-Euler step is a common source of
    // snapping, excessive overshoot and apparently "wrong" recovery.
    float dt = min(deltaTime, 1.0f / 30.0f);

    float omega = 2.0f * PI * max(parameters.frequencyHz, 0.01f);
    float stiffness = omega * omega;
    float damping = 2.0f * parameters.dampingRatio * omega;

    float targetAngle = clamp(
        signedWindLoad * parameters.windTorqueScale,
        -parameters.maxBendRadians,
         parameters.maxBendRadians);

    // x'' + 2*zeta*omega*x' + omega^2*(x-target) = 0
    float acceleration = stiffness * (targetAngle - state.bendAngle)
                       - damping * state.angularVelocity;

    // Semi-implicit Euler is more stable than updating angle before velocity.
    state.angularVelocity += acceleration * dt;
    state.bendAngle += state.angularVelocity * dt;
    state.bendAngle = clamp(
        state.bendAngle,
        -parameters.maxBendRadians,
         parameters.maxBendRadians);

    return state;
}

// -----------------------------------------------------------------------------
// C. Vertex deformation driven by the persistent reed spring state
// -----------------------------------------------------------------------------

GrassWindOutput DeformReedVertex(
    GrassWindInput blade,
    float3 windDirectionWS,
    ReedSpringState spring)
{
    GrassWindOutput result;

    // Smooth cubic weighting is less hinge-like than a raw linear mask. Multiplying
    // by height once more gives a firm root and a flexible upper third.
    float height = saturate(blade.bladeHeight);
    float smoothHeight = height * height * (3.0f - 2.0f * height);
    float bendWeight = smoothHeight * height;

    float angle = spring.bendAngle * bendWeight;
    float3 bendAxis = WindDirectionToBendAxis(windDirectionWS);
    float3 offsetFromRoot = blade.positionWS - blade.anchorWS;

    result.positionWS = blade.anchorWS
                      + RotateAroundAxis(offsetFromRoot, bendAxis, angle);
    result.normalWS = SafeNormalize(
        RotateAroundAxis(blade.normalWS, bendAxis, angle), blade.normalWS);
    result.tangentWS = SafeNormalize(
        RotateAroundAxis(blade.tangentWS, bendAxis, angle), blade.tangentWS);
    return result;
}

// Practical starting point for tall reeds:
//   frequencyHz    = 0.7 .. 1.5
//   dampingRatio   = 0.55 .. 0.8
//   maxBendRadians = radians(15 .. 35)
//
// Add gust/noise to signedWindLoad (the spring target), not directly to the final
// vertex angle. That lets inertia filter high-frequency noise and produces a
// believable delayed recovery instead of a rubbery sine-wave reversal.
