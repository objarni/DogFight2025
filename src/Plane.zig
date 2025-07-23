
const std = @import("std");

const v2 = @import("v.zig");
const V = v2.V;
const v = v2.v;

const PlaneConstants = struct {
    initialPos : V,
    takeoffSpeed: f32,
};

const PlaneState = enum {
    STILL,
    TAKEOFF_ROLL,
    FLYING,
    CRASH,
};

const Plane = struct {
    position: V,
    velocity: V,
    state: PlaneState,

    pub fn init(constants: PlaneConstants) Plane {
        return Plane{
            .position = constants.initialPos,
            .velocity = v(0, 0),
            .state = .STILL,
        };
    }

    pub fn rise(self: Plane) Plane {
        if (self.state == .STILL) {
            const newState :Plane = .{
                .state = .TAKEOFF_ROLL,
                .position = self.position,
                .velocity = self.velocity,
            };
            return newState;
        }
        return self;
    }

    pub fn dive(self: Plane) Plane {
        if (self.state == .STILL) {
            const newState :Plane = .{
                .state = .TAKEOFF_ROLL,
                .position = self.position,
                .velocity = self.velocity,
            };
            return newState;
        }
        return self;
    }
};

const testPlaneConstants = PlaneConstants{
    .initialPos = v(50, 200),
    .takeoffSpeed = 50.0,
};

test {
    const plane = Plane.init(testPlaneConstants);
    const expected = Plane{
        .position = v(50, 200),
        .velocity = v(0, 0),
        .state = .STILL,
    };
    try std.testing.expectEqual(expected, plane);
}

test {
    const plane = Plane.init(testPlaneConstants);
    // Act
    const newPlane = plane.rise();
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, newPlane.state);
}

test {
    const plane = Plane.init(testPlaneConstants);
    // Act
    const newPlane = plane.dive();
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, newPlane.state);
}

// #plane initial state is STILL
// #when hitting rise/dive from STILL, goes to TAKEOFF_ROLL
// if hitting rise/dive before enough speed in TAKEOFF_ROLL, goes to CRASH
// if hitting rise when enough speed in TAKEOFF_ROLL, goes to FLYING
// if hitting dive when enough speed in TAKEOFF_ROLL, goes to CRASH
