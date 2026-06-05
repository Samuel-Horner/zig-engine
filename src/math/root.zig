/// Adapted from https://codeberg.org/grius/zm
pub const Vec = @import("vec.zig").Vec;
pub const Mat = @import("mat.zig").Mat;
pub const Quaternion = @import("quaternion.zig").Quaternion;

pub const Vec2 = Vec(f32, 2);
pub fn vec2(x: f32, y: f32) Vec2 {
    return .{ .data = .{ x, y } };
}

pub const Vec3 = Vec(f32, 3);
pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return .{ .data = .{ x, y, z } };
}

pub const Vec4 = Vec(f32, 4);
pub fn vec4(x: f32, y: f32, z: f32, w: f32) Vec4 {
    return .{ .data = .{ x, y, z, w } };
}

pub const Vec2i = Vec(i32, 2);
pub fn vec2i(x: i32, y: i32) Vec2i {
    return .{ .data = .{ x, y } };
}

pub const Vec3i = Vec(i32, 3);
pub fn vec3i(x: i32, y: i32, z: i32) Vec3i {
    return .{ .data = .{ x, y, z } };
}

pub const Vec4i = Vec(i32, 4);
pub fn vec4i(x: i32, y: i32, z: i32, w: i32) Vec4i {
    return .{ .data = .{ x, y, z, w } };
}

pub const Mat2 = Mat(f32, 2, 2);
pub const Mat3 = Mat(f32, 3, 3);
pub const Mat4 = Mat(f32, 4, 4);

pub const Quat = Quaternion(f32);
pub fn quat(w: f32, x: f32, y: f32, z: f32) Quat {
    return .{ .w = w, .x = x, .y = y, .z = z };
}

test "Math" {
    _ = @import("vec.zig");
    _ = @import("mat.zig");
    _ = @import("quaternion.zig");
}
