const std = @import("std");

const gl = @import("gl");
const UBO = @import("../engine.zig").UBO;
const m = @import("../engine.zig").math;

const null_index = std.math.maxInt(u32);

pub const BoneTree = struct {
    const Bone = struct { offset: m.Mat4, children: [2]u32 = .{ null_index, null_index } };

    data: std.ArrayList(Bone),

    pub fn init() BoneTree {
        return .{
            .data = .empty,
        };
    }

    pub fn deinit(self: *BoneTree, allocator: std.mem.Allocator) void {
        self.deinit(allocator);
    }
};

const Vertex = packed struct {
    pub const Weight = packed struct {
        index: u32 = null_index,
        weight: f32 = 0,
    };

    // We use 8*4 bytes to store the 4 weights, since each weight is 2*4
    const value_split: []const c_int = &.{ 3, 2, 3, 8 };

    x: f32,
    y: f32,
    z: f32,

    tx: f32 = 0,
    ty: f32 = 0,

    nx: f32 = 0,
    ny: f32 = 0,
    nz: f32 = 0,

    weights: [4]Weight = .{ .{}, .{}, .{}, .{} },
};

data: []Vertex,
indices: []u32,
bones: []Bone,

vao: c_uint,
vbo: c_uint,
ebo: c_uint,

ubo: UBO(&.{m.Mat4}),

const Self = @This();

pub fn draw(self: *Self) void {
    gl.BindVertexArray(self.vao);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);

    self.ubo.bind();

    gl.DrawElements(gl.TRIANGLES, @intCast(self.indices.len), gl.UNSIGNED_INT, 0);
}

pub fn dispatch(self: *Self, opts: struct { draw_mode: c_uint = gl.STATIC_DRAW }) void {
    gl.GenVertexArrays(1, (&self.vao)[0..1]);
    gl.GenBuffers(1, (&self.vbo)[0..1]);
    gl.GenBuffers(1, (&self.ebo)[0..1]);

    gl.BindVertexArray(self.vao);

    gl.BindBuffer(gl.ARRAY_BUFFER, self.vbo);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);

    gl.BufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(Vertex) * self.data.len), self.data.ptr, opts.draw_mode);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * self.indices.len), self.indices.ptr, opts.draw_mode);

    const stride: c_int = @sizeOf(Vertex);

    var offset: usize = 0;
    for (Vertex.value_split, 0..) |split, i| {
        gl.VertexAttribPointer(@intCast(i), split, gl.FLOAT, gl.FALSE, stride, offset);
        gl.EnableVertexAttribArray(@intCast(i));
        offset += @intCast(split * @sizeOf(f32));
    }
}

pub fn undispatch(self: *Self) void {
    gl.DeleteBuffers(3, &.{ self.vao, self.vbo, self.ebo });
}

pub fn setModelMatrix(self: *const Self, model: m.Mat4) void {
    self.ubo.write(@as([]const f32, @ptrCast(&model.transpose().data)), 0);
}

pub fn offsetBone(self: *const Self, bone: u32, offset: m.Mat4) void {
    self.bones[bone].offset = self.bones[bone].offset.mul(offset);
    for (self.bones[bone].children) |child| {
        if (child == null_index) continue;
        self.offsetBone(child, offset);
    }
}

pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
    allocator.free(self.data);
    allocator.free(self.indices);
    allocator.free(self.bones);
}

/// Non-transposed model matrix
pub fn init(allocator: std.mem.Allocator, data: []const Vertex, indices: []const u32, bones: []const Bone, ubo_binding: u32, model: m.Mat4) !Self {
    var self: Self = undefined;

    self.data = try allocator.dupe(Vertex, data);
    self.indices = try allocator.dupe(u32, indices);
    self.bones = try allocator.dupe(Bone, bones.len);

    self.ubo = try .init(ubo_binding, .{});
    self.ubo.write(@as([]const f32, @ptrCast(&model.transpose().data)), 0);

    return self;
}
