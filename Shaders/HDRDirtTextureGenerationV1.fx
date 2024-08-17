/**
// - Reshade HDR Dirt Texture Generation shader
// - Ported from the following shadertoy example: https://www.shadertoy.com/view/7sXBWl#
// - Tweaks and edits by MaxG3D
 **/

// Includes
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "HDRShadersFunctions.fxh"

// Defines

// Defines
#ifndef DIRT_TEXTURE_TWEAKING
#define DIRT_TEXTURE_TWEAKING 0
#endif

namespace HDRShaders
{

// UI
uniform int UI_DIRT_OCTAVES
<
	ui_min = 1; ui_max = 8;
	ui_label = "";
	ui_tooltip = "";
	ui_type = "slider";
> = 3;

uniform int UI_DIRT_SHOW
<
	ui_min = 0; ui_max = 1;
	ui_label = "";
	ui_tooltip = "";
	ui_type = "slider";
> = 0;

uniform float UI_DIRT_AMPLITUDE <
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.55;

uniform float UI_DIRT_SEED <
	ui_min = 0.0; ui_max = 6.28;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 1.61;

uniform float UI_DIRT_WARP <
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.40;

uniform float UI_DIRT_UVSCALE <
	ui_min = 0.5; ui_max = 10.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 1.25;

uniform float UI_DIRT_POWER <
	ui_min = 1.0; ui_max = 10.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 4.00;

uniform float UI_DIRT_CLAMP <
	ui_min = 0.01; ui_max = 1.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.01;
	ui_type = "slider";
> = 0.05;

uniform float UI_DIRT_SCRATCHES <
	ui_min = 0.01; ui_max = 1.0;
	ui_label = "";
	ui_tooltip = "";
	ui_step = 0.001;
	ui_type = "slider";
> = 0.035;

//  Textures & Samplers
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
		AddressU = Clamp;
		AddressV = Clamp;
};

float3 cyclicNoise(float3 p, float amp, float warp, float rot_angle, int octaves) {
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

float3 getNoise(float2 uv, float amp, float warp, float rot_angle, int octaves, float power) {
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

float3 NoiseTextureGenerationPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 noise = 0.0;
	noise += getNoise(texcoord * UI_DIRT_UVSCALE, UI_DIRT_AMPLITUDE, UI_DIRT_WARP, UI_DIRT_SEED, UI_DIRT_OCTAVES, UI_DIRT_POWER);
	return min(noise, UI_DIRT_CLAMP);
}

float4 DirtTextureGenerationPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
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

float4 BlendTexturesPS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 DirtTexture = tex2D(SamplerDirtTexture, texcoord);
	DirtTexture += CircularBlur(SamplerDirtTexture, texcoord, 2.0, 24, 1) /2;
	float4 color = tex2D(ReShade::BackBuffer, texcoord);
	color.xyz = lerp(color.xyz, DirtTexture.xyz, saturate(UI_DIRT_SHOW));
	return float4(color.xyz, 1.0);
}

technique HDRDirtTextureGenerationV1 < 
#if DIRT_TEXTURE_TWEAKING == 0
enabled = true; timeout = 1;
#endif
ui_label = "HDRDirtTextureGenerationV1";
ui_tooltip = "This Shader suppose to run only once per game to generate dirt texture for bloom"; >

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
	
	pass BlendTextures
	{
		VertexShader = PostProcessVS;
		PixelShader = BlendTexturesPS;
	}
}

//Namespace
}