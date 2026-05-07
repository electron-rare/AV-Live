#version 150

// Truchet pavage + kaleidoscope. Tuiles aleatoires avec 2 quart-de-cercle
// dans 2 coins, hash(cell) decide l'orientation. Avant le pavage, on
// kaleido-fold pour symetrie radiale.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBpm;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 *
        (vec3(1.0, 0.6, 0.4) * t + vec3(0.0, 0.33, 0.67)));
}

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x   *= uRes.x / uRes.y;

    // Kaleido fold : N segments
    float n = 6.0 + floor(uMid * 6.0);  // 6..12 axes selon mid
    float ang = atan(p.y, p.x);
    float seg = 6.28318 / n;
    ang = abs(mod(ang + seg * 0.5, seg) - seg * 0.5);
    float r = length(p);
    p = vec2(cos(ang), sin(ang)) * r;

    // Slow zoom + rotation
    float t = uTime * (0.2 + uBpm * 0.001);
    p *= 4.0 + sin(t) * 1.0;
    float c = cos(t * 0.2), s = sin(t * 0.2);
    p = mat2(c, -s, s, c) * p;

    // Cell + sub-cell coords
    vec2 ip = floor(p);
    vec2 fp = fract(p) - 0.5;

    // Random tile orientation
    float h = hash(ip + uKick * 0.3);  // shift par kick pour micro-variations
    if (h > 0.5) fp.x = -fp.x;

    // Distance aux deux quart-de-cercles : centres en (-0.5, +0.5) et (+0.5, -0.5)
    float d1 = length(fp - vec2(-0.5,  0.5));
    float d2 = length(fp - vec2( 0.5, -0.5));
    float d  = min(abs(d1 - 0.5), abs(d2 - 0.5));  // distance au plus proche arc
    float line = smoothstep(0.05, 0.0, d);

    // Couleur per cell + bord brillant
    vec3 cellCol = palette(h * 1.0 + t * 0.3);
    vec3 col = cellCol * 0.5 + line * vec3(1.0, 0.9, 0.7) * (1.0 + uTreble);
    col *= 1.0 + uKick * 0.5;
    fragColor = vec4(col, 1.0);
}
