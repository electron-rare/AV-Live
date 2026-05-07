#version 150
#extension GL_ARB_texture_rectangle : enable

uniform sampler2DRect uPrev;
uniform sampler2DRect uCur;
uniform vec2  uRes;
uniform float uT;          // 0..1 progression de la transition

out vec4 fragColor;

void main() {
    vec2 px = gl_FragCoord.xy;
    vec3 a = texture(uPrev, px).rgb;
    vec3 b = texture(uCur,  px).rgb;
    fragColor = vec4(mix(a, b, uT), 1.0);
}
