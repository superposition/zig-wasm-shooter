// Uniform bindings
@group(0) @binding(0) var<uniform> resolution: vec2<f32>;
@group(0) @binding(1) var<uniform> color: vec4<f32>;

// Vertex input structure
struct VertexInput {
    @location(0) position: vec2<f32>,
}

// Vertex output structure
struct VertexOutput {
    @builtin(position) position: vec4<f32>,
}

// Vertex shader for 2D positioning
@vertex
fn vertex_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;

    // Convert from pixel coordinates to normalized device coordinates (-1 to 1)
    let normalized_x = (input.position.x / resolution.x) * 2.0 - 1.0;
    let normalized_y = 1.0 - (input.position.y / resolution.y) * 2.0;

    output.position = vec4<f32>(normalized_x, normalized_y, 0.0, 1.0);

    return output;
}

// Fragment shader for solid colors
@fragment
fn fragment_main(input: VertexOutput) -> @location(0) vec4<f32> {
    return color;
}
