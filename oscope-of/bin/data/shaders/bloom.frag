#version 150

// Bloom single-pass simplifié : downsample 5x5 + threshold.
// Réservé pour usage futur ; LissajousVis utilise actuellement glow.frag.

uniform sampler2DRect uTex;
uniform vec2 uTexel;
uniform float uThreshold;

in vec2 vUV;
out vec4 fragColor;

void main() {
    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    for (int dy = -2; dy <= 2; ++dy) {
        for (int dx = -2; dx <= 2; ++dx) {
            vec2 q = vUV + vec2(float(dx), float(dy)) * 1.5;
            vec3 c = texture(uTex, q).rgb;
            float l = dot(c, vec3(0.299, 0.587, 0.114));
            float k = smoothstep(uThreshold, uThreshold + 0.2, l);
            acc += c * k;
            wsum += 1.0;
        }
    }
    fragColor = vec4(acc / wsum, 1.0);
}
