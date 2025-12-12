const std = @import("std");

// Export functions for WASM - these will be callable from JavaScript
export fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

export fn initialize() void {
    // Initialization logic for the game will go here
}

export fn update(delta_time: f32) void {
    // Game update logic will go here
    _ = delta_time;
}

export fn render() void {
    // Rendering logic will go here
}

// Memory management - allocator for WASM
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

export fn allocate(size: usize) [*]u8 {
    const memory = allocator.alloc(u8, size) catch return undefined;
    return memory.ptr;
}

export fn deallocate(ptr: [*]u8, size: usize) void {
    const memory = ptr[0..size];
    allocator.free(memory);
}
