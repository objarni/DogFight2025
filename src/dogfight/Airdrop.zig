const std = @import("std");

pub const Airdrop = struct {
    position: [2]f32,
    velocity: f32,
    active: bool,

    pub fn init(x: f32, y: f32) Airdrop {
        return Airdrop{
            .position = [2]f32{ x, y },
            .velocity = 0.0,
            .active = true,
        };
    }

    pub fn update(self: *Airdrop, deltaTime: f32) void {
        if (self.active) {
            self.position[1] += self.velocity * deltaTime;
        }
    }
};

test "basic airdrop test" {
    try std.testing.expect(true);
}
