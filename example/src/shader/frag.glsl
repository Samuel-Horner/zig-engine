#version 460 core
out vec4 FragColor;

in vec3 norm;
in vec2 tex;
in vec3 frag_pos;

const vec3 object_color = vec3(1.);

const vec3 ambient_color = vec3(1., 1., 1.);
const float ambient_coefficient = 0.2;

// const vec3 light_dir = -normalize(vec3(-0.5, -0.5, -0.5));
const vec3 light_color = vec3(1.);

const float specular_strength = 0.5;
const float specular_exponent = 32;

uniform vec3 cam_pos;
uniform vec3 light_dir;

layout (std140, binding = 2) uniform test {
    uniform vec3 a;
    uniform vec3 b;
    uniform vec3 c;
};

void main() {
    vec3 light_intensity = ambient_coefficient * ambient_color + light_color * (max(dot(norm, light_dir), 0) + specular_strength * pow(max(dot(normalize(cam_pos - frag_pos), reflect(-light_dir, norm)), 0), specular_exponent));
    FragColor = vec4(light_intensity * object_color, 1.);
}
