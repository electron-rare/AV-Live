#version 150

// Amiga Workbench 1.x homage : fond pattern damier bleu/blanc,
// barres de titre en haut, fenêtres pixelées. Pas le vrai logo.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uKick;

void main() {
    vec2 p = gl_FragCoord.xy;
    vec2 uv = p / uRes;
    // Pixelisation : on snap à des blocs 4x4
    vec2 px = floor(p / 4.0) * 4.0;

    // Background damier 1px noir/orange (Workbench classique)
    vec2 chk = floor(px / 4.0);
    bool dark = mod(chk.x + chk.y, 2.0) < 0.5;
    vec3 col = dark ? vec3(0.0, 0.06, 0.40) : vec3(0.85, 0.45, 0.0);

    // Barre de titre haut (16 px high)
    if (p.y > uRes.y - 18.0) {
        // Pattern raz raz de tirets (style Amiga)
        bool stripe = mod(floor(p.x / 4.0), 2.0) < 0.5;
        col = stripe ? vec3(0.0, 0.0, 0.30) : vec3(0.85, 0.85, 0.85);
    }
    if (p.y > uRes.y - 22.0 && p.y < uRes.y - 18.0) {
        col = vec3(0.85, 0.85, 0.85);  // séparateur
    }

    // Une "fenêtre" qui se déplace
    float wt = uTime * 0.25;
    vec2 wPos = vec2(uRes.x * 0.3 + sin(wt) * 80.0,
                     uRes.y * 0.4 + cos(wt * 0.8) * 60.0);
    vec2 wSize = vec2(220.0, 140.0);
    if (p.x > wPos.x && p.x < wPos.x + wSize.x &&
        p.y > wPos.y && p.y < wPos.y + wSize.y) {
        // Bordure
        if (p.x < wPos.x + 4.0 || p.x > wPos.x + wSize.x - 4.0 ||
            p.y < wPos.y + 4.0 || p.y > wPos.y + wSize.y - 4.0) {
            col = vec3(0.85, 0.85, 0.85);
        } else if (p.y > wPos.y + wSize.y - 18.0) {
            // Title bar
            bool stripe = mod(floor(p.x / 4.0), 2.0) < 0.5;
            col = stripe ? vec3(0.0, 0.0, 0.30) : vec3(0.85, 0.85, 0.85);
        } else {
            col = vec3(0.85, 0.85, 0.85);
            // Icône simple (carré coloré pulsant audio)
            vec2 icon = (p - wPos - vec2(20.0, 20.0));
            if (icon.x > 0.0 && icon.x < 32.0 && icon.y > 0.0 && icon.y < 32.0) {
                col = vec3(0.85, 0.0, 0.0) * (1.0 + uKick * 0.6);
            }
        }
    }

    // Effet "bouge" sur kick
    if (uKick > 0.5) {
        col *= vec3(1.0 + uKick * 0.4);
    }
    fragColor = vec4(col, 1.0);
}
