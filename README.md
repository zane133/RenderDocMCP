# RenderDoc MCP 服务器

本仓库是 **RenderDoc UI 桥接版** MCP：必须先打开 RenderDoc、启用扩展，AI 才能读当前捕获。

日常「给一个 `.rdc` 就分析」请用另一套：[JiaboLi/renderdoc-mcp](https://github.com/JiaboLi-GitHub/renderdoc-mcp)（自带 `renderdoc.dll`，不用开 UI）。

- [两个 MCP 怎么选](#两个-mcp-怎么选)
- [安装本仓库 MCP](#安装本仓库-mcp)
- [Shader 可读化 Skill](renderdoc-decompiled-shader-readable/README.md)（Apply Changes 流程）
- [仓库结构](#仓库结构)

## 两个 MCP 怎么选

| | 本仓库（UI 桥接） | [JiaboLi/renderdoc-mcp](https://github.com/JiaboLi-GitHub/renderdoc-mcp) |
|--|------------------|------------------------------------------------------------------------|
| 前置条件 | **先打开 RenderDoc**，Tools → Manage Extensions 启用 **RenderDoc MCP Bridge** | 只要 `.rdc` 路径；**不用**开 RenderDoc 窗口 |
| 怎么连 | Python MCP ↔ 正在跑的 qRenderDoc。实际走 `%TEMP%/renderdoc_mcp/` 文件 IPC；配置里仍留着 `127.0.0.1:19876`（兼容字段，扩展没起来会报连不上这个地址） | stdio 调 `renderdoc-mcp.exe`，进程内 Replay |
| 给 Agent 什么 | 「RenderDoc 已经打开这份捕获，去读 draw / shader / 贴图」 | 「分析 `D:\captures\foo.rdc`」 |
| 适合 | 对着 UI 改 shader、**Apply Changes**、导出当前 draw 的网格/贴图进 Blender | 离线读帧、像素调试、pass 依赖、两帧 diff、CI |
| Cursor 里常见名字 | 本仓库的 `renderdoc-mcp` Python 命令（若已 `uv tool install`） | `renderdoc` / `user-renderdoc`，指向 `...\renderdoc-mcp.exe` |

**本仓库日常怎么用**

1. 启动 RenderDoc，打开 `.rdc`（或让游戏抓一帧）。
2. 确认扩展已启用；没启用时 MCP 会报连不上 `127.0.0.1:19876` / 找不到 IPC 目录。
3. 在 Cursor / Claude 里调本仓库的工具（`get_draw_calls`、`get_shader_info` 等）。

**JiaboLi 那套怎么用**

1. 从 [Releases](https://github.com/JiaboLi-GitHub/renderdoc-mcp/releases) 装好 `renderdoc-mcp.exe`。
2. 对话里给出 `.rdc` 绝对路径，让 Agent 调 `open_capture`。
3. 改 shader 并在 UI 里 Apply 仍要回到本仓库流程 + [shader skill](renderdoc-decompiled-shader-readable/README.md)。

两套可以同时装着。看捕获结构用 JiaboLi；要对着当前 Draw 贴 HLSL、Apply、对比画面，用本仓库。

## 架构

```
Claude / AI 客户端 (stdio)
        │
        ▼
MCP 服务器进程 (Python + FastMCP 2.0)
        │ 基于文件的 IPC（%TEMP%/renderdoc_mcp/）
        ▼
RenderDoc 进程（扩展）
```

RenderDoc 内置 Python 没有 `socket` 模块，所以用文件 IPC 通信。

## 安装本仓库 MCP

### 1. 安装 RenderDoc 扩展

```bash
python scripts/install_extension.py
```

扩展会装到 `%APPDATA%\qrenderdoc\extensions\renderdoc_mcp_bridge`。

### 2. 在 RenderDoc 里启用扩展

1. 启动 RenderDoc
2. Tools > Manage Extensions
3. 启用 **RenderDoc MCP Bridge**

### 3. 安装 MCP 服务器

```bash
uv tool install
uv tool update-shell  # 写入 PATH
```

重新打开终端后可以使用 `renderdoc-mcp` 命令。

> 开发时加 `--editable`，改源码立刻生效。发稳定版用 `uv tool install .`。

### 4. 配置 MCP 客户端

#### Claude Desktop

写入 `claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "renderdoc": {
      "command": "renderdoc-mcp"
    }
  }
}
```

#### Claude Code / Cursor

写入 `.mcp.json`：

```json
{
  "mcpServers": {
    "renderdoc": {
      "command": "renderdoc-mcp"
    }
  }
}
```

## 用法（本仓库）

1. **先启动 RenderDoc**，打开 `.rdc`，并启用 MCP Bridge 扩展
2. 再从 MCP 客户端读取当前捕获（扩展没起来就连不上）

## MCP 工具一览

| 工具 | 说明 |
|------|------|
| `list_captures` | 列出目录里的 `.rdc` |
| `open_capture` | 打开捕获（会关掉当前已打开的） |
| `get_capture_status` | 捕获是否已加载 |
| `get_draw_calls` | 绘制调用树（可过滤） |
| `get_frame_summary` | 整帧统计（绘制数、marker 等） |
| `find_draws_by_shader` | 按着色器名反查绘制 |
| `find_draws_by_texture` | 按贴图名反查绘制 |
| `find_draws_by_resource` | 按资源 ID 反查绘制 |
| `get_draw_call_details` | 单次绘制详情 |
| `get_action_timings` | GPU 耗时 |
| `get_shader_info` | 着色器源码 / 常量缓冲 |
| `get_buffer_contents` | 缓冲内容（Base64） |
| `get_texture_info` | 贴图元数据 |
| `get_texture_data` | 贴图像素（Base64） |
| `get_pipeline_state` | 整条管线状态 |

## 使用示例

### 绘制列表

```
get_draw_calls(include_children=true)
```

### 着色器信息

```
get_shader_info(event_id=123, stage="pixel")
```

### 管线状态

```
get_pipeline_state(event_id=123)
```

### 贴图数据

```
# 2D 贴图 mip 0
get_texture_data(resource_id="ResourceId::123")

# 指定 mip
get_texture_data(resource_id="ResourceId::123", mip=2)

# 立方体贴图某一面（0=X+, 1=X-, 2=Y+, 3=Y-, 4=Z+, 5=Z-）
get_texture_data(resource_id="ResourceId::456", slice=3)

# 3D 贴图某一深度切片
get_texture_data(resource_id="ResourceId::789", depth_slice=5)
```

### 缓冲局部读取

```
# 整个缓冲
get_buffer_contents(resource_id="ResourceId::123")

# 从偏移 256 起读 512 字节
get_buffer_contents(resource_id="ResourceId::123", offset=256, length=512)
```

## 仓库结构

```
RenderDocMCP/
├── mcp_server/                 # FastMCP 进程（stdio）
├── renderdoc_extension/        # RenderDoc 内的 IPC 扩展
├── scripts/                    # 扩展安装、capture 导出 / Blender
├── tests/
├── renderdoc-decompiled-shader-readable/  # 反编译 HLSL → 可读 + 可 Apply
│   └── README.md               # 安装到 Cursor / Claude / Codex
├── shaders/                    # dump / step1 / step4 / step5 / readable
│   └── archive/                # 旧草/风/手 SSS 实验稿
├── tools/                      # 一次性生成器
│   └── ue_custom_nodes/        # UE 材质 Custom Node 脚本
└── docs/                       # 美术流程
    ├── analyses/               # 着色器与渲染流程笔记
    └── proposals/              # MCP 改进提案
```

根目录只留配置和 README。每个子目录都有自己的 README 说明放什么。

反编译 shader 不要堆在仓库根目录。新 dump 放到 `shaders/`，文件名约定见 skill README。

### Shader skill 安装

```bash
python renderdoc-decompiled-shader-readable/scripts/install_skill.py
```

详见 [renderdoc-decompiled-shader-readable/README.md](renderdoc-decompiled-shader-readable/README.md)。

## 环境要求

- Python 3.10+
- [uv](https://docs.astral.sh/uv/)
- RenderDoc 1.20+

目前只在 **Windows + DirectX 11** 上验证过。Linux/macOS + Vulkan/OpenGL 可能也能跑，但未测。

## 许可证

MIT
