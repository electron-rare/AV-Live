#version 150

// Twister bars : 4 colonnes verticales tournant sur axe Y, gradient
// palette par hauteur. Mythe Amiga (Spaceballs etc.). Audio-réactif :
// vitesse de rotation suit BPM, couleur cycle modulé par mid.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBpm;
uniform float uMid;
uniform float uKick;

#define NCOL 4

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 *
        (vec3(1.0, 0.6, 0.4) * t + vec3(0.0, 0.33, 0.67)));
}

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x   *= uRes.x / uRes.y;

    // Repère colonne : on divise l'écran horizontalement en NCOL bandes.
    float cw = 0.55;                          // largeur chaque bar
    float speed = 0.4 + uBpm * 0.005;
    vec3 col = vec3(0.02, 0.04, 0.06);        // fond bleu nuit

    for (int i = 0; i < NCOL; i++) {
        float fi   = float(i);
        // Centre X de la barre, espacement régulier
        float cx   = -1.5 + 1.0 * fi;
        // Phase rotation propre + offset par barre
        float phase = uTime * speed * (1.0 + fi * 0.08) + fi * 0.7;

        // Coord locale dans la barre
        float lx = (p.x - cx);
        float ly = p.y;

        // "Rotation" sur axe Y : la largeur visible varie en sin(phase)
        // → projection 3D simulée. lx normalisé sur cw.
        float xn = lx / cw;
        if (abs(xn) <= 1.0) {
            // l'angle apparent du faceting du twister
            float ang = atan(xn, sin(phase + ly * 1.6));
            // Couleur gradient vertical + cycle hue par phase
            float t   = ly * 0.5 + 0.5;
            vec3 base = palette(t * 0.7 + phase * 0.05 + uMid * 0.3);
            // Faceting = ombre additionnelle selon angle (faux 3D)
            float facet = 0.5 + 0.5 * cos(ang * 4.0 + phase * 2.0);
            col = mix(col, base * (0.4 + facet * 1.0), 0.95);
            // Bord clair sur les arêtes
            float edge = smoothstep(0.85, 1.0, abs(xn));
            col += vec3(1.0, 0.9, 0.7) * edge * 0.6 * (0.8 + uKick * 1.5);
        }
    }

    // Scanlines CRT
    col *= 0.85 + 0.15 * sin(gl_FragCoord.y * 1.5);

    fragColor = vec4(col, 1.0);
}
