/** 
 - Reshade HDR Saturation
 - Original code copyright, Pumbo
 - Tweaks and edits by MaxG3D
 */

#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "HDRShadersFunctions.fxh"

static const int 
	Basic = 0,
	Extended = 1;

uniform int saturation_method
<
	ui_label = "Sat method";
	ui_tooltip =
		"Either use basic lerp saturation, or more advance saturation that aims to keep hues in check"
		"\n""\n" "Default: Basic";
	ui_type = "combo";
	ui_items = "Basic\0Extended\0";
> = Basic;

uniform float amount < 
    ui_min = -1.0; ui_max = 5.0;
	ui_label = "Sat amount";
    ui_tooltip = "Degree of saturation adjustment, 0 = neutral";
    ui_step = 0.01;
	ui_type = "slider";
> = 1.5;

uniform float limit_to_highlight < 
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Sat global>highlight";
    ui_tooltip = "Switch between global or highlight only saturation";
    ui_step = 0.01;
	ui_type = "slider";
> = 0.95;

uniform float gamut_expansion < 
    ui_min = 0.0; ui_max = 5.0;
    ui_label = "Sat gamut expansion";
    ui_tooltip = "Generates HDR colors from bright saturated SDR ones. Neutral at 0";
    ui_step = 0.01;
	ui_type = "slider";
> = 0.5;

float rangeCompressPow(float x, float fPow)
{
    return 1.0 - pow(exp(-x), fPow);
}

float lumaCompress(float val, float fMaxValue, float fShoulderStart, float fPow)
{
    float v2 = fShoulderStart + (fMaxValue - fShoulderStart) * rangeCompressPow((val - fShoulderStart) / (fMaxValue - fShoulderStart), fPow);
    return val <= fShoulderStart ? val : v2;
}

float3 expandGamut(float3 vHDRColor, float fExpandGamut)
{
    const float3x3 sRGB_2_AP1 = mul(XYZ_2_AP1_MAT, mul(D65_2_D60_CAT, sRGB_2_XYZ_MAT));
    const float3x3 AP1_2_sRGB = mul(XYZ_2_sRGB_MAT, mul(D60_2_D65_CAT, AP1_2_XYZ_MAT));
    const float3x3 Wide_2_AP1 = mul(XYZ_2_AP1_MAT, Wide_2_XYZ_MAT);
    const float3x3 ExpandMat = mul(Wide_2_AP1, AP1_2_sRGB);

    float3 ColorAP1 = mul(sRGB_2_AP1, vHDRColor);

    float LumaAP1 = dot(ColorAP1, AP1_RGB2Y);
    if (LumaAP1 <= 0.f)
    {
        return vHDRColor;
    }
    float3 ChromaAP1 = ColorAP1 / LumaAP1;

    float ChromaDistSqr = dot(ChromaAP1 - 1, ChromaAP1 - 1);
    float ExpandAmount = (1 - exp2(-4 * ChromaDistSqr)) * (1 - exp2(-4 * fExpandGamut * LumaAP1 * LumaAP1));

	float3 ColorExpand = mul(ExpandMat, mul(LumaAP1, ChromaAP1));
	ColorAP1 = lerp(ColorAP1, ColorExpand, ExpandAmount);

    vHDRColor = mul(AP1_2_sRGB, ColorAP1);
    return vHDRColor;
}

float3 SaturationAdjustment(float4 vpos : SV_Position, float2 tex : TEXCOORD) : SV_Target
{
    float3 c0 = tex2D(ReShade::BackBuffer, tex).rgb;
    c0 = clamp(c0, -FLT16_MAX, FLT16_MAX);
    if (luminance(c0, lumCoeffHDR) < 0.f)
	{   
	    c0 = 0.f;
	}   
	const float3 extraColor = c0 - saturate(c0);
    c0 = saturate(c0);   
    c0 += extraColor;     
        
    float3 c1 = c0;
	float HDRLuminance = luminance(c1, lumCoeffHDR); 

	if (amount > 0.0)
    {
	    const float OklabLightness = RGBToOKLab(c1)[0];
        const float highlightSaturationRatio = (OklabLightness + (1.f / 48.f)) / (48.f / 1.f);
        const float midSaturationRatio = OklabLightness;
        float ratio_blend = lerp(midSaturationRatio, highlightSaturationRatio, limit_to_highlight);
        
		if (saturation_method == Basic)	
		{
        	c1 = BasicSaturation(c1, lerp(1.f, amount + 1, (ratio_blend)));
		}
		else if (saturation_method == Extended)
		{
        	c1 = ExtendedSaturation(c1, lerp(1.f, amount + 1, (ratio_blend)));
		}
    }

    if (amount < 0.0)
    {
        c1 = lerp(float3(HDRLuminance,HDRLuminance,HDRLuminance), c1, saturate(1.0 + amount));
    }   
    
    if (gamut_expansion > 0.f)
    {             
        c1 = expandGamut(c1, (gamut_expansion));
        c1 /= 125.f;
  	  c1 = BT709_2_BT2020(c1);
  	  c1 = saturate(c1);
  	  c1 = BT2020_2_BT709(c1) * 125.f;
  	  
    }
    
    float3 c2 = c1 * sourceHDRWhitepoint;
        	
	if (HDRLuminance > 0.0f)
    {
        const float maxOutputLuminance = 10000.f / sRGB_max_nits;
        const float highlightsShoulderStart = 0.5 * maxOutputLuminance;
        const float compressedHDRLuminance = lumaCompress(HDRLuminance, maxOutputLuminance, highlightsShoulderStart, 1);
        c2 *= compressedHDRLuminance / HDRLuminance;
    }    
    float3 XYZColor = mul(sRGB_2_XYZ_MAT, c2);
    XYZColor = max(XYZColor, 0.f);
    c2 = mul(XYZ_2_sRGB_MAT, XYZColor);    
    c2 = fixNAN(c2);
    float3 output = c2;   
    return output;
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