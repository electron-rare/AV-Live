#version 150

// Glow CRT phosphor : 9-tap Gaussian + threshold + additive.
// Préserve la couleur d'origine et ajoute un halo vert pondéré.

uniform sampler2DRect uTex;
uniform vec2 uTexel;       // 1.0 / textureSize
uniform float uIntensity;  // boost global (1.0 = neutre)

in vec2 vUV;
out vec4 fragColor;

void main() {
    // ofTexture par défaut sur of macOS = sampler2DRect (coords pixel).
    vec2 p = vUV;
    vec4 base = texture(uTex, p);

    // 9-tap (3x3) gaussian.
    float w[9] = float[9](
        1.0, 2.0, 1.0,
        2.0, 4.0, 2.0,
        1.0, 2.0, 1.0
    );
    vec4 sum = vec4(0.0);
    int idx = 0;
    for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            vec2 q = p + vec2(float(dx), float(dy));
            sum += texture(uTex, q) * w[idx];
            idx++;
        }
    }
    sum /= 16.0;

    // Threshold : seuil sur la luminance pour ne booster que le tracé.
    float l = dot(sum.rgb, vec3(0.299, 0.587, 0.114));
    float bloom = smoothstep(0.05, 0.6, l);
    vec3 glowCol = vec3(0.0, 1.0, 0.5) * bloom * uIntensity;

    fragColor = vec4(base.rgb + glowCol, 1.0);
}
