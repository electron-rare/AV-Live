#version 120
// openFrameworks injects modelViewProjectionMatrix and the standard
// gl_Vertex / gl_MultiTexCoord0 inputs in compatibility mode.
uniform mat4 modelViewProjectionMatrix;
varying vec2 vTex;
void main() {
    vTex = gl_MultiTexCoord0.xy;
    gl_Position = modelViewProjectionMatrix * gl_Vertex;
}
