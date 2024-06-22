//	All credits go to respective authors like:
//	Lillium
//	Pumbo
//	All the people that worked on defining the standards	
//	Tweaks and edits by MaxG3D	
//	Special thanks to SpecialK, and HDR Den server

#pragma once

#pragma warning(disable : 3571) // disable warning about potentially using pow on a negative value

/////////////////////////////////////////////
//MISC
/////////////////////////////////////////////

// These are from the "color_space" enum in ReShade
#define RESHADE_COLOR_SPACE_SDR        0
#define RESHADE_COLOR_SPACE_SCRGB       1
#define RESHADE_COLOR_SPACE_BT2020_PQ   2

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

#define UINT_MAX 4294967295
#define  INT_MAX 2147483647
#define MIN3(A, B, C) min(A, min(B, C))
#define MAX3(A, B, C) max(A, max(B, C))
#define MAX4(A, B, C, D) max(A, max(B, max(C, D)))
#define MAX5(A, B, C, D, E) max(A, max(B, max(C, max(D, E))))
#define MAXRGB(Rgb) max(Rgb.r, max(Rgb.g, Rgb.b))
#define MINRGB(Rgb) min(Rgb.r, min(Rgb.g, Rgb.b))
#define lumCoeffHDR float3(0.2627f, 0.6780f, 0.0593f)
#define lumCoeffsRGB float3(0.299f, 0.587f, 0.114f)
#define lumCoeffLinear float3(0.2126f, 0.7152f, 0.0722f)
#define FP32_MIN asfloat(0x00800000)
#define FP32_MAX asfloat(0x7F7FFFFF)
#define FLT16_MAX 65504.f

/////////////////////////////////////////////
//STATIC DEFINITIONS
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
//CONVERSIONS - LUMA
/////////////////////////////////////////////

float sRGB_to_linear(float color)
{
    const float a = 0.055f;

    [flatten]
    if (color >= 1.f || color <= 0.f)
    {
        // Nothing to do
    }
    else if (color <= 0.04045f)
        color = color / 12.92f;
    else
        color = pow((color + a) / (1.0f + a), 2.4f);

    return color;
}

float3 sRGB_to_linear(float3 colour)
{
    return float3(
		sRGB_to_linear(colour.r),
		sRGB_to_linear(colour.g),
		sRGB_to_linear(colour.b));
}

float linear_to_sRGB(float channel)
{
	if (channel <= 0.0031308f)
	{
		channel = channel * 12.92f;
	}
	else
	{
		channel = 1.055f * pow(channel, 1.f / 2.4f) - 0.055f;
	}
	return channel;
}

float3 linear_to_sRGB(float3 Color)
{
    return float3(linear_to_sRGB(Color.r), linear_to_sRGB(Color.g), linear_to_sRGB(Color.b));
}

float3 linear_to_PQ(float3 linearCol)
{
    linearCol /= PQMaxWhitePoint;
	
    float3 colToPow = pow(linearCol, PQ_constant_N);
    float3 numerator = PQ_constant_C1 + PQ_constant_C2 * colToPow;
    float3 denominator = 1.f + PQ_constant_C3 * colToPow;
    float3 pq = pow(numerator / denominator, PQ_constant_M);

    return pq;
}

float3 PQ_to_linear(float3 ST2084)
{
    float3 colToPow = pow(ST2084, 1.0f / PQ_constant_M);
    float3 numerator = max(colToPow - PQ_constant_C1, 0.f);
    float3 denominator = PQ_constant_C2 - (PQ_constant_C3 * colToPow);
    float3 linearColor = pow(numerator / denominator, 1.f / PQ_constant_N);

    linearColor *= PQMaxWhitePoint;

    return linearColor;
}

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
static const float3x3 D65_2_D60_CAT = float3x3(
	1.01303, 0.00610531, -0.014971,
	0.00769823, 0.998165, -0.00503203,
	-0.00284131, 0.00468516, 0.924507);
static const float3x3 D60_2_D65_CAT = float3x3(
	0.987224, -0.00611327, 0.0159533,
	-0.00759836, 1.00186, 0.00533002,
	0.00307257, -0.00509595, 1.08168);
static const float3x3 AP1_2_XYZ_MAT = float3x3(
	0.6624541811, 0.1340042065, 0.1561876870,
	0.2722287168, 0.6740817658, 0.0536895174,
	-0.0055746495, 0.0040607335, 1.0103391003);
static const float3 AP1_RGB2Y = float3(
	0.2722287168,
	0.6740817658, 
	0.0536895174 );
static const float3x3 Wide_2_XYZ_MAT = float3x3(
    0.5441691, 0.2395926, 0.1666943,
    0.2394656, 0.7021530, 0.0583814,
    -0.0023439, 0.0361834, 1.0552183);
static const float3x3 BT709_2_BT2020 = float3x3(
	0.627401924722236, 0.329291971755002, 0.0433061035227622,
	0.0690954897392608, 0.919544281267395, 0.0113602289933443,
	0.0163937090881632, 0.0880281623979006, 0.895578128513936);
static const float3x3 BT2020_2_BT709 = float3x3(
	1.66049621914783, -0.587656444131135, -0.0728397750166941,
	-0.124547095586012, 1.13289510924730, -0.00834801366128445,
	-0.0181536813870718, -0.100597371685743, 1.11875105307281);

static const float3x3 XYZ_2_BT2020_MAT = float3x3(
    0.6369580483, 0.1446169032, 0.1688809751,
    0.2627002120, 0.6779980715, 0.0593017165,
    0.0000000000, 0.0280726930, 1.0609850576
);

static const float3x3 BT2020_2_XYZ_MAT = float3x3(
    1.71665118797126, -0.355670783776392, -0.253366281373659,
    -0.666684351832489, 1.61648123663494, 0.015768545813911,
    0.0176398574453105, -0.0427706132578086, 0.942103121235473
);

static const float3x3 AP1_2_BT2020_MAT = float3x3(
    1.6410233797, -0.3248032942, -0.2364246952,
    -0.6636628587, 1.6153315917, 0.0167563477,
    0.0117218943, -0.0082844420, 0.9883948585
);

static const float3x3 BT2020_2_AP1_MAT = float3x3(
    0.6624541811, 0.1340042065, 0.1561876870,
    0.2722287168, 0.6740817658, 0.0536895174,
    -0.0055746495, 0.0040607335, 1.0103391003
);

/////////////////////////////////////////////
//CONVERSIONS - CHROMA (FUNCTIONS)
/////////////////////////////////////////////

float3 BT709_2_BT2020(float3 color)
{
    return mul(BT709_2_BT2020, color);
}

float3 BT2020_2_BT709(float3 color)
{
    return mul(BT2020_2_BT709, color);
}

/////////////////////////////////////////////
//ToneMappers
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
    
    // Avoid out of gamut colors from breaking the formula
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
float3 Reinhard(float3 color)
{
	return (color * (1.0 + color / (HDR10_max_nits * HDR10_max_nits))) / (1.0 + color);
}

float3 Reinhard_Inverse(float3 color)
{
	return (color * (1.0 + color)) / (1.0 + color / (HDR10_max_nits * HDR10_max_nits));	
}

//Lottes
static const float a = 1.6;
static const float d = 0.977;
static const float midIn = 0.18;
static const float midOut = 0.267;
	
float3 Lottes(float3 color)
{
	float b =
    (-pow(midIn, a) + pow(HDR10_max_nits, a) * midOut) /
    ((pow(HDR10_max_nits, a * d) - pow(midIn, a * d)) * midOut);
    
    float c =
    (pow(HDR10_max_nits, a * d) * pow(midIn, a) - pow(HDR10_max_nits, a) * pow(midIn, a * d) * midOut) /
    ((pow(HDR10_max_nits, a * d) - pow(midIn, a * d)) * midOut);

	return color = pow(color, a) / (pow(color, a * d) * b + c);
}

float3 Lottes_Inverse(float3 color)
{
	float k = pow(midIn, a) / midOut;
	float n = a / (a * d - 1.0);

	float3 tonemapped = pow(color, a) 
		/ (pow(color, a * d) * 
		((-pow(midIn, a) + pow(HDR10_max_nits, a) * midOut) / 
		((pow(HDR10_max_nits, a * d) - pow(midIn, a * d)) * midOut)) + 
		((pow(HDR10_max_nits, a * d) * pow(midIn, a) - pow(HDR10_max_nits, a) * 
		pow(midIn, a * d) * midOut) / 
		((pow(HDR10_max_nits, a * d) - pow(midIn, a * d)) * midOut)));
	float3 invTonemapped = pow(tonemapped / k, 2.2 / n);

	return invTonemapped;
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
//NAN-INF FIX
/////////////////////////////////////////////

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