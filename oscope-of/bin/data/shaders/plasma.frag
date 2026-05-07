#version 150

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBpm;
uniform float uBass;
uniform float uLead;
uniform float uKick;
uniform float uPad;

vec3 palette(float t) {
    // Inigo Quilez-style cosine palette, hue tilted toward magenta/cyan
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.0, 0.33, 0.67);
    return a + b * cos(6.28318 * (c * t + d));
}

void main() {
    vec2 p  = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x *= uRes.x / uRes.y;

    float t = uTime * (0.4 + uBpm * 0.005);
    float turb = 1.0 + uLead * 1.8 + uKick * 1.0;

    float v = 0.0;
    v += sin(p.x * 4.0 * turb + t * 1.6);
    v += sin(p.y * 5.0 * turb - t * 1.3);
    v += sin((p.x + p.y) * 3.0 * turb + t * 2.1);
    float r = length(p);
    v += sin(r * 8.0 - t * 2.0 + uBass * 6.0);
    v *= 0.25;

    // Bass swells push the hue
    float hue = v + t * 0.15 + uBass * 0.3;
    vec3 col = palette(hue);

    // Pad amplitude → glow toward white
    col = mix(col, vec3(1.0), uPad * 0.4 * smoothstep(0.0, 1.5, abs(v)));

    // Kick → darker contrast pulse
    col *= mix(1.0, 1.6, uKick);

    // Soft radial vignette
    col *= smoothstep(1.5, 0.2, r);

    fragColor = vec4(col, 1.0);
}
