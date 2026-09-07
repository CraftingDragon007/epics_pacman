const game = @import("game_types.zig");

pub const Controller = struct {
    started: bool = false,
    started_at_ms: i64 = 0,
    phase_started_at_ms: i64 = 0,
    scattering: bool = true,
    frightened_until_ms: i64 = 0,
    frightened_flash_at_ms: i64 = 0,
    next_flash_toggle_ms: i64 = 0,
    flash_visible: bool = false,
    power_pellets_armed: bool = false,
    returning: [4]bool = [_]bool{false} ** 4,
    return_release_at_ms: [4]i64 = [_]i64{0} ** 4,
    respawn_immune_to_fright: [4]bool = [_]bool{false} ** 4,
    power_pellet_seen: [4]bool = [_]bool{false} ** 4,

    const power_pellets = [_]struct { x: i32, y: i32 }{
        .{ .x = 3, .y = 2 }, .{ .x = 8, .y = 2 },
        .{ .x = 19, .y = 6 }, .{ .x = 10, .y = 7 },
    };
    const frightened_duration_ms: i64 = 15_000;
    const frightened_warning_ms: i64 = 5_000;
    const frightened_flash_period_ms: i64 = 250;
    const respawn_wait_ms: i64 = 5_000;
    // A new life rewrites Pacman's coordinates while the existing EPICS food
    // calcout records are still subscribed.  Let their old VIS values settle
    // before treating a 0 transition as an actual pellet consumption.
    const power_pellet_arm_delay_ms: i64 = 1_500;

    pub fn init(self: *Controller, pv: anytype, allocator: std.mem.Allocator) !void {
        self.* = .{};
        const labels = [_]game.GhostId{ .blinky, .pinky, .inky, .clyde };
        const spawn = [_]struct { x0: i32, y0: i32, x1: i32, y1: i32 }{
            .{ .x0 = 423, .y0 = 345, .x1 = 423, .y1 = 345 },
            .{ .x0 = 423, .y0 = 415, .x1 = 423, .y1 = 455 },
            .{ .x0 = 359, .y0 = 415, .x1 = 359, .y1 = 455 },
            .{ .x0 = 487, .y0 = 415, .x1 = 487, .y1 = 455 },
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
        // The legacy calcout records can pulse GAME_FRIGHT_MODE while their
        // inputs settle at IOC startup. Seed the four real power-pellet
        // states and clear that unverified global input.
        for (power_pellets, 0..) |pellet, pellet_index| {
            var name: [32]u8 = undefined;
            const visibility = try std.fmt.bufPrint(&name, "VIS_{d}_{d}", .{ pellet.x, pellet.y });
            self.power_pellet_seen[pellet_index] = try pv.getLong(allocator, visibility) == 0;
        }
        try pv.putLong(allocator, "GAME_FRIGHT_MODE", 0);
        try pv.putLong(allocator, "GAME_FRIGHT_EXPIRATION_TIMER", 0);
        try pv.putLong(allocator, "GAME_FRIGHT_FLASH", 0);
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

    fn index(id: game.GhostId) usize {
        return @intFromEnum(id);
    }

    /// Collision detection is the sole authorizer of MODE_SPAWN. This keeps
    /// a user/UI write from trapping an ordinary ghost in the house, while
    /// allowing a genuinely eaten frightened ghost to return safely.
    pub fn ghostEaten(self: *Controller, pv: anytype, allocator: std.mem.Allocator, id: game.GhostId) !void {
        const slot = index(id);
        self.returning[slot] = true;
        self.return_release_at_ms[slot] = 0;
        self.respawn_immune_to_fright[slot] = true;
        try setMode(pv, allocator, id, .spawn);
        var name: [48]u8 = undefined;
        // The legacy game engine rewrites Blinky's two spawn Y coordinates
        // upon capture. He therefore returns inside the house, unlike his
        // opening-round position immediately above the gate.
        if (id == .blinky) {
            const y0 = try std.fmt.bufPrint(&name, "GHOSTS_{s}_SPAWN_Y0", .{game.pvName(id)});
            try pv.putLong(allocator, y0, 415);
            const y1 = try std.fmt.bufPrint(&name, "GHOSTS_{s}_SPAWN_Y1", .{game.pvName(id)});
            try pv.putLong(allocator, y1, 455);
        }
        const respawn = try std.fmt.bufPrint(&name, "GAME_GHOSTS_{s}_RESPAWN", .{game.pvName(id)});
        try pv.putLong(allocator, respawn, 1);
    }

    fn powerPelletEaten(self: *Controller, pv: anytype, allocator: std.mem.Allocator) !bool {
        var eaten = false;
        for (power_pellets, 0..) |pellet, pellet_index| {
            var name: [32]u8 = undefined;
            const visibility = try std.fmt.bufPrint(&name, "VIS_{d}_{d}", .{ pellet.x, pellet.y });
            const consumed = try pv.getLong(allocator, visibility) == 0;
            if (consumed and !self.power_pellet_seen[pellet_index]) eaten = true;
            self.power_pellet_seen[pellet_index] = consumed;
        }
        return eaten;
    }

    pub fn tick(self: *Controller, pv: anytype, allocator: std.mem.Allocator, now_ms: i64) !void {
        if (!self.started) {
            if (try pv.getLong(allocator, "PACMAN_USER_DIRECTION") < 0) return;
            self.started = true;
            self.started_at_ms = now_ms;
            self.phase_started_at_ms = now_ms;
        }
        const elapsed = now_ms - self.started_at_ms;
        // Keep sampling throughout the startup grace period. This makes the
        // most recent settled state the baseline, rather than accepting an
        // EPICS reset pulse as though Pacman had just eaten a power pellet.
        var frightened_by_pellet = false;
        if (!self.power_pellets_armed) {
            _ = try self.powerPelletEaten(pv, allocator);
            if (elapsed >= power_pellet_arm_delay_ms) self.power_pellets_armed = true;
        } else {
            frightened_by_pellet = try self.powerPelletEaten(pv, allocator);
        }
        // GAME_FRIGHT_MODE is still served for UI compatibility, but the food
        // database is not allowed to start frightened mode on its own: only a
        // newly consumed, known power pellet can do that.
        const fright_input = try pv.getLong(allocator, "GAME_FRIGHT_MODE");
        if (fright_input != 0 and !frightened_by_pellet) try pv.putLong(allocator, "GAME_FRIGHT_MODE", 0);
        if (frightened_by_pellet and self.frightened_until_ms <= now_ms) {
            self.frightened_until_ms = now_ms + frightened_duration_ms;
            self.frightened_flash_at_ms = self.frightened_until_ms - frightened_warning_ms;
            self.next_flash_toggle_ms = self.frightened_flash_at_ms;
            self.flash_visible = false;
            try pv.putLong(allocator, "GAME_KILLED_GHOSTS_MULTIPLIER", 1);
            try pv.putLong(allocator, "GAME_FRIGHT_MODE", 1);
            try pv.putLong(allocator, "GAME_FRIGHT_EXPIRATION_TIMER", 1);
            try pv.putLong(allocator, "GAME_FRIGHT_FLASH", 0);
        }
        const frightened = now_ms < self.frightened_until_ms;
        if (frightened and now_ms >= self.frightened_flash_at_ms) {
            try pv.putLong(allocator, "GAME_FRIGHT_EXPIRATION_TIMER", 0);
            if (now_ms >= self.next_flash_toggle_ms) {
                self.flash_visible = !self.flash_visible;
                self.next_flash_toggle_ms = now_ms + frightened_flash_period_ms;
                try pv.putLong(allocator, "GAME_FRIGHT_FLASH", @intFromBool(self.flash_visible));
            }
        }
        if (!frightened and fright_input != 0) {
            self.flash_visible = false;
            try pv.putLong(allocator, "GAME_FRIGHT_MODE", 0);
            try pv.putLong(allocator, "GAME_FRIGHT_EXPIRATION_TIMER", 0);
            try pv.putLong(allocator, "GAME_FRIGHT_FLASH", 0);
        }

        const phase_duration: i64 = if (self.scattering) 7_000 else 20_000;
        if (!frightened and now_ms - self.phase_started_at_ms >= phase_duration) {
            self.scattering = !self.scattering;
            self.phase_started_at_ms = now_ms;
        }
        const normal_mode: game.GhostMode = if (self.scattering) .scatter else .chase;
        const ghosts = [_]game.GhostId{ .blinky, .pinky, .inky, .clyde };
        for (ghosts) |id| {
            const slot = index(id);
            if (self.returning[slot]) {
                var name: [48]u8 = undefined;
                const mode_name = try std.fmt.bufPrint(&name, "GHOSTS_{s}_MODE", .{game.pvName(id)});
                if (try pv.getLong(allocator, mode_name) != @intFromEnum(game.GhostMode.wait)) continue;
                if (self.return_release_at_ms[slot] == 0) {
                    self.return_release_at_ms[slot] = now_ms + respawn_wait_ms;
                    const respawn = try std.fmt.bufPrint(&name, "GAME_GHOSTS_{s}_RESPAWN", .{game.pvName(id)});
                    try pv.putLong(allocator, respawn, 0);
                }
                if (now_ms < self.return_release_at_ms[slot]) continue;
                self.returning[slot] = false;
                self.return_release_at_ms[slot] = 0;
            }
            if (elapsed < releaseDelay(id)) continue;
            // Clear any unsupported spawn write, but preserve the state that
            // `ghostEaten` explicitly authorized above.
            if (!frightened) self.respawn_immune_to_fright[slot] = false;
            const next_mode: game.GhostMode = if (frightened and !self.respawn_immune_to_fright[slot]) .fright else normal_mode;
            try setMode(pv, allocator, id, next_mode);
        }
        try pv.putString(allocator, "SS_GHOST_MODES", if (frightened and self.flash_visible) "FRIGHTENED_FLASH" else if (frightened) "FRIGHTENED" else if (self.scattering) "SCATTER" else "CHASE");
    }
};

const std = @import("std");
