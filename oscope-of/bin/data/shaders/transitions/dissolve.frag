#version 150
#extension GL_ARB_texture_rectangle : enable

uniform sampler2DRect uPrev;
uniform sampler2DRect uCur;
uniform vec2  uRes;
uniform float uT;

out vec4 fragColor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    // Y-flip : gl_FragCoord est bottom-left, FBO content est top-left.
    vec2 px = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y);
    float n = hash(floor(px / 6.0));         // bruit en blocs 6x6
    float k = smoothstep(uT - 0.08, uT + 0.08, n);
    vec3 a = texture(uPrev, px).rgb;
    vec3 b = texture(uCur,  px).rgb;
    fragColor = vec4(mix(b, a, k), 1.0);
}
