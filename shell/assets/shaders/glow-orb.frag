#version 440

// A metaball field sampled per grid cell, drawn as squares that follow it.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 mainColor;
    vec4 subColor;
    vec4 trail0;
    vec4 trail1;
    vec4 trail2;
    vec4 trail3;
    vec4 trail4;
    vec4 trail5;
    vec2 res;
    vec2 orb;
    vec2 light;
    float time;
    float cell;
    float sigmaMain;
    float sigmaCore;
    float sigmaLight;
    float sigmaTrail;
};

float falloff(vec2 q, vec2 centre, float sigma) {
    vec2 d = q - centre;
    return exp(-dot(d, d) / sigma);
}

float trailAt(vec2 q, vec4 point) {
    vec2 d = q - point.xy;
    return 0.30 * point.z * exp(-dot(d, d) / sigmaTrail);
}

void main() {
    vec2 px = qt_TexCoord0 * res;
    vec2 index = floor(px / cell);
    vec2 centre = (index + 0.5) * cell;

    float v = falloff(centre, orb, sigmaMain)
            + 0.9 * falloff(centre, orb, sigmaCore)
            + 0.5 * falloff(centre, light, sigmaLight);

    v += trailAt(centre, trail0) + trailAt(centre, trail1) + trailAt(centre, trail2)
       + trailAt(centre, trail3) + trailAt(centre, trail4) + trailAt(centre, trail5);

    // Per-cell shimmer, so the field never looks like a static gradient.
    v *= 0.8 + 0.3 * sin(time * 1.05 + index.x * 1.7 + index.y * 2.3);

    // A faint ember per cell, each phased, so the field never pulses as one.
    float hash = fract(sin(dot(index, vec2(12.9898, 78.233))) * 43758.5453);
    float drift = 0.5 + 0.5 * sin(time * 0.55 + (index.x + index.y) * 0.22
                                  + hash * 6.2832);
    float slow = 0.5 + 0.5 * sin(time * 0.21
                                 - (index.x * 0.5 - index.y * 0.7) * 0.11);
    float ember = (0.03 + 0.11 * pow(drift * slow, 1.5)) * (0.5 + hash);
    v = max(v, ember);

    float size = (cell - 1.0) * min(1.0, v * 1.35);
    if (size < 0.42) {
        fragColor = vec4(0.0);
        return;
    }
    size = clamp(size, 0.9, cell - 1.0);
    float halfSize = size * 0.5;
    vec2 offset = abs(px - centre);
    float inside = (1.0 - smoothstep(halfSize - 0.5, halfSize + 0.5, offset.x))
                 * (1.0 - smoothstep(halfSize - 0.5, halfSize + 0.5, offset.y));

    // Scattered off the hash rather than a modulus: any lattice reads as stripes.
    vec3 tinted = fract(hash * 7.31) < 0.25 ? subColor.rgb : mainColor.rgb;
    // Off-hue, so the resting field reads as unlit rather than as the accent.
    vec3 rgb = v > 0.92
        ? vec3(1.0)
        : mix(vec3(0.72, 0.76, 0.86), tinted, smoothstep(0.12, 0.42, v));

    float a = min(0.95, v * 1.05) * inside * qt_Opacity;
    fragColor = vec4(rgb * a, a);
}
