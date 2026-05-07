#version 150

// SDF raymarched tunnel : torus repeate sur Z, raymarch 48 pas. Plus
// "vrai 3D" que tunnel.frag (qui est un mapping 1/r). Audio reactif.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

// Torus SDF (IQ)
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Repeat domain on Z axis
vec3 opRep(vec3 p, float c) { return vec3(p.x, p.y, mod(p.z + 0.5*c, c) - 0.5*c); }

float map(vec3 p) {
    p = opRep(p, 1.5);
    float r1 = 0.7 + uBass * 0.2;       // rayon majeur (bass)
    float r2 = 0.06 + uTreble * 0.04;   // tube (treble)
    return sdTorus(p, vec2(r1, r2));
}

vec3 normal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 *
        (vec3(1.0, 0.7, 0.4) * t + vec3(0.0, 0.33, 0.67)));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * uRes) / uRes.y;
    vec3 ro = vec3(0.0, 0.0, uTime * (1.0 + uBpm * 0.003 + uKick * 1.5));
    vec3 rd = normalize(vec3(uv, 1.0));

    // Camera roll lent
    float a = uTime * 0.1;
    float c = cos(a), s = sin(a);
    rd.xy = mat2(c, -s, s, c) * rd.xy;

    // Raymarch
    float t = 0.0;
    bool hit = false;
    for (int i = 0; i < 48; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if (d < 0.001) { hit = true; break; }
        if (t > 30.0) break;
        t += d;
    }

    vec3 col = vec3(0.02, 0.04, 0.08);  // sky
    if (hit) {
        vec3 p = ro + rd * t;
        vec3 n = normal(p);
        vec3 ld = normalize(vec3(0.4, 0.6, -0.5));
        float diff = max(0.0, dot(n, ld));
        float fres = pow(1.0 - max(0.0, dot(n, -rd)), 3.0);
        vec3 base = palette(t * 0.05 + uTime * 0.1 + uMid * 0.3);
        col = base * (0.3 + 0.7 * diff) + fres * vec3(1.0, 0.9, 0.7);
        // Distance fog
        col = mix(col, vec3(0.02, 0.04, 0.08), smoothstep(5.0, 25.0, t));
    }

    col *= 1.0 + uKick * 0.4;
    fragColor = vec4(col, 1.0);
}
