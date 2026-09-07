const std = @import("std");
const game = @import("game_types.zig");
const grid = @import("grid.zig");
const ai = @import("ghost_ai.zig");
const maze = @import("maze.zig");

const Point = struct { x: i32, y: i32 };

/// The house is deliberately not part of the maze graph: its centre line is
/// between maze columns. These phases keep the legacy pixel animation safe,
/// while `navigating` and `frightened` only use real path tiles.
pub const Phase = enum {
    waiting_in_house,
    leaving_to_center,
    leaving_to_exit,
    aligning_to_grid,
    navigating,
    frightened,
    returning_to_entry,
    returning_to_center,
    returning_to_spawn,
};

pub const Ghost = struct {
    id: game.GhostId,
    direction: game.Direction = .up,
    phase: Phase = .waiting_in_house,
    next_tile: ?grid.Tile = null,
    waiting_for_second_spawn: bool = true,
    next_move_ms: i64 = 0,
    frame: i32 = 0,
    next_frame_ms: i64 = 0,
    random_seed: u32,

    const exit_point = Point{ .x = 423, .y = 343 };
    const maze_exit_tile = grid.Tile{ .x = 14, .y = 11 };
    // The tile immediately above the door is the last ordinary path tile.
    // From there, the returning-house phases take over through the door.
    const return_entry_tile = grid.Tile{ .x = 14, .y = 11 };

    pub fn init(id: game.GhostId) Ghost {
        return .{ .id = id, .random_seed = @as(u32, @intFromEnum(id)) + 1 };
    }

    fn suffix(self: Ghost, buffer: *[48]u8, field: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "GHOSTS_{s}_{s}", .{ game.pvName(self.id), field });
    }

    fn spawnPoint(self: Ghost, second: bool) Point {
        return switch (self.id) {
            .blinky => .{ .x = 423, .y = 345 },
            .pinky => .{ .x = 423, .y = if (second) 455 else 415 },
            .inky => .{ .x = 359, .y = if (second) 455 else 415 },
            .clyde => .{ .x = 487, .y = if (second) 455 else 415 },
        };
    }

    fn modeDelay(pv: anytype, allocator: std.mem.Allocator, mode: game.GhostMode) !i64 {
        const seconds = switch (mode) {
            .scatter, .wait => try pv.getDouble(allocator, "GHOSTS_COMMON_SCATTER_DELAY"),
            .chase => try pv.getDouble(allocator, "GHOSTS_COMMON_CHASE_DELAY"),
            .fright => try pv.getDouble(allocator, "GHOSTS_COMMON_FRIGHT_DELAY"),
            .spawn => try pv.getDouble(allocator, "GHOSTS_COMMON_SPAWN_DELAY"),
        };
        return @as(i64, @intFromFloat(@max(seconds, 0.001) * 1000));
    }

    fn moveOne(current: i32, target: i32) i32 {
        return if (current < target) current + 1 else if (current > target) current - 1 else current;
    }

    fn tilePoint(tile: grid.Tile) Point {
        const pixel = grid.tileToPixel(tile);
        return .{ .x = pixel.x, .y = pixel.y };
    }

    /// The left portal's nominal top-left coordinate is -9, but the legacy
    /// EPICS X record has DRVL=0 and clamps it at the visible edge.  Detect
    /// that clamped coordinate rather than waiting for an unreachable -9.
    fn portalWarp(tile: grid.Tile, position: Point, direction: game.Direction) ?Point {
        if (!maze.isPortal(tile.x, tile.y)) return null;
        if (tile.x == 0 and direction == .left and position.x <= 0) {
            return tilePoint(.{ .x = grid.width - 1, .y = tile.y });
        }
        const right = tilePoint(.{ .x = grid.width - 1, .y = tile.y });
        if (tile.x == grid.width - 1 and direction == .right and position.x >= right.x) {
            return .{ .x = 0, .y = right.y };
        }
        return null;
    }

    fn directionTo(from: Point, target: Point, fallback: game.Direction) game.Direction {
        if (from.x < target.x) return .right;
        if (from.x > target.x) return .left;
        if (from.y < target.y) return .down;
        if (from.y > target.y) return .up;
        return fallback;
    }

    fn moveTowards(self: *Ghost, x: *i32, y: *i32, target: Point) bool {
        self.direction = directionTo(.{ .x = x.*, .y = y.* }, target, self.direction);
        x.* = moveOne(x.*, target.x);
        y.* = moveOne(y.*, target.y);
        return x.* == target.x and y.* == target.y;
    }

    fn writePosition(self: *Ghost, pv: anytype, allocator: std.mem.Allocator, x: i32, y: i32) !void {
        var buf: [48]u8 = undefined;
        try pv.putLong(allocator, try self.suffix(&buf, "X"), x);
        try pv.putLong(allocator, try self.suffix(&buf, "Y"), y);
        try pv.putLong(allocator, try self.suffix(&buf, "DIR"), @intFromEnum(self.direction));
    }

    fn animate(self: *Ghost, pv: anytype, allocator: std.mem.Allocator, now_ms: i64) !void {
        if (now_ms < self.next_frame_ms) return;
        const frame_delay = try pv.getDouble(allocator, "GHOSTS_COMMON_ANIMATION_DELAY");
        self.next_frame_ms = now_ms + @as(i64, @intFromFloat(@max(frame_delay, 0.001) * 1000));
        self.frame = @mod(self.frame + 1, 2);
        var buf: [48]u8 = undefined;
        try pv.putLong(allocator, try self.suffix(&buf, "FRAME"), @intFromEnum(self.direction) * 2 + self.frame);
    }

    fn normalPhase(mode: game.GhostMode) Phase {
        return switch (mode) {
            .fright => .frightened,
            .spawn => .returning_to_entry,
            .wait => .waiting_in_house,
            .scatter, .chase => .navigating,
        };
    }

    fn beginReturning(self: *Ghost) void {
        self.phase = .returning_to_entry;
        self.next_tile = null;
    }

    fn navigationTarget(self: Ghost, pv: anytype, allocator: std.mem.Allocator, mode: game.GhostMode, current: grid.Tile) !grid.Tile {
        if (mode == .spawn) return return_entry_tile;
        const pacman_x = try pv.getLong(allocator, "PACMAN_USER_X");
        const pacman_y = try pv.getLong(allocator, "PACMAN_USER_Y");
        const pacman_dir_raw = try pv.getLong(allocator, "PACMAN_USER_DIRECTION");
        const pacman_dir: game.Direction = if (pacman_dir_raw >= 0 and pacman_dir_raw <= 3) @enumFromInt(pacman_dir_raw) else .left;
        const pacman = grid.pixelToTile(pacman_x, pacman_y);
        const blinky_x = try pv.getLong(allocator, "GHOSTS_BLINKY_X");
        const blinky_y = try pv.getLong(allocator, "GHOSTS_BLINKY_Y");
        const blinky = grid.pixelToTile(blinky_x, blinky_y);
        return switch (mode) {
            .scatter => ai.scatterTarget(self.id),
            .chase => ai.chaseTarget(self.id, pacman, pacman_dir, blinky, current),
            .fright => ai.scatterTarget(self.id),
            .spawn => unreachable,
            .wait => unreachable,
        };
    }

    fn tickNavigation(self: *Ghost, pv: anytype, allocator: std.mem.Allocator, mode: game.GhostMode, x: *i32, y: *i32) !void {
        var current = grid.pixelToTile(x.*, y.*);
        // `neighbor` represents the tunnel as an edge from one portal tile
        // to the other.  That is correct for path choice but not for pixel
        // movement: moving from x=0 toward x=27 would cut across the board.
        // Warp at the reached portal, then choose the next tile from there.
        if (self.next_tile != null) {
            if (portalWarp(current, .{ .x = x.*, .y = y.* }, self.direction)) |opposite| {
                x.* = opposite.x;
                y.* = opposite.y;
                current = grid.pixelToTile(x.*, y.*);
                self.next_tile = null;
            }
        }
        if (self.phase == .returning_to_entry and current.x == return_entry_tile.x and current.y == return_entry_tile.y and grid.centerDistance(x.*, y.*, return_entry_tile) == 0) {
            self.phase = .returning_to_center;
            self.next_tile = null;
            return;
        }
        if (self.next_tile == null or grid.centerDistance(x.*, y.*, self.next_tile.?) <= 1) {
            const target = try self.navigationTarget(pv, allocator, mode, current);
            // Frightened ghosts reverse once when entering the phase, then
            // continue with the usual no-reversal constraint while choosing
            // random legal turns. Returning ghosts may reverse to find the
            // fixed route back to the door.
            const allow_reverse = self.phase == .returning_to_entry;
            self.direction = ai.chooseDirection(current, self.direction, target, allow_reverse, self.phase == .frightened, &self.random_seed);
            self.next_tile = grid.neighbor(current, self.direction);
            const aligned = grid.tileToPixel(current);
            x.* = aligned.x;
            y.* = aligned.y;
        }
        const target_pixel = tilePoint(self.next_tile.?);
        _ = self.moveTowards(x, y, target_pixel);
    }

    pub fn tick(self: *Ghost, pv: anytype, allocator: std.mem.Allocator, now_ms: i64) !void {
        var buf: [48]u8 = undefined;
        const mode: game.GhostMode = @enumFromInt(try pv.getLong(allocator, try self.suffix(&buf, "MODE")));
        if (now_ms < self.next_move_ms) return;
        self.next_move_ms = now_ms + try modeDelay(pv, allocator, mode);

        var x = try pv.getLong(allocator, try self.suffix(&buf, "X"));
        var y = try pv.getLong(allocator, try self.suffix(&buf, "Y"));
        var moved = false;
        switch (self.phase) {
            .waiting_in_house => if (mode != .wait) {
                self.phase = .leaving_to_center;
            } else {
                if (self.moveTowards(&x, &y, self.spawnPoint(self.waiting_for_second_spawn))) self.waiting_for_second_spawn = !self.waiting_for_second_spawn;
                moved = true;
            },
            .leaving_to_center => {
                if (self.moveTowards(&x, &y, .{ .x = exit_point.x, .y = y })) self.phase = .leaving_to_exit;
                moved = true;
            },
            .leaving_to_exit => {
                if (self.moveTowards(&x, &y, exit_point)) self.phase = .aligning_to_grid;
                moved = true;
            },
            .aligning_to_grid => {
                if (self.moveTowards(&x, &y, tilePoint(maze_exit_tile))) {
                    self.phase = normalPhase(mode);
                    self.next_tile = null;
                }
                moved = true;
            },
            .navigating => {
                if (mode == .wait) {} else if (mode == .spawn) self.beginReturning() else if (mode == .fright) {
                    self.phase = .frightened;
                    self.direction = game.opposite(self.direction);
                    self.next_tile = null;
                } else try self.tickNavigation(pv, allocator, mode, &x, &y);
                moved = true;
            },
            .frightened => {
                if (mode == .wait) {} else if (mode == .spawn) self.beginReturning() else if (mode != .fright) {
                    self.phase = .navigating;
                    self.next_tile = null;
                } else try self.tickNavigation(pv, allocator, mode, &x, &y);
                moved = true;
            },
            .returning_to_entry => {
                try self.tickNavigation(pv, allocator, .spawn, &x, &y);
                moved = true;
            },
            .returning_to_center => {
                const entry = grid.tileToPixel(return_entry_tile);
                if (self.moveTowards(&x, &y, .{ .x = exit_point.x, .y = entry.y })) self.phase = .returning_to_spawn;
                moved = true;
            },
            .returning_to_spawn => {
                if (self.moveTowards(&x, &y, self.spawnPoint(false))) {
                    self.phase = .waiting_in_house;
                    self.waiting_for_second_spawn = true;
                    self.next_tile = null;
                    try pv.putLong(allocator, try self.suffix(&buf, "MODE"), @intFromEnum(game.GhostMode.wait));
                }
                moved = true;
            },
        }
        if (moved) {
            try self.writePosition(pv, allocator, x, y);
            try self.animate(pv, allocator, now_ms);
        }
    }
};

test "house routes preserve legacy spawn positions and enter a path tile" {
    const blinky = Ghost.init(.blinky);
    try std.testing.expectEqual(Point{ .x = 423, .y = 345 }, blinky.spawnPoint(false));
    try std.testing.expectEqual(Point{ .x = 359, .y = 455 }, Ghost.init(.inky).spawnPoint(true));
    try std.testing.expect(grid.walkable(Ghost.maze_exit_tile));
    try std.testing.expect(grid.walkable(Ghost.return_entry_tile));
}

test "tunnel transition warps instead of crossing the maze" {
    const left = grid.Tile{ .x = 0, .y = 14 };
    const right = Ghost.tilePoint(.{ .x = grid.width - 1, .y = 14 });
    try std.testing.expectEqual(right, Ghost.portalWarp(left, .{ .x = 0, .y = 439 }, .left).?);
    try std.testing.expectEqual(Point{ .x = 0, .y = 439 }, Ghost.portalWarp(.{ .x = grid.width - 1, .y = 14 }, right, .right).?);
}
