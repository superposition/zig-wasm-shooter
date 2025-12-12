const std = @import("std");

pub fn build(b: *std.Build) void {
    // Create a WASM compilation target
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // Set optimization mode
    const optimize = b.standardOptimizeOption(.{});

    // Build approach 1 - Canvas2D
    const canvas2d = b.addExecutable(.{
        .name = "game-canvas2d",
        .root_module = b.createModule(.{
            .root_source_file = b.path("approach1-canvas2d/src/game.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    canvas2d.entry = .disabled;
    canvas2d.rdynamic = true;
    b.installArtifact(canvas2d);

    // Build approach 2 - WebGL
    const webgl = b.addExecutable(.{
        .name = "game-webgl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("approach2-webgl/src/game.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    webgl.entry = .disabled;
    webgl.rdynamic = true;
    b.installArtifact(webgl);

    // Build approach 3 - WebGPU
    const webgpu = b.addExecutable(.{
        .name = "game-webgpu",
        .root_module = b.createModule(.{
            .root_source_file = b.path("approach3-webgpu/src/game.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    webgpu.entry = .disabled;
    webgpu.rdynamic = true;
    b.installArtifact(webgpu);
}
