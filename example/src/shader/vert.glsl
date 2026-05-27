#version 460 core
in vec3 aVert;
in vec2 aTex;
in vec3 aNorm;

void main() {
    gl_Position = vec4(aVert.xy, 0., 1.);
}
