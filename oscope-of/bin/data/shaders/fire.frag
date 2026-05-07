#version 150

// Effet feu : noise FBM scrollant verticalement + gradient chaud.
// Inspiré des effets feu démo Amiga / DOOM.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    float a = hash(i), b = hash(i + vec2(1, 0));
    float c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, amp = 0.5;
    for (int i = 0; i < 5; i++) { v += amp * noise(p); p *= 2.07; amp *= 0.5; }
    return v;
}

void main() {
    vec2 uv = gl_FragCoord.xy / uRes;
    // Coordonnée scrollante verticale (le feu monte)
    vec2 p = vec2(uv.x * 4.0, uv.y * 3.0 - uTime * 1.5);
    float n = fbm(p);

    // Verticale : feu plus fort en bas
    float heightFalloff = 1.0 - uv.y;
    float heat = n * (heightFalloff * 1.3 + uBass * 0.5 + uKick * 0.3);

    // Gradient noir → rouge → orange → jaune → blanc
    vec3 col;
    if (heat < 0.2) col = mix(vec3(0.0), vec3(0.5, 0.0, 0.0), heat / 0.2);
    else if (heat < 0.45) col = mix(vec3(0.5, 0.0, 0.0), vec3(1.0, 0.4, 0.0), (heat - 0.2) / 0.25);
    else if (heat < 0.7) col = mix(vec3(1.0, 0.4, 0.0), vec3(1.0, 0.95, 0.2), (heat - 0.45) / 0.25);
    else col = mix(vec3(1.0, 0.95, 0.2), vec3(1.0, 1.0, 1.0), min(1.0, (heat - 0.7) / 0.3));

    // Boost saturation par treble (cinder spark)
    col *= 1.0 + uTreble * 0.5;
    fragColor = vec4(col, 1.0);
}
