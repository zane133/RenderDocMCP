# BG3 风格染色资产：Blender → Substance 3D Painter → 现有材质

> 目标：从自己制作的衣服／裤子模型出发，得到可供现有 12 槽染色材质使用的 ID 图，并在 SP 制作表面材质。
> 日期：2026-09-04。
> 流程约定：美术在高模阶段决定染色分区；制作低模并展开 UV 后，将高模分区烘焙到低模贴图。
> 本文是制作方案，不是已完成的烘焙记录。本次无法连接 Blender，尚未修改场景、生成模型贴图或执行 SP 操作。

## 1. 先把三种东西分开

- **模型**：决定裤腿、腰带、扣子在哪里。
- **染色 ID 图（MSKcloth）**：决定每个像素跟随哪个染色槽；不是最终颜色，也不是金属度。
- **SP 输出的表面贴图**：决定布纹、皮革颗粒、磨损、粗糙度、金属度及基础色细节。

推荐第一版流程：

```text
Blender 高模：美术指定染色区域，赋予有语义的 ID 材质
  → 重拓扑／减面得到低模，展开低模 UV
  → 分别导出高模和使用正式材质槽的低模
  → SP 以低模建项目，以高模为烘焙源
  → 烘焙高模分区到低模 UV，得到 ID 图
  → 验证／转换固定编码，得到运行时 MSKcloth
  → 依据 ID 建立材质文件夹和遮罩
  → 绘制并导出 BaseColor / Normal / Roughness / Metallic / AO
  → 原始 MSKcloth + SP 表面贴图一起接回现有材质
```

分区由美术设计。软件可以把“已分好区的面／材质／顶点属性”变成图，但不能从模型外形可靠地推断你的染色意图。

这里有两个不同步骤：**高模转低模是拓扑制作；高模信息转为低模贴图是烘焙。** 重拓扑本身不会自动生成 ID 图，SP 烘焙也不会替你决定分区或生成正式低模。

## 2. 第一件测试资产：四个区域即可

先用一条裤子或简单替代模型跑通，不必一次用满 12 槽：

- 裤腿主体 → `Cloth_Primary` → 原始 RGB 数值 `(1, 0.5, 0)`。
- 裤脚／侧边拼接 → `Cloth_Secondary` → `(1, 0, 0)`。
- 腰带 → `Leather_Primary` → `(0.5, 0, 1)`。
- 腰带扣 → `Metal_Primary` → `(0, 1, 0.5)`。

这只是新资产的制作示例，不是断言 EID 7918 原模型的具体几何分区。

不同部件可以使用同一个 ID：两条裤腿若始终同色，就都用 Cloth_Primary。
反过来，同一种布料也可以分两个 ID，实现主体和拼接独立换色。
因此 **“一种物理材质”不等于“一个染色 ID”**。

## 3. Blender：高模分区，低模承接

### 3.1 美术在高模上指定分区

保留原始高模和正式材质，另存烘焙用版本。给高模区域分配独立的语义材质：

```text
裤腿主体 → ID_Cloth_Primary
拼接布   → ID_Cloth_Secondary
腰带     → ID_Leather_Primary
金属扣   → ID_Metal_Primary
```

同一高模可以有多个材质槽，也可以由多个部件组成。按面 Assign 或给整个部件分配材质均可；材质名负责记录语义，导出的材质颜色负责给 SP 烘焙器提供分区数据。

初版优先使用能经 FBX 导出的简单材质颜色，并记录“材质名 → 染色槽 → 目标 RGB”。**SP 不会因为材质叫 Cloth_Primary 就自动知道 BG3 编码，也不会执行 Blender 的任意节点网络。** 实际颜色传输要先做四区小样验证。

纯材质色／顶点色分区的高模通常不需要 UV；低模必须有 UV。若使用高模纹理作为颜色来源，则属于另一种需要高模 UV 和相应烘焙支持的流程。

### 3.2 美术制作低模、展开 UV

1. 根据轮廓、关节变形和预算重拓扑，或在适合的部件上减面。不要把机械减面当成角色变形拓扑的完整替代。
2. 高低模保持空间对齐；它们不要求面数、顶点数、UV 相同。
3. 低模使用正式 UV，初版单张 0–1、2K，UV 岛之间预留扩边空间。不同分区不能重叠使用同一块 UV。
4. 固定最终三角化／法线策略，使 SP 和引擎使用同一份低模约定。
5. 低模按渲染需求分配材质槽。四区练习只使用一个 `M_Pants`，不要求复制高模的四个 ID 槽。

**低模不必沿每条染色边界加线，也不必重新手工分一次 ID。** 烘焙会把高模分区投射成低模 UV 上的像素边界；只有影响轮廓、变形或其他几何要求的边界才需要对应拓扑。

现有 PS 使用 `input.materialUV.xy` 读取 ID，烘焙时使用的低模 UV 必须与它一致。

### 3.3 分别导出高模和低模

```text
Pants_High.fbx：含分区材质颜色的高模，作为烘焙源。
Pants_Low.fbx ：含最终 UV 和正式材质槽的低模，作为 SP 项目模型。
```

对于贴得很近的部件，命名成对应组，例如 `pants_low / pants_high`、`belt_low / belt_high`、`buckle_low / buckle_high`，后续使用 By Mesh Name 限制烘焙命中范围。名字匹配的是网格对象，不是 Cloth/Leather 染色槽；导出后检查实际匹配结果。[Adobe 名称匹配说明](https://experienceleague.adobe.com/en/docs/substance-3d/bakers/features/matching-by-name)

## 4. SP：把高模分区烘焙到低模 UV

### 4.1 以低模建立项目

1. 用 `Pants_Low.fbx` 新建 PBR 项目，不用高模建立正式绘制项目。
2. 使用现有 UV，不自动重新展开。
3. 确认只有预期的 Texture Set。它们由项目低模的材质划分产生，不是由烘焙源高模的 ID 材质数量决定。因此高模可以有多个 ID 材质，而低模仍使用一套贴图。[Adobe Texture Set 文档](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/interface/texture-set/texture-set)

### 4.2 Bake Mesh Maps

1. 在 High Definition Meshes 中加载 `Pants_High.fbx`，关闭 Use Low Poly Mesh as High Poly Mesh。
2. 初版选择 ID、Normal、AO 等必要贴图，从低分辨率小样开始；通过后再提升到正式分辨率。
3. ID 的 **Color Source 选择 Material Color**。它读取高模面所分配的材质色。若高模实际采用顶点色分区，才选择 Vertex Color；顶点色会插值，硬边分区应特别检查过渡。[Adobe ID 烘焙颜色来源](https://experienceleague.adobe.com/en/docs/substance-3d/bakers/bakers-settings/color-map-from-mesh)
4. 不使用 Mesh ID／Polygroup 的 Random 颜色生成来假定得到 BG3 固定编码；那类颜色可用于 SP 临时选区，但需要明确转换才能成为运行时 ID。
5. 对近邻部件使用 By Mesh Name，并检查匹配列表。调整 cage 或前后射线距离，避免裤腿命中腰带、内外层互相穿透。自定义 cage 要对应低模，不是高模。
6. 设置足够的 Dilation／扩边，UV 岛间距也要容纳它；烘焙后检查边界、漏射和小部件，不仅看日志是否报错。[Adobe 高低模与 cage 设置](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/baking/mesh-map-settings)

直观理解：**每个低模贴图像素找到对应低模表面位置，沿烘焙射线找到高模，再把那里所属区域的颜色写回来。** ID 图由此生成，不是从最终 Base Color 猜出来。

烘焙通过后，ID 会作为当前 Texture Set 的 Mesh Map 使用。如果后续只重烘其他贴图，取消 ID，避免无意覆盖已确认的分区。

### 4.3 用 ID 给材质文件夹建立遮罩

建议按染色语义组织文件夹，而不只是取名“红色、蓝色”：

```text
M_Pants / 一个 Texture Set
  Cloth_Primary      [ID Color Selection 遮罩]
    布料底层
    织纹 / 粗糙度变化 / 缝线 / 局部磨损
  Cloth_Secondary    [ID Color Selection 遮罩]
    拼接布底层与细节
  Leather_Primary    [ID Color Selection 遮罩]
    皮革底层 / 颗粒 / 折痕
  Metal_Primary      [ID Color Selection 遮罩]
    金属底层 / 划痕 / 氧化
```

常用操作：给文件夹添加黑色遮罩，再添加 **Color Selection** 效果，使用 Pick Color 选择对应 ID 区域。遮罩内部再叠加 Fill Layer、Smart Material 或手绘层。

取样区域内部，检查相邻 ID 有没有被阈值一起选进来；不要靠无限提高容差修补原图的错误。SP 的 ID 选色是制作选区，不等于我们 Shader 的 12 锚点距离权重公式。该类基于 ID 的 Color Selection 遮罩是 Painter 的既有工作方式。[Adobe ID 拖放与选色说明](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/release-notes/old-versions/version-2018-2)

一个 ID 内仍能继续细分多个表面材质。例如同属 Cloth_Primary 的织布和绣线，可以再用绘制遮罩区分粗糙度；只要它们应当一起换色，就不必新增染色 ID。

### 4.4 SP 的选区 ID 如何成为运行时 MSKcloth

先保留烘焙母版 `Pants_SourceID`。SP 能正确选区不代表最终导出的 RGB 就符合 Shader，必须另做数值验收。

第一轮把四个区域的 ID Mesh Map 单独输出为无损 RGB PNG，通过 Mesh Maps 输出配置或该版本提供的 Mesh Map 导出方式取得原始图；不要输出叠加了材质层的 Base Color，也不要截屏吸色。

检查区域内部原始字节：

- Cloth_Primary：约 `255, 128, 0`。
- Cloth_Secondary：`255, 0, 0`。
- Leather_Primary：约 `128, 0, 255`。
- Metal_Primary：约 `0, 255, 128`。

若数值正确，可以直接将这份输出作为 `Pants_MSKcloth.png`。若经过 FBX／色彩管理／输出转换后数值不符，则它只能先用于 SP 选区：修正颜色传输，或按已记录的语义区域遮罩重新编码为附录里的固定 RGB，再进入运行时。

Shader 的中间档是 `0.5`，8-bit 输出常用 `128/255 ≈ 0.50196`。`#FF8000` 在这里是数据字节速记；若 128 被按 sRGB 转成约 0.216，Shader 会读错槽。验收区域内部数值，并单独检查抗锯齿、过滤及 mip 的边界行为；不要盲目把所有边缘量化成最近 ID。

此色彩传输链尚未在当前 Blender／SP 版本实测，不把“导出必然保持数值”当作已验证结论。

## 5. SP 里画什么，不画什么

### Base Color

为可广泛换色的区域保留材质明暗、织物纹理和适量固有色，但不要把“最终红色染料”永久画死。否则现有材质再乘蓝色染料，容易变暗或变脏。

这不等于所有区域都必须纯白。可从偏中性的底色开始，分别用浅、深、高饱和染料验证，调整到艺术目标。

### 表面质感

Normal、Roughness、Metallic、AO 照常制作。布、皮、金属的区别主要在这些表面属性及基础反射颜色；把区域标成 Metal_Primary 不会自动生成金属度。

脏污、磨损、褪色先放在表面贴图／专用遮罩里，**不要通过随意模糊 ID 图制造**。是否让污渍参与换色应单独设计，当前染色查表节点不会自动知道哪些污渍应保持原色。

### ID 母版保持独立

保留高模分区烘焙得到的 `Pants_SourceID`，以及通过数值验收的运行时 `Pants_MSKcloth.png`；直接通过验收时二者可以是同一份图。SP 使用 ID 进行选区，但不通过 Base Color 导出它，也不让 Smart Material、颜色校正和污渍层修改它。

若后续要在 SP 精画绣花、徽章的染色区域，可以另建专用编码流程：用语义遮罩合成固定 ID，输出独立的数据通道／贴图。必须验证导出前后数值和边界，再替代现有母版。不要直接以随机 ID 烘焙结果替代 BG3 编码。

## 6. 从 SP 导出并接回现有材质

第一版先输出分离贴图，便于排错：

```text
Pants_BaseColor.png
Pants_Normal.png
Pants_Roughness.png
Pants_Metallic.png
Pants_AO.png
Pants_MSKcloth.png    ← 高模分区烘焙并通过编码验收的 ID，不是 SP beauty 输出
```

SP 的 Output Templates 可以定义输出贴图、位深与通道打包；确认材质消费规则后再配置打包，不能因为 BG3 叫 PM，就把通用 ORM 不加核对地接过去。[Adobe Export 文档](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/export/export)

本仓库的 `ue_custom_bg3_dye_tint.hlsl` 目前负责 **12 槽染色查表**，并不独自包含 EID 7918 的全部 PM / Detail / 覆盖层响应。按其接口接线：

```text
MSKcloth RGB → DyeIdRGB → 12 槽查表 → DyeTint
SP BaseColor × DyeTint → 材质 Base Color
SP Normal / Roughness / Metallic / AO → 对应表面输入
```

ID 按数据图导入：关闭 sRGB，采样器与纹理类型匹配；先在不产生有损变化的设置下验证，再评估最终压缩与 mip。普通 Base Color 使用项目约定的颜色空间。法线的 DirectX / OpenGL Y 方向按目标引擎确定，不能和 ID 的 Non-Color 问题混为一谈。

无需美术手工制作 Texture0 页表，也无需手动把 ID 塞进 BG3 巨型 VT 图集。当前 ID 是普通 2D 纹理；VT 页表与物理图集属于另一个资源组织问题。

## 7. 一次走通的验收清单

- [ ] Blender 高模的四个区域都有明确分配，无漏面；低模 UV 与正式导出一致。
- [ ] SP 高低模名称匹配、cage 与射线距离已检查，没有穿透和串部件。
- [ ] 烘焙 PNG 重读后，区域内部是约定的原始 RGB，尤其检查中间档。
- [ ] SP 里测试低模只有预期的一个 Texture Set。
- [ ] SP 的四个文件夹分别只影响正确区域。
- [ ] SP 和引擎使用同一份最终 UV／三角化／法线约定。
- [ ] 改 Cloth_Primary 只改变裤腿主体；其余三个槽依次验证。
- [ ] 检查近景边界、UV 接缝和远景 mip，没有黑边、串槽或脏色。
- [ ] 测试深色、浅色、高饱和染料；质感和分区都符合预期。
- [ ] 保留 `.blend`、`.spp`、高低模 FBX、源 ID、运行时 ID 与 SP 输出，方便改区和重导出。

特别注意：该查表函数没有对 12 个权重做归一化，也没有“未命中就保持原色”的回退。**黑／白 ID 不是不染色开关**；未命中可能让染色乘数为零。全白染料在精确锚点内部近似中性，但混合边缘不保证权重之和为 1。想做严格的不染色区或修改混合策略，需要另行设计材质规则。

## 附 A：需要在 Blender 烘焙时的备用路径

主线是 SP 高模 → 低模烘焙。若要在 Blender 输出可控数值的 ID，同样是**高模作源、低模作目标**，不能沿用同模型自烘焙的设置：

1. 在高模烘焙副本上，用 Combine Color 的数值输入连接 Emission（Strength = 1），每块区域输出固定 ID RGB。
2. 在低模目标材质上创建指向同一张 Non-Color 图片的活动 Image Texture 节点；目标节点不接回高模着色链。
3. 先选择高模源，最后选择低模，让低模成为活动对象。
4. Cycles 使用 Emit，并**开启 Selected to Active**；调整 cage／射线距离，使低模投射命中正确高模区域。
5. 设置扩边，保存无损 PNG 并关闭 Save As Render，重读数值验证。把通过验证的图导入 SP 的 Mesh Maps → ID；这条备用路径才需要在 SP 关闭 ID 重烘焙。

若 Normal 在 SP 烘焙、ID 在 Blender 烘焙，要额外核对两者投射边界是否一致；不同 cage／射线设置可能产生错位。因此第一轮优先在同一烘焙器内完成，再决定是否需要备用路径。[Blender Render Baking](https://docs.blender.org/UATEST/manual/en/4.5/render/cycles/baking.html)、[图像保存选项](https://docs.blender.org/UATEST/manual/en/4.5/files/media/image_formats.html)

## 附 B：完整 12 槽数值色板

以下是 Shader 原始 RGB 数值，不是显示空间颜色：

```text
Cloth_Primary      = (1.0, 0.5, 0.0)
Cloth_Secondary    = (1.0, 0.0, 0.0)
Cloth_Tertiary     = (1.0, 0.5, 0.5)
Accent_Color      = (1.0, 0.0, 0.5)
Leather_Primary    = (0.5, 0.0, 1.0)
Leather_Secondary  = (0.0, 0.0, 1.0)
Leather_Tertiary   = (0.5, 0.5, 1.0)
Custom_1          = (0.0, 0.5, 1.0)
Metal_Primary      = (0.0, 1.0, 0.5)
Metal_Secondary    = (0.0, 1.0, 0.0)
Metal_Tertiary     = (0.5, 1.0, 0.5)
Custom_2          = (0.5, 1.0, 0.0)
```

本方案按 Shader 可读化 Skill 的保真要求核对了编码与解码，不改 ID 距离公式、不把 RGB 当作三个独立材质遮罩。
本地依据：[UE 染色节点](../shaders/ue_custom_bg3_dye_tint.hlsl)、[EID 7918 可读 Shader](../shaders/eid_7918_ps_readable_semantic.hlsl)、[美术会议版逆向文档](BG3_染色区域逆向说明_美术会议版.md)。
