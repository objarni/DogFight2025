const std = @import("std");

const v2 = @import("v.zig");
const V = v2.V;
const v = v2.v;

const PlaneConstants = struct {
    initialPos: V,
    takeoffSpeed: f32,
    groundAccelerationPerS: f32,
    minTakeOffSpeed: f32 = 50.0,
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
            if(self.velocity[0] >= self.planeConstants.takeoffSpeed) {
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
        return self;
    }

    pub fn timePassed(self: Plane, seconds: f32) Plane {
        if (self.state == .TAKEOFF_ROLL) {
            const newVelocity = self.velocity + v(self.planeConstants.groundAccelerationPerS * seconds, 0);
            const newPosition = self.position + v(newVelocity[0] * seconds, 0);
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
    .initialPos = v(50, 200),
    .takeoffSpeed = 50.0,
    .groundAccelerationPerS = 10.0,
};

test {
    const plane = Plane.init(testPlaneConstants);
    const expected = Plane{ .position = v(50, 200), .velocity = v(0, 0), .state = .STILL, .planeConstants = testPlaneConstants };
    try std.testing.expectEqual(expected, plane);
}

test {
    const plane = Plane.init(testPlaneConstants);
    const newPlane = plane.rise();
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, newPlane.state);
}

test {
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

test "plane flies if enough speed during takeoff roll" {
    const plane = Plane.init(testPlaneConstants);
    var newPlane = plane.rise().timePassed(0.1);
    while(newPlane.velocity[0] < testPlaneConstants.minTakeOffSpeed) {
        newPlane = newPlane.timePassed(0.1);
    }
    newPlane = newPlane.rise();
    try std.testing.expectEqual(PlaneState.FLYING, newPlane.state);
}

// #plane initial state is STILL
// #when hitting rise/dive from STILL, goes to TAKEOFF_ROLL
// if hitting rise/dive before enough speed in TAKEOFF_ROLL, goes to CRASH
// if hitting rise when enough speed in TAKEOFF_ROLL, goes to FLYING
// if hitting dive when enough speed in TAKEOFF_ROLL, goes to CRASH
