#version 150

uniform mat4 modelViewProjectionMatrix;
uniform sampler2D waveformTex;   // width = samples, height = 2 (row0 CH1, row1 CH2)
uniform float displaceAmount;
uniform float baseRadius;

in vec4 position;

out vec2 vSphereUV;   // x = longitude [0,1], y = latitude [0,1]

const float PI = 3.14159265359;

void main() {
    vec3 dir = normalize(position.xyz);
    float lon = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
    float lat = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;

    float row  = (dir.y >= 0.0) ? 0.25 : 0.75;          // CH1 north, CH2 south
    float wave = texture(waveformTex, vec2(lon, row)).r; // [-1,1]
    float r    = baseRadius * (1.0 + displaceAmount * wave);

    gl_Position = modelViewProjectionMatrix * vec4(dir * r, 1.0);
    vSphereUV = vec2(lon, lat);
}
