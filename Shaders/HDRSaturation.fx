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
	HSL = 1,
	HSV = 2,
	YUV = 3,
	Average = 4,
	Max = 5;

// UI
uniform int UI_SATURATION_METHOD
<
	ui_label = "Method";
	ui_tooltip =
		"Specify which saturation function is used"
		"\n""\n" "Default: HSV";
	ui_type = "combo";
	ui_items = "Luma\0HSL\0HSV\0YUV\0Average\0Max\0";
> = YUV;

uniform float UI_SATURATION_AMOUNT < 
    ui_min = -1.0; ui_max = 5.0;
	ui_label = "Amount";
    ui_tooltip = "Degree of saturation adjustment, 0 = neutral";
    ui_step = 0.01;
	ui_type = "slider";
> = 2.0;

uniform float UI_SATURATION_LIMIT < 
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Global>Highlight";
    ui_tooltip = "Switch between global or highlight only saturation";
    ui_step = 0.01;
	ui_type = "slider";
> = 0.99;

uniform float UI_SATURATION_GAMUT_EXPANSION < 
    ui_min = 0.0; ui_max = 100.0;
    ui_label = "Gamut Expansion";
    ui_tooltip = "Generates HDR colors from bright saturated SDR ones. Neutral at 0";
    ui_step = 0.01;
	ui_type = "slider";
> = 1.0;

float3 SaturationAdjustment(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
    color = clamp(color, -FLT16_MAX, FLT16_MAX);
    if (Luminance(color, lumCoeffHDR) < 0.f)
	{   
	    color = 0.f;
	}   
	const float3 ExtraColor = color - saturate(color);
    color = saturate(color);   
    color += ExtraColor;     
        
    float3 PreProcessedColor = color;
	float HDRLuminance = Luminance(PreProcessedColor, lumCoeffHDR); 

	if (UI_SATURATION_AMOUNT > 0.0)
    {
	    const float OklabLightness = RGBToOKLab(PreProcessedColor)[0];
        const float HighlightSaturationRatio = (OklabLightness + (1.f / 48.f)) / (48.f / 1.f);
        const float MidSaturationRatio = OklabLightness;
        float ratio_blend = lerp(MidSaturationRatio, HighlightSaturationRatio, UI_SATURATION_LIMIT);
        
		if (UI_SATURATION_METHOD == Luma)	
		{
        	PreProcessedColor = LumaSaturation(PreProcessedColor, lerp(1.f, UI_SATURATION_AMOUNT + 1, (ratio_blend)));
		}
		else if (UI_SATURATION_METHOD == HSL)
		{
        	PreProcessedColor = HSLSaturation(PreProcessedColor, lerp(1.f, UI_SATURATION_AMOUNT + 1, (ratio_blend)));
		}
		else if (UI_SATURATION_METHOD == HSV)
		{
        	PreProcessedColor = HSVSaturation(PreProcessedColor, lerp(1.f, UI_SATURATION_AMOUNT + 1, (ratio_blend)));
		}
		else if (UI_SATURATION_METHOD == YUV)
		{
        	PreProcessedColor = YUVSaturation(PreProcessedColor, lerp(1.f, UI_SATURATION_AMOUNT + 1, (ratio_blend)));
		}
		else if (UI_SATURATION_METHOD == Average)
		{
        	PreProcessedColor = AverageSaturation(PreProcessedColor, lerp(1.f, UI_SATURATION_AMOUNT + 1, (ratio_blend)));
		}
		else if (UI_SATURATION_METHOD == Max)
		{
        	PreProcessedColor = MaxSaturation(PreProcessedColor, lerp(1.f, UI_SATURATION_AMOUNT + 1, (ratio_blend)));
		}
    }

    if (UI_SATURATION_AMOUNT < 0.0)
    {        
		if (UI_SATURATION_METHOD == Luma)	
		{
        	PreProcessedColor = LumaSaturation(PreProcessedColor, saturate(1.0 + UI_SATURATION_AMOUNT));
		}
		else if (UI_SATURATION_METHOD == HSL)
		{
        	PreProcessedColor = HSLSaturation(PreProcessedColor, saturate(1.0 + UI_SATURATION_AMOUNT));
		}
		else if (UI_SATURATION_METHOD == HSV)
		{
        	PreProcessedColor = HSVSaturation(PreProcessedColor, saturate(1.0 + UI_SATURATION_AMOUNT));
		}
		else if (UI_SATURATION_METHOD == YUV)
		{
        	PreProcessedColor = YUVSaturation(PreProcessedColor, saturate(1.0 + UI_SATURATION_AMOUNT));
		}
		else if (UI_SATURATION_METHOD == Average)
		{
        	PreProcessedColor = AverageSaturation(PreProcessedColor, saturate(1.0 + UI_SATURATION_AMOUNT));
		}
		else if (UI_SATURATION_METHOD == Max)
		{
        	PreProcessedColor = MaxSaturation(PreProcessedColor, saturate(1.0 + UI_SATURATION_AMOUNT));
		}
    }   
    
    if (UI_SATURATION_GAMUT_EXPANSION > 0.f)
    {             
        PreProcessedColor = ExpandGamut(PreProcessedColor, (UI_SATURATION_GAMUT_EXPANSION * 0.01));
        PreProcessedColor /= 125.f;
  	  PreProcessedColor = BT709_2_BT2020(PreProcessedColor);
  	  PreProcessedColor = saturate(PreProcessedColor);
  	  PreProcessedColor = BT2020_2_BT709(PreProcessedColor) * 125.f;
  	  
    }
    
    float3 FinalColor = PreProcessedColor * sourceHDRWhitepoint;
        	
	if (HDRLuminance > 0.0f)
    {
        const float MaxOutputLuminance = 10000.f / sRGB_max_nits;
        const float HighlightsShoulderStart = 0.5 * MaxOutputLuminance;
        const float CompressedHDRLuminance = LumaCompress(HDRLuminance, MaxOutputLuminance, HighlightsShoulderStart, 1);
        FinalColor *= CompressedHDRLuminance / HDRLuminance;
    }    
    float3 XYZColor = mul(sRGB_2_XYZ_MAT, FinalColor);
    XYZColor = max(XYZColor, 0.f);
    FinalColor = mul(XYZ_2_sRGB_MAT, XYZColor);    
    FinalColor = fixNAN(FinalColor);   
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