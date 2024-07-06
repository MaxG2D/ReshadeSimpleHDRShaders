/**
 - Reshade HDR Motion Blur
 - Original code copyright, Jakob Wapenhensch
 - Tweaks and edits by MaxG3D
 **/


// Includes
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "HDRShadersFunctions.fxh"


// Defines
#ifndef LINEAR_CONVERSION
#define LINEAR_CONVERSION 0
#endif

#ifndef FAKE_GAIN
#define FAKE_GAIN 0
#endif

#ifndef DEPTH_ENABLE
#define DEPTH_ENABLE 0
#endif

#define VELOCITY_SCALE 50.0
#define HALF_SAMPLES (UI_BLUR_SAMPLES_MAX / 2)

/**
uniform float HDR_MAX_NITS
<
  ui_label = "HDR display peak brightness (max nits)";
  ui_tooltip = "Set it equal or higher the Auto HDR max brightness to avoid double tonemapping";
  ui_category = "HDR tonemapping";
  ui_type = "drag";
  ui_min = sRGB_max_nits;
  ui_max = 10000.f;
  ui_step = 1.f;
> = 750.f;
**/

// UI
uniform int README
<
	ui_category = "Read me";
	ui_category_closed = true;
	ui_label    = " ";
	ui_type     = "radio";
	ui_text     =
			"This shader MUST have one of the optical flow shaders enabled before it, otherwise it won't work!"
			"\n" "\n" "Be careful with FAKE_GAIN_REJECT function, it's mostly legacy (for SDR), pushing it too far will reduce perf!"
			"\n" "It's meant to reduce flickering when a lot of neighbouring pixels are bright, which happens a lot in old SDR games.";
>;

uniform uint UI_IN_COLOR_SPACE
<
	ui_label    = "Input Color Space";
	ui_type     = "combo";
	ui_items    = "SDR sRGB\0HDR scRGB\0HDR10 BT.2020 PQ\0";
	ui_tooltip = "Specify the input color space\nFor HDR, either pick scRGB or HDR10";
	ui_category = "Calibration";
> = DEFAULT_COLOR_SPACE;

uniform float  UI_BLUR_LENGTH < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.1; ui_max = 0.5; ui_step = 0.01;
	ui_label = "Blur Length";
	ui_tooltip =
	"Scale of the blur amount."
	"\n" "I suggest to use roughly the same values for both length and samples to get the best result.";
	ui_category = "Motion Blur";
> = 0.24;

uniform int  UI_BLUR_SAMPLES_MAX < __UNIFORM_SLIDER_INT1
	ui_min = 8; ui_max = 64; ui_step = 1;
	ui_label = "Blur Samples";
	ui_tooltip =
	"How many samples is used for every pixel."
	"\n" "It is basically a quality tuner.";
	ui_category = "Motion Blur";
> = 24;

uniform float  UI_BLUR_BLUE_NOISE < __UNIFORM_SLIDER_FLOAT2
	ui_min = 0.0; ui_max = 1; ui_step = 0.01;
	ui_label = "Blur Noise";
	ui_tooltip =
	"Scale of the blue noise amount applied to coordinates of the pixel sampling.";
	ui_category = "Motion Blur";
> = 0.5;


#if DEPTH_ENABLE
uniform float  UI_BLUR_DEPTH_WEIGHT <
	ui_label = "Blur Depth Weight";
	ui_min = 0.0;
	ui_max = 64.0;
	ui_step = 0.01;
	ui_type = "slider";
	ui_tooltip =
	"How much depth affects blur - depth contrast.";
	ui_category = "Depth";
> = 20.00;

uniform float  UI_BLUR_DEPTH_BLUR_EDGES <
	ui_label = "Blur Depth Edges Blurring";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.01;
	ui_type = "slider";
	ui_tooltip =
	"How much depth texture get's blurred to make edges softer";
	ui_category = "Depth";
> = 6;

uniform int  UI_BLUR_DEPTH_BLUR_SAMPLES <
	ui_label = "Blur Depth Blurring Samples";
	ui_min = 6;
	ui_max = 32;
	ui_step = 1;
	ui_type = "slider";
	ui_tooltip =
	"How many blur samples used for depth texture blurring";
	ui_category = "Depth";
> = 16;

uniform bool UI_SHOW_DEPTH
<
	ui_category = "Depth";
	ui_label = "Show Depth";
	ui_tooltip =
		"Displays the depth texture.";
> = false;
#endif

#if FAKE_GAIN
uniform float UI_GAIN_SCALE <
	ui_label = "Fake Gain Scale";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.01;
	ui_type = "slider";
	ui_tooltip =
	"Scale the contribution of gain to blurred pixels."
	"\n" "\n" "0.0 is basically no gain, while 2.0 is heavily boosted highlights. Set to 1.0 in true HDR for neutral look.";
	ui_category = "HDR Simulation";
> = 1.00;

uniform float UI_GAIN_POWER <
	ui_label = "Fake Gain Power";
	ui_min = 0.1;
	ui_max = 10.0;
	ui_step = 0.01;
	ui_type = "slider";
	ui_tooltip =
	"Power used to shift the curve of the gain more towards the highlights";
	ui_category = "HDR Simulation";
> = 1.00;

uniform float UI_GAIN_THRESHOLD <
	ui_label = "Fake Gain Threshold";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_type = "slider";
	ui_tooltip =
	"Pixels with luminance above this value will be boosted.";
	ui_category = "HDR Simulation";
> = 0.75;

uniform float UI_GAIN_THRESHOLD_SMOOTH <
	ui_label = "Fake Gain Smoothness";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.01;
	ui_type = "slider";
	ui_tooltip =
	"Thresholding that smoothly interpolates between max and min value of luminance.";
	ui_category = "HDR Simulation";
> = 0.75;
#endif

//  Textures & Samplers
texture ColorTex : COLOR;
sampler SamplerColor
{
	Texture = ColorTex;
	AddressU = Clamp; AddressV = Clamp; MipFilter = Linear; MinFilter = Linear; MagFilter = Linear;
};

texture DepthTex : DEPTH;
sampler SamplerDepth
{
	Texture = DepthTex;
};

texture DepthProcessedTex
{
		Width = BUFFER_WIDTH;
		Height = BUFFER_HEIGHT;
};
sampler SamplerDepthProcessed
{
	    Texture = DepthProcessedTex;
	    MinFilter = LINEAR;
	    MagFilter = LINEAR;
};

texture texMotionVectors
{
		Width = BUFFER_WIDTH;
		Height = BUFFER_HEIGHT;
		Format = RG16F;
};
sampler SamplerMotionVectors2
{
		Texture = texMotionVectors;
		AddressU = Clamp;
		AddressV = Clamp;
		MipFilter = Point;
		MinFilter = Point;
		MagFilter = Point;
};

// Depth Procesing Pixels Shader
#if DEPTH_ENABLE
float4 DepthProcessPS(float4 p : SV_Position, float2 texcoord : TEXCOORD ) : SV_Target
{
	return GetLinearizedDepth(SamplerDepth, texcoord).xxxx;
}
#endif

// Main Pixel Shader
float4 BlurPS(float4 p : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	uint inColorSpace = UI_IN_COLOR_SPACE;
	float2 Velocity = tex2D(SamplerMotionVectors2, texcoord).xy;
	float2 VelocityTimed = Velocity / frametime;
	float2 BlurDist = 0;
	#if DEPTH_ENABLE
		float4 Depthbuffer = CircularBlur(SamplerDepthProcessed, texcoord, UI_BLUR_DEPTH_BLUR_EDGES, UI_BLUR_DEPTH_BLUR_SAMPLES, 1);
		float4 DepthBufferScaled = saturate(min(pow((1.0 - Depthbuffer.xyzw), UI_BLUR_DEPTH_WEIGHT), 1));

		BlurDist = VelocityTimed * VELOCITY_SCALE * (DepthBufferScaled.xx) * UI_BLUR_LENGTH;
	#else
		BlurDist = VelocityTimed * VELOCITY_SCALE * UI_BLUR_LENGTH;
	#endif
	float2 SampleDist = BlurDist / UI_BLUR_SAMPLES_MAX;
	float SampleDistVector = dot(SampleDist, 1.0);
	float4 SummedSamples = 0;
	float4 Sampled = 0;
	//Sampled = tex2D(SamplerColor, texcoord);
	float4 Color = tex2D(SamplerColor, texcoord);
	float2 NoiseOffset = 0;
	if (abs(SampleDistVector) > 0.001)
	{
		NoiseOffset = BlueNoise(texcoord - SampleDist * (0 - HALF_SAMPLES)) * 0.001);
	}
	// Blur Loop
	for (int s = 0; s < UI_BLUR_SAMPLES_MAX; s++)
	{
		Sampled = tex2D(SamplerColor, texcoord - SampleDist * (s - HALF_SAMPLES) + (NoiseOffset * UI_BLUR_BLUE_NOISE));

		// HDR10 BT.2020 PQ
		[branch]
	    if (inColorSpace == 2)
	    {
	    	Sampled.rgb = clamp(Sampled.rgb, -FLT16_MAX, FLT16_MAX);
	    	//Sampled.rgb = BT2020_2_BT709(Sampled.rgb);
	        Sampled.rgb = PQToLinear(Sampled.rgb);
	        //Sampled.rgb = min(max(Sampled.rgb, -PQMaxWhitePoint),PQMaxWhitePoint);
	    }

	    #if LINEAR_CONVERSION
	        Sampled.rgb = sRGBToLinear(Sampled.rgb);
	    #endif

		SummedSamples += Sampled / UI_BLUR_SAMPLES_MAX;
		Color.rgb = max(Color.rgb, Sampled.rgb);
	}

	float luminance = dot(SummedSamples.rgb, inColorSpace == 1 || inColorSpace == 2 ? lumCoeffHDR : lumCoeffsRGB);

	float4 Finalcolor = 0.0;
	float Gain = 0.0;

		[branch]
		#if FAKE_GAIN
		[branch]
		if (inColorSpace == 1 || inColorSpace == 2)
	        Gain = abs(pow(smoothstep(UI_GAIN_THRESHOLD - UI_GAIN_THRESHOLD_SMOOTH, UI_GAIN_THRESHOLD * 10, luminance), UI_GAIN_POWER) * smoothstep(-UI_GAIN_THRESHOLD_SMOOTH, 1.0, luminance) * UI_GAIN_SCALE);
		else
	        Gain = pow(smoothstep(UI_GAIN_THRESHOLD - UI_GAIN_THRESHOLD_SMOOTH, UI_GAIN_THRESHOLD, luminance), UI_GAIN_POWER) * smoothstep(-UI_GAIN_THRESHOLD_SMOOTH, 1.0, luminance) * UI_GAIN_SCALE;
		#endif

		[branch]
		#if FAKE_GAIN
				Finalcolor = SummedSamples * (1.0 - Gain) + Color * Gain;
			#else
				Finalcolor = SummedSamples;
		#endif

		[branch]
		#if LINEAR_CONVERSION
			Finalcolor.rgb = LinearTosRGB(Finalcolor.rgb);
		#endif

		// HDR10 BT.2020 PQ
	    if (inColorSpace == 2)
		    {
		    	Finalcolor.rgb = fixNAN(Finalcolor.rgb);
				//Finalcolor.rgb = DisplayMapColor(Finalcolor.rgb, luminance, HDR_MAX_NITS);
				//Finalcolor.rgb = BT709_2_BT2020(Finalcolor.rgb);
				Finalcolor.rgb = LinearToPQ(Finalcolor.rgb);
		    }

		// SDR
		if (inColorSpace == 0)
			{
				Finalcolor *= 1.0 / max(dot(SummedSamples.rgb, lumCoeffsRGB), 1.0);
				clamp(Finalcolor, 0.0, 1.0);
			}

		#if DEPTH_ENABLE
		Finalcolor = UI_SHOW_DEPTH
			? DepthBufferScaled.xxxx
			: Finalcolor;
		#endif

	return Finalcolor;
}

technique HDRMotionBlur <
ui_label = "HDRMotionBlur";>
{
	#if DEPTH_ENABLE
	pass DepthProcess
	{
		VertexShader = PostProcessVS;
		PixelShader = DepthProcessPS;
		RenderTarget = texDepthProcessed;
	}
	#endif

	pass MotionBlurPass
	{
		VertexShader = PostProcessVS;
		PixelShader = BlurPS;
	}
}