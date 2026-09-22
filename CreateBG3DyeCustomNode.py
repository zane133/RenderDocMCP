from pathlib import Path

import unreal


# 改成目标 Material 的 Content Browser 路径，不要带 .uasset 后缀。
MATERIAL_PATH = "/Game/YourFolder/M_YourMaterial"

# 脚本会读取同一仓库 shaders 目录下的 Custom Node HLSL。
SCRIPT_DIR = Path(__file__).resolve().parent
CUSTOM_CODE_PATH = SCRIPT_DIR / "shaders" / "ue_custom_bg3_dye_tint.hlsl"

# 可选：给 MSKcloth Texture Sample Parameter 预设一张纹理。
# 示例：MASK_TEXTURE_PATH = "/Game/Characters/Textures/T_MSKcloth"
MASK_TEXTURE_PATH = ""

CUSTOM_NODE_X = 600
CUSTOM_NODE_Y = 0
INPUT_NODE_X = -250
INPUT_START_Y = -520
INPUT_SPACING_Y = 90


# Custom Node 输入顺序。DyeIdRGB 由纹理采样器的 RGB 输出提供；
# 其余输入由 Vector Parameter 提供。
CUSTOM_INPUT_NAMES = [
    "DyeIdRGB",
    "ClothPrimary",
    "ClothSecondary",
    "ClothTertiary",
    "AccentColor",
    "LeatherPrimary",
    "LeatherSecondary",
    "LeatherTertiary",
    "Custom1",
    "MetalPrimary",
    "MetalSecondary",
    "MetalTertiary",
    "Custom2",
]

DYE_PARAMETER_NAMES = CUSTOM_INPUT_NAMES[1:]

# 全白相当于不主动改变基础色，便于先检查 MSKcloth 路由是否正确。
DEFAULT_DYE_COLOR = unreal.LinearColor(1.0, 1.0, 1.0, 1.0)


def load_material():
    material = unreal.load_asset(MATERIAL_PATH)
    if not isinstance(material, unreal.Material):
        raise RuntimeError(
            "MATERIAL_PATH 不是有效的 Material：{}".format(MATERIAL_PATH)
        )
    return material


def load_custom_code():
    if not CUSTOM_CODE_PATH.is_file():
        raise RuntimeError(
            "找不到 Custom Node HLSL：{}".format(CUSTOM_CODE_PATH)
        )
    return CUSTOM_CODE_PATH.read_text(encoding="utf-8")


def create_custom_input(input_name):
    custom_input = unreal.CustomInput()
    custom_input.set_editor_property("input_name", unreal.Name(input_name))
    return custom_input


def create_custom_node(material, custom_code):
    custom_node = unreal.MaterialEditingLibrary.create_material_expression(
        material,
        unreal.MaterialExpressionCustom,
        CUSTOM_NODE_X,
        CUSTOM_NODE_Y,
    )
    if custom_node is None:
        raise RuntimeError("创建 MaterialExpressionCustom 失败。")

    custom_node.modify()
    custom_node.set_editor_property(
        "inputs",
        [create_custom_input(name) for name in CUSTOM_INPUT_NAMES],
    )
    custom_node.set_editor_property("code", custom_code)
    custom_node.set_editor_property(
        "output_type",
        unreal.CustomMaterialOutputType.CMOT_FLOAT3,
    )
    custom_node.set_editor_property(
        "description",
        "BG3 MSKcloth Dye Tint",
    )
    return custom_node


def create_mask_texture_parameter(material, custom_node):
    mask_node = unreal.MaterialEditingLibrary.create_material_expression(
        material,
        unreal.MaterialExpressionTextureSampleParameter2D,
        INPUT_NODE_X,
        INPUT_START_Y,
    )
    if mask_node is None:
        raise RuntimeError("创建 MSKcloth Texture Sample Parameter 失败。")

    mask_node.set_editor_property("parameter_name", unreal.Name("MSKcloth"))
    mask_node.set_editor_property(
        "sampler_type",
        unreal.MaterialSamplerType.SAMPLERTYPE_MASKS,
    )

    if MASK_TEXTURE_PATH:
        mask_texture = unreal.load_asset(MASK_TEXTURE_PATH)
        if not isinstance(mask_texture, unreal.Texture):
            raise RuntimeError(
                "MASK_TEXTURE_PATH 不是有效的 Texture：{}".format(
                    MASK_TEXTURE_PATH
                )
            )
        mask_node.set_editor_property("texture", mask_texture)

    connected = unreal.MaterialEditingLibrary.connect_material_expressions(
        mask_node,
        "RGB",
        custom_node,
        "DyeIdRGB",
    )
    if not connected:
        unreal.log_warning("连接失败：MSKcloth.RGB -> DyeIdRGB")

    return mask_node


def create_dye_vector_parameters(material, custom_node):
    nodes = []

    for index, parameter_name in enumerate(DYE_PARAMETER_NAMES, start=1):
        parameter_node = unreal.MaterialEditingLibrary.create_material_expression(
            material,
            unreal.MaterialExpressionVectorParameter,
            INPUT_NODE_X,
            INPUT_START_Y + index * INPUT_SPACING_Y,
        )
        if parameter_node is None:
            raise RuntimeError(
                "创建 Vector Parameter 失败：{}".format(parameter_name)
            )

        parameter_node.set_editor_property(
            "parameter_name",
            unreal.Name(parameter_name),
        )
        parameter_node.set_editor_property(
            "default_value",
            DEFAULT_DYE_COLOR,
        )

        connected = unreal.MaterialEditingLibrary.connect_material_expressions(
            parameter_node,
            "",
            custom_node,
            parameter_name,
        )
        if not connected:
            unreal.log_warning(
                "连接失败：{} -> {}".format(
                    parameter_node.get_name(),
                    parameter_name,
                )
            )

        nodes.append(parameter_node)

    return nodes


def create_bg3_dye_custom_node():
    material = load_material()
    custom_code = load_custom_code()

    material.modify()

    custom_node = create_custom_node(material, custom_code)
    create_mask_texture_parameter(material, custom_node)
    create_dye_vector_parameters(material, custom_node)

    unreal.MaterialEditingLibrary.recompile_material(material)
    unreal.EditorAssetLibrary.save_loaded_asset(
        material,
        only_if_is_dirty=True,
    )

    unreal.log(
        "完成：已创建 BG3 Dye Custom Node 和 13 个输入。{}".format(
            material.get_path_name()
        )
    )
    unreal.log(
        "下一步：给 MSKcloth 参数指定关闭 sRGB 的 Mask 纹理，"
        "再把 Custom 输出乘到 Base Color。"
    )


# 注意：每运行一次都会新建一套节点。
create_bg3_dye_custom_node()
