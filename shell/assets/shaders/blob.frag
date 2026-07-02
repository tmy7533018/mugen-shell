#version 440

// Wavering blob: analytic polar wobble replacing the old per-vertex Canvas
// polygon. Three sine bands at coprime angular frequencies with independent
// drift rates give the organic, non-repeating edge; the radial alpha
// gradient runs to baseRadius exactly like the Canvas gradient did.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 blobColor;
    float time;
    float baseRadius;
    float amplitude;
    float centerAlpha;
    float edgeAlpha;
    float speed;
    float phase1;
    float phase2;
    float phase3;
    float aa;
};

void main() {
    vec2 p = qt_TexCoord0 - vec2(0.5);
    float r = length(p);
    float theta = atan(p.y, p.x);
    float t = time * speed;

    float w = 0.55 * sin(theta * 3.0 + phase1 + t)
            + 0.30 * sin(theta * 5.0 + phase2 - t * 0.8)
            + 0.15 * sin(theta * 7.0 + phase3 + t * 1.3);
    float radius = baseRadius + w * amplitude;

    float g = clamp(r / max(baseRadius, 1e-4), 0.0, 1.0);
    float alpha = mix(centerAlpha, edgeAlpha, g);
    float cut = 1.0 - smoothstep(radius - aa, radius + aa, r);

    float a = alpha * cut * qt_Opacity;
    fragColor = vec4(blobColor.rgb * a, a);
}
