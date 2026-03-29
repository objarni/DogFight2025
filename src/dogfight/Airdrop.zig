const std = @import("std");

pub const PowerupType = enum {
    life,
};

pub const Airdrop = struct {
    position: [2]f32,
    velocity: f32,
    active: bool,
    powerup_type: PowerupType,

    pub fn init(x: f32, y: f32, powerup_type: PowerupType) Airdrop {
        return Airdrop{
            .position = [2]f32{ x, y },
            .velocity = 0.0,
            .active = true,
            .powerup_type = powerup_type,
        };
    }

    pub fn update(self: *Airdrop, deltaTime: f32) void {
        if (self.active) {
            self.position[1] += self.velocity * deltaTime;
        }
    }

    pub fn outOfBounds(self: *Airdrop, ground_level: f32) bool {
        return self.position[1] > ground_level;
    }
};

test "airdrop moves down linearly" {
    var airdrop = Airdrop.init(100.0, 50.0, .life);
    airdrop.velocity = 50.0; // 50 pixels per second downward

    const deltaTime = 1.0; // 1 second
    airdrop.update(deltaTime);

    const expectedY = 50.0 + 50.0 * deltaTime; // Should move down by 50 pixels
    try std.testing.expectEqual(expectedY, airdrop.position[1]);
    try std.testing.expectEqual(100.0, airdrop.position[0]); // X should remain unchanged

    // Test with different time delta to verify linear movement
    var airdrop2 = Airdrop.init(200.0, 100.0, .life);
    airdrop2.velocity = 100.0; // 100 pixels per second
    airdrop2.update(0.5); // 0.5 seconds

    const expectedY2 = 100.0 + 100.0 * 0.5; // Should move down by 50 pixels
    try std.testing.expectEqual(expectedY2, airdrop2.position[1]);
}

test "airdrop out of bounds when below ground level" {
    var airdrop = Airdrop.init(100.0, 50.0, .life);
    airdrop.velocity = 50.0;

    try std.testing.expect(!airdrop.outOfBounds(100.0));

    airdrop.position[1] = 150.0;
    try std.testing.expect(airdrop.outOfBounds(100.0));
}
