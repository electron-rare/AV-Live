#version 120
#extension GL_ARB_texture_rectangle : enable

// Composite post-processing pass. Each effect is gated by an intensity
// uniform — set to 0 to skip its branch. Order matters: spatial /
// kaleido first (work in UV), then color / chromatic / glitch.

uniform sampler2DRect uScene;
uniform sampler2DRect uPrev;
uniform vec2  uRes;
uniform float uTime;

uniform float uChroma;
uniform float uBloom;
uniform float uRgbShift;
uniform float uSat;
uniform float uScan;
uniform float uVignette;
uniform float uGrain;
uniform float uPixelate;
uniform float uKaleido;
uniform float uFeedback;
uniform float uFbZoom;
uniform float uFbRot;
uniform float uGlitch;
uniform float uGlitchProb;

varying vec2 vTex;

const float TAU = 6.2831853;

float rand(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 rot2(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c*v.x - s*v.y, s*v.x + c*v.y);
}

vec3 hueRotate(vec3 col, float a) {
    // Approximate hue rotation in YIQ space — fast and visually OK
    float c1 = cos(a), s1 = sin(a);
    mat3 m = mat3(
        0.299 + 0.701*c1 + 0.168*s1, 0.587 - 0.587*c1 + 0.330*s1, 0.114 - 0.114*c1 - 0.497*s1,
        0.299 - 0.299*c1 - 0.328*s1, 0.587 + 0.413*c1 + 0.035*s1, 0.114 - 0.114*c1 + 0.292*s1,
        0.299 - 0.300*c1 + 1.250*s1, 0.587 - 0.588*c1 - 1.050*s1, 0.114 + 0.886*c1 - 0.203*s1
    );
    return clamp(m * col, 0.0, 1.5);
}

void main() {
    vec2 px = gl_FragCoord.xy;
    vec2 uv = px;
    vec2 c  = (px / uRes) - 0.5;

    // 1. Pixelate (snap to block centers)
    if (uPixelate > 0.001) {
        float ps = mix(1.0, 64.0, uPixelate);
        uv = floor(uv / ps) * ps + ps * 0.5;
        c  = (uv / uRes) - 0.5;
    }

    // 2. Kaleidoscope radial mirror
    if (uKaleido > 0.001) {
        float n = floor(mix(2.0, 12.0, uKaleido));
        float ang = atan(c.y, c.x);
        float seg = TAU / n;
        ang = abs(mod(ang + seg*0.5, seg) - seg*0.5);
        float r = length(c);
        c  = vec2(cos(ang), sin(ang)) * r;
        uv = (c + 0.5) * uRes;
    }

    // 3. Glitch — block displacement on horizontal slices
    vec2 glUv = uv;
    if (uGlitch > 0.001) {
        float blockY = floor(uv.y / 14.0);
        float t = floor(uTime * 24.0);
        float r = rand(vec2(blockY, t));
        float prob = mix(0.0, uGlitchProb * 2.5, uGlitch);
        if (r < prob) {
            float shift = (rand(vec2(blockY, t + 1.0)) - 0.5) * 240.0 * uGlitch;
            glUv.x += shift;
        }
    }
    glUv = clamp(glUv, vec2(0.0), uRes - 1.0);

    // 4. Chromatic aberration : RGB channels sampled at radial offsets
    vec2 dir = c * uChroma * 14.0;
    vec3 col;
    col.r = texture2DRect(uScene, clamp(glUv + dir, vec2(0.0), uRes - 1.0)).r;
    col.g = texture2DRect(uScene, glUv).g;
    col.b = texture2DRect(uScene, clamp(glUv - dir, vec2(0.0), uRes - 1.0)).b;

    // 5. Glitch channel swap
    if (uGlitch > 0.55) {
        float swap = step(0.5, rand(vec2(floor(uTime * 12.0), 1.0)));
        col = mix(col, col.brg, swap);
    }

    // 6. Bloom — cheap 5x5 bright-pass average added back
    if (uBloom > 0.001) {
        vec3 bl = vec3(0.0);
        float w = 4.0 + uBloom * 12.0;
        for (int i = -2; i <= 2; i++) {
            for (int j = -2; j <= 2; j++) {
                vec3 s = texture2DRect(uScene,
                    clamp(uv + vec2(i, j) * w, vec2(0.0), uRes - 1.0)).rgb;
                float lum = max(max(s.r, s.g), s.b);
                bl += s * smoothstep(0.45, 1.0, lum);
            }
        }
        bl /= 25.0;
        col += bl * uBloom * 1.6;
    }

    // 7. Hue rotation
    if (uRgbShift > 0.001) {
        col = hueRotate(col, uRgbShift * TAU);
    }

    // 8. Saturation
    {
        float lum = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(vec3(lum), col, uSat);
    }

    // 9. Feedback (zoom + rotate previous frame)
    if (uFeedback > 0.001) {
        vec2 fc = uv - uRes * 0.5;
        fc /= uFbZoom;
        fc = rot2(fc, uFbRot);
        fc += uRes * 0.5;
        fc = clamp(fc, vec2(0.0), uRes - 1.0);
        vec3 prev = texture2DRect(uPrev, fc).rgb * 0.96;
        col = max(col, prev * uFeedback * 1.5);
    }

    // 10. Scanlines
    if (uScan > 0.001) {
        float sl = sin(px.y * 3.14159) * 0.5 + 0.5;
        col *= mix(1.0, 0.45 + sl * 0.55, uScan);
    }

    // 11. Film grain
    if (uGrain > 0.001) {
        float g = (rand(px + uTime * vec2(13.0, 7.0)) - 0.5) * uGrain * 0.6;
        col += vec3(g);
    }

    // 12. Vignette
    if (uVignette > 0.001) {
        float v = smoothstep(0.95, 0.35, length(c) * 1.4);
        col *= mix(1.0, v, uVignette);
    }

    // Final tone-map / clamp — without this, bloom + grain + feedback
    // saturate to pure white very quickly on bright visualizers.
    col = col / (col + vec3(0.6));    // Reinhard-ish soft knee
    col = clamp(col, 0.0, 1.0);
    gl_FragColor = vec4(col, 1.0);
}
