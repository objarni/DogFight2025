const std = @import("std");

const v2 = @import("V.zig");
const V = v2.V;
const v = v2.v;
var risingPressed = false;
var divingPressed = false;

pub const PlaneConstants = struct {
    initialPos: V,
    ground_acceleration_per_second: f32,
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
    direction: f32, // Angle in degrees, 0 meaning facing right, 45 meaning down-right, etc.
    state: PlaneState,
    planeConstants: PlaneConstants,
    risingPressed: bool = false,
    divingPressed: bool = false,

    pub fn init(constants: PlaneConstants) Plane {
        return Plane{
            .position = constants.initialPos,
            .velocity = v(0, 0),
            .state = .STILL,
            .planeConstants = constants,
            .direction = 0.0,
        };
    }

    pub fn rise(self: *Plane, pressed: bool) void {
        self.risingPressed = pressed;
        switch (self.state) {
            .STILL => |_| {
                self.state = .TAKEOFF_ROLL;
            },
            .TAKEOFF_ROLL => |_| {
                const distanceFromStart = @abs(self.position[0] - self.planeConstants.initialPos[0]);
                const distanceFromTower = @abs(self.position[0] - self.planeConstants.towerDistance);
                if (distanceFromTower < self.planeConstants.towerDistance / 2) {
                    self.state = .FLYING;
                    self.direction = -15;
                    const radians = std.math.degreesToRadians(self.direction);
                    const speed = self.velocity[0]; // We are only moving horizontally during takeoff
                    self.velocity = v(
                        speed * std.math.cos(radians),
                        speed * std.math.sin(radians),
                    );
                    return;
                }
                if (distanceFromStart > 10)
                    self.state = .CRASH;
                return;
            },
            .FLYING => |_| {},
            else => {},
        }
    }

    pub fn dive(self: *Plane, pressed: bool) void {
        self.divingPressed = pressed;
        switch (self.state) {
            .STILL => |_| {
                self.state = .TAKEOFF_ROLL;
            },
            .TAKEOFF_ROLL => |_| {
                self.state = .CRASH;
            },
            .FLYING => |_| {},
            else => {},
        }
    }

    pub fn timePassed(self: *Plane, seconds: f32) void {
        switch (self.state) {
            .STILL => {
                if (self.risingPressed) {
                    self.state = .TAKEOFF_ROLL;
                } else if (self.divingPressed) {
                    self.state = .TAKEOFF_ROLL;
                }
            },
            .TAKEOFF_ROLL => {
                const newVelocity = self.velocity + v(self.planeConstants.ground_acceleration_per_second * seconds, 0);
                const newPosition = self.position + v(newVelocity[0] * seconds, 0);
                if (@abs(newPosition[0] - self.planeConstants.initialPos[0]) >= self.planeConstants.towerDistance) {
                    self.state = PlaneState.CRASH;
                    return;
                }
                self.position = newPosition;
                self.velocity = newVelocity;
            },
            .FLYING => {
                if (self.risingPressed)
                    self.direction -= seconds * 100.0; // Adjust the angle for rising
                if (self.divingPressed)
                    self.direction += seconds * 100.0; // Adjust the angle for diving
                const speed = @sqrt(self.velocity[0] * self.velocity[0] + self.velocity[1] * self.velocity[1]);
                const radians = std.math.degreesToRadians(self.direction);
                self.velocity = v(
                    speed * std.math.cos(radians),
                    speed * std.math.sin(radians),
                );
                self.position = self.position + v(self.velocity[0] * seconds, self.velocity[1] * seconds);
                if (self.position[1] > self.planeConstants.initialPos[1]) {
                    self.state = PlaneState.CRASH; // Plane has crashed if it goes below initial height
                }
            },
            .CRASH => |_| {
                // No further action needed, plane is already in crash state
            },
        }
    }
};

const testPlaneConstants = PlaneConstants{
    .initialPos = v(0, 200),
    .ground_acceleration_per_second = 10.0,
    .towerDistance = 330.0,
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
    plane.rise(true);
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, plane.state);
}

test "plane starts takeoff roll from still state on dive command" {
    var plane = Plane.init(testPlaneConstants);
    plane.dive(true);
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, plane.state);
}

test "plane acceleration on ground during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise(true);
    plane.timePassed(1.0);
    try std.testing.expectEqual(10.0, plane.velocity[0]);
}

test "plane crashes if not enough speed during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise(true);
    plane.timePassed(2.0);
    plane.rise(true);
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane crashes on dive - even when it has accelerated far enough" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise(true);
    plane.timePassed(0.1);
    var i: i16 = 0;
    while (plane.position[0] < testPlaneConstants.towerDistance / 2) {
        plane.timePassed(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    plane.dive(true);
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane crashes when hitting tower during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise(true);
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
    plane.rise(true);
    plane.timePassed(0.1);
    var i: i16 = 0;
    while (@abs(plane.position[0] - testPlaneConstants.initialPos[0]) < testPlaneConstants.towerDistance / 2) {
        plane.timePassed(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    plane.rise(true);
    plane.timePassed(0.1);
    try std.testing.expectEqual(PlaneState.FLYING, plane.state);
    try std.testing.expect(plane.position[1] < testPlaneConstants.initialPos[1]);
    try std.testing.expect(plane.velocity[1] < 0); // Assuming the plane is flying upwards
}
