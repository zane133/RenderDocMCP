# shaders/

3Dmigoto dump 与 RenderDoc Apply 用的 HLSL。工作流见 [../renderdoc-decompiled-shader-readable/README.md](../renderdoc-decompiled-shader-readable/README.md)。

## 命名

`{项目}_{变体}_ps_{YYYYMMDD}_{HHMMSS}_{阶段}.hlsl`

| 阶段 | 含义 |
|------|------|
| `paste_dump` | 原始 dump，不要改这份 |
| `step1_renderdoc` | 最小补丁，Apply 验证用 |
| `step4_readable` | 可读但运算不变 |
| `step5_analysis` | `STEP_*` / `DEBUG_VIS` |
| `readable` | TA 语义稿 |

更早的实验文件用 `eid_{事件号}_...` 或 `ue_custom_...`。

## 当前工作集（ZMD）

| 前缀 | 大致内容 |
|------|----------|
| `zmd_ps_20260922_094301_*` | 脸/身体主 PS |
| `zmd_ps_20260922_140315_*` | 同族后续 dump |
| `zmd_ps_20260922_145935_*` | 同族后续 dump |
| `zmd_ps_20260924_091647_*` | 同族后续 dump |
| `zmd_hair_ps_20260922_171627_*` | 头发 |
| `zmd_eye_ps_20260924_141546_*` | 眼睛 |
| `zmd_post_ps_20260924_101931_*` | 后处理 |
| `eid_1148_zmd_face_*` | 脸 SDF |
| `eid_7918_ps_*` | BG3 染色 |
| `ue_custom_*` | 给 UE Custom Node 贴的精简 HLSL |

## archive/

根目录清出来的旧稿，按主题分 `gots_wind_grass/`、`grass_foliage/`、`hand_sss/`，不参与当前 ZMD 流程。见 [archive/README.md](archive/README.md)。
