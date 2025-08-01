const std = @import("std");

const v2 = @import("V.zig");
const V = v2.V;
const v = v2.v;

const PlaneConstants = struct {
    initialPos: V,
    takeoffSpeed: f32,
    groundAccelerationPerS: f32,
    towerDistance: f32 = 100.0,
};

pub const PlaneState = enum {
    STILL,
    TAKEOFF_ROLL,
    FLYING,
    CRASH,
};

pub const Plane = struct {
    position: V,
    velocity: V,
    state: PlaneState,
    planeConstants: PlaneConstants,

    pub fn init(constants: PlaneConstants) Plane {
        return Plane{
            .position = constants.initialPos,
            .velocity = v(0, 0),
            .state = .STILL,
            .planeConstants = constants,
        };
    }

    pub fn rise(self: Plane) Plane {
        if (self.state == .STILL) {
            const newState: Plane = .{
                .state = .TAKEOFF_ROLL,
                .position = self.position,
                .velocity = self.velocity,
                .planeConstants = self.planeConstants,
            };
            return newState;
        }
        if (self.state == .TAKEOFF_ROLL) {
            if (@abs(self.position[0] - self.planeConstants.towerDistance) < self.planeConstants.towerDistance / 2) {
                var newState = self;
                newState.state = .FLYING;
                return newState;
            }
            var newState = self;
            newState.state = .CRASH;
            return newState;
        }
        return self;
    }

    pub fn dive(self: Plane) Plane {
        if (self.state == .STILL) {
            const newState: Plane = .{
                .state = .TAKEOFF_ROLL,
                .position = self.position,
                .velocity = self.velocity,
                .planeConstants = self.planeConstants,
            };
            return newState;
        }
        if (self.state == .TAKEOFF_ROLL) {
            return sameExcept(self, "state", PlaneState.CRASH);
        }
        return self;
    }

    pub fn timePassed(self: Plane, seconds: f32) Plane {
        if (self.state == .TAKEOFF_ROLL) {
            const newVelocity = self.velocity + v(self.planeConstants.groundAccelerationPerS * seconds, 0);
            const newPosition = self.position + v(newVelocity[0] * seconds, 0);
            if (@abs(newPosition[0] - self.planeConstants.initialPos[0]) >= self.planeConstants.towerDistance) {
                return sameExcept(self, "state", PlaneState.CRASH);
            }
            return Plane{
                .position = newPosition,
                .velocity = newVelocity,
                .state = self.state,
                .planeConstants = self.planeConstants,
            };
        }
        return self;
    }
};

const testPlaneConstants = PlaneConstants{
    .initialPos = v(0, 200),
    .takeoffSpeed = 50.0,
    .groundAccelerationPerS = 10.0,
};

pub inline fn sameExcept(anystruct: anytype, comptime field: []const u8, o: anytype) @TypeOf(anystruct) {
    var new = anystruct;
    @field(new, field) = o;
    return new;
}

test "initialization of plane" {
    const plane = Plane.init(testPlaneConstants);
    const expected = Plane{ .position = testPlaneConstants.initialPos, .velocity = v(0, 0), .state = .STILL, .planeConstants = testPlaneConstants };
    try std.testing.expectEqual(expected, plane);
}

test "plane starts takeoff roll from still state on rise command" {
    const plane = Plane.init(testPlaneConstants);
    const newPlane = plane.rise();
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, newPlane.state);
}

test "plane starts takeoff roll from still state on dive command" {
    const plane = Plane.init(testPlaneConstants);
    const newPlane = plane.dive();
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, newPlane.state);
}

test "plane acceleration on ground during takeoff roll" {
    const plane = Plane.init(testPlaneConstants);
    const newPlane = plane.rise().timePassed(1.0);
    try std.testing.expectEqual(10.0, newPlane.velocity[0]);
}

test "plane crashes if not enough speed during takeoff roll" {
    const plane = Plane.init(testPlaneConstants);
    const newPlane = plane.rise().timePassed(0.1).rise();
    try std.testing.expectEqual(PlaneState.CRASH, newPlane.state);
}

test "plane crashes on dive - even when it has accelerated far enough" {
    const plane = Plane.init(testPlaneConstants);
    var newPlane = plane.rise().timePassed(0.1);
    var i: i16 = 0;
    while (newPlane.position[0] < testPlaneConstants.towerDistance / 2) {
        newPlane = newPlane.timePassed(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    newPlane = newPlane.dive();
    try std.testing.expectEqual(PlaneState.CRASH, newPlane.state);
}

test "plane crashes when hitting tower during takeoff roll" {
    const plane = Plane.init(testPlaneConstants);
    var newPlane = plane.rise();
    var i: i32 = 0;
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, newPlane.state);
    while (@abs(newPlane.position[0] - testPlaneConstants.initialPos[0]) <= testPlaneConstants.towerDistance) {
        newPlane = newPlane.timePassed(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    try std.testing.expectEqual(PlaneState.CRASH, newPlane.state);
}

test "plane flies if far enough from initial position during takeoff roll" {
    const plane = Plane.init(testPlaneConstants);
    var newPlane = plane.rise().timePassed(0.1);
    var i: i16 = 0;
    while (@abs(newPlane.position[0] - testPlaneConstants.initialPos[0]) < testPlaneConstants.towerDistance / 2) {
        newPlane = newPlane.timePassed(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    newPlane = newPlane.rise();
    std.debug.print("state: {}\n", .{newPlane.state});
    try std.testing.expectEqual(PlaneState.FLYING, newPlane.state);
}
