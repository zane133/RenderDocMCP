# 草/植被顶点着色器分析文档

> 来源：RenderDoc + 3Dmigoto v1.4.6 反编译  
> 文件都在 `shaders/archive/grass_foliage/`  
> 原始文件：`grass_vs_paste_dump.hlsl`  
> 可读版本：`grass_vs_readable.hlsl`（注释版）、`grass_vs_readable_refactor.hlsl`（重构版）

---

## 1. 概述

这是一个 **GPU Driven 草地顶点着色器**，每根草叶通过 `TEXCOORD3/4/5` 携带独立的 3×4 变换矩阵，在 VS 中完成：

- 顶点解压缩（11/10/11 位整数 / 归一化 float）
- LOD 距离缩放（远处草叶按 FOV 放大）
- 三层风力动画（风向偏转 / 主摆动 / 高频颤抖）
- 玩家踩压互动
- 坡度/视角厚度修正
- 焦烧破坏
- 运动向量（TAA 用，完整重复上一帧计算）

---

## 2. 文件说明

| 文件 | 用途 | 是否改代码 |
|------|------|-----------|
| `grass_vs_paste_dump.hlsl` | 3Dmigoto 原始反编译 | — |
| `grass_vs_readable.hlsl` | 逐行注释，**数学 100% 与原版一致** | 否 |
| `grass_vs_readable_refactor.hlsl` | 重构为可读函数/变量名 | 是（已修正主要错误） |

**选用建议：**

- 需要 **替换进游戏且形态完全一致** → 用 `grass_vs_readable.hlsl`
- 需要 **阅读理解/二次开发** → 用 `grass_vs_readable_refactor.hlsl`
- 重构版中 **上一帧运动向量路径仍为占位**，不影响弯曲形态，只影响 TAA

---

## 3. 输入语义

| 寄存器 | 语义 | 含义 |
|--------|------|------|
| `v1` POSITION0 | xyz | 局部坐标（可能压缩），w≈255 表示原始浮点 |
| `v2` COLOR0 | r | 弯曲刚度：0=刚硬，1=柔软 |
| | g | 顶点类型：0=根，(0,0.4]=中段，1=顶端 |
| | b | 厚度权重 |
| `v3` NORMAL0 | xyz | [0,1] 编码法线，需 `*2-1` |
| `v4/v5` TEXCOORD0/1 | xy | UV0 / UV1（可能压缩扩展） |
| `v6` TANGENT0 | xyz | 切线 |
| `v8` TEXCOORD3 | xyz + w | 变换矩阵行0 + **根部世界 X** |
| `v9` TEXCOORD4 | xyz + w | 变换矩阵行1 + **根部世界 Y** |
| `v10` TEXCOORD5 | xyz + w | 变换矩阵行2 + **根部世界 Z** |

**关键概念 `worldRoot`：**

```hlsl
float3 worldRoot = float3(v8.w, v9.w, v10.w);
```

所有风力旋转的支点都围绕根部展开，叶尖摆幅大、根部几乎不动。

---

## 4. 常量缓冲区要点

### Global (b2)

| 变量 | 含义 |
|------|------|
| `CameraPos` | 当前帧摄像机世界坐标 |
| `CameraInfo.w` | 垂直 FOV（弧度） |
| `WindParam.xyz` | 风向量（世界空间） |
| `WindParam.w` | 全局风力强度 [0,1] |
| `LastWindParam` | 上一帧风参数（运动向量） |
| `Misc.w` | 当前帧时间（风噪声 UV 滚动） |
| `Misc2.x` | 上一帧时间 |
| `LastCameraPos` | 上一帧摄像机位置 |

### Shader (b1) — 草材质

| 变量 | 含义 |
|------|------|
| `cWindWeight.xyz` | 三层风权重：方向 / 主摆 / 颤抖 |
| `cBendScale` | 朝摄像机预弯曲强度 |
| `cSlopeScale` | 坡度弯曲 |
| `cGrassSize.xy` | LOD 缩放时 X/Y 方向比例 |
| `cImpactParam` | x=踩压波形频率，y=踩压位移强度 |
| `cStandardGrass` | 标准化插值（颤抖目标姿态） |
| `cLocalWindScale_Piv` | 风噪声采样频率缩放 |
| `cRandoffset` | 逐材质随机相位偏移 |

### Batch (b0)

| 变量 | 含义 |
|------|------|
| `LocalBoundingBoxMin/Max` | 顶点压缩解码 AABB |
| `VertexCompressionParams` | xy = 位置/UV 压缩类型 |
| `FoliageCenter.xy` | 植被互动贴图世界中心 |
| `FoliageCenter.zw` | 焦烧贴图世界中心 |
| `FoliageMapParam.x` | 植被贴图覆盖半径 |
| `ViewRotationProjTex` | 运动向量用投影矩阵（仅旋转） |

### 纹理

| 纹理 | 通道 | 用途 |
|------|------|------|
| `tWindNoiseMap` | .w | 风噪声值 |
| `tFoliageMap` | .xy | 玩家踩压方向向量 |
| | .zw | 风力遮蔽强度 |
| `tFoliageBurnMap` | .x | 焦烧因子（0=完好保留弯曲，1=烧毁变直立） |
| `tLastFoliageMap` | 同上 | 上一帧植被数据（运动向量） |

---

## 5. 处理流水线（当前帧）

```
[1] 顶点解压
      v1.w ≈ 255 → 直接用
      否则按 VertexCompressionParams 解码位置/UV

[2] 法线/切线
      localNormal = v3 * 2 - 1
      carriedNormal = v2.x * (up - n̂) + n̂   // 刚度混合

[3] 世界变换
      worldPos  = M * localPos + worldRoot
      lodWorldPos = LOD矩阵 * localPos + worldRoot

[4] 随机哈希（逐草叶相位）
      seed = int(root.x*10) + int(root.z*10) + int(root.y*10)
      hashFrac = Hash33(seed)
      randomPhase = saturate(cRandoffset + hashFrac)

[5] LOD 缩放
      dist = length(CameraPos - worldRoot)
      lodScale = 1 + (3,1,0.2) * saturate(max(0, dist-3) / threshV)
      row0/1/2 = v8/v9/v10 * cGrassSize * lodScale

[6] 提取草叶坐标系
      bladeUp     = normalize(LOD矩阵 · (0,1,0))   // 草叶 up 轴
      heightScale = |LOD矩阵 · (0,1,0)|            // 草叶高度尺度
      diagDir     = normalize(LOD矩阵 · (-0.72,0.72,0))

[7] BendScale（可选）
      绕局部 X 轴旋转 localPos
      角度 = cBendScale * (1 - rootFactor)

[8] 风层1 — 风向偏转
      轴：bladeUp（不是世界 Y！）
      角度：cWindWeight.x * atan2(windDir.xz)
      输出：wind1Delta = 旋转后世界坐标 - 旋转前

[9] 风噪声采样
      UV = frac( dot((1,0,0), diagDir+root), dot((0,0,1), diagDir+root) ) + timeOffset
      ❌ 错误写法：frac(currentPos.xz + time)

[10] 风层2 摆角计算
      sway = (-0.898 + 0.35*bendEff + 0.6π*noise) * heightScale * phase * WindParam.w
      ❌ 错误写法：用 length(顶点-根部) 代替 heightScale

[11] 坡度弯曲（在风层2旋转之前！）
      根据 v2.y 选 4 种局部偏移方向
      厚度由视角方向 + cSlopeScale 决定

[12] 风层2 — 主摆动
      绕局部 X 轴旋转 deformedLocal
      角度 = cWindWeight.y * sway

[13] 风层3 — 高频颤抖
      目标 = lodWorldPos - cStandardGrass * wind1Delta
      绕 bladeUp 旋转目标点
      最终 = afterFlutter + wind1Delta + (wind2World - target)

[14] 玩家踩压
      从 tFoliageMap.xy 推导踩压轴（水平面内）
      sin 波形 + 风噪声调制

[15] 焦烧
      burn = tFoliageBurnMap.x
      finalWorld = lerp(deformedWorld, lodWorldPos, burn)
      // burn=0 弯曲; burn=1 直立

[16] 投影输出
      o0 = ViewProj * finalWorld
      o7.xy = 运动向量（上一帧重复 [7]~[15] 后计算）
```

---

## 6. 三层风力详解

### 风层1：风向偏转 (`cWindWeight.x`)

- **轴**：每根草自己的 `bladeUp`（LOD 矩阵 Y 列归一化）
- **角度**：全局风向在 XZ 平面的 `atan2` 近似 × 权重
- **效果**：整株草朝风向倾斜，但每根草朝向不同（因为 `bladeUp` 不同）

### 风层2：主摆动 (`cWindWeight.y`)

- **轴**：局部 X 轴（`RotateLocalX`，只动 YZ）
- **幅度**：`heightScale`（草叶高度）× 风噪声 × 刚度 × 遮蔽
- **顺序**：先算摆角 → 坡度修正局部坐标 → 再执行旋转

### 风层3：高频颤抖 (`cWindWeight.z`)

- **轴**：`bladeUp`
- **噪声**：两套 UV（根部偏移 120.32 + 世界坐标螺旋采样）
- **目标**：在 `lodWorldPos - cStandardGrass * wind1Delta` 上旋转
- **累加**：`afterFlutter + wind1Delta + (wind2World - flutterTarget)`

---

## 7. 重构版的错误与修正

首次重构（`grass_vs_readable_refactor.hlsl` 初版）导致 **草叶统一斜向弯曲**，原因如下：

| # | 错误 | 现象 | 修正 |
|---|------|------|------|
| 1 | 风层1/2 绕世界 Y 轴 | 全场景同向倾斜 | 风层1/3 用 `bladeUp`，风层2 用局部 X |
| 2 | 风噪声 UV 用 `currentPos.xz` | 噪声空间错乱 | 用 `(diagDir + worldRoot)` 的 XZ 投影 |
| 3 | 摆幅用 `length(顶点-根部)` | 弯曲幅度不对 | 用 `heightScale`（矩阵 Y 列长度） |
| 4 | 哈希公式简化错误 | 随机相位同步 | 还原 Hash33 完整步骤 |
| 5 | 坡度与摆动顺序颠倒 | 形态失真 | 先坡度、后风层2 旋转 |
| 6 | 风层3 直接改 `currentPos` | 位移累加错误 | 使用原版三段式累加公式 |
| 7 | 缺少 `carriedNormal` | 法线不随风转 | 添加刚度混合法线 |
| 8 | `ApproxAtan2` 象限修正错误 | 风向角偏差 | 对齐原版多项式 + 象限逻辑 |

---

## 8. 关键公式摘录

### 随机哈希

```hlsl
int seed = (int)(10*root.x) + (int)(10*root.z) + (int)(10*root.y);
float3 h = frac(float3(0.1031, 0.103, 0.0973) * seed);
float3 h2 = h.yzx + 19.19;
h = h + dot(h, h2);
float hashFrac = frac((h.x + h.z) * h.y);
float randomScale = exp2(0.7 * log2(sin(π * hashFrac)));
```

### 携带法线

```hlsl
float3 n = normalize(localNormal);
float3 carried = v2.x * (float3(0,1,0) - n) + n;
```

### 风噪声 UV（主采样）

```hlsl
float3 timeOff = Misc.w * float3(0.08, 0.06, 0.12) * cLocalWindScale_Piv;
timeOff.xy += 0.05 * rootFactor;
float3 samplePos = diagDir + worldRoot;
float2 uv = frac(float2(dot(samplePos, (1,0,0)), dot(samplePos, (0,0,1))) + timeOff.x);
float noise = tWindNoiseMap.SampleLevel(s, uv, 0).w;
```

### 风层2 摆角

```hlsl
float bendEff = v2.x - v2.x * saturate(shelterStrength);
float sway = (-0.897597909
            + 0.349999994 * bendEff
            + 0.600000024 * π * noise)
           * heightScale
           * (0.5 + 0.5 * randomPhase)
           * saturate(WindParam.w);
float angle = cWindWeight.y * sway;
```

### 风层3 最终位置

```hlsl
float3 target = lodWorldPos - cStandardGrass * wind1Delta;
float3 afterFlutter = RotateWorld(target, pivot, bladeUp, flutterAngle);
float3 final = afterFlutter + wind1Delta + (wind2World - target);
```

### 焦烧混合

```hlsl
float burn = saturate(tFoliageBurnMap.SampleLevel(s, burnUV, 0).x);
// 原版: deformed + burn * (LOD - deformed) = lerp(deformed, LOD, burn)
float3 finalWorld = lerp(deformedWorld, lodWorldPos, burn);
// burn=0 完好保留弯曲; burn=1 焦烧变直立
```

**常见 bug**：写成 `lerp(lodWorldPos, deformedWorld, burn)` 会在 burn≈0（健康草）时输出 LOD 直立坐标，表现为**全场景草叶笔直无弯曲**。

---

## 9. 运动向量（上一帧）

原版在 line 786~1203 **完整重复**当前帧流程，替换为：

| 当前帧 | 上一帧 |
|--------|--------|
| `CameraPos` | `LastCameraPos` |
| `WindParam` | `LastWindParam` |
| `Misc.w` | `Misc2.x` |
| `FoliageCenter` | `LastFoliageCenter` |
| `tFoliageMap` | `tLastFoliageMap` |

投影使用 `ViewRotationProjTex` / `LastViewRotationProjTex`（消除摄像机平移）：

```hlsl
motionUV = lastScreenUV - curScreenUV;
// 超出 [0,1] 屏幕范围时置零
```

---

## 10. 调试检查清单

替换 shader 后若形态不对，按顺序排查：

- [ ] 风层1 是否绕 `bladeUp` 而非 `(0,1,0)`
- [ ] 风层2 是否绕局部 X 轴，且在坡度弯曲之后
- [ ] 摆幅是否用 `heightScale` 而非顶点距根距离
- [ ] 风噪声 UV 是否基于 `diagDir + worldRoot`
- [ ] `worldRoot` 是否取自 `v8.w, v9.w, v10.w`
- [ ] 坡度弯曲是否在风层2 旋转之前
- [ ] 风层3 是否用三段累加而非直接赋值
- [ ] 是否误用了简化版 `ApproxAtan2`
- [ ] 焦烧 lerp 是否为 `lerp(deformed, LOD, burn)`（**不是** `lerp(LOD, deformed, burn)`）

### 捕获中各 EID 对应着色器

| EID | 类型 | 说明 |
|-----|------|------|
| **7002** | 完整风草 VS | `tWindNoiseMap` + `cWindWeight` + 三层风 + 焦烧；与 `grass_vs_readable.hlsl` 一致 |
| 7152 | 简化风草 VS | 仅 `cGrassWindWave`/`cMaxRotatio`，矩阵 v7/v8/v9，**不是**分析文档中的版本 |
| 4258 | LOD 草 VS | `GlobalCulledInstanceBuffer`，无风力，仅玩家踩压 + 距离缩放 |

替换 shader 时务必对准 **EID 7002** 这类 draw，不要误替换 LOD 变体。

---

## 11. 相关文件路径

```
RenderDocMCP/
├── shaders/archive/grass_foliage/
│   ├── grass_vs_paste_dump.hlsl        # 原始反编译
│   ├── grass_vs_readable.hlsl          # 注释版（推荐替换进游戏）
│   └── grass_vs_readable_refactor.hlsl # 重构版（已修正主要错误）
└── docs/analyses/grass_vs_analysis.md  # 本文档
```

---

*文档生成时间：2026-07-06*
