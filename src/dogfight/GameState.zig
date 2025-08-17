const std = @import("std");

const p = @import("Plane.zig");
const Plane = p.Plane;
const PlaneConstants = p.PlaneConstants;
const PlaneState = p.PlaneState;

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
    .takeoff_length = 150.0,
    .ground_acceleration_per_second = 40.0,
};

const plane2_initial_parameters: PlaneConstants = .{
    .initial_position = v(window_width - 280, window_height - 30),
    .takeoff_length = 150.0,
    .ground_acceleration_per_second = 40.0,
};

const plane_constants: [2]PlaneConstants = .{ plane1_initial_parameters, plane2_initial_parameters };

const Player = struct {
    plane: Plane,
    resurrect_timeout: f32 = 0.0, // Time until plane can be resurrected after crash
    lives: u8, // Number of lives for plane
};

const Shot = struct {
    position: V,
    velocity: V,
};

pub const GameState = struct {
    clouds: [2]V,
    players: [2]Player,
    explosions: [10]Explosion = undefined, // Array of explosions, max 10
    num_explosions: u8 = 0,
    shots: std.ArrayList(Shot) = undefined,

    pub fn init(ally: std.mem.Allocator) GameState {
        return GameState{
            .clouds = .{ v(555.0, 305.0), v(100.0, 100.0) },
            .players = .{
                .{
                    .plane = Plane.init(plane1_initial_parameters),
                    .resurrect_timeout = 0.0,
                    .lives = 1,
                },
                .{
                    .plane = Plane.init(plane2_initial_parameters),
                    .resurrect_timeout = 0.0,
                    .lives = 1,
                },
            },
            .shots = .init(ally),
        };
    }

    pub fn deinit(self: *GameState) void {
        self.shots.deinit();
    }

    pub fn handleMsg(self: *GameState, msg: Msg, commands: *std.ArrayList(Command)) !void {
        switch (msg) {
            .timePassed => |time| {
                // Move shots
                for (self.shots.items) |*shot| {
                    shot.position[0] += shot.velocity[0] * time.deltaTime;
                    shot.position[1] += shot.velocity[1] * time.deltaTime;
                }
                // Remove shots that are out of bounds
                var i: usize = 0;
                while (i < self.shots.items.len) {
                    const shot = self.shots.items[i];
                    const hit_ground = shot.position[1] > self.players[0].plane.plane_constants.initial_position[1];
                    if (shot.position[1] < 0 or hit_ground or
                        shot.position[0] < 0 or
                        shot.position[0] > window_width)
                    {
                        std.debug.print("Removing shot at index {}\n", .{i});
                        _ = self.shots.swapRemove(i);
                        if (hit_ground) {
                            self.explosions[self.num_explosions] = Explosion.init(
                                0.3,
                                shot.position,
                                4,
                                0,
                            );
                            self.num_explosions += 1;
                        }
                    } else i += 1;
                }

                // Does a shot hit plane?
                for (self.shots.items) |shot| {
                    for (0..2) |player_ix| {
                        const plane = self.players[player_ix].plane;
                        if (self.players[player_ix].resurrect_timeout <= 0) {
                            const distance = v2.len(plane.position - shot.position);
                            if (distance < 10 and plane.state == PlaneState.FLYING)
                                try self.crashPlane(player_ix, commands);
                        }
                    }
                }

                // Move planes
                const plane_old_state: [2]PlaneState = .{
                    self.players[0].plane.state,
                    self.players[1].plane.state,
                };
                for (0..2) |plane_ix| {
                    var player: *Player = &self.players[plane_ix];
                    if (player.resurrect_timeout <= 0) {
                        const propellerPitch: f32 = @max(
                            0.5,
                            @min(
                                2.0,
                                2.0 * player.plane.computeSpeed() / player.plane.plane_constants.max_speed,
                            ),
                        );
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
                        try player.plane.timePassed(time.deltaTime);
                        if (player.plane.state == PlaneState.CRASH and
                            plane_old_state[plane_ix] != PlaneState.CRASH)
                        {
                            try self.crashPlane(plane_ix, commands);
                        }
                    } else {
                        try commands.append(Command{
                            .playPropellerAudio = PropellerAudio{
                                .plane = @as(u1, @intCast(plane_ix)),
                                .on = false,
                                .pan = 0,
                                .pitch = 0,
                            },
                        });
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

                self.updateExplosions(time);
            },
            .inputPressed => |input| {
                // TODO: refactor so that we don't need to keep track of plane old state
                const plane_old_state: [2]PlaneState = .{
                    self.players[0].plane.state,
                    self.players[1].plane.state,
                };
                switch (input) {
                    .plane1_rise => self.players[0].plane.rise(true),
                    .plane1_dive => self.players[0].plane.dive(true),
                    .Plane1Fire => try self.planeFire(commands, 0),
                    .Plane2Rise => self.players[1].plane.rise(true),
                    .Plane2Dive => self.players[1].plane.dive(true),
                    .Plane2Fire => try self.planeFire(commands, 1),
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
                    .plane1_rise => self.players[0].plane.rise(false),
                    .plane1_dive => self.players[0].plane.dive(false),
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

    fn planeFire(self: *GameState, commands: *std.ArrayList(Command), player_ix: u1) !void {
        const player_human_readable: u8 = @as(u8, player_ix) + 1;
        const plane = self.players[player_ix].plane;
        if (plane.state != PlaneState.FLYING) {
            std.debug.print("Plane {d} cannot fire, not flying\n", .{player_human_readable});
            return;
        }
        std.debug.print("Plane {d} firing\n", .{player_human_readable});
        const radians = std.math.degreesToRadians(plane.direction);
        const plane_direction= v(
            std.math.cos(radians),
            std.math.sin(radians),
        );
        try self.shots.append(Shot{
            .position = plane.position + v2.mulScalar(plane_direction, 20),
            .velocity = v2.mulScalar(plane.velocity, 2.0),
        });
        try commands.append(Command{
            .playSoundEffect = SoundEffect.shoot,
        });
    }

    fn updateExplosions(self: *GameState, time: TimePassed) void {
        for (0..self.num_explosions) |ix| {
            var e = &self.explosions[ix];
            e.timePassed(time.deltaTime);
        }
        var i: usize = 0;
        while (i < self.num_explosions) {
            if (!self.explosions[i].alive) {
                std.debug.print("Removing dead explosion at index {}\n", .{i});
                self.num_explosions -= 1;
                self.explosions[i] = self.explosions[self.num_explosions];
            } else i += 1;
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
                .switchScreen = State.game_over,
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

// TODO: Fix plane2 audio not stopping at crash weirdness
// TODO: Switch explosion array to ArrayList
// TODO: shadows beneath planes
