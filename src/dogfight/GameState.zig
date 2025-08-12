const std = @import("std");

const plane = @import("Plane.zig");
const Plane = plane.Plane;
const PlaneConstants = plane.PlaneConstants;
const PlaneState = plane.PlaneState;

const explosion = @import("Explosion.zig");
const Explosion = explosion.Explosion;

const basics = @import("basics.zig");
const Command = basics.Command;
const TimePassed = basics.TimePassed;
const SoundEffect = basics.SoundEffect;
const PropellerAudio = basics.PropellerAudio;
const State = basics.State;
const Msg = basics.Msg;
const Inputs = basics.Inputs;

const window_width: u16 = basics.window_width;
const window_height: u16 = basics.window_height;

const v2 = @import("V.zig");
const V = v2.V;
const v = v2.v;

const plane1_initial_parameters: PlaneConstants = .{
    .initial_position = v(20.0, window_height - 30),
    .tower_distance = 300.0,
    .ground_acceleration_per_second = 10.0,
};

const plane2_initial_parameters: PlaneConstants = .{
    .initial_position = v(window_width - 280, window_height - 30),
    .tower_distance = 300.0,
    .ground_acceleration_per_second = 10.0,
};

const plane_constants: [2]PlaneConstants = .{ plane1_initial_parameters, plane2_initial_parameters };

const PlaneData = struct {
    plane: Plane,
    resurrect_timeout: f32 = 0.0, // Time until plane can be resurrected after crash
    lives: u8 = 5, // Number of lives for plane
};

pub const GameState = struct {
    clouds: [2]V,
    planes: [2]PlaneData,
    explosions: [10]Explosion = undefined, // Array of explosions, max 10
    num_explosions: u8 = 0,

    pub fn init() GameState {
        return GameState{
            .clouds = .{ v(555.0, 305.0), v(100.0, 100.0) },
            .planes = .{
                .{
                    .plane = Plane.init(plane1_initial_parameters),
                    .resurrect_timeout = 0.0,
                    .lives = 5,
                },
                .{
                    .plane = Plane.init(plane2_initial_parameters),
                    .resurrect_timeout = 0.0,
                    .lives = 5,
                },
            },
        };
    }

    pub fn handleMsg(self: *GameState, msg: Msg, effects: []Command) u8 {
        switch (msg) {
            .timePassed => |time| {
                var numEffects: u8 = 0;

                // Move plane
                if (self.planes[0].resurrect_timeout <= 0) {
                    const propellerPitch: f32 = @max(0.5, @min(2.0, self.planes[0].plane.velocity[0] / 50.0));
                    const propellerPan: f32 = @max(0.0, @min(1.0, self.planes[0].plane.position[0] / window_width));
                    const propellerOn = self.planes[0].plane.state != PlaneState.STILL;
                    const propellerCmd = Command{
                        .playPropellerAudio = PropellerAudio{
                            .plane = 0, // 0 for plane 1
                            .on = propellerOn,
                            .pan = propellerPan,
                            .pitch = propellerPitch,
                        },
                    };
                    effects[0] = propellerCmd;
                    numEffects += 1;
                    const plane1oldState = self.planes[0].plane.state;
                    self.planes[0].plane.timePassed(time.deltaTime);
                    if (self.planes[0].plane.state == PlaneState.CRASH and plane1oldState != PlaneState.CRASH) {
                        numEffects += self.crashPlane(0, effects[1..]);
                    }
                }

                // Check if plane 1 can be resurrected
                if (self.planes[0].resurrect_timeout > 0) {
                    self.planes[0].resurrect_timeout -= time.deltaTime;
                    if (self.planes[0].resurrect_timeout <= 0) {
                        self.planes[0].plane = Plane.init(plane_constants[0]);
                    }
                }

                // Move clouds
                const deltaX: f32 = time.deltaTime;
                self.clouds[0][0] -= deltaX * 5.0;
                self.clouds[1][0] -= deltaX * 8.9; // lower cloud moves faster

                // Update explosions
                for (0..self.num_explosions) |ix| {
                    var e = &self.explosions[ix];
                    e.timePassed(time.deltaTime);
                }
                // Remove dead explosions
                var i: usize = 0;
                while (i < self.num_explosions) {
                    if (!self.explosions[i].alive) {
                        std.debug.print("Removing dead explosion at index {}\n", .{i});
                        self.num_explosions -= 1;
                        self.explosions[i] = self.explosions[self.num_explosions];
                    } else i += 1;
                }

                return numEffects;
            },
            .inputPressed => |input| {
                // TODO: refactor so that we don't need to keep track of plane old state
                const plane_old_state: [2]PlaneState = .{
                    self.planes[0].plane.state,
                    self.planes[1].plane.state,
                };
                switch (input) {
                    .Plane1Rise => self.planes[0].plane.rise(true),
                    .Plane1Dive => self.planes[0].plane.dive(true),
                    .Plane2Rise => self.planes[1].plane.rise(true),
                    .Plane2Dive => self.planes[1].plane.dive(true),
                    else => {},
                }
                var num_effects: u8 = 0;
                for(0..2) |plane_ix| {
                    if (self.planes[plane_ix].plane.state == PlaneState.CRASH and
                        plane_old_state[plane_ix] != PlaneState.CRASH) {
                        num_effects += self.crashPlane(plane_ix, effects);
                    }
                }
                return num_effects;
            },
            .inputReleased => |input| {
                const plane_old_state: [2]PlaneState = .{
                    self.planes[0].plane.state,
                    self.planes[1].plane.state,
                };
                switch (input) {
                    .Plane1Rise => self.planes[0].plane.rise(false),
                    .Plane1Dive => self.planes[0].plane.dive(false),
                    .Plane2Rise => self.planes[1].plane.rise(false),
                    .Plane2Dive => self.planes[1].plane.dive(false),
                    else => {},
                }
                var num_effects: u8 = 0;
                for (0..2) |plane_ix| {
                    if (self.planes[plane_ix].plane.state == PlaneState.CRASH and
                        plane_old_state[plane_ix] != PlaneState.CRASH)
                    {
                        effects[num_effects] = Command{ .playSoundEffect = SoundEffect.crash };
                        num_effects += self.crashPlane(plane_ix, effects);
                    }
                }
                return num_effects;
            },
        }
        return 0;
    }

    fn crashPlane(self: *GameState, plane_ix: usize, effects: []Command) u8 {
        self.planes[plane_ix].lives -= 1;
        self.planes[plane_ix].resurrect_timeout = 4.0; // Time until plane can be resurrected
        for (0..5) |_| {
            if (self.num_explosions < self.explosions.len) {
                const rad = std.crypto.random.float(f32) * std.math.pi * 2;
                const dist = std.crypto.random.float(f32) * 50.0;
                self.explosions[self.num_explosions] = explosion.randomExplosionAt(
                    self.planes[plane_ix].plane.position[0] + dist * std.math.cos(rad),
                    self.planes[plane_ix].plane.position[1] + dist * std.math.sin(rad),
                );
                self.num_explosions += 1;
            }
        }
        effects[0] = Command{
            .playSoundEffect = SoundEffect.crash,
        };
        effects[1] = Command{
            .playPropellerAudio = PropellerAudio{
                .on = false,
                .plane = 0, // 0 for plane 1
                .pan = 0.0,
                .pitch = 0.0,
            },
        };
        if (self.planes[plane_ix].lives == 0) {
            effects[2] = Command{
                .playSoundEffect = SoundEffect.game_over,
            };
            effects[3] = Command{
                .switchScreen = State.menu,
            };
            return 4;
        }

        return 2;
    }
};

test "GameState: both clouds move left but the lower cloud moves faster" {
    var gameState: GameState = GameState.init();
    const highCloudX: f32 = gameState.clouds[0][0];
    const lowCloudX: f32 = gameState.clouds[1][0];
    var effects: [10]Command = undefined;
    _ = gameState.handleMsg(
        Msg{
            .timePassed = TimePassed{
                .totalTime = 1.0,
                .deltaTime = 1.0,
            },
        },
        &effects,
    );
    try std.testing.expectApproxEqAbs(
        highCloudX - 5.0,
        gameState.clouds[0][0],
        0.1,
    );
    try std.testing.expectApproxEqAbs(
        lowCloudX - 8.9,
        gameState.clouds[1][0],
        0.1,
    );
}

// TODO: Implement second plane
