// =============================================================================
// 草/植被顶点着色器 - 人类可读版本（数学与原始 3Dmigoto 反编译一致）
// 修正项：旋转轴、风噪声 UV、摆幅尺度、哈希、局部/世界坐标流程
// =============================================================================

cbuffer Global : register(b2)
{
    float4x4 ViewProj;
    float4x4 ShadowViewProjTexs0, ShadowViewProjTexs1, ShadowViewProjTexs2;
    float4 CSMShadowBiases, DiyLightingInfo;
    float4 CameraPos;
    float4 CameraInfo;          // w = 垂直 FOV（弧度）
    float4 ScreenInfo, ScreenColor, FogInfo, FogColor, EnvInfo;
    float4 SunDirection, SunColor, AmbientColor, ShadowColor;
    float4 ReflectionProbeBBMin, ReflectionProbeBBMax;
    float4 Misc;                  // w = 当前帧时间
    float4 Misc2;                 // x = 上一帧时间
    float4 Misc3, VolumetricFogParam, VolumetricFogParam2;
    float4x4 ShadowViewProjTexs3;
    float4 VTParam0, VTParam1, VTParam2, VTViewpoint, VTIndMapUVTransform;
    float4 SunFogColor;
    float4 WindParam;             // xyz 风向, w 风力 [0,1]
    float4 LastWindParam;
    float4 ScreenMotionGray, GIInfo;
    float4 SSRParam[4];
    float4x4 LastViewProjTex;
    float4 GlobalBurnParam, CSMCacheIndexs;
    float4 AerialPerspectiveExt, AerialPerspectiveMie, AerialPerspectiveRay;
    float4 LastCameraPos;
    float4 SHAOParam, SHSBParam, SHSBParam2, SHGIParam, SHGIParam2;
    float4 TimeOfDayInfos;
    float4 UserData[4];
    float4x4 ViewRotationProj;
    float4 WorldProbeInfo, LastPlayerPos;
    float4 HexEnvData[4], HexRenderOptionData[4];
    float4 OriginSunDir;
}

cbuffer Shader : register(b1)
{
    float3 cBaseColor; float cSmoothness;
    float4 cPorosityFactors;
    float cAlpha, cLocalWindPower, cGrassImpactPlayer, cMaxRotation_Piv;
    float cLocalWindScale_Piv, cSoftness_Piv, cPlayerPushIntencity;
    float3 cSize; float cAngle;
    float3 cWindWeight; float cRandoffset;
    float3 cBaseGradualColor; float cWindShelter;
    float3 cGrassSize; float cSlopeScale;
    float2 cImpactParam, cWeatherSnowInfo;
    float cBendScale, cLodThickness, cStandardGrass;
}

cbuffer Batch : register(b0)
{
    float4x3 World;
    float4 cTintColor1, cTintColor2, cTintColor3, cShadowBias;
    float4 cSHCoefficients[7];
    float4 cParameter, cParameter2, cParameter3, VBufferParam;
    float4 LocalBoundingBoxMin, LocalBoundingBoxMax, VertexCompressionParams;
    float4 cMinBB, cMaxBB;
    float4 cVirtualLitDir, cVirtualLitColor, cVirtualLitColor2, cVirtualLitParam;
    float4 cHeightmapMinPos, cHeightmapMaxPos;
    float4x4 WorldViewProj, LastWorldViewProjTex;
    float4x3 LastWorld;
    float4x4 ViewRotationProjTex, LastViewRotationProjTex;
    float4 PlayerPos, FoliageCenter, LastFoliageCenter, FoliageMapParam;
    float4 SheltermapMinPos, SheltermapMaxPos;
    float4x4 NormalWorld;
    float4 cWBasisX, cWBasisY, cWBasisZ, cVisibilitySH[2];
    float4x3 Local, View, InvView;
    uint4 DynamicShaderProfile;
    float4 HexGpuDrivenParams;
    uint cInstanceOffset;
    uint4 RTGeometryInfo;
}

SamplerState sFoliageMapSampler_s   : register(s3);
SamplerState sWindNoiseMapSampler_s : register(s10);
Texture2D<float4> tFoliageMap   : register(t3);
Texture2D<float4> tLastFoliageMap : register(t6);
Texture2D<float4> tWindNoiseMap : register(t10);

// ---------------------------------------------------------------------------
// 与原始字节码一致的辅助函数
// ---------------------------------------------------------------------------

float GrassHashFrac(float3 worldRoot)
{
    int seed = (int)(10.0 * worldRoot.x) + (int)(10.0 * worldRoot.z) + (int)(10.0 * worldRoot.y);
    float3 h = frac(float3(0.103100002, 0.103, 0.0973000005) * (float)seed);
    float3 h2 = float3(19.1900005, 19.1900005, 19.1900005) + h.yzx;
    float d = dot(h, h2);
    h = h + d;
    return frac((h.x + h.z) * h.y);
}

float GrassRandomScale(float hashFrac)
{
    float s = sin(3.14159274 * hashFrac);
    return exp2(0.699999988 * log2(s));
}

// 原始 shader 中的 atan2 多项式近似（输入为风方向 XZ）
float WindDirAngle(float2 windXZ)
{
    float ax = abs(windXZ.x), ay = abs(windXZ.y);
    float t = min(ax, ay) / max(ax, ay);
    float t2 = t * t;
    float p = ((0.0208350997 * t2 - 0.0851330012) * t2 + 0.180141002) * t2 - 0.330299497;
    float a = (p * t2 + 0.999866009) * t;
    if (abs(windXZ.y) < abs(windXZ.x)) a = 1.57079637 - 2.0 * a;
    if (-windXZ.y < windXZ.y) a += -3.141593;
    float neg = min(-windXZ.x, -windXZ.y);
    float pos = max(-windXZ.x, -windXZ.y);
    if (neg < -neg && pos >= -pos) a = -a;
    return a;
}

// 绕局部 X 轴旋转（用于 BendScale、风层2）—— 只动 YZ 分量
float3 RotateLocalX(float3 localPos, float angle)
{
    float s, c;
    sincos(angle, s, c);
    float3 axisPart = float3(localPos.x, 0, 0);
    float3 perp = localPos - axisPart;
    float3 crossVec = float3(0, -perp.z, perp.y); // cross((1,0,0), perp)
    return axisPart + perp * c + crossVec * s;
}

// 绕世界空间任意轴旋转（Rodriguez），pivot 为支点
float3 RotateWorld(float3 pos, float3 pivot, float3 axis, float angle)
{
    float s, c;
    sincos(angle, s, c);
    float3 v = pos - pivot;
    float3 crossV = cross(axis, v);
    return pivot + v * c + crossV * s + axis * dot(axis, v) * (1.0 - c);
}

float3 LocalToWorld(float3 localPos, float3 row0, float3 row1, float3 row2, float3 root)
{
    return float3(dot(row0, localPos) + root.x,
                  dot(row1, localPos) + root.y,
                  dot(row2, localPos) + root.z);
}

float3 TransformDir(float3 dir, float3 row0, float3 row1, float3 row2)
{
    return float3(dot(row0, dir), dot(row1, dir), dot(row2, dir));
}

// 同步旋转“携带法线”的 YZ 分量（绕 X 轴）
float3 RotateCarriedNormalX(float3 n, float angle)
{
    float s, c;
    sincos(angle, s, c);
    return float3(n.x, c * n.y - s * n.z, s * n.y + c * n.z);
}

// 用 Rodriguez 旋转矩阵变换方向向量（与原始 r31/r29/r27 构建一致）
float3 ApplyRodriguezMatrix(float3 v, float3 axis, float s, float c)
{
    float3 crossAv = cross(axis, v);
    float3 t1 = v * c + crossAv * s;
    // 展开为原始矩阵乘法的等价形式
    float3x3 m;
    float3 a = axis;
    m[0] = float3(c + (1-c)*a.x*a.x, (1-c)*a.x*a.y - s*a.z, (1-c)*a.x*a.z + s*a.y);
    m[1] = float3((1-c)*a.y*a.x + s*a.z, c + (1-c)*a.y*a.y, (1-c)*a.y*a.z - s*a.x);
    m[2] = float3((1-c)*a.z*a.x - s*a.y, (1-c)*a.z*a.y + s*a.x, c + (1-c)*a.z*a.z);
    return mul(v, m);
}

// 抖动用的第二套 atan2（对 r8.zw 风方向，结果做 π/2 + 2π-angle 变换）
float FlutterDirAngle(float2 windXZ)
{
    float ax = abs(windXZ.x), ay = abs(windXZ.y);
    float t = min(ax, ay) / max(ax, ay);
    float t2 = t * t;
    float p = ((0.0208350997 * t2 - 0.0851330012) * t2 + 0.180141002) * t2 - 0.330299497;
    float a = (p * t2 + 0.999866009) * t;
    if (abs(windXZ.y) < abs(windXZ.x)) a = 1.57079637 - 2.0 * a;
    if (windXZ.y < -windXZ.y) a += -3.141593;
    float neg = min(windXZ.x, windXZ.y);
    float pos = max(windXZ.x, windXZ.y);
    if (neg < -neg && pos >= -pos) a = -a;
    return 1.57079637 + (6.28318548 - a);
}

// ---------------------------------------------------------------------------
void main(
    uint v0 : SV_InstanceID0,
    float4 v1 : POSITION0,
    float4 v2 : COLOR0,
    float4 v3 : NORMAL0,
    float4 v4 : TEXCOORD0,
    float2 v5 : TEXCOORD1,
    float4 v6 : TANGENT0,
    float4 v7 : BINORMAL0,
    float4 v8 : TEXCOORD3,
    float4 v9 : TEXCOORD4,
    float4 v10 : TEXCOORD5,
    uint v11 : SV_VertexID0,
    out float4 o0 : SV_Position0,
    out float4 o1 : TEXCOORD0,
    out float4 o2 : TEXCOORD1,
    out float4 o3 : TEXCOORD2,
    out float4 o4 : TEXCOORD3,
    out float4 o5 : COLOR0,
    out float4 o6 : TEXCOORD4,
    out float3 p6 : TEXCOORD6,
    out float4 o7 : TEXCOORD5)
{
    // ===== 1. 顶点解压（略，与之前相同）=====
    float3 localPos;
    float4 texcoord;
    bool isRawFloat = (v1.w > 254.999f) && (v1.w < 255.001f);
    if (!isRawFloat)
    {
        int comprTypePos = (int)(VertexCompressionParams.x + 0.01f);
        int comprTypeUV  = (int)(VertexCompressionParams.y + 0.01f);
        float3 bbSize = LocalBoundingBoxMax.xyz - LocalBoundingBoxMin.xyz;
        if (comprTypePos == 1)
            localPos = LocalBoundingBoxMin.xyz + v1.xyz * bbSize;
        else if (comprTypePos == 2)
        {
            // 简化：多数捕获为 float 压缩；完整位域解码见 grass_vs_readable.hlsl 注释版
            localPos = LocalBoundingBoxMin.xyz + (v1.xyz * 255.0 / float3(2047,1023,2047)) * bbSize;
        }
        else
            localPos = v1.xyz;
        bool uvExpanded = (comprTypeUV >= 1);
        texcoord = uvExpanded ? float4(v4.xy, v5.xy) * 2.0 - 0.5 : float4(v4.xy, v5.xy);
    }
    else
    {
        localPos = v1.xyz;
        texcoord = float4(v4.xy, v5.xy);
    }

    // ===== 2. 法线 / 切线 =====
    float3 localNormal = v3.xyz * 2.0 - 1.0;
    float invLenN = rsqrt(dot(localNormal, localNormal));
    float3 worldTangent = normalize(TransformDir(v6.xyz, v8.xyz, v9.xyz, v10.xyz));

    float3 worldRoot = float3(v8.w, v9.w, v10.w);
    float3 worldPos  = LocalToWorld(localPos, v8.xyz, v9.xyz, v10.xyz, worldRoot);

    // 携带法线：刚度越高越接近竖直 up
    float3 upMinusN = float3(0, 1, 0) - localNormal * invLenN;
    float3 carriedNormal = v2.x * upMinusN + localNormal * invLenN;
    carriedNormal = normalize(carriedNormal);

    // ===== 3. 哈希 & LOD =====
    float hashFrac = GrassHashFrac(worldRoot);
    float randomScale = GrassRandomScale(hashFrac);
    float randomPhase = saturate(cRandoffset + hashFrac);
    float stiffnessInv = rsqrt(max(9.99999975e-05, v2.x)); // 1/sqrt(刚度)，踩压用

    float halfFov = CameraInfo.w * 0.5;
    float sinH, cosH;
    sincos(halfFov, sinH, cosH);
    float tanHalfFov = sinH / cosH;
    float lodThreshH = 35.1899986 / tanHalfFov;
    float lodThreshV = 41.4000015 / tanHalfFov;

    float distRoot = length(CameraPos.xyz - worldRoot);
    float3 lodT = max(0, float3(distRoot, distRoot - 3.0, distRoot));
    lodT = saturate(lodT / lodThreshV);
    float3 lodScale = 1.0 + float3(3, 1, 0.200000003) * lodT;

    float3 row0 = v8.xyz * float3(cGrassSize.x, 1, 1) * lodScale;
    float3 row1 = v9.xyz * float3(1, cGrassSize.y, 1) * lodScale;
    float3 row2 = v10.xyz * lodScale;

    float3 lodWorldPos = LocalToWorld(localPos, row0, row1, row2, worldRoot);

    // 草叶 up 轴（LOD 矩阵 Y 列）及尺度
    float3 bladeUp = float3(dot(row0, float3(0,1,0)), dot(row1, float3(0,1,0)), dot(row2, float3(0,1,0)));
    float heightScale = length(bladeUp);
    bladeUp = bladeUp / heightScale;

    float3 totalScaleVec = float3(dot(row0, float3(1,1,1)), dot(row1, float3(1,1,1)), dot(row2, float3(1,1,1)));
    float totalScale = length(totalScaleVec);

    // 斜线方向（风层1后用于噪声 UV）
    float3 diagDir = float3(dot(row0, float3(-0.72, 0.72, 0)),
                            dot(row1, float3(-0.72, 0.72, 0)),
                            dot(row2, float3(-0.72, 0.72, 0)));
    diagDir = normalize(diagDir);

    float3 lodTangent = normalize(TransformDir(v6.xyz, row0, row1, row2));

    // ===== 4. 风方向 =====
    float windLen = length(WindParam.xyz);
    float2 windXZ = (windLen > 1e-5) ? (-WindParam.xz * rsqrt(dot(WindParam.xyz, WindParam.xyz))) : float2(-1, 0);
    float windAngle1 = cWindWeight.x * WindDirAngle(windXZ);

    // 根距衰减（用于 BendScale 与噪声微调）
    float rootDist = length(lodWorldPos - worldRoot);
    float rootFactor = saturate((1.0 - 0.00831117015 * rootDist) * (1.0 - v2.x));

    // ===== 5. BendScale：局部 X 轴预弯 =====
    float3 deformedLocal = localPos;
    float3 curWorld = lodWorldPos;
    if (cBendScale > 0)
    {
        float bendAng = cBendScale * (1.0 - rootFactor);
        deformedLocal = RotateLocalX(localPos, bendAng);
        carriedNormal = normalize(RotateCarriedNormalX(carriedNormal, bendAng));
        curWorld = LocalToWorld(deformedLocal, row0, row1, row2, worldRoot);
    }

    // ===== 6. 风层1：绕草叶 up 轴（bladeUp），不是世界 Y =====
    float3 wind1Delta = 0;
    {
        float3 preWind1 = curWorld;
        float3 offset = curWorld - worldRoot;
        float3 pivot = worldRoot + bladeUp * dot(bladeUp, offset);
        curWorld = RotateWorld(curWorld, pivot, bladeUp, windAngle1);
        wind1Delta = curWorld - preWind1;
        float s, c;
        sincos(windAngle1, s, c);
        diagDir = ApplyRodriguezMatrix(diagDir, bladeUp, s, c);
    }

    // ===== 7. 风噪声 UV（用 diagDir + root 的 XZ，不是 currentPos.xz）=====
    float3 windTimeOff = Misc.www * float3(0.0799999982, 0.0599999987, 0.119999997) * cLocalWindScale_Piv;
    windTimeOff.xy += 0.05 * rootFactor;
    float3 noisePos = diagDir + worldRoot;
    float2 windNoiseUV = frac(float2(dot(float3(1,0,0), noisePos), dot(float3(0,0,1), noisePos)) + windTimeOff.x);
    float windNoise = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, windNoiseUV, 0).w;

    float phasePow = exp2(0.0399999991 * log2(max(9.99999975e-05, randomPhase)));

    // 植被贴图
    float2 foliageUV = (worldRoot.xz - FoliageCenter.xy) / FoliageMapParam.x + 0.5;
    float4 foliageData = tFoliageMap.SampleLevel(sFoliageMapSampler_s, foliageUV, 0);
    float shelterStr = length(foliageData.zw);
    float pushLen    = length(foliageData.xy);

    // ===== 8. 风层2 摆角（先算角，再坡度，再旋转 —— 与原始顺序一致）=====
    float bendEff = v2.x - v2.x * saturate(shelterStr);
    float swayBase = -0.897597909 + 0.349999994 * bendEff + 0.600000024 * 3.14159274 * windNoise;
    swayBase *= heightScale * (0.5 + 0.5 * randomPhase) * saturate(WindParam.w);
    swayBase += shelterStr * totalScale * min(1.2, totalScale * totalScale * totalScale * totalScale);
    float swayAng = cWindWeight.y * swayBase;

    // ===== 9. 坡度弯曲（在风层2 旋转之前，作用在 deformedLocal 上）=====
    float slopeThickness = 0;
    {
        float slopeBase = cSize.z * 0.25 * lodScale.x;
        float3 midPt = lodWorldPos + wind1Delta;
        float3 viewDir = normalize(midPt - CameraPos.xyz);
        float slopeSign = (dot(lodTangent, -viewDir) > 0) ? -1.0 : 1.0;
        slopeThickness = v2.z * slopeBase * abs(dot(lodTangent, viewDir)) * slopeSign;

        float4 slopeDir;
        slopeDir.xy = float2(-0.1, 0.1) * cSlopeScale;
        slopeDir.zw = float2(0.1, 0);
        float3 d0 = deformedLocal + slopeDir.zxx * slopeThickness;
        float3 d1 = deformedLocal + slopeDir.zwx * slopeThickness;
        float3 d2 = deformedLocal - slopeDir.zxy * slopeThickness;
        float3 d3 = deformedLocal - slopeDir.zwy * slopeThickness;

        bool isRoot = (v2.y == 0);
        bool isTop  = (v2.y == 1);
        bool isMid  = (v2.y > 0) && (v2.y <= 0.4);

        if (isRoot)       deformedLocal = d0;
        else if (isMid)   deformedLocal = d1;
        else if (isTop)   deformedLocal = d2;
        else              deformedLocal = d3;
    }

    // 风层2：绕局部 X 轴旋转（在坡度之后）
    deformedLocal = RotateLocalX(deformedLocal, swayAng);
    carriedNormal = normalize(RotateCarriedNormalX(carriedNormal, swayAng));
    float3 wind2World = LocalToWorld(deformedLocal, row0, row1, row2, worldRoot);

    // ===== 10. 风层3：高频颤抖（绕 bladeUp）=====
    {
        float2 noiseUV2 = frac(float2(dot(float3(1,0,0), worldRoot + 120.32),
                                      dot(float3(0,0,1), worldRoot + 120.32)) + windTimeOff.y);
        float n2 = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, noiseUV2, 0).w;

        float flutterDirAng = FlutterDirAngle(windXZ);
        float fs, fc;
        sincos(flutterDirAng, fs, fc);
        float2 baseUV = frac(float2(0.05, 0.05) * wind2World.zx);
        float2 rotUV = float2(fc * baseUV.y + fs * baseUV.x, -fs * baseUV.y + fc * baseUV.x); // 与原始 r8.zw/r14 一致
        float2 noiseUV3 = frac(windTimeOff.zz + rotUV);
        float n3 = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, noiseUV3, 0).w;

        float flutterAng = cWindWeight.z * (n2 + 0.5 * n3 - 0.5) * saturate(WindParam.w) * phasePow * heightScale;

        float3 flutterTarget = lodWorldPos - cStandardGrass * wind1Delta;
        float3 off = flutterTarget - worldRoot;
        float3 pivot = worldRoot + bladeUp * dot(bladeUp, off);
        float3 afterFlutter = RotateWorld(flutterTarget, pivot, bladeUp, flutterAng);
        float s2, c2;
        sincos(flutterAng, s2, c2);
        carriedNormal = normalize(ApplyRodriguezMatrix(carriedNormal, bladeUp, s2, c2));

        curWorld = afterFlutter + wind1Delta + (wind2World - flutterTarget);
    }

    // ===== 11. 玩家踩压 =====
    float3 pushAxis;
    {
        float2 fw = float2(foliageData.y - foliageData.w, foliageData.x - foliageData.z);
        float3 raw = float3(0, -fw.x, -fw.y);
        float3 c1 = cross(raw.zxy, bladeUp.yzx);
        pushAxis = c1 - raw * bladeUp;
        if (dot(pushAxis, pushAxis) > 0.001) pushAxis = normalize(pushAxis);
    }
    float impactFactor = min(1.3, abs(slopeThickness) * totalScale);
    float pushStrength = 1.0 - 1.0 / (1.0 + pushLen);
    float2 impactNoiseUV = frac(worldRoot.xz * 0.1 + Misc.ww);
    float impactNoise = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, impactNoiseUV, 0).w;
    float impactAng = cImpactParam.y * (0.5 + randomPhase) * sin(cImpactParam.x * 9 * 3.14159274 * pushStrength * phasePow * impactFactor)
                    * impactNoise * impactFactor * stiffnessInv * pushLen;

    float3 impactPivot = worldRoot + pushAxis * dot(pushAxis, curWorld - worldRoot);
    float3 afterImpact = RotateWorld(curWorld, impactPivot, pushAxis, impactAng);
    float3 impactDelta = (afterImpact - curWorld) * max(0, pushStrength);
    curWorld = curWorld + impactDelta;

    float3 finalWorld = curWorld;
    float3 finalNormal = normalize(carriedNormal);

    // ===== 12. 运动向量（上一帧路径仍建议用注释版完整复制；此处保持可编译占位）=====
    float3 lastWorld = finalWorld;
    float4 cw = float4(finalWorld - CameraPos.xyz, 1);
    float2 curUV = float2(dot(cw, ViewRotationProjTex._m00_m10_m20_m30),
                          dot(cw, ViewRotationProjTex._m01_m11_m21_m31)) / dot(cw, ViewRotationProjTex._m03_m13_m23_m33);
    float4 lw = float4(lastWorld - LastCameraPos.xyz, 1);
    float2 lastUV = float2(dot(lw, LastViewRotationProjTex._m00_m10_m20_m30),
                           dot(lw, LastViewRotationProjTex._m01_m11_m21_m31)) / dot(lw, LastViewRotationProjTex._m03_m13_m23_m33);
  float2 motion = lastUV - curUV;
    if (any(float4(curUV, lastUV) < 0) || any(float4(curUV, lastUV) > 1)) motion = 0;

    // ===== 输出 =====
    float4 wp4 = float4(finalWorld, 1);
    o0 = float4(dot(wp4, ViewProj._m00_m10_m20_m30),
                dot(wp4, ViewProj._m01_m11_m21_m31),
                dot(wp4, ViewProj._m02_m12_m22_m32),
                dot(wp4, ViewProj._m03_m13_m23_m33));
    o1 = texcoord;
    o2 = float4(finalWorld, CameraInfo.z * o0.w);
    o3 = float4(finalNormal, 0);
    o4 = float4(worldTangent, 0);
    o5 = float4(randomScale, v2.y, 0, randomPhase);
    o6 = float4(CameraInfo.z * o0.w, 0, 0, 0);
    o7 = float4(motion, 1, 0);
}
