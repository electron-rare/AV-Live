#version 150

// Caustics : surface liquide vue d'au-dessus, lumière qui se concentre
// en patterns chimériques. Trick classique : sin/cos couches + mod.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x   *= uRes.x / uRes.y;

    float t = uTime * (0.4 + uBass * 0.3);
    vec2 q = p * 5.0;
    // Plusieurs couches d'ondes croisées
    float c = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 dir = vec2(cos(fi * 1.7), sin(fi * 1.3));
        c += sin(dot(q, dir) + t * (1.0 + fi * 0.3));
    }
    c = abs(c) * 0.2;

    // Caustic pattern : 1/dist au pic le plus proche
    c = pow(c, 1.5);
    // Couleur : eau bleu-vert + reflets dorés sur kick
    vec3 water = mix(vec3(0.0, 0.15, 0.35), vec3(0.0, 0.6, 0.9), c);
    vec3 gold  = vec3(1.0, 0.85, 0.5) * c * c * 1.5 * (1.0 + uKick * 0.5);
    vec3 col = water + gold * (0.6 + uTreble * 0.6);
    // Vignette douce
    col *= smoothstep(1.5, 0.3, length(p) * 1.2);
    fragColor = vec4(col, 1.0);
}
