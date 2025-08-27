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
    .initial_position = v(20.0, basics.ground_level),
    .takeoff_length = 150.0,
    .ground_acceleration_per_second = 40.0,
};

const plane2_initial_parameters: PlaneConstants = .{
    .initial_position = v(window_width - 280, basics.ground_level),
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

    pub fn move(self: *Shot, deltaTime: f32) void {
        self.position += v2.mulScalar(self.velocity, deltaTime);
    }

    pub fn hit_ground(self: *Shot) bool {
        return self.position[1] >= basics.ground_level;
    }

    pub fn out_of_bounds(self: *Shot) bool {
        const x = self.position[0];
        const y = self.position[1];
        return x < 0 or x > window_width or y < 0 or self.hit_ground();
    }
};

const Smoke = struct {
    position: V,
    lifetime: f32 = 0.0,
    radius: f32,
    color: u8,
};

pub const GameState = struct {
    clouds: [2]V,
    players: [2]Player,
    the_explosions: std.ArrayList(Explosion) = .empty,
    smoke_trails: std.ArrayList(Smoke) = .empty,
    shots: std.ArrayList(Shot) = .empty,
    ally: std.mem.Allocator,

    pub fn init(ally: std.mem.Allocator) GameState {
        return GameState{
            .clouds = .{ v(555.0, 305.0), v(100.0, 100.0) },
            .players = .{
                .{
                    .plane = Plane.init(plane1_initial_parameters),
                    .resurrect_timeout = 0.0,
                    .lives = 3,
                },
                .{
                    .plane = Plane.init(plane2_initial_parameters),
                    .resurrect_timeout = 0.0,
                    .lives = 3,
                },
            },
            .shots = .empty,
            .ally = ally,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.shots.deinit(self.ally);
        self.the_explosions.deinit(self.ally);
        self.smoke_trails.deinit(self.ally);
    }

    fn removeShotsOutOfBounds(self: *GameState) void {
        // TODO: is it possible to write a generic function for this swapRemove pattern?
        var i: usize = 0;
        while (i < self.shots.items.len) {
            if (self.shots.items[i].out_of_bounds()) _ = self.shots.swapRemove(i) else i += 1;
        }
    }

    pub fn handleMsg(self: *GameState, msg: Msg, commands: *std.ArrayList(Command)) !void {
        switch (msg) {
            .timePassed => |time| {

                // Move shots
                for (self.shots.items) |*shot| {
                    shot.move(time.deltaTime);
                    if (shot.hit_ground()) {
                        const new_explosion = Explosion.init(
                            0.3,
                            shot.position,
                            4,
                            0,
                        );
                        try self.the_explosions.append(self.ally, new_explosion);
                    }
                }
                // Remove shots that are out of bounds
                self.removeShotsOutOfBounds();

                // Does a shot hit plane?
                var shot_ix: usize = 0;
                var remove_shot: bool = undefined;
                while (shot_ix < self.shots.items.len) {
                    const shot = self.shots.items[shot_ix];
                    remove_shot = false;
                    for (0..2) |player_ix| {
                        var plane = &self.players[player_ix].plane;
                        if (self.players[player_ix].resurrect_timeout <= 0) {
                            const distance = v2.len(plane.position - shot.position);
                            if (distance < 20 and plane.state == PlaneState.FLYING) {
                                remove_shot = true;
                                plane.power -= 1;
                                std.debug.print("Plane {d} hit, power left: {d}", .{ player_ix, plane.power });
                                try commands.append(self.ally, Command{ .playSoundEffect = SoundEffect.hit });
                                if (plane.power == 0)
                                    try self.crashPlane(player_ix, commands);
                            }
                        }
                    }
                    if (remove_shot)
                        _ = self.shots.swapRemove(shot_ix)
                    else
                        shot_ix += 1;
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
                        try commands.append(self.ally, propellerCmd);
                        player.plane.timePassed(time.deltaTime);
                        if (player.plane.state == PlaneState.CRASH and
                            plane_old_state[plane_ix] != PlaneState.CRASH)
                        {
                            try self.crashPlane(plane_ix, commands);
                        }
                    } else {
                        try commands.append(self.ally, Command{
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

                try self.updateSmokeTrails(time);

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
                    .plane1_fire => try self.planeFire(commands, 0),
                    .plane2_rise => self.players[1].plane.rise(true),
                    .plane2_dive => self.players[1].plane.dive(true),
                    .plane2_fire => try self.planeFire(commands, 1),
                    .general_action => {
                        self.players[0].plane.power -= 1;
                    },
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
                    .plane2_rise => self.players[1].plane.rise(false),
                    .plane2_dive => self.players[1].plane.dive(false),
                    else => {},
                }
                for (0..2) |plane_ix| {
                    if (self.players[plane_ix].plane.state == PlaneState.CRASH and
                        plane_old_state[plane_ix] != PlaneState.CRASH)
                    {
                        try commands.append(self.ally, Command{ .playSoundEffect = SoundEffect.crash });
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
        const plane_direction = v(
            std.math.cos(radians),
            std.math.sin(radians),
        );
        try self.shots.append(self.ally, Shot{
            .position = plane.position + v2.mulScalar(plane_direction, 20),
            .velocity = v2.mulScalar(plane.velocity, 3.0),
        });
        try commands.append(self.ally, Command{
            .playSoundEffect = SoundEffect.shoot,
        });
    }

    fn updateExplosions(self: *GameState, time: TimePassed) void {
        for (self.the_explosions.items) |*e|
            e.timePassed(time.deltaTime);

        var i: usize = 0;
        while (i < self.the_explosions.items.len) {
            if (!self.the_explosions.items[i].alive)
                _ = self.the_explosions.swapRemove(i)
            else
                i += 1;
        }
    }

    fn updateSmokeTrails(self: *GameState, time: TimePassed) !void {
        for (self.smoke_trails.items) |*smoke| {
            smoke.lifetime += time.deltaTime;
            smoke.position[1] -= 5 * time.deltaTime; // Move smoke up
        }

        var i: usize = 0;
        while (i < self.smoke_trails.items.len) {
            if (self.smoke_trails.items[i].lifetime > 1.0) _ = self.smoke_trails.swapRemove(i) else i += 1;
        }

        for (0..2) |plane_ix| {
            const plane = self.players[plane_ix].plane;
            const color: u8 = std.crypto.random.int(u6);
            if (try plane.makeSmoke(time)) {
                const new_smoke = Smoke{
                    .position = plane.position,
                    .radius = std.crypto.random.float(f32) * 10.0 + 2.5,
                    .color = color + 32,
                };
                try self.smoke_trails.append(self.ally, new_smoke);
            }
        }
    }

    fn crashPlane(self: *GameState, plane_ix: usize, commands: *std.ArrayList(Command)) !void {
        self.players[plane_ix].lives -= 1;
        self.players[plane_ix].resurrect_timeout = 4.0; // Time until plane can be resurrected
        for (0..5) |_| {
            const rad = std.crypto.random.float(f32) * std.math.pi * 2;
            const dist = std.crypto.random.float(f32) * 50.0;
            const new_explosion = explosion.randomExplosionAt(
                self.players[plane_ix].plane.position[0] + dist * std.math.cos(rad),
                self.players[plane_ix].plane.position[1] + dist * std.math.sin(rad),
            );
            try self.the_explosions.append(self.ally, new_explosion);
        }
        try commands.append(self.ally, Command{
            .playSoundEffect = SoundEffect.crash,
        });
        try commands.append(self.ally, Command{
            .playPropellerAudio = PropellerAudio{
                .on = false,
                .plane = 0, // 0 for plane 1
                .pan = 0.0,
                .pitch = 0.0,
            },
        });
        if (self.players[plane_ix].lives == 0) {
            try commands.append(self.ally, Command{
                .playSoundEffect = SoundEffect.game_over,
            });
            try commands.append(self.ally, Command{
                .playPropellerAudio = PropellerAudio{
                    .on = false,
                    .plane = 0,
                },
            });
            try commands.append(self.ally, Command{
                .playPropellerAudio = PropellerAudio{
                    .on = false,
                    .plane = 1,
                },
            });
            try commands.append(self.ally, Command{
                .switchScreen = State.game_over,
            });
        }
    }
};

test "GameState: both clouds move left but the lower cloud moves faster" {
    const ally = std.testing.allocator;
    var commands: std.ArrayList(Command) = .empty;
    defer commands.deinit(ally);
    var gameState: GameState = GameState.init(ally);
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
