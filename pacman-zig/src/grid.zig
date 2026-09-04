const maze = @import("maze.zig");
const game = @import("game_types.zig");

pub const width = maze.width;
pub const height = maze.height;
pub const tile_size: i32 = 32;
pub const sprite_half: i32 = 25;
pub const Tile = struct { x: i32, y: i32 };

pub fn pixelToTile(x: i32, y: i32) Tile {
    return .{ .x = @divTrunc(x + sprite_half, tile_size), .y = @divTrunc(y + sprite_half, tile_size) };
}

pub fn tileToPixel(tile: Tile) struct { x: i32, y: i32 } {
    return .{ .x = tile.x * tile_size + tile_size / 2 - sprite_half, .y = tile.y * tile_size + tile_size / 2 - sprite_half };
}

pub fn centerDistance(x: i32, y: i32, tile: Tile) i32 {
    const target = tileToPixel(tile);
    const dx = if (x > target.x) x - target.x else target.x - x;
    const dy = if (y > target.y) y - target.y else target.y - y;
    return dx + dy;
}

/// Ordinary maze navigation must not enter the ghost house. The house door
/// and interior have separate pixel-waypoint movement in ghost.zig.
pub fn walkable(tile: Tile) bool {
    if (tile.x < 0 or tile.x >= width or tile.y < 0 or tile.y >= height) return false;
    const value = maze.cells[maze.index(tile.x, tile.y)];
    return value == 0 or maze.isPortal(tile.x, tile.y);
}

pub fn neighbor(tile: Tile, direction: game.Direction) Tile {
    const step = game.delta(direction);
    var result = Tile{ .x = tile.x + step.x, .y = tile.y + step.y };
    if (tile.y == 14 and direction == .left and tile.x == 0) result.x = width - 1;
    if (tile.y == 14 and direction == .right and tile.x == width - 1) result.x = 0;
    return result;
}

pub fn clamp(tile: Tile) Tile {
    return .{ .x = @max(@as(i32, 0), @min(width - 1, tile.x)), .y = @max(@as(i32, 0), @min(height - 1, tile.y)) };
}

const std = @import("std");

test "tunnel wraps and ordinary ghost navigation excludes the house" {
    try std.testing.expectEqual(Tile{ .x = width - 1, .y = 14 }, neighbor(.{ .x = 0, .y = 14 }, .left));
    try std.testing.expect(!walkable(.{ .x = 14, .y = 12 }));
    try std.testing.expect(walkable(.{ .x = 14, .y = 11 }));
}
