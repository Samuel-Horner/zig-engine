#version 460 core
in vec3 aVert;
in vec2 aTex;
in vec3 aNorm;

out vec3 norm;
out vec2 tex;

void main() {
    gl_Position = vec4(aVert.xy, 0., 1.);
    norm = aNorm;
    tex = aTex;
}
