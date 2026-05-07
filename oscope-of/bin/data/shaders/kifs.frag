#version 150

// KIFS : Kaleidoscopic Iterated Function System (Knighty 2010, IQ).
// Repli 3D + scale + offset, crée des fractales par itérations.
// Pas un raymarcher complet — version 2D simplifiée pour le frag.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(1.0, 0.7, 0.4) * t + vec3(0.0, 0.33, 0.67)));
}

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x   *= uRes.x / uRes.y;

    float t = uTime * (0.15 + uBpm * 0.0008);

    // Iter scale + fold
    float scale = 1.0 + uBass * 0.6;
    float dist = 1e9;
    for (int i = 0; i < 6; i++) {
        // Fold X+Y
        p = abs(p);
        // Rotation
        float a = t + float(i) * 0.4 + uMid * 0.6;
        float c = cos(a), s = sin(a);
        p = mat2(c, -s, s, c) * p;
        // Translate + scale
        p = p * 1.6 - vec2(0.5 + uTreble * 0.2, 0.3);
        dist = min(dist, length(p) / pow(1.6, float(i+1)));
    }

    // Color by distance + iteration
    vec3 col = palette(dist * 8.0 + t * 0.2);
    col *= smoothstep(0.5, 0.0, dist);
    col += vec3(uKick * 0.4);
    fragColor = vec4(col, 1.0);
}
