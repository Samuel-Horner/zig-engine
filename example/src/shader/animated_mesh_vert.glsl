#version 460 core
in vec3 a_vert;
in vec2 a_tex;
in vec3 a_norm;
in uint a_bone;

out vec3 frag_pos;
out vec2 tex;
out vec3 norm;

layout(std430, binding = 0) readonly buffer Bones {
    mat4 bone_offsets[];
};

layout (std140, binding = 0) uniform CameraBlock {
    uniform mat4 proj;
    uniform mat4 view;
};

layout (std140, binding = 1) uniform ModelBlock {
    uniform mat4 model;
};

layout (std140, binding = 2) uniform AnimationBlock {
    uniform uint current;
    uniform uint next;
    uniform float lerp_t;
};

void main() {
    const vec4 current_vert = bone_offsets[current + a_bone] * vec4(a_vert, 1.);
    const vec4 next_vert = bone_offsets[next + a_bone] * vec4(a_vert, 1.); 
    const vec4 offset_vert = mix(current_vert, next_vert, smoothstep(0., 1., lerp_t));
    gl_Position = proj * view * model * offset_vert;
    frag_pos = offset_vert.xyz;
    tex = a_tex;
    norm = a_norm;
}
