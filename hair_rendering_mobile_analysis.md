# 人物毛发渲染方案分析 — Unity 手机端 60fps

## 约束条件

- **引擎**: Unity (URP 为主，Built-in/BiRP 亦可)
- **平台**: 移动端 (iOS/Android, Tile-based GPU)
- **目标帧率**: 60fps (16.67ms 总帧预算，毛发通常分配 2~5ms)
- **核心瓶颈**: Fill rate (overdraw)、ALU 复杂度、Texture sample 数量、带宽

---

## 方案对比总览

| 方案 | GPU 开销 | 画质 | 动态性 | 实现复杂度 | 移动端 60fps |
|------|---------|------|--------|-----------|-------------|
| Hair Card + Alpha Blend | ⭐⭐ 中 | ⭐⭐⭐ 好 | ✅ 可动态 | ⭐⭐ 中 | ✅ 首选 |
| Shell Texturing | ⭐⭐⭐ 高 | ⭐⭐ 一般 | ❌ 静态 | ⭐ 低 | ⚠️ 需优化 |
| 简化 Marschner (Kajiya-Kay) | ⭐⭐ 中 | ⭐⭐⭐ 很好 | ✅ 可动态 | ⭐⭐⭐ 高 | ✅ 可行 |
| 纯 Mesh 几何 | ⭐ 极低 | ⭐ 差 | ✅ 可动态 | ⭐ 低 | ✅ 可行 |
| Strand-based (Compute) | ⭐⭐⭐⭐⭐ 极高 | ⭐⭐⭐⭐⭐ 极好 | ✅ 可动态 | ⭐⭐⭐⭐⭐ 极高 | ❌ 不可行 |

---

## 1. Hair Card + Alpha Blend（推荐首选）

**原理**: 将头发建模为多层发片 (Card)，每层贴带 Alpha 的纹理，用多层叠加模拟体积感。

**移动端适用性**: ⭐⭐⭐⭐⭐

**关键参数**:
- Card 层数: 8~16 层（Face/Head 级别），中远景可降到 4~6 层
- 每 Card 三角形: 8~24 个（合理的面数）
- 纹理: 1~2 张 (BaseColor + Alpha 打包进 BaseColor.a)
- 顶点数总量: 人物整体 < 2000 verts

**Shader 要点**:
```hlsl
// 最简移动端 Hair Card Shader 结构
- Single texture sample (BaseColor + Alpha in alpha channel)
- Lambert / Half-Lambert diffuse
- 可选: 简单的 Blinn-Phong anisotropic 高光 (用 tangent 方向)
- No multi-pass, No GrabPass
- Alpha blend: Blend SrcAlpha OneMinusSrcAlpha
- ZWrite Off (头发通常不写深度, 或最后一层写)
```

**Overdraw 控制策略**（移动端关键）:
1. 分层 LOD：远处角色减少 Card 层数
2. 背面不画：双面渲染仅在需要时开启
3. Alpha Test 代替 Alpha Blend：中远景可切到 Cutout 模式来恢复 Early-Z
4. 比画顺序：尽量先画不透明物体，头发的 Alpha Blend 在最后

**Unity 实现建议**:
- URP: 使用 `Simple Lit` 或手写 `Unlit` + 自定义光照
- 不依赖 Renderer Features（避免额外 Pass）
- 材质球参数少（减少 SRP Batcher 的 cbuffer 大小）

---

## 2. 简化 Marschner / Kajiya-Kay 光照

**原理**: 基于头发纤维的各向异性散射模型。Marschner 考虑 R/TT/TRT 三个 lobe；Kajiya-Kay 是简化版，只做切线方向高光。

**移动端适用性**: ⭐⭐⭐⭐（需精简）

**推荐使用的是 Kajiya-Kay 而非完整 Marschner**:

```hlsl
// Kajiya-Kay Anisotropic Specular (移动端精简版)
// T = 发丝切线方向 (沿 Card 的 UV 方向)
// H = normalize(L + V)
float TdotH = dot(T, H);
float sinTH = sqrt(1.0 - TdotH * TdotH); // sin(angle)
float spec = pow(sinTH, specPower);       // specPower: 64~256
// 可加入 shift 产生双高光效果
float spec2 = pow(sinTH, specPower * 0.5);
float finalSpec = spec * 0.6 + spec2 * 0.4;
```

**性能优化**:
- 不计算环境光遮蔽的完整积分
- 不模拟光线传播（TT/TRT 通道在移动端可忽略）
- 高光用 `pow()` 近似，不用 exp/log 查表
- 合并所有计算到单个 Pass

---

## 3. Shell Texturing

**原理**: 沿法线方向 Offset 多层 Shell，每层采样不同的纹理切片，模拟体积。

**移动端适用性**: ⭐⭐（Fill rate 压力大）

**问题**:
- 需要 N 个 Shell 层（通常 16~64 层），每层 = 一次完整渲染
- Overdraw 极严重，但因为是 Opaque 或 Cutout 模式，不经过 Alpha Blend（可通过 Depth Test 利用 Early-Z 来裁切不可见的 shell 片元）
- 实际填色率消耗 = Shell 层数 × 片元屏幕占比
- 在移动 Tile GPU 上，大面积的 Shell 会迅速耗尽帧预算

**适用场景**:
- 静态/半静态的发型展示（角色预览界面）
- 同屏角色少（1~2 个）
- 可用低 Shell 层数 (8~16) + 模糊纹理来"够用"

---

## 4. 组合方案（实战推荐）

**实际项目中通常采用组合策略**:

| LOD 等级 | 距离 | 方案 | 理由 |
|----------|------|------|------|
| LOD 0 | 近景 | Card ×12~16 + Kajiya-Kay | 最高画质，主角/自拍镜头 |
| LOD 1 | 中景 | Card ×6~8 + Half-Lambert | 降层数，降光照精度 |
| LOD 2 | 远景 | Card ×2~4 + Cutout | 切到 Alpha Test，恢复 Early-Z |
| Shadow | - | 极简 mesh 或关闭 | 头发不投射阴影 |

**每帧 60fps 对头发的预算估算**:
- 16.67ms / 帧
- Opacity geometry: ~2~3ms
- Alpha blended: ~1~2ms
- 头发如果在 Alpha 阶段，需要控制在 2ms 以内
- 降低 fill rate 影响 = 减少像素面积 × 层数

---

## 5. Unity 具体实现路线

### 5.1 资产准备
- 头发建模时，Card 采用 UV 展开（U 沿发根→发梢，V 沿发片宽度）
- BaseColor + Alpha 合并为单张纹理 (RGBA 或 DXT5/BC3)
- Normal Map 可选（如不需要高光细节，可省略以节省带宽）

### 5.2 Shader
```hlsl
Shader "Mobile/HairCard_KajiyaKay"
{
    Properties
    {
        _MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
        _SpecColor ("Specular Color", Color) = (1,1,1,1)
        _SpecPower ("Specular Power", Range(16, 512)) = 128
        _SpecShift ("Specular Shift", Range(-1, 1)) = 0.1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off  // 或 Back（如果 Card 法线正确）

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_fog

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            half4 _MainTex_ST;
            half4 _SpecColor;
            half _SpecPower;
            half _SpecShift;

            // Vertex: pass tangent (发丝方向) + normal + uv
            // Fragment: Kajiya-Kay 高光 + 简单漫反射
            half4 frag(Varyings i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                half3 albedo = tex.rgb;
                half alpha = tex.a;

                Light mainLight = GetMainLight();
                half3 N = normalize(i.normal);
                half3 T = normalize(i.tangent.xyz);    // 发丝流向
                half3 L = normalize(mainLight.direction);
                half3 V = normalize(i.viewDir);
                half3 H = normalize(L + V);

                // Diffuse: Half-Lambert (柔和)
                half NdotL = dot(N, L);
                half diffuse = NdotL * 0.5 + 0.5;
                half3 diffColor = albedo * mainLight.color * diffuse;

                // Anisotropic Specular (Kajiya-Kay)
                half TdotH = dot(T, H);
                half sinTH = sqrt(1.0 - TdotH * TdotH);
                // 双高光模拟
                half spec1 = pow(sinTH, _SpecPower);
                half spec2 = pow(sinTH, _SpecPower * 0.5);
                half spec = spec1 * 0.6 + spec2 * 0.4;
                half3 specColor = _SpecColor.rgb * mainLight.color * spec;

                half3 finalColor = diffColor + specColor;
                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}
```

### 5.3 性能优化清单
- [ ] SRP Batcher 兼容（材质属性在 UnityPerMaterial cbuffer 中）
- [ ] 只用 1 个 texture sample（`_MainTex`）
- [ ] 不用 GrabPass / RenderTexture / 额外 Camera
- [ ] LOD Group 控制 Card 层数（用不同材质/不同 Mesh LOD）
- [ ] 远景 LOD 切到 Opaque Cutout 模式（`ZWrite On`）
- [ ] 头发不参与阴影投射（ShadowCaster Pass 返回 0 或关闭 Cast Shadows）
- [ ] 用 RenderDoc 抓帧验证 DrawCall 数、Overdraw、Fragment 耗时

---

## 最终推荐

**移动端 60fps 人物毛发的最佳方案**:

```
核心: Hair Card + Alpha Blend + Kajiya-Kay 光照
LOD: 3 级分层（近 16 Card / 中 8 Card / 远 3 Card Cutout）
纹理: 单张 RGBA (BaseColor + Alpha), 512×512 或 1024×1024
Shader: 单 Pass, 1 Texture Sample, Half-Lambert + 简化 Anisotropic
顶点: LOD0 < 2000 verts 全身
```

这个方案在画质与性能之间平衡最好，也是大部分手游（原神、幻塔、鸣潮等）实际采用的思路。

---

*分析时间: 2026-05-25 | 模型: Claude Sonnet 4*
