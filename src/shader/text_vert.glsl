#version 460 core
in vec4 aVert;

out vec2 tex_coords;

uniform mat4 proj;

void main() {
    gl_Position = proj * vec4(aVert.xy, 0., 1.);
    tex_coords = aVert.zw;
}
