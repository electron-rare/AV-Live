#version 150

// Dot tunnel : grille de points en perspective défilant vers la caméra.
// Classique demoscene C64/Amiga.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * uRes) / uRes.y;
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    float speed = 0.5 + uBpm * 0.005 + uKick * 1.0;
    float depth = 1.0 / max(r, 0.05);
    float z = depth + uTime * speed;

    // Tile depth (8 levels par cycle)
    float zi = floor(z * 4.0);
    float zf = fract(z * 4.0);

    // Dots : autour de chaque (slice z, angle), un point
    float arms = 12.0;
    float ang = floor(a / 6.28318 * arms);
    float angF = fract(a / 6.28318 * arms);

    // Distance au centre du dot dans la cellule (zf, angF)
    vec2 cellCoord = vec2(angF, zf) - 0.5;
    float dotDist = length(cellCoord) * 4.0;

    float dot = smoothstep(0.5, 0.0, dotDist);
    // Faraway dots become fainter
    dot *= smoothstep(0.0, 1.5, depth) * smoothstep(8.0, 0.5, depth);

    // Couleur cycle hue par tile z
    float hue = zi * 0.13 + ang * 0.05 + uMid * 0.3;
    vec3 col = 0.5 + 0.5 * cos(6.28318 *
        (vec3(1.0, 0.7, 0.4) * hue + vec3(0.0, 0.4, 0.7)));
    col *= dot * (1.0 + uKick * 0.6);

    fragColor = vec4(col, 1.0);
}
