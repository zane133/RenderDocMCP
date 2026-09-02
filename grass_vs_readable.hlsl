// =============================================================================
// 草/植被顶点着色器（Grass Foliage Vertex Shader）
// 由 3Dmigoto v1.4.6 反编译 — 代码完全未修改，仅添加注释
//
// 整体流程：
//   [1] 顶点位置解压缩  → r1.xyz (局部坐标), r0.xyzw (UV)
//   [2] 法线/切线解码   → r2.xyz (局部法线), r3.xyz (切线)
//   [3] 第二次解压检查  → r4.yzw (通常=r1.xyz)
//   [4] 世界变换        → r5.xyz (未缩放世界坐标), r17.xyz (LOD缩放后世界坐标)
//                         r11.xyz (草叶根部世界坐标 = worldRoot)
//   [5] 随机哈希        → r10.x (逐叶随机缩放因子), r10.w (随机相位)
//   [6] LOD缩放         → r14/r16/r12.yzw (按摄像机距离拉伸的变换行)
//   [7] 风力层1: 风向偏转   → atan2近似→ r3.w=cWindWeight.x*windAngle
//   [8] 弯曲预处理(BendScale)→ 局部X轴旋转 (仅当cBendScale>0)
//   [9] 风力层1 旋转    → 绕草叶up轴旋转 r3.w 弧度 (Rodriguez旋转)
//   [10] 风噪声采样     → tWindNoiseMap → 调制摆动幅度
//   [11] 植被贴图采样   → tFoliageMap: xy=玩家踩压, zw=遮蔽
//   [12] 风力层2: 主摆动    → 绕局部X轴旋转 r3.w=cWindWeight.y*amplitude
//   [13] 坡度弯曲       → 根据顶点类型(v2.y)选择4种偏移方向
//   [14] 风力层3: 高频颤抖  → 绕草叶up轴旋转 r3.w=cWindWeight.z*flutter
//   [15] 玩家踩压互动   → 绕踩压方向轴旋转 r3.w=cImpactParam.y*amplitude
//   [16] 焦烧贴图       → tFoliageBurnMap: lerp(变形坐标, LOD坐标, burnFactor)
//   [17] 上一帧重复计算 → 使用LastWindParam/LastCameraPos（运动向量用）
//   [18] 最终投影+输出  → ViewProj * finalWorldPos → clip space
//   [19] 运动向量       → ViewRotationProjTex (当前帧) vs LastViewRotationProjTex
//
// 输入语义说明：
//   v1 POSITION0  : xyz=局部坐标(可能压缩), w=压缩标志(≈255=无压缩)
//   v2 COLOR0     : r=弯曲刚度(0=完全刚硬,1=完全弯曲), g=顶点类型, b=厚度
//   v3 NORMAL0    : xyz=[0,1]编码法线，需*2-1还原
//   v4 TEXCOORD0  : xy=UV通道0(可能压缩)
//   v5 TEXCOORD1  : xy=UV通道1(可能压缩)
//   v6 TANGENT0   : 切线向量
//   v8 TEXCOORD3  : 逐草叶变换矩阵行0 + worldRoot.x(w分量)
//   v9 TEXCOORD4  : 逐草叶变换矩阵行1 + worldRoot.y(w分量)
//   v10 TEXCOORD5 : 逐草叶变换矩阵行2 + worldRoot.z(w分量)
//   (v8/v9/v10 的 xyz 是旋转/缩放部分，w 是平移即根部世界坐标)
// =============================================================================

cbuffer Global : register(b2)
{
  float4x4 ViewProj : packoffset(c0);                    // 视图-投影矩阵（当前帧）
  float4x4 ShadowViewProjTexs0 : packoffset(c4);         // CSM阴影矩阵 级联0
  float4x4 ShadowViewProjTexs1 : packoffset(c8);         // CSM阴影矩阵 级联1
  float4x4 ShadowViewProjTexs2 : packoffset(c12);        // CSM阴影矩阵 级联2
  float4 CSMShadowBiases : packoffset(c16);              // CSM深度偏移
  float4 DiyLightingInfo : packoffset(c17);
  float4 CameraPos : packoffset(c18);                    // 当前帧摄像机世界坐标 xyz
  float4 CameraInfo : packoffset(c19);                   // z=近平面, w=垂直FOV(弧度)
  float4 ScreenInfo : packoffset(c20);
  float4 ScreenColor : packoffset(c21);
  float4 FogInfo : packoffset(c22);
  float4 FogColor : packoffset(c23);
  float4 EnvInfo : packoffset(c24);
  float4 SunDirection : packoffset(c25);
  float4 SunColor : packoffset(c26);
  float4 AmbientColor : packoffset(c27);
  float4 ShadowColor : packoffset(c28);
  float4 ReflectionProbeBBMin : packoffset(c29);
  float4 ReflectionProbeBBMax : packoffset(c30);
  float4 Misc : packoffset(c31);                         // w=当前帧时间（风噪声UV滚动用）
  float4 Misc2 : packoffset(c32);                        // x=上一帧时间
  float4 Misc3 : packoffset(c33);
  float4 VolumetricFogParam : packoffset(c34);
  float4 VolumetricFogParam2 : packoffset(c35);
  float4x4 ShadowViewProjTexs3 : packoffset(c36);        // CSM阴影矩阵 级联3
  float4 VTParam0 : packoffset(c40);
  float4 VTParam1 : packoffset(c41);
  float4 VTParam2 : packoffset(c42);
  float4 VTViewpoint : packoffset(c43);
  float4 VTIndMapUVTransform : packoffset(c44);
  float4 SunFogColor : packoffset(c45);
  float4 WindParam : packoffset(c46);                    // xyz=风向量(世界空间XZ), w=全局风力[0,1]
  float4 LastWindParam : packoffset(c47);                // 上一帧风参数（运动向量用）
  float4 ScreenMotionGray : packoffset(c48);
  float4 GIInfo : packoffset(c49);
  float4 SSRParam[4] : packoffset(c50);
  float4x4 LastViewProjTex : packoffset(c54);
  float4 GlobalBurnParam : packoffset(c58);
  float4 CSMCacheIndexs : packoffset(c59);
  float4 AerialPerspectiveExt : packoffset(c60);
  float4 AerialPerspectiveMie : packoffset(c61);
  float4 AerialPerspectiveRay : packoffset(c62);
  float4 LastCameraPos : packoffset(c63);                // 上一帧摄像机世界坐标（运动向量用）
  float4 SHAOParam : packoffset(c64);
  float4 SHSBParam : packoffset(c65);
  float4 SHSBParam2 : packoffset(c66);
  float4 SHGIParam : packoffset(c67);
  float4 SHGIParam2 : packoffset(c68);
  float4 TimeOfDayInfos : packoffset(c69);
  float4 UserData[4] : packoffset(c70);
  float4x4 ViewRotationProj : packoffset(c74);           // 仅含旋转的投影（天空盒用）
  float4 WorldProbeInfo : packoffset(c78);
  float4 LastPlayerPos : packoffset(c79);
  float4 HexEnvData[4] : packoffset(c80);
  float4 HexRenderOptionData[4] : packoffset(c84);
  float4 OriginSunDir : packoffset(c88);
}

cbuffer Shader : register(b1)
{
  // --- 草叶外观 ---
  float3 cBaseColor : packoffset(c0);        // 基础颜色
  float cSmoothness : packoffset(c0.w);      // 光滑度
  float4 cPorosityFactors : packoffset(c1);  // 透光孔隙率
  float cAlpha : packoffset(c2);             // 透明度

  // --- 风力响应 ---
  float cLocalWindPower : packoffset(c2.y);  // 本地风力强度倍增
  float cGrassImpactPlayer : packoffset(c2.z); // 玩家踩压响应强度
  float cMaxRotation_Piv : packoffset(c2.w); // 主轴最大旋转角
  float cLocalWindScale_Piv : packoffset(c3); // 主轴风频率缩放（影响噪声UV采样频率）
  float cSoftness_Piv : packoffset(c3.y);    // 主轴弯曲柔软度
  float cPlayerPushIntencity : packoffset(c3.z); // 玩家推力强度

  // --- 草叶尺寸 ---
  float3 cSize : packoffset(c4);             // xyz=草叶尺寸缩放（z用于厚度）
  float cAngle : packoffset(c4.w);           // 初始角度偏移
  float3 cWindWeight : packoffset(c5);       // xyz=三层风力权重（x=方向/y=主摆/z=颤抖）
  float cRandoffset : packoffset(c5.w);      // 随机相位偏移（逐材质，与逐叶哈希叠加）
  float3 cBaseGradualColor : packoffset(c6); // 根部渐变颜色
  float cWindShelter : packoffset(c6.w);     // 风力遮蔽系数

  // --- 草叶几何 ---
  float3 cGrassSize : packoffset(c7);        // x/y=横/纵缩放比，供LOD拉伸用
  float cSlopeScale : packoffset(c7.w);      // 坡度弯曲强度

  // --- 踩压/天气 ---
  float2 cImpactParam : packoffset(c8);      // x=踩压波形频率, y=踩压位移总强度
  float2 cWeatherSnowInfo : packoffset(c8.z);// 雪覆盖参数
  float cBendScale : packoffset(c9);         // 朝摄像机预弯曲强度（0=不弯）
  float cLodThickness : packoffset(c9.y);    // LOD厚度缩放
  float cStandardGrass : packoffset(c9.z);   // 标准化系数（[0,1]插值姿态→标准直立）
}

cbuffer Batch : register(b0)
{
  float4x3 World : packoffset(c0);                    // 批次世界矩阵
  float4 cTintColor1 : packoffset(c3);
  float4 cTintColor2 : packoffset(c4);
  float4 cTintColor3 : packoffset(c5);
  float4 cShadowBias : packoffset(c6);
  float4 cSHCoefficients[7] : packoffset(c7);         // 球谐光照系数
  float4 cParameter : packoffset(c14);
  float4 cParameter2 : packoffset(c15);
  float4 cParameter3 : packoffset(c16);
  float4 VBufferParam : packoffset(c17);
  float4 LocalBoundingBoxMin : packoffset(c18);       // 顶点压缩解码AABB最小值
  float4 LocalBoundingBoxMax : packoffset(c19);       // 顶点压缩解码AABB最大值
  float4 VertexCompressionParams : packoffset(c20);   // xy=压缩类型(0=无,1=float,2=整数)
  float4 cMinBB : packoffset(c21);
  float4 cMaxBB : packoffset(c22);
  float4 cVirtualLitDir : packoffset(c23);
  float4 cVirtualLitColor : packoffset(c24);
  float4 cVirtualLitColor2 : packoffset(c25);
  float4 cVirtualLitParam : packoffset(c26);
  float4 cHeightmapMinPos : packoffset(c27);
  float4 cHeightmapMaxPos : packoffset(c28);
  float4x4 WorldViewProj : packoffset(c29);
  float4x4 LastWorldViewProjTex : packoffset(c33);
  float4x3 LastWorld : packoffset(c37);
  float4x4 ViewRotationProjTex : packoffset(c40);     // 带旋转的投影纹理矩阵（当前帧，运动向量用）
  float4x4 LastViewRotationProjTex : packoffset(c44); // 上一帧版本
  float4 PlayerPos : packoffset(c48);
  float4 FoliageCenter : packoffset(c49);             // xy=当前帧植被贴图世界中心, zw=焦烧贴图中心
  float4 LastFoliageCenter : packoffset(c50);         // 上一帧
  float4 FoliageMapParam : packoffset(c51);           // x=当前帧覆盖范围(半径), z=上一帧覆盖范围
  float4 SheltermapMinPos : packoffset(c52);
  float4 SheltermapMaxPos : packoffset(c53);
  float4x4 NormalWorld : packoffset(c54);
  float4 cWBasisX : packoffset(c58);
  float4 cWBasisY : packoffset(c59);
  float4 cWBasisZ : packoffset(c60);
  float4 cVisibilitySH[2] : packoffset(c61);
  float4x3 Local : packoffset(c63);
  float4x3 View : packoffset(c66);
  float4x3 InvView : packoffset(c69);
  uint4 DynamicShaderProfile : packoffset(c72);
  float4 HexGpuDrivenParams : packoffset(c73);
  uint cInstanceOffset : packoffset(c74);
  uint4 RTGeometryInfo : packoffset(c75);
}

// --- 纹理 ---
// tFoliageMap     : xy=玩家踩压位移方向向量（从根部指向踩压点）, zw=风力遮蔽强度向量
// tFoliageBurnMap : x=焦烧强度 (0=完全燃烧变平, 1=完好保持变形)
// tLastFoliageMap : 上一帧植被贴图（用于运动向量的上一帧踩压信息）
// tWindNoiseMap   : 风噪声 .w 通道存储值，以世界XZ坐标+时间偏移作为UV采样
SamplerState sFoliageMapSampler_s : register(s3);
SamplerState sFoliageBurnMapSampler_s : register(s4);
SamplerState sWindNoiseMapSampler_s : register(s10);
Texture2D<float4> tFoliageMap : register(t3);
Texture2D<float4> tFoliageBurnMap : register(t4);
Texture2D<float4> tLastFoliageMap : register(t6);
Texture2D<float4> tWindNoiseMap : register(t10);


// 3Dmigoto declarations
// 注意：`#define cmp -` 是 3Dmigoto 的伪HLSL约定：
//   cmp(a < b) 展开为 -(a < b)，结果为 -1.0(真) 或 0.0(假)
//   后续代码使用 `if(r == 0)` 或三元判断来还原条件逻辑
#define cmp -


void main(
  uint v0 : SV_InstanceID0,
  float4 v1 : POSITION0,    // xyz=顶点局部坐标(可能压缩), w=压缩标志(≈255=原始浮点)
  float4 v2 : COLOR0,       // r=弯曲刚度(0=刚,1=软), g=顶点类型(0=根,1=顶), b=厚度权重
  float4 v3 : NORMAL0,      // xyz=[0,1]编码法线，须*2-1解码
  float4 v4 : TEXCOORD0,    // xy=UV通道0(可能压缩)
  float2 v5 : TEXCOORD1,    // xy=UV通道1(可能压缩)
  float4 v6 : TANGENT0,     // 切线向量
  float4 v7 : BINORMAL0,    // 副切线
  float4 v8 : TEXCOORD3,    // 逐草叶变换矩阵行0: xyz=旋转/缩放, w=worldRoot.x(根部世界X坐标)
  float4 v9 : TEXCOORD4,    // 逐草叶变换矩阵行1: xyz=旋转/缩放, w=worldRoot.y(根部世界Y坐标)
  float4 v10 : TEXCOORD5,   // 逐草叶变换矩阵行2: xyz=旋转/缩放, w=worldRoot.z(根部世界Z坐标)
  uint v11 : SV_VertexID0,
  out float4 o0 : SV_Position0,  // 裁剪空间坐标
  out float4 o1 : TEXCOORD0,     // xyzw = UV (xy=UV0, zw=UV1)
  out float4 o2 : TEXCOORD1,     // xyz=最终世界坐标, w=?
  out float4 o3 : TEXCOORD2,     // xyz=世界法线（含风力/踩压变形后）
  out float4 o4 : TEXCOORD3,     // xyz=世界切线
  out float4 o5 : COLOR0,        // x=随机缩放因子, y=顶点类型
  out float4 o6 : TEXCOORD4,     // xyz=压缩坐标?, w=?
  out float3 p6 : TEXCOORD6,
  out float4 o7 : TEXCOORD5)     // xy=运动向量, z=1(有效标志), w=0
{
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27,r28,r29,r30,r31,r32,r33,r34;
  uint4 bitmask, uiDest;
  float4 fDest;

  // ===========================================================================
  // [1] 顶点位置 & UV 解压缩
  //     v1.w ≈ 255 → 原始浮点，直接使用
  //     否则根据 VertexCompressionParams 类型解码：
  //       type 0: 标准化 float [0,1]，乘以 bbSize + bbMin
  //       type 1: 标准化 float，但UV需*2-0.5扩展
  //       type 2: 11/10/11位整数打包（从 v1.zyxw 的位域中提取 XYZ 分量）
  //     解压结果:
  //       r1.xyz = 局部坐标（local position）
  //       r0.xyzw = UV 坐标（xy=UV0, zw=UV1）
  // ===========================================================================
  r0.x = cmp(254.998993 < v1.w);
  r0.y = cmp(v1.w < 255.001007);
  r0.x = r0.y ? r0.x : 0;         // r0.x = (v1.w ≈ 255) ? 1 : 0
  if (r0.x == 0) {                 // 需要解压缩
    r0.xy = float2(0.00999999978,0.00999999978) + VertexCompressionParams.xy; // 加0.01后转uint得压缩类型
    r0.x = (uint)r0.x;             // r0.x = 位置压缩类型 (0/1/2)
    r1.xyz = LocalBoundingBoxMax.xyz + -LocalBoundingBoxMin.xyz;              // bbSize
    r2.xyz = v1.xyz * r1.xyz;
    r2.xyz = LocalBoundingBoxMin.xyz + r2.xyz;  // type 0 解码: bbMin + v1.xyz * bbSize
    r0.y = (int)r0.y;
    r0.y = cmp((int)r0.y >= 1);    // UV需要扩展？
    r3.xy = v4.xy * float2(2,2) + float2(-0.5,-0.5);  // UV扩展: [0,1]→[-0.5,1.5]
    r3.zw = v5.xy * float2(2,2) + float2(-0.5,-0.5);
    r4.xy = v4.xy;
    r4.zw = v5.xy;
    r3.xyzw = r0.yyyy ? r3.xyzw : r4.xyzw;  // 选择UV（扩展 or 原始）
    r0.xy = cmp((int2)r0.xx == int2(1,2));   // r0.x=type1? r0.y=type2?
    // 以下: 11/10/11位整数解包（type2）
    // v1.zyxw * 255 → uint4 r5，然后从 r5.w 中提取 3bit、5bit 字段
    r5.xyzw = float4(255,255,255,255) * v1.zyxw;
    r5.xyzw = float4(0.00999999978,0.00999999978,0.00999999978,0.00999999978) + r5.xyzw;
    r5.xyzw = (uint4)r5.xyzw;
    // 位域提取：从 r5.w 提取 bits[5..7] (3bit) 和 bits[3..7] (5bit)
    if (3 == 0) r0.z = 0; else if (3+5 < 32) {     r0.z = (uint)r5.w << (32-(3 + 5)); r0.z = (uint)r0.z >> (32-3);    } else r0.z = (uint)r5.w >> 5;
    if (5 == 0) r0.w = 0; else if (5+3 < 32) {     r0.w = (uint)r5.w << (32-(5 + 3)); r0.w = (uint)r0.w >> (32-5);    } else r0.w = (uint)r5.w >> 3;
    bitmask.z = ((~(-1 << 24)) << 8) & 0xffffffff;  r0.z = (((uint)r0.z << 8) & bitmask.z) | ((uint)r5.x & ~bitmask.z);
    bitmask.w = ((~(-1 << 2)) << 8) & 0xffffffff;  r0.w = (((uint)r0.w << 8) & bitmask.w) | ((uint)0 & ~bitmask.w);
    bitmask.w = ((~(-1 << 8)) << 0) & 0xffffffff;  r0.w = (((uint)r5.y << 0) & bitmask.w) | ((uint)r0.w & ~bitmask.w);
    bitmask.w = ((~(-1 << 3)) << 8) & 0xffffffff;  r1.w = (((uint)r5.w << 8) & bitmask.w) | ((uint)0 & ~bitmask.w);
    bitmask.w = ((~(-1 << 8)) << 0) & 0xffffffff;  r1.w = (((uint)r5.z << 0) & bitmask.w) | ((uint)r1.w & ~bitmask.w);
    r5.xy = (uint2)r0.zw;
    r5.z = (uint)r1.w;
    r5.xyz = r5.xyz / float3(2047,1023,2047);       // 11/10/11 bit → [0,1]
    r1.xyz = r5.xyz * r1.xyz;
    r1.xyz = LocalBoundingBoxMin.xyz + r1.xyz;      // r1.xyz = type2 解码结果
    r1.w = 255;
    r1.xyzw = r0.yyyy ? r1.xyzw : v1.xyzw;         // type1: 使用 type2 结果
    r2.w = 255;
    r1.xyzw = r0.xxxx ? r2.xyzw : r1.xyzw;         // type0: 使用 float 结果
    r0.x = (int)r0.x | (int)r0.y;
    r0.xyzw = r0.xxxx ? r3.xyzw : r4.xyzw;         // r0.xyzw = 选定的UV
  } else {                         // 无压缩：直接使用原始值
    r1.xyzw = v1.xyzw;            // r1.xyz = 原始局部坐标
    r0.xy = v4.xy;
    r0.zw = v5.xy;                 // r0.xyzw = 原始UV
  }
  // 此时: r1.xyz = 局部坐标, r0.xyzw = UV(xy=UV0, zw=UV1)

  // ===========================================================================
  // [2] 法线 & 切线解码
  //     v3.xyz [0,1] → [-1,1] (乘2减1)
  //     v6.xyz 归一化 → 切线
  // ===========================================================================
  r2.xyz = v3.xyz * float3(2,2,2) + float3(-1,-1,-1);  // r2.xyz = 解码后局部法线
  r2.w = dot(v6.xyz, v6.xyz);
  r2.w = rsqrt(r2.w);
  r3.xyz = v6.xyz * r2.www;        // r3.xyz = 归一化切线

  // ===========================================================================
  // [3] 第二次解压检查（通常不执行）
  //     r1.w 在上面已被置为255，所以 r2.w=1，if分支不走
  //     else分支: r4.yzw = r1.xyz（局部坐标的拷贝）
  // ===========================================================================
  r2.w = cmp(254.998993 < r1.w);
  r3.w = cmp(r1.w < 255.001007);
  r2.w = r2.w ? r3.w : 0;         // r2.w = (r1.w ≈ 255) ? 1 : 0 → 通常为1
  if (r2.w == 0) {                 // 通常不执行（r2.w=1）
    r4.xy = float2(0.00999999978,0.00999999978) + VertexCompressionParams.xy;
    r2.w = (uint)r4.x;
    r4.xzw = LocalBoundingBoxMax.xyz + -LocalBoundingBoxMin.xyz;
    r5.xyz = r4.xzw * r1.xyz;
    r5.xyz = LocalBoundingBoxMin.xyz + r5.xyz;
    r3.w = (int)r4.y;
    r3.w = cmp((int)r3.w >= 1);
    r6.xy = r0.zw * float2(2,2) + float2(-0.5,-0.5);
    r6.xy = r3.ww ? r6.xy : r0.zw;
    r6.zw = cmp((int2)r2.ww == int2(1,2));
    r7.xyzw = float4(255,255,255,255) * r1.zyxw;
    r7.xyzw = float4(0.00999999978,0.00999999978,0.00999999978,0.00999999978) + r7.xyzw;
    r7.xyzw = (uint4)r7.xyzw;
    if (3 == 0) r8.x = 0; else if (3+5 < 32) {     r8.x = (uint)r7.w << (32-(3 + 5)); r8.x = (uint)r8.x >> (32-3);    } else r8.x = (uint)r7.w >> 5;
    if (5 == 0) r8.y = 0; else if (5+3 < 32) {     r8.y = (uint)r7.w << (32-(5 + 3)); r8.y = (uint)r8.y >> (32-5);    } else r8.y = (uint)r7.w >> 3;
    bitmask.w = ((~(-1 << 24)) << 8) & 0xffffffff;  r1.w = (((uint)r8.x << 8) & bitmask.w) | ((uint)r7.x & ~bitmask.w);
    bitmask.w = ((~(-1 << 2)) << 8) & 0xffffffff;  r2.w = (((uint)r8.y << 8) & bitmask.w) | ((uint)0 & ~bitmask.w);
    bitmask.w = ((~(-1 << 8)) << 0) & 0xffffffff;  r2.w = (((uint)r7.y << 0) & bitmask.w) | ((uint)r2.w & ~bitmask.w);
    bitmask.w = ((~(-1 << 3)) << 8) & 0xffffffff;  r3.w = (((uint)r7.w << 8) & bitmask.w) | ((uint)0 & ~bitmask.w);
    bitmask.w = ((~(-1 << 8)) << 0) & 0xffffffff;  r3.w = (((uint)r7.z << 0) & bitmask.w) | ((uint)r3.w & ~bitmask.w);
    r7.x = (uint)r1.w;
    r7.y = (uint)r2.w;
    r7.z = (uint)r3.w;
    r7.xyz = r7.xyz / float3(2047,1023,2047);
    r4.xyz = r7.xyz * r4.xzw;
    r4.xyz = LocalBoundingBoxMin.xyz + r4.xyz;
    r4.xyz = r6.www ? r4.xyz : r1.xyz;
    r4.yzw = r6.zzz ? r5.xyz : r4.xyz;
    r1.w = (int)r6.z | (int)r6.w;
    r0.zw = r1.ww ? r6.xy : r0.zw;
  } else {
    r4.yzw = r1.xyz;               // r4.yzw = 局部坐标（与r1.xyz相同）
  }
  // 此时: r4.yzw = 局部坐标 (= r1.xyz)

  // ===========================================================================
  // [4a] 逐草叶世界变换（无LOD缩放版，用于摄像机距离计算）
  //      v8/v9/v10 构成 3×4 逐叶变换矩阵：
  //        worldPos.i = dot(vi.xyz, localPos) + vi.w
  //      r5.xyz = 未缩放的世界坐标（用于LOD距离判断）
  //      r11.xyz = worldRoot = {v8.w, v9.w, v10.w} = 草叶根部世界坐标（所有旋转的支点）
  // ===========================================================================
  r1.w = dot(v8.xyz, r1.xyz);
  r5.x = v8.w + r1.w;             // r5.x = worldPos.x (未缩放)
  r1.w = dot(v9.xyz, r1.xyz);
  r5.y = v9.w + r1.w;             // r5.y = worldPos.y
  r1.x = dot(v10.xyz, r1.xyz);
  r5.z = v10.w + r1.x;            // r5.z = worldPos.z
  // r5.xyz = 未LOD缩放的世界坐标

  // 法线世界变换（使用3×3部分）
  r6.x = dot(v8.xyz, r2.xyz);
  r6.y = dot(v9.xyz, r2.xyz);
  r6.z = dot(v10.xyz, r2.xyz);    // r6.xyz = 世界法线（未归一化）
  r1.x = dot(r6.xyz, r6.xyz);
  r1.x = rsqrt(r1.x);             // r1.x = 1/|worldNormal|

  // 切线世界变换
  r7.x = dot(v8.xyz, r3.xyz);
  r7.y = dot(v9.xyz, r3.xyz);
  r7.z = dot(v10.xyz, r3.xyz);    // r7.xyz = 世界切线（未归一化）
  r1.z = dot(r7.xyz, r7.xyz);
  r1.z = rsqrt(r1.z);
  o4.xyz = r7.xyz * r1.zzz;       // 输出: 归一化世界切线

  // 变换矩阵的 Y 列 = 草叶"上"方向（up axis）
  r3.x = v8.y;
  r3.y = v9.y;
  r3.z = v10.y;                   // r3.xyz = 变换矩阵Y列（草叶局部up方向，世界空间）
  r1.z = dot(r3.xyz, r3.xyz);
  r1.z = rsqrt(r1.z);             // r1.z = 1/|upCol|（后用于归一化）

  r1.w = dot(r2.xyz, r2.xyz);
  r1.w = rsqrt(r1.w);
  r7.xyz = r2.xyz * r1.www;       // r7.xyz = 归一化世界法线

  // ===========================================================================
  // [4b] LOD 缩放因子计算（基于摄像机距离）
  //      使用垂直FOV切线值推算有效视角距离阈值
  //      r8.xy = {lodThresholdH, lodThresholdV}（= {35.19, 41.4} / tan(halfFOV)）
  //      r2.w = LOD因子（顶点距摄像机的归一化距离，[0,1]）
  // ===========================================================================
  r2.w = 0.5 * CameraInfo.w;      // halfFOV
  sincos(r2.w, r8.x, r9.x);
  r2.w = r8.x / r9.x;             // tan(halfFOV)
  r8.xy = float2(35.1899986,41.4000015) / r2.ww;  // LOD阈值 [H, V]
  r9.xyz = CameraPos.xyz + -r5.xyz;               // camera - worldPos (未缩放)
  r2.w = dot(r9.xyz, r9.xyz);
  r2.w = sqrt(r2.w);
  r2.w = saturate(r2.w / r8.x);   // r2.w = 顶点与摄像机的归一化LOD距离

  // 法线朝上方向的混合量：r2.xyz = up - normalize(normal)
  // 后续: r9.xyz = bendability*(up-normal) + worldNormal → 随刚度变化的"携带法线"
  r2.xyz = -r2.xyz * r1.www + float3(0,1,0);
  r9.xyz = v2.xxx * r2.xyz + r7.xyz;  // r9.xyz = 携带法线（跟随风力/弯曲一起旋转）

  // ===========================================================================
  // [5] 逐草叶随机哈希
  //     基于根部世界坐标的整数近似值（×10取整），通过哈希函数生成[0,1]随机值
  //     r10.x = exp2(0.7*log2(sin(π*hash))) — 随机缩放因子，输出到 o5.x
  //     r1.w  = frac(hash) — 用于随机相位
  // ===========================================================================
  r1.w = 10 * v8.w;               // worldRoot.x * 10
  r1.w = (int)r1.w;               // 取整
  r3.w = 10 * v10.w;
  r3.w = (int)r3.w;
  r1.w = (int)r1.w + (int)r3.w;
  r3.w = 10 * v9.w;
  r3.w = (int)r3.w;
  r1.w = (int)r1.w + (int)r3.w;  // r1.w = int(root.x*10) + int(root.y*10) + int(root.z*10) → 哈希种子
  r1.w = (int)r1.w;
  // 多项式哈希（参考 Hash33 函数）
  r10.xyz = float3(0.103100002,0.103,0.0973000005) * r1.www;
  r10.xyz = frac(r10.xyz);
  r11.xyz = float3(19.1900005,19.1900005,19.1900005) + r10.yzx;
  r1.w = dot(r10.xyz, r11.xyz);
  r10.xyz = r10.xyz + r1.www;
  r1.w = r10.x + r10.z;
  r1.w = r1.w * r10.y;
  r1.w = frac(r1.w);              // r1.w = frac hash ∈ [0,1]
  r3.w = 3.14159274 * r1.w;
  r3.w = sin(r3.w);
  r3.w = log2(r3.w);
  r3.w = 0.699999988 * r3.w;
  r10.x = exp2(r3.w);             // r10.x = 逐叶随机缩放因子 → 输出 o5.x

  // ===========================================================================
  // [6] LOD缩放（基于根部距离）→ 拉伸变换矩阵行
  //     r11.xyz = worldRoot = {v8.w, v9.w, v10.w}
  //     r12.xyz = LOD缩放 {1+3*f, 1+1*(f-3/thresh), 1+0.2*f}（f=sat(dist/thresh)）
  //     r14.xyz, r16.xyz, r12.yzw = LOD缩放后的三行变换矩阵（用cGrassSize调整XY尺寸）
  //     r17.xyz = 应用LOD缩放后的草叶顶点世界坐标
  //     r18.xyz = LOD矩阵的归一化Y列（草叶up方向）
  //     r5.w    = LOD矩阵Y列的长度（草叶高度尺度）
  //     r6.w    = LOD矩阵(1,1,1)方向的长度（总缩放量）
  // ===========================================================================
  r3.w = CameraInfo.w / 2;        // halfFOV
  sincos(r3.w, r11.x, r12.x);
  r3.w = r11.x / r12.x;           // tan(halfFOV)
  r3.w = 41.4000015 / r3.w;       // r3.w = lodThresholdV
  r11.x = v8.w;
  r11.y = v9.w;
  r11.z = v10.w;                   // r11.xyz = worldRoot（草叶根部世界坐标，不随风移动）
  r12.xyz = CameraPos.xyz + -r11.xyz;
  r5.w = dot(r12.xyz, r12.xyz);
  r5.w = sqrt(r5.w);               // r5.w = dist(摄像机, worldRoot)
  r12.xyz = float3(-0,-3,-0) + r5.www;        // {dist, dist-3, dist}
  r12.xyz = max(float3(0,0,0), r12.xyz);
  r12.xyz = saturate(r12.xyz / r3.www);       // 各轴归一化距离（Y轴从3m外才开始缩放）
  r12.xyz = float3(3,1,0.200000003) * r12.xyz;// LOD放大系数（X最大4×, Y最大2×, Z最大1.2×）
  r12.xyz = float3(1,1,1) + r12.xyz;          // r12.xyz = {LOD.x, LOD.y, LOD.z}
  // 应用cGrassSize比例到LOD缩放，再乘以原始矩阵行
  r13.x = cGrassSize.x;
  r13.yz = float2(1,1);
  r14.xyz = r13.xzz * r12.xyz;               // {cGrassSize.x*LOD.x, LOD.y, LOD.z}
  r14.xyz = v8.xyz * r14.xyz;                // r14.xyz = LOD缩放后的矩阵行0
  r15.xz = float2(1,1);
  r15.y = cGrassSize.y;
  r16.xyz = r15.zyz * r12.xyz;               // {LOD.x, cGrassSize.y*LOD.y, LOD.z}
  r16.xyz = v9.xyz * r16.xyz;                // r16.xyz = LOD缩放后的矩阵行1
  r12.yzw = v10.xyz * r12.xyz;               // r12.yzw = LOD缩放后的矩阵行2（复用r12.yzw）
  // 用LOD缩放后的矩阵行变换局部坐标
  r3.w = dot(r14.xyz, r4.yzw);
  r17.x = v8.w + r3.w;            // r17.x = LOD缩放后的世界坐标.x
  r3.w = dot(r16.xyz, r4.yzw);
  r17.y = v9.w + r3.w;
  r3.w = dot(r12.yzw, r4.yzw);
  r17.z = v10.w + r3.w;           // r17.xyz = LOD缩放后的草叶顶点世界坐标
  // 计算矩阵Y列（草叶高度方向）的长度 → 后用于风力摆幅调制
  r18.x = dot(r14.xyz, float3(0,1,0));
  r18.y = dot(r16.xyz, float3(0,1,0));
  r18.z = dot(r12.yzw, float3(0,1,0));       // r18.xyz = LOD矩阵的Y列（世界空间up）
  r3.w = dot(r18.xyz, r18.xyz);
  r5.w = sqrt(r3.w);              // r5.w = 草叶高度尺度（LOD缩放后的Y列长度）
  // (1,1,1)方向的总缩放量
  r19.x = dot(r14.xyz, float3(1,1,1));
  r19.y = dot(r16.xyz, float3(1,1,1));
  r19.z = dot(r12.yzw, float3(1,1,1));
  r6.w = dot(r19.xyz, r19.xyz);
  r6.w = sqrt(r6.w);             // r6.w = 总缩放量（影响玩家踩压幅度）

  // ===========================================================================
  // [7] 风方向处理
  //     WindParam.xyz = 风向量（世界空间），投影到XZ面
  //     r19.xy = 归一化风方向(XZ)，风速为0时默认(-1, 0)
  //     r10.w  = randomPhase = saturate(cRandoffset + hashFrac)（逐叶随机相位）
  //     r1.w   = sqrt(v2.x) = sqrt(弯曲刚度)（后用于踩压幅度）
  //     r20.xyz = 草叶变换矩阵在(-0.72, 0.72, 0)方向的世界投影（归一化）
  //     r18.xyz = 归一化的LOD矩阵Y列（草叶up轴，旋转轴）
  //     r21.xyz = LOD矩阵对切线(v6.xyz)的投影（归一化）
  // ===========================================================================
  r7.w = dot(WindParam.xyz, WindParam.xyz);
  r7.w = sqrt(r7.w);
  r7.w = cmp(9.99999975e-06 < r7.w);  // 风速 > 极小值?
  r8.z = dot(-WindParam.xyz, -WindParam.xyz);
  r8.z = rsqrt(r8.z);
  r8.zw = -WindParam.xz * r8.zz;      // 归一化风方向 XZ 分量
  r19.xy = r7.ww ? r8.zw : float2(-1,0);  // r19.xy = 风方向2D（无风时默认(-1,0)）
  r10.w = saturate(cRandoffset + r1.w);   // r10.w = randomPhase ∈ [0,1]
  r1.w = max(9.99999975e-05, v2.x);
  r1.w = rsqrt(r1.w);
  r1.w = 1 / r1.w;                    // r1.w = sqrt(弯曲刚度) = sqrt(v2.x)
  // 草叶变换矩阵在(-0.72, 0.72, 0)方向的投影（约45°斜线方向）
  r20.x = dot(r14.xyz, float3(-0.720000029,0.720000029,0));
  r20.y = dot(r16.xyz, float3(-0.720000029,0.720000029,0));
  r20.z = dot(r12.yzw, float3(-0.720000029,0.720000029,0));
  r7.w = dot(r20.xyz, r20.xyz);
  r7.w = rsqrt(r7.w);
  r20.xyz = r20.xyz * r7.www;          // r20.xyz = 归一化的斜线方向（风层1旋转后的切向方向）
  r3.w = rsqrt(r3.w);
  r18.xyz = r18.xyz * r3.www;          // r18.xyz = 归一化Y列 = 草叶up轴（旋转轴）
  // 切线在LOD变换矩阵中的投影（归一化）
  r21.x = dot(r14.xyz, v6.xyz);
  r21.y = dot(r16.xyz, v6.xyz);
  r21.z = dot(r12.yzw, v6.xyz);
  r3.w = dot(r21.xyz, r21.xyz);
  r3.w = rsqrt(r3.w);
  r21.xyz = r21.xyz * r3.www;          // r21.xyz = 归一化切线（坡度弯曲用）

  // ===========================================================================
  // [7b] atan2 近似（4阶多项式逼近，误差 < 0.0015 rad）
  //      输入: r19.xy = 风方向2D (x, y)
  //      输出: r3.w = 风方向角（弧度），乘以 cWindWeight.x 作为风层1旋转角
  //      算法: atan2(y,x) ≈ atan(min/max) + 象限修正
  // ===========================================================================
  r3.w = min(abs(r19.x), abs(r19.y));
  r7.w = max(abs(r19.x), abs(r19.y));
  r7.w = 1 / r7.w;
  r3.w = r7.w * r3.w;                 // t = min/max
  r7.w = r3.w * r3.w;                 // t²
  // 4阶多项式: atan(t) ≈ t*(0.9999+t²*(-0.3303+t²*(0.1801+t²*(-0.0851+t²*0.0208))))
  r9.w = 0.0208350997 * r7.w;
  r9.w = -0.0851330012 + r9.w;
  r9.w = r9.w * r7.w;
  r9.w = 0.180141002 + r9.w;
  r9.w = r9.w * r7.w;
  r9.w = -0.330299497 + r9.w;
  r7.w = r9.w * r7.w;
  r7.w = 0.999866009 + r7.w;
  r3.w = r7.w * r3.w;                 // ≈ atan(t)
  r7.w = cmp(abs(r19.y) < abs(r19.x));
  r9.w = -2 * r3.w;
  r9.w = 1.57079637 + r9.w;           // π/2 - 2*atan(t) (当|y|<|x|时补正)
  r7.w = r7.w ? r9.w : 0;
  r3.w = r7.w + r3.w;
  r7.w = cmp(-r19.y < r19.y);         // y > 0?
  r7.w = r7.w ? -3.141593 : 0;
  r3.w = r7.w + r3.w;                 // 象限2/3修正(-π)
  r7.w = min(-r19.x, -r19.y);
  r9.w = max(-r19.x, -r19.y);
  r7.w = cmp(r7.w < -r7.w);
  r9.w = cmp(r9.w >= -r9.w);
  r7.w = r7.w ? r9.w : 0;
  r3.w = r7.w ? -r3.w : r3.w;        // 最终象限修正（翻转符号）
  r3.w = cWindWeight.x * r3.w;        // r3.w = 风层1旋转角（风向偏转，弧度）

  // ===========================================================================
  // [8] 弯曲预处理（BendScale / cBendScale）
  //     根距因子 r7.w: 离根越近+越刚硬→r7.w越高→弯曲越少
  //     bendAngle = cBendScale * (1 - r7.w)
  //     绕局部X轴旋转（Rodriguez旋转，axis=(1,0,0)）
  //     r24.yzw = 弯曲后的局部坐标，r25.xyz = 弯曲后的归一化法线（含携带法线）
  //     r26.xyz = 弯曲后通过LOD矩阵变换得到的世界坐标
  //     r10.y   = (cBendScale > 0) 开关
  //     最后根据 r10.y 决定是否使用弯曲结果
  // ===========================================================================
  r19.xyz = r17.xyz + -r11.xyz;  // scaledWorldPos - worldRoot = 顶点相对根部偏移
  r7.w = dot(r19.xyz, r19.xyz);
  r7.w = sqrt(r7.w);
  r7.w = 0.00831117015 * r7.w;  // ~0.00831 * bladeLength
  r9.w = 1 + -v2.x;             // 1 - bendability（刚度）
  r7.w = 1 + -r7.w;
  r7.w = saturate(r7.w * r9.w); // r7.w = 根距因子（根部且刚硬=1，远端且柔软=0）
  r10.y = cmp(0 < cBendScale);  // r10.y = cBendScale > 0
  r11.w = 1 + -r7.w;
  r11.w = cBendScale * r11.w;   // bendAngle = cBendScale * (1-根距因子)
  // 绕X轴的Rodriguez旋转（axis=(1,0,0)，pivot=坐标原点）：
  // 分解: r4.yzw → 轴向分量 r19.xzz(x,0,0) + 垂直分量 r22.xyz(0,y,z)
  r13.w = dot(float3(1,0,0), r4.yzw);    // x分量
  r19.xyz = float3(1,0,0) * r13.www;     // {x,0,0}
  r22.xyz = -r19.xzz + r4.yzw;           // {0,y,z}
  r23.xyz = float3(0,0,1) * r22.zxy;     // cross((1,0,0), (0,y,z)) 的一部分
  r24.xyz = float3(0,1,0) * r22.yzx;
  r23.xyz = -r24.xyz + r23.xyz;          // r23.xyz = cross(axis, r22) = (0, -z, y)
  sincos(r11.w, r24.x, r25.x);          // sin/cos(bendAngle)
  r24.yzw = r25.xxx * r22.xyz;           // cos(angle) * v⊥
  r25.yzw = r24.xxx * r23.xyz;           // sin(angle) * (axis × v⊥)
  r24.yzw = r25.yzw + r24.yzw;          // Rodriguez: cos*v⊥ + sin*(axis×v⊥)
  r24.yzw = r24.yzw + r19.xzz;          // 加回轴向分量
  r24.yzw = r24.yzw + -r4.yzw;          // 求位移delta
  r24.yzw = r24.yzw + r4.yzw;           // r24.yzw = 弯曲后的局部坐标
  // 同步旋转携带法线 r9（仅旋转YZ分量，即2D绕X轴）：
  r26.x = -r24.x;   // -sin
  r26.y = r25.x;    // cos
  r25.y = dot(r26.yx, r9.yz);   // normal.y' = cos*normal.y - sin*normal.z
  r26.z = r24.x;    // sin
  r25.z = dot(r26.zy, r9.yz);   // normal.z' = sin*normal.y + cos*normal.z
  r25.x = r9.x;                 // normal.x 不变
  r11.w = dot(r25.xyz, r25.xyz);
  r11.w = rsqrt(r11.w);
  r25.xyz = r25.xyz * r11.www;  // r25.xyz = 归一化弯曲后携带法线
  // 将弯曲后的局部坐标通过LOD矩阵变换到世界坐标
  r11.w = dot(r14.xyz, r24.yzw);
  r26.x = v8.w + r11.w;
  r11.w = dot(r16.xyz, r24.yzw);
  r26.y = v9.w + r11.w;
  r11.w = dot(r12.yzw, r24.yzw);
  r26.z = v10.w + r11.w;        // r26.xyz = 弯曲后的世界坐标
  // 根据 cBendScale>0 决定是否使用弯曲结果
  r9.xyz = r10.yyy ? r25.xyz : r9.xyz;      // 选携带法线（弯曲 or 原始）
  r24.xyz = r10.yyy ? r24.yzw : r4.yzw;    // 选局部坐标
  r25.xyz = r10.yyy ? r26.xyz : r17.xyz;   // r25.xyz = 当前世界坐标（含弯曲的LOD后坐标）

  // ===========================================================================
  // [9] 风力层1：风向偏转（绕草叶up轴旋转，角度=r3.w=cWindWeight.x*windAngle）
  //     使用 Rodriguez 旋转，旋转轴为 r18.xyz（草叶归一化up轴）
  //     支点为 worldRoot + 投影到up轴的分量（旋转发生在up轴方向的切面内）
  //     r25.xyz 更新为风层1旋转后的 "位移delta"（加到后续坐标）
  //     r31/r29/r27 = 旋转矩阵（供后续法线变换用）
  //     r20.xyz = 斜线方向经旋转矩阵变换后的新方向
  // ===========================================================================
  r26.xyz = r25.xyz + -r11.xyz;            // worldPos相对worldRoot的偏移
  r11.w = dot(r18.xyz, r26.xyz);           // 投影到up轴
  r26.xyz = r18.xyz * r11.www;             // up轴方向分量
  r26.xyz = r26.xyz + r11.xyz;             // 旋转支点 = worldRoot + up轴投影
  r27.xyz = -r26.xyz + r25.xyz;            // 垂直于up轴的分量（待旋转向量）
  r28.xyz = r27.zxy * r18.yzx;
  r29.xyz = r27.yzx * r18.zxy;
  r28.xyz = -r29.xyz + r28.xyz;            // r28 = cross(r27, up) (或反向cross)
  sincos(r3.w, r29.x, r30.x);             // sin/cos(风层1角度)
  r27.xyz = r30.xxx * r27.xyz;             // cos * v
  r28.xyz = r29.xxx * r28.xyz;             // sin * (up × v)
  r27.xyz = r28.xyz + r27.xyz;             // Rodriguez旋转结果
  r26.xyz = r27.xyz + r26.xyz;             // 新世界坐标
  r25.xyz = r26.xyz + -r25.xyz;            // r25.xyz = 风层1位移delta
  // 构建旋转矩阵（用于后续法线/切线的旋转）
  r3.w = 1 + -r30.x;                      // 1-cos
  r26.xyzw = r3.wwww * r18.xxzy;
  r27.xyzw = r26.xyzw * r18.xyxy;
  r28.xyz = r29.xxx * r18.zxy;
  r29.xy = r28.zx + r27.zy;
  r31.xy = r27.xw + r30.xx;
  r26.xy = r26.wz * r18.zz;
  r29.z = r26.x + -r28.y;
  r27.xy = -r28.xz + r27.yz;
  r27.z = r26.x + r28.y;
  r27.w = r26.y + r30.x;
  r31.z = r27.x;
  r31.w = r29.x;                           // r31/r29/r27 = Rodrigues旋转矩阵列
  // 用旋转矩阵变换斜线方向 r20.xyz
  r26.x = dot(r31.xzw, r20.xyz);
  r29.w = r31.y;
  r26.y = dot(r29.ywz, r20.xyz);
  r26.z = dot(r27.yzw, r20.xyz);
  r3.w = dot(r26.xyz, r26.xyz);
  r3.w = rsqrt(r3.w);
  r20.xyz = r26.xyz * r3.www;              // r20.xyz = 风层1旋转后的斜线方向（归一化）

  // ===========================================================================
  // [10] 风噪声采样 + 植被贴图采样
  //      风噪声UV = 斜线方向世界坐标 + 时间偏移（Misc.w * cLocalWindScale_Piv）
  //      r3.w  = 采样的风噪声值（tWindNoiseMap.w）
  //      r20.xyzw = 植被贴图数据: xy=玩家踩压向量, zw=风力遮蔽向量
  //      r11.w = 遮蔽强度 = length(foliageData.zw)
  //      r13.w = 踩压幅度 = length(foliageData.xy)
  //      r7.w  = randomPhase^0.04（几乎=1，微调）
  // ===========================================================================
  r26.xyz = float3(0.0799999982,0.0599999987,0.119999997) * cLocalWindScale_Piv; // 频率
  r28.xyz = Misc.www * r26.xyz;            // 时间偏移 * 频率
  r3.w = 0.0500000007 * r7.w;             // 额外偏移（基于根距因子）
  r28.xy = r28.xy + r3.ww;
  r20.xyz = r20.xyz + r11.xyz;            // 移动到根部附近的世界坐标
  r30.x = dot(float3(1,0,0), r20.xyz);   // X分量
  r30.y = dot(float3(0,0,1), r20.xyz);   // Z分量
  r20.xy = r30.xy + r28.xx;              // 风噪声UV: 世界XZ + 时间偏移
  r20.xy = frac(r20.xy);                 // 包裹到[0,1]
  r3.w = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, r20.xy, 0).w; // 采样风噪声
  // randomPhase调制（log2→exp2 使分布偏向中间值）
  r7.w = max(9.99999975e-05, r10.w);
  r7.w = log2(r7.w);
  r7.w = 0.0399999991 * r7.w;
  r7.w = exp2(r7.w);                     // r7.w = phase^0.04 ≈ 1
  // 植被贴图采样（根部世界XZ相对FoliageCenter）
  r20.xy = -FoliageCenter.xy + r11.xz;
  r20.xy = r20.xy / FoliageMapParam.xx;  // 归一化到[-0.5, 0.5]
  r20.xy = float2(0.5,0.5) + r20.xy;    // 映射到UV[0,1]
  r20.xyzw = tFoliageMap.SampleLevel(sFoliageMapSampler_s, r20.xy, 0).xyzw;
  r11.w = dot(r20.zw, r20.zw);
  r11.w = sqrt(r11.w);                  // r11.w = 遮蔽强度（foliageData.zw长度）
  r13.w = dot(r20.xy, r20.xy);
  r13.w = sqrt(r13.w);                  // r13.w = 踩压幅度（foliageData.xy长度）

  // ===========================================================================
  // [11] 风力层2：主摆动角度计算
  //      综合: 风噪声 + 弯曲刚度 + 遮蔽 → 摆动角幅度
  //      r3.w = cWindWeight.y * (shelterAdjusted * 0.35 + noise*0.6π - 0.898) * bladeHeight * phaseFactor * globalWindScale
  // ===========================================================================
  r14.w = saturate(r11.w);               // 遮蔽强度，夹到[0,1]
  r14.w = -v2.x * r14.w;
  r14.w = v2.x + r14.w;                 // r14.w = bendability * (1 - shelterStrength)（遮蔽减弱弯曲性）
  r3.w = 3.14159274 * r3.w;
  r3.w = 0.600000024 * r3.w;            // 风噪声贡献: noise * 0.6π
  r14.w = 0.349999994 * r14.w;          // 弯曲刚度贡献: * 0.35
  r3.w = r14.w + r3.w;                  // 噪声 + 刚度
  r3.w = -0.897597909 + r3.w;           // 减去基线偏移（使中心点约为0）
  r3.w = r3.w * r5.w;                   // 乘以草叶高度尺度（越高摆幅越大）
  r14.w = 0.5 * r10.w;
  r14.w = 0.5 + r14.w;                  // 相位因子: 0.5 + 0.5*randomPhase ∈ [0.5, 1.0]
  r3.w = r14.w * r3.w;
  r15.w = saturate(WindParam.w);         // 全局风力强度[0,1]
  r3.w = r15.w * r3.w;                  // r3.w = 风层2摆动角（弧度）× cWindWeight.y（后乘）

  // ===========================================================================
  // [12] 坡度弯曲（cSlopeScale）
  //      根据顶点类型v2.y（0=根,中段,1=顶），向4个方向之一偏移局部坐标
  //      偏移量 = cSize.z * 0.25 * cSlopeScale * v2.z * dot(tangent, viewDir) * slopeSign
  //      不同顶点类型选择不同偏移方向，实现叶片面向摄像机的厚度效果
  // ===========================================================================
  r21.xyz = r30.xyz * r16.www;
  r21.xyz = r30.xyz * r16.www;          // r21.xyz = 归一化切线（重整）[实际见下]
  // 注：r21.xyz 先前已在 [7] 末尾计算为归一化切线
  r12.x = 0.25 * r12.x;
  r12.x = cSize.z * r12.x;             // r12.x = cSize.z * 0.25 * LOD.x
  r30.xyz = r25.xyz + r17.xyz;         // 两个世界坐标之和（用于计算视线方向中点）
  r30.xyz = -CameraPos.xyz + r30.xyz;  // 指向摄像机的方向向量（从中点到相机）
  r16.w = dot(r30.xyz, r30.xyz);
  r16.w = rsqrt(r16.w);
  r30.xyz = r30.xyz * r16.www;         // 归一化视线方向
  r16.w = dot(r21.xyz, -r30.xyz);      // 切线与视线的点积
  r17.w = cmp(0 < r16.w);
  r17.w = r17.w ? -1 : 1;             // 正负号（决定坡度弯曲方向）
  r12.x = v2.z * r12.x;               // * 厚度权重(v2.z)
  r12.x = r12.x * abs(r16.w);         // * |dot(tangent, viewDir)|
  r12.x = r12.x * r17.w;             // r12.x = 坡度偏移量（有符号）
  r21.xy = float2(-0.100000001,0.100000001) * cSlopeScale;  // 各偏移方向的XY缩放
  r21.zw = float2(0.100000001,0);
  // 4种偏移方向（XZ平面内的不同正负组合）：
  r30.xyz = r21.zxx * r12.xxx;   // 方向1: ( slopeOffset, -slopeOffset*0.1, slopeOffset*0.1)... [简化]
  r30.xyz = r30.xyz + r24.xyz;   // 局部坐标 + 方向1偏移
  r16.w = cmp(0.400000006 >= v2.y);
  r17.w = cmp(0 < v2.y);
  r16.w = r16.w ? r17.w : 0;    // vertIsMidLow = (0 < v2.y <= 0.4)
  r32.xyz = r21.zwx * r12.xxx;
  r32.xyz = r32.xyz + r24.xyz;   // 方向2
  r28.xw = cmp(v2.yy == float2(0,1));  // r28.x=(v2.y==0)=根部, r28.w=(v2.y==1)=顶端
  r33.xyz = r21.zxy * r12.xxx;
  r33.xyz = -r33.xyz + r24.xyz;  // 方向3（负）
  r34.xyz = r21.zwy * r12.xxx;
  r24.xyz = -r34.xyz + r24.xyz;  // 方向4（负，默认）
  r24.xyz = r28.www ? r33.xyz : r24.xyz;  // 顶端→方向3
  r24.xyz = r16.www ? r32.xyz : r24.xyz;  // 中低段→方向2
  r24.xyz = r28.xxx ? r30.xyz : r24.xyz;  // 根部→方向1
  // r24.xyz = 坡度弯曲后的局部坐标

  // ===========================================================================
  // [12b] 风层2旋转角最终计算
  //       r11.w = 遮蔽强度 * 总缩放量（r6.w）→ 放大摆动
  //       r17.w = (r6.w^8 夹到1.2) * r11.w（高阶放大）
  //       最终 r3.w = cWindWeight.y * (基础摆动 + 遮蔽放大)
  // ===========================================================================
  r11.w = r11.w * r6.w;                // 遮蔽强度 * 总缩放量
  r12.x = r6.w * r6.w;
  r17.w = r12.x * r12.x;
  r17.w = r17.w * r17.w;              // r6.w^8
  r17.w = min(1.20000005, r17.w);     // 夹到1.2
  r11.w = r17.w * r11.w;
  r3.w = r11.w + r3.w;               // 风层2总摆动角（加入遮蔽放大部分）
  r3.w = cWindWeight.y * r3.w;       // r3.w = 风层2最终旋转角

  // ===========================================================================
  // [12c] 风力层2旋转（绕局部X轴 Rodriguez 旋转）
  //       axis = (1,0,0)（world-aligned X轴），angle = r3.w
  //       r24.xyz 从坡度弯曲后坐标更新为主摆动后坐标
  //       同步更新携带法线 r9.xyz
  // ===========================================================================
  r11.w = dot(float3(1,0,0), r24.xyz);
  r30.xyz = float3(1,0,0) * r11.www;    // r24 的X分量
  r32.xyz = -r30.xzz + r24.xyz;         // r24 的YZ分量 {0,y,z}
  r33.xyz = float3(0,0,1) * r32.zxy;
  r34.xyz = float3(0,1,0) * r32.yzx;
  r33.xyz = -r34.xyz + r33.xyz;         // cross((1,0,0), r32)
  sincos(r3.w, r27.x, r29.x);          // sin/cos(风层2角度)
  r32.xyz = r32.xyz * r29.xxx;          // cos*v
  r33.xyz = r33.xyz * r27.xxx;          // sin*(axis×v)
  r32.xyz = r33.xyz + r32.xyz;          // 旋转后的YZ分量
  r30.xyz = r32.xyz + r30.xyz;          // 加回X分量
  r30.xyz = r30.xyz + -r24.xyz;         // delta
  r24.xyz = r30.xyz + r24.xyz;          // r24.xyz = 风层2旋转后的局部坐标
  // 同步旋转携带法线（2D绕X轴）
  r30.x = -r27.x;  r30.y = r29.x;
  r32.y = dot(r30.yx, r9.yz);
  r30.z = r27.x;
  r32.z = dot(r30.zy, r9.yz);
  r32.x = r9.x;
  r3.w = dot(r32.xyz, r32.xyz);
  r3.w = rsqrt(r3.w);
  r9.xyz = r32.xyz * r3.www;            // r9.xyz = 风层2旋转后的携带法线
  // 计算世界坐标并经旋转矩阵更新法线
  r3.w = dot(r14.xyz, r24.xyz);
  r30.x = v8.w + r3.w;
  r3.w = dot(r16.xyz, r24.xyz);
  r30.y = v9.w + r3.w;
  r3.w = dot(r12.yzw, r24.xyz);
  r30.z = v10.w + r3.w;                // r30.xyz = 风层2后的世界坐标
  r14.x = dot(r14.xyz, r9.xyz);
  r14.y = dot(r16.xyz, r9.xyz);
  r14.z = dot(r12.yzw, r9.xyz);
  r3.w = dot(r14.xyz, r14.xyz);
  r3.w = rsqrt(r3.w);
  r9.xyz = r14.xyz * r3.www;            // 法线经过世界变换矩阵再归一化
  // 旋转矩阵再次应用于 r9，确保与旋转后方向一致
  r14.x = dot(r31.xzw, r9.xyz);
  r14.y = dot(r29.ywz, r9.xyz);
  r14.z = dot(r27.yzw, r9.xyz);
  r3.w = dot(r14.xyz, r14.xyz);
  r3.w = rsqrt(r3.w);
  r9.xyz = r14.xyz * r3.www;            // r9.xyz = 风层2后最终携带法线

  // ===========================================================================
  // [13] 第二个风噪声采样 + 风层3(高频颤抖)角度的atan2计算
  //      第二个噪声UV: worldRoot + 120.32偏移 + 时间偏移（r28.y通道）
  //      r3.w = 采样结果（来自tWindNoiseMap.w）
  //      第二套atan2近似（r8.z作为风方向角，但相位做了 π/2+2π 变换）
  //      此角度用于生成横向旋转的第三套噪声UV
  // ===========================================================================
  r12.yzw = float3(120.32,120.32,120.32) + r11.xyz;  // worldRoot + 120.32
  r14.x = dot(float3(1,0,0), r12.yzw);
  r14.y = dot(float3(0,0,1), r12.yzw);
  r14.xy = r14.xy + r28.yy;            // 加时间偏移（r28.y = Misc.w*cLocalWindScale_Piv*0.06）
  r14.xy = frac(r14.xy);
  r3.w = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, r14.xy, 0).w;  // 第二个噪声
  // 第二套atan2（对风方向XZ做4阶多项式近似）
  r11.w = min(abs(r8.z), abs(r8.w));
  r12.z = max(abs(r8.z), abs(r8.w));
  r12.z = 1 / r12.z;
  r11.w = r12.z * r11.w;
  r12.z = r11.w * r11.w;
  r14.x = 0.0208350997 * r12.z;
  r14.x = -0.0851330012 + r14.x;
  r14.x = r14.x * r12.z;
  r14.x = 0.180141002 + r14.x;
  r14.x = r14.x * r12.z;
  r14.x = -0.330299497 + r14.x;
  r12.z = r14.x * r12.z;
  r12.z = 0.999866009 + r12.z;
  r11.w = r12.z * r11.w;
  r12.z = cmp(abs(r8.w) < abs(r8.z));
  r14.x = -2 * r11.w;
  r14.x = 1.57079637 + r14.x;
  r12.z = r12.z ? r14.x : 0;
  r11.w = r12.z + r11.w;
  r12.z = cmp(r8.w < -r8.w);
  r12.z = r12.z ? -3.141593 : 0;
  r11.w = r12.z + r11.w;
  r12.z = min(r8.z, r8.w);
  r8.z = max(r8.z, r8.w);
  r8.w = cmp(r12.z < -r12.z);
  r8.z = cmp(r8.z >= -r8.z);
  r8.z = r8.z ? r8.w : 0;
  r8.z = r8.z ? -r11.w : r11.w;
  r8.z = 6.28318548 + -r8.z;
  r8.z = 1.57079637 + r8.z;       // r8.z = π/2 + (2π - windAngle) = 偏转后风向角（用于颤抖方向）
  // 生成颤抖噪声UV（在r30.zx为基础的XZ坐标上，按旋转角做螺旋偏移）
  r14.xy = float2(0.0500000007,0.0500000007) * r30.zx;
  r14.xy = frac(r14.xy);
  sincos(r8.z, r16.x, r24.x);    // sin/cos(偏转角)
  r8.zw = r24.xx * r14.yx;       // cos * frac(pos)
  r14.xy = r16.xx * r14.xy;      // sin * frac(pos)
  r16.x = r14.x + r8.z;
  r16.y = -r14.y + r8.w;         // 旋转后的UV偏移
  r8.zw = r28.zz + r16.xy;       // 加时间偏移（r28.z = 0.12频率 * 时间）
  r8.zw = frac(r8.zw);
  r8.z = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, r8.zw, 0).w;  // 第三个噪声
  r8.z = 0.5 * r8.z;

  // ===========================================================================
  // [14] 风力层3：高频颤抖（叶尖摇曳）
  //      r3.w = cWindWeight.z * ((noise2 + noise3*0.5) - 0.5) * globalWind * phase^0.04 * bladeHeight
  //      绕 r18.xyz（草叶up轴）旋转颤抖角度
  //      目标点 r14.xyz = lerp(worldPos, LODPos, cStandardGrass)（标准化插值后的坐标）
  // ===========================================================================
  r3.w = r8.z + r3.w;
  r3.w = -0.5 + r3.w;            // 中心化：[(noise2+noise3*0.5) - 0.5]
  r3.w = r3.w * r15.w;           // * 全局风力
  r3.w = r3.w * r7.w;            // * phase^0.04
  r3.w = r3.w * r5.w;            // * 草叶高度尺度（越高颤抖越大）
  r3.w = cWindWeight.z * r3.w;   // r3.w = 风层3颤抖角
  // 计算标准化后的目标点（cStandardGrass=0时=worldPos，=1时=LOD后根部坐标）
  r14.xyz = cStandardGrass * r25.xyz;   // r25.xyz = 风层1后的位置delta
  r14.xyz = r17.xyz + -r14.xyz;         // LOD坐标 - cStandardGrass * wind1delta
  // 绕 r18.xyz（up轴）旋转 r3.w（颤抖角）
  r16.xyz = r14.xyz + -r11.xyz;
  r5.w = dot(r18.xyz, r16.xyz);
  r16.xyz = r18.xyz * r5.www;
  r16.xyz = r16.xyz + r11.xyz;          // 旋转支点
  r24.xyz = -r16.xyz + r14.xyz;         // 垂直分量
  r27.xyz = r24.zxy * r18.yzx;
  r29.xyz = r24.yzx * r18.zxy;
  r27.xyz = -r29.xyz + r27.xyz;         // cross(r24, up)
  sincos(r3.w, r29.x, r31.x);
  r24.xyz = r31.xxx * r24.xyz;
  r27.xyz = r29.xxx * r27.xyz;
  r24.xyz = r27.xyz + r24.xyz;          // Rodriguez旋转
  r16.xyz = r24.xyz + r16.xyz;          // 新世界坐标
  r14.xyz = r16.xyz + -r14.xyz;         // r14.xyz = 颤抖位移delta
  // 构建旋转矩阵并旋转携带法线
  r3.w = 1 + -r31.x;
  r24.xyzw = r3.wwww * r18.xxzy;
  r16.xyz = r29.xxx * r18.zxy;
  r27.xy = r24.zy * r18.xy + r16.zx;
  r29.xy = r24.xw * r18.xy + r31.xx;
  r27.z = r24.w * r18.z + -r16.y;
  r32.xy = r24.yz * r18.yx + -r16.xz;
  r32.z = r24.w * r18.z + r16.y;
  r32.w = r24.z * r18.z + r31.x;
  r29.z = r32.x;
  r29.w = r27.x;
  r16.x = dot(r29.xzw, r9.xyz);
  r27.w = r29.y;
  r16.y = dot(r27.ywz, r9.xyz);
  r16.z = dot(r32.yzw, r9.xyz);
  r3.w = dot(r16.xyz, r16.xyz);
  r3.w = rsqrt(r3.w);
  r9.xyz = r16.xyz * r3.www;            // r9.xyz = 颤抖旋转后的携带法线
  // 累加位移：r14.xyz = wind1delta + flutter_delta + wind2_worldPos_delta
  r14.xyz = r25.xyz + r14.xyz;          // 加入风层1位移
  r14.xyz = r30.xyz + r14.xyz;          // 加入风层2世界坐标（r30.xyz）
  // 从植被贴图推导踩压方向轴（r16.xyz）
  r8.zw = r20.yx + -r20.wz;            // foliage.yx - foliage.wz
  r16.yz = -r8.zw;
  r16.x = 0;
  r20.xyz = r16.zxy * r18.yzx;
  r16.xyz = r16.xyz * r18.xyz;
  r16.xyz = r20.xyz + -r16.xyz;         // cross(r16, up) → 踩压方向与up轴正交
  r3.w = dot(r16.yzx, r16.yzx);
  r5.w = cmp(0.00100000005 < r3.w);
  r3.w = rsqrt(r3.w);
  r18.xyz = r16.xyz * r3.www;
  r16.xyz = r5.www ? r18.xyz : r16.xyz; // r16.xyz = 归一化踩压旋转轴（垂直于up）

  // ===========================================================================
  // [15] 玩家踩压互动（当前帧）
  //      r3.w = 碰撞距离因子（min(LOD.x*totalScale, 1.3)）
  //      wave = sin(cImpactParam.x * 9π * playerPushLen * phase^0.04 * r3.w)
  //      noise = 采样tWindNoiseMap（以worldRoot XZ为UV）
  //      角度 = cImpactParam.y * noise * wave * (0.5+phase) * r3.w * sqrt(bendability) * playerPushLen
  //      绕 r16.xyz 旋转，旋转幅度与踩压幅度/刚度正相关
  // ===========================================================================
  r3.w = r12.x * r6.w;
  r3.w = min(1.29999995, r3.w);  // r3.w = 碰撞因子（夹到1.3）
  r8.zw = float2(0.100000001,0.100000001) * r17.xz;
  r8.zw = Misc.ww + r8.zw;
  r8.zw = frac(r8.zw);
  r5.w = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, r8.zw, 0).w;  // 踩压噪声
  r6.w = 1 + r13.w;
  r6.w = 1 / r6.w;
  r6.w = 1 + -r6.w;              // r6.w = 1 - 1/(1+playerPushLen) = 非线性踩压强度
  r8.z = 9 * r6.w;
  r8.z = 3.14159274 * r8.z;      // 9π * 强度
  r8.z = r8.z * r7.w;            // * phase^0.04
  r8.z = r8.z * r3.w;            // * 碰撞因子
  r8.z = cImpactParam.x * r8.z;  // * 波形频率参数
  r8.z = sin(r8.z);              // sin波形（踩压波）
  r5.w = r8.z * r5.w;            // * 噪声
  r8.z = 0.5 + r10.w;           // 0.5 + randomPhase
  r5.w = r8.z * r5.w;            // * 相位因子
  r3.w = r5.w * r3.w;            // * 碰撞因子
  r3.w = r3.w * r1.w;            // * sqrt(弯曲刚度)
  r3.w = r3.w * r13.w;           // * playerPushLen
  r3.w = cImpactParam.y * r3.w;  // r3.w = 踩压旋转角（弧度）
  // 绕 r16.xyz（踩压轴）旋转 r14.xyz
  r18.xyz = r14.xyz + -r11.xyz;
  r5.w = dot(r16.yzx, r18.xyz);
  r18.xyz = r16.yzx * r5.www;
  r18.xyz = r18.xyz + r11.xyz;          // 旋转支点
  r20.xyz = -r18.xyz + r14.xyz;         // 垂直分量
  r24.xyz = r20.zxy * r16.zxy;
  r25.xyz = r20.yzx * r16.xyz;
  r24.xyz = -r25.xyz + r24.xyz;         // cross(r20, r16)
  sincos(r3.w, r12.x, r25.x);
  r20.xyz = r25.xxx * r20.xyz;
  r24.xyz = r24.xyz * r12.xxx;
  r20.xyz = r24.xyz + r20.xyz;          // Rodriguez旋转
  r18.xyz = r20.xyz + r18.xyz;          // 新世界坐标
  r18.xyz = r18.xyz + -r14.xyz;         // r18.xyz = 踩压位移delta
  // 更新携带法线（旋转矩阵方式，加权混合）
  r3.w = 1 + -r25.x;
  r20.xyzw = r3.wwww * r16.yyxz;
  r24.xyz = r16.xyz * r12.xxx;
  r27.xy = r20.zy * r16.yz + r24.zx;
  r29.xy = r20.xw * r16.yz + r25.xx;
  r27.z = r20.w * r16.x + -r24.y;
  r30.xy = r20.yz * r16.zy + -r24.xz;
  r30.z = r20.w * r16.x + r24.y;
  r30.w = r20.z * r16.x + r25.x;
  r29.z = r30.x;
  r29.w = r27.x;
  r16.x = dot(r29.xzw, r9.xyz);
  r27.w = r29.y;
  r16.y = dot(r27.ywz, r9.xyz);
  r16.z = dot(r30.yzw, r9.xyz);
  r3.w = dot(r16.xyz, r16.xyz);
  r3.w = rsqrt(r3.w);
  r5.w = max(0, r6.w);           // 踩压强度（>0）
  r18.xyz = r5.www * r18.xyz;    // 按强度缩放踩压delta
  r16.xyz = r16.xyz * r3.www + -r9.xyz;
  r9.xyz = r5.www * r16.xyz + r9.xyz;   // 按强度混合法线
  r3.w = dot(r9.xyz, r9.xyz);
  r3.w = rsqrt(r3.w);
  r9.xyz = r9.xyz * r3.www;             // 归一化携带法线
  r14.xyz = r18.xyz + r14.xyz;          // r14.xyz = 踩压后最终局部坐标（含所有变形）
  // LOD距离混合（携带法线 vs 原始世界法线）
  r16.xyz = r3.xyz * r1.zzz + -r9.xyz; // r3.xyz=upCol(归一化Y列), 原始法线与携带法线的差
  r9.xyz = r2.www * r16.xyz + r9.xyz;  // r2.w=LOD因子，远处渐变回原始法线

  // ===========================================================================
  // [16] 焦烧贴图（当前帧）
  //      burnUV = (worldRoot.xz - FoliageCenter.zw) / 64 + 0.5
  //      burnFactor = saturate(tFoliageBurnMap.x)
//      burnFactor=0 → 保持全部变形(r14.xyz)
//      burnFactor=1 → 草叶完全恢复到无变形的LOD坐标(r17.xyz)
//      最终: r17.xyz = lerp(r14.xyz, r17.xyz, burnFactor)
  //              r6.xyz = 法线（混合当前与归一化世界法线）
  // ===========================================================================
  r12.xz = -FoliageCenter.zw + r17.xz; // 焦烧UV: 以FoliageCenter.zw为中心
  r12.xz = r12.xz / float2(64,64);
  r12.xz = float2(0.5,0.5) + r12.xz;
  r2.w = tFoliageBurnMap.SampleLevel(sFoliageBurnMapSampler_s, r12.xz, 0).x;
  r2.w = saturate(r2.w);               // r2.w = burnFactor ∈ [0,1]
  r16.xyz = r17.xyz + -r14.xyz;        // LODPos - 变形后Pos
  r16.xyz = r16.xyz * r2.www;          // * burnFactor
  r17.xyz = r16.xyz + r14.xyz;         // r17.xyz = lerp(变形,LOD,burnFactor) = 最终世界坐标
  r6.xyz = r6.xyz * r1.xxx + -r9.xyz;  // 法线混合准备
  r6.xyz = r2.www * r6.xyz + r9.xyz;   // r6.xyz = 最终世界法线（burnFactor混合）

  // ===========================================================================
  // [17] 最终投影（当前帧）
  //      o0 = ViewProj * r17 （裁剪空间坐标）
  //      o2.xyz = r17.xyz （世界坐标输出）
  // ===========================================================================
  r17.w = 1;
  o0.x = dot(r17.xyzw, ViewProj._m00_m10_m20_m30);
  o0.y = dot(r17.xyzw, ViewProj._m01_m11_m21_m31);
  o0.z = dot(r17.xyzw, ViewProj._m02_m12_m22_m32);
  r1.x = dot(r17.xyzw, ViewProj._m03_m13_m23_m33);  // r1.x = 深度(w)

  // ===========================================================================
  // [18] 上一帧计算（运动向量用）
  //      完整重复一遍上面的 [4]-[16] 流程，但使用：
  //        LastCameraPos（代替 CameraPos）
  //        LastWindParam（代替 WindParam）
  //        LastFoliageCenter（代替 FoliageCenter）
  //        Misc2.x（代替 Misc.w）作为时间参数
  //      最终得到 r3.xyz（上一帧最终世界坐标）和 r2.xyz（上一帧法线）
  //
  //      此段代码与 [4]-[16] 完全对称，寄存器复用但逻辑一致，不再重复注释
  // ===========================================================================
  // --- 上一帧LOD缩放（基于LastCameraPos到worldRoot的距离）---
  r5.xyz = LastCameraPos.xyz + -r5.xyz;
  r2.w = dot(r5.xyz, r5.xyz);
  r2.w = sqrt(r2.w);
  r10.z = saturate(r2.w / r8.x);           // r10.z = 上一帧LOD因子（顶点距上帧摄像机的距离）
  r2.xyz = r10.xxx * r2.xyz + r7.xyz;       // r2.xyz = LOD因子混合后的法线（用于上帧运动向量）
  r5.xyz = LastCameraPos.xyz + -r11.xyz;    // LastCameraPos - worldRoot
  r2.w = dot(r5.xyz, r5.xyz);
  r2.w = sqrt(r2.w);                        // dist(LastCameraPos, worldRoot)
  r5.xyz = float3(-0,-3,-0) + r2.www;
  r5.xyz = max(float3(0,0,0), r5.xyz);
  r5.xyz = saturate(r5.xyz / r8.yyy);       // r8.y = lodThresholdV
  r5.xyz = float3(3,1,0.200000003) * r5.xyz;
  r5.xyz = float3(1,1,1) + r5.xyz;          // r5.xyz = 上一帧LOD缩放
  // 上一帧缩放矩阵行
  r7.xyz = r5.xyz * r13.xyz;
  r7.xyz = v8.xyz * r7.xyz;                 // r7.xyz = 上帧LOD矩阵行0
  r8.xyw = r5.xyz * r15.xyz;
  r8.xyw = v9.xyz * r8.xyw;                 // r8.xyw = 上帧LOD矩阵行1
  r5.yzw = v10.xyz * r5.xyz;                // r5.yzw = 上帧LOD矩阵行2
  r2.w = dot(r7.xyz, r4.yzw);
  r9.x = v8.w + r2.w;
  r2.w = dot(r8.xyw, r4.yzw);
  r9.y = v9.w + r2.w;
  r2.w = dot(r5.yzw, r4.yzw);
  r9.z = v10.w + r2.w;                      // r9.xyz = 上帧LOD缩放后世界坐标
  r13.x = r7.y;  r13.y = r8.y;  r13.z = r5.z;
  r2.w = dot(r13.xyz, r13.xyz);
  r3.w = sqrt(r2.w);                        // r3.w = 上帧草叶高度尺度
  r14.x = dot(r7.xyz, float3(1,1,1));
  r14.y = dot(r8.xyw, float3(1,1,1));
  r14.z = dot(r5.yzw, float3(1,1,1));
  r6.w = dot(r14.xyz, r14.xyz);
  r11.w = sqrt(r6.w);                       // r11.w = 上帧总缩放量
  // 上一帧风方向
  r12.x = dot(LastWindParam.xyz, LastWindParam.xyz);
  r12.x = sqrt(r12.x);
  r12.x = cmp(9.99999975e-06 < r12.x);
  r12.z = dot(-LastWindParam.xyz, -LastWindParam.xyz);
  r12.z = rsqrt(r12.z);
  r14.xy = -LastWindParam.xz * r12.zz;
  r12.xz = r12.xx ? r14.xy : float2(-1,0);  // r12.xz = 上帧风方向2D
  // 上一帧斜线方向等（同[7]）
  r15.x = dot(r7.xy, float2(-0.720000029,0.720000029));
  r15.y = dot(r8.xy, float2(-0.720000029,0.720000029));
  r15.z = dot(r5.yz, float2(-0.720000029,0.720000029));
  r13.w = dot(r15.xyz, r15.xyz);
  r13.w = rsqrt(r13.w);
  r15.xyz = r15.xyz * r13.www;              // r15.xyz = 上帧斜线方向（归一化）
  r2.w = rsqrt(r2.w);
  r13.xyz = r13.xyz * r2.www;               // r13.xyz = 上帧up轴（归一化）
  r16.x = dot(r7.xyz, v6.xyz);
  r16.y = dot(r8.xyw, v6.xyz);
  r16.z = dot(r5.yzw, v6.xyz);
  r2.w = dot(r16.xyz, r16.xyz);
  r2.w = rsqrt(r2.w);
  r16.xyz = r16.xyz * r2.www;               // r16.xyz = 上帧切线（归一化）
  // 上一帧atan2 + cWindWeight.x * windAngle
  r2.w = min(abs(r12.x), abs(r12.z));
  r13.w = max(abs(r12.x), abs(r12.z));
  r13.w = 1 / r13.w;
  r2.w = r13.w * r2.w;
  r13.w = r2.w * r2.w;
  r14.z = 0.0208350997 * r13.w;
  r14.z = -0.0851330012 + r14.z;
  r14.z = r14.z * r13.w;
  r14.z = 0.180141002 + r14.z;
  r14.z = r14.z * r13.w;
  r14.z = -0.330299497 + r14.z;
  r13.w = r14.z * r13.w;
  r13.w = 0.999866009 + r13.w;
  r2.w = r13.w * r2.w;
  r13.w = cmp(abs(r12.z) < abs(r12.x));
  r14.z = -2 * r2.w;
  r14.z = 1.57079637 + r14.z;
  r13.w = r13.w ? r14.z : 0;
  r2.w = r13.w + r2.w;
  r13.w = cmp(-r12.z < r12.z);
  r13.w = r13.w ? -3.141593 : 0;
  r2.w = r13.w + r2.w;
  r13.w = min(-r12.x, -r12.z);
  r12.x = max(-r12.x, -r12.z);
  r12.z = cmp(r13.w < -r13.w);
  r12.x = cmp(r12.x >= -r12.x);
  r12.x = r12.x ? r12.z : 0;
  r2.w = r12.x ? -r2.w : r2.w;
  r2.w = cWindWeight.x * r2.w;              // r2.w = 上帧风层1旋转角
  // 上一帧BendScale（同[8]）
  r18.xyz = r9.xyz + -r11.xyz;
  r12.x = dot(r18.xyz, r18.xyz);
  r12.x = sqrt(r12.x);
  r12.x = 0.00831117015 * r12.x;
  r12.x = 1 + -r12.x;
  r9.w = saturate(r12.x * r9.w);
  r12.x = 1 + -r9.w;
  r12.x = cBendScale * r12.x;
  sincos(r12.x, r12.x, r18.x);
  r18.yzw = r22.xyz * r18.xxx;
  r20.xyz = r23.xyz * r12.xxx;
  r18.yzw = r20.xyz + r18.yzw;
  r18.yzw = r19.xyz + r18.yzw;
  r19.x = -r12.x;
  r19.y = r18.x;
  r20.y = dot(r19.yx, r2.yz);
  r19.z = r12.x;
  r20.z = dot(r19.zy, r2.yz);
  r20.x = r2.x;
  r12.x = dot(r20.xyz, r20.xyz);
  r12.x = rsqrt(r12.x);
  r19.xyz = r20.xyz * r12.xxx;
  r12.x = dot(r7.xyz, r18.yzw);
  r20.x = v8.w + r12.x;
  r12.x = dot(r8.xyw, r18.yzw);
  r20.y = v9.w + r12.x;
  r12.x = dot(r5.yzw, r18.yzw);
  r20.z = v10.w + r12.x;
  r2.xyz = r10.yyy ? r19.xyz : r2.xyz;
  r18.xyz = r10.yyy ? r18.yzw : r4.yzw;
  r19.xyz = r10.yyy ? r20.xyz : r9.xyz;
  // 上一帧风层1旋转（同[9]，使用r13.xyz作为up轴）
  r20.xyz = r19.xyz + -r11.xyz;
  r10.y = dot(r13.xyz, r20.xyz);
  r20.xyz = r13.xyz * r10.yyy;
  r20.xyz = r20.xyz + r11.xyz;
  r22.xyz = -r20.xyz + r19.xyz;
  r23.xyz = r22.zxy * r13.yzx;
  r24.xyz = r22.yzx * r13.zxy;
  r23.xyz = -r24.xyz + r23.xyz;
  sincos(r2.w, r12.x, r24.x);
  r22.xyz = r24.xxx * r22.xyz;
  r23.xyz = r23.xyz * r12.xxx;
  r22.xyz = r23.xyz + r22.xyz;
  r20.xyz = r22.xyz + r20.xyz;
  r19.xyz = r20.xyz + -r19.xyz;
  r2.w = 1 + -r24.x;
  r20.xyzw = r2.wwww * r13.xxzy;
  r22.xyzw = r20.xyzw * r13.xyxy;
  r23.xyz = r13.zxy * r12.xxx;
  r25.xy = r23.zx + r22.zy;
  r27.xy = r22.xw + r24.xx;
  r12.xz = r20.wz * r13.zz;
  r25.z = r12.x + -r23.y;
  r20.xy = -r23.xz + r22.yz;
  r20.z = r12.x + r23.y;
  r20.w = r12.z + r24.x;
  r27.z = r20.x;
  r27.w = r25.x;
  r22.x = dot(r27.xzw, r15.xyz);
  r25.w = r27.y;
  r22.y = dot(r25.ywz, r15.xyz);
  r22.z = dot(r20.yzw, r15.xyz);
  r2.w = dot(r22.xyz, r22.xyz);
  r2.w = rsqrt(r2.w);
  r12.xz = r22.xz * r2.ww;               // 旋转后斜线方向的XZ分量（归一化）
  // 上一帧风噪声UV（使用Misc2.x作为时间）
  r15.xyz = Misc2.xxx * r26.xyz;          // r26.xyz = 频率向量（[10]中计算）
  r2.w = 0.0500000007 * r9.w;
  r15.xy = r15.xy + r2.ww;
  r22.x = v8.w + r12.x;
  r22.y = v10.w + r12.z;
  r12.xz = r22.xy + r15.xx;
  r12.xz = frac(r12.xz);
  r2.w = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, r12.xz, 0).w;  // 上帧风噪声
  // 上一帧植被贴图（使用LastFoliageCenter）
  r12.xz = -LastFoliageCenter.xy + r11.xz;
  r12.xz = r12.xz / FoliageMapParam.zz;  // z分量=上帧覆盖范围
  r12.xz = float2(0.5,0.5) + r12.xz;
  r22.xyzw = tLastFoliageMap.SampleLevel(sFoliageMapSampler_s, r12.xz, 0).xyzw;
  r9.w = dot(r22.zw, r22.zw);
  r9.w = sqrt(r9.w);                      // r9.w = 上帧遮蔽强度
  r10.y = dot(r22.xy, r22.xy);
  r10.y = sqrt(r10.y);                    // r10.y = 上帧踩压幅度
  // 上一帧风层2角度（同[11]，使用LastWindParam.w）
  r12.x = min(1, r9.w);
  r12.x = -v2.x * r12.x;
  r12.x = v2.x + r12.x;
  r2.w = 3.14159274 * r2.w;
  r2.w = 0.600000024 * r2.w;
  r12.x = 0.349999994 * r12.x;
  r2.w = r12.x + r2.w;
  r2.w = -0.897597909 + r2.w;
  r2.w = r2.w * r3.w;                     // * 上帧草叶高度尺度
  r2.w = r2.w * r14.w;                    // * 相位因子
  r12.x = saturate(LastWindParam.w);      // 上帧全局风力
  r2.w = r12.x * r2.w;                    // r2.w = 上帧风层2摆动角
  // 上一帧切线投影（同[7]末尾）
  r23.x = dot(r27.xzw, r16.xyz);
  r23.y = dot(r25.ywz, r16.xyz);
  r23.z = dot(r20.yzw, r16.xyz);
  r12.z = dot(r23.xyz, r23.xyz);
  r12.z = rsqrt(r12.z);
  r16.xyz = r23.xyz * r12.zzz;            // r16.xyz = 上帧切线（旋转后归一化）
  // 上一帧坡度弯曲（同[12]，使用LastCameraPos）
  r5.x = 0.25 * r5.x;
  r5.x = cSize.z * r5.x;
  r23.xyz = r19.xyz + r9.xyz;
  r23.xyz = -LastCameraPos.xyz + r23.xyz;
  r12.z = dot(r23.xyz, r23.xyz);
  r12.z = rsqrt(r12.z);
  r23.xyz = r23.xyz * r12.zzz;
  r12.z = dot(r16.xyz, -r23.xyz);
  r13.w = cmp(0 < r12.z);
  r13.w = r13.w ? -1 : 1;
  r5.x = v2.z * r5.x;
  r5.x = r5.x * abs(r12.z);
  r5.x = r5.x * r13.w;
  r16.xyz = r21.zxx * r5.xxx;
  r16.xyz = r18.xyz + r16.xyz;
  r23.xyz = r21.zwx * r5.xxx;
  r23.xyz = r23.xyz + r18.xyz;
  r24.xyz = r21.zxy * r5.xxx;
  r24.xyz = -r24.xyz + r18.xyz;
  r21.xyz = r21.zwy * r5.xxx;
  r18.xyz = -r21.xyz + r18.xyz;
  r18.xyz = r28.www ? r24.xyz : r18.xyz;
  r18.xyz = r16.www ? r23.xyz : r18.xyz;
  r16.xyz = r28.xxx ? r16.xyz : r18.xyz;  // r16.xyz = 上帧坡度弯曲后的局部坐标
  // 上一帧风层2旋转角放大（同[12b]）
  r5.x = r9.w * r11.w;
  r9.w = r6.w * r6.w;
  r9.w = r9.w * r9.w;
  r9.w = min(1.20000005, r9.w);
  r5.x = r9.w * r5.x;
  r2.w = r5.x + r2.w;
  r2.w = cWindWeight.y * r2.w;            // r2.w = 上帧风层2最终旋转角
  // 上一帧风层2旋转（同[12c]，绕X轴）
  r18.xyz = float3(1,0,0) * r16.xxx;
  r16.xyz = -r18.xzz + r16.xyz;
  r21.xyz = float3(0,0,1) * r16.zxy;
  r23.xyz = float3(0,1,0) * r16.yzx;
  r21.xyz = -r23.xyz + r21.xyz;
  sincos(r2.w, r5.x, r15.x);
  r16.xyz = r16.xyz * r15.xxx;
  r21.xyz = r21.xyz * r5.xxx;
  r16.xyz = r21.xyz + r16.xyz;
  r16.xyz = r18.xyz + r16.xyz;
  r18.x = -r5.x;  r18.y = r15.x;
  r21.y = dot(r18.yx, r2.yz);
  r18.z = r5.x;
  r21.z = dot(r18.zy, r2.yz);
  r21.x = r2.x;
  r2.x = dot(r21.xyz, r21.xyz);
  r2.x = rsqrt(r2.x);
  r2.xyz = r21.xyz * r2.xxx;
  r2.w = dot(r7.xyz, r16.xyz);
  r18.x = v8.w + r2.w;
  r2.w = dot(r8.xyw, r16.xyz);
  r18.y = v9.w + r2.w;
  r2.w = dot(r5.yzw, r16.xyz);
  r18.z = v10.w + r2.w;                   // r18.xyz = 上帧风层2后世界坐标
  r7.x = dot(r7.xyz, r2.xyz);
  r7.y = dot(r8.xyw, r2.xyz);
  r7.z = dot(r5.yzw, r2.xyz);
  r2.x = dot(r7.xyz, r7.xyz);
  r2.x = rsqrt(r2.x);
  r2.xyz = r7.xyz * r2.xxx;
  r5.x = dot(r27.xzw, r2.xyz);
  r5.y = dot(r25.ywz, r2.xyz);
  r5.z = dot(r20.yzw, r2.xyz);
  r2.x = dot(r5.xyz, r5.xyz);
  r2.x = rsqrt(r2.x);
  r2.xyz = r5.xyz * r2.xxx;              // r2.xyz = 上帧携带法线（风层2旋转后）
  // 上一帧风层3颤抖角的atan2 + 噪声采样（同[13]-[14]，使用LastWindParam/Misc2）
  r5.xy = r15.yy + r12.yw;
  r5.xy = frac(r5.xy);
  r2.w = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, r5.xy, 0).w;
  r5.x = min(abs(r14.x), abs(r14.y));
  r5.y = max(abs(r14.x), abs(r14.y));
  r5.y = 1 / r5.y;
  r5.x = r5.x * r5.y;
  r5.y = r5.x * r5.x;
  r5.z = 0.0208350997 * r5.y;
  r5.z = -0.0851330012 + r5.z;
  r5.z = r5.y * r5.z;
  r5.z = 0.180141002 + r5.z;
  r5.z = r5.y * r5.z;
  r5.z = -0.330299497 + r5.z;
  r5.y = r5.y * r5.z;
  r5.y = 0.999866009 + r5.y;
  r5.x = r5.x * r5.y;
  r5.y = cmp(abs(r14.y) < abs(r14.x));
  r5.z = -2 * r5.x;
  r5.z = 1.57079637 + r5.z;
  r5.y = r5.y ? r5.z : 0;
  r5.x = r5.y + r5.x;
  r5.y = cmp(r14.y < -r14.y);
  r5.y = r5.y ? -3.141593 : 0;
  r5.x = r5.x + r5.y;
  r5.y = min(r14.x, r14.y);
  r5.z = max(r14.x, r14.y);
  r5.y = cmp(r5.y < -r5.y);
  r5.z = cmp(r5.z >= -r5.z);
  r5.y = r5.z ? r5.y : 0;
  r5.x = r5.y ? -r5.x : r5.x;
  r5.x = 6.28318548 + -r5.x;
  r5.x = 1.57079637 + r5.x;
  r5.yz = float2(0.0500000007,0.0500000007) * r18.zx;
  r5.yz = frac(r5.yz);
  sincos(r5.x, r5.x, r7.x);
  r7.xy = r7.xx * r5.zy;
  r5.xy = r5.yz * r5.xx;
  r8.x = r7.x + r5.x;
  r8.y = r7.y + -r5.y;
  r5.xy = r15.zz + r8.xy;
  r5.xy = frac(r5.xy);
  r5.x = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, r5.xy, 0).w;
  r5.x = 0.5 * r5.x;
  r2.w = r5.x + r2.w;
  r2.w = -0.5 + r2.w;
  r2.w = r2.w * r12.x;                   // * 上帧LastWindParam.w（全局风力）
  r2.w = r2.w * r7.w;                    // * phase^0.04
  r2.w = r2.w * r3.w;                    // * 上帧草叶高度尺度
  r2.w = cWindWeight.z * r2.w;           // r2.w = 上帧风层3颤抖角
  // 上一帧颤抖旋转（同[14]）
  r5.xyz = cStandardGrass * r19.xyz;
  r5.xyz = r9.xyz + -r5.xyz;
  r7.xyz = r5.xyz + -r11.xyz;
  r3.w = dot(r13.xyz, r7.xyz);
  r7.xyz = r13.xyz * r3.www;
  r7.xyz = r11.xyz + r7.xyz;
  r8.xyw = -r7.xyz + r5.xyz;
  r12.xyz = r13.yzx * r8.wxy;
  r14.xyz = r13.zxy * r8.ywx;
  r12.xyz = -r14.xyz + r12.xyz;
  sincos(r2.w, r14.x, r15.x);
  r8.xyw = r15.xxx * r8.xyw;
  r12.xyz = r14.xxx * r12.xyz;
  r8.xyw = r12.xyz + r8.xyw;
  r7.xyz = r8.xyw + r7.xyz;
  r5.xyz = r7.xyz + -r5.xyz;             // 上帧颤抖delta
  r2.w = 1 + -r15.x;
  r12.xyzw = r2.wwww * r13.xxzy;
  r7.xyz = r14.xxx * r13.zxy;
  r14.xy = r12.zy * r13.xy + r7.zx;
  r16.xy = r12.xw * r13.xy + r15.xx;
  r14.z = r12.w * r13.z + -r7.y;
  r20.xy = r12.yz * r13.yx + -r7.xz;
  r20.z = r12.w * r13.z + r7.y;
  r20.w = r12.z * r13.z + r15.x;
  r16.z = r20.x;
  r16.w = r14.x;
  r7.x = dot(r16.xzw, r2.xyz);
  r14.w = r16.y;
  r7.y = dot(r14.ywz, r2.xyz);
  r7.z = dot(r20.yzw, r2.xyz);
  r2.x = dot(r7.xyz, r7.xyz);
  r2.x = rsqrt(r2.x);
  r2.xyz = r7.xyz * r2.xxx;
  // 累加上帧位移
  r5.xyz = r19.xyz + r5.xyz;             // 上帧风层1delta + 颤抖delta
  r5.xyz = r18.xyz + r5.xyz;             // + 上帧风层2世界坐标
  // 上一帧踩压方向轴（同[15]前半段）
  r7.xy = r22.yx + -r22.wz;
  r7.yz = -r7.xy;
  r7.x = 0;
  r8.xyw = r7.zxy * r13.yzx;
  r7.xyz = r7.xyz * r13.xyz;
  r7.xyz = r8.xyw + -r7.xyz;
  r2.w = dot(r7.yzx, r7.yzx);
  r3.w = cmp(0.00100000005 < r2.w);
  r2.w = rsqrt(r2.w);
  r8.xyw = r7.xyz * r2.www;
  r7.xyz = r3.www ? r8.xyw : r7.xyz;    // r7.xyz = 上帧踩压轴（归一化）
  // 上一帧踩压旋转（同[15]，使用r10.y=上帧踩压幅度）
  r2.w = r11.w * r6.w;
  r2.w = min(1.29999995, r2.w);
  r8.xy = float2(0.100000001,0.100000001) * r9.xz;
  r8.xy = Misc2.xx + r8.xy;             // Misc2.x = 上帧时间
  r8.xy = frac(r8.xy);
  r3.w = tWindNoiseMap.SampleLevel(sWindNoiseMapSampler_s, r8.xy, 0).w;
  r5.w = 1 + r10.y;
  r5.w = 1 / r5.w;
  r5.w = 1 + -r5.w;                     // r5.w = 上帧踩压非线性强度
  r6.w = 9 * r5.w;
  r6.w = 3.14159274 * r6.w;
  r6.w = r6.w * r7.w;
  r6.w = r6.w * r2.w;
  r6.w = cImpactParam.x * r6.w;
  r6.w = sin(r6.w);
  r3.w = r6.w * r3.w;
  r3.w = r3.w * r8.z;                   // r8.z = 0.5+r10.w（当前帧相位因子，跨帧复用）
  r2.w = r3.w * r2.w;
  r1.w = r2.w * r1.w;
  r1.w = r1.w * r10.y;
  r1.w = cImpactParam.y * r1.w;         // r1.w = 上帧踩压旋转角
  r8.xyz = r5.xyz + -r11.xyz;
  r2.w = dot(r7.yzx, r8.xyz);
  r8.xyz = r7.yzx * r2.www;
  r8.xyz = r11.xyz + r8.xyz;
  r11.xyz = -r8.xyz + r5.xyz;
  r12.xyz = r11.zxy * r7.zxy;
  r13.xyz = r11.yzx * r7.xyz;
  r12.xyz = -r13.xyz + r12.xyz;
  sincos(r1.w, r13.x, r14.x);
  r11.xyz = r14.xxx * r11.xyz;
  r12.xyz = r13.xxx * r12.xyz;
  r11.xyz = r12.xyz + r11.xyz;
  r8.xyz = r11.xyz + r8.xyz;
  r8.xyz = r8.xyz + -r5.xyz;            // r8.xyz = 上帧踩压delta
  r1.w = 1 + -r14.x;
  r11.xyzw = r1.wwww * r7.yyxz;
  r12.xyz = r13.xxx * r7.xyz;
  r13.xy = r11.zy * r7.yz + r12.zx;
  r15.xy = r11.xw * r7.yz + r14.xx;
  r13.z = r11.w * r7.x + -r12.y;
  r16.xy = r11.yz * r7.zy + -r12.xz;
  r16.z = r11.w * r7.x + r12.y;
  r16.w = r11.z * r7.x + r14.x;
  r15.z = r16.x;
  r15.w = r13.x;
  r7.x = dot(r15.xzw, r2.xyz);
  r13.w = r15.y;
  r7.y = dot(r13.ywz, r2.xyz);
  r7.z = dot(r16.yzw, r2.xyz);
  r1.w = dot(r7.xyz, r7.xyz);
  r1.w = rsqrt(r1.w);
  r8.xyz = r8.xyz * r5.www;             // 按强度缩放踩压delta
  r7.xyz = r7.xyz * r1.www + -r2.xyz;
  r2.xyz = r5.www * r7.xyz + r2.xyz;    // 上帧法线混合
  r1.w = dot(r2.xyz, r2.xyz);
  r1.w = rsqrt(r1.w);
  r2.xyz = r2.xyz * r1.www;             // 归一化上帧法线
  r5.xyz = r8.xyz + r5.xyz;             // r5.xyz = 上帧踩压后最终世界坐标
  // 上帧LOD距离混合法线
  r3.xyz = r3.xyz * r1.zzz + -r2.xyz;
  r2.xyz = r10.zzz * r3.xyz + r2.xyz;  // r2.xyz = 上帧最终法线
  // 上一帧焦烧贴图（同[16]，使用LastFoliageCenter.zw）
  r1.zw = -LastFoliageCenter.zw + r9.xz;
  r1.zw = float2(0.015625,0.015625) * r1.zw;  // 1/64
  r1.zw = float2(0.5,0.5) + r1.zw;
  r1.z = tFoliageBurnMap.SampleLevel(sFoliageBurnMapSampler_s, r1.zw, 0).x;
  r1.z = saturate(r1.z);               // r1.z = 上帧 burnFactor
  r3.xyz = r9.xyz + -r5.xyz;           // 上帧LOD坐标 - 上帧变形坐标
  r3.xyz = r3.xyz * r1.zzz;
  r3.xyz = r5.xyz + r3.xyz;            // r3.xyz = 上帧最终世界坐标（焦烧混合后）
  // 上帧法线输出（o3）
  r5.xyz = r6.xyz + -r2.xyz;
  o3.xyz = r1.zzz * r5.xyz + r2.xyz;  // o3.xyz = 上帧最终法线（焦烧混合后）

  // ===========================================================================
  // [19] 运动向量计算
  //      当前帧: ViewRotationProjTex 投影 (仅旋转，消除摄像机平移抖动)
  //      上一帧: LastViewRotationProjTex 投影
  //      差值 = 屏幕空间运动向量
  //      若任意坐标超出[0,1]屏幕范围，运动向量置零
  // ===========================================================================
  r2.xyz = -CameraPos.xyz + r17.xyz;    // 当前帧: worldPos - cameraPos（消除摄像机平移）
  r2.w = 1;
  r5.x = dot(r2.xyzw, ViewRotationProjTex._m00_m10_m20_m30);
  r5.y = dot(r2.xyzw, ViewRotationProjTex._m01_m11_m21_m31);
  r1.z = dot(r2.xyzw, ViewRotationProjTex._m03_m13_m23_m33);
  r2.xy = r5.xy / r1.zz;               // r2.xy = 当前帧屏幕坐标（透视除法）
  r3.xyz = -LastCameraPos.xyz + r3.xyz; // 上一帧: worldPos - lastCameraPos
  r3.w = 1;
  r1.z = dot(r3.xyzw, LastViewRotationProjTex._m00_m10_m20_m30);
  r1.w = dot(r3.xyzw, LastViewRotationProjTex._m01_m11_m21_m31);
  r3.x = dot(r3.xyzw, LastViewRotationProjTex._m03_m13_m23_m33);
  r2.zw = r1.zw / r3.xx;              // r2.zw = 上一帧屏幕坐标
  // 越界检测
  r3.xyzw = cmp(r2.xyzw < float4(0,0,0,0));
  r1.zw = (int2)r3.zw | (int2)r3.xy;
  r1.z = (int)r1.w | (int)r1.z;
  r3.xyzw = cmp(float4(1,1,1,1) < r2.xyzw);
  r3.xy = (int2)r3.zw | (int2)r3.xy;
  r1.w = (int)r3.y | (int)r3.x;
  r1.z = (int)r1.w | (int)r1.z;      // r1.z = 任意坐标超出[0,1]？
  r2.xy = r2.zw + -r2.xy;            // 运动向量 = 上帧坐标 - 当前帧坐标
  o7.xy = r1.zz ? float2(0,0) : r2.xy; // 超界则置零

  // ===========================================================================
  // [20] 最终输出写入
  // ===========================================================================
  r4.x = CameraInfo.z * r1.x;        // 线性化深度（CameraInfo.z * w）
  o0.w = r1.x;                        // 裁剪空间 w 分量
  o1.xyzw = r0.xyzw;                  // UV 输出（xy=UV0, zw=UV1）
  o2.xyz = r17.xyz;                   // 当前帧最终世界坐标
  o2.w = r1.y;                        // ?（可能是其他深度值）
  o3.w = 0;
  o4.w = 0;
  o5.y = v2.y;                        // 顶点类型（0=根,1=顶端）
  o5.xzw = r10.xzw;                   // x=随机缩放因子, z=上帧LOD因子, w=随机相位
  o6.xyzw = r4.xyzw;                  // 包含线性深度等
  o7.zw = float2(1,0);                // z=1 (运动向量有效标志), w=0
  return;
}
