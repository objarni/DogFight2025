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

    pub fn riseP(self: *Plane) void {
        if (self.state == .STILL) {
            self.state = .TAKEOFF_ROLL;
            return;
        }
        if (self.state == .TAKEOFF_ROLL) {
            if (@abs(self.position[0] - self.planeConstants.towerDistance) < self.planeConstants.towerDistance / 2) {
                self.state = .FLYING;
                return;
            }
            self.state = .CRASH;
            return;
        }
    }

    pub fn diveP(self: *Plane) void {
        if (self.state == .STILL) {
            self.state = .TAKEOFF_ROLL;
            return;
        }
        if (self.state == .TAKEOFF_ROLL) {
            self.state = PlaneState.CRASH;
            return;
        }
        return;
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

    pub fn timePassedP(self: *Plane, seconds: f32) void {
        if (self.state == .TAKEOFF_ROLL) {
            const newVelocity = self.velocity + v(self.planeConstants.groundAccelerationPerS * seconds, 0);
            const newPosition = self.position + v(newVelocity[0] * seconds, 0);
            if (@abs(newPosition[0] - self.planeConstants.initialPos[0]) >= self.planeConstants.towerDistance) {
                self.state = PlaneState.CRASH;
                return;
            }
            self.position = newPosition;
            self.velocity = newVelocity;
            return;
        }
        return;
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
    var plane = Plane.init(testPlaneConstants);
    plane.riseP();
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, plane.state);
}

test "plane starts takeoff roll from still state on dive command" {
    var plane = Plane.init(testPlaneConstants);
    plane.diveP();
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, plane.state);
}

test "plane acceleration on ground during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.riseP();
    plane.timePassedP(1.0);
    try std.testing.expectEqual(10.0, plane.velocity[0]);
}

test "plane crashes if not enough speed during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.riseP();
    plane.timePassedP(0.1);
    plane.riseP();
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane crashes on dive - even when it has accelerated far enough" {
    var plane = Plane.init(testPlaneConstants);
    plane.riseP();
    plane.timePassedP(0.1);
    var i: i16 = 0;
    while (plane.position[0] < testPlaneConstants.towerDistance / 2) {
        plane.timePassedP(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    plane.diveP();
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane crashes when hitting tower during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.riseP();
    var i: i32 = 0;
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, plane.state);
    while (@abs(plane.position[0] - testPlaneConstants.initialPos[0]) <= testPlaneConstants.towerDistance) {
        plane.timePassedP(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane flies if far enough from initial position during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.riseP();
    plane.timePassedP(0.1);
    var i: i16 = 0;
    while (@abs(plane.position[0] - testPlaneConstants.initialPos[0]) < testPlaneConstants.towerDistance / 2) {
        plane.timePassedP(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    plane.riseP();
    std.debug.print("state: {}\n", .{plane.state});
    try std.testing.expectEqual(PlaneState.FLYING, plane.state);
}
