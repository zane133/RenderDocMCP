# RenderDoc MCP 改进提案

## 背景

在 Unity 项目中分析 RenderDoc 捕获时，存在以下问题：

1. **UI 噪声问题**：从 Unity Editor 捕获时，会包含大量 `GUI.Repaint`、`UIR.DrawChain` 等 Editor UI 绘制，难以找到真正的游戏绘制（`Camera.Render` 之下）
2. **响应体积问题**：`get_draw_calls(include_children=true)` 的结果超过 70KB，挤占 LLM 上下文
3. **探索效率低**：要找使用特定着色器或纹理的 Draw Call，需要逐个检查全部 Draw Call

## 改进提案

### 1. 标记过滤（优先级：高）

仅获取某个标记之下的内容，或排除特定标记的功能。

```python
get_draw_calls(
    include_children=True,
    marker_filter="Camera.Render",  # 仅获取该标记之下
    exclude_markers=["GUI.Repaint", "UIR.DrawChain", "UGUI.Rendering"]
)
```

**用例**：
- 从 Unity Editor 捕获中只提取游戏绘制
- 只调查特定渲染路径（Shadows、PostProcess 等）

**预期效果**：
- 将响应体积压缩到原来的 10–20%
- 结果可直接放入 LLM 可解析的大小

---

### 2. event_id 范围指定（优先级：高）

仅获取指定 event_id 范围的功能。

```python
get_draw_calls(
    event_id_min=7372,
    event_id_max=7600,
    include_children=True
)
```

**用例**：
- 已知 `Camera.Render` 的 event_id 时，只取该范围附近
- 对有问题的 Draw Call 周边做详细调查

**预期效果**：
- 只快速获取需要的部分
- 支持分阶段探索

---

### 3. 按着色器 / 纹理 / 资源反向查找（优先级：中）

查找使用特定资源的 Draw Call。

```python
# 按着色器名搜索（部分匹配）
find_draws_by_shader(shader_name="Toon")

# 按纹理名搜索（部分匹配）
find_draws_by_texture(texture_name="CharacterSkin")

# 按资源 ID 搜索（完全匹配）
find_draws_by_resource(resource_id="ResourceId::12345")
```

**返回值示例**：
```json
{
  "matches": [
    {"event_id": 7538, "name": "DrawIndexed", "match_reason": "pixel_shader contains 'Toon'"},
    {"event_id": 7620, "name": "DrawIndexed", "match_reason": "pixel_shader contains 'Toon'"}
  ],
  "total_matches": 2
}
```

**用例**：
- 直接回答「哪些 Draw 用了这个着色器？」这类最常见问题
- 追踪某纹理在何处被使用
- 确定着色器 bug 的影响范围

---

### 4. 获取帧摘要（优先级：中）

获取整帧概览的功能。

```python
get_frame_summary()
```

**返回值示例**：
```json
{
  "api": "D3D11",
  "total_events": 7763,
  "statistics": {
    "draw_calls": 64,
    "dispatches": 193,
    "clears": 5,
    "copies": 8
  },
  "top_level_markers": [
    {"name": "WaitForRenderJobs", "event_id": 118},
    {"name": "CustomRenderTextures.Update", "event_id": 6451},
    {"name": "Camera.Render", "event_id": 7372},
    {"name": "UIR.DrawChain", "event_id": 6484}
  ],
  "render_targets": [
    {"resource_id": "ResourceId::22573", "name": "MainRT", "resolution": "1920x1080"},
    {"resource_id": "ResourceId::22585", "name": "ShadowMap", "resolution": "2048x2048"}
  ],
  "unique_shaders": {
    "vertex": 12,
    "pixel": 15,
    "compute": 8
  }
}
```

**用例**：
- 作为探索起点把握整体结构
- 判断应深入哪个标记之下
- 把握性能概览

---

### 5. 仅获取 Draw Call 模式（优先级：中）

排除标记（PushMarker/PopMarker），只获取实际绘制调用。

```python
get_draw_calls(
    only_actions=True,  # 排除标记
    flags_filter=["Drawcall", "Dispatch"]  # 仅保留带特定标志的项
)
```

**用例**：
- 只要 Draw Call 总数与列表
- 只调查 Compute Shader（Dispatch）

---

### 6. 批量获取管线状态（优先级：低）

一次获取多个 event_id 的管线状态。

```python
get_multiple_pipeline_states(event_ids=[7538, 7558, 7450, 7458])
```

**返回值示例**：
```json
{
  "states": {
    "7538": { /* pipeline state */ },
    "7558": { /* pipeline state */ },
    "7450": { /* pipeline state */ },
    "7458": { /* pipeline state */ }
  }
}
```

**用例**：
- 对比多个 Draw Call
- 差分调查（正常 Draw 与异常 Draw 对比）

---

## 优先级汇总

| 优先级 | 功能 | 实现难度 | 效果 |
|--------|------|----------|------|
| **高** | 标记过滤 | 中 | 去除 UI 噪声，改善显著 |
| **高** | event_id 范围指定 | 低 | 局部获取，加速查询 |
| **中** | 着色器/纹理反向查找 | 高 | 直接支撑最常见用例 |
| **中** | 帧摘要 | 中 | 作为探索起点很有用 |
| **中** | 仅获取 Draw Call | 低 | 简单过滤 |
| **低** | 批量获取 | 低 | 提高效率，但非必需 |

## Unity 专用过滤预设（可选）

提供 Unity 专用预设会更方便：

```python
get_draw_calls(
    preset="unity_game_rendering"
)
```

**预设内容**：
- `marker_filter`: "Camera.Render"
- `exclude_markers`: ["GUI.Repaint", "UIR.DrawChain", "GUITexture.Draw", "UGUI.Rendering.RenderOverlays", "PlayerEndOfFrame", "EditorLoop"]

---

## 实现参考：当前工作流的问题

### 现状流程

```
1. get_draw_calls(include_children=true)
   → 返回 76KB JSON（会保存到文件）

2. 用外部工具（Python 等）解析文件
   → 确定 Camera.Render 的 event_id（例如：7372）

3. 手动指定 event_id 范围再做详细调查
   → get_pipeline_state(7538), get_shader_info(7538, "pixel"), ...
```

### 改进后的理想流程

```
1. get_frame_summary()
   → 可知 Camera.Render 在 event_id: 7372

2. get_draw_calls(marker_filter="Camera.Render", exclude_markers=[...])
   → 只获取需要的 Draw Call（数 KB）

3. find_draws_by_shader(shader_name="MyShader")
   → 直接返回对应 event_id

4. 用 get_pipeline_state(event_id) 查看详情
```

---

## 补充：应跳过的 Unity 标记一览

从 Unity Editor 捕获时应排除的标记：

| 标记名 | 说明 |
|--------|------|
| `GUI.Repaint` | IMGUI 绘制 |
| `UIR.DrawChain` | UI Toolkit 绘制 |
| `GUITexture.Draw` | GUI 纹理绘制 |
| `UGUI.Rendering.RenderOverlays` | uGUI 叠加层 |
| `PlayerEndOfFrame` | 帧结束处理 |
| `EditorLoop` | 编辑器循环处理 |

相对地，重要标记：

| 标记名 | 说明 |
|--------|------|
| `Camera.Render` | 主相机绘制起点 |
| `Drawing` | 绘制阶段 |
| `Render.OpaqueGeometry` | 不透明物体绘制 |
| `Render.TransparentGeometry` | 半透明物体绘制 |
| `RenderForward.RenderLoopJob` | 前向渲染的 Draw Call 群 |
| `Camera.RenderSkybox` | 天空盒绘制 |
| `Camera.ImageEffects` | 后处理 |
| `Shadows.RenderShadowMap` | 阴影贴图生成 |
