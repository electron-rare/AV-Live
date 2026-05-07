#version 150

// Tunnel de cubes : SDF cubes répétés dans grille 3D, raymarch.
// Boites flottantes perçues comme défilant vers la caméra.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

vec3 opRep(vec3 p, vec3 c) { return mod(p + 0.5*c, c) - 0.5*c; }

float map(vec3 p) {
    // Tunnel hollow : cubes seulement en couronne (pas au centre)
    float r = length(p.xy);
    float wall = max(0.0, 1.5 - r);  // empty inside
    if (wall > 0.5) return 9.0;       // far away inside

    vec3 q = opRep(p, vec3(1.0));
    return sdBox(q, vec3(0.30 + uBass * 0.08));
}

vec3 normal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)));
}

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(1.0, 0.5, 0.4) * t + vec3(0.0, 0.4, 0.7)));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * uRes) / uRes.y;
    vec3 ro = vec3(0.0, 0.0, uTime * (1.5 + uBpm * 0.005 + uKick * 1.5));
    vec3 rd = normalize(vec3(uv, 1.2));
    // Roll lent
    float a = uTime * 0.15;
    float c = cos(a), s = sin(a);
    rd.xy = mat2(c, -s, s, c) * rd.xy;

    float t = 0.0;
    float minD = 9.0;
    bool hit = false;
    for (int i = 0; i < 56; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        minD = min(minD, d);
        if (d < 0.001) { hit = true; break; }
        if (t > 25.0) break;
        t += d * 0.85;
    }

    vec3 col = vec3(0.02, 0.04, 0.10);
    if (hit) {
        vec3 p = ro + rd * t;
        vec3 n = normal(p);
        float diff = max(0.0, dot(n, normalize(vec3(0.5, 0.6, -0.5))));
        float fres = pow(1.0 - max(0.0, dot(n, -rd)), 3.0);
        vec3 base = palette(floor(p.z) * 0.07 + uMid * 0.4 + uTime * 0.05);
        col = base * (0.3 + 0.7 * diff) + fres * vec3(1.0, 0.9, 0.7);
        col = mix(col, vec3(0.02, 0.02, 0.06), smoothstep(5.0, 22.0, t));
    } else {
        // Glow autour des cubes manqués
        col += vec3(0.4, 0.6, 1.0) * exp(-minD * 8.0) * 0.5;
    }
    col *= 1.0 + uKick * 0.4 + uTreble * 0.2;
    fragColor = vec4(col, 1.0);
}
