#version 460 core
in vec2 tex_coords;
out vec4 color;

uniform sampler2D tex;
uniform vec3 text_color;

void main() {
    color = vec4(text_color, texture(tex, tex_coords).r);
}
