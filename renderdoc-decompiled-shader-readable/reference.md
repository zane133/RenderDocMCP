# 参考 — RenderDoc / 3Dmigoto 着色器还原

## RenderDoc Apply Changes 限制

- D3D11 捕获上，编译器基本是 FXC / DXBC 取向。
- 资源绑定看的是 **register**，不是 HLSL 名字 —— 把 `t1` 改成 `texNoise` 没问题，只要 `: register(t1)` 还在。
- 改 `cbuffer` 打包（`float4 cb1[15]` → 没有 `packoffset` 的一堆具名字段）会**静默**打乱布局。优先：

  ```hlsl
  cbuffer MaterialCB : register(b1) { float4 cb1[15]; }
  // 再别名: float fresnelWrap = cb1[2].w;
  ```

- 输入签名必须和配对阶段一致。3Dmigoto 常把 VS 的一个 `float3 o6` 拆成 PS 的 `float2 v6 : TEXCOORD5` + `float w6 : TEXCOORD6`。这个拆分要留着。
- 删路径之后，没用到的参数（`SV_Position`、多余 TEXCOORD）仍可能要留着才能对上签名。

## `#define cmp -`

3Dmigoto 把比较写成 `cmp(expr)`，语义是 **真 → -1，假 → 0**（DXBC 风格）。

```hlsl
// 坏 — 类型炸掉 / 一堆警告
#define cmp -

// 好
float  cmp(bool  v) { return v ? -1.0 : 0.0; }
float2 cmp(bool2 v) { return v ? -1.0.xx : 0.0.xx; }
float3 cmp(bool3 v) { return v ? -1.0.xxx : 0.0.xxx; }
float4 cmp(bool4 v) { return v ? -1.0.xxxx : 0.0.xxxx; }
```

常见写法：

```hlsl
r = cmp(a < b);
if (r != 0) discard;           // a < b 时 discard

keep = cmp(0 != flag) ? 0 : 1; // flag != 0 时把颜色掐掉
```

## 语义名

| dump | Apply Changes |
|------|-----------------|
| `SV_Position0` | `SV_Position` |
| `SV_Target0` | `SV_Target` |
| `SV_VertexID0` | `SV_VertexID` |
| `SV_InstanceID0` | `SV_InstanceID` |

## SampleGrad / 导数

DXBC 对 `texture2darray` 的 `sample_d` 可能带 3 分量 ddx/ddy。HLSL 的
`Texture2DArray::SampleGrad` 要的是 **float2** ddx/ddy：

```hlsl
// warning X3206: 隐式截断
t.SampleGrad(s, uvw, ddx3, ddy3);

// dump 常写成标量 — 不忠实于 DXBC
t.SampleGrad(s, uvw, r4.x, r2.x);

// 对：用紧挨着算出来的完整导数寄存器
t.SampleGrad(s, uvw, r4.xy, r2.xy);
```

## 位域（`ubfe`）和无类型读取

页表 / 打包的 R32 数据：

```hlsl
uint packed = asuint(tex.Load(int3(x, y, mip)).x);
uint a = (packed >> 14) & 1023u; // ubfe width=10, offset=14
uint b = packed & 15u;

// 或写成对齐 DXBC ubfe(width, offset, src) 的 helper：
uint ubfe(uint width, uint offset, uint src) { ... }
```

不要写 `(uint)floatReg` —— 那是 **数值转换**，不是 bitcast。

3Dmigoto 的 `t125[i].val[32/4]` 这类下标是 **byteOffset/4** —— 原样留着（或注释字节来源）；不要「简化」成错误下标。

## 忠实的数学 helper

```hlsl
// dump: exp2(k * log2(x))，且 x 已经 max(abs(x), eps)
float Pow2(float x, float k) { return exp2(k * log2(x)); }
```

只有在这个绘制上验证过结果相同，才改成 `pow(x,k)`。

`mad(a,b,c)` ↔ `a*b+c`。  
`a + t*(b-a)` ↔ `lerp(a,b,t)` 仅在恒等时。

## 脆弱块 — 函数体保持寄存器形态

抽 helper 时，下面这些：

- 虚拟贴图页表 + 图集 `SampleGrad`
- 体积光 / 3D 贴图三次 B 样条（很多 tap + 权重寄存器）

……把 **已 Apply 验证的 Step 1 寄存器路径** 拷进 helper。不要凭记忆重推三次权重；`mad` 顺序差一点画面就坏。

贴图/采样器可以在外围改名；数学行保持 dump 形状。

## 关掉 STEP 时的恒等（分析开关）

| 项的类型 | 错误的「关」 | 正确的「关」 |
|--------------|-------------|-------------|
| 乘法 mask | 不写说明就把到处留在峰值 1 | 「无衰减」才用 `1`；或继续算但不乘 —— 写清楚 |
| 加法项 `mix * exp2(k*log(f))` | `log=0` → 因子 `1` → **到处都是满 mix** | 因子 **`0`** |
| Fresnel / wrap | — | `1.0` |
| 不透明度 / discard | — | `opacity=1`，跳过 discard |
| 颜色阶段 | — | 白/灰，只看 alpha |
| VT 分支 | — | 退回非 VT 采样（例如 `t4`） |
| 体积光叠加 | — | `transmittance=1`，`volumeRgb=0` |

选了哪种恒等，写在 `#define STEP…` 旁边。

## 建议的可读结构

```hlsl
// 1. 资源 + register
// 2. cmp / ubfe / 数学 helper
// 3. main 开头的 CB 别名（或从 cb 数组 LoadMaterial）
// 4. 分阶段函数（Eval*）— 脆弱块 = 寄存器函数体
// 5. main：STEP 开关 → 配方 → DEBUG_VIS 输出
// 6. （Step 6 文件）没有 rN；函数体只用语义名
```

## Step 6 — 人类可读命名

Step 4/5 之后的可选精简文件：

1. 消掉 `r0`/`r1`… —— `viewDir`、`N`、`ramp`、`litDirect`、`rimTerm`…
2. 每个用到的 `cbN[i].*` 在 `main` 开头别名一次；函数体不再写裸下标。
3. 保住 `float4 cbN[]` + `register(tN/sN/bN)`；不要重摆打包。
4. **不要** 把 `v0..vN` 插值器整份 shader `const` 拷走（会弄坏 rim）。
5. 用户给了行数预算，只砍对方点名的路径；标明配方忠实。
6. helper 吃具名参数 —— 别名之后 `Eval*` 里不要再写 `cb0[…]`。

别名块示例：

```hlsl
float3 sunDir         = cb0[6].xyz;
float3 cameraPos      = cb0[44].xyz;
float  exposure       = cb0[109].x;
float3 rimColor       = cb0[194].xyz;
float  rimIntensity   = cb0[194].w;
float  albedoLitScale = cb0[186].z;
float  envIblScale    = cb0[186].w;
float  normalStrength = cb5[0].w;
float  brdfLutBlend   = cb5[1].x;
```

用 `DEBUG_VIS` 看边缘 fresnel 时：在 rim 计算现场保存 `1-|N·V|`，别等雾/后续通路复用同一个寄存器。

## 会话核对清单

- [ ] 处理的是 **这次贴的 dump**，不是旧 readable
- [ ] Step 1 只做：cmp / SV_* / asuint+ubfe / SampleGrad `.xy`
- [ ] 用户 Apply + 画面一致之后，才做 Step 4/5/6
- [ ] 能编过；X3206 已消或已知原因
- [ ] 签名仍对得上 VS（`float2`+`float` 的 TEXCOORD 拆分还在）
- [ ] 没点名就不删路径
- [ ] 关掉 STEP 不会爆白；DEBUG_VIS 是合成前的量
- [ ] 密集体积/VT helper 仍对得上 Step 1 数学
- [ ] 若做了 Step 6：没有 rN 乱炖；CB 已起名；插值器没有整份 const 拷贝
