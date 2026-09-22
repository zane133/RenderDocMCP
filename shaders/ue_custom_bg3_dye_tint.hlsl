// BG3 MSKcloth dye lookup - Unreal Engine Material Custom node code.
//
// Custom node settings:
//   Output Type: CMOT Float 3
//
// Inputs (names must match exactly):
//   DyeIdRGB         - MSKcloth texture RGB
//   ClothPrimary     - dye colour
//   ClothSecondary   - dye colour
//   ClothTertiary    - dye colour
//   AccentColor      - dye colour
//   LeatherPrimary   - dye colour
//   LeatherSecondary - dye colour
//   LeatherTertiary  - dye colour
//   Custom1          - dye colour
//   MetalPrimary     - dye colour
//   MetalSecondary   - dye colour
//   MetalTertiary    - dye colour
//   Custom2          - dye colour
//
// Connect the returned float3 to BaseColor multiplication:
//   FinalBaseColor = TextureBaseColor.rgb * CustomNodeResult

// These are routing IDs stored in MSKcloth, not display colours.
const float3 ID_CLOTH_PRIMARY     = float3(1.0, 0.5, 0.0); // #FF8000
const float3 ID_CLOTH_SECONDARY   = float3(1.0, 0.0, 0.0); // #FF0000
const float3 ID_CLOTH_TERTIARY    = float3(1.0, 0.5, 0.5); // #FF8080
const float3 ID_ACCENT_COLOR      = float3(1.0, 0.0, 0.5); // #FF0080
const float3 ID_LEATHER_PRIMARY   = float3(0.5, 0.0, 1.0); // #8000FF
const float3 ID_LEATHER_SECONDARY = float3(0.0, 0.0, 1.0); // #0000FF
const float3 ID_LEATHER_TERTIARY  = float3(0.5, 0.5, 1.0); // #8080FF
const float3 ID_CUSTOM_1          = float3(0.0, 0.5, 1.0); // #0080FF
const float3 ID_METAL_PRIMARY     = float3(0.0, 1.0, 0.5); // #00FF80
const float3 ID_METAL_SECONDARY   = float3(0.0, 1.0, 0.0); // #00FF00
const float3 ID_METAL_TERTIARY    = float3(0.5, 1.0, 0.5); // #80FF80
const float3 ID_CUSTOM_2          = float3(0.5, 1.0, 0.0); // #80FF00

const float ID_DISTANCE_SCALE = 0.577350;
const float ID_WEIGHT_BIAS = 0.25;
const float ID_WEIGHT_SCALE = 4.0;

float3 dyeId = DyeIdRGB.rgb;

// Green edge: Metal Primary/Secondary/Tertiary + Custom 2.
float4 metalCustomDistances;
metalCustomDistances.x = length(dyeId - ID_METAL_PRIMARY);
metalCustomDistances.y = length(dyeId - ID_METAL_SECONDARY);
metalCustomDistances.z = length(dyeId - ID_METAL_TERTIARY);
metalCustomDistances.w = length(dyeId - ID_CUSTOM_2);
float4 metalCustomWeights = max(
    (-metalCustomDistances * ID_DISTANCE_SCALE) + ID_WEIGHT_BIAS,
    0.0) * ID_WEIGHT_SCALE;

float3 dyeTint = metalCustomWeights.y * MetalSecondary.rgb;
dyeTint = metalCustomWeights.x * MetalPrimary.rgb + dyeTint;
float3 upperIdTint = metalCustomWeights.w * Custom2.rgb;
upperIdTint = metalCustomWeights.z * MetalTertiary.rgb + upperIdTint;
dyeTint = upperIdTint + dyeTint;

// Blue edge: Leather Primary/Secondary/Tertiary + Custom 1.
float4 leatherCustomDistances;
leatherCustomDistances.x = length(dyeId - ID_LEATHER_PRIMARY);
leatherCustomDistances.y = length(dyeId - ID_LEATHER_SECONDARY);
leatherCustomDistances.z = length(dyeId - ID_LEATHER_TERTIARY);
leatherCustomDistances.w = length(dyeId - ID_CUSTOM_1);
float4 leatherCustomWeights = max(
    (-leatherCustomDistances * ID_DISTANCE_SCALE) + ID_WEIGHT_BIAS,
    0.0) * ID_WEIGHT_SCALE;

float3 leatherCustomTint = leatherCustomWeights.w * Custom1.rgb;
leatherCustomTint =
    leatherCustomWeights.z * LeatherTertiary.rgb + leatherCustomTint;
dyeTint = dyeTint + leatherCustomTint;

// Red edge: Cloth Primary/Secondary/Tertiary + Accent.
float4 clothAccentDistances;
clothAccentDistances.x = length(dyeId - ID_CLOTH_PRIMARY);
clothAccentDistances.y = length(dyeId - ID_CLOTH_SECONDARY);
clothAccentDistances.z = length(dyeId - ID_CLOTH_TERTIARY);
clothAccentDistances.w = length(dyeId - ID_ACCENT_COLOR);
float4 clothAccentWeights = max(
    (-clothAccentDistances * ID_DISTANCE_SCALE) + ID_WEIGHT_BIAS,
    0.0) * ID_WEIGHT_SCALE;

float3 clothAccentTint = clothAccentWeights.w * AccentColor.rgb;
clothAccentTint =
    clothAccentWeights.z * ClothTertiary.rgb + clothAccentTint;

float3 leatherPrimarySecondaryTint =
    leatherCustomWeights.y * LeatherSecondary.rgb;
leatherPrimarySecondaryTint =
    leatherCustomWeights.x * LeatherPrimary.rgb
    + leatherPrimarySecondaryTint;

clothAccentTint = clothAccentTint + leatherPrimarySecondaryTint;
clothAccentTint = dyeTint + clothAccentTint;

float3 clothPrimarySecondaryTint =
    clothAccentWeights.y * ClothSecondary.rgb;
clothPrimarySecondaryTint =
    clothAccentWeights.x * ClothPrimary.rgb
    + clothPrimarySecondaryTint;

return clothAccentTint + clothPrimarySecondaryTint;
