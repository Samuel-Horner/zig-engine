const std = @import("std");

const engine = @import("zig_engine");
const m = engine.math;

const stbi = @import("zstbi");

// Static mesh object
const Mesh = struct {
    mesh: engine.Object.StaticMesh,
    ubo: engine.UBO(&.{m.Mat4}),

    allocator: std.mem.Allocator,

    pub fn draw(self: *const Mesh, ubo_bind_point: c_uint) void {
        self.ubo.bind(ubo_bind_point);
        self.mesh.draw();
    }

    pub fn init(allocator: std.mem.Allocator, comptime path: []const u8, pos: m.Vec3, scale: m.Vec3, rot: m.Quat) !Mesh {
        const model = m.Mat4.translationVec3(pos).mul(m.Mat4.fromQuaternion(rot)).mul(m.Mat4.scalingVec3(scale)).transpose();

        std.log.debug("Parsing OBJ: {s}.", .{path});
        var self: Mesh = .{
            .mesh = try engine.Object.fromOBJ(allocator, @embedFile(path)),
            .allocator = allocator,
            .ubo = try .init(.{}),
        };

        self.mesh.dispatch(.{});
        self.ubo.write(@as([]const f32, @ptrCast(&model.data)), 0);
        return self;
    }

    pub fn deinit(self: *Mesh) void {
        self.mesh.undispatch();
        self.allocator.free(self.mesh.data);
        self.allocator.free(self.mesh.indices);
        self.ubo.deinit();
    }
};

// Animated mesh object
const AnimatedMesh = struct {
    mesh: engine.Object.AnimatedMesh,
    animation: engine.Object.Animation,
    ubo: engine.UBO(&.{m.Mat4}),

    allocator: std.mem.Allocator,

    pub fn draw(self: *const AnimatedMesh, t: f32, ubo_bind_point: c_uint, animation_ubo_bind_point: c_uint, animation_ssbo_bind_point: c_uint) void {
        self.ubo.bind(ubo_bind_point);
        self.animation.bind(animation_ssbo_bind_point, animation_ubo_bind_point);
        self.animation.writeUBO(t);
        self.mesh.draw();
    }

    pub fn init(allocator: std.mem.Allocator, data: []const engine.Object.AnimatedMesh.Vertex, indices: []const u32, animation: engine.Object.Animation, model: m.Mat4) !AnimatedMesh {
        var self: AnimatedMesh = .{
            .mesh = .init(data, indices),
            .animation = animation,
            .allocator = allocator,
            .ubo = try .init(.{}),
        };

        self.mesh.dispatch(.{});
        try self.animation.dispatch(allocator);
        self.ubo.write(@as([]const f32, @ptrCast(&model.transpose().data)), 0);
        return self;
    }

    pub fn deinit(self: *AnimatedMesh) void {
        self.animation.undispatch();
        self.mesh.undispatch();
        self.ubo.deinit();
    }
};

pub fn main(init: std.process.Init) !void {
    stbi.init(init.io, init.gpa);
    stbi.setFlipVerticallyOnLoad(true);
    defer stbi.deinit();

    try engine.init(init.gpa, 600, 400, "Hello World", .{});
    defer engine.deinit() catch std.log.err("Failed to deinit engine.", .{});
    engine.window.setInputModeCursor(engine.input.CursorMode.Disabled);
    // engine.window.fullScreen();

    const font = try engine.ui.Font.init(engine.allocator, "src/font/JetBrainsMonoNerdFont-Regular.ttf", 64);

    var prog = try engine.Program.init(@embedFile("shader/vert.glsl"), @embedFile("shader/frag.glsl"));
    defer prog.deinit();

    var animated_prog = try engine.Program.init(@embedFile("shader/animated_mesh_vert.glsl"), @embedFile("shader/animated_mesh_frag.glsl"));
    defer animated_prog.deinit();

    var animated_mesh = try AnimatedMesh.init(init.gpa, &.{
        .{ .x = 0, .y = -1, .z = 0, .bone = 0 },
        .{ .x = 0, .y = 1, .z = 0, .bone = 0 },
        .{ .x = 1, .y = 1, .z = 0, .bone = 0 },
    }, &.{ 2, 1, 0 }, .init(
        &.{ m.Mat4.identity(), m.Mat4.translation(0, 1, 0), m.Mat4.fromQuaternion(m.Quat.fromEulerAngles(m.vec3(0, std.math.pi * 0.5, 0), .xyz)) },
        &.{ 0, 1, 2, 3 },
    ), m.Mat4.translation(1, 0, -2));
    defer animated_mesh.deinit();

    var tex_prog = try engine.Program.init(@embedFile("shader/tex_vert.glsl"), @embedFile("shader/tex_frag.glsl"));
    defer tex_prog.deinit();

    var image = try stbi.Image.loadFromFile("src/texture/test.png", 0);
    var tex = try engine.Texture.init(image.data, @intCast(image.width), @intCast(image.height), .{ .format = engine.Texture.Format.get(.RGBA, null, null) });
    defer tex.deinit();
    image.deinit();

    var tex_plane = try Mesh.init(init.gpa, "model/cube.obj", m.vec3(0, 0, -1), m.vec3(1, 1, 1), m.Quat.identity());
    defer tex_plane.deinit();

    var monkey = try Mesh.init(init.gpa, "model/monkey.obj", m.vec3(2, 0, -5), m.vec3(1, 1, 1), m.Quat.identity());
    defer monkey.deinit();

    var teapot = try Mesh.init(init.gpa, "model/utah_teapot.obj", m.vec3(-2, -1.5, -5), m.vec3(1, 1, 1), m.Quat.identity());
    defer teapot.deinit();

    // Cam is a pointer type here since we heap allocate it.
    // This is a necessary downside of registering an owned callback in a initialisation function.
    // You can stack allocate structs with owned callbacks, but you must register the callback outside the initialiser to avoid dead pointers.
    var cam = try engine.Object.FPCamera.init(init.gpa, 0.05);
    defer cam.deinit(init.gpa);

    prog.use();
    const light_dir = m.vec3(-0.5, -0.5, -0.5).norm().invert();
    prog.setVec3("light_dir", light_dir);

    var f11_down = false;

    var next_debug_update = std.Io.Clock.now(.awake, init.io).toSeconds();
    var frames: usize = 0;
    var fps: usize = 0;

    var previous: f32 = 0;

    const start = std.Io.Clock.now(.awake, init.io).toMicroseconds();
    while (!engine.window.shouldClose()) {
        const time_stamp = std.Io.Clock.now(.awake, init.io).toMicroseconds();
        const t: f32 = @floatCast(@as(f128, @floatFromInt(time_stamp - start)) / 1e6);
        const dt: f32 = t - previous;
        previous = t;

        frames += 1;

        const now = std.Io.Clock.now(.awake, init.io).toSeconds();
        if (now > next_debug_update) {
            fps = frames;
            frames = 0;
            next_debug_update = now;
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

        if (engine.window.keyPressed(engine.input.Key.Q)) {
            engine.setRenderMode(true);
        } else {
            engine.setRenderMode(false);
        }

        if (engine.window.keyPressed(engine.input.Key.W)) cam.pos = cam.pos.add(cam.dir.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.S)) cam.pos = cam.pos.sub(cam.dir.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.D)) cam.pos = cam.pos.add(cam.right.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.A)) cam.pos = cam.pos.sub(cam.right.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.Space)) cam.pos = cam.pos.add(engine.Object.FPCamera.global_up.muls(dt));
        if (engine.window.keyPressed(engine.input.Key.LeftControl)) cam.pos = cam.pos.sub(engine.Object.FPCamera.global_up.muls(dt));

        var debug_str_buf: [256]u8 = undefined;
        const debug_str = std.fmt.bufPrint(&debug_str_buf, "t: {d:.3}\nfps:{}\nres:{}x{}\nx:{d:.3} y:{d:.3} z:{d:.3}\np:{d:.3} y:{d:.3}", .{ t, fps, engine.window.width, engine.window.height, cam.pos.data[0], cam.pos.data[1], cam.pos.data[2], cam.pitch, cam.yaw }) catch "Buffer Print Error";

        cam.renderTick();

        engine.clearViewport();

        prog.use();
        cam.ubo.bind(0);
        prog.setVec3("cam_pos", cam.pos);
        teapot.draw(1);
        monkey.draw(1);

        tex_prog.use();
        tex.bind(null);
        tex_plane.draw(1);

        animated_prog.use();
        cam.ubo.bind(0);
        animated_mesh.draw(t, 1, 2, 0);

        try engine.ui.text_renderer.drawStringRelative(&font, debug_str, m.vec2(0, 1), m.vec3(1, 1, 1), 1);

        engine.finishRender();
    }
}
