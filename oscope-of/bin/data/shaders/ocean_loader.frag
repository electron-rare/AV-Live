#version 150

// Ocean Software Loader homage : bandes horizontales rainbow
// scrollantes typiques des chargements C64/Spectrum 1986-1990.
// Greetings Martin Galway, Jonathan Dunn.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uMid;
uniform float uKick;
uniform float uBpm;

vec3 paletteOcean(float t) {
    // Rainbow strict avec césures dures (pas de smooth)
    int idx = int(floor(t * 8.0)) % 8;
    if (idx == 0) return vec3(1.0, 0.0, 0.0);  // rouge
    if (idx == 1) return vec3(1.0, 0.5, 0.0);  // orange
    if (idx == 2) return vec3(1.0, 1.0, 0.0);  // jaune
    if (idx == 3) return vec3(0.0, 1.0, 0.0);  // vert
    if (idx == 4) return vec3(0.0, 1.0, 1.0);  // cyan
    if (idx == 5) return vec3(0.0, 0.5, 1.0);  // bleu
    if (idx == 6) return vec3(0.5, 0.0, 1.0);  // violet
    return vec3(1.0, 0.0, 1.0);                // magenta
}

void main() {
    vec2 uv = gl_FragCoord.xy / uRes;
    // Bandes horizontales scrollantes vers le bas
    float speed = 0.5 + uBpm * 0.003;
    float t = uv.y * 12.0 + uTime * speed;
    vec3 col = paletteOcean(t);

    // Subtle scanlines CRT
    float sl = mod(gl_FragCoord.y, 2.0);
    if (sl < 1.0) col *= 0.85;

    // Border noire haut/bas (style Ocean loader avec bandes)
    if (uv.y < 0.05 || uv.y > 0.95) col = vec3(0.0);

    // Pulse audio sur kick
    col *= 1.0 + uKick * 0.4;
    fragColor = vec4(col, 1.0);
}
