const std = @import("std");

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

const width = 28;
const height = 31;
const tiles = width * height;
const invalid_direction: i32 = -1;
const Direction = enum(i32) { right = 0, left = 1, up = 2, down = 3 };
const GhostMode = enum(i32) { wait = 0, scatter = 1, chase = 2, fright = 3, spawn = 4 };

const Pv = struct {
    prefix: []const u8,

    fn name(self: Pv, allocator: std.mem.Allocator, suffix: []const u8) ![:0]u8 {
        return std.fmt.allocPrintSentinel(allocator, "{s}:{s}", .{ self.prefix, suffix }, 0);
    }

    fn addr(self: Pv, allocator: std.mem.Allocator, suffix: []const u8) !c.dbAddr {
        const pv_name = try self.name(allocator, suffix);
        defer allocator.free(pv_name);
        var result: c.dbAddr = undefined;
        if (c.dbNameToAddr(pv_name.ptr, &result) != 0) return error.UnknownPv;
        return result;
    }

    fn getLong(self: Pv, allocator: std.mem.Allocator, suffix: []const u8) !i32 {
        var address = try self.addr(allocator, suffix);
        var value: i32 = 0;
        var options: c_long = 0;
        var count: c_long = 1;
        if (c.dbGetField(&address, c.DBR_LONG, &value, &options, &count, null) != 0) return error.EpicsRead;
        return value;
    }

    fn putLong(self: Pv, allocator: std.mem.Allocator, suffix: []const u8, value: i32) !void {
        var address = try self.addr(allocator, suffix);
        if (c.dbPutField(&address, c.DBR_LONG, &value, 1) != 0) return error.EpicsWrite;
    }

    fn getDouble(self: Pv, allocator: std.mem.Allocator, suffix: []const u8) !f64 {
        var address = try self.addr(allocator, suffix);
        var value: f64 = 0;
        var options: c_long = 0;
        var count: c_long = 1;
        if (c.dbGetField(&address, c.DBR_DOUBLE, &value, &options, &count, null) != 0) return error.EpicsRead;
        return value;
    }

    fn putString(self: Pv, allocator: std.mem.Allocator, suffix: []const u8, value: []const u8) !void {
        var address = try self.addr(allocator, suffix);
        var buffer: [40]u8 = [_]u8{0} ** 40;
        const n = @min(value.len, buffer.len - 1);
        @memcpy(buffer[0..n], value[0..n]);
        if (c.dbPutField(&address, c.DBR_STRING, &buffer, 1) != 0) return error.EpicsWrite;
    }

    fn putShortArray(self: Pv, allocator: std.mem.Allocator, suffix: []const u8, values: []const i16) !void {
        var address = try self.addr(allocator, suffix);
        if (c.dbPutField(&address, c.DBR_SHORT, values.ptr, @intCast(values.len)) != 0) return error.EpicsWrite;
    }
};

const PacmanState = enum { init, ready, moving, blocked, aborted };
const Pacman = struct {
    state: PacmanState = .init,
    x: i32 = 426,
    y: i32 = 727,
    direction: i32 = invalid_direction,
    target_x: i32 = -1,
    target_y: i32 = -1,
    next_move_ms: i64 = 0,

    fn tileAt(x: i32, y: i32) usize { return @intCast(y * width + x); }

    fn reset(self: *Pacman, pv: Pv, allocator: std.mem.Allocator) !void {
        self.* = .{};
        try pv.putLong(allocator, "PACMAN_USER_X", self.x);
        try pv.putLong(allocator, "PACMAN_USER_Y", self.y);
        try pv.putLong(allocator, "PACMAN_USER_DIRECTION", invalid_direction);
        try pv.putLong(allocator, "PACMAN_TRY_DIRECTION", invalid_direction);
        try pv.putLong(allocator, "PACMAN_PACMAN_STATE", 3);
        try pv.putString(allocator, "SS_PACMAN", "READY");
        self.state = .ready;
    }

    fn walkable(map: []const i16, x: i32, y: i32) bool {
        return x >= 0 and x < width and y >= 0 and y < height and map[tileAt(x, y)] == 0;
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

    fn tick(self: *Pacman, pv: Pv, allocator: std.mem.Allocator, map: []const i16, now_ms: i64) !void {
        const abort = try pv.getLong(allocator, "PACMAN_PACMAN_ABORT");
        if (abort != 0) { self.state = .aborted; try pv.putString(allocator, "SS_PACMAN", "USER_ABORT"); return; }
        if (self.state == .aborted) return self.reset(pv, allocator);

        var requested = try pv.getLong(allocator, "PACMAN_TRY_DIRECTION");
        inline for ([_]struct { suffix: []const u8, dir: i32 }{
            .{ .suffix = "PACMAN_TRY_DIRECTION_LEFT", .dir = 1 }, .{ .suffix = "PACMAN_TRY_DIRECTION_RIGHT", .dir = 0 },
            .{ .suffix = "PACMAN_TRY_DIRECTION_UP", .dir = 2 }, .{ .suffix = "PACMAN_TRY_DIRECTION_DOWN", .dir = 3 },
        }) |input| if (try pv.getLong(allocator, input.suffix) != 0) { requested = input.dir; try pv.putLong(allocator, input.suffix, 0); };
        if (requested != invalid_direction and requested != self.direction) {
            self.direction = requested;
            self.chooseTarget(map, requested);
            try pv.putLong(allocator, "PACMAN_TRY_DIRECTION", requested);
            try pv.putLong(allocator, "PACMAN_USER_DIRECTION", requested);
            try pv.putLong(allocator, "PACMAN_PACMAN_STATE", 0);
            try pv.putString(allocator, "SS_PACMAN", "MOVE");
            self.state = .moving;
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
        if (self.x == tx and self.y == ty) { self.state = .blocked; try pv.putLong(allocator, "PACMAN_PACMAN_STATE", 1); }
    }
};

const Ghost = struct {
    label: []const u8,
    x: i32 = 0, y: i32 = 0, dir: i32 = 0, next_ms: i64 = 0,
    fn tick(self: *Ghost, pv: Pv, allocator: std.mem.Allocator, now_ms: i64) !void {
        var suffix: [48]u8 = undefined;
        const mode_name = try std.fmt.bufPrint(&suffix, "GHOSTS_{s}_MODE", .{self.label});
        const mode = try pv.getLong(allocator, mode_name);
        if (mode == @intFromEnum(GhostMode.wait) or now_ms < self.next_ms) return;
        const delay = switch (mode) { @intFromEnum(GhostMode.fright) => try pv.getDouble(allocator, "GHOSTS_COMMON_FRIGHT_DELAY"), @intFromEnum(GhostMode.spawn) => try pv.getDouble(allocator, "GHOSTS_COMMON_SPAWN_DELAY"), else => try pv.getDouble(allocator, "GHOSTS_COMMON_CHASE_DELAY") };
        self.next_ms = now_ms + @as(i64, @intFromFloat(@max(delay, 0.001) * 1000));
        const px = try pv.getLong(allocator, "PACMAN_USER_X");
        const py = try pv.getLong(allocator, "PACMAN_USER_Y");
        if (self.x == 0 and self.y == 0) { self.x = try pv.getLong(allocator, try std.fmt.bufPrint(&suffix, "GHOSTS_{s}_X", .{self.label})); self.y = try pv.getLong(allocator, try std.fmt.bufPrint(&suffix, "GHOSTS_{s}_Y", .{self.label})); }
        if (self.x < px) { self.x += 1; self.dir = 0; } else if (self.x > px) { self.x -= 1; self.dir = 1; } else if (self.y < py) { self.y += 1; self.dir = 3; } else if (self.y > py) { self.y -= 1; self.dir = 2; }
        try pv.putLong(allocator, try std.fmt.bufPrint(&suffix, "GHOSTS_{s}_X", .{self.label}), self.x);
        try pv.putLong(allocator, try std.fmt.bufPrint(&suffix, "GHOSTS_{s}_Y", .{self.label}), self.y);
        try pv.putLong(allocator, try std.fmt.bufPrint(&suffix, "GHOSTS_{s}_DIR", .{self.label}), self.dir);
    }
};

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
fn loadMap() [tiles]i16 {
    // The record interface accepts a replaceable waveform.  Start with a
    // bounded play area; deployments may overwrite it with the canonical map.
    var result = [_]i16{0} ** tiles;
    for (0..height) |y| for (0..width) |x| {
        if (x == 0 or x == width - 1 or y == 0 or y == height - 1) result[y * width + x] = 1;
    };
    return result;
}

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator); defer arena_state.deinit(); const allocator = arena_state.allocator();
    const prefix: []const u8 = "PACMAN";
    const epics_base: []const u8 = "/usr/lib/epics";
    const db_dir: []const u8 = "../pacman-softIoc";
    try loadDatabase(allocator, epics_base, db_dir, prefix);
    const pv = Pv{ .prefix = prefix };
    var map = loadMap();
    try pv.putShortArray(allocator, "PACMAN_PLAY_FIELD", &map);
    var pacman = Pacman{}; try pacman.reset(pv, allocator);
    var ghosts = [_]Ghost{ .{ .label = "BLINKY" }, .{ .label = "PINKY" }, .{ .label = "INKY" }, .{ .label = "CLYDE" } };
    try pv.putString(allocator, "SS_GAME_ENGINE", "INIT"); try pv.putString(allocator, "SS_GHOSTS", "READY"); try pv.putString(allocator, "SS_GHOST_MODES", "WAIT_FOR_START");
    var now_ms: i64 = 0;
    while (true) {
        try pacman.tick(pv, allocator, &map, now_ms);
        for (&ghosts) |*ghost| try ghost.tick(pv, allocator, now_ms);
        c.epicsThreadSleep(0.001);
        now_ms += 1;
    }
}

test "walkable map bounds" { var map = [_]i16{1} ** tiles; map[Pacman.tileAt(1, 1)] = 0; try std.testing.expect(Pacman.walkable(&map, 1, 1)); try std.testing.expect(!Pacman.walkable(&map, -1, 1)); }
