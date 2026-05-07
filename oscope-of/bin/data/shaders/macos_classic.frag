#version 150

// Classic Mac OS homage : fond gris pixelisé, fenêtre Finder centrale,
// "happy mac" face stylisé. Pixel art procédural pas de logo authentique.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uMid;
uniform float uKick;

float box(vec2 p, vec2 mn, vec2 mx) {
    return (p.x >= mn.x && p.x <= mx.x && p.y >= mn.y && p.y <= mx.y)
        ? 1.0 : 0.0;
}

void main() {
    vec2 p = floor(gl_FragCoord.xy / 3.0) * 3.0;  // pixelize 3x3

    // Fond pattern hatch gris (Mac classic desktop)
    bool hatch = mod(floor(p.x/3.0) + floor(p.y/3.0), 2.0) < 0.5;
    vec3 col = hatch ? vec3(0.7, 0.7, 0.7) : vec3(0.55, 0.55, 0.55);

    // Menu bar haut (20 px)
    if (gl_FragCoord.y > uRes.y - 20.0) {
        col = vec3(0.95, 0.95, 0.95);
        if (gl_FragCoord.y > uRes.y - 21.0) col = vec3(0.0); // séparateur
    }

    // Fenêtre centrale 320x200
    vec2 wMin = uRes * 0.5 - vec2(160.0, 100.0);
    vec2 wMax = wMin + vec2(320.0, 200.0);
    if (box(gl_FragCoord.xy, wMin, wMax) > 0.5) {
        col = vec3(0.95, 0.95, 0.95);
        // Bordure noire
        if (gl_FragCoord.x < wMin.x + 1.0 || gl_FragCoord.x > wMax.x - 1.0 ||
            gl_FragCoord.y < wMin.y + 1.0 || gl_FragCoord.y > wMax.y - 1.0) {
            col = vec3(0.0);
        }
        // Title bar style Mac avec stripes horizontales
        if (gl_FragCoord.y > wMax.y - 18.0 && gl_FragCoord.y < wMax.y - 2.0) {
            bool s = mod(floor(gl_FragCoord.y), 2.0) < 0.5;
            col = s ? vec3(0.85) : vec3(1.0);
            if (gl_FragCoord.y > wMax.y - 4.0) col = vec3(0.0);
        }
        // Happy mac face (carré + 2 yeux + bouche)
        vec2 face = (gl_FragCoord.xy - wMin - vec2(140.0, 60.0));
        if (face.x > 0.0 && face.x < 40.0 && face.y > 0.0 && face.y < 40.0) {
            // Cadre face
            col = vec3(0.0);
            // Intérieur visage
            if (face.x > 4.0 && face.x < 36.0 && face.y > 4.0 && face.y < 36.0) {
                col = vec3(0.95, 0.95, 0.95) * (1.0 + uKick * 0.3);
                // Yeux
                if ((face.x > 10.0 && face.x < 14.0 && face.y > 22.0 && face.y < 26.0) ||
                    (face.x > 26.0 && face.x < 30.0 && face.y > 22.0 && face.y < 26.0)) {
                    col = vec3(0.0);
                }
                // Bouche (sourire)
                if (face.y > 12.0 && face.y < 16.0 &&
                    face.x > 12.0 && face.x < 28.0) {
                    col = vec3(0.0);
                }
            }
        }
    }
    fragColor = vec4(col, 1.0);
}
