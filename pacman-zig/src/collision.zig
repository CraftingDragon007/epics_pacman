const std = @import("std");
const game = @import("game_types.zig");

pub const tolerance_pixels: i32 = 10;

pub const Outcome = union(enum) {
    none,
    pacman_died,
    ghost_eaten: game.GhostId,
};

fn abs(value: i32) i32 {
    return if (value < 0) -value else value;
}

/// All sprites use the same top-left coordinate convention and 50px size.
/// Keeping the legacy 10px tolerance gives a deliberate, visually fair hit
/// area rather than triggering just because bounding boxes touch.
pub fn overlaps(pacman_x: i32, pacman_y: i32, ghost_x: i32, ghost_y: i32) bool {
    return abs(pacman_x - ghost_x) <= tolerance_pixels and abs(pacman_y - ghost_y) <= tolerance_pixels;
}

pub fn evaluate(id: game.GhostId, mode: game.GhostMode) Outcome {
    return switch (mode) {
        .fright => .{ .ghost_eaten = id },
        .scatter, .chase => .pacman_died,
        .wait, .spawn => .none,
    };
}

test "contact boundary matches the legacy ten-pixel tolerance" {
    try std.testing.expect(overlaps(100, 200, 110, 190));
    try std.testing.expect(!overlaps(100, 200, 111, 200));
}
