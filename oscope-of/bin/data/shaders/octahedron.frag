#version 150

// Octahedron raymarched : SDF octahedre central, rotation continue,
// reflection via fresnel pour effet métallique chrome.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

float sdOctahedron(vec3 p, float s) {
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735;
}

float map(vec3 p) {
    // Rotation 3D continue
    float t = uTime * (0.5 + uBpm * 0.002);
    float c = cos(t), s = sin(t);
    p.xz = mat2(c, -s, s, c) * p.xz;
    p.xy = mat2(c, -s, s, c) * p.xy;
    return sdOctahedron(p, 0.8 + uBass * 0.4);
}

vec3 normal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)));
}

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(1.0, 0.6, 0.5) * t + vec3(0.0, 0.4, 0.6)));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * uRes) / uRes.y;
    vec3 ro = vec3(0.0, 0.0, -3.0);
    vec3 rd = normalize(vec3(uv, 1.0));

    // Raymarch
    float t = 0.0;
    bool hit = false;
    for (int i = 0; i < 64; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if (d < 0.001) { hit = true; break; }
        if (t > 10.0) break;
        t += d;
    }

    vec3 col = vec3(0.02, 0.04, 0.10);
    // Fond : bandes radiales subtles
    float r = length(uv);
    col += vec3(0.1, 0.2, 0.4) * exp(-r * 1.5) * (0.5 + uMid * 0.5);

    if (hit) {
        vec3 p = ro + rd * t;
        vec3 n = normal(p);
        // Reflection chrome : palette par direction normale
        vec3 ref = reflect(rd, n);
        vec3 metal = palette(ref.x * 0.5 + ref.y * 0.3 + uTime * 0.1);
        // Fresnel
        float fres = pow(1.0 - max(0.0, dot(n, -rd)), 3.0);
        col = metal * (0.4 + 0.6 * fres);
        // Highlight specular
        vec3 ld = normalize(vec3(0.5, 0.7, -0.5));
        float spec = pow(max(0.0, dot(reflect(-ld, n), -rd)), 32.0);
        col += vec3(1.0, 0.95, 0.9) * spec * 0.8;
    }
    col *= 1.0 + uKick * 0.4 + uTreble * 0.2;
    fragColor = vec4(col, 1.0);
}
