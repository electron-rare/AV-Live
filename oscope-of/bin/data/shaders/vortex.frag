#version 150

// Vortex / spirale : warping radial polaire avec twist par profondeur.
// Donne une sensation de tourbillon hypnotique.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(1.0, 0.65, 0.35) * t + vec3(0.0, 0.4, 0.7)));
}

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x   *= uRes.x / uRes.y;

    float r = length(p);
    float a = atan(p.y, p.x);

    // Twist : angle augmente avec 1/r, vitesse modulée par BPM
    float twist = 1.0 / max(r, 0.05);
    float speed = uTime * (0.3 + uBpm * 0.0015);
    a += twist * (0.6 + uBass * 0.5) - speed;

    // Spiral arms : modulation cos(a * arms)
    float arms = 5.0 + floor(uMid * 5.0);
    float v = 0.5 + 0.5 * cos(a * arms + r * 4.0 - speed * 2.0);

    // Halo central
    float core = exp(-r * 4.0) * (1.0 + uKick * 1.5);

    vec3 col = palette(v + r * 0.5 + speed * 0.1);
    col *= 0.4 + 0.7 * v;
    col += vec3(1.0, 0.8, 0.6) * core;

    // Vignette
    col *= smoothstep(1.6, 0.3, r * 1.2);
    fragColor = vec4(col, 1.0);
}
