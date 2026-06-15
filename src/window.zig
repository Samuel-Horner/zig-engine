const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");

const input = @import("input.zig");
const engine = @import("engine.zig");

pub const CursorPosCallback = union(enum) {
    basic: *const fn (f64, f64) void,
    owned: struct { owner: *anyopaque, fun: *const fn (*anyopaque, f64, f64) void },
};

pub const FrameBufferSizeCallback = union(enum) {
    basic: *const fn (c_int, c_int) void,
    owned: struct { owner: *anyopaque, fun: *const fn (*anyopaque, c_int, c_int) void },
};

id: *glfw.Window,
width: c_int,
height: c_int,
name: [*:0]const u8,

cursor_pos_callbacks: std.ArrayList(CursorPosCallback),
frame_buffer_size_callbacks: std.ArrayList(FrameBufferSizeCallback),

const Self = @This();

pub fn init(width: c_int, height: c_int, name: [*:0]const u8) !Self {
    const id = try glfw.createWindow(width, height, name, null, null);
    _ = glfw.setCursorPosCallback(id, engine.glfwCursorPosCallback);
    _ = glfw.setFramebufferSizeCallback(id, engine.glfwFrameBufferSizeCallback);

    return .{
        .id = id,
        .width = width,
        .height = height,
        .name = name,

        .cursor_pos_callbacks = .empty,
        .frame_buffer_size_callbacks = .empty,
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.cursor_pos_callbacks.deinit(allocator);
    self.frame_buffer_size_callbacks.deinit(allocator);
    glfw.destroyWindow(self.id);
}

pub fn makeCurrent(self: *const Self) void {
    glfw.makeContextCurrent(self.id);
}

pub fn shouldClose(self: *const Self) bool {
    return glfw.windowShouldClose(self.id);
}

pub fn keyPressed(self: *const Self, key: c_int) bool {
    return glfw.getKey(self.id, key) == input.KeyState.Press;
}

pub fn close(self: *const Self) void {
    glfw.setWindowShouldClose(self.id, true);
}

pub fn toggleFullScreen(self: *const Self) void {
    if (glfw.getWindowMonitor(self.id) == null) {
        const monitor = glfw.getPrimaryMonitor();
        const mode = glfw.getVideoMode(monitor);

        glfw.setWindowMonitor(self.id, monitor, 0, 0, mode.?.width, mode.?.height, mode.?.refreshRate);
    } else {
        glfw.setWindowMonitor(self.id, null, 0, 0, 800, 460, 0);
    }
}

pub fn setInputModeCursor(self: *const Self, value: c_int) void {
    glfw.setInputMode(self.id, glfw.Cursor, value);
}

pub fn registerCursorPosCallback(self: *Self, allocator: std.mem.Allocator, callback: *const fn (f64, f64) void) !void {
    try self.cursor_pos_callbacks.append(allocator, .{ .basic = callback });
}

pub fn registerCursorPosCallbackOwned(self: *Self, allocator: std.mem.Allocator, owner: *anyopaque, callback: *const fn (*anyopaque, f64, f64) void) !void {
    try self.cursor_pos_callbacks.append(allocator, .{ .owned = .{ .owner = owner, .fun = callback } });
}

pub fn registerFrameBufferSizeCallback(self: *Self, allocator: std.mem.Allocator, callback: *const fn (c_int, c_int) void) !void {
    try self.frame_buffer_size_callbacks.append(allocator, .{ .basic = callback });
}

pub fn registerFrameBufferSizeCallbackOwned(self: *Self, allocator: std.mem.Allocator, owner: *anyopaque, callback: *const fn (*anyopaque, c_int, c_int) void) !void {
    try self.frame_buffer_size_callbacks.append(allocator, .{ .owned = .{ .owner = owner, .fun = callback } });
}
