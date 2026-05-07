#version 150
#extension GL_ARB_texture_rectangle : enable

uniform sampler2DRect uPrev;
uniform sampler2DRect uCur;
uniform vec2  uRes;
uniform float uT;

out vec4 fragColor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 px = gl_FragCoord.xy;
    float n = hash(floor(px / 6.0));         // bruit en blocs 6x6
    // Bordure dégradée : pixels avec hash < uT viennent de cur, autres de prev,
    // avec un fade doux autour du seuil pour pas un "step" agressif.
    float k = smoothstep(uT - 0.08, uT + 0.08, n);
    vec3 a = texture(uPrev, px).rgb;
    vec3 b = texture(uCur,  px).rgb;
    fragColor = vec4(mix(b, a, k), 1.0);
}
