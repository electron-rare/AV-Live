#version 150
#extension GL_ARB_texture_rectangle : enable

uniform sampler2DRect uPrev;
uniform sampler2DRect uCur;
uniform vec2  uRes;
uniform float uT;

out vec4 fragColor;

void main() {
    vec2 px = gl_FragCoord.xy;
    vec2 uv = px / uRes;
    // Wipe radial depuis le centre. À uT=0 : tout uPrev. À uT=1 : tout uCur.
    float d = length(uv - 0.5) * 1.5;     // 0 au centre, ~1 au coin
    float k = smoothstep(uT - 0.06, uT + 0.06, d);
    vec3 a = texture(uPrev, px).rgb;
    vec3 b = texture(uCur,  px).rgb;
    // Anneau lumineux à la frontière
    float ring = exp(-pow((d - uT) * 30.0, 2.0));
    vec3 col = mix(b, a, k) + vec3(1.0, 0.9, 0.7) * ring * 0.8;
    fragColor = vec4(col, 1.0);
}
