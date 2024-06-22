# Various HDR shaders

## [Download]()

There's a lot of cool shaders that focus on the most basic HDR adjustments and fixes, most noteably Lillium's and Pumbo's absolutely essential shaders. This is a very high quality stuff with a lot of various math involved to get the most proper HDR experience.

This repo tries tries something else. It's 2 main focus points are:
- Finally have a proper HDR support in ReShade for cinematic effects like motion blur, bloom, vignetting, lens flares, etc.
- Keep things relatively simple, and reduce bloat as much as possible.

# Currently available shaders:
## - HDR Motion Blur

This is something that I've been experimenting a lot before I even had a HDR capable TV, so it has a lot of legacy SDR support. It's very important that you use it with one of the widely available optical flow shaders!

## - HDR Saturation

I love Pumbo's AdvancedAutoHDR shader with it's saturation adjustments, but I want something that is more flexible, and something that will actually prevent color from going into invalid space.
