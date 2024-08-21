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

#ifndef ENABLE_DESATURATION
#define ENABLE_DESATURATION 0
#endif

static const int
	Luma = 0,
	YUV = 1,
	Average = 2,
	Vibrance = 3,
	Adaptive = 4,
	OKLAB = 5;

namespace HDRShaders
{

// UI
uniform bool UI_SATURATION_KEEP_BRIGHTNESS <
	ui_category = "Saturation";
	ui_label = "Keep Brightness";
	ui_tooltip = "Should saturation be disallowed to increase image brightness?";
> = 0;

uniform int UI_SATURATION_METHOD
<
	ui_category = "Saturation";
	ui_label = "Method";
	ui_tooltip =
		"Specify which saturation function is used"
		"\n""\n" "Default: HSV";
	ui_type = "combo";
	ui_items = "Luma\0YUV\0Average\0Vibrance\0Adaptive\0OKLAB\0";
> = OKLAB;

uniform float UI_SATURATION_AMOUNT <
	ui_category = "Saturation";
	#if ENABLE_DESATURATION
		ui_min = -1.0;
	#else
		ui_min = 0.01;
	#endif
	ui_max = 25.0;
	ui_label = "Amount";
	ui_tooltip = "Degree of saturation adjustment, 0 = neutral";
	ui_step = 0.01;
	ui_type = "slider";
> = 25.0;

uniform float UI_SATURATION_GAMUT_EXPANSION <
	ui_category = "Saturation";
	ui_min = 0.0; ui_max = 20.0;
	ui_label = "Gamut Expansion";
	ui_tooltip = "Generates HDR colors from bright saturated SDR ones. Neutral at 0";
	ui_step = 0.01;
	ui_type = "slider";
> = 20.0;

uniform float UI_SATURATION_LIMIT <
	ui_category = "Saturation - Advanced";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Global>Highlight";
	ui_tooltip = "Switch between global or highlight only saturation";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.98;

uniform float UI_SATURATION_CLIPPING_LIMIT <
	ui_category = "Saturation - Advanced";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Luma Preservation";
	ui_tooltip = "Avoid clipping out highlight details";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.85;

uniform float UI_SATURATION_COLORS_LIMIT <
	ui_category = "Saturation - Advanced";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Chroma Preservation";
	ui_tooltip = "Avoid clipping out color details";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.65;

uniform float UI_SATURATION_GAMUT_EXPANSION_CLIPPING_LIMIT <
	ui_category = "Saturation - Advanced";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Gamut Expansion Threshold";
	ui_tooltip = "How much Gamut Expansion is controlled by image luminance";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.92;

float3 SaturationAdjustment(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	const float3x3 sRGB_2_AP1 = mul(XYZ_2_AP1_MAT, mul(D65_2_D60_CAT, sRGB_2_XYZ_MAT));
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	color = clamp(color, -FLT16_MAX, FLT16_MAX);
	if (Luminance(color, lumCoeffHDR) < 0.f)
	{
		color = 0.f;
	};
	float3 PreProcessedColor = color;
	float HDRLuminance = Luminance(PreProcessedColor, lumCoeffHDR);

	float3 ChromaComponents = PreProcessedColor - HDRLuminance;
	float Chroma = length(ChromaComponents);

	float BaseSaturationRatio = 1.0 + UI_SATURATION_AMOUNT;
	float SaturationClippingFactor = 1.0 - saturate(HDRLuminance) * (UI_SATURATION_CLIPPING_LIMIT);
	float AdjustedSaturationRatio = BaseSaturationRatio;

	const float OklabLightness = RGBToOKLab(PreProcessedColor)[0];
	const float HighlightSaturationRatio = (OklabLightness + (1.f / 48.f)) / (192.f / 1.f);
	const float MidSaturationRatio = OklabLightness;

	float RatioBlend = 0.0;
	if (UI_SATURATION_AMOUNT > 0.0)
	{
		AdjustedSaturationRatio *= SaturationClippingFactor;
		RatioBlend = lerp(MidSaturationRatio, HighlightSaturationRatio, UI_SATURATION_LIMIT);
	}
	else
	{
		RatioBlend = 1.0;
	}

	float AdjustedSaturation = max(lerp(1.f, AdjustedSaturationRatio, RatioBlend), .0f);

	float3 SaturatedColor = PreProcessedColor;
	if (UI_SATURATION_METHOD == Luma)
	{
		SaturatedColor = LumaSaturation(SaturatedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == YUV)
	{
		SaturatedColor = YUVSaturation(SaturatedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == Average)
	{
		SaturatedColor = AverageSaturation(SaturatedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == Vibrance)
	{
		SaturatedColor = VibranceSaturation(SaturatedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == Adaptive)
	{
		SaturatedColor = AdaptiveSaturation(SaturatedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == OKLAB)
	{
		SaturatedColor = OKLABSaturation(SaturatedColor, AdjustedSaturation);
	}

	if (UI_SATURATION_KEEP_BRIGHTNESS)
	{
		SaturatedColor = SaturationBrightnessLimiter(PreProcessedColor, SaturatedColor);
	}
	SaturatedColor = WideColorsClamp(SaturatedColor);
	SaturatedColor = GamutMapping(SaturatedColor);
	SaturatedColor = lerp(SaturatedColor, max(SaturatedColor, 0.f), UI_SATURATION_COLORS_LIMIT); // Awful hack to reduce invalid color\clipping

	if (UI_SATURATION_GAMUT_EXPANSION > 0.f)
	{
		SaturatedColor = ExpandGamut
		(
			SaturatedColor,
			UI_SATURATION_GAMUT_EXPANSION * saturate(smoothstep(1, 1.0 - Chroma, UI_SATURATION_GAMUT_EXPANSION_CLIPPING_LIMIT))
		);
		SaturatedColor = GamutMapping(SaturatedColor);
	}
	float3 XYZColor = mul(sRGB_2_XYZ_MAT, SaturatedColor);
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

//Namespace
}