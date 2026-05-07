#version 150

// Mode 7 (SNES) : sol texturé en perspective, scrollant.
// Inverse perspective mapping de uv → ground plane.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(1.0, 0.6, 0.4) * t + vec3(0.0, 0.4, 0.7)));
}

void main() {
    vec2 uv = (gl_FragCoord.xy / uRes) - 0.5;
    uv.x *= uRes.x / uRes.y;

    // Sky : top-half, gradient
    if (uv.y > 0.0) {
        float k = clamp(uv.y * 2.0, 0.0, 1.0);
        vec3 sky = mix(vec3(0.95, 0.4, 0.6), vec3(0.05, 0.05, 0.2), k);
        // Soleil
        float sd = length(uv - vec2(0.0, 0.15));
        sky += vec3(1.0, 0.95, 0.6) * smoothstep(0.18, 0.0, sd);
        fragColor = vec4(sky, 1.0);
        return;
    }

    // Ground inverse perspective
    float t = uTime * (0.6 + uBpm * 0.003 + uKick * 1.0);
    float fz = -1.0 / uv.y;          // depth
    float fx = uv.x * fz;            // x in ground
    float fy = fz - t;               // depth scrolling

    // Camera roll + audio modulation
    float ang = sin(uTime * 0.3) * 0.2 * uMid;
    float c = cos(ang), s = sin(ang);
    vec2 g = mat2(c, -s, s, c) * vec2(fx, fy);

    // Texture : damier psyché coloré
    float gx = abs(fract(g.x * 1.5 + 0.5) - 0.5);
    float gy = abs(fract(g.y * 1.0 + 0.5) - 0.5);
    float check = step(0.0, sin(g.x * 3.14159) * sin(g.y * 3.14159));
    vec3 colA = palette(g.x * 0.05 + uTime * 0.1);
    vec3 colB = palette(g.y * 0.05 + uTime * 0.15 + 0.5);
    vec3 col = mix(colA, colB, check);

    // Bordures cellules
    float edge = smoothstep(0.05, 0.0, min(gx, gy));
    col = mix(col, vec3(1.0, 0.9, 0.7), edge * 0.5);

    // Fade horizon
    col *= smoothstep(0.0, -0.5, uv.y) * 1.3 + 0.2;
    col *= 1.0 + uKick * 0.3;
    fragColor = vec4(col, 1.0);
}
