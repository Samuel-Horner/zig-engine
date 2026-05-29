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

    const zig_engine_tests = b.addTest(.{
        .root_module = zig_engine,
        .use_llvm = true, // Needed for some reason
    });

    const run_zig_engine_tests = b.addRunArtifact(zig_engine_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_zig_engine_tests.step);
}
