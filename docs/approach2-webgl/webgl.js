// WebGL JavaScript bindings for Zig WASM game
// Provides gl_clear, gl_draw_quad, and gl_draw_triangle functions

let gl;
let shaderProgram;
let positionBuffer;
let resolutionUniformLocation;
let colorUniformLocation;
let wasmInstance;
let lastTime = 0;

// Canvas dimensions
const CANVAS_WIDTH = 800;
const CANVAS_HEIGHT = 600;

// Initialize WebGL context and setup
async function initWebGL() {
    const canvas = document.getElementById('gameCanvas');
    if (!canvas) {
        console.error('Canvas element not found');
        return false;
    }

    // Set canvas size
    canvas.width = CANVAS_WIDTH;
    canvas.height = CANVAS_HEIGHT;

    // Get WebGL context
    gl = canvas.getContext('webgl');
    if (!gl) {
        console.error('WebGL not supported');
        return false;
    }

    // Load and compile shaders
    const vertexShaderSource = await loadShader('shaders/vertex.glsl');
    const fragmentShaderSource = await loadShader('shaders/fragment.glsl');

    if (!vertexShaderSource || !fragmentShaderSource) {
        console.error('Failed to load shaders');
        return false;
    }

    const vertexShader = compileShader(gl.VERTEX_SHADER, vertexShaderSource);
    const fragmentShader = compileShader(gl.FRAGMENT_SHADER, fragmentShaderSource);

    if (!vertexShader || !fragmentShader) {
        console.error('Failed to compile shaders');
        return false;
    }

    // Create shader program
    shaderProgram = gl.createProgram();
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.linkProgram(shaderProgram);

    if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS)) {
        console.error('Failed to link shader program:', gl.getProgramInfoLog(shaderProgram));
        return false;
    }

    gl.useProgram(shaderProgram);

    // Get attribute and uniform locations
    const positionAttributeLocation = gl.getAttribLocation(shaderProgram, 'a_position');
    resolutionUniformLocation = gl.getUniformLocation(shaderProgram, 'u_resolution');
    colorUniformLocation = gl.getUniformLocation(shaderProgram, 'u_color');

    // Create position buffer
    positionBuffer = gl.createBuffer();

    // Enable the position attribute
    gl.enableVertexAttribArray(positionAttributeLocation);
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.vertexAttribPointer(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0);

    // Set the resolution uniform
    gl.uniform2f(resolutionUniformLocation, CANVAS_WIDTH, CANVAS_HEIGHT);

    // Enable blending for transparency
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    return true;
}

// Load shader from file
async function loadShader(path) {
    try {
        const response = await fetch(path);
        if (!response.ok) {
            console.error(`Failed to load shader: ${path}`);
            return null;
        }
        return await response.text();
    } catch (error) {
        console.error(`Error loading shader ${path}:`, error);
        return null;
    }
}

// Compile a shader
function compileShader(type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error('Shader compilation error:', gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        return null;
    }

    return shader;
}

// Clear the screen with a color
function gl_clear(r, g, b, a) {
    gl.clearColor(r, g, b, a);
    gl.clear(gl.COLOR_BUFFER_BIT);
}

// Draw a filled rectangle (quad)
function gl_draw_quad(x, y, w, h, r, g, b, a) {
    // Define two triangles to form a rectangle
    const x1 = x;
    const y1 = y;
    const x2 = x + w;
    const y2 = y + h;

    const positions = new Float32Array([
        x1, y1,  // Top-left
        x2, y1,  // Top-right
        x1, y2,  // Bottom-left
        x1, y2,  // Bottom-left
        x2, y1,  // Top-right
        x2, y2,  // Bottom-right
    ]);

    // Set the color uniform
    gl.uniform4f(colorUniformLocation, r, g, b, a);

    // Set the position buffer
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW);

    // Draw the quad
    gl.drawArrays(gl.TRIANGLES, 0, 6);
}

// Draw a filled triangle
function gl_draw_triangle(x1, y1, x2, y2, x3, y3, r, g, b, a) {
    const positions = new Float32Array([
        x1, y1,
        x2, y2,
        x3, y3,
    ]);

    // Set the color uniform
    gl.uniform4f(colorUniformLocation, r, g, b, a);

    // Set the position buffer
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW);

    // Draw the triangle
    gl.drawArrays(gl.TRIANGLES, 0, 3);
}

// Load WASM module and initialize game
async function loadWasm() {
    try {
        // Define the imports that WASM expects
        const wasmImports = {
            env: {
                gl_clear: gl_clear,
                gl_draw_quad: gl_draw_quad,
                gl_draw_triangle: gl_draw_triangle,
            }
        };

        // Load and instantiate WASM module
        const response = await fetch('game-webgl.wasm');
        const wasmBytes = await response.arrayBuffer();
        const wasmModule = await WebAssembly.instantiate(wasmBytes, wasmImports);

        wasmInstance = wasmModule.instance;

        // Initialize the game
        wasmInstance.exports.init();

        console.log('WASM module loaded and game initialized');
        return true;
    } catch (error) {
        console.error('Failed to load WASM module:', error);
        return false;
    }
}

// Game loop
function gameLoop(currentTime) {
    // Calculate delta time in seconds
    const deltaTime = lastTime === 0 ? 0 : (currentTime - lastTime) / 1000;
    lastTime = currentTime;

    // Cap delta time to avoid large jumps
    const cappedDeltaTime = Math.min(deltaTime, 0.1);

    // Update game logic
    if (wasmInstance) {
        wasmInstance.exports.update(cappedDeltaTime);
        wasmInstance.exports.render();

        // Update score display
        const score = wasmInstance.exports.get_score();
        const isAlive = wasmInstance.exports.is_alive();

        const scoreElement = document.getElementById('score');
        if (scoreElement) {
            scoreElement.textContent = `Score: ${score}`;

            if (!isAlive) {
                scoreElement.textContent += ' - GAME OVER! (Refresh to restart)';
            }
        }
    }

    // Continue the loop
    requestAnimationFrame(gameLoop);
}

// Keyboard input handling
function setupKeyboardInput() {
    window.addEventListener('keydown', (event) => {
        if (wasmInstance) {
            wasmInstance.exports.key_down(event.keyCode);
        }
        // Prevent arrow keys from scrolling the page
        if ([37, 38, 39, 40].includes(event.keyCode)) {
            event.preventDefault();
        }
    });

    window.addEventListener('keyup', (event) => {
        if (wasmInstance) {
            wasmInstance.exports.key_up(event.keyCode);
        }
    });
}

// Initialize and start the game
async function main() {
    console.log('Initializing game...');

    // Initialize WebGL
    const webglInit = await initWebGL();
    if (!webglInit) {
        console.error('Failed to initialize WebGL');
        return;
    }

    console.log('WebGL initialized');

    // Load WASM module
    const wasmLoaded = await loadWasm();
    if (!wasmLoaded) {
        console.error('Failed to load WASM module');
        return;
    }

    // Setup keyboard input
    setupKeyboardInput();

    // Start game loop
    console.log('Starting game loop...');
    requestAnimationFrame(gameLoop);
}

// Start the game when page loads
window.addEventListener('load', main);
