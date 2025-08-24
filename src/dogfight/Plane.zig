const std = @import("std");

const v2 = @import("V.zig");
const V = v2.V;
const v = v2.v;
var risingPressed = false;
var divingPressed = false;

pub const PlaneConstants = struct {
    initial_position: V,
    ground_acceleration_per_second: f32,
    takeoff_length: f32,
    max_speed: f32 = 200.0, // Maximum speed of the plane in pixels per second
};

pub const PlaneState = enum {
    STILL,
    TAKEOFF_ROLL,
    FLYING,
    CRASH,
};

const tweak = @import("tweak.zig");
const basics = @import("basics.zig");

pub const Plane = struct {
    position: V,
    velocity: V,
    direction: f32, // Angle in degrees, 0 meaning facing right, 45 meaning down-right, etc.
    state: PlaneState,
    plane_constants: PlaneConstants,
    risingPressed: bool = false,
    divingPressed: bool = false,
    power: u8,

    pub fn init(constants: PlaneConstants) Plane {
        return Plane{
            .position = constants.initial_position,
            .velocity = v(0, 0),
            .state = .STILL,
            .plane_constants = constants,
            .direction = 0.0,
            .power = 5,
        };
    }

    pub fn makeSmoke(self: Plane) !bool {
        if (self.state != .FLYING)
            return false;
        // Probability of smoke is higher with lower power
        const hurt: f32 = 5.0 - @as(f32, @floatFromInt(self.power));
        std.debug.print("Plane power: {}, hurt: {}\n", .{self.power, hurt});
        const smoke_probability = hurt * 2.0;
        std.debug.print("Smoke probability: {}\n", .{smoke_probability});
        const r = std.crypto.random.float(f32);
        std.debug.print("Random value: {}\n", .{r});
        return r * 100.0 < smoke_probability;
    }

    pub fn rise(self: *Plane, pressed: bool) void {
        self.risingPressed = pressed;
        switch (self.state) {
            .STILL => |_| {
                self.state = .TAKEOFF_ROLL;
            },
            .TAKEOFF_ROLL => |_| {
                const distanceFromStart = @abs(self.position[0] - self.plane_constants.initial_position[0]);
                if (distanceFromStart > self.plane_constants.takeoff_length) {
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

    pub fn computeSpeed(self: *Plane) f32 {
        return @sqrt(self.velocity[0] * self.velocity[0] + self.velocity[1] * self.velocity[1]);
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
                const newVelocity = self.velocity + v(self.plane_constants.ground_acceleration_per_second * seconds, 0);
                const newPosition = self.position + v(newVelocity[0] * seconds, 0);
                if (@abs(newPosition[0] - self.plane_constants.initial_position[0]) >= 2 * self.plane_constants.takeoff_length) {
                    self.state = PlaneState.CRASH;
                    return;
                }
                self.position = newPosition;
                self.velocity = newVelocity;
            },
            .FLYING => {
                var speed = self.computeSpeed();
                const radians = std.math.degreesToRadians(self.direction);
                const acceleration = std.math.sin(radians);
                speed += seconds * (10.0 + acceleration * 40.0);
                if (speed > self.plane_constants.max_speed)
                    speed = self.plane_constants.max_speed;
                if (self.risingPressed)
                    self.direction -= (40.0 + speed) * seconds;
                if (self.divingPressed)
                    self.direction += (40.0 + speed) * seconds;
                self.velocity = v(
                    speed * std.math.cos(radians),
                    speed * std.math.sin(radians),
                );
                self.position = self.position + v2.mulScalar(self.velocity, seconds);
                if (self.position[0] < 0)
                    self.position[0] += basics.window_width;
                if (self.position[0] > basics.window_width)
                    self.position[0] -= basics.window_width;
                if (self.position[1] > self.plane_constants.initial_position[1])
                    self.state = PlaneState.CRASH;
                if (self.position[1] < 0)
                    self.position[1] = 0; // Prevent going off the top of the screen
            },
            .CRASH => |_| {
                // No further action needed, plane is already in crash state
            },
        }
    }
};

const testPlaneConstants = PlaneConstants{
    .initial_position = v(0, 200),
    .ground_acceleration_per_second = 10.0,
    .takeoff_length = 330.0,
};

test "initialization of plane" {
    const plane = Plane.init(testPlaneConstants);
    const expected = Plane{
        .position = testPlaneConstants.initial_position,
        .velocity = v(0, 0),
        .state = .STILL,
        .plane_constants = testPlaneConstants,
        .direction = 0.0,
        .power = 5,
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
    try std.testing.expectEqual(testPlaneConstants.ground_acceleration_per_second, plane.velocity[0]);
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
    while (plane.position[0] < testPlaneConstants.takeoff_length / 2) {
        plane.timePassed(0.1);
        i += 1;
        if (i > 100) {
            break; // Prevent infinite loop in case of an error
        }
    }
    plane.dive(true);
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane crashes when passing runway during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise(true);
    var i: i32 = 0;
    try std.testing.expectEqual(PlaneState.TAKEOFF_ROLL, plane.state);
    while (@abs(plane.position[0] - testPlaneConstants.initial_position[0]) < 2 * testPlaneConstants.takeoff_length) {
        plane.timePassed(0.1);
        i += 1;
        if (i > 1000) {
            break; // Prevent infinite loop in case of an error
        }
    }
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}

test "plane flies if player presses rise when far enough from initial position" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise(true);
    plane.timePassed(0.1);
    var i: i16 = 0;
    while (@abs(plane.position[0] - testPlaneConstants.initial_position[0]) <= testPlaneConstants.takeoff_length) {
        plane.timePassed(0.1);
        i += 1;
        if (i > 1000) {
            break; // Prevent infinite loop in case of an error
        }
    }
    plane.rise(true);
    plane.timePassed(0.1);
    try std.testing.expectEqual(PlaneState.FLYING, plane.state);
    try std.testing.expect(plane.position[1] < testPlaneConstants.initial_position[1]);
    try std.testing.expect(plane.velocity[1] < 0); // Assuming the plane is flying upwards
}

// TODO: introduce "STALL" state to very low speed - with gravity!
// TODO: also STALL when hitting 'roof'
// TODO: in STALL state, ability to recover to FLYING with enough y-velocity and direction downwards
// TODO: return crash or not from timePassed, so that we can handle it in GameState
