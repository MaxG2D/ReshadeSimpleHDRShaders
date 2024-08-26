/**
 - Reshade HDR Bloom
 - Inspired largly by Luluco250's MagicHDR [https://github.com/luluco250/FXShaders]
 - By MaxG3D
 **/

// Includes
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "HDRShadersFunctions.fxh"

// Defines
#ifndef REMOVE_SDR_VALUES
#define REMOVE_SDR_VALUES 0
#endif

#ifndef ADDITIONAL_BLUR_PASS
#define ADDITIONAL_BLUR_PASS 1
#endif

// Good range is between 12-24
#ifndef ADDITIONAL_BLUR_SAMPLES
#define ADDITIONAL_BLUR_SAMPLES 12
#endif

#ifndef DOWNSAMPLE
#define DOWNSAMPLE 4
#endif

#ifndef LINEAR_CONVERSION
#define LINEAR_CONVERSION 0
#endif

#ifndef DIRT_TEXTURE
#define DIRT_TEXTURE 0
#endif

#ifndef DIRT_TEXTURE_TWEAKING
#define DIRT_TEXTURE_TWEAKING 0
#endif

#if DOWNSAMPLE < 1
	#error "Downsample cannot be less than 1x"
#endif

namespace HDRShaders
{

static const int
	Additive = 0,
	Overlay = 1;

static const int
	None = 0,
	Reinhard = 1;

static const int
	Medium = 0,
	High = 1,
	Ultra = 2,
	Overkill = 3;

static const int2 DownsampleAmount = DOWNSAMPLE;

// UI
uniform uint UI_IN_COLOR_SPACE
<
	ui_label	= "Input Color Space";
	ui_type		= "combo";
	ui_items	= "SDR sRGB\0HDR scRGB\0HDR10 BT.2020 PQ\0";
	ui_tooltip	= "Specify the input color space (Auto doesn't always work right).\nFor HDR, either pick scRGB or HDR10";
	ui_category = "Calibration";
> = DEFAULT_COLOR_SPACE;

uniform float UI_BLOOM_AMOUNT
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

uniform float UI_BLOOM_BRIGHTNESS
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

uniform float UI_BLOOM_SATURATION
<
	ui_category = "Bloom";
	ui_label = "Saturation";
	ui_tooltip =
		"Determines the saturation of bloom.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 10.0;
> = 1.0;

#if DIRT_TEXTURE
uniform float UI_DIRT_THRESHOLD
<
	ui_category = "Bloom - Dirt";
	ui_label = "Dirt Threshold";
	ui_tooltip =
		"The threshold of dirt texture to apply to the image"
		"\n" "\n" "Default: 0.9";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.80;

uniform float UI_DIRT_BRIGHTNESS
<
	ui_category = "Bloom - Dirt";
	ui_label = "Dirt Brightness";
	ui_tooltip =
		"Scalar of the dirt texture brightness."
		"\n" "\n" "Default: 200.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 200.0;
> = 50.0;
#endif

uniform int UI_SAMPLE_COUNT
<
	ui_category = "Bloom - Advanced";
	ui_label = "Sampling Quality";
	ui_tooltip = "Specify the number of samples for Gaussian blur."
	"\n" "\n" "Medium - 5, High - 7, VeryHigh - 11, Overkill - 13\n"
	"\n" "\n" "Default: Medium";
	ui_category_closed = true;
	ui_type = "combo";
	ui_items = "Medium\0High\0Ultra\0Overkill\0";  // 0 - Medium, 1 - High, 2 - Ultra, 3 - Overkill
> = Medium;

uniform int UI_BLOOM_INV_TMO
<
	ui_category = "Bloom - Advanced";
	ui_label = "Inverse Tonemapping";
	ui_tooltip =
		"Optional inverse tonemapping to increase the range on the input values"
		"\n" "\n" "Default: None";
	ui_category_closed = true;
	ui_type = "combo";
	ui_items = "None\0Reinhard\0";
> = None;

uniform float UI_BLOOM_BLUR_SIZE
<
	ui_category = "Bloom - Advanced";
	ui_label = "Blur Size";
	ui_tooltip =
		"How much gaussian blur is applied for each bloom texture pass"
		"\n" "\n" "Default: 0.75";
	ui_category_closed = true;
	ui_type = "slider";
	ui_min = 0.5;
	ui_max = 4.0;
> = 2.0;

#if ADDITIONAL_BLUR_PASS
uniform float UI_BLOOM_SECOND_BLUR_SIZE
<
	ui_category = "Bloom - Advanced";
	ui_label = "Additional Blur Size";
	ui_tooltip =
		"The size of the gaussian blur applied to bloom texture right before it's mixed with input"
		"\n" "Used to mitigate undersampling artifacts"
		"\n" "\n" "Default: 1.6";
	ui_category_closed = true;
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 10.0;
> = 5.0;
#endif

uniform int UI_BLOOM_BLENDING_TYPE
<
	ui_category = "Bloom - Advanced";
	ui_label = "Blending Type";
	ui_tooltip =
		"Methods of blending bloom with image.\n"
		"\nDefault: Overlay";
	ui_category_closed = true;
	ui_type = "combo";
	ui_items = "Additive\0Overlay\0";
> = Overlay;

uniform bool UI_BLOOM_SHOW_DEBUG
<
	ui_category = "Debug";
	ui_label = "Show Bloom";
	ui_tooltip =
		"Displays the bloom texture."
		"\n" "\n" "Default: Off";
> = false;

uniform bool UI_BLOOM_DEBUG_RAW
<
	ui_category = "Debug";
	ui_label = "Bloom x Amount?";
	ui_tooltip =
		"Should the bloom texture be multiplied by amount before display or show the raw texture?"
		"\n" "\n" "Default: On";
> = false;

#if DIRT_TEXTURE
uniform int UI_DIRT_OCTAVES
<
	ui_category = "Dirt Texture Generation";
	ui_label = "Noise Octaves";
	ui_category_closed = true;
	ui_min = 1; ui_max = 8;
	ui_label = "";
	ui_tooltip = "";
	ui_type = "slider";
> = 3;

uniform int UI_DIRT_SHOW
<
	ui_category = "Dirt Texture Generation";
	ui_label = "Noise Debug";
	ui_category_closed = true;
	ui_min = 0; ui_max = 1;
	ui_label = "";
	ui_tooltip = "";
	ui_type = "slider";
> = 0;

uniform float UI_DIRT_AMPLITUDE
<
	ui_category = "Dirt Texture Generation";
	ui_label = "Noise Amplitude";
	ui_category_closed = true;
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.55;

uniform float UI_DIRT_SEED
<
	ui_category = "Dirt Texture Generation";
	ui_label = "Noise Seed";
	ui_category_closed = true;
	ui_min = 0.0; ui_max = 6.28;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 1.61;

uniform float UI_DIRT_WARP
<
	ui_category = "Dirt Texture Generation";
	ui_label = "Noise Distort";
	ui_category_closed = true;
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.40;

uniform float UI_DIRT_UVSCALE
<
	ui_category = "Dirt Texture Generation";
	ui_label = "Noise UV Size";
	ui_category_closed = true;
	ui_min = 0.5; ui_max = 10.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 1.25;

uniform float UI_DIRT_POWER
<
	ui_category = "Dirt Texture Generation";
	ui_label = "Noise Power";
	ui_category_closed = true;
	ui_min = 1.0; ui_max = 10.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 4.00;

uniform float UI_DIRT_CLAMP
<
	ui_category = "Dirt Texture Generation";
	ui_label = "Noise Brightness";
	ui_category_closed = true;
	ui_min = 0.01; ui_max = 1.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.05;

uniform float UI_DIRT_SCRATCHES
<
	ui_category = "Dirt Texture Generation";
	ui_label = "Noise Scratches Brightness";
	ui_category_closed = true;
	ui_min = 0.01; ui_max = 1.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.001;
	ui_type = "slider";
> = 0.035;
#endif

// Textures
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

texture DirtTexture
{
		Width = BUFFER_WIDTH;
		Height = BUFFER_HEIGHT;
		Format = R16F;
};
sampler SamplerDirtTexture
{
		Texture = DirtTexture;
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;
		AddressU = Border;
		AddressV = Border;
};

texture NoiseTexture
{
		Width = BUFFER_WIDTH;
		Height = BUFFER_HEIGHT;
		Format = R16F;
};
sampler SamplerNoiseTexture
{
	    Texture = NoiseTexture;
	    MinFilter = LINEAR;
	    MagFilter = LINEAR;
		AddressU = Clamp;
		AddressV = Clamp;
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
	DECLARE_BLOOM_TEXTURE(Bloom6, 64);
	DECLARE_BLOOM_TEXTURE(Bloom7, 128);

// Preprocessing Pixels Shader
float4 PreProcessPS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target
{
	float4 color = tex2D(ReShade::BackBuffer, texcoord);
	color.rgb = clamp(color.rgb, -FLT16_MAX, FLT16_MAX);

	uint inColorSpace = UI_IN_COLOR_SPACE;
	// HDR10 BT.2020 PQ
	if (inColorSpace == 2)
	{
		color.rgb = clamp(color.rgb, -FLT16_MAX, FLT16_MAX);
		color.rgb = PQToLinear(color.rgb);
	}

	// Inv Tonemapping
	if (UI_BLOOM_INV_TMO == 0)
		color.rgb = color.rgb;
	else if (UI_BLOOM_INV_TMO == 1)
	{
		color.rgb = Reinhard_Inverse(color.rgb);
	}

	#if LINEAR_CONVERSION
		color.rgb = sRGBToLinear(color.rgb);
	#endif

	// HDR Thresholding (ignoring 0.0-1.0 range)
	#if REMOVE_SDR_VALUES
		if (Luminance(color.rgb, lumCoeffHDR) < 1.f)
		{
			color.rgb = 0.f;
		}
	#endif

	// Bloom Brightness
	color.rgb *= UI_BLOOM_BRIGHTNESS;

	// Bloom Saturation
	color.rgb = max(AdaptiveSaturation(color.rgb, UI_BLOOM_SATURATION), 0.f);

	return color;
}

float4 GaussianBlur(sampler SampledTexture, float2 TexCoord, float2 Direction, float BlurSize, int SampleCount)
{
	float weights[13];
	int kernelSize = 0;

	// Kernel size and weights based on sample count
	switch (SampleCount)
	{
		case 0:
			kernelSize = 5;
			for (int i = 0; i < kernelSize; ++i)
				weights[i] = Weights5[i];
			break;
		case 1:
			kernelSize = 7;
			for (int i = 0; i < kernelSize; ++i)
				weights[i] = Weights7[i];
			break;
		case 2:
			kernelSize = 11;
			for (int i = 0; i < kernelSize; ++i)
				weights[i] = Weights11[i];
			break;
		case 3:
			kernelSize = 13;
			for (int i = 0; i < kernelSize; ++i)
				weights[i] = Weights13[i];
			break;
	}

	float4 color = 0.0;
	static const float halfSamples = (kernelSize - 1) * 0.5;
	static const float2 GaussBlur = Direction * GetPixelSize() * DownsampleAmount * (BlurSize / DownsampleAmount) * sqrt(2.0 * PI) / (SampleCount * 0.5 + 1);
	for (int i = 0; i < kernelSize; ++i)
	{
		float2 offset = GaussBlur * (i - halfSamples);

		color += (tex2D(SampledTexture, TexCoord - offset).rgba * weights[i]);
	}

	return color;
}

#define DEFINE_BLUR_FUNCTIONS(H, V, input, Scale) \
	float4 HorizontalBlur##H##PS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target \
	{ \
		return GaussianBlur(input, texcoord, float2(Scale, 0.0), UI_BLOOM_BLUR_SIZE, UI_SAMPLE_COUNT); \
	} \
	float4 VerticalBlur##V##PS(float4 pixel : SV_POSITION,float2 texcoord : TEXCOORD0) : SV_Target \
	{ \
		return GaussianBlur(Intermediate, texcoord, float2(0.0, Scale), UI_BLOOM_BLUR_SIZE, UI_SAMPLE_COUNT); \
	}

	DEFINE_BLUR_FUNCTIONS(0, 1, Bloom0, 1);
	DEFINE_BLUR_FUNCTIONS(2, 3, Bloom0, 2);
	DEFINE_BLUR_FUNCTIONS(4, 5, Bloom1, 4);
	DEFINE_BLUR_FUNCTIONS(6, 7, Bloom2, 8);
	DEFINE_BLUR_FUNCTIONS(8, 9, Bloom3, 16);
	DEFINE_BLUR_FUNCTIONS(10, 11, Bloom4, 32);
	DEFINE_BLUR_FUNCTIONS(12, 13, Bloom5, 64);
	DEFINE_BLUR_FUNCTIONS(14, 15, Bloom6, 128);
	DEFINE_BLUR_FUNCTIONS(16, 17, Bloom7, 256)

// Merging all bloom textures so far into a single texture
float4 CombineBloomPS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target
{
	float4 MergedBloom = 0.0;

#if ADDITIONAL_BLUR_PASS
	MergedBloom +=
		CircularBlur(Bloom0, texcoord, UI_BLOOM_SECOND_BLUR_SIZE * 0.2, ADDITIONAL_BLUR_SAMPLES, DownsampleAmount.x) +
		CircularBlur(Bloom1, texcoord, UI_BLOOM_SECOND_BLUR_SIZE * 0.4, ADDITIONAL_BLUR_SAMPLES, DownsampleAmount.x) +
		CircularBlur(Bloom2, texcoord, UI_BLOOM_SECOND_BLUR_SIZE * 0.8, ADDITIONAL_BLUR_SAMPLES, DownsampleAmount.x) +
		CircularBlur(Bloom3, texcoord, UI_BLOOM_SECOND_BLUR_SIZE * 1.6, ADDITIONAL_BLUR_SAMPLES, DownsampleAmount.x) +
		CircularBlur(Bloom4, texcoord, UI_BLOOM_SECOND_BLUR_SIZE * 3.2, ADDITIONAL_BLUR_SAMPLES, DownsampleAmount.x) +
		CircularBlur(Bloom5, texcoord, UI_BLOOM_SECOND_BLUR_SIZE * 6.4, ADDITIONAL_BLUR_SAMPLES, DownsampleAmount.x) +
		CircularBlur(Bloom6, texcoord, UI_BLOOM_SECOND_BLUR_SIZE * 12.8, ADDITIONAL_BLUR_SAMPLES, DownsampleAmount.x) +
		CircularBlur(Bloom7, texcoord, UI_BLOOM_SECOND_BLUR_SIZE * 25.6, ADDITIONAL_BLUR_SAMPLES, DownsampleAmount.x);
	MergedBloom /= 8;
#else
	MergedBloom +=
		tex2D(Bloom0, texcoord) +
		tex2D(Bloom1, texcoord) +
		tex2D(Bloom2, texcoord) +
		tex2D(Bloom3, texcoord) +
		tex2D(Bloom4, texcoord) +
		tex2D(Bloom5, texcoord) +
		tex2D(Bloom6, texcoord) +
		tex2D(Bloom7, texcoord);
	MergedBloom /= 8;
#endif

	return MergedBloom;
}

float4 BlendBloomPS(float4 pixel : SV_POSITION, float2 texcoord : TEXCOORD0) : SV_Target
{
	float4 finalcolor = tex2D(ReShade::BackBuffer, texcoord);
	float4 bloom = tex2D(BloomCombined, texcoord);

	#if DIRT_TEXTURE
	float4 dirt = tex2D(SamplerDirtTexture, texcoord);
	bloom = lerp(bloom, bloom + max((bloom * (dirt.r * (UI_DIRT_BRIGHTNESS * 10))), bloom), 1.0 - UI_DIRT_THRESHOLD);
	#endif

	// There can be a ONE MORE blurring step here, but at this point, it's pretty destructive
	//
	//bloom = CircularBlur(BloomCombined, texcoord, BloomSecondBlurSize, 12, DownsampleAmount.x);
	//bloom = BoxBlur(BloomCombined, texcoord, BloomSecondBlurSize, DownsampleAmount.x);
	//bloom /= 3.0;

	uint inColorSpace = UI_IN_COLOR_SPACE;

	// HDR10 BT.2020 PQ

	if (inColorSpace == 2)
		{
			bloom.rgb = fixNAN(bloom.rgb);
			bloom.rgb = LinearToPQ(bloom.rgb);
		}


	if (UI_BLOOM_BLENDING_TYPE == Overlay)
		{
		finalcolor.rgb = UI_BLOOM_SHOW_DEBUG
			? (UI_BLOOM_DEBUG_RAW ? bloom.rgb * UI_BLOOM_AMOUNT : bloom.rgb)
			: lerp(finalcolor.rgb, bloom.rgb, log10(UI_BLOOM_AMOUNT + 1.0));
		}

	else if (UI_BLOOM_BLENDING_TYPE == Additive)
		{
		finalcolor.rgb = UI_BLOOM_SHOW_DEBUG
			? (UI_BLOOM_DEBUG_RAW ? bloom.rgb * UI_BLOOM_AMOUNT : bloom.rgb)
			: finalcolor.rgb + (bloom.rgb * UI_BLOOM_AMOUNT);
		}

	// SDR Clamp
	if (inColorSpace == 0)
		{
			finalcolor = clamp(finalcolor, 0.0, 1.0);
		}

	return finalcolor;
}

#if DIRT_TEXTURE
/////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////
// Dirt Texture Generation
// Ported from the following shadertoy example:
// https://www.shadertoy.com/view/7sXBWl#
/////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////
float3 cyclicNoise(float3 p, float amp, float warp, float rot_angle, int octaves)
{
	float3 sum = 0.0;
	float3x3 rotationMatrix = orthBasis(float3(rot_angle, -rot_angle, 0.2));

	for (int i = 0; i < octaves; i++) {
		p = mul(p, (rotationMatrix * 2));
		p += sin(p.zxy * warp);
		sum += sin(cross(cos(p), sin(p.yzx))) * amp;
		amp *= 0.5;
		warp *= 1.3;
	}

	return sum;
}

float3 getNoise(float2 uv, float amp, float warp, float rot_angle, int octaves, float power)
{
	float3 na = cyclicNoise(float3(uv + 20.0, 5.0), amp, warp, rot_angle, octaves);
	float3 n = cyclicNoise(float3(uv * 10.0 + na.xy * 4.0, cyclicNoise(float3(uv, 1.0), amp, warp, rot_angle, octaves).x * 4.0), amp, warp, rot_angle, octaves);
	float3 nb = cyclicNoise(float3(uv * 2.0 - n.xy * 1.0, cyclicNoise(float3(n.xy, n.z), amp, warp, rot_angle, octaves).x * -0.2 - 10.0), amp, warp, rot_angle, octaves);
	float3 nc = cyclicNoise(float3(uv * 22.0 - n.xy * 1.0 + nb.xz * 1.0, n.y * 1.0 + nb.x - n.x), amp, warp, rot_angle, octaves);
	float3 nd = cyclicNoise(float3(n.xy * 2.0 + nc.xz * 0.6, nc.y + 5.0), amp, warp, rot_angle, octaves);
	float3 ne = cyclicNoise(float3(nd.xy * 2.0 + uv.xy, nd.x * 1.0 + 441.0), amp, warp, rot_angle, octaves);
	n *= nb * 7.0 * dot(nc, float3(0.2 - nd.x, 1.0 - nd.y, 0.1)) * nd * ne * 3.0;
	n = dot(n, float3(0.23, 1.0, 0.5)) * float3(1.0, 1.0, 1.0);
	n = max(n, 0.0);
	n = n / (1.0 + n);
	n = pow(n, float3(power, power, power)) * 55.0;
	return n;
}

float3 NoiseTextureGenerationPS(float4 pixel : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 noise = 0.0;
	noise += getNoise(texcoord * UI_DIRT_UVSCALE, UI_DIRT_AMPLITUDE, UI_DIRT_WARP, UI_DIRT_SEED, UI_DIRT_OCTAVES, UI_DIRT_POWER);
	return min(noise, UI_DIRT_CLAMP);
}

float4 DirtTextureGenerationPS(float4 pixel : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float2 uv = texcoord * float2(1.0, 0.8);
	float4 col = 0.0;
	float iters = 150.0;
	float radius = 0.01;

	for (float i = 0.0; i < iters; i++) {
		float3 r = hash33(float3(texcoord * 445.0 + 1150.0, i));
		r.x = i / iters;
		float3 c = float3(r.z * 0.75, 0.4, 0.35);
		float2 offset = float2(sin(r.x * TAU), cos(r.x * TAU)) * sqrt(r.y) * radius;
		float2 newUV = uv + offset * GetAspectRatio();
		col += min(tex2D(SamplerNoiseTexture, newUV).xyz, UI_DIRT_CLAMP) / iters * c * 5.0;
	}
	col += tex2D(SamplerNoiseTexture, uv * 0.985).xyz * UI_DIRT_SCRATCHES;

	return float4(col);
}

float4 BlendDirtTexturesPS(float4 pixel : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 DirtTexture = tex2D(SamplerDirtTexture, texcoord);
	DirtTexture += CircularBlur(SamplerDirtTexture, texcoord, 2.0, 24, 1) /2;
	float4 color = tex2D(ReShade::BackBuffer, texcoord);
	color.xyz = lerp(color.xyz, DirtTexture.rrr, saturate(UI_DIRT_SHOW));
	return float4(color.xyz, 1.0);
}

// Drit Texture Generation technique
technique HDRDirtTextureGeneration
<
enabled = true;
hidden = 1;
#if DIRT_TEXTURE_TWEAKING == 0
timeout = 1;
#endif
>
{
	pass NoiseTextureGeneration
	{
		VertexShader = PostProcessVS;
		PixelShader = NoiseTextureGenerationPS;
		RenderTarget = NoiseTexture;
	}

	pass DirtTextureGeneration
	{
		VertexShader = PostProcessVS;
		PixelShader = DirtTextureGenerationPS;
		RenderTarget = DirtTexture;
	}

	pass BlendDirtTextures
	{
		VertexShader = PostProcessVS;
		PixelShader = BlendDirtTexturesPS;
	}
}
#endif

// Main technique
technique HDRBloom <
ui_label = "HDRBloom";>
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

	ADD_BLUR_PASSES(0, 0, 1)
	ADD_BLUR_PASSES(1, 2, 3)
	ADD_BLUR_PASSES(2, 4, 5)
	ADD_BLUR_PASSES(3, 6, 7)
	ADD_BLUR_PASSES(4, 8, 9)
	ADD_BLUR_PASSES(5, 10, 11)
	ADD_BLUR_PASSES(6, 12, 13)
	ADD_BLUR_PASSES(7, 14, 15)

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