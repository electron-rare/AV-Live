#version 150

uniform mat4 modelViewProjectionMatrix;
in vec4 position;

out vec2 vSphereUV;   // x = longitude [0,1], y = latitude [0,1]

const float PI = 3.14159265359;

void main() {
    vec3 dir = normalize(position.xyz);
    float lon = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
    float lat = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;
    gl_Position = modelViewProjectionMatrix * position;
    vSphereUV = vec2(lon, lat);
}
