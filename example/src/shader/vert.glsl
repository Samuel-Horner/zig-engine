#version 460 core
in vec3 aVert;
in vec2 aTex;
in vec3 aNorm;

out vec3 norm;
out vec2 tex;


layout (std140, binding = 0) uniform CameraBlock {
    uniform mat4 proj;
    uniform mat4 view;
};

void main() {
    gl_Position = proj * view * vec4(aVert, 1.);
    norm = aNorm;
    tex = aTex;
}
