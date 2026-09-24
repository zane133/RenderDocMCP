# docs/

| 路径 | 内容 |
|------|------|
| [BG3_染色区域逆向说明_美术会议版.md](BG3_染色区域逆向说明_美术会议版.md) | BG3 `MSKcloth` / 染色槽，面向美术 |
| [BG3_Blender_SP_染色资产制作流程.md](BG3_Blender_SP_染色资产制作流程.md) | 染色资产制作流程 |
| `analyses/` | 着色器与渲染流程笔记 |
| `proposals/` | RenderDoc MCP 改进提案（中英各一份） |
| `assets/` | 文档配图 |

## analyses/

| 文件 | 对应 shader |
|------|-------------|
| `grass_vs_analysis.md` | `shaders/archive/grass_foliage/` |
| `wind_grass_vs_analysis.md` | `shaders/archive/gots_wind_grass/` |
| `hair_rendering_mobile_analysis.md` | 移动端头发渲染调研 |
| `render_flow.md` | 整帧渲染流程 |

Shader 可读化流程本身在 [../renderdoc-decompiled-shader-readable/README.md](../renderdoc-decompiled-shader-readable/README.md)。

两套 MCP（本仓库要开 RenderDoc；JiaboLi 只要 `.rdc`）见仓库根 [../README.md](../README.md)「两个 MCP 怎么选」。
