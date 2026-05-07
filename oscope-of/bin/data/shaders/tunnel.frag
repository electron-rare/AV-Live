#version 120

// Cylindrical pseudo-3D tunnel. Closed-form mapping from screen UV to
// (angle, depth) — no real raymarching needed for an infinite straight
// tunnel. Twist is added per-depth slice based on lead amplitude.

uniform vec2  uRes;
uniform float uTime;
uniform float uTravel;
uniform float uBpm;
uniform float uKick;
uniform float uBass;
uniform float uLead;
uniform float uPad;

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(1.0) * t + vec3(0.0, 0.33, 0.67)));
}

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x *= uRes.x / uRes.y;

    // Polar coords -> tunnel space
    float r = length(p);
    float a = atan(p.y, p.x);
    if (r < 0.001) r = 0.001;

    // depth z = 1/r so r→0 is far. Travel scrolls slices.
    float z = 1.0 / r + uTravel;
    // Twist: deeper = more rotation, modulated by lead
    a += z * (0.15 + uLead * 0.6);

    // Slice index for repeating bands
    float slice = floor(z * 2.0);
    float frac  = fract(z * 2.0);

    // Brick / ring pattern — checker on (slice, angle)
    float ang  = a / 6.28318 * 16.0;
    float wall = mod(floor(ang) + slice, 2.0);

    // Base color cycles along depth + slight bass push
    vec3 col = palette(slice * 0.07 + uTime * 0.05 + uBass * 0.2);

    // Bright "lamps" every 4 slices
    float lampMask = step(0.92, fract(slice / 4.0));
    float lamp = (1.0 - smoothstep(0.0, 0.4, abs(frac - 0.5))) * lampMask;
    col += vec3(1.0, 0.9, 0.7) * lamp * (0.6 + uKick * 1.5);

    // Wall vs floor stripes alternate brightness
    col *= mix(0.45, 1.0, wall);

    // Add edges between bricks (subtle dark line)
    float edge = smoothstep(0.0, 0.05, abs(frac - 0.5));
    col *= mix(0.7, 1.0, edge);

    // Distance fog : pixels close to center (far away) fade to background
    float fog = smoothstep(0.0, 0.85, r);
    col = mix(vec3(0.0, 0.0, 0.05 + uPad * 0.15), col, fog);

    // Outer ring vignette
    col *= smoothstep(2.0, 0.4, length(p));

    gl_FragColor = vec4(col, 1.0);
}
