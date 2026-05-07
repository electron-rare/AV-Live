#version 150

// Rotozoomer Amiga classique : rotation 2D + zoom continu d'une texture
// proceduriale (damier psyche). Pas de texture externe = sizecoding.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBpm;
uniform float uBass;
uniform float uMid;
uniform float uKick;

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 *
        (vec3(1.0, 0.7, 0.4) * t + vec3(0.0, 0.4, 0.7)));
}

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x   *= uRes.x / uRes.y;

    float zoom  = 2.0 + 1.5 * sin(uTime * 0.4 + uBass * 1.2);
    float angle = uTime * (0.15 + uBpm * 0.001);
    float c = cos(angle), s = sin(angle);
    vec2 uv = mat2(c, -s, s, c) * p * zoom;

    // Texture procédurale = anneaux concentriques + damier
    float r = length(uv);
    float ang = atan(uv.y, uv.x);
    float rings = 0.5 + 0.5 * cos(r * 6.0 - uTime * 2.0);
    float spokes = 0.5 + 0.5 * cos(ang * 8.0);
    float check = step(0.5, fract(uv.x * 0.5)) ^^ step(0.5, fract(uv.y * 0.5));

    vec3 col = palette(rings * 0.5 + spokes * 0.3 + uMid * 0.2);
    col *= 0.5 + 0.5 * float(check);
    // Boost luminosité sur kick
    col *= 1.0 + uKick * 0.6;

    // Vignette
    col *= smoothstep(2.5, 0.5, length(p) * 1.4);
    fragColor = vec4(col, 1.0);
}
