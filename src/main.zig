// Minimal WASM entry point - exports basic test functions
// For the actual game, use the game.zig files in each approach folder

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn multiply(a: i32, b: i32) i32 {
    return a * b;
}
