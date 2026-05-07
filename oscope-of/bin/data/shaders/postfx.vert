#version 150

// macOS oF 0.12 tourne en GL 3.2 core profile : pas de gl_Vertex /
// gl_MultiTexCoord0 (built-ins legacy). On utilise les attributs nommés
// que oF injecte automatiquement (cf. glow.vert / bloom.vert).
uniform mat4 modelViewProjectionMatrix;
in vec4 position;
in vec2 texcoord;
out vec2 vTex;

void main() {
    vTex = texcoord;
    gl_Position = modelViewProjectionMatrix * position;
}
