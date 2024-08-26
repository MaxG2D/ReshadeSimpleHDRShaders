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
	ui_max = 100.0;
	ui_label = "Amount";
	ui_tooltip = "Degree of saturation adjustment, 0 = neutral";
	ui_step = 1;
	ui_type = "slider";
> = 60.0;

uniform float UI_SATURATION_GAMUT_EXPANSION <
	ui_category = "Saturation";
	ui_min = 0.0; ui_max = 100.0;
	ui_label = "Gamut Expansion";
	ui_tooltip = "Generates HDR colors from bright saturated SDR ones. Neutral at 0";
	ui_step = 1;
	ui_type = "slider";
> = 100.0;

uniform bool UI_SATURATION_KEEP_BRIGHTNESS <
	ui_category = "Saturation - Advanced";
	ui_label = "Keep Brightness";
	ui_tooltip = "Should saturation be disallowed to increase image brightness?"
	"\n" "\n" "Generally not recommended to turn on,"
	"\n" "since increased brightness is a part of perceptual increase of saturation.";
> = 0;

uniform float UI_SATURATION_LIMIT <
	ui_category = "Saturation - Advanced";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Global>Highlight";
	ui_tooltip = "Switch between global or highlight only saturation";
	ui_step = 0.001;
	ui_type = "slider";
> = 0.99;

uniform float UI_SATURATION_LUMA_LIMIT <
	ui_category = "Saturation - Advanced";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Luma Preservation";
	ui_tooltip = "Avoid clipping out highlight details";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.90;

uniform float UI_SATURATION_COLORS_LIMIT <
	ui_category = "Saturation - Advanced";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Chroma Preservation";
	ui_tooltip = "Avoid clipping out color details.";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.50;

uniform float UI_SATURATION_GAMUT_EXPANSION_CLIPPING_LIMIT <
	ui_category = "Saturation - Advanced";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Gamut Expansion Threshold";
	ui_tooltip = "How much Gamut Expansion is controlled by image luminance";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.85;

float3 SaturationAdjustment(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	const float3x3 sRGB_2_AP1 = mul(XYZ_2_AP1_MAT, mul(D65_2_D60_CAT, sRGB_2_XYZ_MAT));
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	color = clamp(color, -FLT16_MAX, FLT16_MAX);
	if (Luminance(color, lumCoeffHDR) < 0.f)
	{
		color = 0.f;
	};
	const float3 PreProcessedColor = color;
	const float HDRLuminance = Luminance(PreProcessedColor, lumCoeffHDR);

	const float OklabLightness = RGBToOKLab(PreProcessedColor)[0];
	const float MidSaturationRatio = OklabLightness;
	const float OKlabLuminance = pow(OklabLightness, 4.0);
	//const float OKlabLuminanceSoft2 = smootherLerp(pow(OKlabLuminance, 0.25), OKlabLuminance, 0.5);
	const float OKlabLuminanceSoft = smoothstep(-8, 8, OKlabLuminance);
	const float HighlightSaturationRatio = (OklabLightness + (1.f / 48.f)) / (192.f / 1.f);

	const float3 ChromaComponents = PreProcessedColor - OKlabLuminance;
	const float Chroma = length(ChromaComponents);
	const float ChromaLimit = UI_SATURATION_COLORS_LIMIT * sqrt(sqrt(sqrt(Chroma)));

	float BaseSaturationRatio = 1.0 + UI_SATURATION_AMOUNT;
	float SaturationClippingFactor = 1.0 - saturate(OKlabLuminanceSoft) * (UI_SATURATION_LUMA_LIMIT);
	float AdjustedSaturationRatio = BaseSaturationRatio;

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

	float3 ProcessedColor = PreProcessedColor;
	float AdjustedSaturation = max(lerp(1.f, AdjustedSaturationRatio, RatioBlend), .0f);
	if (UI_SATURATION_METHOD == Luma)
	{
		ProcessedColor = LumaSaturation(ProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == YUV)
	{
		ProcessedColor = YUVSaturation(ProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == Average)
	{
		ProcessedColor = AverageSaturation(ProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == Vibrance)
	{
		ProcessedColor = VibranceSaturation(ProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == Adaptive)
	{
		ProcessedColor = AdaptiveSaturation(ProcessedColor, AdjustedSaturation);
	}
	else if (UI_SATURATION_METHOD == OKLAB)
	{
		ProcessedColor = OKLABSaturation(ProcessedColor, AdjustedSaturation);
	}

	if (UI_SATURATION_KEEP_BRIGHTNESS)
	{
		ProcessedColor = SaturationBrightnessLimiter(PreProcessedColor, ProcessedColor);
	}

	ProcessedColor = WideColorsClamp(ProcessedColor);
	ProcessedColor = GamutMapping(ProcessedColor);
	ProcessedColor = lerp(ProcessedColor, max(ProcessedColor, 0.f), ChromaLimit);

	if (UI_SATURATION_GAMUT_EXPANSION > 0.f)
	{
		ProcessedColor = ExpandGamut
		(
			ProcessedColor,
			(UI_SATURATION_GAMUT_EXPANSION / 5) * saturate(smoothstep(1, 1.0 - Chroma, UI_SATURATION_GAMUT_EXPANSION_CLIPPING_LIMIT))
		);
		ProcessedColor = GamutMapping(ProcessedColor);
	}
	float3 XYZColor = mul(sRGB_2_XYZ_MAT, ProcessedColor);
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