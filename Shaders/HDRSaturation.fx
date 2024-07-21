/**
 - Reshade HDR Saturation
 - Original code copyright, Pumbo
 - Tweaks and edits by MaxG3D
 **/

// Includes
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "HDRShadersFunctions.fxh"

// Defines
static const int
	Luma = 0,
	YUV = 1,
	Average = 2,
	Vibrance = 3,
	Adaptive = 4,
	OKLAB = 5;

// UI
uniform int UI_SATURATION_METHOD
<
	ui_label = "Method";
	ui_tooltip =
		"Specify which saturation function is used"
		"\n""\n" "Default: HSV";
	ui_type = "combo";
	ui_items = "Luma\0YUV\0Average\0Vibrance\0Adaptive\0OKLAB\0";
> = OKLAB;

uniform float UI_SATURATION_AMOUNT <
	ui_min = -1.0; ui_max = 10.0;
	ui_label = "Amount";
	ui_tooltip = "Degree of saturation adjustment, 0 = neutral";
	ui_step = 0.01;
	ui_type = "slider";
> = 3.25;

uniform float UI_SATURATION_LIMIT <
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Global>Highlight";
	ui_tooltip = "Switch between global or highlight only saturation";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.75;

uniform float UI_SATURATION_CLIPPING_LIMIT <
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Detail Preservation";
	ui_tooltip = "Avoid clipping out highlight color details";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.78;

uniform float UI_SATURATION_GAMUT_EXPANSION <
	ui_min = 0.0; ui_max = 1000.0;
	ui_label = "Gamut Expansion";
	ui_tooltip = "Generates HDR colors from bright saturated SDR ones. Neutral at 0";
	ui_step = 1;
	ui_type = "slider";
> = 500.0;

float3 SaturationAdjustment(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	color = clamp(color, -FLT16_MAX, FLT16_MAX);
	if (Luminance(color, lumCoeffHDR) < 0.f)
	{
		color = 0.f;
	}
	float3 ExtraColor = color - saturate(color);
	color = saturate(color);
	color += ExtraColor;
	float3 PreProcessedColor = color;
	float HDRLuminance = Luminance(PreProcessedColor, lumCoeffHDR);

	float BaseSaturationRatio = 1.0 + UI_SATURATION_AMOUNT;
	float SaturationClippingFactor = 1.0 - saturate(HDRLuminance) * UI_SATURATION_CLIPPING_LIMIT;
	float AdjustedSaturationRatio = BaseSaturationRatio * SaturationClippingFactor;

	float RatioBlend;
	if (UI_SATURATION_AMOUNT > 0.0)
	{
		const float OklabLightness = RGBToOKLab(PreProcessedColor)[0];
		const float HighlightSaturationRatio = (OklabLightness + (1.f / 48.f)) / (48.f / 1.f);
		const float MidSaturationRatio = OklabLightness;
		RatioBlend = lerp(MidSaturationRatio, HighlightSaturationRatio, UI_SATURATION_LIMIT);
	}
	else
	{
		RatioBlend = 1.0;
	}

	float AdjustedSaturation = lerp(1.f, AdjustedSaturationRatio, RatioBlend);

	if (UI_SATURATION_METHOD == Luma)
	{
		PreProcessedColor = LumaSaturation(PreProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == YUV)
	{
		PreProcessedColor = YUVSaturation(PreProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == Average)
	{
		PreProcessedColor = AverageSaturation(PreProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == Vibrance)
	{
		PreProcessedColor = VibranceSaturation(PreProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == Adaptive)
	{
		PreProcessedColor = AdaptiveSaturation(PreProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == OKLAB)
	{
		PreProcessedColor = OKLABSaturation(PreProcessedColor, AdjustedSaturation);
	}

	if (UI_SATURATION_GAMUT_EXPANSION > 0.f)
	{
		PreProcessedColor = ExpandGamut(PreProcessedColor, UI_SATURATION_GAMUT_EXPANSION * 0.01);
		PreProcessedColor /= 125.f;
		PreProcessedColor = BT709_2_BT2020(PreProcessedColor);
		PreProcessedColor = max(PreProcessedColor, 0.f);
		PreProcessedColor = BT2020_2_BT709(PreProcessedColor) * 125.f;
	}
	float3 XYZColor = mul(sRGB_2_XYZ_MAT, PreProcessedColor);
	XYZColor = max(XYZColor, 0.f);
	float3 FinalColor = mul(XYZ_2_sRGB_MAT, XYZColor);

	return FinalColor;
}

technique HDR_Saturation <
ui_label = "HDRSaturation";>

{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = SaturationAdjustment;
	}
}
