#version 460 core
out vec4 FragColor;

in vec2 tex;

uniform sampler2D cube_tex;

void main() {
    FragColor = texture(cube_tex, tex);
}
