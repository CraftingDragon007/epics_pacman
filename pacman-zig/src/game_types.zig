pub const Direction = enum(i32) {
    right = 0,
    left = 1,
    up = 2,
    down = 3,
};

pub const GhostMode = enum(i32) {
    wait = 0,
    scatter = 1,
    chase = 2,
    fright = 3,
    spawn = 4,
};

pub const GhostId = enum { blinky, pinky, inky, clyde };

pub const Delta = struct { x: i32, y: i32 };

pub fn delta(direction: Direction) Delta {
    return switch (direction) {
        .right => .{ .x = 1, .y = 0 }, .left => .{ .x = -1, .y = 0 },
        .up => .{ .x = 0, .y = -1 }, .down => .{ .x = 0, .y = 1 },
    };
}

pub fn opposite(direction: Direction) Direction {
    return switch (direction) { .right => .left, .left => .right, .up => .down, .down => .up };
}

pub fn pvName(id: GhostId) []const u8 {
    return switch (id) { .blinky => "BLINKY", .pinky => "PINKY", .inky => "INKY", .clyde => "CLYDE" };
}
