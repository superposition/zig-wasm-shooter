const std = @import("std");

// WebGPU extern function imports from JavaScript
extern fn gpu_begin_frame() void;
extern fn gpu_end_frame() void;
extern fn gpu_draw_rect(x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32) void;
extern fn gpu_draw_triangle(x1: f32, y1: f32, x2: f32, y2: f32, x3: f32, y3: f32, r: f32, g: f32, b: f32, a: f32) void;

// Game constants
const CANVAS_WIDTH = 800.0;
const CANVAS_HEIGHT = 600.0;
const PLAYER_SIZE = 30.0;
const PLAYER_SPEED = 300.0;
const ENEMY_SIZE = 25.0;
const ENEMY_SPEED = 100.0;
const OBSTACLE_WIDTH = 60.0;
const OBSTACLE_HEIGHT = 80.0;
const OBSTACLE_SPEED = 150.0;
const HALLWAY_WIDTH = 400.0;
const MAX_ENEMIES = 10;
const MAX_OBSTACLES = 5;
const SPAWN_INTERVAL = 2.0;

// Game state
const Vec2 = struct {
    x: f32,
    y: f32,
};

const Player = struct {
    pos: Vec2,
    vel: Vec2,
    size: f32,
};

const Enemy = struct {
    pos: Vec2,
    active: bool,
};

const Obstacle = struct {
    pos: Vec2,
    active: bool,
};

var game_state = struct {
    player: Player = .{
        .pos = .{ .x = CANVAS_WIDTH / 2.0, .y = CANVAS_HEIGHT - 100.0 },
        .vel = .{ .x = 0.0, .y = 0.0 },
        .size = PLAYER_SIZE,
    },
    enemies: [MAX_ENEMIES]Enemy = [_]Enemy{.{ .pos = .{ .x = 0.0, .y = 0.0 }, .active = false }} ** MAX_ENEMIES,
    obstacles: [MAX_OBSTACLES]Obstacle = [_]Obstacle{.{ .pos = .{ .x = 0.0, .y = 0.0 }, .active = false }} ** MAX_OBSTACLES,
    score: i32 = 0,
    spawn_timer: f32 = 0.0,
    keys: [256]bool = [_]bool{false} ** 256,
    initialized: bool = false,
}{};

// Key codes
const KEY_LEFT = 37;
const KEY_RIGHT = 39;
const KEY_UP = 38;
const KEY_DOWN = 40;
const KEY_A = 65;
const KEY_D = 68;
const KEY_W = 87;
const KEY_S = 83;

// Random number generator
var rng_state: u64 = 12345;

fn random() f32 {
    // Simple xorshift RNG
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 7;
    rng_state ^= rng_state << 17;
    return @as(f32, @floatFromInt(rng_state & 0xFFFFFF)) / @as(f32, 0xFFFFFF);
}

// Exported game functions

export fn init() void {
    // Initialize game state
    game_state.player.pos.x = CANVAS_WIDTH / 2.0;
    game_state.player.pos.y = CANVAS_HEIGHT - 100.0;
    game_state.player.vel.x = 0.0;
    game_state.player.vel.y = 0.0;
    game_state.score = 0;
    game_state.spawn_timer = 0.0;

    // Clear all entities
    for (&game_state.enemies) |*enemy| {
        enemy.active = false;
    }
    for (&game_state.obstacles) |*obstacle| {
        obstacle.active = false;
    }

    // Clear keys
    for (&game_state.keys) |*key| {
        key.* = false;
    }

    // Seed RNG with a different value each time
    rng_state = 12345;

    game_state.initialized = true;
}

export fn update(delta_time: f32) void {
    if (!game_state.initialized) {
        init();
    }

    // Update player velocity based on input
    game_state.player.vel.x = 0.0;
    game_state.player.vel.y = 0.0;

    if (game_state.keys[KEY_LEFT] or game_state.keys[KEY_A]) {
        game_state.player.vel.x = -PLAYER_SPEED;
    }
    if (game_state.keys[KEY_RIGHT] or game_state.keys[KEY_D]) {
        game_state.player.vel.x = PLAYER_SPEED;
    }
    if (game_state.keys[KEY_UP] or game_state.keys[KEY_W]) {
        game_state.player.vel.y = -PLAYER_SPEED;
    }
    if (game_state.keys[KEY_DOWN] or game_state.keys[KEY_S]) {
        game_state.player.vel.y = PLAYER_SPEED;
    }

    // Update player position
    game_state.player.pos.x += game_state.player.vel.x * delta_time;
    game_state.player.pos.y += game_state.player.vel.y * delta_time;

    // Constrain player to hallway
    const hallway_left = (CANVAS_WIDTH - HALLWAY_WIDTH) / 2.0;
    const hallway_right = hallway_left + HALLWAY_WIDTH;

    if (game_state.player.pos.x - PLAYER_SIZE / 2.0 < hallway_left) {
        game_state.player.pos.x = hallway_left + PLAYER_SIZE / 2.0;
    }
    if (game_state.player.pos.x + PLAYER_SIZE / 2.0 > hallway_right) {
        game_state.player.pos.x = hallway_right - PLAYER_SIZE / 2.0;
    }
    if (game_state.player.pos.y - PLAYER_SIZE / 2.0 < 0.0) {
        game_state.player.pos.y = PLAYER_SIZE / 2.0;
    }
    if (game_state.player.pos.y + PLAYER_SIZE / 2.0 > CANVAS_HEIGHT) {
        game_state.player.pos.y = CANVAS_HEIGHT - PLAYER_SIZE / 2.0;
    }

    // Update spawn timer
    game_state.spawn_timer += delta_time;
    if (game_state.spawn_timer >= SPAWN_INTERVAL) {
        game_state.spawn_timer = 0.0;
        spawn_entity();
    }

    // Update enemies
    for (&game_state.enemies) |*enemy| {
        if (enemy.active) {
            enemy.pos.y += ENEMY_SPEED * delta_time;

            // Deactivate if off screen
            if (enemy.pos.y > CANVAS_HEIGHT + ENEMY_SIZE) {
                enemy.active = false;
                game_state.score += 1; // Score for dodging
            }

            // Check collision with player
            if (check_collision_circle(
                game_state.player.pos.x,
                game_state.player.pos.y,
                PLAYER_SIZE / 2.0,
                enemy.pos.x,
                enemy.pos.y,
                ENEMY_SIZE / 2.0,
            )) {
                enemy.active = false;
                game_state.score -= 5; // Penalty for collision
            }
        }
    }

    // Update obstacles
    for (&game_state.obstacles) |*obstacle| {
        if (obstacle.active) {
            obstacle.pos.y += OBSTACLE_SPEED * delta_time;

            // Deactivate if off screen
            if (obstacle.pos.y > CANVAS_HEIGHT + OBSTACLE_HEIGHT) {
                obstacle.active = false;
                game_state.score += 2; // Score for dodging obstacle
            }

            // Check collision with player
            if (check_collision_rect(
                game_state.player.pos.x - PLAYER_SIZE / 2.0,
                game_state.player.pos.y - PLAYER_SIZE / 2.0,
                PLAYER_SIZE,
                PLAYER_SIZE,
                obstacle.pos.x,
                obstacle.pos.y,
                OBSTACLE_WIDTH,
                OBSTACLE_HEIGHT,
            )) {
                obstacle.active = false;
                game_state.score -= 10; // Penalty for collision
            }
        }
    }
}

export fn render() void {
    gpu_begin_frame();

    // Draw hallway walls
    const hallway_left = (CANVAS_WIDTH - HALLWAY_WIDTH) / 2.0;
    const hallway_right = hallway_left + HALLWAY_WIDTH;

    // Left wall (dark gray)
    gpu_draw_rect(0.0, 0.0, hallway_left, CANVAS_HEIGHT, 0.2, 0.2, 0.2, 1.0);

    // Right wall (dark gray)
    gpu_draw_rect(hallway_right, 0.0, hallway_left, CANVAS_HEIGHT, 0.2, 0.2, 0.2, 1.0);

    // Hallway floor (lighter gray)
    gpu_draw_rect(hallway_left, 0.0, HALLWAY_WIDTH, CANVAS_HEIGHT, 0.4, 0.4, 0.4, 1.0);

    // Draw center line markers (white dashed line effect)
    const center_x = CANVAS_WIDTH / 2.0;
    var y: f32 = 0.0;
    while (y < CANVAS_HEIGHT) : (y += 40.0) {
        gpu_draw_rect(center_x - 2.0, y, 4.0, 20.0, 1.0, 1.0, 1.0, 1.0);
    }

    // Draw obstacles (rectangles - red)
    for (game_state.obstacles) |obstacle| {
        if (obstacle.active) {
            gpu_draw_rect(
                obstacle.pos.x,
                obstacle.pos.y,
                OBSTACLE_WIDTH,
                OBSTACLE_HEIGHT,
                0.8,
                0.2,
                0.2,
                1.0,
            );
        }
    }

    // Draw enemies (triangles - orange/yellow)
    for (game_state.enemies) |enemy| {
        if (enemy.active) {
            const half_size = ENEMY_SIZE / 2.0;
            // Draw triangle pointing down
            gpu_draw_triangle(
                enemy.pos.x, enemy.pos.y - half_size, // Top
                enemy.pos.x - half_size, enemy.pos.y + half_size, // Bottom left
                enemy.pos.x + half_size, enemy.pos.y + half_size, // Bottom right
                0.9,
                0.6,
                0.1,
                1.0,
            );
        }
    }

    // Draw player (triangle - cyan/blue)
    const px = game_state.player.pos.x;
    const py = game_state.player.pos.y;
    const half_size = PLAYER_SIZE / 2.0;

    // Draw triangle pointing up
    gpu_draw_triangle(
        px, py - half_size, // Top
        px - half_size, py + half_size, // Bottom left
        px + half_size, py + half_size, // Bottom right
        0.2,
        0.7,
        1.0,
        1.0,
    );

    gpu_end_frame();
}

export fn key_down(key: u8) void {
    if (key < 256) {
        game_state.keys[key] = true;
    }
}

export fn key_up(key: u8) void {
    if (key < 256) {
        game_state.keys[key] = false;
    }
}

export fn get_score() i32 {
    return game_state.score;
}

// Helper functions

fn spawn_entity() void {
    const hallway_left = (CANVAS_WIDTH - HALLWAY_WIDTH) / 2.0;
    const hallway_right = hallway_left + HALLWAY_WIDTH;

    // Randomly spawn either enemy or obstacle
    if (random() < 0.6) {
        // Spawn enemy
        for (&game_state.enemies) |*enemy| {
            if (!enemy.active) {
                enemy.active = true;
                enemy.pos.x = hallway_left + random() * (HALLWAY_WIDTH - ENEMY_SIZE);
                enemy.pos.y = -ENEMY_SIZE;
                break;
            }
        }
    } else {
        // Spawn obstacle
        for (&game_state.obstacles) |*obstacle| {
            if (!obstacle.active) {
                obstacle.active = true;
                obstacle.pos.x = hallway_left + random() * (HALLWAY_WIDTH - OBSTACLE_WIDTH);
                obstacle.pos.y = -OBSTACLE_HEIGHT;
                break;
            }
        }
    }
}

fn check_collision_circle(x1: f32, y1: f32, r1: f32, x2: f32, y2: f32, r2: f32) bool {
    const dx = x1 - x2;
    const dy = y1 - y2;
    const dist_sq = dx * dx + dy * dy;
    const r_sum = r1 + r2;
    return dist_sq < r_sum * r_sum;
}

fn check_collision_rect(x1: f32, y1: f32, w1: f32, h1: f32, x2: f32, y2: f32, w2: f32, h2: f32) bool {
    return x1 < x2 + w2 and
        x1 + w1 > x2 and
        y1 < y2 + h2 and
        y1 + h1 > y2;
}
