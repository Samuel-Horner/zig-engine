//! Requires specialised shader consumer.
//! Example:
//! ``` glsl
//!#version 460 core
//!in vec3 a_vert;
//!in vec2 a_tex;
//!in vec3 a_norm;
//!in uint a_bone;
//!
//!out vec3 frag_pos;
//!out vec2 tex;
//!out vec3 norm;
//!
//!layout(std430, binding = 0) readonly buffer Bones {
//!    mat4 bone_offsets[];
//!};
//!
//!layout (std140, binding = 0) uniform CameraBlock {
//!    uniform mat4 proj;
//!    uniform mat4 view;
//!};
//!
//!layout (std140, binding = 1) uniform ModelBlock {
//!    uniform mat4 model;
//!};
//!
//!layout (std140, binding = 2) uniform AnimationBlock {
//!    uniform uint current;
//!    uniform uint next;
//!    uniform float lerp_t;
//!};
//!
//!void main() {
//!    const vec4 current_vert = bone_offsets[current + a_bone] * vec4(a_vert, 1.);
//!    const vec4 next_vert = bone_offsets[next + a_bone] * vec4(a_vert, 1.);
//!    const vec4 offset_vert = mix(current_vert, next_vert, lerp_t);
//!    gl_Position = proj * view * model * offset_vert;
//!    frag_pos = offset_vert.xyz;
//!    tex = a_tex;
//!    norm = a_norm;
//!}
//! ```
const std = @import("std");
const gl = @import("gl");
const m = @import("../engine.zig").math;
const UBO = @import("../engine.zig").UBO;

const Self = @This();

offsets: []const m.Mat4,
time_steps: []const f32,

ssbo: c_uint,
ubo: UBO(&.{ u32, u32, f32 }),

pub fn bind(self: *const Self, ssbo_bind_point: c_uint, ubo_bind_point: c_uint) void {
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, self.ssbo);
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, ssbo_bind_point, self.ssbo);

    self.ubo.bind(ubo_bind_point);
}

pub fn writeUBO(self: *const Self, t: f32) void {
    // Gets current (lower bound) time step index
    const limit = self.time_steps[self.time_steps.len - 1];
    const half_limit = limit / 2;
    const wt = std.math.wrap(t - half_limit, half_limit) + half_limit;

    var current: usize = @divFloor(self.time_steps.len, 2);
    while (!(self.time_steps[current] <= wt and self.time_steps[current + 1] > wt)) {
        if (self.time_steps[current] < wt) {
            current = current * 2;
        } else {
            current = @divFloor(current, 2);
        }
    }

    const offsets_per_kf: u32 = @intCast(@divFloor(self.offsets.len, self.time_steps.len - 1));

    const current_index: u32 = @intCast(current * offsets_per_kf);
    const next_index: u32 = @intCast(@mod(current + 1, self.time_steps.len - 1) * offsets_per_kf);
    const lerp_t = (wt - self.time_steps[current]) / (self.time_steps[current + 1] - self.time_steps[current]);

    self.ubo.writePrimitive(0, current_index);
    self.ubo.writePrimitive(1, next_index);
    self.ubo.writePrimitive(2, lerp_t);
}

pub fn undispatch(self: *Self) void {
    gl.DeleteBuffers(1, &.{self.ssbo});
    self.ubo.deinit();
}

pub fn dispatch(self: *Self, allocator: std.mem.Allocator) !void {
    const transposed_offsets: []m.Mat4 = try allocator.alloc(m.Mat4, self.offsets.len);
    defer allocator.free(transposed_offsets);

    for (0.., self.offsets) |i, offset| {
        transposed_offsets[i] = offset.transpose();
    }

    gl.GenBuffers(1, (&self.ssbo)[0..1]);
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, self.ssbo);

    gl.BufferData(gl.SHADER_STORAGE_BUFFER, @intCast(self.offsets.len * @sizeOf(f32) * 16), transposed_offsets.ptr, gl.STATIC_DRAW);

    self.ubo = try .init(.{});
}

/// Time steps must be sorted.
/// Add one more time step to mark the end point of the frames, i.e.
/// With three frames, time steps might be
/// `[0, 1, 2, 3]`
/// So at 3 we loop back to 0.
pub fn init(offsets: []const m.Mat4, time_steps: []const f32) Self {
    return .{
        .offsets = offsets,
        .time_steps = time_steps,

        .ssbo = undefined,
        .ubo = undefined,
    };
}
