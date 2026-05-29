#version 460 core
out vec4 FragColor;

in vec3 norm;
in vec2 tex;

void main() {
    FragColor = vec4(norm, 1.);
} 
