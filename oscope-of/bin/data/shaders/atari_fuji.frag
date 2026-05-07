#version 150

// Atari Fuji homage : 3 barres verticales convergentes au sommet,
// fond rouge magenta vintage. Pixelisation 4x4. Logo abstrait
// (pas la marque exacte) qui évoque le Fuji 1972.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uMid;
uniform float uKick;

void main() {
    // Pixelize
    vec2 p = floor(gl_FragCoord.xy / 4.0) * 4.0;
    vec2 c = (p / uRes - 0.5) * 2.0;
    c.x *= uRes.x / uRes.y;

    // Fond gradient rouge → noir
    float grad = clamp(0.5 - c.y * 0.4, 0.0, 1.0);
    vec3 col = mix(vec3(0.10, 0.0, 0.05), vec3(0.95, 0.10, 0.20), grad);

    // 3 barres convergentes — modélisation : à y=-1 elles sont à x=-0.6/0/+0.6,
    // à y=+1 elles sont à x=0 (toutes). Largeur des barres aussi diminue.
    float yBase = (c.y + 1.0) * 0.5;  // 0..1
    float top = 1.0 - yBase;
    // 3 positions originales
    float positions[3] = float[3](-0.5, 0.0, 0.5);
    // Convergence : position(y) = posOrig * (1 - top * 1.0)
    float w = 0.10 + top * 0.06;  // largeur (légèrement plus large en haut)
    bool inBar = false;
    for (int i = 0; i < 3; i++) {
        float bx = positions[i] * (1.0 - top * 0.6);  // converge un peu
        if (abs(c.x - bx) < w * 0.5 && c.y < 0.7 && c.y > -0.85) inBar = true;
    }
    // Barre transversale haute (le "chapeau")
    if (c.y > 0.55 && c.y < 0.70 && abs(c.x) < 0.7) inBar = true;

    if (inBar) {
        col = vec3(0.95, 0.85, 0.20) * (1.0 + uKick * 0.3);
    }

    // Texte "ATARI" en bas (procédural minimal — barres horizontales)
    if (c.y > -0.95 && c.y < -0.85 && abs(c.x) < 0.5) {
        bool stripe = mod(floor(p.x / 8.0), 2.0) < 0.5;
        if (stripe) col = vec3(0.95, 0.85, 0.20);
    }

    fragColor = vec4(col, 1.0);
}
