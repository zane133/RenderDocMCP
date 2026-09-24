# shaders/archive/

从仓库根目录清出来的旧实验稿，不参与当前 ZMD 流程。命名保持搬迁前的样子，方便对回老文档。

## gots_wind_grass/

《对马岛之魂》风草，VS 是 `vs_SetMaterial_techMoving`。分析见 [../../docs/analyses/wind_grass_vs_analysis.md](../../docs/analyses/wind_grass_vs_analysis.md)。

| 文件 | 内容 |
|------|------|
| `wind_grass_vs_dump.hlsl` | VS 原始反编译（SPIRV-Cross 风格） |
| `gots_grass_vs_step1_renderdoc.hlsl` | VS 最小补丁 |
| `gots_grass_vs_step4_readable.hlsl` | VS 可读化 |
| `gots_grass_vs_step5_analysis.hlsl` | VS 分析开关版 |
| `ghost_of_tsushima_grass_vs_readable.hlsl` | 早期可读稿 |
| `wind_grass_ps_dump.hlsl` / `..._renderdoc.hlsl` | 配套 PS 与补丁版 |
| `ghost_grass_wind_reference.hlsl` | 风场研究稿，**不能**直接 Apply |

搬迁时 `pasted_shader_step{1,4,5}_*.hlsl` 改成了 `gots_grass_vs_step*`，内容未动。

## grass_foliage/

另一份 GPU Driven 草地 VS（3Dmigoto v1.4.6，2026-07-06）。分析见 [../../docs/analyses/grass_vs_analysis.md](../../docs/analyses/grass_vs_analysis.md)。

| 文件 | 内容 |
|------|------|
| `grass_vs_paste_dump.hlsl` | 原始反编译（原名 `新建 Text Document.txt`） |
| `grass_vs_readable.hlsl` | 逐行注释，数学与原版一致 |
| `grass_vs_readable_refactor.hlsl` | 重构版（原名 `grass_vs_readable copy.hlsl`） |

## hand_sss/

`hand_sss_ps_readable.hlsl`：手部 SSS PS 精简稿，已删掉 fresnel / 厚度 / 不透明度 / 校色 / kill。
