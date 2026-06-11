const std = @import("std");

const engine = @import("zig_engine");
const m = engine.Math;

// Free camera
const Camera = struct {
    const sensitivity: f32 = 0.05;
    const fov: f32 = 90;
    const up = m.vec3(0, 1, 0);
    const global_right = m.vec3(1, 0, 0);
    const in = m.vec3(0, 0, -1);

    pos: m.Vec3,
    dir: m.Vec3,
    right: m.Vec3,

    yaw: f32,
    pitch: f32,

    ubo: engine.UBO(&.{m.Mat4, m.Mat4}),

    // Implements Object
    pub fn object(self: *Camera) engine.Object {
        return engine.Object.init(self, null);
    }

    pub fn tick(self: *Camera) !void {
        _ = self;
    }

    pub fn rotate(self: *Camera, dx: f32, dy: f32) void {
        self.yaw = std.math.wrap(self.yaw + dx * sensitivity, 180);
        self.pitch = std.math.clamp(self.pitch + dy * sensitivity, -89, 89);
        
        const yaw_rot = m.Quat.fromAxisAngle(up, std.math.degreesToRadians(self.yaw));
        const pitch_rot = m.Quat.fromAxisAngle(global_right, std.math.degreesToRadians(self.pitch));
        const rot = yaw_rot.mul(pitch_rot);

        self.dir = m.Quat.rotVec3(in, rot.norm()).norm();

        self.right = self.dir.cross(up).norm();
    }

    pub fn renderTick(self: *Camera, delta_time: f32) void {
        if (engine.window.keyPressed(engine.Input.Key.W)) self.pos = self.pos.add(self.dir.muls(delta_time));
        if (engine.window.keyPressed(engine.Input.Key.S)) self.pos = self.pos.sub(self.dir.muls(delta_time));
        if (engine.window.keyPressed(engine.Input.Key.D)) self.pos = self.pos.add(self.right.muls(delta_time));
        if (engine.window.keyPressed(engine.Input.Key.A)) self.pos = self.pos.sub(self.right.muls(delta_time));
        if (engine.window.keyPressed(engine.Input.Key.Space)) self.pos = self.pos.add(up.muls(delta_time));
        if (engine.window.keyPressed(engine.Input.Key.LeftControl)) self.pos = self.pos.sub(up.muls(delta_time));

        const proj = m.Mat4.perspective(
            std.math.degreesToRadians(fov),
            @as(f32, @floatFromInt(engine.window.width)) / @as(f32, @floatFromInt(engine.window.height)),
            0.1,
            1000,
        ).transpose();
        const view = m.Mat4.lookAt(self.pos, self.pos.add(self.dir), m.vec3(0, 1, 0)).transpose();

        self.ubo.write(@as([]const f32, @ptrCast(&proj.data)), 0);
        self.ubo.write(@as([]const f32, @ptrCast(&view.data)), 1);
    }

    pub fn init() !Camera {
        return .{
            .pos = m.vec3(0, 0, 1),
            .dir = in,
            .right = m.vec3(1, 0, 0),

            .yaw = 0,
            .pitch = 0,

            .ubo = try .init(0, .{}),
        };
    }

    pub fn deinit(self: *Camera) void {
        self.ubo.deinit();
    }
};

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

    pub fn init(allocator: std.mem.Allocator, comptime path: []const u8, pos: m.Vec3) !SimpleMesh {
        std.log.debug("Parsing OBJ: {s}.", .{path});
        var self: SimpleMesh = .{
            .mesh = try engine.Object.Mesh.fromOBJ(allocator, @embedFile(path), 1, pos),
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

var cam: Camera = undefined;

var prevx: f64 = 0;
var prevy: f64 = 0;
fn cursorCallback(x: f64, y: f64) void {
    // Invert both deltas to obtain regular controlls.
    cam.rotate(@floatCast(prevx - x), @floatCast(prevy - y));    

    prevx = x;
    prevy = y;
}

pub fn main(init: std.process.Init) !void {
    try engine.init(init.arena.allocator(), 800, 460, "Hello World");
    defer engine.deinit();
    engine.window.setInputModeCursor(engine.Input.CursorMode.Disabled);

    var prog = try engine.Program.init(@embedFile("shader/vert.glsl"), @embedFile("shader/frag.glsl"));
    defer prog.deinit();

    var monkey = try SimpleMesh.init(init.gpa, "model/monkey.obj", m.vec3(2, 0, -5));
    defer monkey.deinit();

    var teapot = try SimpleMesh.init(init.gpa, "model/utah_teapot.obj", m.vec3(-2, -1, -5));
    defer teapot.deinit();

    cam = try Camera.init();
    defer cam.deinit();
    try engine.window.registerCursorPosCallback(engine.allocator, cursorCallback);

    var previous = std.Io.Clock.now(.awake, init.io).toNanoseconds();
    while (!engine.window.shouldClose()) {
        const time_stamp = std.Io.Clock.now(.awake, init.io).toNanoseconds();
        const dt: f32 = @floatCast(@as(f128, @floatFromInt(time_stamp - previous)) / 1e9);
        previous = time_stamp;

        if (engine.window.keyPressed(engine.Input.Key.Escape)) {
            engine.window.close();
        }

        engine.clearViewport();

        prog.use();
        cam.renderTick(dt);
        try teapot.object().draw();
        try monkey.object().draw();

        engine.finishRender();
    }
}
