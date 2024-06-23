/**
 - Reshade HDR Bloom
 - Inspired largly by Luluco250's MagicHDR [https://github.com/luluco250/FXShaders]
 - By MaxG3D
 **/

// Includes
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "HDRShadersFunctions.fxh"

#ifndef REMOVE_SDR
#define REMOVE_SDR 1
#endif

#ifndef DOWNSAMPLE
#define DOWNSAMPLE 2
#endif  

namespace HDRShaders
{

// Kernel weights for different blur sizes
static const float Weights5[5] = {0.06136, 0.24477, 0.38774, 0.24477, 0.06136};
static const float Weights7[7] = {0.071303, 0.131514, 0.189879, 0.214607, 0.189879, 0.131514, 0.071303};
static const float Weights11[11] = {0.062496, 0.076065, 0.091321, 0.107807, 0.124101, 0.138889, 0.150959, 0.159208, 0.163746, 0.164606, 0.161891};

static const int 
	Additive = 0,
	Overlay = 1;

static const int2 DownsampleAmount = DOWNSAMPLE;

uniform uint IN_COLOR_SPACE
<
    ui_label    = "Input Color Space";
    ui_type     = "combo";
    ui_items    = "SDR sRGB\0HDR scRGB\0HDR10 BT.2020 PQ\0";
    ui_tooltip  = "Specify the input color space (Auto doesn't always work right).\nFor HDR, either pick scRGB or HDR10";
    ui_category = "Calibration";
> = DEFAULT_COLOR_SPACE;

uniform float BloomAmount
<
    ui_category = "Bloom";
    ui_label = "Amount";
    ui_tooltip =
        "The amount of bloom to apply to the image."
        "\n" "\n" "Default: 0.05";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.05;

uniform float BloomBrightness
<
    ui_category = "Bloom";
    ui_label = "Brightness";
    ui_tooltip =
        "Scalar of the bloom texture brightness."
        "\n" "\n" "Default: 1.0";
    ui_type = "slider";
    ui_min = 0.001;
    ui_max = 10.0;
> = 1.0;

uniform float BloomBlurSize
<
    ui_category = "Bloom - Advanced";
    ui_category_closed = true;
    ui_label = "Blur Size";
    ui_tooltip =
        "How much gaussian blur is applied for each bloom texture pass"
        "\n" "\n" "Default: 1.5";
    ui_type = "slider";
    ui_min = 0.1;
    ui_max = 2.0;
> = 1.5;

uniform float BloomSecondBlurSize
<
    ui_category = "Bloom - Advanced";
    ui_category_closed = true;
    ui_label = "Second Blur Size";
    ui_tooltip =
        "The size of the gaussian blur applied to bloom texture right before it's mixed with input"
        "\n" "Used to mitigate undersampling artifacts"        
        "\n" "\n" "Default: 1.5";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 2.0;
> = 1.25;

uniform int BlendingType
<
	ui_category = "Bloom - Advanced";
	ui_label = "Blending Type";
	ui_tooltip =
		"Methods of blending bloom with image.\n"
		"\nDefault: Additive";
	ui_type = "combo";
	ui_items = "Additive\0Overlay\0";
> = Additive;

uniform bool ShowBloom
<
    ui_category = "Debug";
    ui_category_closed = true;
    ui_label = "Show Bloom";
    ui_tooltip =
        "Displays the bloom texture."
        "\n" "\n" "Default: Off";
> = false;

// Textures
texture ColorTex : COLOR;
sampler Color
{
	Texture = ColorTex;
};

texture BloomCombinedTex
{
		Width = BUFFER_WIDTH / 2; 
		Height = BUFFER_HEIGHT / 2; 
		Format = RGBA16F; 
		MipLevels = 1; 
};
sampler BloomCombined
{
	    Texture = BloomCombinedTex;
	    MinFilter = LINEAR;
	    MagFilter = LINEAR;
	    AddressU = Border;
	    AddressV = Border;
};

#define DECLARE_BLOOM_TEXTURE(TexName, Downscale) \
	texture TexName##Mip <pooled = true;> \
	{ \
		Width = BUFFER_WIDTH / DownsampleAmount.x / Downscale; \
		Height = BUFFER_HEIGHT / DownsampleAmount.y / Downscale; \
		Format = RGBA16F; \
		MipLevels = 1; \
	}; \
	\
	sampler TexName \
	{ \
	    Texture = TexName##Mip; \
	    MinFilter = LINEAR; \
	    MagFilter = LINEAR; \
	    AddressU = Border; \
	    AddressV = Border; \
	}

	DECLARE_BLOOM_TEXTURE(Intermediate, 1);
	
	DECLARE_BLOOM_TEXTURE(Bloom0, 1);
	DECLARE_BLOOM_TEXTURE(Bloom1, 2);
	DECLARE_BLOOM_TEXTURE(Bloom2, 4);
	DECLARE_BLOOM_TEXTURE(Bloom3, 8);
	DECLARE_BLOOM_TEXTURE(Bloom4, 16);
	DECLARE_BLOOM_TEXTURE(Bloom5, 32);

// Preprocessing
float4 PreProcessPS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target
{
    float4 color = tex2D(Color, texcoord);
    
    uint inColorSpace = IN_COLOR_SPACE;
	if (inColorSpace == 2) // HDR10 BT.2020 PQ
    {
        color.rgb = PQ_to_linear(color.rgb);
        color.rgb = BT2020_2_BT709(color.rgb);
    }
    
	#if REMOVE_SDR
		// HDR Thresholding (ignoring 0.0-1.0 range)
		if (luminance(color.rgb, lumCoeffHDR) < 1.f)
		{
			color.rgb = 0.f;
		}
	#endif
	
	// Bloom Brightness
	color *= BloomBrightness;
    
    return color;
}

// Gaussian blur function
float4 GaussianBlur(sampler s, float2 uv, float2 direction, float blurSize, const float weights[5], int kernelSize)
{
    float4 color = 0.0;
    for (int i = 0; i < kernelSize; ++i)
    {
        float2 offset = direction * (i - (kernelSize - 1) * 0.5) * blurSize;
        color += tex2D(s, uv - offset * GetPixelSize() * DownsampleAmount).rgba * weights[i];
    }
    return color;
}

#define DEFINE_BLUR_FUNCTIONS(H, V, input, Scale) \
    float4 HorizontalBlur##H##PS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target \
    { \
        return GaussianBlur(input, texcoord, float2(Scale, 0.0), BloomBlurSize, Weights5, 5); \
    } \
    float4 VerticalBlur##V##PS(float4 pixel : SV_POSITION,float2 texcoord : TEXCOORD0) : SV_Target \
    { \
        return GaussianBlur(Intermediate, texcoord, float2(0.0, Scale), BloomBlurSize, Weights5, 5); \
    }

	// Define blur functions for each mip level
	DEFINE_BLUR_FUNCTIONS(0, 1, Bloom0, 0);
	DEFINE_BLUR_FUNCTIONS(2, 3, Bloom0, 2);
	DEFINE_BLUR_FUNCTIONS(4, 5, Bloom1, 4);
	DEFINE_BLUR_FUNCTIONS(6, 7, Bloom2, 8);
	DEFINE_BLUR_FUNCTIONS(8, 9, Bloom3, 16);
	DEFINE_BLUR_FUNCTIONS(10, 11, Bloom4, 32);

// Second blur pass for artifact smoothing
float4 CombineBloomPS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target
{
	float4 MergedBloom = 0.0;
    // Adding all passes	
	MergedBloom +=
		tex2D(Bloom0, texcoord) +
		tex2D(Bloom1, texcoord) +
		tex2D(Bloom2, texcoord) +
		tex2D(Bloom3, texcoord) +
		tex2D(Bloom4, texcoord) +
		tex2D(Bloom5, texcoord);
	MergedBloom /= 6;
	
    return MergedBloom;  
}

float4 BlendBloomPS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target
{
	float4 finalcolor = tex2D(Color, texcoord);
    float4 bloom = tex2D(BloomCombined, texcoord);

	// Additional Blur
    bloom = GaussianBlur(BloomCombined, texcoord, float2(1, 0.0), BloomSecondBlurSize, Weights5, 5);
    bloom.rgb += GaussianBlur(BloomCombined, texcoord, float2(0.0, 1), BloomSecondBlurSize, Weights5, 5).rgb; 
	bloom /= 2;
   
	if (BlendingType == Overlay)	
	{
	finalcolor.rgb = ShowBloom
		? bloom.rgb
		: lerp(finalcolor.rgb, bloom.rgb, log10(BloomAmount + 1.0));
	}
	
	else if (BlendingType == Additive)	
	{
	finalcolor.rgb = ShowBloom
		? bloom.rgb
		: finalcolor.rgb + (bloom.rgb * BloomAmount);
	}
    return finalcolor;
	
}

// Main technique
technique HDRBloom
{
	pass PreProcess
    {
    	VertexShader = PostProcessVS;
        PixelShader = PreProcessPS;
        RenderTarget = Bloom0Mip;
    }
    
	#define ADD_BLUR_PASSES(index, H, V) \
    pass HorizontalBlur##H \
    { \
    	VertexShader = PostProcessVS; \
        PixelShader = HorizontalBlur##H##PS; \
        RenderTarget = IntermediateMip; \
    } \
    pass VerticalBlur##V \
    { \
    	VertexShader = PostProcessVS; \
        PixelShader = VerticalBlur##V##PS; \
        RenderTarget = Bloom##index##Mip; \
    }
    
    // Add blur passes for each mip level
    ADD_BLUR_PASSES(0, 0, 1)
    ADD_BLUR_PASSES(1, 2, 3)
    ADD_BLUR_PASSES(2, 4, 5)
    ADD_BLUR_PASSES(3, 6, 7)
    ADD_BLUR_PASSES(4, 8, 9)
    ADD_BLUR_PASSES(5, 10, 11)
    
    pass CombineBloom
    {
    	VertexShader = PostProcessVS;
        PixelShader = CombineBloomPS;
        RenderTarget = BloomCombinedTex;
    }
    
    pass BlendBloom
    {
    	VertexShader = PostProcessVS;
        PixelShader = BlendBloomPS;
    }
}

//Namespace
}
