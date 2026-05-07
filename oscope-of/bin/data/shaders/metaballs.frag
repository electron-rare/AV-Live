#version 150

// Metaballs : champ scalaire = somme de potentiels rᵢ²/distᵢ², seuil
// iso-surface, anneaux additionnels pour le contour. Audio-réactif :
// position des balls modulée par bands, threshold par kick.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;

#define NB 7

void main() {
    vec2 p  = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x    *= uRes.x / uRes.y;

    float field = 0.0;
    for (int i = 0; i < NB; i++) {
        float fi = float(i);
        // Position des balls : orbites lentes + modulation audio
        vec2 c = vec2(
            cos(uTime * (0.3 + fi * 0.07) + fi * 1.1) * (0.6 + uMid * 0.3),
            sin(uTime * (0.4 + fi * 0.05) + fi * 1.7) * (0.4 + uBass * 0.3)
        );
        float r = 0.18 + 0.05 * sin(uTime * 0.7 + fi);
        float d = length(p - c);
        // Inverse-square potential (smooth falloff)
        field += (r * r) / max(d * d, 0.001);
    }

    // Seuil iso-surface modulé par kick (le blob "respire" sur kick)
    float thresh = 4.5 - uKick * 1.5;
    float surf   = smoothstep(thresh - 0.5, thresh + 0.5, field);

    // Couleur dégradée par champ — intérieur chaud, contour cyan
    vec3 inside  = vec3(1.0, 0.4 + uTreble * 0.4, 0.2);
    vec3 contour = vec3(0.2, 0.8, 1.0);
    vec3 col = mix(contour, inside, surf);

    // Halo extérieur (anneau plus large pour l'épaisseur visuelle)
    float halo = smoothstep(thresh - 1.5, thresh - 0.4, field) *
                 (1.0 - smoothstep(thresh - 0.4, thresh, field));
    col += vec3(0.3, 0.9, 1.0) * halo * 0.6;

    fragColor = vec4(col, 1.0);
}
