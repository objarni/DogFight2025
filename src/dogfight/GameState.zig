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

const Player = struct {
    plane: Plane,
    resurrect_timeout: f32 = 0.0, // Time until plane can be resurrected after crash
    lives: u8 = 5, // Number of lives for plane
};

pub const GameState = struct {
    clouds: [2]V,
    players: [2]Player,
    explosions: [10]Explosion = undefined, // Array of explosions, max 10
    num_explosions: u8 = 0,

    pub fn init() GameState {
        return GameState{
            .clouds = .{ v(555.0, 305.0), v(100.0, 100.0) },
            .players = .{
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

    pub fn handleMsg(self: *GameState, msg: Msg, commands: *std.ArrayList(Command)) !void {
        switch (msg) {
            .timePassed => |time| {
                // Move plane
                const plane_old_state: [2]PlaneState = .{
                    self.players[0].plane.state,
                    self.players[1].plane.state,
                };
                for (0..2) |plane_ix| {
                    var player = self.players[plane_ix];
                    if (player.resurrect_timeout <= 0) {
                        const propellerPitch: f32 = @max(0.5, @min(2.0, player.plane.velocity[0] / 50.0));
                        const propellerPan: f32 = @max(0.0, @min(1.0, player.plane.position[0] / window_width));
                        const propellerOn = player.plane.state != PlaneState.STILL;
                        const propellerCmd = Command{
                            .playPropellerAudio = PropellerAudio{
                                .plane = @as(u1, @intCast(plane_ix)),
                                .on = propellerOn,
                                .pan = propellerPan,
                                .pitch = propellerPitch,
                            },
                        };
                        try commands.append(propellerCmd);
                        player.plane.timePassed(time.deltaTime);
                        if (player.plane.state == PlaneState.CRASH and
                            plane_old_state[plane_ix] != PlaneState.CRASH)
                        {
                            try self.crashPlane(plane_ix, commands);
                        }
                    }

                    if (player.resurrect_timeout > 0) {
                        player.resurrect_timeout -= time.deltaTime;
                        if (player.resurrect_timeout <= 0) {
                            player.plane = Plane.init(plane_constants[plane_ix]);
                        }
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
            },
            .inputPressed => |input| {
                // TODO: refactor so that we don't need to keep track of plane old state
                const plane_old_state: [2]PlaneState = .{
                    self.players[0].plane.state,
                    self.players[1].plane.state,
                };
                switch (input) {
                    .Plane1Rise => self.players[0].plane.rise(true),
                    .Plane1Dive => self.players[0].plane.dive(true),
                    .Plane2Rise => self.players[1].plane.rise(true),
                    .Plane2Dive => self.players[1].plane.dive(true),
                    else => {},
                }
                for (0..2) |plane_ix| {
                    if (self.players[plane_ix].plane.state == PlaneState.CRASH and
                        plane_old_state[plane_ix] != PlaneState.CRASH)
                    {
                        try self.crashPlane(plane_ix, commands);
                    }
                }
            },
            .inputReleased => |input| {
                const plane_old_state: [2]PlaneState = .{
                    self.players[0].plane.state,
                    self.players[1].plane.state,
                };
                switch (input) {
                    .Plane1Rise => self.players[0].plane.rise(false),
                    .Plane1Dive => self.players[0].plane.dive(false),
                    .Plane2Rise => self.players[1].plane.rise(false),
                    .Plane2Dive => self.players[1].plane.dive(false),
                    else => {},
                }
                for (0..2) |plane_ix| {
                    if (self.players[plane_ix].plane.state == PlaneState.CRASH and
                        plane_old_state[plane_ix] != PlaneState.CRASH)
                    {
                        try commands.append(Command{ .playSoundEffect = SoundEffect.crash });
                        try self.crashPlane(plane_ix, commands);
                    }
                }
            },
        }
    }

    fn crashPlane(self: *GameState, plane_ix: usize, commands: *std.ArrayList(Command)) !void {
        self.players[plane_ix].lives -= 1;
        self.players[plane_ix].resurrect_timeout = 4.0; // Time until plane can be resurrected
        for (0..5) |_| {
            if (self.num_explosions < self.explosions.len) {
                const rad = std.crypto.random.float(f32) * std.math.pi * 2;
                const dist = std.crypto.random.float(f32) * 50.0;
                self.explosions[self.num_explosions] = explosion.randomExplosionAt(
                    self.players[plane_ix].plane.position[0] + dist * std.math.cos(rad),
                    self.players[plane_ix].plane.position[1] + dist * std.math.sin(rad),
                );
                self.num_explosions += 1;
            }
        }
        try commands.append(Command{
            .playSoundEffect = SoundEffect.crash,
        });
        try commands.append(Command{
            .playPropellerAudio = PropellerAudio{
                .on = false,
                .plane = 0, // 0 for plane 1
                .pan = 0.0,
                .pitch = 0.0,
            },
        });
        if (self.players[plane_ix].lives == 0) {
            try commands.append(Command{
                .playSoundEffect = SoundEffect.game_over,
            });
            try commands.append(Command{
                .switchScreen = State.menu,
            });
        }
    }
};

test "GameState: both clouds move left but the lower cloud moves faster" {
    const ally = std.testing.allocator;
    var commands = std.ArrayList(Command).init(ally);
    defer commands.deinit();
    var gameState: GameState = GameState.init();
    const highCloudX: f32 = gameState.clouds[0][0];
    const lowCloudX: f32 = gameState.clouds[1][0];
    try gameState.handleMsg(
        Msg{
            .timePassed = TimePassed{
                .totalTime = 1.0,
                .deltaTime = 1.0,
            },
        },
        &commands,
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
