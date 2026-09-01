#version 460 core
in vec2 tex_coords;
out vec4 color;

uniform sampler2D tex;
uniform vec3 text_color;

void main() {
    const float alpha = texture(tex, tex_coords).r;
    color = vec4(text_color, alpha);
}
