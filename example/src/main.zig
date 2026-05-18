const std = @import("std");
const Io = std.Io;

const engine = @import("zig_engine");

pub fn main(init: std.process.Init) !void {
    try engine.init(init.arena.allocator(), 800, 460, "Hello World");
    defer engine.deinit();

    while (!engine.window.shouldClose()) {
        if (engine.window.keyPressed(engine.glfw.KeyEscape)) {
            engine.window.close();
        }

        engine.clearViewport();
        engine.finishRender();
    }

}
