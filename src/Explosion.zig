// Represents an anime-style sphere-within-a-sphere explosion
//
//
// The explosion stands still and lives for lifetimeSeconds.
// The size of the explosion is a parameter of the explosion.
// The inner sphere starts at the perimeter of the outer sphere,
// and grows to the size of the outer sphere over the lifetimeSeconds.
// This means, that at lifetimeSeconds / 2, the inner sphere is half the size of the outer sphere.
// And at lifetimeSeconds, the inner sphere is the same size as the outer sphere.

const std = @import("std");

//    rl.DrawCircle(200, 200, 50, rl.RED);
const V = @import("V.zig").V;
const v = @import("V.zig").v;

const Explosion = struct {
    outerPosition: V,
    outerDiameter: f32,
    innerPosition: V,
    innerDiameter: f32,
    lifetimeSeconds: f32,
    ageSeconds: f32,

    fn timePassed(self: *Explosion, seconds: f32) void {
        self.ageSeconds += seconds;
        if (self.ageSeconds >= self.lifetimeSeconds) {
            self.ageSeconds = self.lifetimeSeconds;
        }
        self.innerDiameter = self.outerDiameter * (self.ageSeconds / self.lifetimeSeconds);
    }
};

fn concat(
    allocator: std.mem.Allocator,
    a: []const u8,
    b: []const u8,
) ![]const u8 {
    const result = try std.fmt.allocPrint(
        allocator,
        "{s}{s}",
        .{ a, b },
    );
    return result;
}

fn printExplosionState(
    allocator: std.mem.Allocator,
    explosion: Explosion,
) ![]const u8 {
    const result = try std.fmt.allocPrint(
        allocator,
        \\t={d}
        \\outerPosition={d},{d}
        \\outerDiameter={d}
        \\innerPosition={d},{d}
        \\innerDiameter={d}
        \\
        \\
    ,
        .{
            explosion.ageSeconds,
            explosion.outerPosition[0],
            explosion.outerPosition[1],
            explosion.outerDiameter,
            explosion.innerPosition[0],
            explosion.innerPosition[1],
            explosion.innerDiameter,
        },
    );
    return result;
}

fn writeExplosionString(buffer: *std.ArrayList(u8), explosion: Explosion) !void {
    var writer = buffer.writer();
    const explosionString = try printExplosionState(buffer.allocator, explosion);
    defer buffer.allocator.free(explosionString);
    _ = try writer.writeAll(explosionString);
}

test "explosion state printer" {
    const expected =
        \\t=0
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=0,50
        \\innerDiameter=0
        \\
    ;
    const ally = std.testing.allocator;
    const explosion = Explosion{
        .outerPosition = v(50, 50),
        .outerDiameter = 100,
        .innerPosition = v(0, 50),
        .innerDiameter = 0,
        .lifetimeSeconds = 1.0,
        .ageSeconds = 0.0,
    };
    const actual: []const u8 = try printExplosionState(ally, explosion);
    defer ally.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

test "the life of an explosion 2" {
    const expectedStorybook: []const u8 =
        \\Explosion at 50,50 of size 100, lifetime 1 second:
        \\
        \\t=0
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=0,50
        \\innerDiameter=0
        \\
        \\t=0.5
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=25,50
        \\innerDiameter=50
        \\
        \\t=1.0
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=50,50
        \\innerDiameter=100
    ;
    const ally = std.testing.allocator;
    var buffer = std.ArrayList(u8).init(ally);
    defer buffer.deinit();
    const writer = buffer.writer();
    _ = try writer.write("Explosion at 50,50 of size 100, lifetime 1 second:\n\n");
    var explosion = Explosion{
        .outerPosition = v(50, 50),
        .outerDiameter = 100,
        .innerPosition = v(0, 50),
        .innerDiameter = 0,
        .lifetimeSeconds = 1.0,
        .ageSeconds = 0.0,
    };
    try writeExplosionString(&buffer, explosion);
    explosion.timePassed(0.5);
    try writeExplosionString(&buffer, explosion);
    explosion.timePassed(0.5);
    try writeExplosionString(&buffer, explosion);
    const result : []const u8 = try buffer.toOwnedSlice();
    defer ally.free(result);
    try std.testing.expectEqualStrings(expectedStorybook, result);
}
