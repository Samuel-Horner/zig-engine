#version 460 core
out vec2 tex_coords;
out vec2 tex_size;

uniform mat4 proj;

// struct item {
//     float x;
//     float y;
//     float width;
//     float height;
//     float tex_orig_x;
//     float tex_orig_y;
//     float tex_width;
//     float tex_height;
// }

#define VERTS_PER_CHAR 6
#define FLOATS_PER_CHAR 8

layout(std430, binding = 0) readonly buffer CharSSBO {
    float chars[];
};

const vec2 vert_offsets[6] = vec2[6](
    vec2(0, 1),
    vec2(0, 0),
    vec2(1, 0),
    vec2(0, 1),
    vec2(1, 0),
    vec2(1, 1)
);

const vec2 tex_offsets[6] = vec2[6](
    vec2(0, 0),
    vec2(0, 1),
    vec2(1, 1),
    vec2(0, 0),
    vec2(1, 1),
    vec2(1, 0)
);

void main() {
    const uint char_index = (gl_VertexID / VERTS_PER_CHAR) * FLOATS_PER_CHAR;
    vec2 pos = vec2(chars[char_index + 0], chars[char_index + 1]);
    const vec2 size = vec2(chars[char_index + 2], chars[char_index + 3]);
    vec2 tex_coord = vec2(chars[char_index + 4], chars[char_index + 5]);
    const vec2 tex_size = vec2(chars[char_index + 6], chars[char_index + 7]);

    pos += vert_offsets[gl_VertexID % VERTS_PER_CHAR] * size;
    tex_coord += tex_offsets[gl_VertexID % VERTS_PER_CHAR] * tex_size;

    gl_Position = proj * vec4(pos, 0., 1.);
    tex_coords = tex_coord;
}
