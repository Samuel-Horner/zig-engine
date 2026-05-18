const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gl = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.6",
        .profile = .core,
        .extensions = &.{},
    });

    const zglfw = b.dependency("zglfw", .{});

    const zig_engine = b.addModule("zig_engine", .{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl },
            .{ .name = "glfw", .module = zglfw.module("glfw") },
        },
    });

    zig_engine.linkSystemLibrary("glfw", .{});

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zig_engine",
        .root_module = zig_engine,
    });

    b.installArtifact(lib);
}
