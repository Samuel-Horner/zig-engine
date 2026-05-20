const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");

const Input = @import("input.zig");

id: *glfw.Window,
width: c_int,
height: c_int,
name: [*:0]const u8,

const Self = @This();

pub fn init(width: c_int, height: c_int, name: [*:0]const u8) !Self {
    return .{
        .id = try glfw.createWindow(width, height, name, null, null),
        .width = width,
        .height = height,
        .name = name,
    };
}

pub fn makeCurrent(self: *const Self) void {
    glfw.makeContextCurrent(self.id);
}

pub fn deinit(self: *Self) void {
    glfw.destroyWindow(self.id);
}

pub fn shouldClose(self: *const Self) bool {
    return glfw.windowShouldClose(self.id);
}

pub fn keyPressed(self: *const Self, key: c_int) bool {
    return glfw.getKey(self.id, key) == Input.KeyState.Press;
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
