#version 150

// Grille perspective infinie qui scrolle vers la caméra, façon Tron / outrun.
// Pas de raymarching — juste un mapping screen-space → ground plane.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

void main() {
    vec2 uv = (gl_FragCoord.xy / uRes) - 0.5;
    uv.x *= uRes.x / uRes.y;

    // Ground plane : seulement le bas de l'écran (uv.y < 0)
    if (uv.y > 0.0) {
        // Sky gradient : bleu → magenta horizon
        float sk = clamp(uv.y * 1.5, 0.0, 1.0);
        vec3 sky = mix(vec3(0.6, 0.1, 0.4), vec3(0.05, 0.05, 0.2), sk);
        // Soleil retro
        vec2 sunC = vec2(0.0, 0.05);
        float sunD = length(uv - sunC);
        float sun = smoothstep(0.18, 0.0, sunD);
        // Bandes horizontales sur le soleil
        float bands = step(0.5, fract((uv.y - sunC.y) * 30.0));
        sun *= bands;
        sky += sun * vec3(1.0, 0.3, 0.5);
        fragColor = vec4(sky, 1.0);
        return;
    }

    // Inverse perspective : ground = uv.y / -1 → distance, uv.x / -y → x
    float t = uTime * (1.0 + uBpm * 0.005 + uKick * 1.5);
    float fz = -1.0 / uv.y;
    float fx = uv.x * fz;
    float fy = fz - t;

    // Grille
    float lineX = abs(fract(fx * 4.0) - 0.5);
    float lineY = abs(fract(fy * 0.8) - 0.5);
    float w = 0.05 + uBass * 0.04;
    float gx = smoothstep(w, 0.0, lineX);
    float gy = smoothstep(w * 0.5, 0.0, lineY);
    float grid = max(gx, gy);

    // Couleur : magenta vif sur fond sombre
    vec3 lineCol = vec3(1.0, 0.2, 0.8) * (1.0 + uTreble * 0.8);
    vec3 col = vec3(0.05, 0.0, 0.1) + lineCol * grid;
    // Fade vers l'horizon
    col *= smoothstep(0.0, -0.5, uv.y) * 1.2 + 0.2;
    col *= 1.0 + uKick * 0.3;
    fragColor = vec4(col, 1.0);
}
