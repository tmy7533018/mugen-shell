#version 440

// Mesh gradient: four colour sources drift on coprime sine orbits and are
// blended by inverse-square weight, so no edge or shape is ever visible. The
// vertical base ramp underneath keeps the surface readable when the sources
// wander to one side.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 baseTop;
    vec4 baseBottom;
    vec4 colorA;
    vec4 colorB;
    vec4 colorC;
    vec4 colorD;
    float time;
    float speed;
    float spread;
    float strength;
    float aspect;
    float radiusN;
    float aaN;
};

// Rounded-rect coverage in uv space, so the pill shape needs no OpacityMask
// pass — one less FBO, and nothing to go stale when the source is hidden.
float roundedCoverage(vec2 uv, float r, float aa) {
    vec2 halfExtent = vec2(0.5 * aspect, 0.5);
    vec2 p = abs(vec2(uv.x * aspect, uv.y) - halfExtent);
    vec2 q = p - (halfExtent - vec2(r));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    return 1.0 - smoothstep(-aa, aa, d);
}

vec2 orbit(float t, float fx, float fy, vec2 centre, float rx, float ry) {
    return centre + vec2(rx * sin(t * fx), ry * cos(t * fy));
}

void main() {
    vec2 uv = qt_TexCoord0;
    // Weights are measured in a square space so a wide bar does not squash
    // the sources into vertical stripes.
    vec2 p = vec2(uv.x * aspect, uv.y);
    float t = time * speed;

    vec2 a = orbit(t, 0.31, 0.23, vec2(0.25 * aspect, 0.30), 0.22 * aspect, 0.26);
    vec2 b = orbit(t, 0.19, 0.37, vec2(0.75 * aspect, 0.35), 0.26 * aspect, 0.22);
    vec2 c = orbit(t, 0.41, 0.17, vec2(0.40 * aspect, 0.75), 0.24 * aspect, 0.20);
    vec2 d = orbit(t, 0.13, 0.29, vec2(0.85 * aspect, 0.70), 0.20 * aspect, 0.24);

    float s = max(spread, 1e-3);
    float wa = 1.0 / (dot(p - a, p - a) / s + 1.0);
    float wb = 1.0 / (dot(p - b, p - b) / s + 1.0);
    float wc = 1.0 / (dot(p - c, p - c) / s + 1.0);
    float wd = 1.0 / (dot(p - d, p - d) / s + 1.0);
    float sum = wa + wb + wc + wd;

    vec3 mesh = (colorA.rgb * wa + colorB.rgb * wb + colorC.rgb * wc + colorD.rgb * wd) / sum;
    vec3 base = mix(baseTop.rgb, baseBottom.rgb, uv.y);

    vec3 rgb = mix(base, mesh, clamp(strength, 0.0, 1.0));
    float alpha = mix(baseTop.a, baseBottom.a, uv.y) * qt_Opacity
                * roundedCoverage(uv, radiusN, aaN);
    fragColor = vec4(rgb * alpha, alpha);
}
