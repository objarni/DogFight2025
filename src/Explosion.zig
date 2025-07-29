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
const lerp = @import("V.zig").lerp;

pub const Explosion = struct {
    outerPosition: V,
    outerDiameter: f32,
    initialInnerPosition: V,
    innerPosition: V,
    innerDiameter: f32,
    lifetimeSeconds: f32,
    ageSeconds: f32,
    alive: bool,

    pub fn init(
        lifetimeSeconds: f32,
        position: V,
        diameter: f32,
        innerPositionPolar: f32,
    ) Explosion {
        const innerPosition = v(
            position[0] + diameter / 2 * std.math.cos(innerPositionPolar),
            position[1] + diameter / 2 * std.math.sin(innerPositionPolar),
        );

        return Explosion{
            .outerPosition = position,
            .outerDiameter = diameter,
            .innerPosition = innerPosition,
            .innerDiameter = 0.0,
            .lifetimeSeconds = lifetimeSeconds,
            .ageSeconds = 0.0,
            .initialInnerPosition = innerPosition,
            .alive = true,
        };
    }

    pub fn timePassed(self: *Explosion, seconds: f32) void {
        self.ageSeconds += seconds;
        if (self.ageSeconds >= self.lifetimeSeconds) {
            self.ageSeconds = self.lifetimeSeconds;
            self.alive = false;
        }
        // Detmine if frac age is in 0..0.25, .25..0.75 or .75..1.0 span.
        const frac = self.ageSeconds / self.lifetimeSeconds;
        if (frac < 0.25) {
            // The inner sphere is not moving yet.
            self.innerDiameter = 0;
            self.innerPosition = self.initialInnerPosition;
        } else if (frac < 0.75) {
            // The inner sphere is growing.
            const innerFrac = (frac - 0.25) / 0.5; // Normalize to 0..1
            self.innerDiameter = self.outerDiameter * innerFrac;
            self.innerPosition = lerp(self.initialInnerPosition, self.outerPosition, innerFrac);
        } else {
            // The inner sphere has reached the outer sphere.
            self.innerDiameter = self.outerDiameter;
            self.innerPosition = lerp(self.outerPosition, self.outerPosition, frac);
        }
    }
};

fn printExplosionState(
    allocator: std.mem.Allocator,
    explosion: Explosion,
) ![]const u8 {
    const result = try std.fmt.allocPrint(
        allocator,
        \\t={d}
        \\outerPosition={d:.0},{d:.0}
        \\outerDiameter={d:.0}
        \\innerPosition={d:.0},{d:.0}
        \\innerDiameter={d:.0}
        \\alive={s}
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
            if (explosion.alive) "true" else "false",
        },
    );
    return result;
}

fn writeExplosionString(buffer: *std.ArrayList(u8), explosion: Explosion) !void {
    var writer = buffer.writer();
    try writer.print(
        \\t={d}
        \\outerPosition={d:.0},{d:.0}
        \\outerDiameter={d:.0}
        \\innerPosition={d:.0},{d:.0}
        \\innerDiameter={d:.0}
        \\alive={s}
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
            if (explosion.alive) "true" else "false",
        },
    );
}

test "explosion state printer" {
    const expected =
        \\t=0
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=0,50
        \\innerDiameter=0
        \\alive=true
        \\
        \\
    ;
    const ally = std.testing.allocator;
    const expl: Explosion = .init(
        1.0,
        v(50, 50),
        100,
        std.math.pi,
    );
    const actual: []const u8 = try printExplosionState(ally, expl);
    defer ally.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

test "explosion init function" {
    const ally = std.testing.allocator;
    const explosion = Explosion.init(
        1.0,
        v(50, 50),
        100,
        std.math.pi / 4.0, // 45 degrees in radians
    );

    var buffer = std.ArrayList(u8).init(ally);
    defer buffer.deinit();
    try writeExplosionString(&buffer, explosion);

    const expected =
        \\t=0
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=85,85
        \\innerDiameter=0
        \\alive=true
        \\
        \\
    ;

    try std.testing.expectEqualStrings(expected, buffer.items);
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
        \\alive=true
        \\
        \\t=0.25
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=0,50
        \\innerDiameter=0
        \\alive=true
        \\
        \\t=0.5
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=25,50
        \\innerDiameter=50
        \\alive=true
        \\
        \\t=0.75
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=50,50
        \\innerDiameter=100
        \\alive=true
        \\
        \\t=1
        \\outerPosition=50,50
        \\outerDiameter=100
        \\innerPosition=50,50
        \\innerDiameter=100
        \\alive=false
        \\
        \\
    ;
    const ally = std.testing.allocator;
    var buffer = std.ArrayList(u8).init(ally);
    defer buffer.deinit();
    const writer = buffer.writer();
    _ = try writer.write("Explosion at 50,50 of size 100, lifetime 1 second:\n\n");
    var explosion: Explosion = .init(
        1.0,
        v(50, 50),
        100,
        std.math.pi*1.001,
    );
    try writeExplosionString(&buffer, explosion);
    explosion.timePassed(0.25);
    try writeExplosionString(&buffer, explosion);
    explosion.timePassed(0.25);
    try writeExplosionString(&buffer, explosion);
    explosion.timePassed(0.25);
    try writeExplosionString(&buffer, explosion);
    explosion.timePassed(0.25);
    try writeExplosionString(&buffer, explosion);
    try std.testing.expectEqualStrings(expectedStorybook, buffer.items);
}
