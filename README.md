# Zig WASM Shooter

A vertical shooter game implemented in **Zig** compiled to **WebAssembly**, with three different rendering approaches for comparison.

## Game Concept

Navigate your ship down a vertical hallway, dodging enemies and obstacles that spawn from above. Use WASD or arrow keys to move.

## Three Approaches

| Approach | Rendering | Complexity | Browser Support | Best For |
|----------|-----------|------------|-----------------|----------|
| **1. Canvas2D** | JavaScript Canvas2D | Easy | All browsers | Prototyping, simple games |
| **2. WebGL** | GPU via WebGL 1.0 | Medium | All browsers | Better performance, effects |
| **3. WebGPU** | Modern GPU API | Advanced | Chrome/Edge 113+ | Future-proof, best perf |

## Quick Start

### Prerequisites
- [Zig](https://ziglang.org/download/) (0.11+)
- A web browser (Chrome/Edge for WebGPU)
- Python 3 (for local server)

### Build

```bash
# Clone the repo
git clone https://github.com/superposition/zig-wasm-shooter.git
cd zig-wasm-shooter

# Build WASM for all approaches
zig build
```

### Run

```bash
# Start local server
python3 -m http.server 8080

# Open in browser:
# Canvas2D: http://localhost:8080/approach1-canvas2d/web/
# WebGL:    http://localhost:8080/approach2-webgl/web/
# WebGPU:   http://localhost:8080/approach3-webgpu/web/
```

## Project Structure

```
zig-wasm-shooter/
├── build.zig                 # Shared WASM build configuration
├── src/main.zig              # Shared entry point template
│
├── approach1-canvas2d/       # Easiest - JS rendering
│   ├── src/game.zig          # Game logic exports data to JS
│   └── web/
│       ├── index.html
│       └── game.js           # Canvas2D rendering
│
├── approach2-webgl/          # Medium - Zig calls WebGL
│   ├── src/game.zig          # Game logic + render() calls gl_*
│   └── web/
│       ├── index.html
│       ├── webgl.js          # WebGL bindings for Zig
│       └── shaders/
│           ├── vertex.glsl
│           └── fragment.glsl
│
└── approach3-webgpu/         # Advanced - Modern GPU
    ├── src/game.zig          # Game logic + render() calls gpu_*
    └── web/
        ├── index.html
        ├── webgpu.js         # WebGPU bindings for Zig
        └── shaders.wgsl
```

## Approach Comparison

### Approach 1: Canvas2D (Easiest)

**Strategy**: Zig handles game logic only. JavaScript reads game state and renders with Canvas2D.

**Pros**:
- Simplest to implement
- Works everywhere
- Easy to debug
- Clear separation of concerns

**Cons**:
- Not true GPU rendering
- Limited visual effects
- Performance ceiling

**Exported Functions**:
```zig
export fn init() void;
export fn update(delta_time: f32) void;
export fn get_player_x() f32;
export fn get_player_y() f32;
export fn get_entity_count() i32;
export fn get_entity_data(index: i32) [*]f32;
```

### Approach 2: WebGL (Medium)

**Strategy**: Zig handles game logic AND rendering by calling WebGL functions imported from JavaScript.

**Pros**:
- True GPU rendering
- Universal browser support
- Shader effects possible
- Good performance

**Cons**:
- More setup required
- GL state management
- Shader debugging

**Imported Functions** (from JS):
```zig
extern fn gl_clear(r: f32, g: f32, b: f32, a: f32) void;
extern fn gl_draw_quad(x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32) void;
extern fn gl_draw_triangle(...) void;
```

### Approach 3: WebGPU (Advanced)

**Strategy**: Zig controls rendering through modern WebGPU API bindings.

**Pros**:
- Best performance potential
- Modern GPU features
- Compute shaders available
- Future-proof

**Cons**:
- Limited browser support
- Most complex setup
- Newer, less documentation

**Imported Functions** (from JS):
```zig
extern fn gpu_begin_frame() void;
extern fn gpu_end_frame() void;
extern fn gpu_draw_rect(x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32) void;
extern fn gpu_draw_triangle(...) void;
```

## Controls

- **W / ↑** - Move up
- **A / ←** - Move left
- **S / ↓** - Move down
- **D / →** - Move right

## Game Mechanics

- **Player**: Green/cyan triangle at bottom
- **Enemies**: Red shapes moving down (10 damage)
- **Obstacles**: Gray rectangles moving down (20 damage)
- **Score**: Increases over time survived
- **Health**: Starts at 100, game over at 0

## Development

### GitHub Issues

This project was developed using GitHub Issues for task tracking. See the [Issues](https://github.com/superposition/zig-wasm-shooter/issues) page for the full development history with blockers and dependencies.

### Multi-Agent Development

The project structure supports parallel development:
- Issues #2, #5, #10 (game.zig) can run in parallel after #1
- Issues #6, #11 (shaders) have no dependencies
- Web shells depend on their respective game.zig files

## License

MIT

---

Built with Zig + WebAssembly
