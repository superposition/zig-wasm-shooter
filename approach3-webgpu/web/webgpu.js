// WebGPU JavaScript bindings for zig-wasm-shooter
// Provides rendering interface for game.zig

// WebGPU state
let device;
let context;
let renderPipeline;
let commandEncoder;
let renderPass;
let uniformBindGroup;
let resolutionBuffer;
let colorBuffer;
let vertexBuffer;
let wasmInstance;
let wasmMemory;

// Canvas dimensions
const CANVAS_WIDTH = 800;
const CANVAS_HEIGHT = 600;

// Maximum vertices per draw call (for rectangles and triangles)
const MAX_VERTICES = 6; // 2 triangles = 6 vertices for rectangle, or 3 for triangle

// Draw state
let currentVertices = [];

// Check WebGPU support
async function checkWebGPUSupport() {
    if (!navigator.gpu) {
        throw new Error('WebGPU is not supported in this browser. Please use Chrome/Edge 113+ or another WebGPU-compatible browser.');
    }
}

// Initialize WebGPU
async function initWebGPU() {
    await checkWebGPUSupport();

    // Get canvas
    const canvas = document.getElementById('gameCanvas');
    if (!canvas) {
        throw new Error('Canvas element not found');
    }
    canvas.width = CANVAS_WIDTH;
    canvas.height = CANVAS_HEIGHT;

    // Request adapter and device
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) {
        throw new Error('Failed to get GPU adapter');
    }

    device = await adapter.requestDevice();
    if (!device) {
        throw new Error('Failed to get GPU device');
    }

    // Configure canvas context
    context = canvas.getContext('webgpu');
    const presentationFormat = navigator.gpu.getPreferredCanvasFormat();

    context.configure({
        device: device,
        format: presentationFormat,
        alphaMode: 'premultiplied',
    });

    // Load shader code
    const shaderResponse = await fetch('shaders.wgsl');
    const shaderCode = await shaderResponse.text();

    // Create shader module
    const shaderModule = device.createShaderModule({
        label: 'Game shaders',
        code: shaderCode,
    });

    // Create uniform buffers
    resolutionBuffer = device.createBuffer({
        label: 'Resolution uniform buffer',
        size: 8, // vec2<f32> = 2 * 4 bytes
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    colorBuffer = device.createBuffer({
        label: 'Color uniform buffer',
        size: 16, // vec4<f32> = 4 * 4 bytes
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    // Write resolution to buffer
    device.queue.writeBuffer(
        resolutionBuffer,
        0,
        new Float32Array([CANVAS_WIDTH, CANVAS_HEIGHT])
    );

    // Create vertex buffer
    vertexBuffer = device.createBuffer({
        label: 'Vertex buffer',
        size: MAX_VERTICES * 2 * 4, // MAX_VERTICES * vec2<f32> * 4 bytes
        usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
    });

    // Create bind group layout
    const bindGroupLayout = device.createBindGroupLayout({
        label: 'Bind group layout',
        entries: [
            {
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: { type: 'uniform' }
            },
            {
                binding: 1,
                visibility: GPUShaderStage.FRAGMENT,
                buffer: { type: 'uniform' }
            }
        ]
    });

    // Create bind group
    uniformBindGroup = device.createBindGroup({
        label: 'Uniform bind group',
        layout: bindGroupLayout,
        entries: [
            {
                binding: 0,
                resource: { buffer: resolutionBuffer }
            },
            {
                binding: 1,
                resource: { buffer: colorBuffer }
            }
        ]
    });

    // Create pipeline layout
    const pipelineLayout = device.createPipelineLayout({
        label: 'Pipeline layout',
        bindGroupLayouts: [bindGroupLayout]
    });

    // Create render pipeline
    renderPipeline = device.createRenderPipeline({
        label: 'Render pipeline',
        layout: pipelineLayout,
        vertex: {
            module: shaderModule,
            entryPoint: 'vertex_main',
            buffers: [
                {
                    arrayStride: 8, // vec2<f32> = 2 * 4 bytes
                    attributes: [
                        {
                            shaderLocation: 0,
                            offset: 0,
                            format: 'float32x2'
                        }
                    ]
                }
            ]
        },
        fragment: {
            module: shaderModule,
            entryPoint: 'fragment_main',
            targets: [
                {
                    format: presentationFormat,
                    blend: {
                        color: {
                            srcFactor: 'src-alpha',
                            dstFactor: 'one-minus-src-alpha',
                            operation: 'add'
                        },
                        alpha: {
                            srcFactor: 'one',
                            dstFactor: 'one-minus-src-alpha',
                            operation: 'add'
                        }
                    }
                }
            ]
        },
        primitive: {
            topology: 'triangle-list',
            cullMode: 'none'
        }
    });

    console.log('WebGPU initialized successfully');
}

// Begin frame - create command encoder and render pass
function gpu_begin_frame() {
    // Create command encoder
    commandEncoder = device.createCommandEncoder({
        label: 'Frame command encoder'
    });

    // Get current texture from canvas
    const textureView = context.getCurrentTexture().createView();

    // Begin render pass
    renderPass = commandEncoder.beginRenderPass({
        label: 'Frame render pass',
        colorAttachments: [
            {
                view: textureView,
                clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
                loadOp: 'clear',
                storeOp: 'store'
            }
        ]
    });

    // Set pipeline
    renderPass.setPipeline(renderPipeline);
    renderPass.setBindGroup(0, uniformBindGroup);
}

// End frame - end render pass and submit
function gpu_end_frame() {
    // End render pass
    renderPass.end();

    // Submit command buffer
    device.queue.submit([commandEncoder.finish()]);
}

// Draw filled rectangle
function gpu_draw_rect(x, y, w, h, r, g, b, a) {
    // Create two triangles for the rectangle
    // Triangle 1: top-left, top-right, bottom-left
    // Triangle 2: top-right, bottom-right, bottom-left
    const vertices = new Float32Array([
        x, y,           // top-left
        x + w, y,       // top-right
        x, y + h,       // bottom-left
        x + w, y,       // top-right
        x + w, y + h,   // bottom-right
        x, y + h        // bottom-left
    ]);

    // Update color buffer
    device.queue.writeBuffer(
        colorBuffer,
        0,
        new Float32Array([r, g, b, a])
    );

    // Update vertex buffer
    device.queue.writeBuffer(vertexBuffer, 0, vertices);

    // Set vertex buffer and draw
    renderPass.setVertexBuffer(0, vertexBuffer);
    renderPass.draw(6, 1, 0, 0); // 6 vertices for 2 triangles
}

// Draw filled triangle
function gpu_draw_triangle(x1, y1, x2, y2, x3, y3, r, g, b, a) {
    // Create triangle vertices
    const vertices = new Float32Array([
        x1, y1,
        x2, y2,
        x3, y3
    ]);

    // Update color buffer
    device.queue.writeBuffer(
        colorBuffer,
        0,
        new Float32Array([r, g, b, a])
    );

    // Update vertex buffer
    device.queue.writeBuffer(vertexBuffer, 0, vertices);

    // Set vertex buffer and draw
    renderPass.setVertexBuffer(0, vertexBuffer);
    renderPass.draw(3, 1, 0, 0); // 3 vertices for 1 triangle
}

// WASM imports object
const wasmImports = {
    env: {
        gpu_begin_frame,
        gpu_end_frame,
        gpu_draw_rect,
        gpu_draw_triangle
    }
};

// Load WASM and start game
async function loadWASM() {
    try {
        // Fetch WASM file
        const response = await fetch('game.wasm');
        const wasmBytes = await response.arrayBuffer();

        // Instantiate WASM module
        const wasmModule = await WebAssembly.instantiate(wasmBytes, wasmImports);
        wasmInstance = wasmModule.instance;
        wasmMemory = wasmInstance.exports.memory;

        console.log('WASM loaded successfully');

        // Initialize game
        if (wasmInstance.exports.init) {
            wasmInstance.exports.init();
            console.log('Game initialized');
        }

        // Start game loop
        startGameLoop();
    } catch (error) {
        console.error('Failed to load WASM:', error);
        throw error;
    }
}

// Game loop
let lastTime = performance.now();
let isRunning = true;

function startGameLoop() {
    function gameLoop() {
        if (!isRunning) return;

        // Calculate delta time in seconds
        const currentTime = performance.now();
        const deltaTime = (currentTime - lastTime) / 1000.0;
        lastTime = currentTime;

        // Update game state
        if (wasmInstance.exports.update) {
            wasmInstance.exports.update(deltaTime);
        }

        // Render game
        if (wasmInstance.exports.render) {
            wasmInstance.exports.render();
        }

        // Update score display
        if (wasmInstance.exports.get_score) {
            const score = wasmInstance.exports.get_score();
            const scoreElement = document.getElementById('score');
            if (scoreElement) {
                scoreElement.textContent = `Score: ${score}`;
            }
        }

        // Continue loop
        requestAnimationFrame(gameLoop);
    }

    requestAnimationFrame(gameLoop);
    console.log('Game loop started');
}

// Keyboard input handling
function setupKeyboardInput() {
    document.addEventListener('keydown', (event) => {
        if (wasmInstance && wasmInstance.exports.key_down) {
            wasmInstance.exports.key_down(event.keyCode);
        }
        // Prevent default for arrow keys and WASD
        if ([37, 38, 39, 40, 65, 68, 83, 87].includes(event.keyCode)) {
            event.preventDefault();
        }
    });

    document.addEventListener('keyup', (event) => {
        if (wasmInstance && wasmInstance.exports.key_up) {
            wasmInstance.exports.key_up(event.keyCode);
        }
    });

    console.log('Keyboard input setup complete');
}

// Initialize everything
async function init() {
    try {
        console.log('Initializing WebGPU shooter game...');

        // Initialize WebGPU
        await initWebGPU();

        // Setup keyboard input
        setupKeyboardInput();

        // Load WASM and start game
        await loadWASM();

        console.log('Game ready!');
    } catch (error) {
        console.error('Initialization failed:', error);

        // Display error to user
        const canvas = document.getElementById('gameCanvas');
        if (canvas) {
            const ctx = canvas.getContext('2d');
            if (ctx) {
                ctx.fillStyle = '#ff0000';
                ctx.font = '20px Arial';
                ctx.fillText('Failed to initialize WebGPU', 50, 50);
                ctx.fillText('Check console for details', 50, 80);
            }
        }
    }
}

// Start when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
