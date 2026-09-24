# scripts/

| 脚本 | 用途 |
|------|------|
| `install_extension.py` | 把 `renderdoc_extension/` 装进 RenderDoc |
| `export_*.py` / `import_scene_to_blend.py` / `attach_materials*.py` | 从 capture 导出网格/贴图并进 Blender |
| `fix_3dmigoto_vs_for_renderdoc.py` | VS dump 的旧补丁；PS 请用 skill 里的 `patch_3dmigoto_for_renderdoc.py` |
| `verify_draw_coverage.py` / `render_scene_check.py` | 导出覆盖检查 |

Shader skill 安装：`../renderdoc-decompiled-shader-readable/scripts/install_skill.py`。
