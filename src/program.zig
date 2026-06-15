const std = @import("std");
const gl = @import("gl");
const ubo = @import("ubo.zig");
const m = @import("math/root.zig");

id: c_uint,

const Self = @This();

fn compileShader(shader: c_uint, source: []const u8) !void {
    gl.ShaderSource(shader, 1, &.{source.ptr}, &.{@intCast(source.len)});
    gl.CompileShader(shader);

    var success: i32 = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, (&success)[0..1]);
    if (success != 1) {
        var info_log: [1024:0]u8 = undefined;
        gl.GetShaderInfoLog(shader, info_log.len, null, &info_log);
        std.log.err("Shader {} failed to compile.\n{s}", .{ shader, std.mem.sliceTo(&info_log, 0) });

        return error.ShaderCompilationFailed;
    }
}

fn linkProgram(self: *Self, vertex_shader: c_uint, fragment_shader: c_uint) !void {
    gl.AttachShader(self.id, vertex_shader);
    gl.AttachShader(self.id, fragment_shader);

    gl.LinkProgram(self.id);

    // Check program link status
    var success: i32 = undefined;
    gl.GetProgramiv(self.id, gl.LINK_STATUS, (&success)[0..1]);
    if (success != 1) {
        var info_log: [1024:0]u8 = undefined;
        gl.GetProgramInfoLog(self.id, info_log.len, null, &info_log);
        std.log.err("Program {} failed to link.\n{s}", .{ self.id, std.mem.sliceTo(&info_log, 0) });

        return error.ProgramLinkFailed;
    }
}

pub fn use(self: *const Self) void {
    gl.UseProgram(self.id);
}

// Uniform Setters
pub fn setVec2(self: *const Self, name: [*:0]const u8, v: m.Vec2) void {
    gl.ProgramUniform2fv(self.id, gl.GetUniformLocation(self.id, name), 1, @ptrCast(&v.data));
}

pub fn setVec3(self: *const Self, name: [*:0]const u8, v: m.Vec3) void {
    gl.ProgramUniform3fv(self.id, gl.GetUniformLocation(self.id, name), 1, @ptrCast(&v.data));
}

pub fn setVec4(self: *const Self, name: [*:0]const u8, v: m.Vec4) void {
    gl.ProgramUniform4fv(self.id, gl.GetUniformLocation(self.id, name), 1, @ptrCast(&v.data));
}

pub fn setMat2(self: *const Self, name: [*:0]const u8, v: m.Mat2) void {
    gl.ProgramUniformMatrix2fv(self.id, gl.GetUniformLocation(self.id, name), 1, @ptrCast(&v.data));
}

pub fn setMat3(self: *const Self, name: [*:0]const u8, v: m.Mat3) void {
    gl.ProgramUniformMatrix3fv(self.id, gl.GetUniformLocation(self.id, name), 1, @ptrCast(&v.data));
}

pub fn setMat4(self: *const Self, name: [*:0]const u8, v: m.Mat4) void {
    gl.ProgramUniformMatrix4fv(self.id, gl.GetUniformLocation(self.id, name), 1, @ptrCast(&v.data));
}

pub fn init(vertex_source: []const u8, fragment_source: []const u8) !Self {
    var program: Self = undefined;

    // Vertex Shader
    const vertex_shader: c_uint = gl.CreateShader(gl.VERTEX_SHADER);
    try compileShader(vertex_shader, vertex_source);

    // Fragment Shader
    const fragment_shader: c_uint = gl.CreateShader(gl.FRAGMENT_SHADER);
    try compileShader(fragment_shader, fragment_source);

    // Create and link program
    program.id = gl.CreateProgram();
    try program.linkProgram(vertex_shader, fragment_shader);

    std.log.debug("Created program {}.", .{program.id});

    // Delete shaders
    gl.DeleteShader(vertex_shader);
    gl.DeleteShader(fragment_shader);

    return program;
}

pub fn deinit(self: *Self) void {
    gl.DeleteProgram(self.id);
}
