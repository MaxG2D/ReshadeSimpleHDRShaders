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
#ifndef BLUR_SAMPLES
#define BLUR_SAMPLES 20
#endif

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
#define HALF_SAMPLES (BLUR_SAMPLES / 2)

static const int
	Linear = 0,
	Bezier = 1;

// UI
uniform int README
<
	ui_category = "Read me";
	ui_category_closed = true;
	ui_label    = " ";
	ui_type     = "radio";
	ui_text     =
			"This shader MUST have one of the optical flow shaders enabled before it, otherwise it won't work!";
>;

uniform uint UI_IN_COLOR_SPACE
<
	ui_label    = "Input Color Space";
	ui_type     = "combo";
	ui_items    = "SDR sRGB\0HDR scRGB\0HDR10 BT.2020 PQ\0";
	ui_tooltip = "Specify the input color space\nFor HDR, either pick scRGB or HDR10";
	ui_category = "Calibration";
> = DEFAULT_COLOR_SPACE;

uniform uint UI_BLUR_CURVE
<
	ui_label    = "Blur Curve";
	ui_type     = "combo";
	ui_items    = "Linear\0Bezier\0";
	ui_tooltip = "Specify the blurring shape of the curve"
	"\n""\n" "By default, it uses bezier curve which gives it more cinematic look"
	"\n" "But you can use linear sampling which gives it more artificial but sort of more flashy look";
	ui_category = "Motion Blur";
> = Bezier;

uniform float  UI_BLUR_LENGTH <
	ui_min = 0.1; ui_max = 1.0; ui_step = 0.01;
	ui_type = "slider";
	ui_label = "Blur Length";
	ui_tooltip =
	"Scale of the blur amount.";
	ui_category = "Motion Blur";
> = 0.25;

/*
uniform int  UI_BLUR_SAMPLES_MAX <
	ui_min = 8; ui_max = 64; ui_step = 1;
	ui_type = "slider";
	ui_label = "Blur Samples";
	ui_tooltip =
	"How many samples is used for every pixel."
	"\n" "It is basically a quality tuner.";
	ui_category = "Motion Blur";
> = 20;
*/

uniform float  UI_BLUR_BLUE_NOISE <
	ui_min = 0.0; ui_max = 1; ui_step = 0.01;
	ui_type = "slider";
	ui_label = "Blue Noise";
	ui_tooltip =
	"Scale of the blue noise amount applied to coordinates of the pixel sampling.";
	ui_category = "Motion Blur";
> = 0.25;

uniform bool UI_BLUR_BLUE_NOISE_DEBUG
<
	ui_label = "Blue Noise Debug";
	ui_tooltip =
		"Show Blue Noise Threshold.";
	ui_category = "Motion Blur - Advanced";
> = false;

uniform float  UI_BLUR_LENGTH_CLAMP <
	ui_min = 0.05; ui_max = 1; ui_step = 0.001;
	ui_type = "slider";
	ui_label = "Blur Length Clamp";
	ui_tooltip =
	"Clamp of maximum blur length."
	"\n" "Help achieve strong object base blur while making screen based motion fairly low.";
	ui_category = "Motion Blur - Advanced";
> = 0.135;

uniform float  UI_BLUR_CENTER_SAMPLING <
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
	ui_type = "slider";
	ui_label = "Blur Sampling: Center->Lag";
	ui_tooltip =
	"Scalar of lerp between center sampling and previous frame sampling.";
	ui_category = "Motion Blur - Advanced";
> = 0.20;

uniform float  UI_BLUR_BLUE_THRESHOLD <
	ui_min = 0.000050; ui_max = 0.001000; ui_step = 0.000001;
	ui_type = "slider";
	ui_label = "Blue Noise Threshold";
	ui_tooltip =
	"Threshold of the velocity vector length before blue noise sampling kicks in.";
	ui_category = "Motion Blur - Advanced";
> = 0.000125;

#if DEPTH_ENABLE
uniform float  UI_BLUR_DEPTH_WEIGHT <
	ui_label = "Blur Depth Weight";
	ui_min = 0.0;
	ui_max = 1000.0;
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
uniform bool UI_GAIN_THRESHOLD_DEBUG
<
	ui_label = "Fake Gain Threshold Debug";
	ui_tooltip =
	"Show Gain Threshold.";
	ui_category = "HDR Simulation";
> = false;

uniform bool UI_GAIN_SCALE_DEBUG
<
	ui_label = "Debug with scale applied";
	ui_tooltip =
	"Show Gain Threshold with scale applied.";
	ui_category = "HDR Simulation";
> = false;

uniform float UI_GAIN_SCALE <
	ui_label = "Fake Gain Scale";
	ui_min = 0.0;
	ui_max = 600.0;
	ui_step = 1;
	ui_type = "slider";
	ui_tooltip =
	"Scale the contribution of gain to blurred pixels."
	"\n" "\n" "0.0 is basically no gain, while 10.0 is heavily boosted highlights. Set to 1.0 for fairly neutral boost.";
	ui_category = "HDR Simulation";
> = 550.0;

uniform float UI_GAIN_THRESHOLD <
	ui_label = "Fake Gain Threshold";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_type = "slider";
	ui_tooltip =
	"Pixels with luminance above this value will be boosted.";
	ui_category = "HDR Simulation";
> = 0.9;

uniform float UI_GAIN_THRESHOLD_SMOOTH <
	ui_label = "Fake Gain Smoothness";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.01;
	ui_type = "slider";
	ui_tooltip =
	"Thresholding that smoothly interpolates between max and min value of luminance.";
	ui_category = "HDR Simulation";
> = 0.9;
#endif

namespace HDRShaders
{
	// Textures & Samplers
	texture DepthBufferTexture : DEPTH;
	sampler SamplerDepth
	{
		Texture = DepthBufferTexture;
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

// Namespace
}


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
	float4 ProcessedDepth = GetLinearizedDepth(HDRShaders::SamplerDepth, texcoord).xxxx;
	float NormalizeDepth = normalize(ProcessedDepth.xyzw).x;

	if (NormalizeDepth.x >= 0.9999999)
		ProcessedDepth = 0.f;
	return ProcessedDepth;
}
#endif

// Main Pixel Shader
float4 BlurPS(float4 p : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	uint inColorSpace = UI_IN_COLOR_SPACE;

	static float2 Velocity = tex2D(SamplerMotionVectors2, texcoord).xy;
	static float2 VelocityTimed = Velocity / frametime;
	float2 BlurDist = 0;

	#if DEPTH_ENABLE
		float4 Depthbuffer = CircularBlur(HDRShaders::SamplerDepthProcessed, texcoord, UI_BLUR_DEPTH_BLUR_EDGES, UI_BLUR_DEPTH_BLUR_SAMPLES, 1);
		float4 DepthBufferScaled = saturate(min(pow((1.0 - Depthbuffer.xyzw), UI_BLUR_DEPTH_WEIGHT), 1));

		BlurDist = VelocityTimed * VELOCITY_SCALE * (DepthBufferScaled.xx) * UI_BLUR_LENGTH;
	#else
		BlurDist = VelocityTimed * VELOCITY_SCALE * UI_BLUR_LENGTH;
	#endif

	// Clamp large displacements
	BlurDist = ClampMotionVector(BlurDist, UI_BLUR_LENGTH_CLAMP/10);
	static const float HalfSampleSwitch = HALF_SAMPLES * (UI_BLUR_CENTER_SAMPLING);
	static const float HalfSampleSwitchInv = HALF_SAMPLES * (1.0 - UI_BLUR_CENTER_SAMPLING);
	static const float SamplesMinusOne = BLUR_SAMPLES - 1;
	float2 SampleDist = (BlurDist / SamplesMinusOne) * (lerp(1, 0.5, UI_BLUR_CENTER_SAMPLING));
	float SampleDistVector = dot(SampleDist, 0.25);

	// Define control points for the cubic Bezier curve
	static const float2 p0 = texcoord;
	float2 p1 = texcoord + BlurDist * 0.33;
	float2 p2 = texcoord + BlurDist * 0.66;
	float2 p3 = texcoord + BlurDist;

	float4 SummedSamples = 0;
	float4 Sampled = 0;
	float4 Color = tex2D(ReShade::BackBuffer, texcoord);
	float2 NoiseOffset = 0;
	if (abs(SampleDistVector) > UI_BLUR_BLUE_THRESHOLD)
	{
		NoiseOffset = BlueNoise(texcoord + SampleDist * (0 - HalfSampleSwitch)) * 0.001);
		Sampled += float3(1, 0, 0);
	}

	if (UI_BLUR_CURVE == 1)
	{
		// Blur Loop - Bezier
		for (float s = 0.0; s <= 1.0; s += 1.0 / SamplesMinusOne)
		{
			float2 SampleCoord = BezierCurveCubic(p0, p1, p2, p3, s);
			Sampled = tex2D(ReShade::BackBuffer, SampleCoord + SampleDist * (s - HalfSampleSwitchInv) + (NoiseOffset * UI_BLUR_BLUE_NOISE * 2));

			if (UI_BLUR_BLUE_NOISE_DEBUG)
			{
				if (abs(SampleDistVector) > UI_BLUR_BLUE_THRESHOLD)
				{
					Sampled += float3(1, 0, 0);
				}
			}
			// HDR10 BT.2020 PQ
			[branch]
			if (inColorSpace == 2)
			{
				Sampled.rgb = clamp(Sampled.rgb, -FLT16_MAX, FLT16_MAX);
				Sampled.rgb = PQToLinear(Sampled.rgb);
			}

			#if LINEAR_CONVERSION
				Sampled.rgb = sRGBToLinear_Safe(Sampled.rgb);
			#endif

			SummedSamples += Sampled;
			Color.rgb = max(Color.rgb, Sampled.rgb);
		}
		SummedSamples /= SamplesMinusOne;
	}

	else if (UI_BLUR_CURVE == 0)
	{
		// Blur Loop - Linear
		for (int s = 0; s < BLUR_SAMPLES; s++)
		{
			Sampled = tex2D(ReShade::BackBuffer, texcoord + SampleDist * (s - HalfSampleSwitchInv) + (NoiseOffset * UI_BLUR_BLUE_NOISE));

			// HDR10 BT.2020 PQ
			[branch]
		    if (inColorSpace == 2)
		    {
		    	Sampled.rgb = clamp(Sampled.rgb, -FLT16_MAX, FLT16_MAX);
		        Sampled.rgb = PQToLinear(Sampled.rgb);
		    }

		    #if LINEAR_CONVERSION
		        Sampled.rgb = sRGBToLinear_Safe(Sampled.rgb);
		    #endif

			SummedSamples += Sampled / BLUR_SAMPLES;
			Color.rgb = max(Color.rgb, Sampled.rgb);
		}
	}

	// Luma Luminance
	//float LuminanceLuma = dot(SummedSamples.rgb, inColorSpace == 1 || inColorSpace == 2 ? lumCoeffHDR : lumCoeffsRGB);

	// OKLab Luminance
	static const float OklabLightness = RGBToOKLab(SummedSamples.rgb)[0];
	static const float OklabLuminance = OklabLightness * OklabLightness * OklabLightness * OklabLightness;
	float Luminance = OklabLuminance;
	if (Luminance < 0.0001f)
	{
		Luminance = -0.0001f;
	}
	static const float ClampedLuminance = clamp(Luminance, 0.0, Luminance/Luminance);

	float4 Finalcolor = 0.0;
	float Gain = 0.0;

	[branch]
	    #if FAKE_GAIN
	    [branch]
	    if (inColorSpace == 1 || inColorSpace == 2)
	    {
	    // Refined approach specifically for HDR
	    	if (UI_GAIN_SCALE > 0.0)
	    	{
		        Gain = smoothstep(UI_GAIN_THRESHOLD - UI_GAIN_THRESHOLD_SMOOTH * Luminance, UI_GAIN_THRESHOLD * pow(FLT16_MAX * Luminance, 0.5), Luminance);
				Gain *= pow(UI_GAIN_SCALE, UI_GAIN_SCALE * 0.002);
				Gain = BrightnessLimiter(ClampedLuminance, Gain);
				//Gain = max(Gain, 0.f);
			}
		}
	    else
	    {
	    	if (UI_GAIN_SCALE > 0.0)
	    	{
		        Gain = smoothstep(UI_GAIN_THRESHOLD - UI_GAIN_THRESHOLD_SMOOTH, UI_GAIN_THRESHOLD, saturate(Luminance));
				Gain *= UI_GAIN_SCALE;
		    /* Old approach made in nightmarish SDR days

		        Gain = smoothstep(UI_GAIN_THRESHOLD - UI_GAIN_THRESHOLD_SMOOTH, UI_GAIN_THRESHOLD, luminance);
				Gain *= smoothstep(-UI_GAIN_THRESHOLD_SMOOTH, 1.0, luminance);
				Gain *= UI_GAIN_SCALE;
			*/
			}
		}
	    #endif

	[branch]
	    #if FAKE_GAIN
	        Finalcolor = SaturationBrightnessLimiter(Color.rgb , SummedSamples.rgb * (1.0 - Gain) + Color.rgb * Gain);
			if (UI_GAIN_THRESHOLD_DEBUG)
			{
				Finalcolor = UI_GAIN_SCALE_DEBUG ? Gain.rrrr : Gain.rrrr / UI_GAIN_SCALE;
			}
	    #else
	        Finalcolor = SummedSamples;
	    #endif

	[branch]
	    #if LINEAR_CONVERSION
	        Finalcolor.rgb = LinearTosRGB_Safe(Finalcolor.rgb);
	    #endif

	// HDR10 BT.2020 PQ
	if (inColorSpace == 2)
	{
		Finalcolor.rgb = fixNAN(Finalcolor.rgb);
		Finalcolor.rgb = LinearToPQ(Finalcolor.rgb);
	}

	// SDR
	if (inColorSpace == 0)
	{
		Finalcolor *= 1.0 / max(dot(SummedSamples.rgb, lumCoeffsRGB), 1.0);
		clamp(Finalcolor, 0.0, 1.0);
	}

	#if DEPTH_ENABLE
		Finalcolor = UI_SHOW_DEPTH ? DepthBufferScaled.xxxx : Finalcolor;
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
		RenderTarget = HDRShaders::DepthProcessedTex;
	}
	#endif

	pass MotionBlurPass
	{
		VertexShader = PostProcessVS;
		PixelShader = BlurPS;
	}
}