#version 150

// Plasma fractale FBM (Fractional Brownian Motion).
// 5 octaves de noise additionne, palette IQ cosine.
// Audio-reactif : amplitude FBM monte avec mid, vitesse avec bpm.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

// Hash 2D->1D quick noise base
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    float a = hash(i), b = hash(i + vec2(1, 0));
    float c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
    vec2 u = f * f * (3.0 - 2.0 * f);  // smoothstep
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, amp = 0.5;
    for (int i = 0; i < 5; i++) {
        v += amp * noise(p);
        p  *= 2.13;
        amp *= 0.5;
    }
    return v;
}

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 *
        (vec3(1.0, 0.7, 0.4) * t + vec3(0.0, 0.33, 0.67)));
}

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x   *= uRes.x / uRes.y;

    float t = uTime * (0.2 + uBpm * 0.0015);
    // Domain warping (IQ) : on noise une coordonnee pour distordre
    // l'espace avant le noise principal.
    vec2 q = vec2(fbm(p + t * 0.3), fbm(p + t * 0.27 + 5.2));
    vec2 r = vec2(fbm(p + 2.0 * q + vec2(1.7, 9.2) + t * 0.15),
                  fbm(p + 2.0 * q + vec2(8.3, 2.8) + t * 0.13));
    float v = fbm(p + 3.0 * r) * (0.7 + uMid * 0.6);

    // Couleur cycle hue + boost treble (pulse aigus)
    vec3 col = palette(v + t * 0.05 + uTreble * 0.4);
    col *= 0.5 + 0.7 * v;
    col += vec3(uKick * 0.3);
    fragColor = vec4(col, 1.0);
}
