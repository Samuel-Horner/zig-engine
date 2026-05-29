const std = @import("std");
const Io = std.Io;

const engine = @import("zig_engine");

const Camera = struct {
    // Implements Object
    pub fn object(self: *Camera) engine.Object {
        return engine.Object.init(self, null);
    }

    pub fn tick(self: *Camera) !void {
        _ = self;
        std.log.debug("Camera tick", .{});
    }
};

const Tri = struct {
    mesh: engine.Object.Mesh,
    allocator: std.mem.Allocator,

    pub fn object(self: *Tri) engine.Object {
        return engine.Object.init(self, &self.mesh);
    }

    pub fn tick(self: *Tri) void {
        _ = self;
    }

    pub fn init(allocator: std.mem.Allocator) !Tri {
        var self: Tri = .{
            .mesh = try engine.Object.Mesh.init(allocator, &.{
                .{ .x = -1, .y = -1, .z = 0, .nx = 0, .ny = 0, .nz = 0},
                .{ .x = 1, .y = -1, .z = 0, .nx = 1, .ny = 0, .nz = 0 },
                .{ .x = 0, .y = 1, .z = 0, .nx = 0, .ny = 1, .nz = 0 },
            }, &.{ 2, 1, 0 }),
            .allocator = allocator,
        };

        self.mesh.dispatch(.{});
        return self;
    }

    pub fn deinit(self: *Tri) void {
        self.mesh.undispatch();
        self.mesh.deinit(self.allocator);
    }
};

pub fn main(init: std.process.Init) !void {
    try engine.init(init.arena.allocator(), 800, 460, "Hello World");
    defer engine.deinit();

    var prog = try engine.Program.init(@embedFile("shader/vert.glsl"), @embedFile("shader/frag.glsl"));
    defer prog.deinit();

    var tri = try Tri.init(init.arena.allocator());
    defer tri.deinit();

    while (!engine.window.shouldClose()) {
        if (engine.window.keyPressed(engine.Input.Key.Escape)) {
            engine.window.close();
        }

        engine.clearViewport();

        prog.use();
        try tri.object().draw();

        engine.finishRender();
    }
}
