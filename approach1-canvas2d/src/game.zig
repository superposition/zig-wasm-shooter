const std = @import("std");

// Constants
const PLAYER_SPEED: f32 = 200.0;
const PLAYER_SIZE: f32 = 20.0;
const ENEMY_SPEED: f32 = 100.0;
const ENEMY_SIZE: f32 = 15.0;
const OBSTACLE_SPEED: f32 = 80.0;
const SPAWN_INTERVAL: f32 = 1.5;
const GAME_WIDTH: f32 = 800.0;
const GAME_HEIGHT: f32 = 600.0;
const MAX_ENTITIES: usize = 100;

// Entity types
const EntityType = enum(i32) {
    Enemy = 0,
    Obstacle = 1,
};

// Player structure
const Player = struct {
    x: f32,
    y: f32,
    velocity_x: f32,
    velocity_y: f32,
    health: i32,
    width: f32,
    height: f32,
};

// Enemy structure
const Enemy = struct {
    x: f32,
    y: f32,
    velocity_y: f32,
    width: f32,
    height: f32,
    entity_type: EntityType,
    active: bool,
};

// Obstacle structure
const Obstacle = struct {
    x: f32,
    y: f32,
    velocity_y: f32,
    width: f32,
    height: f32,
    entity_type: EntityType,
    active: bool,
};

// Entity union for easier management
const Entity = union(enum) {
    enemy: Enemy,
    obstacle: Obstacle,

    fn isActive(self: Entity) bool {
        return switch (self) {
            .enemy => |e| e.active,
            .obstacle => |o| o.active,
        };
    }

    fn getX(self: Entity) f32 {
        return switch (self) {
            .enemy => |e| e.x,
            .obstacle => |o| o.x,
        };
    }

    fn getY(self: Entity) f32 {
        return switch (self) {
            .enemy => |e| e.y,
            .obstacle => |o| o.y,
        };
    }

    fn getWidth(self: Entity) f32 {
        return switch (self) {
            .enemy => |e| e.width,
            .obstacle => |o| o.width,
        };
    }

    fn getHeight(self: Entity) f32 {
        return switch (self) {
            .enemy => |e| e.height,
            .obstacle => |o| o.height,
        };
    }

    fn getType(self: Entity) i32 {
        return switch (self) {
            .enemy => |e| @intFromEnum(e.entity_type),
            .obstacle => |o| @intFromEnum(o.entity_type),
        };
    }
};

// Game state
const GameState = struct {
    player: Player,
    entities: [MAX_ENTITIES]Entity,
    entity_count: usize,
    score: i32,
    spawn_timer: f32,
    key_states: [256]bool,
    rng_state: u64,
};

// Global game state
var game_state: GameState = undefined;
var initialized: bool = false;

// Entity data buffer for JS interop (x, y, width, height, type)
var entity_data_buffer: [5]f32 = undefined;

// Simple PRNG (Linear Congruential Generator)
fn random(state: *u64) f32 {
    state.* = state.* *% 1103515245 +% 12345;
    return @as(f32, @floatFromInt((state.* / 65536) % 32768)) / 32768.0;
}

// Initialize game state
export fn init() void {
    game_state = GameState{
        .player = Player{
            .x = GAME_WIDTH / 2.0,
            .y = GAME_HEIGHT - 50.0,
            .velocity_x = 0.0,
            .velocity_y = 0.0,
            .health = 100,
            .width = PLAYER_SIZE,
            .height = PLAYER_SIZE,
        },
        .entities = undefined,
        .entity_count = 0,
        .score = 0,
        .spawn_timer = 0.0,
        .key_states = [_]bool{false} ** 256,
        .rng_state = 12345, // Seed for random number generator
    };

    // Initialize all entities as inactive
    var i: usize = 0;
    while (i < MAX_ENTITIES) : (i += 1) {
        game_state.entities[i] = Entity{
            .enemy = Enemy{
                .x = 0,
                .y = 0,
                .velocity_y = 0,
                .width = 0,
                .height = 0,
                .entity_type = EntityType.Enemy,
                .active = false,
            },
        };
    }

    initialized = true;
}

// Handle key down events
export fn key_down(key: u8) void {
    if (!initialized) return;
    if (key < 256) {
        game_state.key_states[key] = true;
    }
}

// Handle key up events
export fn key_up(key: u8) void {
    if (!initialized) return;
    if (key < 256) {
        game_state.key_states[key] = false;
    }
}

// Check AABB collision
fn checkCollision(x1: f32, y1: f32, w1: f32, h1: f32, x2: f32, y2: f32, w2: f32, h2: f32) bool {
    return x1 < x2 + w2 and
        x1 + w1 > x2 and
        y1 < y2 + h2 and
        y1 + h1 > y2;
}

// Spawn a new entity
fn spawnEntity() void {
    if (game_state.entity_count >= MAX_ENTITIES) return;

    // Find first inactive entity slot
    var i: usize = 0;
    while (i < MAX_ENTITIES) : (i += 1) {
        if (!game_state.entities[i].isActive()) {
            // Randomly choose between enemy and obstacle
            const entity_choice = random(&game_state.rng_state);
            const rand_x = random(&game_state.rng_state) * (GAME_WIDTH - 40.0) + 20.0;

            if (entity_choice < 0.6) {
                // Spawn enemy (60% chance)
                game_state.entities[i] = Entity{
                    .enemy = Enemy{
                        .x = rand_x,
                        .y = -ENEMY_SIZE,
                        .velocity_y = ENEMY_SPEED,
                        .width = ENEMY_SIZE,
                        .height = ENEMY_SIZE,
                        .entity_type = EntityType.Enemy,
                        .active = true,
                    },
                };
            } else {
                // Spawn obstacle (40% chance)
                const obstacle_width = 30.0 + random(&game_state.rng_state) * 40.0;
                game_state.entities[i] = Entity{
                    .obstacle = Obstacle{
                        .x = rand_x,
                        .y = -30.0,
                        .velocity_y = OBSTACLE_SPEED,
                        .width = obstacle_width,
                        .height = 30.0,
                        .entity_type = EntityType.Obstacle,
                        .active = true,
                    },
                };
            }
            game_state.entity_count += 1;
            break;
        }
    }
}

// Update game logic
export fn update(delta_time: f32) void {
    if (!initialized) return;
    if (game_state.player.health <= 0) return;

    // Update player velocity based on key states
    game_state.player.velocity_x = 0.0;
    game_state.player.velocity_y = 0.0;

    // WASD controls
    // W = 87, A = 65, S = 83, D = 68
    // Also support lowercase: w = 119, a = 97, s = 115, d = 100
    if (game_state.key_states[65] or game_state.key_states[97]) { // A or a
        game_state.player.velocity_x = -PLAYER_SPEED;
    }
    if (game_state.key_states[68] or game_state.key_states[100]) { // D or d
        game_state.player.velocity_x = PLAYER_SPEED;
    }
    if (game_state.key_states[87] or game_state.key_states[119]) { // W or w
        game_state.player.velocity_y = -PLAYER_SPEED;
    }
    if (game_state.key_states[83] or game_state.key_states[115]) { // S or s
        game_state.player.velocity_y = PLAYER_SPEED;
    }

    // Update player position
    game_state.player.x += game_state.player.velocity_x * delta_time;
    game_state.player.y += game_state.player.velocity_y * delta_time;

    // Clamp player position to game bounds
    if (game_state.player.x < 0) {
        game_state.player.x = 0;
    }
    if (game_state.player.x + game_state.player.width > GAME_WIDTH) {
        game_state.player.x = GAME_WIDTH - game_state.player.width;
    }
    if (game_state.player.y < 0) {
        game_state.player.y = 0;
    }
    if (game_state.player.y + game_state.player.height > GAME_HEIGHT) {
        game_state.player.y = GAME_HEIGHT - game_state.player.height;
    }

    // Update spawn timer
    game_state.spawn_timer += delta_time;
    if (game_state.spawn_timer >= SPAWN_INTERVAL) {
        game_state.spawn_timer = 0.0;
        spawnEntity();
    }

    // Update entities
    var i: usize = 0;
    while (i < MAX_ENTITIES) : (i += 1) {
        if (!game_state.entities[i].isActive()) continue;

        switch (game_state.entities[i]) {
            .enemy => |*e| {
                e.y += e.velocity_y * delta_time;

                // Check collision with player
                if (checkCollision(
                    game_state.player.x,
                    game_state.player.y,
                    game_state.player.width,
                    game_state.player.height,
                    e.x,
                    e.y,
                    e.width,
                    e.height,
                )) {
                    game_state.player.health -= 10;
                    e.active = false;
                    game_state.entity_count -= 1;
                }

                // Remove if off screen
                if (e.y > GAME_HEIGHT) {
                    e.active = false;
                    game_state.entity_count -= 1;
                }
            },
            .obstacle => |*o| {
                o.y += o.velocity_y * delta_time;

                // Check collision with player
                if (checkCollision(
                    game_state.player.x,
                    game_state.player.y,
                    game_state.player.width,
                    game_state.player.height,
                    o.x,
                    o.y,
                    o.width,
                    o.height,
                )) {
                    game_state.player.health -= 20;
                    o.active = false;
                    game_state.entity_count -= 1;
                }

                // Remove if off screen
                if (o.y > GAME_HEIGHT) {
                    o.active = false;
                    game_state.entity_count -= 1;
                }
            },
        }
    }

    // Increment score (10 points per second survived)
    game_state.score += @as(i32, @intFromFloat(delta_time * 10.0));
}

// Get player X position
export fn get_player_x() f32 {
    if (!initialized) return 0.0;
    return game_state.player.x;
}

// Get player Y position
export fn get_player_y() f32 {
    if (!initialized) return 0.0;
    return game_state.player.y;
}

// Get player health
export fn get_player_health() i32 {
    if (!initialized) return 0;
    return game_state.player.health;
}

// Get current score
export fn get_score() i32 {
    if (!initialized) return 0;
    return game_state.score;
}

// Get number of active entities
export fn get_entity_count() i32 {
    if (!initialized) return 0;
    var count: i32 = 0;
    var i: usize = 0;
    while (i < MAX_ENTITIES) : (i += 1) {
        if (game_state.entities[i].isActive()) {
            count += 1;
        }
    }
    return count;
}

// Get entity data at index (returns pointer to [x, y, width, height, type])
export fn get_entity_data(index: i32) [*]f32 {
    if (!initialized) return &entity_data_buffer;
    if (index < 0) return &entity_data_buffer;

    var current_index: i32 = 0;
    var i: usize = 0;
    while (i < MAX_ENTITIES) : (i += 1) {
        if (game_state.entities[i].isActive()) {
            if (current_index == index) {
                const entity = game_state.entities[i];
                entity_data_buffer[0] = entity.getX();
                entity_data_buffer[1] = entity.getY();
                entity_data_buffer[2] = entity.getWidth();
                entity_data_buffer[3] = entity.getHeight();
                entity_data_buffer[4] = @as(f32, @floatFromInt(entity.getType()));
                return &entity_data_buffer;
            }
            current_index += 1;
        }
    }

    // If index not found, return empty data
    entity_data_buffer = [_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0 };
    return &entity_data_buffer;
}
