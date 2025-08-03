const std = @import("std");

const v2 = @import("V.zig");
const V = v2.V;
const v = v2.v;

const PlaneConstants = struct {
    initialPos: V,
    groundAccelerationPerS: f32,
    towerDistance: f32,
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
    direction: f32, // Angle in radians, 0 meaning facing right, pi/2 meaning facing up
    state: PlaneState,
    planeConstants: PlaneConstants,

    pub fn init(constants: PlaneConstants) Plane {
        return Plane{
            .position = constants.initialPos,
            .velocity = v(0, 0),
            .state = .STILL,
            .planeConstants = constants,
            .direction = 0.0,
        };
    }

    pub fn rise(self: *Plane) void {
        switch (self.state) {
            .STILL => |_| {
                self.state = .TAKEOFF_ROLL;
            },
            .TAKEOFF_ROLL => |_| {
                if (@abs(self.position[0] - self.planeConstants.towerDistance) < self.planeConstants.towerDistance / 2) {
                    self.state = .FLYING;
                    self.direction += 0.1;
                    // TODO compute speed and use it to set velocity
                    self.velocity = v(
                        50,
                        -50 * std.math.cos(self.direction),
                    );
                    return;
                }
                self.state = .CRASH;
                return;
            },
            else => {},
        }
    }

    pub fn dive(self: *Plane) void {
        switch (self.state) {
            .STILL => |_| {
                self.state = .TAKEOFF_ROLL;
            },
            .TAKEOFF_ROLL => |_| {
                self.state = .CRASH;
            },
            else => {},
        }
    }

    pub fn timePassed(self: *Plane, seconds: f32) void {
        if (self.state == .TAKEOFF_ROLL) {
            const newVelocity = self.velocity + v(self.planeConstants.groundAccelerationPerS * seconds, 0);
            const newPosition = self.position + v(newVelocity[0] * seconds, 0);
            if (@abs(newPosition[0] - self.planeConstants.initialPos[0]) >= self.planeConstants.towerDistance) {
                self.state = PlaneState.CRASH;
                return;
            }
            self.position = newPosition;
            self.velocity = newVelocity;
        }
        if (self.state == .FLYING) {
            // Simulate flying behavior, e.g., update position based on velocity
            self.position = self.position + v(self.velocity[0] * seconds, self.velocity[1] * seconds);
            // Here you could add more complex flying logic if needed
        }
    }
};

const testPlaneConstants = PlaneConstants{
    .initialPos = v(0, 200),
    .groundAccelerationPerS = 10.0,
    .towerDistance = 330.0
};

test "initialization of plane" {
    const plane = Plane.init(testPlaneConstants);
    const expected = Plane{
        .position = testPlaneConstants.initialPos,
        .velocity = v(0, 0),
        .state = .STILL,
        .planeConstants = testPlaneConstants,
        .direction = 0.0,
    };
    try std.testing.expectEqual(expected, plane);
}

test "plane starts takeoff roll from still state on rise command" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise();
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, plane.state);
}

test "plane starts takeoff roll from still state on dive command" {
    var plane = Plane.init(testPlaneConstants);
    plane.dive();
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, plane.state);
}

test "plane acceleration on ground during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise();
    plane.timePassed(1.0);
    try std.testing.expectEqual(10.0, plane.velocity[0]);
}

test "plane crashes if not enough speed during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise();
    plane.timePassed(0.1);
    plane.rise();
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane crashes on dive - even when it has accelerated far enough" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise();
    plane.timePassed(0.1);
    var i: i16 = 0;
    while (plane.position[0] < testPlaneConstants.towerDistance / 2) {
        plane.timePassed(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    plane.dive();
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane crashes when hitting tower during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise();
    var i: i32 = 0;
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, plane.state);
    while (@abs(plane.position[0] - testPlaneConstants.initialPos[0]) <= testPlaneConstants.towerDistance) {
        plane.timePassed(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane flies if far enough from initial position during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise();
    plane.timePassed(0.1);
    var i: i16 = 0;
    while (@abs(plane.position[0] - testPlaneConstants.initialPos[0]) < testPlaneConstants.towerDistance / 2) {
        plane.timePassed(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    plane.rise();
    plane.timePassed(0.1);
    try std.testing.expectEqual(PlaneState.FLYING, plane.state);
    try std.testing.expect(plane.position[1] < testPlaneConstants.initialPos[1]);
    try std.testing.expect(plane.velocity[1] < 0); // Assuming the plane is flying upwards
}
