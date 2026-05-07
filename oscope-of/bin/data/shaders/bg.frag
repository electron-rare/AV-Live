#version 150

// Layer arrière-plan réactif sound_algo.
// Grille hexagonale qui pulse sur kick, gradient HSV qui tourne au beat,
// distortion modulée par la mélodie. Subtil par défaut (alpha global ~0.6).

uniform vec2 uResolution;
uniform float uTime;
uniform float uBpm;
uniform int   uBeat;
uniform float uKick;
uniform float uHat;
uniform float uSnare;
uniform float uClap;
uniform float uPerc;
uniform float uMelody;
uniform float uAcid;
uniform float uHarmony;

out vec4 fragColor;

// HSV -> RGB.
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// Distance hexagonale (vector display style).
float hexDist(vec2 p) {
    p = abs(p);
    return max(p.x * 0.866 + p.y * 0.5, p.y);
}

vec4 hexCoords(vec2 uv) {
    vec2 r = vec2(1.0, 1.732);
    vec2 h = r * 0.5;
    vec2 a = mod(uv, r) - h;
    vec2 b = mod(uv - h, r) - h;
    vec2 gv = (dot(a, a) < dot(b, b)) ? a : b;
    float d = hexDist(gv);
    return vec4(gv, d, 1.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution) / min(uResolution.x, uResolution.y);

    // Distortion mélodique.
    uv += 0.05 * uMelody * vec2(sin(uv.y * 6.0 + uTime * 1.3),
                                cos(uv.x * 5.0 + uTime * 0.9));

    // Grille hexagonale.
    float scale = 6.0 + 2.0 * uHarmony - 1.5 * uKick;
    vec4 hex = hexCoords(uv * scale);
    float ring = smoothstep(0.5, 0.49, hex.z);
    float pulse = smoothstep(0.4 - 0.3 * uKick, 0.5, hex.z);

    // Couleur HSV qui tourne avec beat.
    float hue = fract(0.55 + 0.02 * float(uBeat) + 0.05 * uAcid);
    vec3 col = hsv2rgb(vec3(hue, 0.6 + 0.3 * uClap, 0.35 + 0.5 * pulse));

    // Vignette radiale.
    float r = length(uv);
    col *= smoothstep(1.4, 0.2, r);

    // Boost kick.
    col += 0.15 * uKick * vec3(0.6, 0.2, 1.0);

    // Trame snare (lignes horizontales).
    col += 0.08 * uSnare * sin(uv.y * 200.0);

    // Hat = grain léger.
    float n = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
    col += 0.06 * uHat * (n - 0.5);

    fragColor = vec4(col, 0.85);
}
