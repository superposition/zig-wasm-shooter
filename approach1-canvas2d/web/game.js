// Canvas2D WASM Shooter Game
// This file bridges the WASM game logic with Canvas2D rendering

const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const statusElement = document.getElementById('status');

// Game constants
const GAME_WIDTH = 800;
const GAME_HEIGHT = 600;
const PLAYER_SIZE = 20;

// WASM instance
let wasmInstance = null;
let wasmMemory = null;

// Game state
let lastFrameTime = performance.now();
let isRunning = false;

// Update status message
function updateStatus(message, isError = false) {
    statusElement.textContent = message;
    if (isError) {
        statusElement.classList.add('error');
    } else {
        statusElement.classList.remove('error');
    }
}

// Load and initialize WASM module
async function loadWasm() {
    try {
        updateStatus('Loading WASM module...');

        const wasmPath = '../zig-out/bin/shooter.wasm';
        const response = await fetch(wasmPath);

        if (!response.ok) {
            throw new Error(`Failed to fetch WASM: ${response.status} ${response.statusText}`);
        }

        const wasmBytes = await response.arrayBuffer();

        // Create WASM instance with minimal imports
        const importObject = {
            env: {
                // Zig may expect these memory management functions
                // but for simple games they might not be needed
            }
        };

        updateStatus('Compiling WASM module...');
        const wasmModule = await WebAssembly.compile(wasmBytes);

        updateStatus('Instantiating WASM module...');
        wasmInstance = await WebAssembly.instantiate(wasmModule, importObject);
        wasmMemory = wasmInstance.exports.memory;

        // Initialize the game
        updateStatus('Initializing game...');
        wasmInstance.exports.init();

        updateStatus('Game ready! Use WASD to move.');

        // Start the game loop
        isRunning = true;
        requestAnimationFrame(gameLoop);

    } catch (error) {
        console.error('Error loading WASM:', error);
        updateStatus(`Error: ${error.message}`, true);
    }
}

// Draw a triangle pointing upward
function drawTriangle(x, y, size, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    // Top point
    ctx.moveTo(x + size / 2, y);
    // Bottom right
    ctx.lineTo(x + size, y + size);
    // Bottom left
    ctx.lineTo(x, y + size);
    ctx.closePath();
    ctx.fill();
}

// Draw a rectangle
function drawRect(x, y, width, height, color) {
    ctx.fillStyle = color;
    ctx.fillRect(x, y, width, height);
}

// Render the game state
function render() {
    if (!wasmInstance) return;

    // Clear canvas with dark background
    ctx.fillStyle = '#0a0a0a';
    ctx.fillRect(0, 0, GAME_WIDTH, GAME_HEIGHT);

    // Draw hallway walls (dark gray on sides)
    const wallWidth = 40;
    ctx.fillStyle = '#1a1a1a';
    ctx.fillRect(0, 0, wallWidth, GAME_HEIGHT); // Left wall
    ctx.fillRect(GAME_WIDTH - wallWidth, 0, wallWidth, GAME_HEIGHT); // Right wall

    // Draw subtle hallway effect with darker edges
    const gradient = ctx.createLinearGradient(0, 0, GAME_WIDTH, 0);
    gradient.addColorStop(0, 'rgba(0, 0, 0, 0.5)');
    gradient.addColorStop(0.1, 'rgba(0, 0, 0, 0)');
    gradient.addColorStop(0.9, 'rgba(0, 0, 0, 0)');
    gradient.addColorStop(1, 'rgba(0, 0, 0, 0.5)');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, GAME_WIDTH, GAME_HEIGHT);

    // Get player data
    const playerX = wasmInstance.exports.get_player_x();
    const playerY = wasmInstance.exports.get_player_y();
    const playerHealth = wasmInstance.exports.get_player_health();
    const score = wasmInstance.exports.get_score();

    // Draw entities (enemies and obstacles)
    const entityCount = wasmInstance.exports.get_entity_count();

    for (let i = 0; i < entityCount; i++) {
        const dataPtr = wasmInstance.exports.get_entity_data(i);

        // Read entity data from WASM memory
        // The buffer contains: [x, y, width, height, type]
        const dataView = new Float32Array(wasmMemory.buffer, dataPtr, 5);
        const ex = dataView[0];
        const ey = dataView[1];
        const ew = dataView[2];
        const eh = dataView[3];
        const type = dataView[4];

        // Draw based on entity type
        if (type === 0) {
            // Enemy - red square
            drawRect(ex, ey, ew, eh, '#ff3333');
            // Add a darker border for enemies
            ctx.strokeStyle = '#aa0000';
            ctx.lineWidth = 2;
            ctx.strokeRect(ex, ey, ew, eh);
        } else if (type === 1) {
            // Obstacle - gray rectangle
            drawRect(ex, ey, ew, eh, '#666666');
            // Add a lighter border for obstacles
            ctx.strokeStyle = '#999999';
            ctx.lineWidth = 2;
            ctx.strokeRect(ex, ey, ew, eh);
        }
    }

    // Draw player as green triangle
    if (playerHealth > 0) {
        drawTriangle(playerX, playerY, PLAYER_SIZE, '#33ff33');
        // Add a darker outline
        ctx.strokeStyle = '#00aa00';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(playerX + PLAYER_SIZE / 2, playerY);
        ctx.lineTo(playerX + PLAYER_SIZE, playerY + PLAYER_SIZE);
        ctx.lineTo(playerX, playerY + PLAYER_SIZE);
        ctx.closePath();
        ctx.stroke();
    } else {
        // Game over
        ctx.fillStyle = 'rgba(255, 0, 0, 0.5)';
        ctx.fillRect(0, 0, GAME_WIDTH, GAME_HEIGHT);

        ctx.fillStyle = '#ffffff';
        ctx.font = 'bold 48px Arial';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('GAME OVER', GAME_WIDTH / 2, GAME_HEIGHT / 2 - 30);

        ctx.font = '24px Arial';
        ctx.fillText(`Final Score: ${score}`, GAME_WIDTH / 2, GAME_HEIGHT / 2 + 20);
        ctx.fillText('Refresh to play again', GAME_WIDTH / 2, GAME_HEIGHT / 2 + 60);
    }

    // Draw HUD (Health and Score)
    ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    ctx.fillRect(10, 10, 200, 80);

    ctx.fillStyle = '#ffffff';
    ctx.font = 'bold 20px Arial';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.fillText(`Health: ${playerHealth}`, 20, 20);
    ctx.fillText(`Score: ${score}`, 20, 50);

    // Health bar
    const healthBarWidth = 180;
    const healthBarHeight = 10;
    const healthBarX = 20;
    const healthBarY = 75;

    // Background
    ctx.fillStyle = '#333333';
    ctx.fillRect(healthBarX, healthBarY, healthBarWidth, healthBarHeight);

    // Health fill
    const healthPercent = Math.max(0, playerHealth) / 100;
    const healthColor = playerHealth > 50 ? '#33ff33' : playerHealth > 25 ? '#ffaa33' : '#ff3333';
    ctx.fillStyle = healthColor;
    ctx.fillRect(healthBarX, healthBarY, healthBarWidth * healthPercent, healthBarHeight);

    // Border
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 1;
    ctx.strokeRect(healthBarX, healthBarY, healthBarWidth, healthBarHeight);
}

// Main game loop
function gameLoop(currentTime) {
    if (!isRunning) return;

    // Calculate delta time in seconds
    const deltaTime = (currentTime - lastFrameTime) / 1000.0;
    lastFrameTime = currentTime;

    // Cap delta time to prevent huge jumps
    const cappedDeltaTime = Math.min(deltaTime, 0.1);

    // Update game logic
    if (wasmInstance) {
        wasmInstance.exports.update(cappedDeltaTime);
    }

    // Render the frame
    render();

    // Continue the loop
    requestAnimationFrame(gameLoop);
}

// Keyboard input handling
document.addEventListener('keydown', (event) => {
    if (!wasmInstance) return;

    // Get the key code
    const keyCode = event.keyCode || event.which;

    // Call WASM key_down function
    wasmInstance.exports.key_down(keyCode);

    // Prevent default behavior for game keys (WASD)
    if ([87, 65, 83, 68].includes(keyCode)) {
        event.preventDefault();
    }
});

document.addEventListener('keyup', (event) => {
    if (!wasmInstance) return;

    // Get the key code
    const keyCode = event.keyCode || event.which;

    // Call WASM key_up function
    wasmInstance.exports.key_up(keyCode);

    // Prevent default behavior for game keys (WASD)
    if ([87, 65, 83, 68].includes(keyCode)) {
        event.preventDefault();
    }
});

// Start loading the WASM module when the page loads
window.addEventListener('load', () => {
    loadWasm();
});
