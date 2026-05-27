const std = @import("std");
const gl = @import("gl");

pub const Mesh = struct {
    const Vertex = packed struct {
        const value_split: []const c_int = &.{3, 2, 3}; 

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

    pub fn draw(mesh: *Mesh) void {
        gl.BindVertexArray(mesh.vao);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.ebo);

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

    pub fn init(allocator: std.mem.Allocator, data: []const Vertex, indices: []const u32) !Mesh {
        var mesh: Mesh = undefined;

        mesh.data = try allocator.dupe(Vertex, data);
        mesh.indices = try allocator.dupe(u32, indices);

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
