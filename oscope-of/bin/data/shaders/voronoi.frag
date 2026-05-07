#version 150

// Voronoi / Worley cells (Steven Worley 1996 + Inigo Quilez approach).
// Pour chaque pixel : distance F1 au site le plus proche, F2 au 2e.
// Couleur basée sur F1 (bordure cellulaire = F2-F1), animation temporelle.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

void main() {
    vec2 uv = gl_FragCoord.xy / uRes.xx * 6.0;  // ~6 cells horizontalement
    uv.y   *= uRes.x / uRes.y;

    vec2  ip = floor(uv);
    vec2  fp = fract(uv);

    float F1 = 9.9, F2 = 9.9;
    vec2  closest = vec2(0.0);

    // Recherche 3x3 cells autour du fragment
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash2(ip + g);
            // Site animé sur orbite lente + bass shake
            o = 0.5 + 0.5 * sin(uTime * (0.5 + uBass * 0.6) + 6.2831 * o);
            vec2 r = g + o - fp;
            float d = dot(r, r);
            if (d < F1) { F2 = F1; F1 = d; closest = ip + g; }
            else if (d < F2) { F2 = d; }
        }
    }

    F1 = sqrt(F1);
    F2 = sqrt(F2);

    // Bordure cellulaire (F2-F1 = distance à la frontière)
    float edge = smoothstep(0.0, 0.10, F2 - F1);

    // Couleur par cell : hash de la position pour stabilité
    vec3 cellColor = 0.5 + 0.5 * sin(
        vec3(0.0, 2.1, 4.2) + hash2(closest).x * 6.28 + uTime * 0.3
    );
    cellColor *= 0.4 + 0.8 * smoothstep(0.7, 0.0, F1);  // assombrit centre

    // Mix bordure phosphor cyan
    vec3 borderColor = vec3(0.4, 0.9, 1.0) * (1.0 - edge) * (1.0 + uTreble * 1.5);

    vec3 col = mix(borderColor, cellColor, edge);

    // Pulse sur kick : flash global
    col += vec3(uKick * 0.3);

    // Vignette
    vec2 v = (gl_FragCoord.xy / uRes) - 0.5;
    col *= smoothstep(1.2, 0.3, length(v) * 1.5);

    fragColor = vec4(col, 1.0);
}
