#version 150

// Plasma C64-style : sin layers + palette indexed.
// Look 1985, pas trop riche mais authentique.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x *= uRes.x / uRes.y;

    float t = uTime * (0.5 + uMid * 0.4);
    float v = 0.0;
    v += sin(p.x * 6.0 + t * 2.0);
    v += sin(p.y * 8.0 - t * 1.5);
    v += sin((p.x + p.y) * 5.0 + t * 1.7);
    v += sin(length(p) * 8.0 - t * 2.5);
    v *= 0.25;

    // Palette indexée 8 couleurs C64-style
    int idx = int(floor((v + 1.0) * 4.0));
    vec3 pal[8];
    pal[0] = vec3(0.0, 0.0, 0.0);
    pal[1] = vec3(0.55, 0.20, 0.20);
    pal[2] = vec3(0.85, 0.60, 0.35);
    pal[3] = vec3(0.95, 0.95, 0.65);
    pal[4] = vec3(0.45, 0.85, 0.45);
    pal[5] = vec3(0.30, 0.65, 0.95);
    pal[6] = vec3(0.65, 0.35, 0.85);
    pal[7] = vec3(0.95, 0.40, 0.65);
    int i = clamp(idx, 0, 7);
    vec3 col = pal[i];
    col *= 1.0 + uKick * 0.4;
    fragColor = vec4(col, 1.0);
}
