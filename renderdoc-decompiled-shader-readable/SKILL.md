---
name: renderdoc-decompiled-shader-readable
description: >-
  把 3Dmigoto/RenderDoc 反编译 HLSL 改成人类可读、且仍能通过 RenderDoc Apply Changes
  编译的着色器。在用户粘贴 3Dmigoto dump、要求可读化、修复 Apply Changes
  编译错误、加 STEP_*/DEBUG_VIS，或提到反编译 PS/VS、#define cmp -、
  SV_Position0、ubfe/SampleGrad 截断警告时使用。
---

# RenderDoc 反编译着色器 → 可读 + 可编译

目标：吃进 **3Dmigoto / RenderDoc 反编译** 着色器，产出同时满足三点的 HLSL：

1. **人能读**
2. **数学上忠实于二进制 / dump**
3. **能在 RenderDoc Apply Changes 里编过**

## 不可妥协

1. **先对画面，再谈可读。** 在寄存器忠实版已经 Apply、并对上原帧之前，不要「整理」数学。
2. **保住绑定和签名。** 显式 `register(tN/sN/bN)`、输入输出语义和类型必须与绑定的 VS/PS 对得上。
3. **每次大改都要在 RenderDoc 里验证**（Apply Changes → 和改之前的捕获对比）。
4. **刚贴的 dump 才是真相。** 永远处理用户**这次贴出来的**文件。不要因为已有 `*_readable.hlsl`「看起来一样」就跳过 Step 1，更不要先拿旧分析稿覆盖。

## 硬闸门（不许跳）

| 做完… | Agent 必须… |
|--------|-------------|
| 写出 Step 1 | **停下。** 让用户 Apply Changes 并对比。等确认（`没问题` / `继续` / 画面一致）。 |
| 用户确认对上 | 这才做 Step 3（若对方要求）→ Step 4 → Step 5 → Step 6。 |
| 用户说「继续」 | 只推进 **一个** 还没做完的步骤（4 → 5 → 6）。 |
| 用户要「人类可读 / 优化 rx / 翻译 cb」 | 跑 **Step 6**（Step 5 或 Step 4 已 OK 之后）。 |
| 画面对不上 | 退回寄存器 / `r0` 形态；修好；再 Apply。不要继续改名。 |

## 反模式（一做就翻车）

- Apply 验证过的 Step 1 还没有，就上 `LoadMaterial` / `Eval*` / `STEP_*`。
- 把新 dump 当成「和上次手 SSS / 草一样」，直接交旧 readable。
- 用户没点名就删 VT / 体积光等路径（只能 Step 3，且必须对方要求）。
- 「好心」重写密集体块（三次体积采样、VT 页表）导致和 dump 寄存器分叉。
- 把 `exp2(k*log2(x))` 换成 `pow`，或编一个和 dump 的 `mad` 并不恒等的 `lerp`。

## 工作流（复制并勾进度）

```
进度:
- [ ] 1. 吃进 dump + 最小 RenderDoc 补丁
- [ ] 2. 用户 Apply Changes — 必须和原画面一致  ← 没 OK 就停
- [ ] 3. 可选：删死路径（仅用户点名）
- [ ] 4. 渐进可读化
- [ ] 5. 可选：STEP_*/DEBUG_VIS 分析开关
- [ ] 6. 可选：人类可读语义稿（去掉 rN / 给 CB 起名）
```

### Step 1 — 最小补丁（必须能编过）

从**刚贴的 dump** 起步（必要时先写进目标 `.hlsl`）。优先跑自带脚本，再**手改脚本覆盖不到的**：

```bash
python <this-skill>/scripts/patch_3dmigoto_for_renderdoc.py input.hlsl -o out_renderdoc.hlsl
```

必改项见 [reference.md](reference.md)：

| dump 产物 | RenderDoc 安全写法 |
|---|---|
| `#define cmp -` | `float cmp(bool v) { return v ? -1.0 : 0.0; }`（加 float2/3/4 重载） |
| `SV_Position0` / `SV_Target0` / `SV_VertexID0` / `SV_InstanceID0` | 去掉末尾 `0` |
| `Texture2DArray.SampleGrad(..., float3/标量)` | 用完整 ddx/ddy 寄存器的 **`.xy`**（消 X3206，且忠实） |
| 页表 / 打包 uint 读取 | `asuint(...)` + `ubfe`/移位/`&`，不要 `(uint)floatValue` |
| DXBC `ubfe` 被写成巨大的 `if (10==0)` | 改成经 `asuint` 的位域提取 |

这一步 **不要**：给资源改名、拆改 CB 布局、抽 helper、加 STEP_*、删 VT/体积光，或从另一份 readable 搬逻辑。

交付：寄存器忠实 HLSL（`r0/r1…` 可以）+ 只说明改了哪些补丁。

### Step 2 — 证明忠实

- 用户贴进 RenderDoc → **Apply Changes**。
- 和未改的绘制对比（并排 / 直方图 / Pixel History）。
- 没明确 OK 之前，Agent 不做 Step 4/5。

常见分叉原因：`SampleGrad` 参数个数不对、`(uint)` 对 `asuint`、`mad`/`lerp` 顺序被改、`pow` 代替 `exp2(k*log2(x))`、TEXCOORD 拆分坏了（`float2 v6` + `float w6`）、体积光/VT 数学被「清理」过。

### Step 3 — 可选删路径

仅当用户要求（例如去掉体积光 / VT）：

- 删代码 **以及** 不再用的 `Texture*` / `SamplerState` / `cbuffer` 声明。
- VS 仍在写的插值器，即使 PS 不用也要 **留在 `main` 参数里**。
- 再 Apply，确认剩下的样子就是对方要的。

### Step 4 — 渐进可读

必须 Step 2 OK 之后。要清楚，但 **别改运算**：

1. 在已验证的寄存器版上加分段注释（可选快过一遍）。
2. 局部变量起名（`modelUV`、`fresnel`）——表达式不变。
3. CB 字段别名 / `struct Material` + `LoadMaterial()` —— 继续用 `float4 cbN[]`。
4. 抽出 `Eval*` —— 函数体数学不变。
5. 贴图/采样器 **名字** 可读（`register` 不变）。

**又密又脆的块**（VT 页表、8 tap 三次体积、位打包）：helper **里面**继续放寄存器忠实代码（复制已验证的 Step 1 函数体），不要凭记忆重推权重。

dump 用了 log/exp 就继续写 `exp2(k*log2(x))`，不要换成 `pow`。
只有和 dump 代数恒等时才用 `a + t*(b-a)` / `lerp`。

### Step 5 — 分析开关（可选）

研究分阶段时（常在 Step 4 后对方说「继续」），在文件顶加：

```hlsl
#define STEP1_... 1
#define DEBUG_VIS 0  // 0=最终结果, 1..N=中间量
```

每个 STEP：

- 默认 **开** = 原行为。
- **关** = 真正的恒等 / 该项无贡献 —— **不是**「曲线峰值」。

**关键：** 若某项是 `mix * exp2(k * log(falloff))`，关掉 falloff 时必须让该项因子为 **0**，不能把 `log` 置 0（→ `exp2(0)=1` → 爆白）。在开关旁写清楚。

`DEBUG_VIS` = **合成之前** 的中间量（例如 mask 前的 ramp、体积光前的颜色）。

**DEBUG_VIS 提示：** 在 **rim 计算现场** 抓边缘 / fresnel。后面的雾/灯经常复用同一个 `rN` 再 return（例如 `1-|N·V|` 全白的坑）。

### Step 6 — 人类可读语义稿（可选）

用户要 **人类可读** / **优化 rx** / **翻译 cb** / 给 TA 看的精简文件时
（通常在 Step 5 之后；没有分析稿则 Step 4 OK 即可）：

交付：`*_readable.hlsl`（或同类名），TA 能从头读到尾。

**目标**

1. 函数体里 **不要一锅 `r0`/`r1`…** —— 只用语义名（`viewDir`、`N`、`litDirect`、`rimTerm`、`gi`…）。
2. 函数体里 **不要裸写 `cb0[186].z`** —— 在 `main` 开头（或一小段参数块）别名一次，再用名字（`sunDir`、`albedoLitScale`…）。
3. 保住 `float4 cbN[]` 打包 + `register(tN/sN/bN)` —— 只起别名；没有证明安全就不要用 `packoffset` 重摆布局。
4. **不要** 把插值器 `v0..vN` 整份 shader 都 `const` 拷进局部 —— 以前这样干过，rim / 朝向会丢。注释它们，直接用 `v*`。
5. 行数预算：用户若要求（例如 ≤500），只砍对方点名的路径（probe / detail / tiled lights / fog），用恒等注释标出来；保住对方关心的配方（材质 → 法线 → F0 → 太阳/Ramp → 边缘光 → IBL → 校色 → 曝光）。

**别名块写法（`main` 开头）**

```hlsl
// CB 别名（推断）。左边=含义；右边=dump 槽位。
float3 sunDir         = cb0[6].xyz;    // 主光 / 太阳方向
float3 cameraPos      = cb0[44].xyz;
float  exposure       = cb0[109].x;
float3 rimColor       = cb0[194].xyz;
float  rimIntensity   = cb0[194].w;
float  albedoLitScale = cb0[186].z;
float  envIblScale    = cb0[186].w;
// …材质 cb5 → normalStrength, brdfLutBlend, gradeSat, …
```

**函数体只使用名字** —— helper 吃具名参数（`EvalViewDir(worldPos, cameraPos, camForward, viewBend)`），内部不要再写裸的 `cb0[…]`。

**命名启发（推断；不确定就在注释里说）**

| dump 用法 | 优先名 |
|----------|-------------|
| 主光方向 | `sunDir` / `mainLightDir` |
| 相机世界坐标 | `cameraPos` |
| 曝光 / 色调映射缩放 | `exposure` |
| 边缘光颜色 / 强度 / 宽度 | `rimColor`、`rimIntensity`、`rimWidth` |
| 反照 / 环境 / IBL 缩放 | `albedoLitScale`、`envIblScale`、`skyLitScale` |
| 屏幕 AO 混合 | `screenAoBlend` |
| 材质法线强度 | `normalStrength` |
| 校色开关/饱和/对比 | `gradeEnable`、`gradeSat`、`gradeContrast` |

**Step 6 反模式**

- 函数体里留着半截 `rN` +「错了；正确是…」注释。
- 改名的同时发明 `lerp`/`pow`。
- 大砍路径之后还声称二进制完全一致 —— 应叫 **配方忠实（recipe-faithful）**，Apply 对照仍以 Step 5 为准。

Step 6 之后：让用户 Apply 这份可读稿，抽查 rim / Ramp / 曝光；完整灯光/雾仍在 `*_step5_analysis.hlsl`。

## 每步交付

每一步交出一份能贴进 RenderDoc 的 `.hlsl`，外加短说明：

- 这一步补了 / 改写了什么
- 删了什么（若有）
- 怎么用 STEP_*/DEBUG_VIS（若加了）
- Step 6：别名表摘要 + 砍了哪些路径
- 用户下一步该做什么（Apply / 确认 / 继续）
- 风险（同一 shader 对象会影响所有用它的绘制）

## 更多资料

- 坑、签名、位运算、STEP 恒等、Step 6 命名：[reference.md](reference.md)
- 补丁脚本：[scripts/patch_3dmigoto_for_renderdoc.py](scripts/patch_3dmigoto_for_renderdoc.py)
  （只处理 cmp + SV_*；ubfe / SampleGrad / asuint 必须手改）
