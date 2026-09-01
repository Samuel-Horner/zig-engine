const std = @import("std");
const engine = @import("engine.zig");
const gl = @import("gl");

const m = engine.math;

fn getStd140Size(comptime t: type) comptime_int {
    return 4 * switch (t) {
        bool, u32, i32, f32 => 1,
        m.Vec2 => 2,
        m.Vec3, m.Vec4 => 4,
        m.Mat2 => 8,
        m.Mat3 => 12,
        m.Mat4 => 16,
        else => error.UndefinedSize,
    };
}

pub fn UBO(comptime vals: []const type) type {
    const offsets: [vals.len]isize = comptime offsets: {
        var arr: [vals.len]isize = undefined;
        arr[0] = 0;
        for (vals[0 .. vals.len - 1], 1..) |val, i| {
            arr[i] = getStd140Size(val) + arr[i - 1];
        }
        break :offsets arr;
    };

    const size = comptime size: {
        var sum = 0;
        for (vals) |val| {
            sum += getStd140Size(val);
        }
        break :size sum;
    };

    return struct {
        const Self = @This();

        ubo: u32,

        pub fn write(self: *const Self, data: anytype, index: usize) void {
            const bytes = std.mem.sliceAsBytes(data);
            gl.BindBuffer(gl.UNIFORM_BUFFER, self.ubo);
            gl.BufferSubData(gl.UNIFORM_BUFFER, offsets[index], @intCast(bytes.len), @ptrCast(bytes));
        }

        pub fn writeBytes(self: *const Self, data: []const u8, index: usize) void {
            gl.BindBuffer(gl.UNIFORM_BUFFER, self.ubo);
            gl.BufferSubData(gl.UNIFORM_BUFFER, offsets[index], @intCast(data.len), @ptrCast(data.ptr));
        }

        pub fn writePrimitive(self: *const Self, index: comptime_int, data: vals[index]) void {
            gl.BindBuffer(gl.UNIFORM_BUFFER, self.ubo);
            gl.BufferSubData(gl.UNIFORM_BUFFER, offsets[index], @intCast(getStd140Size(vals[index])), &data);
        }

        pub fn bind(self: *const Self, bind_point: c_uint) void {
            gl.BindBuffer(gl.UNIFORM_BUFFER, self.ubo);
            gl.BindBufferBase(gl.UNIFORM_BUFFER, bind_point, self.ubo);
        }

        pub fn init(opts: struct { draw_mode: c_uint = gl.DYNAMIC_DRAW }) !Self {
            var self: Self = undefined;

            gl.GenBuffers(1, (&self.ubo)[0..1]);
            gl.BindBuffer(gl.UNIFORM_BUFFER, self.ubo);
            gl.BufferData(gl.UNIFORM_BUFFER, size, null, opts.draw_mode);

            return self;
        }

        pub fn deinit(self: *const Self) void {
            gl.DeleteBuffers(1, &.{self.ubo});
        }
    };
}
