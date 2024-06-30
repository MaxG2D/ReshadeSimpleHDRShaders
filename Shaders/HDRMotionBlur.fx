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

#ifndef FAKE_GAIN_REJECT
#define FAKE_GAIN_REJECT 0
#endif

#ifndef DEPTH_ENABLE
#define DEPTH_ENABLE 0
#endif

#define VELOCITY_SCALE 50.0
#define HALF_SAMPLES (UI_BLUR_SAMPLES_MAX / 2)

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

uniform uint IN_COLOR_SPACE
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
> = 0.75;


#if DEPTH_ENABLE
uniform float  UI_BLUR_DEPTH_WEIGHT <
	ui_label = "Blur Depth Weight";
    ui_min = 0.0;
    ui_max = 32.0;
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

uniform bool ShowDepth
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

uniform int UI_GAIN_THRESHOLD_METHOD <
	ui_type = "combo";
    ui_label = "Fake Gain Threshold method";
    ui_items = "Soft\0Hard\0";
    ui_tooltip = 
	"Soft is more natural looking but gain have to be more artifically raised.\n"
	"Hard is better for preserving highlights";
	ui_min = 0; 
    ui_max = 1;
    ui_category = "HDR Simulation";
> = 0;

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

#if FAKE_GAIN_REJECT
uniform float UI_GAIN_REJECT <
    ui_label = "Fake Gain Reject";
    ui_min = 0.0;
    ui_max = 10.0;
    ui_step = 0.01;
	ui_type = "slider";
    ui_tooltip = 
	"This is used for rejecting neighbouring pixels if they are too bright,\n"
	"\nto avoid flickering in overly bright scens. 0.0 disables this function completely.";
    ui_category = "HDR Simulation";
> = 0.00;

uniform float UI_GAIN_REJECT_RANGE <
    ui_label = "Fake Gain Reject Range";
    ui_min = 0.01;
    ui_max = 10.0;
    ui_step = 0.01;
	ui_type = "slider";
    ui_tooltip = 
	"Distance to sample neighbor pixels for rejecting";
    ui_category = "HDR Simulation";
> = 3.50;
#endif

//  Textures & Samplers
texture texColor : COLOR;
sampler samplerColor 
{ 
	Texture = texColor;	
	AddressU = Clamp; AddressV = Clamp; MipFilter = Linear; MinFilter = Linear; MagFilter = Linear; 
};

texture texDepth : DEPTH;
sampler samplerDepth
{ 
	Texture = texDepth;	
	//AddressU = Clamp; AddressV = Clamp; MipFilter = Linear; MinFilter = Linear; MagFilter = Linear; 
};

texture texDepthProcessed
{
		Width = BUFFER_WIDTH; 
		Height = BUFFER_HEIGHT; 
		//Format = RGBA16F; 
		//MipLevels = 1; 
};
sampler samplerDepthProcessed
{
	    Texture = texDepthProcessed;
	    MinFilter = LINEAR;
	    MagFilter = LINEAR;
	    //AddressU = Border;
	    //AddressV = Border;
};

texture texMotionVectors          { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RG16F; };
sampler SamplerMotionVectors2 { Texture = texMotionVectors; AddressU = Clamp; AddressV = Clamp; MipFilter = Point; MinFilter = Point; MagFilter = Point; };

#if DEPTH_ENABLE
float4 DepthProcessPS(float4 p : SV_Position, float2 texcoord : TEXCOORD ) : SV_Target
{
	return GetLinearizedDepth(samplerDepth, texcoord).xxxx;
}
#endif

// Pixel Shader
float4 BlurPS(float4 p : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{		  
    float2 velocity = tex2D(SamplerMotionVectors2, texcoord).xy;
    float2 velocityTimed = velocity / frametime;
    float2 blurDist = 0;    
    #if DEPTH_ENABLE
        float4 depthbuffer = CircularBlur(samplerDepthProcessed, texcoord, UI_BLUR_DEPTH_BLUR_EDGES, UI_BLUR_DEPTH_BLUR_SAMPLES, 1);
        float4 depthBufferScaled = saturate(min(pow((1.0 - depthbuffer.xyzw), UI_BLUR_DEPTH_WEIGHT), 1));  
        
        blurDist = velocityTimed * VELOCITY_SCALE * (depthBufferScaled.xx) * UI_BLUR_LENGTH;            
    #else
        blurDist = velocityTimed * VELOCITY_SCALE * UI_BLUR_LENGTH;            
    #endif   
    float2 sampleDist = blurDist / UI_BLUR_SAMPLES_MAX;
    float sampleDistVector = dot(sampleDist, 1.0);
    float4 summedSamples = 0;
    float4 sampled = 0;
    float4 color = tex2D(samplerColor, texcoord);
    uint inColorSpace = IN_COLOR_SPACE;
    float2 noiseOffset = 0;
    if (abs(sampleDistVector) > 0.001)
    {
        noiseOffset = BlueNoise(texcoord - sampleDist * (0 - HALF_SAMPLES)) * 0.001); // Calculate noiseOffset for the first sample
    }
    
    // Perform blur sampling
    for (int s = 0; s < UI_BLUR_SAMPLES_MAX; s++)
    {
        sampled = tex2D(samplerColor, texcoord - sampleDist * (s - HALF_SAMPLES) + (noiseOffset * UI_BLUR_BLUE_NOISE));
        
        if (inColorSpace == 2) // HDR10 BT.2020 PQ
        {
            sampled.rgb = PQ_to_linear(sampled.rgb);
            sampled.rgb = BT2020_2_BT709(sampled.rgb);
        }
        
        #if LINEAR_CONVERSION
            sampled.rgb = sRGB_to_linear(sampled.rgb);            
        #endif
        
        summedSamples += sampled / UI_BLUR_SAMPLES_MAX;
        color.rgb = max(color.rgb, sampled.rgb);
    }
	
	float luminance = dot(summedSamples.rgb, inColorSpace == 1 || inColorSpace == 2 ? lumCoeffHDR : lumCoeffsRGB);
	
	float4 finalcolor = 0.0;
	float gain = 0.0;
	float reject = 1.0;
	
		#if FAKE_GAIN
		// (this function is crazy, I know :/)
		[branch]
		if (inColorSpace == 1 || inColorSpace == 2) {
		    if (UI_GAIN_THRESHOLD_METHOD > 0) {
		        gain = luminance > UI_GAIN_THRESHOLD * 10 ? UI_GAIN_SCALE : smoothstep(0.0, luminance, UI_GAIN_SCALE * UI_GAIN_THRESHOLD_SMOOTH);
		    } else {
		        gain = abs(pow(smoothstep(UI_GAIN_THRESHOLD - UI_GAIN_THRESHOLD_SMOOTH, UI_GAIN_THRESHOLD * 10, luminance), UI_GAIN_POWER) * smoothstep(-UI_GAIN_THRESHOLD_SMOOTH, 1.0, luminance) * UI_GAIN_SCALE);
		    }
		} else {
		    if (UI_GAIN_THRESHOLD_METHOD > 0) {
		        gain = luminance > UI_GAIN_THRESHOLD ? UI_GAIN_SCALE : smoothstep(0.0, luminance, UI_GAIN_SCALE * UI_GAIN_THRESHOLD_SMOOTH);
		    } else {
		        gain = pow(smoothstep(UI_GAIN_THRESHOLD - UI_GAIN_THRESHOLD_SMOOTH, UI_GAIN_THRESHOLD, luminance), UI_GAIN_POWER) * smoothstep(-UI_GAIN_THRESHOLD_SMOOTH, 1.0, luminance) * UI_GAIN_SCALE;
		    }
		}
		#endif
	
			#if FAKE_GAIN_REJECT
			// Rejection Function 
			if (UI_GAIN_REJECT > 0.01)
			{
				float2 texCoordOffset = sampleDist * (UI_BLUR_SAMPLES_MAX * UI_GAIN_REJECT_RANGE);
				float neighborLuminance = 0.0;
				float luminanceRatio = 0.0;
				float totalWeight = 0.0;
				float neighborLum = 0.0;
				for (int i = 0; i < UI_BLUR_SAMPLES_MAX; i++)
				{
					float2 neighborTexCoord = texcoord - sampleDist * (i - HALF_SAMPLES) * UI_GAIN_REJECT_RANGE;
					neighborLum = dot(tex2D(samplerColor, neighborTexCoord).rgb, inColorSpace == 1 || inColorSpace == 2 ? lumCoeffHDR : lumCoeffsRGB);
		            float luminanceDiff = neighborLum - luminance;
					float distanceWeight = exp(-(length(normalize(sampleDist * (i - HALF_SAMPLES))) + luminanceDiff) / (UI_BLUR_SAMPLES_MAX * UI_GAIN_REJECT_RANGE));
					neighborLuminance += neighborLum * distanceWeight;
					totalWeight += distanceWeight;
					[branch]
					if (neighborLum > luminance) {
						luminanceRatio += luminance / neighborLum;
					} else {
						luminanceRatio += neighborLum / luminance;
					}
				}
				neighborLuminance /= totalWeight;
				float avgLuminanceRatio = luminanceRatio / UI_BLUR_SAMPLES_MAX;
				float rejectThreshold = smoothstep(0.0, gain, avgLuminanceRatio);
				reject = 1.0 - smoothstep(0.0, gain, rejectThreshold * UI_GAIN_REJECT);
			}
				
			if (FAKE_GAIN_REJECT > 0) 
			{
				[branch]
				if (inColorSpace == 1 || inColorSpace == 2) {
					gain = gain * reject;
				} else {
					gain = saturate(gain * reject);
				}
			}	
			#endif
	
		[branch]
		#if FAKE_GAIN 
			finalcolor = summedSamples * (1.0 - gain) + color * gain;
		#else 
			finalcolor = summedSamples;
		#endif
		
		if (inColorSpace == 0) 
		{
			finalcolor *= 1.0 / max(dot(summedSamples.rgb, lumCoeffsRGB), 1.0);
			clamp(finalcolor, 0.0, 1.0);
		}
	
	    if (inColorSpace == 2) // HDR10 BT.2020 PQ
	    {
	        finalcolor.rgb = BT709_2_BT2020(finalcolor.rgb);
	        finalcolor.rgb = linear_to_PQ(finalcolor.rgb);
	    }
	
		#if LINEAR_CONVERSION
			finalcolor.rgb = linear_to_sRGB(finalcolor.rgb);
		#endif
	
		#if DEPTH_ENABLE
		finalcolor = ShowDepth
			? depthBufferScaled.xxxx
			: finalcolor;
		#endif
	
	return finalcolor;
}

technique HDRMotionBlur
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
