/**	All credits go to respective authors like:
*	Lilium
*	Pumbo
*	All the people that worked on defining the standards
*
*	Tweaks and edits by MaxG3D
*
*	Special thanks to SpecialK, and HDR Den server
**/

#pragma once

#pragma warning(disable : 3571) // disable warning about potentially using pow on a negative value

/////////////////////////////////////////////
//DEFINITIONS
/////////////////////////////////////////////

// These are from the "color_space" enum in ReShade
#define RESHADE_COLOR_SPACE_SDR        	0
#define RESHADE_COLOR_SPACE_SCRGB       	1
#define RESHADE_COLOR_SPACE_BT2020_PQ   	2

// This uses the enum values defined in "IN_COLOR_SPACE"
#define DEFAULT_COLOR_SPACE 1

// "BUFFER_COLOR_SPACE" is defined by ReShade.
// "ACTUAL_COLOR_SPACE" uses the enum values defined in "IN_COLOR_SPACE".
#if BUFFER_COLOR_SPACE == RESHADE_COLOR_SPACE_SRGB
  #define ACTUAL_COLOR_SPACE 0
#elif BUFFER_COLOR_SPACE == RESHADE_COLOR_SPACE_SCRGB
  #define ACTUAL_COLOR_SPACE 1
#elif BUFFER_COLOR_SPACE == RESHADE_COLOR_SPACE_BT2020_PQ
  #define ACTUAL_COLOR_SPACE 2
#else
  #define ACTUAL_COLOR_SPACE 1
#endif

#define PI 3.1415927410125732421875f
#define TAU 6.2831854820251464843750f

#define UINT_MAX 4294967295
#define  INT_MAX 2147483647
#define MIN3(A, B, C) min(A, min(B, C))
#define MAX3(A, B, C) max(A, max(B, C))
#define MAX4(A, B, C, D) max(A, max(B, max(C, D)))
#define MAX5(A, B, C, D, E) max(A, max(B, max(C, max(D, E))))
#define MAXRGB(Rgb) max(Rgb.r, max(Rgb.g, Rgb.b))
#define MINRGB(Rgb) min(Rgb.r, min(Rgb.g, Rgb.b))
#define lumCoeffHDR float3(0.2627f, 0.6780f, 0.0593f)
#define lumCoeffAP1_RGB2Y float3(0.2722287168f, 0.6740817658f, 0.0536895174f)
#define lumCoeffsRGB float3(0.299f, 0.587f, 0.114f)
#define lumCoeffLinear float3(0.2126f, 0.7152f, 0.0722f)
#define FP32_MIN asfloat(0x00800000)
#define FP32_MAX asfloat(0x7F7FFFFF)
#define FLT16_MAX 65504.f

uniform float frametime < source = "frametime"; >;
//uniform int framecount < source = "framecount"; >;
uniform float2 mouse_delta < source = "mousedelta"; >;
uniform float2 mouse_point < source = "mousepoint"; >;
uniform bool overlay_open < source = "overlay_open"; >;


/////////////////////////////////////////////
//NOISE GENERATION
/////////////////////////////////////////////

//HASH NOISE - VERSION 1

#define ORTH_BASIS(z, basis) { \
	z = normalize(z); \
	float3 up = abs(z.y) > 0.999 ? float3(0.0, 0.0, 1.0) : float3(0.0, 1.0, 0.0); \
	float3 x = normalize(cross(up, z)); \
	float3 y = cross(z, x); \
	basis = float3x3(x, y, z); \
}
#define ROT(a, rotMat) { \
	float c = cos(a); \
	float s = sin(a); \
	rotMat = float2x2(c, -s, s, c); \
}
float3x3 orthBasis(float3 z) {
	float3x3 basis;
	ORTH_BASIS(z, basis);
	return basis;
}
float2x2 _rot(float a) {
	float2x2 rotMat;
	ROT(a, rotMat);
	return rotMat;
}

#define HASH_SCALE float3(0.1031, 0.1030, 0.0973)
#define DOT_ADD float3(33.33, 33.33, 33.33)

#define HASH33(p3, result) { \
	p3 = frac(p3 * HASH_SCALE); \
	p3 += dot(p3, p3.yxz + DOT_ADD); \
	result = frac((p3.xxy + p3.yxx) * p3.zyx); \
}

float3 hash33(float3 p3) {
	float3 result;
	HASH33(p3, result);
	return result;
}


//HASH NOISE - VERSION 2

#define hash(n) (frac(sin(n) * 43758.5453123))

//BLUE NOISE

#define NoiseScale float2(12.9898, 78.2330)		//12.9898, 78.2330
#define NoiseStrength (20000)	   					//43758.5453
#define BlendFactor (1/9.0)						//0.5/9.0
#define ScaleFactor (1.5)							//2.1
#define BiasFactor (0.3) 							//0.5

// Blue Noise: https://www.shadertoy.com/view/7sGBzW
#define HASH(p) (sin(dot(p, NoiseScale + frametime)) * NoiseStrength - floor(sin(dot(p, NoiseScale + frametime)) * NoiseStrength))
#define BlueNoise(p) ( \
	( \
	(  HASH(p+float2(-1,-1)) + HASH(p+float2(0,-1)) + HASH(p+float2(1,-1))  \
	+ HASH(p+float2(-1, 0)) - 8.* HASH( p )      + HASH(p+float2(1, 0))  \
	+ HASH(p+float2(-1, 1)) + HASH(p+float2(0, 1)) + HASH(p+float2(1, 1))  \
	) * BlendFactor * ScaleFactor + BiasFactor )

/////////////////////////////////////////////
//STATIC CONST
/////////////////////////////////////////////

static const float sRGB_max_nits = 80.f;
static const float ReferenceWhiteNits_BT2408 = 203.f;
static const float sourceHDRWhitepoint = 80.f / sRGB_max_nits;
static const float HDR10_max_nits = 10000.f;
static const float mid_gray = 0.18f;

static const float PQ_constant_N = (2610.0 / 4096.0 / 4.0);
static const float PQ_constant_M = (2523.0 / 4096.0 * 128.0);
static const float PQ_constant_C1 = (3424.0 / 4096.0);
static const float PQ_constant_C2 = (2413.0 / 4096.0 * 32.0);
static const float PQ_constant_C3 = (2392.0 / 4096.0 * 32.0);
static const float PQMaxWhitePoint = HDR10_max_nits / sRGB_max_nits;

static const float3 BT2020_PrimaryRed = float3(0.6300, 0.3400, 0.0300);
static const float3 BT2020_PrimaryGreen = float3(0.3300, 0.6000, 0.0800);
static const float3 BT2020_PrimaryBlue = float3(0.1500, 0.0600, 1.0000);
static const float3 BT2020_WhitePoint = float3(0.3127, 0.3290, 0.3583);

/////////////////////////////////////////////
//STATIC CONST - GAUSSIAN KERNELS
/////////////////////////////////////////////

//Sigma 1
static const float Weights5[5] =
{
  0.0613595978134402f,
  0.24477019552960988f,
  0.38774041331389975f,
  0.24477019552960988f,
  0.0613595978134402f
};

//Sigma 1.4
static const float Weights7[7] =
{
  0.03050260371857921f,
  0.10546420324961808f,
  0.2218866945336653f,
  0.28429299699627486f,
  0.2218866945336653f,
  0.10546420324961808f,
  0.03050260371857921f
};

//Sigma 2.2
static const float Weights11[11] =
{
  0.014642062351313795f,
  0.03622922216280118f,
  0.0732908252747015f,
  0.1212268244846623f,
  0.163954439140855f,
  0.18131325317133223f,
  0.163954439140855f,
  0.1212268244846623f,
  0.0732908252747015f,
  0.03622922216280118f,
  0.014642062351313795f
};

//Sigma 2.6
static const float Weights13[13] =
{
  0.011311335636445246f,
  0.02511527845053647f,
  0.04823491379898901f,
  0.08012955958832953f,
  0.11514384884108936f,
  0.14312253396755542f,
  0.1538850594341098f,
  0.14312253396755542f,
  0.11514384884108936f,
  0.08012955958832953f,
  0.04823491379898901f,
  0.02511527845053647f,
  0.011311335636445246f
};

/////////////////////////////////////////////
//CONVERSIONS - CHROMA
/////////////////////////////////////////////

static const float3x3 XYZ_2_sRGB_MAT = float3x3(
	3.2409699419, -1.5373831776, -0.4986107603,
	-0.9692436363, 1.8759675015, 0.0415550574,
	0.0556300797, -0.2039769589, 1.0569715142);
static const float3x3 sRGB_2_XYZ_MAT = float3x3(
	0.4124564, 0.3575761, 0.1804375,
	0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041);
static const float3x3 XYZ_2_AP1_MAT = float3x3(
	1.6410233797, -0.3248032942, -0.2364246952,
	-0.6636628587, 1.6153315917, 0.0167563477,
	0.0117218943, -0.0082844420, 0.9883948585);
static const float3x3 AP1_2_XYZ_MAT = float3x3(
	0.6624541811, 0.1340042065, 0.1561876870,
	0.2722287168, 0.6740817658, 0.0536895174,
	-0.0055746495, 0.0040607335, 1.0103391003);
static const float3x3 D65_2_D60_CAT = float3x3(
	1.01303, 0.00610531, -0.014971,
	0.00769823, 0.998165, -0.00503203,
	-0.00284131, 0.00468516, 0.924507);
static const float3x3 D60_2_D65_CAT = float3x3(
	0.987224, -0.00611327, 0.0159533,
	-0.00759836, 1.00186, 0.00533002,
	0.00307257, -0.00509595, 1.08168);
static const float3x3 Wide_2_XYZ_MAT = float3x3(
	0.5441691, 0.2395926, 0.1666943,
	0.2394656, 0.7021530, 0.0583814,
	-0.0023439, 0.0361834, 1.0552183);
static const float3x3 BT709_2_BT2020_MAT = float3x3(
	0.627401924722236, 0.329291971755002, 0.0433061035227622,
	0.0690954897392608, 0.919544281267395, 0.0113602289933443,
	0.0163937090881632, 0.0880281623979006, 0.895578128513936);
static const float3x3 BT2020_2_BT709_MAT = float3x3(
	1.66049621914783, -0.587656444131135, -0.0728397750166941,
	-0.124547095586012, 1.13289510924730, -0.00834801366128445,
	-0.0181536813870718, -0.100597371685743, 1.11875105307281);

static const float3x3 XYZ_2_BT2020_MAT = float3x3(
	0.6369580483, 0.1446169032, 0.1688809751,
	0.2627002120, 0.6779980715, 0.0593017165,
	0.0000000000, 0.0280726930, 1.0609850576);

static const float3x3 BT2020_2_XYZ_MAT = float3x3(
	1.71665118797126, -0.355670783776392, -0.253366281373659,
	-0.666684351832489, 1.61648123663494, 0.015768545813911,
	0.0176398574453105, -0.0427706132578086, 0.942103121235473);

static const float3x3 AP1_2_BT2020_MAT = float3x3(
	1.6410233797, -0.3248032942, -0.2364246952,
	-0.6636628587, 1.6153315917, 0.0167563477,
	0.0117218943, -0.0082844420, 0.9883948585);

static const float3x3 BT2020_2_AP1_MAT = float3x3(
	0.6624541811, 0.1340042065, 0.1561876870,
	0.2722287168, 0.6740817658, 0.0536895174,
	-0.0055746495, 0.0040607335, 1.0103391003);

static const float3x3 XYZ_2_LMS_MAT = float3x3(
	0.4002, 0.7075, -0.0808,
	-0.2263, 1.1653, 0.0457,
	0.0000, 0.0000, 0.9182);


/////////////////////////////////////////////
//CONVERSIONS - CHROMA (FUNCTIONS)
/////////////////////////////////////////////

float3 XYZ_2_sRGB_MAT(float3 color)
{
	return mul(XYZ_2_sRGB_MAT, color);
}
float3 sRGB_2_XYZ_MAT(float3 color)
{
	return mul(sRGB_2_XYZ_MAT, color);
}


float3 XYZ_2_AP1_MAT(float3 color)
{
	return mul(XYZ_2_AP1_MAT, color);
}
float3 AP1_2_XYZ_MAT(float3 color)
{
	return mul(AP1_2_XYZ_MAT, color);
}


float3 BT709_2_BT2020_MAT(float3 color)
{
	return mul(BT709_2_BT2020_MAT, color);
}
float3 BT2020_2_BT709_MAT(float3 color)
{
	return mul(BT2020_2_BT709_MAT, color);
}


float3 XYZ_2_BT2020_MAT(float3 color)
{
	return mul(XYZ_2_BT2020_MAT, color);
}
float3 BT2020_2_XYZ_MAT(float3 color)
{
	return mul(BT2020_2_XYZ_MAT, color);
}


float3 AP1_2_BT2020_MAT(float3 color)
{
	return mul(AP1_2_BT2020_MAT, color);
}
float3 BT2020_2_AP1_MAT(float3 color)
{
	return mul(BT2020_2_AP1_MAT, color);
}

/////////////////////////////////////////////
//NAN-INF FIX
/////////////////////////////////////////////

float Luminance(float3 color, float3 lumCoeff)
{
	return dot(color, lumCoeff);
}

bool IsNAN(const float input)
{
	if (isnan(input) || isinf(input))
		return true;
	else
		return false;
}

float fixNAN(const float input)
{
	if (IsNAN(input))
		return 0.f;
	else
		return input;
}

float3 fixNAN(float3 input)
{
	if (IsNAN(input.r))
		input.r = 0.f;
	else if (IsNAN(input.g))
		input.g = 0.f;
	else if (IsNAN(input.b))
		input.b = 0.f;

	return input;
}

float SafeDivide(float a, float b)
{
	return (b != 0.0f) ? a / b : 0.0f;
}

float SafePow(float input, float exponent) {
  return sign(input) * pow(abs(input), exponent);
}

float3 SafePow(float3 color, float exponent) {
  return sign(color) * pow(abs(color), exponent);
}

float FastPow(float base, float exponent)
{
	return exp(exponent * log(base));
}

float3 WideColorsClamp(float3 input)
{
	const float3x3 sRGB_2_AP1 = mul(XYZ_2_AP1_MAT, mul(D65_2_D60_CAT, sRGB_2_XYZ_MAT));
	float3 ColorAP1 = mul(sRGB_2_AP1, input);

	float LumaAP1 = Luminance(ColorAP1, lumCoeffAP1_RGB2Y);
	if (LumaAP1 <= 0.f)
	{
		return input;
	}
	return input;
}

float3 GamutMapping(float3 input)
{
	input = BT709_2_BT2020_MAT(input);
	input = max(input, 0.f);
	input = BT2020_2_BT709_MAT(input);
	return input;
}

/////////////////////////////////////////////
//CONVERSIONS - LUMA
/////////////////////////////////////////////

float sRGBToLinear(float color)
{
	const float a = 0.055f;
	float result = color;
	result = (color > 0.04045f) ? FastPow((color + a) / (1.0f + a), 2.4f) : color / 12.92f;

	return result;
}

float3 sRGBToLinear(float3 color)
{
	return float3(sRGBToLinear(color.r), sRGBToLinear(color.g), sRGBToLinear(color.b));
}

float LinearTosRGB(float channel)
{
	float result = channel;
	result = (channel > 0.0031308f) ? 1.055f * FastPow(channel, 1.f / 2.4f) - 0.055f : channel * 12.92f;

	return result;
}

float3 LinearTosRGB(float3 color)
{
	return float3(LinearTosRGB(color.r), LinearTosRGB(color.g), LinearTosRGB(color.b));
}

float sRGBToLinearChannel_Safe(float channel)
{
	const float absChannel = abs(channel);
	return (channel < 0.0) ? -sRGBToLinear(absChannel) : sRGBToLinear(absChannel);
}

float LinearTosRGBChannel_Safe(float channel)
{
	const float absChannel = abs(channel);
	return (channel < 0.0) ? -LinearTosRGB(absChannel) : LinearTosRGB(absChannel);
}

float3 sRGBToLinear_Safe(float3 color)
{
	return float3(sRGBToLinearChannel_Safe(color.r), sRGBToLinearChannel_Safe(color.g), sRGBToLinearChannel_Safe(color.b));
}

float3 LinearTosRGB_Safe(float3 color)
{
	return float3(LinearTosRGBChannel_Safe(color.r), LinearTosRGBChannel_Safe(color.g), LinearTosRGBChannel_Safe(color.b));
}

float3 LinearToPQ(float3 linearCol)
{
	linearCol /= HDR10_max_nits;

	float3 colToPow = pow(linearCol, PQ_constant_N);
	float3 numerator = PQ_constant_C1 + PQ_constant_C2 * colToPow;
	float3 denominator = 1.f + PQ_constant_C3 * colToPow;
	float3 pq = pow(numerator / denominator, PQ_constant_M);

	return pq;
}

float3 PQToLinear(float3 ST2084)
{
	float3 colToPow = pow(ST2084, 1.0f / PQ_constant_M);
	float3 numerator = max(colToPow - PQ_constant_C1, 0.f);
	float3 denominator = PQ_constant_C2 - (PQ_constant_C3 * colToPow);
	//denominator = max(denominator, 1e-10f);
	float3 linearColor = pow(numerator / denominator, 1.f / PQ_constant_N);

	linearColor *= HDR10_max_nits;

	return linearColor;
}

float RangeCompressPow(float x, float Pow)
{
	return 1.0 - pow(exp(-x), Pow);
}

float LumaCompress(float val, float MaxValue, float ShoulderStart, float Pow)
{
	float v2 = ShoulderStart + (MaxValue - ShoulderStart) * RangeCompressPow((val - ShoulderStart) / (MaxValue - ShoulderStart), Pow);
	return val <= ShoulderStart ? val : v2;
}

float3 DisplayMapColor (float3 color, float luma, float HdrMaxNits)
{
	luma = Luminance(color, lumCoeffHDR);
	float maxOutputLuminance = HdrMaxNits / sRGB_max_nits;
	float compressedHDRLuminance = LumaCompress(luma, maxOutputLuminance, maxOutputLuminance, 1);
	return color * compressedHDRLuminance / luma;
}

/////////////////////////////////////////////
//OKLAB
/////////////////////////////////////////////

float3 RGBToOKLab(float3 c)
{
	float l = (0.4122214708f * c.r) + (0.5363325363f * c.g) + (0.0514459929f * c.b);
	float m = (0.2119034982f * c.r) + (0.6806995451f * c.g) + (0.1073969566f * c.b);
	float s = (0.0883024619f * c.r) + (0.2817188376f * c.g) + (0.6299787005f * c.b);

	float l_ = pow(abs(l), 1.f / 3.f) * sign(l);
	float m_ = pow(abs(m), 1.f / 3.f) * sign(m);
	float s_ = pow(abs(s), 1.f / 3.f) * sign(s);

	return float3(
		(0.2104542553f * l_) + (0.7936177850f * m_) - (0.0040720468f * s_),
		(1.9779984951f * l_) - (2.4285922050f * m_) + (0.4505937099f * s_),
		(0.0259040371f * l_) + (0.7827717662f * m_) - (0.8086757660f * s_)
	);
}

float3 OKLabToRGB(float3 c)
{
	float l_ = c.x + 0.3963377774f * c.y + 0.2158037573f * c.z;
	float m_ = c.x - 0.1055613458f * c.y - 0.0638541728f * c.z;
	float s_ = c.x - 0.0894841775f * c.y - 1.2914855480f * c.z;

	float l = l_*l_*l_;
	float m = m_*m_*m_;
	float s = s_*s_*s_;

	float3 rgb;
	rgb.r = + 4.0767245293f*l - 3.3072168827f*m + 0.2307590544f*s;
	rgb.g = - 1.2681437731f*l + 2.6093323231f*m - 0.3411344290f*s;
	rgb.b = - 0.0041119885f*l - 0.7034763098f*m + 1.7068625689f*s;
	return rgb;
}

float3 oklab_to_oklch(float3 lab) {
	float L = lab[0];
	float a = lab[1];
	float b = lab[2];
	return float3(
		L,
		sqrt((a*a) + (b*b)),
		atan2(b, a)
	);
}

float3 oklch_to_oklab(float3 lch) {
	float L = lch[0];
	float C = lch[1];
	float h = lch[2];
	return float3(
		L,
		C * cos(h),
		C * sin(h)
	);
}

float3 oklch_to_linear_srgb(float3 lch) {
	return OKLabToRGB(
			oklch_to_oklab(lch)
	);
}

float3 linear_srgb_to_oklch(float3 rgb) {
	return oklab_to_oklch(
		RGBToOKLab(rgb)
	);
}

/////////////////////////////////////////////
//MISC - FUNCTIONS
/////////////////////////////////////////////

float2 GetResolution()
{
	return float2(BUFFER_WIDTH, BUFFER_HEIGHT);
}

float2 GetPixelSize()
{
	return float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
}

float GetAspectRatio()
{
	return BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
}

float4 GetScreenParams()
{
	return float4(GetResolution(), GetPixelSize());
}

float AngleBetween(float2 v1, float2 v2)
{
	return acos(dot(normalize(v1), normalize(v2)));
}

float AverageValue(float3 Color)
{
	return dot(Color, float3(1.f / 3.f, 1.f / 3.f, 1.f / 3.f));
}

float2 ProjectOnto(float2 a, float2 b)
{
	return dot(a, b) / dot(b, b) * b;
}

/////////////////////////////////////////////
//MISC - BLURS
/////////////////////////////////////////////

float4 BoxBlur(sampler s, float2 uv, float blurSize, int DownsampleAmount)
{
	float4 color = float4(0.0, 0.0, 0.0, 0.0);
	int samples = 3;

	for (int x = -samples; x <= samples; ++x)
	{
		for (int y = -samples; y <= samples; ++y)
		{
			float2 offset = float2(x, y) * GetPixelSize() * DownsampleAmount * blurSize;
			color += tex2D(s, uv + offset);
		}
	}

	float sampleCount = (2 * samples + 1) * (2 * samples + 1);
	return color / sampleCount;
}

float4 CircularBlur(sampler s, float2 uv, float blurSize, int sampleCount, int DownsampleAmount)
{
	float4 color = float4(0.0, 0.0, 0.0, 0.0);
	float radius = blurSize;
	float sampleAngle = 2.0 * 3.14159265359 / sampleCount;

	for (int i = 0; i < sampleCount; ++i)
	{
		float angle = sampleAngle * i;
		float2 offset = float2(cos(angle), sin(angle)) * radius * GetPixelSize() * DownsampleAmount;
		color += tex2D(s, uv + offset);
	}

	return color / sampleCount;
}

float GaussianSimple(float x, float sigma)
{
	return exp(-0.5 * (x * x) / (sigma * sigma));
}

/////////////////////////////////////////////
//MISC - SAMPLING
/////////////////////////////////////////////

float2 CatmullRom(float2 p0, float2 p1, float2 p2, float2 p3, float t, float tension)
{
	float2 a = 2.0 * p1;
	float2 b = p2 - p0;
	float2 c = 2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3;
	float2 d = -p0 + 3.0 * p1 - 3.0 * p2 + p3;

	float2 result = 0.5 * (a + (b * t) + (c * t * t) + (d * t * t * t));

	return lerp(p1, result, tension);
}

float2 Interpolate(float2 start, float2 end, float t)
{
	return start * (1.0 - t) + end * t;
}

float2 BezierCurve(float2 p0, float2 p1, float2 p2, float t)
{
	float2 a = Interpolate(p0, p1, t);
	float2 b = Interpolate(p1, p2, t);
	return Interpolate(a, b, t);
}

float2 BezierCurveCubic(float2 p0, float2 p1, float2 p2, float2 p3, float t)
{
	float u = 1.0 - t;
	float tt = t * t;
	float uu = u * u;
	float uuu = uu * u;
	float ttt = tt * t;

	float2 p = uuu * p0; // (1-t)^3 * p0
	p += 3.0 * uu * t * p1; // 3 * (1-t)^2 * t * p1
	p += 3.0 * u * tt * p2; // 3 * (1-t) * t^2 * p2
	p += ttt * p3; // t^3 * p3

	return p;
}

float2 LagrangeInterpolation(float2 p0, float2 p1, float2 p2, float2 p3, float t)
{
	float2 result = float2(0.0, 0.0);
	float L0 = (1 - t) * (1 - t) * (1 - t) / 6.0;
	float L1 = (3 * t * t * t - 6 * t * t + 4) / 6.0;
	float L2 = (-3 * t * t * t + 3 * t * t + 3 * t + 1) / 6.0;
	float L3 = t * t * t / 6.0;

	result = L0 * p0 + L1 * p1 + L2 * p2 + L3 * p3;

	return result;
}

float2 ClampMotionVector(float2 motionVector, float maxMagnitude)
{
	float magnitude = length(motionVector);
	if (magnitude > maxMagnitude)
	{
		motionVector = normalize(motionVector) * maxMagnitude;
	}
	return motionVector;
}

float4 AnisotropicSample(sampler2D tex, float2 uv, float2 offset)
{
	float2 sampleOffset = offset * 0.25;
	float4 sample1 = tex2D(tex, uv + sampleOffset);
	float4 sample2 = tex2D(tex, uv - sampleOffset);
	return (sample1 + sample2) * 0.5;
}

float smoothLerp(float a, float b, float t)
{
	t = clamp(t, 0.0, 1.0);
	static const float smoothness = 2.0;
	t = t * t * (smoothness * (2.0 - t) - (smoothness - 1.0));
	t = clamp(t, 0.0, 1.0);
	return lerp(a, b, t);
}

float smootherLerp(float a, float b, float t)
{
	t = clamp(t, 0.0, 1.0);
	static const float smoothness = 4.0;
	t = t * t * (smoothness * (2.0 - t) - (smoothness - 1.0));
	t = clamp(t, 0.0, 1.0);
	return lerp(a, b, t);
}

float3 smootherLerp(float3 a, float3 b, float t)
{
	t = clamp(t, 0.0, 1.0);
	static const float smoothness = 4.0;
	t = t * t * t * t * (smoothness * (2.0 - t) - (smoothness - 1.0));
	t = clamp(t, 0.0, 1.0);
	return lerp(a, b, t);
}

/////////////////////////////////////////////
//MISC - Depth
/////////////////////////////////////////////

float GetLinearizedDepth(sampler depthSampler, float2 texcoord)
{
	float depth = 0.0;

	// Adjust texcoord for potential shader settings
	#if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
		texcoord.y = 1.0 - texcoord.y;
	#endif
	texcoord.x /= RESHADE_DEPTH_INPUT_X_SCALE;
	texcoord.y /= RESHADE_DEPTH_INPUT_Y_SCALE;
	#if RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET
		texcoord.x -= RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET * BUFFER_RCP_WIDTH;
	#else
		texcoord.x -= RESHADE_DEPTH_INPUT_X_OFFSET / 2.000000001;
	#endif
	#if RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET
		texcoord.y += RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET * BUFFER_RCP_HEIGHT;
	#else
		texcoord.y += RESHADE_DEPTH_INPUT_Y_OFFSET / 2.000000001;
	#endif

	// Sample depth from the provided sampler
	depth = tex2Dlod(depthSampler, float4(texcoord, 0, 0)).x * RESHADE_DEPTH_MULTIPLIER;

	// Apply depth transformations based on shader settings
	#if RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
		static const float C = 0.01;
		depth = (exp(depth * LOG(C + 1.0)) - 1.0) / C;
	#endif
	#if RESHADE_DEPTH_INPUT_IS_REVERSED
		depth = 1.0 - depth;
	#endif

	// Linearize depth value
	static const float N = 1.0;
	depth /= RESHADE_DEPTH_LINEARIZATION_FAR_PLANE - depth * (RESHADE_DEPTH_LINEARIZATION_FAR_PLANE - N);

	// Clamp the depth value to ensure it's within the valid range [0, 1]
	return saturate(depth);
}

/////////////////////////////////////////////
//SATURATION - CONVERSIONS
/////////////////////////////////////////////

float HuetoRGB(float p, float q, float t)
{
	if (t < 0.0f) t += 1.0f;
	if (t > 1.0f) t -= 1.0f;
	if (t < 1.0f / 6.0f) return p + (q - p) * 6.0f * t;
	if (t < 1.0f / 2.0f) return q;
	if (t < 2.0f / 3.0f) return p + (q - p) * (2.0f / 3.0f - t) * 6.0f;
	return p;
}

float3 RGBtoHSL(float3 color)
{
	float max = MAXRGB(color);
	float min = MINRGB(color);
	float delta = max - min;
	float h = 0.0f;
	float s = 0.0f;
	float l = (max + min) * 0.5f;

	if (delta > 0.0f)
	{
		s = SafeDivide(delta, (l < 0.5f ? (max + min) : (2.0f - max - min)));
		if (color.r == max)
			h = SafeDivide((color.g - color.b), delta) + (color.g < color.b ? 6.0f : 0.0f);
		else if (color.g == max)
			h = SafeDivide((color.b - color.r), delta) + 2.0f;
		else
			h = SafeDivide((color.r - color.g), delta) + 4.0f;
		h /= 6.0f;
	}

	return float3(h, s, l);
}

float3 HSLtoRGB(float3 hsl)
{
	float h = hsl.x;
	float s = hsl.y;
	float l = hsl.z;

	float r, g, b;

	if (s == 0.0f)
	{
		r = g = b = l; // achromatic
	}
	else
	{
		float q = l < 0.5f ? l * (1.0f + s) : l + s - l * s;
		float p = 2.0f * l - q;
		r = HuetoRGB(p, q, h + 1.0f / 3.0f);
		g = HuetoRGB(p, q, h);
		b = HuetoRGB(p, q, h - 1.0f / 3.0f);
	}

	return float3(r, g, b);
}

float3 RGBtoHSV(float3 color)
{
	float max = MAXRGB(color);
	float min = MINRGB(color);
	float delta = max - min;
	float h = 0.0f;
	float s = (max == 0.0f) ? 0.0f : delta / max;
	float v = max;

	if (delta != 0.0f)
	{
		if (color.r == max)
			h = (color.g - color.b) / delta + (color.g < color.b ? 6.0f : 0.0f);
		else if (color.g == max)
			h = (color.b - color.r) / delta + 2.0f;
		else
			h = (color.r - color.g) / delta + 4.0f;
		h /= 6.0f;
	}

	return float3(h, s, v);
}

float3 HSVtoRGB(float3 hsv)
{
	float h = hsv.x * 6.0f;
	float s = hsv.y;
	float v = hsv.z;

	int i = (int)floor(h);
	float f = h - i;
	float p = v * (1.0f - s);
	float q = v * (1.0f - s * f);
	float t = v * (1.0f - s * (1.0f - f));

	float3 rgb;
	switch (i % 6)
	{
		case 0: rgb = float3(v, t, p); break;
		case 1: rgb = float3(q, v, p); break;
		case 2: rgb = float3(p, v, t); break;
		case 3: rgb = float3(p, q, v); break;
		case 4: rgb = float3(t, p, v); break;
		case 5: rgb = float3(v, p, q); break;
	}

	return rgb;
}

float3 RGBtoHSI(float3 color)
{
	float r = color.r;
	float g = color.g;
	float b = color.b;

	float num = 0.5 * ((r - g) + (r - b));
	float den = sqrt((r - g) * (r - g) + (r - b) * (g - b));
	float h = acos(num / max(den, 0.00001));

	if (b > g) h = 2.0 * 3.14159 - h;
	h /= 2.0 * 3.14159;

	float sum = r + g + b;
	float intensity = sum / 3.0;
	float minRGB = MIN3(r, g, b);
	float saturation = 1.0 - (3.0 / sum) * minRGB;

	return float3(h, saturation, intensity);
}

float3 HSItoRGB(float3 hsi)
{
	float h = hsi.x * 2.0 * 3.14159;
	float s = hsi.y;
	float i = hsi.z;

	float r, g, b;

	if (h < 2.0 * 3.14159 / 3.0)
	{
		b = i * (1.0 - s);
		r = i * (1.0 + s * cos(h) / cos(3.14159 / 3.0 - h));
		g = 3.0 * i - (r + b);
	}
	else if (h < 4.0 * 3.14159 / 3.0)
	{
		h = h - 2.0 * 3.14159 / 3.0;
		r = i * (1.0 - s);
		g = i * (1.0 + s * cos(h) / cos(3.14159 / 3.0 - h));
		b = 3.0 * i - (r + g);
	}
	else
	{
		h = h - 4.0 * 3.14159 / 3.0;
		g = i * (1.0 - s);
		b = i * (1.0 + s * cos(h) / cos(3.14159 / 3.0 - h));
		r = 3.0 * i - (g + b);
	}

	return float3(r, g, b);
}

float3 RGBtoYUV(float3 color)
{
	float3 yuv;
	yuv.x = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
	yuv.y = -0.14713 * color.r - 0.28886 * color.g + 0.436 * color.b;
	yuv.z = 0.615 * color.r - 0.51499 * color.g - 0.10001 * color.b;
	return yuv;
}

float3 YUVtoRGB(float3 yuv)
{
	float3 rgb;
	rgb.r = yuv.x + 1.13983 * yuv.z;
	rgb.g = yuv.x - 0.39465 * yuv.y - 0.58060 * yuv.z;
	rgb.b = yuv.x + 2.03211 * yuv.y;
	return rgb;
}

/////////////////////////////////////////////
//SATURATION - FUNCTIONS
/////////////////////////////////////////////

float3 ExpandGamut(float3 HDRColor, float ExpandGamut)
{
	const float3x3 sRGB_2_AP1 = mul(XYZ_2_AP1_MAT, mul(D65_2_D60_CAT, sRGB_2_XYZ_MAT));
	const float3x3 AP1_2_sRGB = mul(XYZ_2_sRGB_MAT, mul(D60_2_D65_CAT, AP1_2_XYZ_MAT));
	const float3x3 Wide_2_AP1 = mul(XYZ_2_AP1_MAT, Wide_2_XYZ_MAT);
	const float3x3 ExpandMat = mul(Wide_2_AP1, AP1_2_sRGB);

	float3 ColorAP1 = mul(sRGB_2_AP1, HDRColor);
	ColorAP1 = WideColorsClamp(ColorAP1);
	float LumaAP1 = Luminance(ColorAP1, lumCoeffAP1_RGB2Y);
	float3 ChromaAP1 = ColorAP1 / LumaAP1;

	float ChromaDistSqr = dot(ChromaAP1 - 1, ChromaAP1 - 1);
	float ExpandAmount = (1 - exp2(-4 * ChromaDistSqr)) * (1 - exp2(-4 * ExpandGamut * LumaAP1 * LumaAP1));
	//float ExpandAmount = (1 - exp2(-1 * ChromaDistSqr)) * (1 - exp2(-1 * ExpandGamut * LumaAP1));  // Less extreme version
	//float ExpandAmount = 1 - exp2(-ExpandGamut * ChromaDistSqr); // More uniform

	float3 ColorExpand = mul(ExpandMat, mul(LumaAP1, ChromaAP1));
	ColorAP1 = lerp(ColorAP1, ColorExpand, ExpandAmount);
	HDRColor = mul(AP1_2_sRGB, ColorAP1);

	return HDRColor;
}

float3 SaturationBrightnessLimiter(float3 originalColor, float3 saturatedColor)
{
	float maxChannel = max(max(originalColor.r, originalColor.g), originalColor.b);
	float saturatedMaxChannel = max(max(saturatedColor.r, saturatedColor.g), saturatedColor.b);
	if (saturatedMaxChannel > maxChannel)
	{
		saturatedColor *= maxChannel / saturatedMaxChannel;
	}

	return saturatedColor;
}

float BrightnessLimiter(float3 originalColor, float Output)
{
	float maxChannel = max(max(originalColor.r, originalColor.g), originalColor.b);
	if (Output > maxChannel)
	{
		Output = maxChannel;
	}

	return Output;
}

float3 LumaSaturation(float3 color, float amount)
{
	float luminanceHDR = Luminance(color, lumCoeffHDR);
	return lerp(luminanceHDR, color, amount);
}

float3 HSLSaturation(float3 color, float amount)
{
	float3 hsl = RGBtoHSL(color.rgb);
	hsl.y *= amount;
	return HSLtoRGB(hsl);
}

float3 HSVSaturation(float3 color, float amount)
{
	float maxVal = MAXRGB(color);
	float3 hsv = RGBtoHSV(color.rgb);
	hsv.y *= amount;
	float3 hsvProcessed = HSVtoRGB(hsv);
	return max(HSVtoRGB(hsv), 0.0 - maxVal);
}

float3 HSISaturation(float3 color, float amount)
{
	float3 hsi = RGBtoHSI(color.rgb);
	hsi.y *= amount;
	return HSItoRGB(hsi);
}

float3 YUVSaturation(float3 color, float amount)
{
	float3 yuv = RGBtoYUV(color.rgb);
	yuv.yz *= amount;
	return YUVtoRGB(yuv);
}

float3 AverageSaturation(float3 color, float amount)
{
	float avg = (color.r + color.g + color.b) / 3.0f;
	return lerp(avg.xxx, color.rgb, amount);
}

float3 MaxSaturation(float3 color, float amount)
{
	float maxVal = MAXRGB(color);
	return max(lerp(maxVal.xxx, color.rgb, amount), 0.0 - maxVal);
}

float3 ColorfulnessSaturation(float3 color, float amount)
{
	float maxVal = MAXRGB(color);
	float minVal = MINRGB(color);
	float chroma = maxVal - minVal;
	float3 adjustedColor = max(lerp(chroma, color, amount), 0.0 - maxVal);

	return adjustedColor;
}

float3 VibranceSaturation(float3 color, float amount)
{
	float luminanceHDR = Luminance(color, lumCoeffHDR);
	float maxVal = MAXRGB(color);
	float minVal = MINRGB(color);
	float chroma = sign((maxVal - minVal) * (-1.0));
	return lerp(luminanceHDR.xxx, color, amount -1.0 - chroma);
}

float3 AdaptiveSaturation(float3 color, float amount)
{
	float luminanceHDR = Luminance(color, lumCoeffHDR);
	float3 gray = float3(luminanceHDR, luminanceHDR, luminanceHDR);
	float3 colorDiff = color - gray;
	float initialSaturation = length(colorDiff) / max(luminanceHDR, 1e-5);
	float modulation = smoothstep(0.0, 1.0, initialSaturation);
	float factor = 1.0 + (amount - 1.0) * modulation;
	float3 saturatedColor = gray + colorDiff * factor;

	float maxChannel = max(max(color.r, color.g), color.b);
	float saturatedMaxChannel = max(max(saturatedColor.r, saturatedColor.g), saturatedColor.b);
	if (saturatedMaxChannel > maxChannel)
	{
		saturatedColor *= maxChannel / saturatedMaxChannel;
	}

	return saturatedColor;
}

float3 OKLABSaturation(float3 color, float amount)
{
	float3 oklab = RGBToOKLab(color);
	float3 oklch = oklab_to_oklch(oklab);
	oklch.y *= amount;
	oklab = oklch_to_oklab(oklch);
	return OKLabToRGB(oklab);
}

/////////////////////////////////////////////
//TMOs
/////////////////////////////////////////////

//ACES
float3 ACES(float3 color)
{
	float a = 2.51f;
	float b = 0.03f;
	float c = 2.43f;
	float d = 0.59f;
	float e = 0.14f;

	return (color * ((a * color) + b)) / (color * ((c * color) + d) + e);
}

float3 ACES_Inverse(float3 color)
{
	float a = 2.51f;
	float b = 0.03f;
	float c = 2.43f;
	float d = 0.59f;
	float e = 0.14f;

	color = saturate(color);
	float3 fixed_numerator = (-d * color) + b;
	float3 variable_numerator_part1 = (d * color) - b;
	float3 variable_numerator = sqrt((variable_numerator_part1 * variable_numerator_part1) - (4.f * e * color * ((c * color) - a)));
	float3 denominator = 2.f * ((c * color) - a);
	float3 result1 = (fixed_numerator + variable_numerator) / denominator;
	float3 result2 = (fixed_numerator - variable_numerator) / denominator;
	color = max(result1, result2);
	return color;
}

//Reinhard
float3 Reinhard_Inverse(float3 color)
{
	return (color * (1.0 + color)) / (1.0 + color / (HDR10_max_nits * HDR10_max_nits));
}

//Hybrid Log-Gamma
float3 HLG_Inverse(float3 color)
{
	float a = 0.17883277;
	float b = 0.28466892;
	float c = 0.55991072952956202016;

	float3 x = color;
	float3 y = pow((a * x + b), 1.0 / c);

	return y;
}

//BT2390
float3 BT2390_Inverse(float3 color)
{
	float a = 0.17883277;
	float b = 0.28466892;
	float c = 0.55991072952956202016;

	color = max(color, 0.0);
	float3 x = color;
	return (pow(x, 1.0/2.4) * (c * x + b) / (c * x + a));
}

//PBR Neutral Tonemapping
//(https://modelviewer.dev/examples/tone-mapping)
float3 PBRToneMapping(float3 color)
{
	static const float startCompression = 0.8 - 0.04;
	static const float desaturation = 0.15;
	float x = min(color.r, min(color.g, color.b));
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;

	float peak = max(color.r, max(color.g, color.b));
	if (peak < startCompression) return color;

	float d = 1. - startCompression;
	float newPeak = 1. - d * d / (peak + d - startCompression);
	color *= newPeak / peak;

	float g = 1. - 1. / (desaturation * (peak - newPeak) + 1.);
	return lerp(color, newPeak * float3(1, 1, 1), g);
}

// Approximate Inverse PBR Neutral Tonemapping
float3 PBRToneMapping_Inverse(float3 color)
{
	static const float startCompression = 0.8 - 0.04;
	static const float desaturation = 0.15;
	float peak = max(color.r, max(color.g, color.b));
	float g = 1. - 1. / (desaturation * (1.0 - peak) + 1.);
	float3 originalColor = lerp(color, float3(1, 1, 1), -g);

	peak = max(originalColor.r, max(originalColor.g, originalColor.b));
	if (peak >= startCompression)
	{
		float d = 1. - startCompression;
		float newPeak = peak / (1. - d * d / (1. - peak + d - startCompression));
		originalColor *= newPeak / peak;
	}

	float x = min(originalColor.r, min(originalColor.g, originalColor.b));
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	originalColor += offset;

	return originalColor;
}