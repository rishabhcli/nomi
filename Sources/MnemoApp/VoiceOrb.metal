// Agent-B audit B-029
// Agent-B audit B-011
#include <metal_stdlib>
using namespace metal;

// Listening-orb fragment shader (UI.md §12.4) — the dark glass sphere with an
// amplitude-reactive meniscus wave, studied frame-by-frame from the reference
// recording. Driven by `time` + the smoothed mic `amplitude`; everything
// per-frame runs on the GPU. Applied with SwiftUI `.colorEffect` over a circle.
//
// Louder → the band grows taller AND brighter AND more saturated, with a
// white-hot core and chromatic fringing; silence → a thin warm seam. A fixed
// reflection arc across the upper hemisphere keeps it reading as glass.

static float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

[[ stitchable ]]
half4 voiceOrb(float2 pos, half4 color, float2 size,
               float time, float amplitude,
               float waveHeight, float brightness, float saturation) {
    float2 uv = (pos / size) * 2.0 - 1.0;          // center to [-1,1]
    float r = length(uv);
    if (r > 1.0) return half4(0.0);                 // outside the sphere
    float aa = smoothstep(1.0, 0.98, r);            // rim anti-alias

    float amp = clamp(amplitude, 0.0, 1.0);
    float z = sqrt(max(0.0, 1.0 - r * r));          // sphere normal z
    float fresnel = pow(1.0 - z, 3.0);              // grazing-edge rim

    // Meniscus divide: three traveling harmonics → organic S-curve flow.
    // Clamped so peaks bloom downward, never up behind the notch (§12.5).
    float wave = sin(uv.x * 2.6 + time * 1.6)
               + 0.55 * sin(uv.x * 5.2 - time * 2.2 + 1.3)
               + 0.28 * sin(uv.x * 9.1 + time * 3.0 + 4.1);
    float yDiv = clamp((wave / 1.83) * (0.10 + amp * 0.38), -0.35, 0.50);

    // Band half-height comes straight from OrbUniforms.waveHeight (the single,
    // unit-tested amplitude→visual mapping — no divergent re-derivation here).
    float bandHalf = clamp(waveHeight, 0.0, 0.80);
    float d = uv.y - yDiv;
    float band = pow(smoothstep(bandHalf, 0.0, abs(d)), 1.4);

    // Spectral gradient along x, rotating slowly; sat/val from OrbUniforms.
    float hue = fract(uv.x * 0.35 + time * 0.15);
    float sat = saturation;
    float val = brightness * band;
    float3 rgb = hsv2rgb(float3(hue, sat, val));

    // Two-tone: warm crest above the divide, cool trough below [measured].
    float side = smoothstep(-bandHalf, bandHalf, d);
    rgb += band * mix(float3(1.0, 0.55, 0.25), float3(0.25, 0.55, 1.0), side)
               * (0.10 + 0.25 * amp);

    // White-hot core at the divide when loud.
    float core = smoothstep(bandHalf * 0.35, 0.0, abs(d));
    rgb += core * amp * amp * 0.9;

    // Chromatic aberration: offset band per channel, ∝ amplitude.
    float off = amp * 0.045;
    float bandR = pow(smoothstep(bandHalf, 0.0, abs(d - off)), 1.4);
    float bandB = pow(smoothstep(bandHalf, 0.0, abs(d + off)), 1.4);
    rgb.r += (bandR - band) * 0.6 * amp;
    rgb.b += (bandB - band) * 0.6 * amp;

    // Upper-hemisphere reflection arc — the fixed glassiness cue.
    float reflArc = pow(max(0.0, -uv.y), 4.0) * smoothstep(0.45, 0.92, r) * 0.30;
    // Inner shadow settling into the lower rim.
    float innerShadow = pow(max(0.0, uv.y), 3.0) * smoothstep(0.5, 1.0, r) * 0.35;

    // Dark glass base + fresnel rim (rim brightens slightly with amplitude —
    // the non-color amplitude cue, §12.6). The base is lifted enough that the
    // sphere reads as a present piece of glass even at silence (contrast).
    float3 glassBase = float3(0.055, 0.055, 0.075) + fresnel * 0.30 * (1.0 + 0.5 * amp);
    float3 outc = glassBase + rgb + reflArc;
    outc *= (1.0 - innerShadow);

    // Hash dither (±1/255) removes visible banding on the dark gradient — a
    // cheap, real smoothness win.
    float dither = (fract(sin(dot(pos, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    outc += dither;

    float alpha = max(band, 0.90) * aa;
    return half4(half3(clamp(outc, 0.0, 1.4) * aa), half(alpha));
}
