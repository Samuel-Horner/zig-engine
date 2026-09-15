const std = @import("std");
const gl = @import("gl");
const m = @import("../engine.zig").math;
const UBO = @import("../engine.zig").UBO;

pub const FPCamera = @import("fp_camera.zig");
pub const Animation = @import("animation.zig");

/// Returns a generic mesh
/// T is the vertex type, e.g.
/// ```zig
/// packed struct { x: f32, y: f32, z: f32 };
/// ```
/// Splits defines how the vertex is split into seperate attributes, i.e.
/// ```
/// &.{3, 3}
/// ```
/// would create 2 vec3 attributes.
pub fn Mesh(comptime T: type, splits: []const c_int) type {
    return struct {
        const Self = @This();

        pub const Vertex: type = T;

        data: []const T,
        indices: []const u32,

        vao: c_uint,
        vbo: c_uint,
        ebo: c_uint,

        pub fn draw(self: *const Self) void {
            gl.BindVertexArray(self.vao);
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);

            gl.DrawElements(gl.TRIANGLES, @intCast(self.indices.len), gl.UNSIGNED_INT, 0);
        }

        pub fn dispatch(self: *Self, opts: struct { draw_mode: c_uint = gl.STATIC_DRAW }) void {
            gl.GenVertexArrays(1, (&self.vao)[0..1]);
            gl.GenBuffers(1, (&self.vbo)[0..1]);
            gl.GenBuffers(1, (&self.ebo)[0..1]);

            gl.BindVertexArray(self.vao);

            gl.BindBuffer(gl.ARRAY_BUFFER, self.vbo);
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);

            gl.BufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(T) * self.data.len), self.data.ptr, opts.draw_mode);
            gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * self.indices.len), self.indices.ptr, opts.draw_mode);

            const stride: c_int = @sizeOf(T);

            var offset: usize = 0;
            for (splits, 0..) |split, i| {
                gl.VertexAttribPointer(@intCast(i), split, gl.FLOAT, gl.FALSE, stride, offset);
                gl.EnableVertexAttribArray(@intCast(i));
                offset += @intCast(split * @sizeOf(f32));
            }
        }

        pub fn undispatch(self: *const Self) void {
            gl.DeleteBuffers(2, &.{ self.vbo, self.ebo });
            gl.DeleteVertexArrays(1, &.{self.vao});
        }

        /// Non-transposed model matrix
        pub fn setModelMatrix(self: *const Self, model: m.Mat4) void {
            self.ubo.write(@as([]const f32, @ptrCast(&model.transpose().data)), 0);
        }

        pub fn init(data: []const T, indices: []const u32) Self {
            var self: Self = undefined;
            self.data = data;
            self.indices = indices;

            return self;
        }
    };
}

/// Generic Static mesh
pub const StaticMesh = Mesh(packed struct {
    // zig fmt: off
    x: f32 = 0, y: f32 = 0, z: f32 = 0,
    u: f32 = 0, v: f32 = 0,
    nx: f32 = 0, ny: f32 = 0, nz: f32 = 0,
    // zig fmt: on
}, &.{ 3, 2, 3 });

/// N-bone per vertex animated mesh.
/// Special case for n=1 removing weights array.
pub fn AnimatedMesh(comptime n: u32) type {
    if (n == 1) {
        return Mesh(packed struct {
            // zig fmt: off
            x: f32 = 0, y: f32 = 0, z: f32 = 0,
            u: f32 = 0, v: f32 = 0,
            nx: f32 = 0, ny: f32 = 0, nz: f32 = 0,
            bone: u32 = 0,
            // zig fmt: on
        }, &.{ 3, 2, 3, 1 });
    }

    // We get away with an extern struct since all values are 4-byte aligned
    return Mesh(extern struct {
        // zig fmt: off
        x: f32 = 0, y: f32 = 0, z: f32 = 0,
        u: f32 = 0, v: f32 = 0,
        nx: f32 = 0, ny: f32 = 0, nz: f32 = 0,
        bones: [n]u32 = [_]u32{0} ** n,
        weights: [n]f32 = [_]f32{0} ** n,
        // zig fmt: on
    }, &.{ 3, 2, 3, n, n });
}

/// Remember to deinit the mesh slices!
pub fn fromOBJ(allocator: std.mem.Allocator, src: []const u8) !StaticMesh {
    var data: std.ArrayList(StaticMesh.Vertex) = .empty;
    defer data.deinit(allocator);

    var indices: std.ArrayList(u32) = .empty;
    defer indices.deinit(allocator);

    var poss: std.ArrayList(m.Vec3) = .empty;
    defer poss.deinit(allocator);

    var texs: std.ArrayList(m.Vec2) = .empty;
    defer texs.deinit(allocator);

    var norms: std.ArrayList(m.Vec3) = .empty;
    defer norms.deinit(allocator);

    var defined_verts: std.StringHashMap(usize) = .init(allocator);
    defer defined_verts.deinit();

    var line_iter = std.mem.splitScalar(u8, src, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var value_iter = std.mem.splitScalar(u8, line, ' ');
        const indicator = value_iter.first();

        if (std.mem.eql(u8, indicator, "#") or std.mem.eql(u8, indicator, "o")) {
            continue;
        } else if (std.mem.eql(u8, indicator, "v")) {
            // Vertex
            const x = try std.fmt.parseFloat(f32, value_iter.next().?);
            const y = try std.fmt.parseFloat(f32, value_iter.next().?);
            const z = try std.fmt.parseFloat(f32, value_iter.next().?);
            try poss.append(allocator, m.vec3(x, y, z));
        } else if (std.mem.eql(u8, indicator, "vt")) {
            // Vertex Texture Coord
            const u = try std.fmt.parseFloat(f32, value_iter.next().?);
            const v = try std.fmt.parseFloat(f32, value_iter.next().?);
            try texs.append(allocator, m.vec2(u, v));
        } else if (std.mem.eql(u8, indicator, "vn")) {
            // Vertex Normal
            const x = try std.fmt.parseFloat(f32, value_iter.next().?);
            const y = try std.fmt.parseFloat(f32, value_iter.next().?);
            const z = try std.fmt.parseFloat(f32, value_iter.next().?);
            try norms.append(allocator, m.vec3(x, y, z));
        } else if (std.mem.eql(u8, indicator, "f")) {
            // Face
            while (value_iter.next()) |vert_buf| {
                var index = defined_verts.get(vert_buf);
                if (index == null) {
                    // Create vertex
                    var vert: StaticMesh.Vertex = .{};

                    var index_iter = std.mem.splitScalar(u8, vert_buf, '/');
                    const pos_index = try std.fmt.parseInt(usize, index_iter.first(), 10) - 1;
                    const vert_pos = poss.items[pos_index];
                    vert.x = vert_pos.data[0];
                    vert.y = vert_pos.data[1];
                    vert.z = vert_pos.data[2];

                    const tex_index_buf = index_iter.next().?;
                    if (tex_index_buf.len != 0) {
                        const tex_index = try std.fmt.parseInt(usize, tex_index_buf, 10) - 1;
                        const tex = texs.items[tex_index];
                        vert.u = tex.data[0];
                        vert.v = tex.data[1];
                    }

                    const norm_index_buf = index_iter.next().?;
                    if (norm_index_buf.len != 0) {
                        const norm_index = try std.fmt.parseInt(usize, norm_index_buf, 10) - 1;
                        const norm = norms.items[norm_index];
                        vert.nx = norm.data[0];
                        vert.ny = norm.data[1];
                        vert.nz = norm.data[2];
                    }

                    index = data.items.len;
                    try data.append(allocator, vert);
                    try defined_verts.put(vert_buf, index.?);
                }

                try indices.append(allocator, @intCast(index.?));
            }
        } else {
            std.log.err("Error passing OBJ. Unrecognised indicator '{s}'.", .{indicator});
        }
    }

    return StaticMesh.init(try allocator.dupe(StaticMesh.Vertex, data.items), try allocator.dupe(u32, indices.items));
}

/// Remember to deinit the mesh slices!
pub fn fromAOBJ(allocator: std.mem.Allocator, src: []const u8, comptime n: u32) !struct { AnimatedMesh(n), Animation } {
    var data: std.ArrayList(AnimatedMesh(n).Vertex) = .empty;
    defer data.deinit(allocator);

    var indices: std.ArrayList(u32) = .empty;
    defer indices.deinit(allocator);

    var poss: std.ArrayList(m.Vec3) = .empty;
    defer poss.deinit(allocator);

    var texs: std.ArrayList(m.Vec2) = .empty;
    defer texs.deinit(allocator);

    var norms: std.ArrayList(m.Vec3) = .empty;
    defer norms.deinit(allocator);

    var bones: std.ArrayList(std.ArrayList(m.Mat4)) = .empty;
    defer {
        for (0..bones.items.len) |i| {
            bones.items[i].deinit(allocator);
        }
        bones.deinit(allocator);
    }

    var keyframes: std.ArrayList(f32) = .empty;
    defer keyframes.deinit(allocator);

    var defined_verts: std.StringHashMap(usize) = .init(allocator);
    defer defined_verts.deinit();

    var line_iter = std.mem.splitScalar(u8, src, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var value_iter = std.mem.splitScalar(u8, line, ' ');
        const indicator = value_iter.first();

        if (std.mem.eql(u8, indicator, "#") or std.mem.eql(u8, indicator, "o")) {
            continue;
        } else if (std.mem.eql(u8, indicator, "v")) {
            // Vertex
            const x = try std.fmt.parseFloat(f32, value_iter.next().?);
            const y = try std.fmt.parseFloat(f32, value_iter.next().?);
            const z = try std.fmt.parseFloat(f32, value_iter.next().?);
            try poss.append(allocator, m.vec3(x, y, z));
        } else if (std.mem.eql(u8, indicator, "vt")) {
            // Vertex Texture Coord
            const u = try std.fmt.parseFloat(f32, value_iter.next().?);
            const v = try std.fmt.parseFloat(f32, value_iter.next().?);
            try texs.append(allocator, m.vec2(u, v));
        } else if (std.mem.eql(u8, indicator, "vn")) {
            // Vertex Normal
            const x = try std.fmt.parseFloat(f32, value_iter.next().?);
            const y = try std.fmt.parseFloat(f32, value_iter.next().?);
            const z = try std.fmt.parseFloat(f32, value_iter.next().?);
            try norms.append(allocator, m.vec3(x, y, z));
        } else if (std.mem.eql(u8, indicator, "b")) {
            // Bone
            var bone: std.ArrayList(m.Mat4) = .empty;

            var offset: m.Mat4 = undefined;
            var i: usize = 0;
            while (value_iter.next()) |val| {
                // Load offset matrix
                offset.data[@divFloor(@mod(i, 16), 4)][@mod(i, 4)] = try std.fmt.parseFloat(f32, val);
                i += 1;
                if (@mod(i, 16) == 0) {
                    try bone.append(allocator, offset);
                }
            }

            try bones.append(allocator, bone);
        } else if (std.mem.eql(u8, indicator, "kf")) {
            while (value_iter.next()) |val| {
                try keyframes.append(allocator, try std.fmt.parseFloat(f32, val));
            }
        } else if (std.mem.eql(u8, indicator, "f")) {
            // Face
            while (value_iter.next()) |vert_buf| {
                var index = defined_verts.get(vert_buf);
                if (index == null) {
                    // Create vertex
                    var vert: AnimatedMesh(n).Vertex = .{};

                    var index_iter = std.mem.splitScalar(u8, vert_buf, '/');
                    const pos_index = try std.fmt.parseInt(usize, index_iter.first(), 10) - 1;
                    const vert_pos = poss.items[pos_index];
                    vert.x = vert_pos.data[0];
                    vert.y = vert_pos.data[1];
                    vert.z = vert_pos.data[2];

                    const tex_index_buf = index_iter.next().?;
                    if (tex_index_buf.len != 0) {
                        const tex_index = try std.fmt.parseInt(usize, tex_index_buf, 10) - 1;
                        const tex = texs.items[tex_index];
                        vert.u = tex.data[0];
                        vert.v = tex.data[1];
                    }

                    const norm_index_buf = index_iter.next().?;
                    if (norm_index_buf.len != 0) {
                        const norm_index = try std.fmt.parseInt(usize, norm_index_buf, 10) - 1;
                        const norm = norms.items[norm_index];
                        vert.nx = norm.data[0];
                        vert.ny = norm.data[1];
                        vert.nz = norm.data[2];
                    }

                    var i:usize = 0;
                    while (index_iter.next()) |bone| {
                        var bone_iter = std.mem.splitScalar(u8, bone, ',');
                        const bone_index: u32 = try std.fmt.parseInt(u32, bone_iter.next().?, 10) - 1;
                        const weight: f32 = try std.fmt.parseFloat(f32, bone_iter.next().?);

                        if (n == 1) {
                            vert.bone = bone_index;
                            break;
                        }

                        vert.bones[i] = bone_index;
                        vert.weights[i] = weight;

                        i += 1;
                    }

                    index = data.items.len;
                    try data.append(allocator, vert);
                    try defined_verts.put(vert_buf, index.?);
                }

                try indices.append(allocator, @intCast(index.?));
            }
        } else {
            std.log.err("Error passing AOBJ. Unrecognised indicator '{s}'.", .{indicator});
        }
    }

    // Build animation
    var offsets: []m.Mat4 = try allocator.alloc(m.Mat4, bones.items.len * (keyframes.items.len - 1));
    for (keyframes.items[0 .. keyframes.items.len - 1], 0..) |_, i| {
        for (bones.items, 0..) |bone, j| {
            offsets[i * (keyframes.items.len - 1) + j] = bone.items[i];
        }
    }

    return .{
        .init(try allocator.dupe(AnimatedMesh(n).Vertex, data.items), try allocator.dupe(u32, indices.items)),
        .init(offsets, try allocator.dupe(f32, keyframes.items)),
    };
}
