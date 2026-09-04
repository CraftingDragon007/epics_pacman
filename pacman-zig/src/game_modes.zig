const game = @import("game_types.zig");

pub const Controller = struct {
    started: bool = false,
    started_at_ms: i64 = 0,
    phase_started_at_ms: i64 = 0,
    scattering: bool = true,
    frightened_until_ms: i64 = 0,

    pub fn init(self: *Controller, pv: anytype, allocator: std.mem.Allocator) !void {
        _ = self;
        const labels = [_]game.GhostId{ .blinky, .pinky, .inky, .clyde };
        const spawn = [_]struct { x0: i32, y0: i32, x1: i32, y1: i32 }{
            .{ .x0 = 423, .y0 = 345, .x1 = 423, .y1 = 345 },
            .{ .x0 = 423, .y0 = 415, .x1 = 423, .y1 = 465 },
            .{ .x0 = 359, .y0 = 415, .x1 = 359, .y1 = 465 },
            .{ .x0 = 487, .y0 = 415, .x1 = 487, .y1 = 465 },
        };
        for (labels, spawn) |id, position| {
            var name: [48]u8 = undefined;
            const x_name = try std.fmt.bufPrint(&name, "GHOSTS_{s}_X", .{game.pvName(id)});
            try pv.putLong(allocator, x_name, position.x0);
            const y_name = try std.fmt.bufPrint(&name, "GHOSTS_{s}_Y", .{game.pvName(id)});
            try pv.putLong(allocator, y_name, position.y0);
            const spawn_x0 = try std.fmt.bufPrint(&name, "GHOSTS_{s}_SPAWN_X0", .{game.pvName(id)});
            try pv.putLong(allocator, spawn_x0, position.x0);
            const spawn_y0 = try std.fmt.bufPrint(&name, "GHOSTS_{s}_SPAWN_Y0", .{game.pvName(id)});
            try pv.putLong(allocator, spawn_y0, position.y0);
            const spawn_x1 = try std.fmt.bufPrint(&name, "GHOSTS_{s}_SPAWN_X1", .{game.pvName(id)});
            try pv.putLong(allocator, spawn_x1, position.x1);
            const spawn_y1 = try std.fmt.bufPrint(&name, "GHOSTS_{s}_SPAWN_Y1", .{game.pvName(id)});
            try pv.putLong(allocator, spawn_y1, position.y1);
            const mode_name = try std.fmt.bufPrint(&name, "GHOSTS_{s}_MODE", .{game.pvName(id)});
            try pv.putLong(allocator, mode_name, @intFromEnum(game.GhostMode.wait));
        }
        try pv.putLong(allocator, "GAME_GHOSTS_RUNNING", 1);
        try pv.putString(allocator, "SS_GHOST_MODES", "SCATTER");
    }

    fn releaseDelay(id: game.GhostId) i64 {
        return switch (id) { .blinky => 0, .pinky => 3_000, .inky => 8_000, .clyde => 13_000 };
    }

    fn setMode(pv: anytype, allocator: std.mem.Allocator, id: game.GhostId, mode: game.GhostMode) !void {
        var name: [48]u8 = undefined;
        const field = try std.fmt.bufPrint(&name, "GHOSTS_{s}_MODE", .{game.pvName(id)});
        try pv.putLong(allocator, field, @intFromEnum(mode));
    }

    pub fn tick(self: *Controller, pv: anytype, allocator: std.mem.Allocator, now_ms: i64) !void {
        if (!self.started) {
            if (try pv.getLong(allocator, "PACMAN_USER_DIRECTION") < 0) return;
            self.started = true;
            self.started_at_ms = now_ms;
            self.phase_started_at_ms = now_ms;
        }
        const elapsed = now_ms - self.started_at_ms;
        const fright_input = try pv.getLong(allocator, "GAME_FRIGHT_MODE");
        if (fright_input != 0 and self.frightened_until_ms <= now_ms) self.frightened_until_ms = now_ms + 6_000;
        const frightened = now_ms < self.frightened_until_ms;
        if (!frightened and fright_input != 0) try pv.putLong(allocator, "GAME_FRIGHT_MODE", 0);

        const phase_duration: i64 = if (self.scattering) 7_000 else 20_000;
        if (!frightened and now_ms - self.phase_started_at_ms >= phase_duration) {
            self.scattering = !self.scattering;
            self.phase_started_at_ms = now_ms;
        }
        const normal_mode: game.GhostMode = if (self.scattering) .scatter else .chase;
        const ghosts = [_]game.GhostId{ .blinky, .pinky, .inky, .clyde };
        for (ghosts) |id| {
            if (elapsed < releaseDelay(id)) continue;
            // No ghost-eaten event exists yet, so MODE_SPAWN is never a
            // valid externally sustained state.  Reasserting the controller
            // mode prevents a stale/UI-written value from trapping a ghost
            // in the return-to-house animation.
            try setMode(pv, allocator, id, if (frightened) .fright else normal_mode);
        }
        try pv.putString(allocator, "SS_GHOST_MODES", if (frightened) "FRIGHTENED" else if (self.scattering) "SCATTER" else "CHASE");
    }
};

const std = @import("std");
