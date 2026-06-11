const std = @import("std");
const gl = @import("gl");
const m = @import("math/root.zig");
const UBO = @import("ubo.zig").UBO;

pub const Mesh = struct {
    const Vertex = packed struct {
        const value_split: []const c_int = &.{ 3, 2, 3 };

        x: f32,
        y: f32,
        z: f32,

        tx: f32 = 0,
        ty: f32 = 0,

        nx: f32 = 0,
        ny: f32 = 0,
        nz: f32 = 0,
    };

    data: []Vertex,
    indices: []u32,

    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint,

    ubo: UBO(&.{m.Mat4}),

    pub fn draw(mesh: *Mesh) void {
        gl.BindVertexArray(mesh.vao);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.ebo);

        mesh.ubo.bind();

        gl.DrawElements(gl.TRIANGLES, @intCast(mesh.indices.len), gl.UNSIGNED_INT, 0);
    }

    pub fn dispatch(mesh: *Mesh, opts: struct { draw_mode: c_uint = gl.STATIC_DRAW }) void {
        gl.GenVertexArrays(1, (&mesh.vao)[0..1]);
        gl.GenBuffers(1, (&mesh.vbo)[0..1]);
        gl.GenBuffers(1, (&mesh.ebo)[0..1]);

        gl.BindVertexArray(mesh.vao);

        gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.ebo);

        gl.BufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(Vertex) * mesh.data.len), mesh.data.ptr, opts.draw_mode);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * mesh.indices.len), mesh.indices.ptr, opts.draw_mode);

        const stride: c_int = @sizeOf(Vertex);

        var offset: usize = 0;
        for (Vertex.value_split, 0..) |split, i| {
            gl.VertexAttribPointer(@intCast(i), split, gl.FLOAT, gl.FALSE, stride, offset);
            gl.EnableVertexAttribArray(@intCast(i));
            offset += @intCast(split * @sizeOf(f32));
        }
    }

    pub fn undispatch(mesh: *Mesh) void {
        gl.DeleteBuffers(3, &.{ mesh.vao, mesh.vbo, mesh.ebo });
    }

    pub fn fromOBJ(allocator: std.mem.Allocator, src: []const u8, ubo_binding: u32, pos: m.Vec3) !Mesh {
        var data: std.ArrayList(Vertex) = .empty;
        defer data.deinit(allocator);

        var poss: std.ArrayList(m.Vec3) = .empty;
        defer poss.deinit(allocator);

        var texs: std.ArrayList(m.Vec2) = .empty;
        defer texs.deinit(allocator);

        var norms: std.ArrayList(m.Vec3) = .empty;
        defer norms.deinit(allocator);

        var defined_verts: std.StringHashMap(usize) = .init(allocator);
        defer defined_verts.deinit();

        var indices: std.ArrayList(u32) = .empty;
        defer indices.deinit(allocator);

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
                while(value_iter.next()) |vert_buf| {
                    var index = defined_verts.get(vert_buf);
                    if (index == null) {
                        // Create vertex
                        var vert: Vertex = undefined;

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
                            vert.tx = tex.data[0];
                            vert.ty = tex.data[1];
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

        return Mesh.init(allocator, data.items, indices.items, ubo_binding, pos);
    }

    pub fn init(allocator: std.mem.Allocator, data: []const Vertex, indices: []const u32, ubo_binding: u32, pos: m.Vec3) !Mesh {
        var mesh: Mesh = undefined;

        mesh.data = try allocator.dupe(Vertex, data);
        mesh.indices = try allocator.dupe(u32, indices);

        mesh.ubo = try .init(ubo_binding, .{});
        const model = m.Mat4.translation(pos.data[0], pos.data[1], pos.data[2]).transpose();
        mesh.ubo.write(@as([]const f32, @ptrCast(&model.data)), 0);

        return mesh;
    }

    pub fn deinit(mesh: *Mesh, allocator: std.mem.Allocator) void {
        allocator.free(mesh.indices);
        allocator.free(mesh.data);
    }
};

const Self = @This();

ptr: *anyopaque,
tickFn: *const fn (ptr: *anyopaque) anyerror!void,

mesh: ?*Mesh,

pub fn init(ptr: anytype, mesh_ptr: ?*Mesh) Self {
    const T = @TypeOf(ptr);
    const ptr_info = @typeInfo(T);

    const gen = struct {
        pub fn tick(pointer: *anyopaque) anyerror!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.pointer.child.tick(self);
        }
    };

    return .{
        .ptr = ptr,
        .tickFn = gen.tick,

        .mesh = mesh_ptr,
    };
}

pub fn draw(self: Self) !void {
    self.mesh.?.draw();
}

pub fn tick(self: Self) !void {
    return self.tickFn(self.ptr);
}
