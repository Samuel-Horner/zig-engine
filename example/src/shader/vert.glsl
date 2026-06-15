#version 460 core
in vec3 aVert;
in vec2 aTex;
in vec3 aNorm;

out vec3 norm;
out vec2 tex;
out vec3 frag_pos;

layout (std140, binding = 0) uniform CameraBlock {
    uniform mat4 proj;
    uniform mat4 view;
};

layout (std140, binding = 1) uniform ModelBlock {
    uniform mat4 model;
};

void main() {
    gl_Position = proj * view * model * vec4(aVert, 1.);
    norm = aNorm;
    tex = aTex;
    frag_pos = (model * vec4(aVert, 1.)).xyz;
}
