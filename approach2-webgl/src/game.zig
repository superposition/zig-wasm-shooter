// WebGL extern function imports - these will be provided by JavaScript
extern fn gl_clear(r: f32, g: f32, b: f32, a: f32) void;
extern fn gl_draw_quad(x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32) void;
extern fn gl_draw_triangle(x1: f32, y1: f32, x2: f32, y2: f32, x3: f32, y3: f32, r: f32, g: f32, b: f32, a: f32) void;

// Game constants
const CANVAS_WIDTH: f32 = 800.0;
const CANVAS_HEIGHT: f32 = 600.0;
const PLAYER_WIDTH: f32 = 30.0;
const PLAYER_HEIGHT: f32 = 30.0;
const ENEMY_SIZE: f32 = 25.0;
const OBSTACLE_WIDTH: f32 = 40.0;
const OBSTACLE_HEIGHT: f32 = 60.0;
const HALLWAY_WIDTH: f32 = 300.0;
const PLAYER_SPEED: f32 = 200.0;
const ENEMY_SPEED: f32 = 150.0;
const OBSTACLE_SPEED: f32 = 100.0;
const SPAWN_INTERVAL: f32 = 2.0; // seconds

// Game structures
const Vec2 = struct {
    x: f32,
    y: f32,
};

const Player = struct {
    pos: Vec2,
    velocity: Vec2,
    alive: bool,
};

const Enemy = struct {
    pos: Vec2,
    active: bool,
};

const Obstacle = struct {
    pos: Vec2,
    active: bool,
};

// Game state
const MAX_ENEMIES = 10;
const MAX_OBSTACLES = 8;

var player: Player = undefined;
var enemies: [MAX_ENEMIES]Enemy = undefined;
var obstacles: [MAX_OBSTACLES]Obstacle = undefined;
var score: i32 = 0;
var spawn_timer: f32 = 0.0;
var game_time: f32 = 0.0;

// Input state
var key_left: bool = false;
var key_right: bool = false;
var key_up_pressed: bool = false;
var key_down_pressed: bool = false;

// Initialize the game
export fn init() void {
    // Initialize player
    player = Player{
        .pos = Vec2{
            .x = CANVAS_WIDTH / 2.0,
            .y = CANVAS_HEIGHT - 80.0,
        },
        .velocity = Vec2{ .x = 0.0, .y = 0.0 },
        .alive = true,
    };

    // Initialize enemies
    for (&enemies) |*enemy| {
        enemy.* = Enemy{
            .pos = Vec2{ .x = 0.0, .y = 0.0 },
            .active = false,
        };
    }

    // Initialize obstacles
    for (&obstacles) |*obstacle| {
        obstacle.* = Obstacle{
            .pos = Vec2{ .x = 0.0, .y = 0.0 },
            .active = false,
        };
    }

    score = 0;
    spawn_timer = 0.0;
    game_time = 0.0;
    key_left = false;
    key_right = false;
    key_up_pressed = false;
    key_down_pressed = false;
}

// Update game logic
export fn update(delta_time: f32) void {
    if (!player.alive) {
        return;
    }

    game_time += delta_time;
    spawn_timer += delta_time;

    // Update player velocity based on input
    player.velocity.x = 0.0;
    player.velocity.y = 0.0;

    if (key_left) {
        player.velocity.x = -PLAYER_SPEED;
    }
    if (key_right) {
        player.velocity.x = PLAYER_SPEED;
    }
    if (key_up_pressed) {
        player.velocity.y = -PLAYER_SPEED;
    }
    if (key_down_pressed) {
        player.velocity.y = PLAYER_SPEED;
    }

    // Update player position
    player.pos.x += player.velocity.x * delta_time;
    player.pos.y += player.velocity.y * delta_time;

    // Constrain player to hallway
    const hallway_left = (CANVAS_WIDTH - HALLWAY_WIDTH) / 2.0;
    const hallway_right = hallway_left + HALLWAY_WIDTH;

    if (player.pos.x < hallway_left) {
        player.pos.x = hallway_left;
    }
    if (player.pos.x + PLAYER_WIDTH > hallway_right) {
        player.pos.x = hallway_right - PLAYER_WIDTH;
    }
    if (player.pos.y < 0.0) {
        player.pos.y = 0.0;
    }
    if (player.pos.y + PLAYER_HEIGHT > CANVAS_HEIGHT) {
        player.pos.y = CANVAS_HEIGHT - PLAYER_HEIGHT;
    }

    // Spawn enemies and obstacles
    if (spawn_timer >= SPAWN_INTERVAL) {
        spawn_timer = 0.0;
        spawnEnemy();
        if (@mod(@as(i32, @intFromFloat(game_time)), 3) == 0) {
            spawnObstacle();
        }
    }

    // Update enemies
    for (&enemies) |*enemy| {
        if (!enemy.active) continue;

        enemy.pos.y += ENEMY_SPEED * delta_time;

        // Deactivate if off screen
        if (enemy.pos.y > CANVAS_HEIGHT) {
            enemy.active = false;
            score += 1; // Player survived this enemy
        }

        // Check collision with player
        if (checkCollision(
            player.pos.x,
            player.pos.y,
            PLAYER_WIDTH,
            PLAYER_HEIGHT,
            enemy.pos.x,
            enemy.pos.y,
            ENEMY_SIZE,
            ENEMY_SIZE,
        )) {
            player.alive = false;
        }
    }

    // Update obstacles
    for (&obstacles) |*obstacle| {
        if (!obstacle.active) continue;

        obstacle.pos.y += OBSTACLE_SPEED * delta_time;

        // Deactivate if off screen
        if (obstacle.pos.y > CANVAS_HEIGHT) {
            obstacle.active = false;
            score += 1; // Player survived this obstacle
        }

        // Check collision with player
        if (checkCollision(
            player.pos.x,
            player.pos.y,
            PLAYER_WIDTH,
            PLAYER_HEIGHT,
            obstacle.pos.x,
            obstacle.pos.y,
            OBSTACLE_WIDTH,
            OBSTACLE_HEIGHT,
        )) {
            player.alive = false;
        }
    }
}

// Render the game using WebGL
export fn render() void {
    // Clear screen with dark blue background
    gl_clear(0.1, 0.1, 0.2, 1.0);

    // Calculate hallway bounds
    const hallway_left = (CANVAS_WIDTH - HALLWAY_WIDTH) / 2.0;
    const hallway_right = hallway_left + HALLWAY_WIDTH;

    // Draw left wall (dark gray)
    gl_draw_quad(0.0, 0.0, hallway_left, CANVAS_HEIGHT, 0.2, 0.2, 0.2, 1.0);

    // Draw right wall (dark gray)
    gl_draw_quad(hallway_right, 0.0, CANVAS_WIDTH - hallway_right, CANVAS_HEIGHT, 0.2, 0.2, 0.2, 1.0);

    // Draw hallway floor/background (lighter gray)
    gl_draw_quad(hallway_left, 0.0, HALLWAY_WIDTH, CANVAS_HEIGHT, 0.3, 0.3, 0.35, 1.0);

    // Draw obstacles (gray)
    for (obstacles) |obstacle| {
        if (!obstacle.active) continue;
        gl_draw_quad(
            obstacle.pos.x,
            obstacle.pos.y,
            OBSTACLE_WIDTH,
            OBSTACLE_HEIGHT,
            0.5,
            0.5,
            0.5,
            1.0,
        );
    }

    // Draw enemies (red)
    for (enemies) |enemy| {
        if (!enemy.active) continue;
        gl_draw_quad(
            enemy.pos.x,
            enemy.pos.y,
            ENEMY_SIZE,
            ENEMY_SIZE,
            1.0,
            0.0,
            0.0,
            1.0,
        );
    }

    // Draw player
    if (player.alive) {
        // Draw as green triangle (pointing up)
        const center_x = player.pos.x + PLAYER_WIDTH / 2.0;
        const top_y = player.pos.y;
        const bottom_y = player.pos.y + PLAYER_HEIGHT;
        const left_x = player.pos.x;
        const right_x = player.pos.x + PLAYER_WIDTH;

        gl_draw_triangle(
            center_x,
            top_y, // top point
            left_x,
            bottom_y, // bottom left
            right_x,
            bottom_y, // bottom right
            0.0,
            1.0,
            0.0,
            1.0,
        );
    } else {
        // Draw as red X (two triangles) to indicate game over
        const center_x = player.pos.x + PLAYER_WIDTH / 2.0;
        const center_y = player.pos.y + PLAYER_HEIGHT / 2.0;
        const half_size = PLAYER_WIDTH / 2.0;

        // First diagonal
        gl_draw_triangle(
            center_x - half_size,
            center_y - half_size,
            center_x + half_size,
            center_y + half_size,
            center_x,
            center_y,
            1.0,
            0.0,
            0.0,
            1.0,
        );
    }
}

// Handle key down events
export fn key_down(key: u8) void {
    switch (key) {
        37, 65 => key_left = true, // Left arrow or 'A'
        39, 68 => key_right = true, // Right arrow or 'D'
        38, 87 => key_up_pressed = true, // Up arrow or 'W'
        40, 83 => key_down_pressed = true, // Down arrow or 'S'
        else => {},
    }
}

// Handle key up events
export fn key_up(key: u8) void {
    switch (key) {
        37, 65 => key_left = false, // Left arrow or 'A'
        39, 68 => key_right = false, // Right arrow or 'D'
        38, 87 => key_up_pressed = false, // Up arrow or 'W'
        40, 83 => key_down_pressed = false, // Down arrow or 'S'
        else => {},
    }
}

// Get current score
export fn get_score() i32 {
    return score;
}

// Get player alive status
export fn is_alive() bool {
    return player.alive;
}

// Helper function to spawn an enemy
fn spawnEnemy() void {
    for (&enemies) |*enemy| {
        if (!enemy.active) {
            const hallway_left = (CANVAS_WIDTH - HALLWAY_WIDTH) / 2.0;
            const hallway_right = hallway_left + HALLWAY_WIDTH - ENEMY_SIZE;

            // Simple pseudo-random position based on game time
            const rand_val = @mod(@as(i32, @intFromFloat(game_time * 1000.0)), 100);
            const x_pos = hallway_left + (@as(f32, @floatFromInt(rand_val)) / 100.0) * (hallway_right - hallway_left);

            enemy.* = Enemy{
                .pos = Vec2{ .x = x_pos, .y = -ENEMY_SIZE },
                .active = true,
            };
            break;
        }
    }
}

// Helper function to spawn an obstacle
fn spawnObstacle() void {
    for (&obstacles) |*obstacle| {
        if (!obstacle.active) {
            const hallway_left = (CANVAS_WIDTH - HALLWAY_WIDTH) / 2.0;
            const hallway_right = hallway_left + HALLWAY_WIDTH - OBSTACLE_WIDTH;

            // Simple pseudo-random position based on game time
            const rand_val = @mod(@as(i32, @intFromFloat(game_time * 731.0)), 100);
            const x_pos = hallway_left + (@as(f32, @floatFromInt(rand_val)) / 100.0) * (hallway_right - hallway_left);

            obstacle.* = Obstacle{
                .pos = Vec2{ .x = x_pos, .y = -OBSTACLE_HEIGHT },
                .active = true,
            };
            break;
        }
    }
}

// Helper function to check collision between two rectangles
fn checkCollision(x1: f32, y1: f32, w1: f32, h1: f32, x2: f32, y2: f32, w2: f32, h2: f32) bool {
    return x1 < x2 + w2 and
        x1 + w1 > x2 and
        y1 < y2 + h2 and
        y1 + h1 > y2;
}
