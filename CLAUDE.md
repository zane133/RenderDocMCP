# RenderDoc MCP 服务器

作为 **RenderDoc UI 扩展** 运行的 MCP 服务器。必须先打开 RenderDoc 并启用 MCP Bridge，AI 才能读**当前窗口里**的捕获。

不要和 [JiaboLi/renderdoc-mcp](https://github.com/JiaboLi-GitHub/renderdoc-mcp) 搞混：那套自带 Replay，给 `.rdc` 路径即可，不用开 UI。怎么选用见仓库根 `README.md`「两个 MCP 怎么选」。

## 架构

**混合进程隔离**：

```
Claude / AI 客户端 (stdio)
        │
        ▼
MCP 服务器进程（标准 Python + FastMCP 2.0）
        │ 基于文件的 IPC（%TEMP%/renderdoc_mcp/）
        ▼
RenderDoc 进程（扩展 + 文件轮询）
```

## 项目结构

```
RenderDocMCP/
├── mcp_server/                 # MCP 服务器
│   ├── server.py               # FastMCP 入口
│   ├── config.py               # 配置
│   └── bridge/
│       └── client.py           # 文件 IPC 客户端
│
├── renderdoc_extension/        # RenderDoc 扩展
│   ├── __init__.py             # register() / unregister()
│   ├── extension.json          # 清单
│   ├── socket_server.py        # 文件 IPC 服务端
│   ├── request_handler.py      # 请求处理
│   └── renderdoc_facade.py     # RenderDoc API 封装
│
├── scripts/
│   └── install_extension.py    # 安装扩展
│
├── renderdoc-decompiled-shader-readable/  # 3Dmigoto dump → 可 Apply 的 HLSL
│   ├── SKILL.md
│   ├── reference.md
│   └── README.md               # 安装到 Cursor / Claude / Codex
│
├── shaders/                    # dump 与逐步可读化产物
├── tools/                      # 一次性脚本、UE Custom Node
└── docs/
```

反编译 shader 流程见 `renderdoc-decompiled-shader-readable/README.md`。用户新贴 dump 时走该 skill，不要用旧的 `*_readable.hlsl` 覆盖。

## MCP 工具

| 工具名 | 说明 |
|---------|------|
| `list_captures` | 列出指定目录下的 `.rdc` |
| `open_capture` | 打开捕获（会自动关掉当前捕获） |
| `get_capture_status` | 捕获是否已加载 |
| `get_draw_calls` | 绘制调用树（可过滤） |
| `get_frame_summary` | 整帧统计（绘制数、marker 等） |
| `find_draws_by_shader` | 按着色器名反查绘制 |
| `find_draws_by_texture` | 按贴图名反查绘制 |
| `find_draws_by_resource` | 按资源 ID 反查绘制 |
| `get_draw_call_details` | 单次绘制详情 |
| `get_action_timings` | 动作的 GPU 耗时 |
| `get_shader_info` | 着色器源码 / 常量缓冲 |
| `get_buffer_contents` | 缓冲数据（可指定偏移/长度） |
| `get_texture_info` | 贴图元数据 |
| `get_texture_data` | 贴图像素（mip / slice / 3D 切片） |
| `get_pipeline_state` | 整条管线状态 |

### `get_draw_calls` 过滤选项

```python
get_draw_calls(
    include_children=True,      # 包含子动作
    marker_filter="Camera.Render",  # 只取该 marker 之下
    exclude_markers=["GUI.Repaint", "UIR.DrawChain"],  # 排除这些 marker
    event_id_min=7372,          # event_id 下限
    event_id_max=7600,          # event_id 上限
    only_actions=True,          # 去掉 marker，只要绘制
    flags_filter=["Drawcall", "Dispatch"],  # 只要这些标志
)
```

### 捕获管理

```python
# 列出目录里的捕获
list_captures(directory="D:\\captures")
# → {"count": 3, "captures": [{"filename": "game.rdc", "path": "...", "size_bytes": 12345, "modified_time": "..."}, ...]}

# 打开捕获（会关掉当前已打开的）
open_capture(capture_path="D:\\captures\\game.rdc")
# → {"success": true, "filename": "game.rdc", "api": "D3D11"}
```

### 反查

```python
# 着色器名（部分匹配）
find_draws_by_shader(shader_name="Toon", stage="pixel")

# 贴图名（部分匹配）
find_draws_by_texture(texture_name="CharacterSkin")

# 资源 ID（完全匹配）
find_draws_by_resource(resource_id="ResourceId::12345")
```

### GPU 耗时

```python
# 全部动作
get_action_timings()
# → {"available": true, "unit": "CounterUnit.Seconds", "timings": [...], "total_duration_ms": 12.5, "count": 150}

# 指定 event_id
get_action_timings(event_ids=[100, 200, 300])

# 按 marker 过滤
get_action_timings(marker_filter="Camera.Render", exclude_markers=["GUI.Repaint"])
```

**注意**：部分硬件/驱动没有 GPU 计时计数器。返回 `available: false` 时，这份捕获拿不到耗时。

## 通信协议

文件 IPC：

- IPC 目录：`%TEMP%/renderdoc_mcp/`
- `request.json`：请求（MCP 服务器 → RenderDoc）
- `response.json`：响应（RenderDoc → MCP 服务器）
- `lock`：写入中的锁文件
- 轮询间隔：100ms（RenderDoc 侧）

## 开发备忘

- RenderDoc 内置 Python 没有 `socket` / `QtNetwork`，所以用文件 IPC
- 扩展只能用 Python 3.6 标准库
- 访问 `ReplayController` 必须走 `BlockInvoke`

## 参考链接

- [FastMCP](https://github.com/jlowin/fastmcp)
- [RenderDoc Python API](https://renderdoc.org/docs/python_api/index.html)
- [RenderDoc Extension Registration](https://renderdoc.org/docs/how/how_python_extension.html)
