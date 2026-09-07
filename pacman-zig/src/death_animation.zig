const std = @import("std");

/// Drives the frame values expected by the existing caQtDM skin.  The legacy
/// SNL jumps to frame 8 on contact, then advances frames 9 through 20 every
/// quarter second before publishing -1 to restore the normal Pac-Man skin.
pub const Sequence = struct {
    active: bool = false,
    game_over_after: bool = false,
    frame: i32 = -1,
    next_frame_ms: i64 = 0,

    pub fn begin(self: *Sequence, now_ms: i64, game_over_after: bool) i32 {
        self.active = true;
        self.game_over_after = game_over_after;
        self.frame = 8;
        self.next_frame_ms = now_ms + 250;
        return self.frame;
    }

    /// Returns a new UI frame only when it changes; -1 marks completion.
    pub fn tick(self: *Sequence, now_ms: i64) ?i32 {
        if (!self.active) return null;
        // Frame 20 is the final visible frame.  Complete on the following
        // game-loop pass rather than waiting for another timer edge; this
        // matches the SNL `>= 20` transition and cannot strand game over on
        // the last animation frame.
        if (self.frame >= 20) {
            self.active = false;
            self.frame = -1;
            return -1;
        }
        if (now_ms < self.next_frame_ms) return null;
        if (self.frame < 20) {
            self.frame += 1;
            self.next_frame_ms = now_ms + 250;
            return self.frame;
        }
        self.active = false;
        self.frame = -1;
        return -1;
    }
};

test "death frames run from eight through twenty then restore the normal skin" {
    var sequence = Sequence{};
    try std.testing.expectEqual(@as(i32, 8), sequence.begin(1_000, false));
    try std.testing.expect(sequence.tick(1_249) == null);
    try std.testing.expectEqual(@as(i32, 9), sequence.tick(1_250).?);
    sequence.frame = 20;
    try std.testing.expectEqual(@as(i32, -1), sequence.tick(1_500).?);
    try std.testing.expect(!sequence.active);
}

test "the final death frame never needs a further timer tick to complete" {
    var sequence = Sequence{};
    _ = sequence.begin(1_000, true);
    sequence.frame = 20;
    sequence.next_frame_ms = 99_999;
    try std.testing.expectEqual(@as(i32, -1), sequence.tick(1_001).?);
    try std.testing.expect(!sequence.active);
}
