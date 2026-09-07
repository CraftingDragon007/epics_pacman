const std = @import("std");
const maze = @import("maze.zig");
const game = @import("game_types.zig");
const ghost_controller = @import("ghost.zig");
const game_modes = @import("game_modes.zig");
const collision = @import("collision.zig");
const death_animation = @import("death_animation.zig");

const c = @cImport({
    @cInclude("dbAccess.h");
    @cInclude("dbStaticLib.h");
    @cInclude("dbIocRegister.h");
    @cInclude("dbLoadTemplate.h");
    @cInclude("iocInit.h");
    @cInclude("epicsThread.h");
    @cInclude("envDefs.h");
});

extern fn softIoc_registerRecordDeviceDriver(base: ?*c.dbBase) c_int;

const width = maze.width;
const height = maze.height;
const tiles = maze.tiles;
const invalid_direction: i32 = -1;
const pre_turn_window_pixels: i32 = 48;
const Direction = game.Direction;

const Pv = struct {
    prefix: []const u8,

    pub fn name(self: Pv, allocator: std.mem.Allocator, suffix: []const u8) ![:0]u8 {
        return std.fmt.allocPrintSentinel(allocator, "{s}:{s}", .{ self.prefix, suffix }, 0);
    }

    pub fn addr(self: Pv, allocator: std.mem.Allocator, suffix: []const u8) !c.dbAddr {
        const pv_name = try self.name(allocator, suffix);
        defer allocator.free(pv_name);
        var result: c.dbAddr = undefined;
        if (c.dbNameToAddr(pv_name.ptr, &result) != 0) return error.UnknownPv;
        return result;
    }

    pub fn getLong(self: Pv, allocator: std.mem.Allocator, suffix: []const u8) !i32 {
        var address = try self.addr(allocator, suffix);
        var value: i32 = 0;
        var options: c_long = 0;
        var count: c_long = 1;
        if (c.dbGetField(&address, c.DBR_LONG, &value, &options, &count, null) != 0) return error.EpicsRead;
        return value;
    }

    pub fn putLong(self: Pv, allocator: std.mem.Allocator, suffix: []const u8, value: i32) !void {
        var address = try self.addr(allocator, suffix);
        if (c.dbPutField(&address, c.DBR_LONG, &value, 1) != 0) return error.EpicsWrite;
    }

    pub fn getDouble(self: Pv, allocator: std.mem.Allocator, suffix: []const u8) !f64 {
        var address = try self.addr(allocator, suffix);
        var value: f64 = 0;
        var options: c_long = 0;
        var count: c_long = 1;
        if (c.dbGetField(&address, c.DBR_DOUBLE, &value, &options, &count, null) != 0) return error.EpicsRead;
        return value;
    }

    pub fn putString(self: Pv, allocator: std.mem.Allocator, suffix: []const u8, value: []const u8) !void {
        var address = try self.addr(allocator, suffix);
        var buffer: [40]u8 = [_]u8{0} ** 40;
        const n = @min(value.len, buffer.len - 1);
        @memcpy(buffer[0..n], value[0..n]);
        if (c.dbPutField(&address, c.DBR_STRING, &buffer, 1) != 0) return error.EpicsWrite;
    }

    pub fn putShortArray(self: Pv, allocator: std.mem.Allocator, suffix: []const u8, values: []const i16) !void {
        var address = try self.addr(allocator, suffix);
        if (c.dbPutField(&address, c.DBR_SHORT, values.ptr, @intCast(values.len)) != 0) return error.EpicsWrite;
    }
};

const PacmanState = enum { init, ready, moving, blocked, aborted, dying, game_over };
const Pacman = struct {
    state: PacmanState = .init,
    x: i32 = 426,
    y: i32 = 727,
    direction: i32 = invalid_direction,
    target_x: i32 = -1,
    target_y: i32 = -1,
    next_move_ms: i64 = 0,
    pending_direction: i32 = invalid_direction,

    fn tileAt(x: i32, y: i32) usize { return @intCast(y * width + x); }

    fn reset(self: *Pacman, pv: Pv, allocator: std.mem.Allocator) !void {
        self.* = .{};
        try pv.putLong(allocator, "PACMAN_USER_X", self.x);
        try pv.putLong(allocator, "PACMAN_USER_Y", self.y);
        try pv.putLong(allocator, "PACMAN_USER_DIRECTION", invalid_direction);
        try pv.putLong(allocator, "PACMAN_TRY_DIRECTION", invalid_direction);
        try pv.putLong(allocator, "PACMAN_PACMAN_ABORT", 0);
        try pv.putLong(allocator, "PACMAN_PACMAN_DEATH", -1);
        try pv.putLong(allocator, "PACMAN_PACMAN_STATE", 3);
        try pv.putString(allocator, "SS_PACMAN", "READY");
        self.state = .ready;
    }

    fn prepareGameOver(self: *Pacman, pv: Pv, allocator: std.mem.Allocator) !void {
        self.state = .game_over;
        try pv.putLong(allocator, "PACMAN_USER_DIRECTION", invalid_direction);
        try pv.putLong(allocator, "PACMAN_TRY_DIRECTION", invalid_direction);
        try pv.putLong(allocator, "PACMAN_TRY_DIRECTION_LEFT", 0);
        try pv.putLong(allocator, "PACMAN_TRY_DIRECTION_RIGHT", 0);
        try pv.putLong(allocator, "PACMAN_TRY_DIRECTION_UP", 0);
        try pv.putLong(allocator, "PACMAN_TRY_DIRECTION_DOWN", 0);
        try pv.putLong(allocator, "PACMAN_PACMAN_ABORT", 0);
        try pv.putLong(allocator, "PACMAN_PACMAN_DEATH", -1);
        try pv.putLong(allocator, "PACMAN_PACMAN_STATE", 3);
        try pv.putString(allocator, "SS_PACMAN", "GAME_OVER");
    }

    /// A game over must remain still until a fresh player command arrives.
    /// Checking both button and direct-direction PVs supports the two input
    /// methods exposed by the existing UI.
    fn startRequestedAfterGameOver(pv: Pv, allocator: std.mem.Allocator) !bool {
        if (try pv.getLong(allocator, "PACMAN_TRY_DIRECTION_LEFT") != 0) return true;
        if (try pv.getLong(allocator, "PACMAN_TRY_DIRECTION_RIGHT") != 0) return true;
        if (try pv.getLong(allocator, "PACMAN_TRY_DIRECTION_UP") != 0) return true;
        if (try pv.getLong(allocator, "PACMAN_TRY_DIRECTION_DOWN") != 0) return true;
        const direct = try pv.getLong(allocator, "PACMAN_TRY_DIRECTION");
        return direct >= @intFromEnum(Direction.right) and direct <= @intFromEnum(Direction.down);
    }

    fn walkable(map: []const i16, x: i32, y: i32) bool {
        return x >= 0 and x < width and y >= 0 and y < height and
            (map[tileAt(x, y)] == 0 or maze.isPortal(x, y));
    }

    fn chooseTarget(self: *Pacman, map: []const i16, dir: i32) void {
        var tx: i32 = @divTrunc(self.x + 25, 32);
        var ty: i32 = @divTrunc(self.y + 25, 32);
        var dx: i32 = 0;
        var dy: i32 = 0;
        switch (dir) {
            0 => dx = 1,
            1 => dx = -1,
            2 => dy = -1,
            3 => dy = 1,
            else => return,
        }
        while (walkable(map, tx + dx, ty + dy)) { tx += dx; ty += dy; }
        self.target_x = tx;
        self.target_y = ty;
    }

    fn abs(value: i32) i32 {
        return if (value < 0) -value else value;
    }

    /// Match the SNL turn rule: a buffered input takes effect when Pac-Man is
    /// within two pixels of a crossing's centre line and the neighbouring tile
    /// is a path/portal. The buffer survives earlier invalid positions.
    fn canTurn(self: *Pacman, map: []const i16, dir: i32) bool {
        const center_x = self.x + 25;
        const center_y = self.y + 25;
        const tile_x: i32 = @divTrunc(center_x, 32);
        const tile_y: i32 = @divTrunc(center_y, 32);
        const aligned_x = abs(center_x - (tile_x * 32 + 16)) <= 2;
        const aligned_y = abs(center_y - (tile_y * 32 + 16)) <= 2;
        return switch (dir) {
            @intFromEnum(Direction.left) => aligned_y and walkable(map, tile_x - 1, tile_y),
            @intFromEnum(Direction.right) => aligned_y and walkable(map, tile_x + 1, tile_y),
            @intFromEnum(Direction.up) => aligned_x and walkable(map, tile_x, tile_y - 1),
            @intFromEnum(Direction.down) => aligned_x and walkable(map, tile_x, tile_y + 1),
            else => false,
        };
    }

    fn snapForTurn(self: *Pacman, dir: i32) void {
        const center_x = self.x + 25;
        const center_y = self.y + 25;
        const tile_x: i32 = @divTrunc(center_x, 32);
        const tile_y: i32 = @divTrunc(center_y, 32);
        if (dir == @intFromEnum(Direction.left) or dir == @intFromEnum(Direction.right)) {
            self.y = tile_y * 32 + 16 - 25;
        } else {
            self.x = tile_x * 32 + 16 - 25;
        }
    }

    fn directionDelta(dir: i32) struct { x: i32, y: i32 } {
        return switch (dir) {
            @intFromEnum(Direction.left) => .{ .x = -1, .y = 0 },
            @intFromEnum(Direction.right) => .{ .x = 1, .y = 0 },
            @intFromEnum(Direction.up) => .{ .x = 0, .y = -1 },
            @intFromEnum(Direction.down) => .{ .x = 0, .y = 1 },
            else => .{ .x = 0, .y = 0 },
        };
    }

    fn turnAvailableAt(map: []const i16, tile_x: i32, tile_y: i32, turn: i32) bool {
        const delta = directionDelta(turn);
        return walkable(map, tile_x + delta.x, tile_y + delta.y);
    }

    /// A pre-turn can be queued only while approaching an opening within a
    /// bounded 48-pixel window (about one and a half tiles).
    /// the next intersection. This keeps controls responsive without allowing
    /// a turn requested far down a corridor to take effect much later.
    fn canScheduleTurn(self: *Pacman, map: []const i16, turn: i32) bool {
        if (self.canTurn(map, turn)) return true;
        if (self.direction == invalid_direction or turn == self.direction) return false;

        const center_x = self.x + 25;
        const center_y = self.y + 25;
        const tile_x: i32 = @divTrunc(center_x, 32);
        const tile_y: i32 = @divTrunc(center_y, 32);
        const moving = directionDelta(self.direction);
        // Around a tile boundary, the crossing may be represented either by
        // the current tile or the immediately following one. Check both so
        // the queueing window is continuous.
        for ([_]struct { x: i32, y: i32 }{
            .{ .x = tile_x, .y = tile_y },
            .{ .x = tile_x + moving.x, .y = tile_y + moving.y },
        }) |candidate| {
            if (!turnAvailableAt(map, candidate.x, candidate.y, turn)) continue;
            const distance_to_center = if (moving.x == 1)
                (candidate.x * 32 + 16) - center_x
            else if (moving.x == -1)
                center_x - (candidate.x * 32 + 16)
            else if (moving.y == 1)
                (candidate.y * 32 + 16) - center_y
            else
                center_y - (candidate.y * 32 + 16);
            if (distance_to_center >= 0 and distance_to_center <= pre_turn_window_pixels) return true;
        }
        return false;
    }

    fn clearAcceptedButton(pv: Pv, allocator: std.mem.Allocator, dir: i32) !void {
        const suffix = switch (dir) {
            @intFromEnum(Direction.left) => "PACMAN_TRY_DIRECTION_LEFT",
            @intFromEnum(Direction.right) => "PACMAN_TRY_DIRECTION_RIGHT",
            @intFromEnum(Direction.up) => "PACMAN_TRY_DIRECTION_UP",
            @intFromEnum(Direction.down) => "PACMAN_TRY_DIRECTION_DOWN",
            else => return,
        };
        try pv.putLong(allocator, suffix, 0);
    }

    fn tick(self: *Pacman, pv: Pv, allocator: std.mem.Allocator, map: []const i16, now_ms: i64) !void {
        if (self.state == .game_over) return;
        const abort = try pv.getLong(allocator, "PACMAN_PACMAN_ABORT");
        if (abort != 0) { self.state = .aborted; try pv.putString(allocator, "SS_PACMAN", "USER_ABORT"); return; }
        if (self.state == .aborted) return self.reset(pv, allocator);

        // Preserve the original priority, but only latch a request while it
        // is close enough to the next opening to be a genuine pre-turn.
        var requested = invalid_direction;
        if (try pv.getLong(allocator, "PACMAN_TRY_DIRECTION_LEFT") != 0) {
            requested = @intFromEnum(Direction.left);
        } else if (try pv.getLong(allocator, "PACMAN_TRY_DIRECTION_RIGHT") != 0) {
            requested = @intFromEnum(Direction.right);
        } else if (try pv.getLong(allocator, "PACMAN_TRY_DIRECTION_UP") != 0) {
            requested = @intFromEnum(Direction.up);
        } else if (try pv.getLong(allocator, "PACMAN_TRY_DIRECTION_DOWN") != 0) {
            requested = @intFromEnum(Direction.down);
        } else {
            const direct_request = try pv.getLong(allocator, "PACMAN_TRY_DIRECTION");
            if (direct_request != invalid_direction and direct_request != self.direction) requested = direct_request;
        }
        if (self.pending_direction == invalid_direction and requested != invalid_direction) {
            if (self.canScheduleTurn(map, requested)) {
                self.pending_direction = requested;
            } else {
                // Too early or into a wall: discard the command immediately.
                try clearAcceptedButton(pv, allocator, requested);
                try pv.putLong(allocator, "PACMAN_TRY_DIRECTION", self.direction);
            }
        }

        if (self.pending_direction != invalid_direction) {
            if (self.canTurn(map, self.pending_direction)) {
                self.snapForTurn(self.pending_direction);
                self.direction = self.pending_direction;
                self.chooseTarget(map, self.pending_direction);
                try pv.putLong(allocator, "PACMAN_USER_X", self.x);
                try pv.putLong(allocator, "PACMAN_USER_Y", self.y);
                try pv.putLong(allocator, "PACMAN_TRY_DIRECTION", self.pending_direction);
                try pv.putLong(allocator, "PACMAN_USER_DIRECTION", self.pending_direction);
                try pv.putLong(allocator, "PACMAN_PACMAN_STATE", 0);
                try pv.putString(allocator, "SS_PACMAN", "MOVE");
                try clearAcceptedButton(pv, allocator, self.pending_direction);
                self.pending_direction = invalid_direction;
                self.state = .moving;
            } else {
                // A wall never interrupts movement; retain the request for the
                // next opening and keep the public direction unchanged.
                try pv.putLong(allocator, "PACMAN_TRY_DIRECTION", self.direction);
            }
        }
        if (self.state != .moving or now_ms < self.next_move_ms) return;
        const delay = try pv.getDouble(allocator, "PACMAN_MOVE_DELAY");
        self.next_move_ms = now_ms + @as(i64, @intFromFloat(@max(delay, 0.001) * 1000));
        const tx = self.target_x * 32 + 16 - 25;
        const ty = self.target_y * 32 + 16 - 25;
        if (self.x < tx) self.x += 1 else if (self.x > tx) self.x -= 1;
        if (self.y < ty) self.y += 1 else if (self.y > ty) self.y -= 1;
        try pv.putLong(allocator, "PACMAN_USER_X", self.x);
        try pv.putLong(allocator, "PACMAN_USER_Y", self.y);
        if (self.x == tx and self.y == ty) {
            if (maze.isPortal(self.target_x, self.target_y)) {
                // The two open edge cells on the tunnel row are a pair.  Warp
                // to the opposite portal, retain direction, and continue.
                self.x = if (self.direction == @intFromEnum(Direction.left)) (width - 1) * 32 + 16 - 25 else 16 - 25;
                try pv.putLong(allocator, "PACMAN_USER_X", self.x);
                self.chooseTarget(map, self.direction);
                try pv.putString(allocator, "SS_PACMAN", "TELEPORT");
            } else {
                self.state = .blocked;
                try pv.putLong(allocator, "PACMAN_PACMAN_STATE", 1);
                try pv.putString(allocator, "SS_PACMAN", "BLOCKED");
            }
        }
    }
};

fn checkGhostCollisions(pv: Pv, allocator: std.mem.Allocator) !collision.Outcome {
    const pacman_x = try pv.getLong(allocator, "PACMAN_USER_X");
    const pacman_y = try pv.getLong(allocator, "PACMAN_USER_Y");
    for ([_]game.GhostId{ .blinky, .pinky, .inky, .clyde }) |id| {
        var name: [48]u8 = undefined;
        const x_name = try std.fmt.bufPrint(&name, "GHOSTS_{s}_X", .{game.pvName(id)});
        const ghost_x = try pv.getLong(allocator, x_name);
        const y_name = try std.fmt.bufPrint(&name, "GHOSTS_{s}_Y", .{game.pvName(id)});
        const ghost_y = try pv.getLong(allocator, y_name);
        if (!collision.overlaps(pacman_x, pacman_y, ghost_x, ghost_y)) continue;
        const mode_name = try std.fmt.bufPrint(&name, "GHOSTS_{s}_MODE", .{game.pvName(id)});
        const mode: game.GhostMode = @enumFromInt(try pv.getLong(allocator, mode_name));
        const outcome = collision.evaluate(id, mode);
        switch (outcome) {
            .none => {},
            else => return outcome,
        }
    }
    return .none;
}

fn resetRound(pacman: *Pacman, ghosts: *[4]ghost_controller.Ghost, modes: *game_modes.Controller, pv: Pv, allocator: std.mem.Allocator) !void {
    for (ghosts) |*ghost| ghost.* = ghost_controller.Ghost.init(ghost.id);
    try pacman.reset(pv, allocator);
    try modes.init(pv, allocator);
    try pv.putLong(allocator, "GAME_FRIGHT_MODE", 0);
    try pv.putLong(allocator, "GAME_KILLED_GHOSTS_MULTIPLIER", 1);
    try pv.putString(allocator, "SS_GAME_ENGINE", "ROUND_READY");
}

fn resetGameAfterGameOver(pacman: *Pacman, ghosts: *[4]ghost_controller.Ghost, modes: *game_modes.Controller, pv: Pv, allocator: std.mem.Allocator) !void {
    for (ghosts) |*ghost| ghost.* = ghost_controller.Ghost.init(ghost.id);
    try pacman.reset(pv, allocator);
    try modes.init(pv, allocator);
    // Pulse the legacy food reset calcouts so a new game restores all dots
    // and four power pellets.  The mode controller's startup arming absorbs
    // the records' resulting visibility updates.
    try pv.putLong(allocator, "PACMAN_RESET_FOOD", 0);
    try pv.putLong(allocator, "PACMAN_RESET_FOOD", 1);
    try pv.putLong(allocator, "PACMAN_USER_SCORE", 0);
    try pv.putLong(allocator, "GAME_PACMAN_LIVES", 3);
    try pv.putLong(allocator, "GAME_KILLED_GHOSTS_MULTIPLIER", 1);
    try pv.putString(allocator, "SS_GAME_ENGINE", "ROUND_READY");
}

/// The original game-over reset restores the board and all sprite positions,
/// but leaves the completed game's score visible behind the GAME OVER label.
/// A later player command starts the next game and clears that score.
fn resetPositionsForGameOver(pacman: *Pacman, ghosts: *[4]ghost_controller.Ghost, modes: *game_modes.Controller, pv: Pv, allocator: std.mem.Allocator) !void {
    for (ghosts) |*ghost| ghost.* = ghost_controller.Ghost.init(ghost.id);
    try pacman.reset(pv, allocator);
    try modes.init(pv, allocator);
    try pv.putLong(allocator, "PACMAN_RESET_FOOD", 0);
    try pv.putLong(allocator, "PACMAN_RESET_FOOD", 1);
    try pacman.prepareGameOver(pv, allocator);
    try pv.putLong(allocator, "GAME_PACMAN_LIVES", -1);
    try pv.putLong(allocator, "GAME_GHOSTS_RUNNING", 0);
    try pv.putString(allocator, "SS_GAME_ENGINE", "GAME_OVER");
}

fn handleCollision(outcome: collision.Outcome, pacman: *Pacman, modes: *game_modes.Controller, death: *death_animation.Sequence, pv: Pv, allocator: std.mem.Allocator, now_ms: i64) !void {
    switch (outcome) {
        .none => {},
        .ghost_eaten => |id| {
            const multiplier = @max(try pv.getLong(allocator, "GAME_KILLED_GHOSTS_MULTIPLIER"), 1);
            const score = try pv.getLong(allocator, "PACMAN_USER_SCORE");
            try pv.putLong(allocator, "PACMAN_USER_SCORE", score + 200 * multiplier);
            try pv.putLong(allocator, "GAME_KILLED_GHOSTS_MULTIPLIER", multiplier + 1);
            try modes.ghostEaten(pv, allocator, id);
            try pv.putString(allocator, "SS_GAME_ENGINE", "GHOST_EATEN");
        },
        .pacman_died => {
            const lives = try pv.getLong(allocator, "GAME_PACMAN_LIVES");
            const remaining = @max(lives - 1, 0);
            try pv.putLong(allocator, "GAME_PACMAN_LIVES", remaining);
            pacman.state = .dying;
            try pv.putLong(allocator, "PACMAN_PACMAN_ABORT", 1);
            try pv.putLong(allocator, "PACMAN_PACMAN_STATE", 1);
            try pv.putLong(allocator, "GAME_GHOSTS_RUNNING", 0);
            for ([_]game.GhostId{ .blinky, .pinky, .inky, .clyde }) |id| {
                var name: [48]u8 = undefined;
                const mode = try std.fmt.bufPrint(&name, "GHOSTS_{s}_MODE", .{game.pvName(id)});
                try pv.putLong(allocator, mode, @intFromEnum(game.GhostMode.wait));
            }
            try pv.putLong(allocator, "PACMAN_PACMAN_DEATH", death.begin(now_ms, remaining == 0));
            try pv.putString(allocator, "SS_GAME_ENGINE", "PACMAN_DEATH");
        },
    }
}

fn checked(status: c_int, what: []const u8) !void { if (status != 0) { std.log.err("EPICS failed while {s}: {d}", .{ what, status }); return error.EpicsSetup; } }

fn loadDatabase(allocator: std.mem.Allocator, epics_base: []const u8, db_dir: []const u8, prefix: []const u8) !void {
    const base_dbd = try std.fmt.allocPrintSentinel(allocator, "{s}/dbd/base.dbd", .{epics_base}, 0); defer allocator.free(base_dbd);
    const base_dbd_dir = try std.fmt.allocPrintSentinel(allocator, "{s}/dbd", .{epics_base}, 0); defer allocator.free(base_dbd_dir);
    const dir_z = try std.fmt.allocPrintSentinel(allocator, "{s}", .{db_dir}, 0); defer allocator.free(dir_z);
    const include_path = try std.fmt.allocPrintSentinel(allocator, "{s}/dbd:{s}", .{ epics_base, db_dir }, 0); defer allocator.free(include_path);
    _ = c.epicsEnvSet("EPICS_DB_INCLUDE_PATH", include_path.ptr);
    try checked(c.dbLoadDatabase(base_dbd.ptr, base_dbd_dir.ptr, null), "loading base.dbd");
    c.dbIocRegister();
    try checked(softIoc_registerRecordDeviceDriver(c.pdbbase), "registering standard record support");
    const specs = [_]struct { file: []const u8, macros: []const u8 }{
        .{ .file = "pacman_data.subs", .macros = "SYSTEM=PACMAN" }, .{ .file = "pacman_food.subs", .macros = "SYSTEM=PACMAN" },
        .{ .file = "game_engine.subs", .macros = "SYSTEM=PACMAN" }, .{ .file = "pacman_fruit.subs", .macros = "SYSTEM=PACMAN" },
        .{ .file = "ghosts_common.subs", .macros = "SYSTEM=PACMAN,GHOST=COMMON" },
        .{ .file = "ghosts_individual.subs", .macros = "SYSTEM=PACMAN,GHOST=BLINKY" }, .{ .file = "ghosts_individual.subs", .macros = "SYSTEM=PACMAN,GHOST=PINKY" },
        .{ .file = "ghosts_individual.subs", .macros = "SYSTEM=PACMAN,GHOST=INKY" }, .{ .file = "ghosts_individual.subs", .macros = "SYSTEM=PACMAN,GHOST=CLYDE" },
    };
    for (specs) |spec| { const file = try std.fmt.allocPrintSentinel(allocator, "{s}/{s}", .{ db_dir, spec.file }, 0); defer allocator.free(file); const macros = try std.fmt.allocPrintSentinel(allocator, "{s}", .{spec.macros}, 0); defer allocator.free(macros); try checked(c.dbLoadTemplate(file.ptr, macros.ptr, dir_z.ptr), "loading substitutions"); }
    const db_file = try std.fmt.allocPrintSentinel(allocator, "{s}/pacman.db", .{db_dir}, 0); defer allocator.free(db_file);
    for ([_][]const u8{ "PACMAN", "GHOSTS", "GAME_ENGINE", "GHOST_MODES" }) |ss| { const macros = try std.fmt.allocPrintSentinel(allocator, "NAME={s},SS={s}", .{ prefix, ss }, 0); defer allocator.free(macros); try checked(c.dbLoadRecords(db_file.ptr, macros.ptr), "loading status records"); }
    try checked(c.iocInit(), "initializing IOC");
}

/// Reuse the canonical map literal from the legacy boot script.  Keeping the
/// map data separate from the controller lets both IOCs serve identical tiles.
pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator); defer arena_state.deinit(); const allocator = arena_state.allocator();
    const prefix: []const u8 = "PACMAN";
    const epics_base: []const u8 = "/usr/lib/epics";
    const db_dir: []const u8 = "../pacman-softIoc";
    try loadDatabase(allocator, epics_base, db_dir, prefix);
    const pv = Pv{ .prefix = prefix };
    var map = maze.cells;
    try pv.putShortArray(allocator, "PACMAN_PLAY_FIELD", &map);
    var pacman = Pacman{}; try pacman.reset(pv, allocator);
    var ghosts = [_]ghost_controller.Ghost{ .init(.blinky), .init(.pinky), .init(.inky), .init(.clyde) };
    var modes = game_modes.Controller{};
    var death = death_animation.Sequence{};
    try modes.init(pv, allocator);
    try pv.putString(allocator, "SS_GAME_ENGINE", "INIT"); try pv.putString(allocator, "SS_GHOSTS", "READY");
    var now_ms: i64 = 0;
    while (true) {
        if (death.active) {
            if (death.tick(now_ms)) |frame| {
                try pv.putLong(allocator, "PACMAN_PACMAN_DEATH", frame);
                if (frame == -1) {
                    if (death.game_over_after) {
                        // `-1` is the original UI's game-over sentinel. It
                        // displays GAME OVER after resetting every sprite to
                        // its opening position, then waits for new input.
                        try resetPositionsForGameOver(&pacman, &ghosts, &modes, pv, allocator);
                    } else {
                        try resetRound(&pacman, &ghosts, &modes, pv, allocator);
                    }
                }
            }
        } else if (pacman.state == .game_over) {
            if (try Pacman.startRequestedAfterGameOver(pv, allocator)) {
                try resetGameAfterGameOver(&pacman, &ghosts, &modes, pv, allocator);
            }
        } else {
            try pacman.tick(pv, allocator, &map, now_ms);
            try modes.tick(pv, allocator, now_ms);
            for (&ghosts) |*ghost| try ghost.tick(pv, allocator, now_ms);
            try handleCollision(try checkGhostCollisions(pv, allocator), &pacman, &modes, &death, pv, allocator, now_ms);
        }
        c.epicsThreadSleep(0.001);
        now_ms += 1;
    }
}

test "maze exposes walls, paths, and side portals" {
    try std.testing.expect(Pacman.walkable(&maze.cells, 1, 1));
    try std.testing.expect(!Pacman.walkable(&maze.cells, 0, 0));
    try std.testing.expect(maze.isPortal(0, 14));
    try std.testing.expect(maze.isPortal(27, 14));
}

test "movement target stops at a wall and includes a side portal" {
    var pacman = Pacman{ .x = 23, .y = 23 };
    pacman.chooseTarget(&maze.cells, @intFromEnum(Direction.right));
    try std.testing.expectEqual(@as(i32, 12), pacman.target_x);
    try std.testing.expectEqual(@as(i32, 1), pacman.target_y);

    pacman = .{ .x = 23, .y = 14 * 32 + 16 - 25 };
    pacman.chooseTarget(&maze.cells, @intFromEnum(Direction.left));
    try std.testing.expectEqual(@as(i32, 0), pacman.target_x);
    try std.testing.expectEqual(@as(i32, 14), pacman.target_y);
}

test "wall-directed input is rejected while a centered opening can be pre-turned" {
    // Tile (1,1) has an open corridor to the right and a wall above it.
    var pacman = Pacman{ .x = 23, .y = 23, .direction = @intFromEnum(Direction.right) };
    try std.testing.expect(!pacman.canTurn(&maze.cells, @intFromEnum(Direction.up)));
    try std.testing.expect(pacman.canTurn(&maze.cells, @intFromEnum(Direction.right)));

    // Two pixels before the vertical center line is still a legal pre-turn.
    pacman.y = 21;
    try std.testing.expect(pacman.canTurn(&maze.cells, @intFromEnum(Direction.right)));
}

test "pre-turn window starts only close to the opening" {
    // On row 1, tile (6,1) opens downward. Moving right, its centre is x=208.
    var pacman = Pacman{ .x = 103, .y = 23, .direction = @intFromEnum(Direction.right) };
    try std.testing.expect(!pacman.canScheduleTurn(&maze.cells, @intFromEnum(Direction.down)));

    pacman.x = 135; // centre x=160: 48 pixels before the opening centre
    try std.testing.expect(pacman.canScheduleTurn(&maze.cells, @intFromEnum(Direction.down)));
}
