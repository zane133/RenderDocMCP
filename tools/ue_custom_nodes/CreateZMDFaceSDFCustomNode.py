from pathlib import Path

import unreal


# 改成目标 Material 的 Content Browser 路径，不要带 .uasset 后缀。
MATERIAL_PATH = "/Game/XW_Art/RES/TAExample/ToonRender/M_FBX_Face"

# 可选：预设纹理。留空时脚本仍会创建 Texture Object Parameter。
FACE_SDF_TEXTURE_PATH = ""
FACE_CONTROL_TEXTURE_PATH = ""

REPO_ROOT = Path(__file__).resolve().parents[2]
CUSTOM_CODE_PATH = (
    REPO_ROOT / "shaders" / "ue_custom_zmd_face_sdf_masks.hlsl"
)

CUSTOM_NODE_X = 650
CUSTOM_NODE_Y = 0
INPUT_NODE_X = -250
INPUT_START_Y = -420
INPUT_SPACING_Y = 100


INPUT_SPECS = [
    (
        "FaceSDFTex",
        unreal.MaterialExpressionTextureObjectParameter,
        FACE_SDF_TEXTURE_PATH,
    ),
    (
        "FaceControlTex",
        unreal.MaterialExpressionTextureObjectParameter,
        FACE_CONTROL_TEXTURE_PATH,
    ),
    ("UV", unreal.MaterialExpressionTextureCoordinate, None),
    ("NormalWS", unreal.MaterialExpressionVertexNormalWS, None),
    (
        "LightDirectionWS",
        unreal.MaterialExpressionVectorParameter,
        unreal.LinearColor(0.0, 1.0, 0.0, 0.0),
    ),
    (
        "FaceRightWS",
        unreal.MaterialExpressionVectorParameter,
        unreal.LinearColor(1.0, 0.0, 0.0, 0.0),
    ),
    (
        "FaceForwardWS",
        unreal.MaterialExpressionVectorParameter,
        unreal.LinearColor(0.0, 1.0, 0.0, 0.0),
    ),
    ("SDFOffset", unreal.MaterialExpressionScalarParameter, 0.0),
    ("SDFSoftness", unreal.MaterialExpressionScalarParameter, 0.0),
    ("ControlMipBias", unreal.MaterialExpressionScalarParameter, 0.0),
    ("InvertOutput", unreal.MaterialExpressionScalarParameter, 0.0),
]


ADDITIONAL_OUTPUTS = [
    ("LitMask", unreal.CustomMaterialOutputType.CMOT_FLOAT1),
    ("SDFValue", unreal.CustomMaterialOutputType.CMOT_FLOAT1),
    ("DirectionTS", unreal.CustomMaterialOutputType.CMOT_FLOAT3),
    ("SDFRaw", unreal.CustomMaterialOutputType.CMOT_FLOAT4),
    ("FaceControl", unreal.CustomMaterialOutputType.CMOT_FLOAT4),
]


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


def create_custom_output(output_name, output_type):
    custom_output = unreal.CustomOutput()
    custom_output.set_editor_property("output_name", unreal.Name(output_name))
    custom_output.set_editor_property("output_type", output_type)
    return custom_output


def configure_parameter_node(node, input_name, default_value):
    if isinstance(node, unreal.MaterialExpressionTextureObjectParameter):
        node.set_editor_property("parameter_name", unreal.Name(input_name))
        node.set_editor_property(
            "sampler_type",
            unreal.MaterialSamplerType.SAMPLERTYPE_MASKS,
        )
        if default_value:
            texture = unreal.load_asset(default_value)
            if not isinstance(texture, unreal.Texture):
                raise RuntimeError(
                    "纹理路径无效：{}".format(default_value)
                )
            node.set_editor_property("texture", texture)

    elif isinstance(node, unreal.MaterialExpressionVectorParameter):
        node.set_editor_property("parameter_name", unreal.Name(input_name))
        node.set_editor_property("default_value", default_value)

    elif isinstance(node, unreal.MaterialExpressionScalarParameter):
        node.set_editor_property("parameter_name", unreal.Name(input_name))
        node.set_editor_property("default_value", float(default_value))


def create_zmd_face_sdf_custom_node():
    material = load_material()
    custom_code = load_custom_code()

    with unreal.ScopedEditorTransaction("Create ZMD Face SDF Custom Node"):
        material.modify()

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
            [create_custom_input(name) for name, _, _ in INPUT_SPECS],
        )
        custom_node.set_editor_property(
            "additional_outputs",
            [
                create_custom_output(name, output_type)
                for name, output_type in ADDITIONAL_OUTPUTS
            ],
        )
        custom_node.set_editor_property("code", custom_code)
        custom_node.set_editor_property(
            "output_type",
            unreal.CustomMaterialOutputType.CMOT_FLOAT1,
        )
        custom_node.set_editor_property(
            "description",
            "ZMD Face SDF Masks",
        )

        for index, (input_name, node_class, default_value) in enumerate(
            INPUT_SPECS
        ):
            input_node = unreal.MaterialEditingLibrary.create_material_expression(
                material,
                node_class,
                INPUT_NODE_X,
                INPUT_START_Y + index * INPUT_SPACING_Y,
            )
            if input_node is None:
                raise RuntimeError("创建输入节点失败：{}".format(input_name))

            configure_parameter_node(input_node, input_name, default_value)

            connected = unreal.MaterialEditingLibrary.connect_material_expressions(
                input_node,
                "",
                custom_node,
                input_name,
            )
            if not connected:
                unreal.log_warning(
                    "连接失败：{} -> {}".format(
                        input_node.get_name(),
                        input_name,
                    )
                )

        unreal.MaterialEditingLibrary.recompile_material(material)
        unreal.EditorAssetLibrary.save_loaded_asset(
            material,
            only_if_is_dirty=True,
        )

    unreal.log(
        "完成：创建 ZMD Face SDF Custom Node。主输出为 ShadowMask；"
        "附加输出为 LitMask、SDFValue、DirectionTS、SDFRaw、FaceControl。"
    )
    unreal.log(
        "注意：FaceSDFTex 与 FaceControlTex 必须关闭 sRGB；"
        "LightDirectionWS 建议由 Material Parameter Collection 或蓝图驱动。"
    )


# 每运行一次都会新建一套节点。
create_zmd_face_sdf_custom_node()
