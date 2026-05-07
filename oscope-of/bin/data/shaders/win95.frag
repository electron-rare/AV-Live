#version 150

// Windows 95 startup homage : ciel bleu nuageux, fenêtre 95 stylisée.
// Pixelisé. Greetings tous les hackers de l'ère pre-XP.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
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
    for (int i = 0; i < 4; i++) { v += amp * noise(p); p *= 2.0; amp *= 0.5; }
    return v;
}

void main() {
    vec2 px = floor(gl_FragCoord.xy / 2.0) * 2.0;  // pixelize 2x2
    vec2 uv = px / uRes;

    // Ciel bleu Win95 + nuages FBM
    float clouds = fbm(uv * 2.5 + vec2(uTime * 0.1, 0.0));
    vec3 sky = mix(vec3(0.05, 0.20, 0.55), vec3(1.0, 1.0, 1.0), clouds);
    vec3 col = sky;

    // Bandeau haut "Microsoft Windows 95" stylisé
    // 4 carrés colorés (rouge/vert/bleu/jaune) ondulants comme le logo
    vec2 logoC = uRes * vec2(0.5, 0.55);
    vec2 d = px - logoC;
    if (abs(d.x) < 90.0 && abs(d.y) < 90.0) {
        // 4 quadrants avec couleurs Win
        bool right = d.x > 0.0;
        bool top   = d.y > 0.0;
        vec3 quad;
        if (right && top)        quad = vec3(0.95, 0.20, 0.20);  // rouge
        else if (!right && top)  quad = vec3(0.20, 0.85, 0.20);  // vert
        else if (right && !top)  quad = vec3(0.20, 0.40, 0.95);  // bleu
        else                     quad = vec3(0.95, 0.85, 0.10);  // jaune
        // Wave : déplace selon l'angle pour effet "drapeau"
        float wave = sin(d.x * 0.04 + uTime * 1.0) * 8.0;
        if (abs(d.y - wave) < 80.0) col = quad * (1.0 + uKick * 0.3);
    }

    // Pulse uMid → flicker du logo
    if (uMid > 0.5) col *= 1.1;
    fragColor = vec4(col, 1.0);
}
