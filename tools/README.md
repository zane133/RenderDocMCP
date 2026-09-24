# tools/

一次性脚本，**不是** MCP 服务器的一部分。

| 路径 | 用途 |
|------|------|
| `ue_custom_nodes/` | 在 UE 材质里创建 Custom Node，读取 `shaders/ue_custom_*.hlsl` |
| `make_step*.py` / `verify_step*.py` | 某次 dump 的可读化生成器，按时间戳命名，可删可留 |

## ue_custom_nodes/

在 UE 编辑器的 Python 控制台里跑。脚本顶部先改 `MATERIAL_PATH`。

| 脚本 | 目标 |
|------|------|
| `CreateBG3DyeCustomNode.py` | BG3 染色（读 `shaders/ue_custom_bg3_dye_tint.hlsl`） |
| `CreateZMDFaceSDFCustomNode.py` | 脸部 SDF 遮罩（读 `shaders/ue_custom_zmd_face_sdf_masks.hlsl`） |
| `CreateHandSSSCustomNode.py` | 手部 SSS noise 可视化（HLSL 内联） |
| `CreateParamByCustomNode.py` | 边缘光 / 脉冲参数示例（HLSL 内联） |

路径靠 `REPO_ROOT = Path(__file__).resolve().parents[2]` 回到仓库根，所以别把脚本单独拷到别处跑。

## make_step*.py

新 dump 优先走 skill + `patch_3dmigoto_for_renderdoc.py`，不要为每个时间戳再加一个 `make_step*`，除非文件太大、手工替换容易漏。
