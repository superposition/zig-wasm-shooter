const std = @import("std");

pub fn build(b: *std.Build) void {
    // Create a WASM compilation target
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // Set optimization mode (can be overridden with -Doptimize=...)
    const optimize = b.standardOptimizeOption(.{});

    // Create the WASM library
    const wasm = b.addExecutable(.{
        .name = "shooter",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Configure for WASM
    wasm.entry = .disabled; // No _start function needed
    wasm.rdynamic = true; // Export all symbols

    // Install the WASM file to zig-out/bin/
    b.installArtifact(wasm);

    // Create a run step for convenience (though WASM can't be directly run)
    const install_step = b.getInstallStep();
    install_step.dependOn(&wasm.step);
}
