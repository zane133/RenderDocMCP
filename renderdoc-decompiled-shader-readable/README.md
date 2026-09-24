# renderdoc-decompiled-shader-readable

把 **3Dmigoto / RenderDoc 反编译 HLSL** 做成三件事同时成立的文件：

1. 人能读
2. 数学上尽量忠实于 dump
3. 能在 RenderDoc **Apply Changes** 里编过、画面能对上

本目录是 skill 的**仓库源**。Cursor / Claude Code / Codex 要真正自动走这套流程，需要再装到对应产品的 `skills/` 目录。

完整规则给 Agent 读：[SKILL.md](SKILL.md)。编译坑、语义、bit 操作：[reference.md](reference.md)。Step 1 半自动补丁：[scripts/patch_3dmigoto_for_renderdoc.py](scripts/patch_3dmigoto_for_renderdoc.py)。

## 安装（推荐 junction，不要再拷一份）

拷贝会和仓库脱节。Windows 下用目录联接（junction）指向本仓库这份源：

```powershell
# 仓库根目录执行
python renderdoc-decompiled-shader-readable/scripts/install_skill.py
```

默认会链到当前用户下已存在的技能目录：

| 产品 | 目标 |
|------|------|
| Cursor | `%USERPROFILE%\.cursor\skills\renderdoc-decompiled-shader-readable` |
| Claude Code | `%USERPROFILE%\.claude\skills\renderdoc-decompiled-shader-readable` |
| Codex | `%USERPROFILE%\.codex\skills\renderdoc-decompiled-shader-readable` |
| 本仓库 Agent | `.agents/skills/renderdoc-decompiled-shader-readable` |

常用参数：

```powershell
python renderdoc-decompiled-shader-readable/scripts/install_skill.py --list
python renderdoc-decompiled-shader-readable/scripts/install_skill.py --only cursor
python renderdoc-decompiled-shader-readable/scripts/install_skill.py --replace
```

`--replace`：目标已是普通拷贝时，先改名为 `*.bak-<时间>` 再接 junction。

手动安装（PowerShell）：

```powershell
$src  = "F:\13_MCP_AI\RenderDocMCP\renderdoc-decompiled-shader-readable"
$dest = "$env:USERPROFILE\.cursor\skills\renderdoc-decompiled-shader-readable"
New-Item -ItemType Junction -Path $dest -Target $src
```

装完后**新开一轮 Agent 会话**，技能列表里应出现 `renderdoc-decompiled-shader-readable`。

## 你怎么用（和 Agent 说什么）

1. 把 3Dmigoto dump 贴进对话，或指到仓库里的 `*_paste_dump.hlsl`。
2. 说「按 skill 做 Step 1」。Agent 应只做 `cmp` / `SV_*` / `SampleGrad` / `asuint`+`ubfe` 等最小补丁，**停下来**让你 Apply Changes。
3. 画面和原 draw 对得上之后回 `没问题` / `继续`。不要跳过这一步。
4. `继续` 一次只走一步：可读化（Step 4）→ `STEP_*` / `DEBUG_VIS`（Step 5）→ 语义化 TA 稿（Step 6）。
5. 需要砍体积光 / VT / 雾等路径时，明确说要删哪条（Step 3）。没点名不要删。

本仓库约定文件名（`shaders/`）：

| 后缀 | 步骤 |
|------|------|
| `*_paste_dump.hlsl` | 原始 dump |
| `*_step1_renderdoc.hlsl` | Apply 用最小补丁，寄存器忠实 |
| `*_step4_readable.hlsl` | 分段 / 别名 / helper，运算不变 |
| `*_step5_analysis.hlsl` | 开关拆阶段 |
| `*_readable.hlsl` | Step 6 TA 可读稿（可能砍了支路，标 recipe-faithful） |

## Agent 不要做的事

- Apply 还没对上就上 `LoadMaterial` / `Eval*` / `STEP_*`
- 拿上一份脸/草/手 SSS 的 readable 去覆盖新 dump
- 把 `exp2(k*log2(x))` 改成 `pow`，或编一个 dump 里没有的 `lerp`
- 关掉 falloff 时把 `log` 置 0（`exp2(0)=1` 会爆白）；应让该项贡献为 0

## 和 RenderDoc MCP 的关系

环境里可能有两套 MCP，别用错：

| | 本仓库 UI 桥接 | [JiaboLi/renderdoc-mcp](https://github.com/JiaboLi-GitHub/renderdoc-mcp) | 本 skill |
|--|----------------|------------------------------------------------------------------------|----------|
| 干什么 | 读 **已打开的** RenderDoc 窗口：draw、管线、贴图 | 直接 `open_capture(rdc 路径)`，不用开 UI | 把反编译 HLSL 改成能 Apply 的可读文件 |
| 前置 | RenderDoc 已开 + MCP Bridge 扩展 | 只要 `.rdc` | Apply 验证时要开 RenderDoc |

看帧结构、像素调试：JiaboLi。对着当前 Draw 贴 shader、Apply、对比画面：本仓库桥接 + 本 skill。


## 补丁脚本（可单独跑）

```powershell
python renderdoc-decompiled-shader-readable/scripts/patch_3dmigoto_for_renderdoc.py `
  shaders\foo_paste_dump.hlsl -o shaders\foo_step1_renderdoc.hlsl
```

脚本**只**处理 `#define cmp -` 和 `SV_*0`。`ubfe` / `SampleGrad` / `asuint` 仍要手改，见 [reference.md](reference.md)。
