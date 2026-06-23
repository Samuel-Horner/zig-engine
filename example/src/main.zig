const std = @import("std");

const engine = @import("zig_engine");
const m = engine.math;

// Free camera
// Simple static mesh object
const SimpleMesh = struct {
    mesh: engine.Object.Mesh,

    allocator: std.mem.Allocator,

    pub fn object(self: *SimpleMesh) engine.Object {
        return engine.Object.init(self, &self.mesh);
    }

    pub fn tick(self: *SimpleMesh) void {
        _ = self;
    }

    pub fn init(allocator: std.mem.Allocator, comptime path: []const u8, pos: m.Vec3, scale: m.Vec3, rot: m.Quat) !SimpleMesh {
        const model = m.Mat4.translationVec3(pos).mul(m.Mat4.fromQuaternion(rot)).mul(m.Mat4.scalingVec3(scale));

        std.log.debug("Parsing OBJ: {s}.", .{path});
        var self: SimpleMesh = .{
            .mesh = try engine.Object.Mesh.fromOBJ(allocator, @embedFile(path), 1, model),
            .allocator = allocator,
        };

        self.mesh.dispatch(.{});
        return self;
    }

    pub fn deinit(self: *SimpleMesh) void {
        self.mesh.undispatch();
        self.mesh.deinit(self.allocator);
    }
};

pub fn main(init: std.process.Init) !void {
    try engine.init(init.arena.allocator(), 1920, 1080, "Hello World", .{});
    defer engine.deinit() catch std.log.err("Failed to deinit engine.", .{});
    engine.window.setInputModeCursor(engine.input.CursorMode.Disabled);
    engine.window.fullScreen();

    const atlas_font = try engine.ui.AtlasFont.init(engine.allocator, "src/font/JetBrainsMonoNerdFont-Regular.ttf", 64);

    var prog = try engine.Program.init(@embedFile("shader/vert.glsl"), @embedFile("shader/frag.glsl"));
    defer prog.deinit();

    var monkey = try SimpleMesh.init(init.gpa, "model/monkey.obj", m.vec3(2, 0, -5), m.vec3(1, 1, 1), m.Quat.identity());
    defer monkey.deinit();

    var teapot = try SimpleMesh.init(init.gpa, "model/utah_teapot.obj", m.vec3(-2, -1.5, -5), m.vec3(1, 1, 1), m.Quat.identity());
    defer teapot.deinit();

    // Cam is a pointer type here since we heap allocate it.
    // This is a necessary downside of registering an owned callback in a initialisation function.
    // You can stack allocate structs with owned callbacks, but you must register the callback outside the initialiser to avoid dead pointers.
    var cam = try engine.Object.FPCamera.init(init.gpa, 0.05, 0);
    defer cam.deinit(init.gpa);

    var f11_down = false;

    var next_debug_update = std.Io.Clock.now(.awake, init.io).toSeconds();
    var frames: usize = 0;
    var fps: usize = 0;

    var previous = std.Io.Clock.now(.awake, init.io).toNanoseconds();
    while (!engine.window.shouldClose()) {
        const time_stamp = std.Io.Clock.now(.awake, init.io).toNanoseconds();
        const dt: f32 = @floatCast(@as(f128, @floatFromInt(time_stamp - previous)) / 1e9);
        previous = time_stamp;

        frames += 1;

        const now = std.Io.Clock.now(.awake, init.io).toSeconds();
        if (now >= next_debug_update) {
            fps = frames;
            frames = 0;
            next_debug_update = now + 1;
        }

        // Input
        if (engine.window.keyPressed(engine.input.Key.Escape)) {
            engine.window.close();
        }

        if (engine.window.keyPressed(engine.input.Key.F11)) {
            if (!f11_down) {
                engine.window.toggleFullScreen();
                f11_down = true;
            }
        } else {
            f11_down = false;
        }

        if (engine.window.keyPressed(engine.input.Key.W)) cam.pos = cam.pos.add(cam.dir.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.S)) cam.pos = cam.pos.sub(cam.dir.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.D)) cam.pos = cam.pos.add(cam.right.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.A)) cam.pos = cam.pos.sub(cam.right.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.Space)) cam.pos = cam.pos.add(engine.Object.FPCamera.global_up.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.LeftControl)) cam.pos = cam.pos.sub(engine.Object.FPCamera.global_up.muls(dt));

        var debug_str_buf: [256]u8 = undefined;
        const debug_str = std.fmt.bufPrint(&debug_str_buf, "fps:{}\nres:{}x{}\nx:{d:.3} y:{d:.3} z:{d:.3}\np:{d:.3} y:{d:.3}", .{ fps, engine.window.width, engine.window.height, cam.pos.data[0], cam.pos.data[1], cam.pos.data[2], cam.pitch, cam.yaw }) catch "Buffer Print Error";

        cam.renderTick();

        engine.clearViewport();

        prog.use();
        cam.ubo.bind();
        prog.setVec3("cam_pos", cam.pos);
        try teapot.object().draw();
        try monkey.object().draw();

        try engine.ui.atlas_text_renderer.drawStringRelative(&atlas_font, debug_str, m.vec2(0, 1), m.vec3(1, 1, 1), 1);

        engine.finishRender();
    }
}
