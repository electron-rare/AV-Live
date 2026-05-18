#version 150

uniform mat4 modelViewProjectionMatrix;
uniform mat4 modelViewMatrix;
uniform sampler2D waveformTex;
uniform sampler2D spectroTex;
uniform float displaceAmount;
uniform float spectroAmount;
uniform float scrollOffset;
uniform float baseRadius;
uniform int   renderMode;        // 0 = skin, 1 = points

in vec4 position;

out vec2  vSphereUV;
out vec3  vViewPos;
out float vWave;

const float PI = 3.14159265359;

void main() {
    vec3 dir = normalize(position.xyz);
    float lon = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
    float lat = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;

    // waveform ripple (per hemisphere) + scrolling spectrogram relief
    float row  = (dir.y >= 0.0) ? 0.25 : 0.75;          // CH1 north, CH2 south
    float wave = texture(waveformTex, vec2(lon, row)).r;             // [-1,1]
    float spec = texture(spectroTex,
                         vec2(fract(lon - scrollOffset), lat)).r;    // [0,1]

    float r = baseRadius * (1.0 + displaceAmount * wave
                                + spectroAmount * spec);
    if (renderMode == 1) {
        r *= 1.06;                  // float the point cloud outside the skin
        gl_PointSize = 6.0;
    } else if (renderMode == 2) {
        r *= 1.01;                  // wireframe sits just above the lit skin
    }

    vec4 viewPos = modelViewMatrix * vec4(dir * r, 1.0);
    gl_Position  = modelViewProjectionMatrix * vec4(dir * r, 1.0);
    vViewPos  = viewPos.xyz;
    vSphereUV = vec2(lon, lat);
    vWave     = wave;
}
