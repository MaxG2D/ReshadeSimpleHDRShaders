/**
 - Reshade HDR Bloom
 - Inspired largly by Luluco250's MagicHDR [https://github.com/luluco250/FXShaders]
 - By MaxG3D
 **/
 
// Includes
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "HDRShadersFunctions.fxh"

#ifndef REMOVE_SDR_VALUES
#define REMOVE_SDR_VALUES 1
#endif

#ifndef ADDITIONAL_BLUR_PASS
#define ADDITIONAL_BLUR_PASS 1
#endif

#ifndef DOWNSAMPLE
#define DOWNSAMPLE 4
#endif

#ifndef LINEAR_CONVERSION
#define LINEAR_CONVERSION 0
#endif

#if DOWNSAMPLE < 1
	#error "Downsample cannot be less than 1x"
#endif  

namespace HDRShaders
{

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

uniform float BloomSaturation
<
	ui_category = "Bloom";
	ui_label = "Saturation";
	ui_tooltip =
		"Determines the saturation of bloom.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 2.0;
> = 1.0;

uniform int SampleCount
<
    ui_category = "Bloom - Advanced";
    ui_label = "Sampling Quality";
    ui_tooltip = "Specify the number of samples for Gaussian blur."
	"\n" "\n" "Medium - 5, High - 7, VeryHigh - 11, Overkill - 13\n"
	"\n" "\n" "Default: Medium";
    ui_type = "combo";
    ui_items = "Medium\0High\0Ultra\0Overkill\0";
> = 0;

uniform float BloomBlurSize
<
    ui_category = "Bloom - Advanced";
    ui_category_closed = true;
    ui_label = "Blur Size";
    ui_tooltip =
        "How much gaussian blur is applied for each bloom texture pass"
        "\n" "\n" "Default: 0.75";
    ui_type = "slider";
    ui_min = 0.1;
    ui_max = 2.0;
> = 2.0;

#if ADDITIONAL_BLUR_PASS
uniform float BloomSecondBlurSize
<
    ui_category = "Bloom - Advanced";
    ui_category_closed = true;
    ui_label = "Additional Blur Size";
    ui_tooltip =
        "The size of the gaussian blur applied to bloom texture right before it's mixed with input"
        "\n" "Used to mitigate undersampling artifacts"        
        "\n" "\n" "Default: 1.6";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 7.0;
> = 6.0;
#endif

uniform int BlendingType
<
	ui_category = "Bloom - Advanced";
	ui_label = "Blending Type";
	ui_tooltip =
		"Methods of blending bloom with image.\n"
		"\nDefault: Overlay";
	ui_type = "combo";
	ui_items = "Additive\0Overlay\0";
> = Overlay;

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
		Width = BUFFER_WIDTH / DownsampleAmount.x; 
		Height = BUFFER_HEIGHT / DownsampleAmount.y; 
		Format = RGBA16F; 
		MipLevels = 1; 
};
sampler BloomCombined
{
	    Texture = BloomCombinedTex;
	    MinFilter = LINEAR;
	    MagFilter = LINEAR;
	    MipFilter = LINEAR;
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
        MipFilter = LINEAR; \
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

	#if LINEAR_CONVERSION
		color.rgb = sRGB_to_linear(color.rgb);			
	#endif
    
	#if REMOVE_SDR_VALUES
		// HDR Thresholding (ignoring 0.0-1.0 range)
		if (luminance(color.rgb, lumCoeffHDR) < 1.f)
		{
			color.rgb = 0.f;
		}
	#endif
	
	// Bloom Brightness
	color *= BloomBrightness;

	// Bloom Saturation
	color.rgb = LumaSaturation(color.rgb, BloomSaturation);
    
    return color;
}

float4 GaussianBlur(sampler s, float2 uv, float2 direction, float blurSize, int kernelSize)
{
    float3 weights[13];    
    if (SampleCount == 0)
        {
            kernelSize = 5;
        }
    else if (SampleCount == 1)
        {
            kernelSize = 7;
        }
    else if (SampleCount == 2)
        {
            kernelSize = 11;
        }
    else if (SampleCount == 3)
        {
            kernelSize = 13;
        }
        
    switch (kernelSize)
    {
        case 5:
            for (int i = 0; i < kernelSize; ++i)
                weights[i] = Weights5[i];
            break;
        case 7:
            for (int i = 0; i < kernelSize; ++i)
                weights[i] = Weights7[i];
            break;
        case 11:
            for (int i = 0; i < kernelSize; ++i)
                weights[i] = Weights11[i];
            break;
        case 13:
            for (int i = 0; i < kernelSize; ++i)
                weights[i] = Weights13[i];
            break;
        default:
            kernelSize = 5; // Default to 5 if SampleCount is out of expected range
            for (int i = 0; i < kernelSize; ++i)
                weights[i] = Weights5[i];
            break;
    }

    float4 color = 0.0;
    static const float halfSamples = (kernelSize - 1) * 0.5;

    // Iterate through kernel samples
    for (int i = 0; i < kernelSize; ++i)
    {
        // Calculate offset
        float2 offset = direction * GetPixelSize() * DownsampleAmount * (blurSize / DownsampleAmount) * sqrt(2.0 * PI) * (i - halfSamples);

        // Accumulate blurred color
        color += tex2D(s, uv - offset).rgba * weights[i].xxxx;
    }

    return color;
}

#define DEFINE_BLUR_FUNCTIONS(H, V, input, Scale) \
    float4 HorizontalBlur##H##PS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target \
    { \
        return GaussianBlur(input, texcoord, float2(Scale, 0.0), BloomBlurSize, SampleCount); \
    } \
    float4 VerticalBlur##V##PS(float4 pixel : SV_POSITION,float2 texcoord : TEXCOORD0) : SV_Target \
    { \
        return GaussianBlur(Intermediate, texcoord, float2(0.0, Scale), BloomBlurSize, SampleCount); \
    }

	DEFINE_BLUR_FUNCTIONS(0, 1, Bloom0, 1);
	DEFINE_BLUR_FUNCTIONS(2, 3, Bloom0, 2);
	DEFINE_BLUR_FUNCTIONS(4, 5, Bloom1, 4);
	DEFINE_BLUR_FUNCTIONS(6, 7, Bloom2, 8);
	DEFINE_BLUR_FUNCTIONS(8, 9, Bloom3, 16);
	DEFINE_BLUR_FUNCTIONS(10, 11, Bloom4, 32);
	DEFINE_BLUR_FUNCTIONS(12, 13, Bloom5, 64)

// Merging all bloom textures so far into a single texture
float4 CombineBloomPS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target
{
	float4 MergedBloom = 0.0;
    
#if ADDITIONAL_BLUR_PASS
	// Adding all passes	
	MergedBloom +=
		CircularBlur(Bloom0, texcoord, BloomSecondBlurSize * 0.2, 12, DownsampleAmount.x) +
		CircularBlur(Bloom1, texcoord, BloomSecondBlurSize * 0.4, 12, DownsampleAmount.x) +
		CircularBlur(Bloom2, texcoord, BloomSecondBlurSize * 0.8, 12, DownsampleAmount.x) +
		CircularBlur(Bloom3, texcoord, BloomSecondBlurSize * 1.6, 12, DownsampleAmount.x) +
		CircularBlur(Bloom4, texcoord, BloomSecondBlurSize * 3.2, 12, DownsampleAmount.x) +
		CircularBlur(Bloom5, texcoord, BloomSecondBlurSize * 6.4, 12, DownsampleAmount.x);
	MergedBloom /= 6;	
#else	
	 // Adding all passes	
	MergedBloom +=
		tex2D(Bloom0, texcoord) +
		tex2D(Bloom1, texcoord) +
		tex2D(Bloom2, texcoord) +
		tex2D(Bloom3, texcoord) +
		tex2D(Bloom4, texcoord) +
		tex2D(Bloom5, texcoord);
	MergedBloom /= 6;
#endif
	
    return MergedBloom;  
}

float4 BlendBloomPS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target
{
    float4 finalcolor = tex2D(Color, texcoord);
    float4 bloom = tex2D(BloomCombined, texcoord);
	
	// There can be a ONE MORE blurring step here, but at this point, it's pretty destructive
    //
	//bloom = CircularBlur(BloomCombined, texcoord, BloomSecondBlurSize, 12, DownsampleAmount.x);
    //bloom = BoxBlur(BloomCombined, texcoord, BloomSecondBlurSize, DownsampleAmount.x);
    //bloom /= 3.0;
    	
	uint inColorSpace = IN_COLOR_SPACE;
    if (inColorSpace == 2) // HDR10 BT.2020 PQ
    {
        bloom.rgb = BT709_2_BT2020(bloom.rgb);
        bloom.rgb = linear_to_PQ(bloom.rgb);
    }
   
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
