const std = @import("std");
const engine = @import("../engine.zig");
const m = engine.math;

pub const global_up = m.vec3(0, 1, 0);
pub const global_right = m.vec3(1, 0, 0);
pub const global_in = m.vec3(0, 0, -1);

pos: m.Vec3 = m.vec3(0, 0, 1),
dir: m.Vec3 = global_in,
right: m.Vec3 = global_right,

yaw: f32,
pitch: f32,

// View, Proj
ubo: engine.UBO(&.{ m.Mat4, m.Mat4 }),

prevx: f64,
prevy: f64,

near: f32,
far: f32,

/// Vertical FOV in degrees
fov: f32,

sensitivity: f32,

const Self = @This();

/// yaw and pitch in degrees
pub fn rotate(self: *Self, yaw: f32, pitch: f32) void {
    self.yaw = std.math.wrap(self.yaw + yaw, 180);
    self.pitch = std.math.clamp(self.pitch + pitch, -89, 89);

    const yaw_rot = m.Quat.fromAxisAngle(global_up, std.math.degreesToRadians(self.yaw));
    const pitch_rot = m.Quat.fromAxisAngle(global_right, std.math.degreesToRadians(self.pitch));
    const rot = yaw_rot.mul(pitch_rot);

    self.dir = m.Quat.rotVec3(global_in, rot.norm()).norm();

    self.right = self.dir.cross(global_up).norm();
}

/// Recalculates and writes projection and view matrices every call.
/// Not ideal, since they may not change between renders, but cost should be negligable.
/// This can be circumvented by not calling this function and calling Mat4.perspective and Mat4.lookAt directly,
pub fn renderTick(self: *const Self) void {
    const proj = m.Mat4.perspective(
        std.math.degreesToRadians(self.fov),
        @as(f32, @floatFromInt(engine.window.width)) / @as(f32, @floatFromInt(engine.window.height)),
        self.near,
        self.far,
    ).transpose();
    const view = m.Mat4.lookAt(self.pos, self.pos.add(self.dir), global_up).transpose();

    self.ubo.write(@as([]const f32, @ptrCast(&proj.data)), 0);
    self.ubo.write(@as([]const f32, @ptrCast(&view.data)), 1);
}

pub fn cursorCallback(generic_self: *anyopaque, x: f64, y: f64) void {
    const self: *Self = @ptrCast(@alignCast(generic_self));

    // Inverting both axis to obtain normal controls
    self.rotate(@as(f32, @floatCast(self.prevx - x)) * self.sensitivity, @as(f32, @floatCast(self.prevy - y)) * self.sensitivity);

    self.prevx = x;
    self.prevy = y;
}

pub fn bind(self: *const Self) void {
    self.ubo.bind();
}

pub fn init(allocator: std.mem.Allocator, sensitivity: f32, ubo_binding: u32) !*Self {
    var cam = try allocator.create(Self);
    cam.sensitivity = sensitivity;
    cam.ubo = try .init(ubo_binding, .{});

    cam.prevx = 0;
    cam.prevy = 0;
    
    cam.fov = 90;
    cam.near = 0.1;
    cam.far = 1000;
        
    cam.pos = m.vec3(0, 0, 1);
    cam.dir = global_in;
    cam.right = global_right;

    try engine.window.registerCursorPosCallbackOwned(engine.allocator, cam, Self.cursorCallback);
    return cam;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.ubo.deinit();
    allocator.destroy(self);
}
