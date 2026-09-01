#version 460 core
out vec4 FragColor;

in vec3 norm;
in vec2 tex;
in vec3 frag_pos;

layout (std140, binding = 2) uniform AnimationBlock {
    uniform uint current;
    uniform uint next;
    uniform float lerp_t;
};

void main() {
    FragColor = vec4(mix(vec3(0.), vec3(1.), lerp_t), 1.);
}
