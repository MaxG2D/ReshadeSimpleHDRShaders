# Various HDR shaders

## [Download](https://github.com/MaxG2D/ReshadeSimpleHDRShaders/releases)

There's a lot of cool shaders that focus on the getting most basic HDR display adjustments and fixes right, most noteably [Lilium's](https://github.com/EndlesslyFlowering/ReShade_HDR_shaders) and [Pumbo's](https://github.com/Filoppi/PumboAutoHDR), which are absolutely essential shaders. This is a very high quality stuff with a lot of various math involved to get the most proper HDR experience.

This repo tries something else. It's 2 main focus points are:
- Finally have a proper HDR support in ReShade for cinematic effects like motion blur, bloom, lens flares, etc.
- Keep things relatively simple, and reduce bloat as much as possible.

# Currently available shaders:


# ----------------------  HDR Motion Blur  ---------------------

(This video is HDR encoded, should work on most chromium based browsers. On different browser, it will be clipped to SDR range.)

https://github.com/MaxG2D/ReshadeSimpleHDRShaders/assets/88550439/439638ee-fed6-4656-888e-9ab927d5d1ef

This is something that I've been experimenting a lot before I even had a HDR capable TV. It's feature rich to enhance the contrast of the blur, but if output is pure, untonemapped HDR color, it shouldn't need any tweaking, giving nice, bright highlights out of the box. Otherwise, it might a good idea to use a bit of fake gain function, or linear conversion.

***It's very important that you use it with one of the widely available optical flow shaders, here are some examples:***

1: [qUINT_of.fx](https://github.com/martymcmodding/ReShade-Optical-Flow/blob/main/Shaders/qUINT_of.fx)

2: [qUINT_MotionVectors.fx](https://gist.github.com/martymcmodding/69c775f844124ec2c71c37541801c053)

3: [ReshadeMotionEstimation](https://github.com/JakobPCoder/ReshadeMotionEstimation)

## Features:
- Linear motion blur with optional Blue Noise slider that activates when blur gets too extreme, hidding artifacts from under sampling
- Support for SDR, HDR10 and scRGB
- Variable samples quality, you can tune the quality however you want
- Optional fake gain option to increase highlights brightness, as well as linear conversion to bring up more highlights
- An option to sample depth buffer, simulating per object motion blur only, rather than per pixel
----------


# ----------------------  HDR Saturation  -----------------------


I love Pumbo's AdvancedAutoHDR shader with it's saturation adjustments, but I want something that is more flexible, and something that will actually prevent color from going into invalid space.
This shader is best used as a subtle sublement to HDR games that output only rec.709 colors.

## Features:
- HDR compatible saturation and desaturation adjustment
- Choose whether to apply adjustment globaly or only to highlights
- Optional gamut expansion
- Various algorithms to choose from, like Luma, HSL, HSV, YUV, etc.
----------


# ------------------------  HDR Bloom  --------------------------
(Again, this is HDR encoded PNGs. Should work just fine on Chromium browser, On different browser, it will be tonemapped to SDR range.
From left to right: Bloom off, Bloom on, Bloom debug view)

<p align="center" width="100%">
<img width="33%" src="https://github.com/MaxG2D/ReshadeSimpleHDRShaders/assets/88550439/59189fdf-df4f-4547-b8b3-eb092271c030">

<img width="33%" src="https://github.com/MaxG2D/ReshadeSimpleHDRShaders/assets/88550439/553592f6-8f26-4c23-9585-f29337ecb92e">

<img width="33%" src="https://github.com/MaxG2D/ReshadeSimpleHDRShaders/assets/88550439/5302b73b-2312-49ff-a99a-e01e06924033">
</p>

Based on awesome Luluco250's [MagicHDR shader](https://github.com/luluco250/FXShaders/blob/master/Shaders/MagicHDR.fx), I've made my own take on  fully HDR-Compatible bloom shader.
Highly performant, with very wide, realistic blur, coupled with plethora of features to tweak.

## Features:
- Seperable Gaussian blur bloom
- Additional circular bloom stage at upsampling, giving perfectly smooth and very wide bloom, at very low perf cost, fixing upsampling and temporal artifacts
- Support for SDR, HDR10 and scRGB
- Option to inverse tonemap input to further increase the range of values, useful for oldschool pure LDR games
- Plenty of basic customization, like bloom amount, bloom texture brightness, saturation, bluring range, quality, etc
- Option to properly remove SDR range from the input, to make sure bloom is not overly "hazy" (for obvious reasons, it only works in HDR)
- Variable downsampling and gaussian blur samples quality
- Debug option to show bloom texture only, which helps immensly in tweaking the values
----------


# Credits


Pumbo, Lillium, Jakob Wapenhensch

Huge thanks to SpecialK and HDR Den Discord servers for making HDR experience better every day!
