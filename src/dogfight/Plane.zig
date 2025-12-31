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
    max_speed: f32 = 200.0,
    stall_threshold: f32,
};

pub const PlaneState = enum {
    STILL,
    TAKEOFF_ROLL,
    FLYING,
    CRASH,
    STALL,
};

const tweak = @import("tweak.zig");
const basics = @import("basics.zig");
const TimePassed = basics.TimePassed;
const Command = basics.Command;

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
            .direction = -20.0,
            .power = 5,
        };
    }

    pub fn visible(self: Plane) bool {
        return self.state != .CRASH;
    }

    pub fn makeSmoke(self: Plane, time: TimePassed) !bool {
        if (self.state != .FLYING)
            return false;
        // Probability of smoke is higher with lower power
        const hurt: f32 = 5.0 - @as(f32, @floatFromInt(self.power));
        var smoke_probability = hurt * 400.0 * time.deltaTime;
        if (self.power == 1) smoke_probability += 1.5;
        const r = std.crypto.random.float(f32);
        return r * 100.0 < smoke_probability;
    }

    fn distanceFromStart(self: *Plane) f32 {
        return @abs(self.position[0] - self.plane_constants.initial_position[0]);
    }

    pub fn rise(self: *Plane, pressed: bool) void {
        self.risingPressed = pressed;
        switch (self.state) {
            .STILL => |_| {
                self.state = .TAKEOFF_ROLL;
                self.direction = 0;
                self.position[1] -= 1;
            },
            .TAKEOFF_ROLL => |_| {
                const distFromStart = self.distanceFromStart();
                if (distFromStart > self.plane_constants.takeoff_length) {
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
                if (distFromStart > 10.0)
                    self.state = .CRASH;
                return;
            },
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
            else => {},
        }
    }

    pub fn computeSpeed(self: *Plane) f32 {
        return @sqrt(self.velocity[0] * self.velocity[0] + self.velocity[1] * self.velocity[1]);
    }

    pub fn timePassed(self: *Plane, seconds: f32) void {
        switch (self.state) {
            .STILL => {
                if (self.risingPressed or self.divingPressed) {
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
                self.direction = if (self.distanceFromStart() > self.plane_constants.takeoff_length) 0 else -15;
                if(self.direction == 0 and self.position[1] == self.plane_constants.initial_position[1] - 1)
                    self.position[1] -= 2;
            },
            .FLYING => {
                var speed = self.computeSpeed();
                if(speed < self.plane_constants.stall_threshold) {
                    std.debug.print("Entering STALL state: speed={}\n", .{speed});
                    self.state = .STALL;
                    return;
                }
                const speed_change = speedChangeCalc(self.direction);
                speed += seconds * speed_change;
                if (speed > self.plane_constants.max_speed)
                    speed = self.plane_constants.max_speed;
                if (self.risingPressed)
                    self.direction -= (40.0 + speed) * seconds;
                if (self.divingPressed)
                    self.direction += (40.0 + speed) * seconds;
                const radians = std.math.degreesToRadians(self.direction);
                self.velocity = v(
                    speed * std.math.cos(radians),
                    speed * std.math.sin(radians),
                );
                self.position = self.position + v2.mulScalar(self.velocity, seconds);
                self.handleEdges();
                if (self.position[1] < 0) {
                    self.position[1] = 0;
                    self.velocity = v(self.velocity[0], 0);
                    self.state = .STALL;
                }
            },
            .CRASH => |_| {
                // No further action needed, plane is already in crash state
            },
            .STALL => {
                const stall_direction_change_rate = 60.0; // degrees per second
                if (self.risingPressed) {
                    self.direction -= stall_direction_change_rate * seconds;
                } else if (self.divingPressed) {
                    self.direction += stall_direction_change_rate * seconds;
                }
                // Gravity effect
                const gravity = 80.0; // units per second squared
                self.velocity = self.velocity + v(0, gravity * seconds);
                self.position = self.position + v2.mulScalar(self.velocity, seconds);
                self.handleEdges();
                // Ready to fly again?
                const speed = self.computeSpeed();
                const direction_normalized: f32 = @mod(
                    self.direction,
                    360.0);
                if (speed > self.plane_constants.stall_threshold and
                    (direction_normalized > 70.0 and direction_normalized < 110.0)) {
                    self.state = .FLYING;
                }
            },
        }
    }

    pub fn propellerOn(self: *Plane) bool {
        return self.state == .FLYING or self.state == .TAKEOFF_ROLL;
    }

    fn handleEdges(self: *Plane) void {
        if (self.position[0] < 0)
            self.position[0] += basics.window_width;
        if (self.position[0] > basics.window_width)
            self.position[0] -= basics.window_width;
        if (self.position[1] > self.plane_constants.initial_position[1])
            self.state = PlaneState.CRASH;
    }
};

const testPlaneConstants = PlaneConstants{
    .initial_position = v(0, 200),
    .ground_acceleration_per_second = 10.0,
    .takeoff_length = 330.0,
    .stall_threshold = 1.0,
};

test "initialization of plane" {
    const plane = Plane.init(testPlaneConstants);
    const expected = Plane{
        .position = testPlaneConstants.initial_position,
        .velocity = v(0, 0),
        .state = .STILL,
        .plane_constants = testPlaneConstants,
        .direction = -20.0,
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

test "plane is tilted during takeoff roll" {
    var plane = Plane.init(testPlaneConstants);
    plane.rise(true);
    plane.timePassed(2.0);
    try std.testing.expectEqual(-15, plane.direction);
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


test "plane enters stall state when speed drops below threshold" {
    var plane = Plane.init(testPlaneConstants);
    // Simulate flying with decreasing speed
    plane.velocity = v(5.0, -5.0);
    plane.state = .FLYING;
    while(plane.state != PlaneState.STALL) {
        plane.timePassed(0.1);
    }
    try std.testing.expectEqual(PlaneState.STALL, plane.state);
}
//
// test "plane keeps approximate x velocity and zeroes y velocity when entering stall from top of screen" {
//     var plane = Plane.init(testPlaneConstants);
//     plane.position = v(100.0, 0.0); // At top of screen
//     plane.velocity = v(50.0, -20.0);
//     plane.state = .FLYING;
//     plane.timePassed(0.1);
//     try std.testing.expectEqual(PlaneState.STALL, plane.state);
//     try std.testing.expectEqual(std.math.approxEqAbs(f32,plane.velocity[0], 50.0, 1.0), true);
//     try std.testing.expectEqual(plane.velocity[1], 0.0);
// }

// test "plane direction changes in stall state based on input" {
//     var plane = Plane.init(testPlaneConstants);
//     plane.state = .STALL;
//     plane.direction = 0.0;
//
//     // No input
//     plane.timePassed(1.0);
//     try std.testing.expectEqual(std.math.approxEqAbs(f32, plane.direction, 0.0, 0.1), true);
//
//     // Rising input
//     plane.rise(true);
//     plane.timePassed(1.0);
//     try std.testing.expectEqual(std.math.approxEqAbs(f32, plane.direction, -60.0, 0.1), true);
//
//     // Diving input
//     plane.rise(false);
//     plane.dive(true);
//     plane.timePassed(1.0);
//     try std.testing.expectEqual(std.math.approxEqAbs(f32, plane.direction, 0.0, 0.1), true);
// }

test "plane is affected by gravity in stall state" {
    var plane = Plane.init(testPlaneConstants);
    plane.state = .STALL;
    plane.velocity = v(50.0, 0.0);
    plane.timePassed(1.0);
    try std.testing.expect(plane.velocity[1] > 0.0); // Y velocity should increase due to gravity
}

test "plane re-enters from other side when exiting screen in stall state" {
    var plane = Plane.init(testPlaneConstants);
    plane.state = .STALL;
    plane.position = v(basics.window_width - 10, 100.0); // Close to right edge
    plane.velocity = v(50.0, 0.0); // Moving right
    plane.timePassed(1.0);
    try std.testing.expect(plane.position[0] < 100); // Should have re-entered from left
}

test "plane crashes when touching ground in stall state" {
    var plane = Plane.init(testPlaneConstants);
    plane.state = .STALL;
    plane.position = v(100.0, testPlaneConstants.initial_position[1] + 10.0); // Just above ground
    plane.velocity = v(50.0, 100.0); // Moving downwards
    plane.timePassed(1.0);
    try std.testing.expectEqual(PlaneState.CRASH, plane.state);
}


// *** STALL state behaviour ***
// [x] enters stall state when touching top of screen or speed < threshold
// [x] initial velocity is same in x-direction, 0 in y-direction if entering from top of screen
// [x] in stall state, only gravity acts on plane
// [x] when plane exits screen through left or right, it re-enters from the other side
// [x] plane crashes if it touches ground in stall state
// [ ] plane exits stall state when speed goes above threshold and direction is close to 270 degrees
// [ ] initial velocity is same as before stall if entering from threshold
// [ ] the sound "ENGINE_STALL" is played when entering stall state
// [ ] there is no engine sound from a plane in STALL state
// [ ] plane direction changes at fixed rate based on input:
//       -60 degrees per second when rising, +60 degrees per second when diving

test "plane exits stall state when speed goes above threshold and direction is close to -90 degrees" {
    var plane = Plane.init(testPlaneConstants);
    plane.state = .STALL;
    plane.velocity = v(0.5, 0.5); // Below threshold
    plane.position = v(100.0, 50.0);

    // Simulate conditions to exit stall
    plane.direction = 80.0;
    plane.velocity = v(0.0, 5.0);
    plane.timePassed(1.0);
    try std.testing.expectEqual(PlaneState.FLYING, plane.state);
}


fn speedChangeCalc(direction: f32) f32 {
    const radians = std.math.degreesToRadians(direction);
    const sin = std.math.sin(radians);
    const diveAcceleration:f32 = if(sin > 0) sin * 40.0 else 0;
    const riseDeceleration:f32 = if(sin < 0) sin * sin * 80.0 else 0;
    const engineAcceleration = 10.0;
    return engineAcceleration + diveAcceleration - riseDeceleration;
}

fn expectGreaterThanZero(value: f32) !void {
    if (value <= 0.0) {
        std.debug.print("Expected value to be greater than zero, but got: {}\n", .{value});
        return error.ValueNotGreaterThanZero;
    }
}

fn expectLessThanZero(value: f32) !void {
    if (value >= 0.0) {
        std.debug.print("Expected value to be less than zero, but got: {}\n", .{value});
        return error.ValueNotLessThanZero;
    }
}

test "speedChangeCalc: positive when flying horisontally (0 or 180 degrees, as well as 360, -360)" {
    try expectGreaterThanZero(speedChangeCalc(0.0));
    try expectGreaterThanZero(speedChangeCalc(180.0));
    try expectGreaterThanZero(speedChangeCalc(360.0));
    try expectGreaterThanZero(speedChangeCalc(-360.0));
    try expectGreaterThanZero(speedChangeCalc(-180.0));
}

test "speedChangeCalc: greater when diving (90 degrees) than when flying horisontally" {
    const horizontal = speedChangeCalc(0.0);
    const diving = speedChangeCalc(90.0);
    try std.testing.expect(diving > horizontal);
}

test "speedChangeCalc: greater when diving (90 degrees) than when flying slightly upwards (-10 degrees)" {
    const slight_up = speedChangeCalc(-10.0);
    const diving = speedChangeCalc(90.0);
    try std.testing.expect(diving > slight_up);
}

test "speedChangeCalc: negative when rising steeply (-90 degrees)" {
    const rising_steeply = speedChangeCalc(-90.0);
    try expectLessThanZero(rising_steeply);
}

test "speedChangeCalc: absolute value lower when diving steeply (90 degrees) than when rising steeply (-90 degrees)" {
    const rising_steeply = speedChangeCalc(-90.0);
    const diving_steeply = speedChangeCalc(90.0);
    try std.testing.expect(@abs(diving_steeply) < @abs(rising_steeply));
}
