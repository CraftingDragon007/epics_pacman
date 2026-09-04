const game = @import("game_types.zig");
const grid = @import("grid.zig");

pub const Target = grid.Tile;

pub fn scatterTarget(id: game.GhostId) Target {
    return switch (id) {
        .blinky => .{ .x = 26, .y = 1 }, .pinky => .{ .x = 1, .y = 1 },
        .inky => .{ .x = 26, .y = 29 }, .clyde => .{ .x = 1, .y = 29 },
    };
}

pub fn chaseTarget(id: game.GhostId, pacman: grid.Tile, pacman_direction: game.Direction, blinky: grid.Tile, self_tile: grid.Tile) Target {
    const step = game.delta(pacman_direction);
    return switch (id) {
        .blinky => pacman,
        .pinky => grid.clamp(.{ .x = pacman.x + step.x * 4, .y = pacman.y + step.y * 4 }),
        .inky => blk: {
            const pivot = grid.clamp(.{ .x = pacman.x + step.x * 2, .y = pacman.y + step.y * 2 });
            break :blk grid.clamp(.{ .x = pivot.x * 2 - blinky.x, .y = pivot.y * 2 - blinky.y });
        },
        .clyde => if (distanceSquared(self_tile, pacman) >= 64) pacman else scatterTarget(.clyde),
    };
}

pub fn distanceSquared(a: grid.Tile, b: grid.Tile) i32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return dx * dx + dy * dy;
}

pub fn chooseDirection(current: grid.Tile, current_direction: game.Direction, target: Target, allow_reverse: bool, frightened: bool, seed: *u32) game.Direction {
    const order = [_]game.Direction{ .up, .left, .down, .right };
    var legal: [4]game.Direction = undefined;
    var legal_count: usize = 0;
    for (order) |candidate| {
        if (!allow_reverse and candidate == game.opposite(current_direction)) continue;
        if (grid.walkable(grid.neighbor(current, candidate))) {
            legal[legal_count] = candidate;
            legal_count += 1;
        }
    }
    // A dead end is the sole normal exception to the no-reversal rule.
    if (legal_count == 0 and grid.walkable(grid.neighbor(current, game.opposite(current_direction)))) {
        return game.opposite(current_direction);
    }
    if (legal_count == 0) return current_direction;
    if (frightened) {
        seed.* = seed.* *% 1664525 +% 1013904223;
        return legal[seed.* % legal_count];
    }
    var best = legal[0];
    var best_distance: i32 = std.math.maxInt(i32);
    for (legal[0..legal_count]) |candidate| {
        const distance = distanceSquared(grid.neighbor(current, candidate), target);
        if (distance < best_distance) { best = candidate; best_distance = distance; }
    }
    return best;
}

const std = @import("std");

test "classic personalities choose distinct targets" {
    const pac = grid.Tile{ .x = 10, .y = 10 };
    try std.testing.expectEqual(grid.Tile{ .x = 14, .y = 10 }, chaseTarget(.pinky, pac, .right, .{ .x = 5, .y = 5 }, .{ .x = 1, .y = 1 }));
    try std.testing.expectEqual(scatterTarget(.clyde), chaseTarget(.clyde, pac, .right, .{ .x = 5, .y = 5 }, .{ .x = 9, .y = 9 }));
}
