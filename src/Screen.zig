pub const Screen = union(enum) {
    menu: MenuState,
    game: GameState,

    pub fn init(ally: std.mem.Allocator) Screen {
        return Screen{ .menu = .init(ally) };
    }
};

const Explosion = @import("Explosion.zig").Explosion;

const window_width: u16 = 960;
const window_height: u16 = 540;

pub const MenuState = struct {
    blink: bool = false,
    es: std.ArrayList(Explosion),
    e: Explosion,

    pub fn init(ally: std.mem.Allocator) MenuState {
        return MenuState{
            .blink = false,
            .e = Explosion.init(
                2.0,
                v(180.0, 270.0),
                100.0,
                50.0,
                std.math.pi / 4.0,
            ),
            .es = std.ArrayList(Explosion).init(ally),
        };
    }
};

const v2 = @import("V.zig");
const V = v2.V;
const v = v2.v;

const Plane = @import("Plane.zig").Plane;
const PlaneState = @import("Plane.zig").PlaneState;

pub const GameState = struct {
    clouds: [2]V,
    plane1: Plane,

    pub fn init() GameState {
        return GameState{
            .clouds = .{ v(555.0, 305.0), v(100.0, 100.0) },
            .plane1 = Plane.init(.{
                .initialPos = v(100.0, 200.0),
                .takeoffSpeed = 50.0,
                .groundAccelerationPerS = 10.0,
            }),
        };
    }

    fn handleMessage(self: *GameState, ally: std.mem.Allocator, msg: Msg) !?UpdateResult {
        return switch (msg) {
            .timePassed => |time| {
                // Pitch of propeller audio should be based on plane speed
                // but with minimum 0.5 and maximum 2.0
                const propellerPitch: f32 = @max(0.5, @min(2.0, self.plane1.velocity[0] / 50.0));
                // Panning of propeller audio should be based on plane position
                // but with minimum 0.0 and maximum 1.0
                const propellerPan: f32 = @max(0.0, @min(1.0, self.plane1.position[0] / window_width));
                const propellerOn = self.plane1.state != PlaneState.STILL;

                const propellerCmd = Command{
                    .playPropellerAudio = PropellerAudio{
                        .plane = 0, // 0 for plane 1
                        .on = propellerOn,
                        .pan = propellerPan,
                        .pitch = propellerPitch,
                    },
                };

                const deltaX: f32 = time.deltaTime;
                self.clouds[0][0] -= deltaX * 5.0;
                self.clouds[1][0] -= deltaX * 8.9; // lower cloud moves faster
                self.plane1 = self.plane1.timePassed(time.deltaTime);

                return try UpdateResult.init(
                    ally,
                    Screen{ .game = self.* },
                    &.{propellerCmd},
                );
            },
            .inputClicked => |input| {
                const plane1oldState = self.plane1.state;
                switch (input) {
                    .Plane1Rise => self.plane1 = self.plane1.rise(),
                    .Plane2Rise => {}, // TODO: Implement second plane
                    else => {},
                }
                if (self.plane1.state == PlaneState.CRASH and plane1oldState != PlaneState.CRASH) {
                    return try UpdateResult.init(ally, Screen{ .game = self.* }, &.{
                        Command{ .playSoundEffect = SoundEffect.crash },
                    });
                }
                return try UpdateResult.init(ally, Screen{ .game = self.* }, &.{});
            },
        };
    }
};

pub const TimePassed = struct {
    deltaTime: f32,
    totalTime: f32,
};

pub const Msg = union(enum) {
    inputClicked: Inputs,
    timePassed: TimePassed,
};

pub const Inputs = enum {
    Plane1Rise,
    Plane1Dive,
    Plane2Rise,
    Plane2Dive,
    GeneralAction, // This is starting game, pausing/unpausing, switching from game over to menu etc
};

pub const UpdateResult = struct {
    screen: Screen,
    commands: std.ArrayList(Command),

    fn init(ally: std.mem.Allocator, screen: Screen, cmds: []const Command) !UpdateResult {
        return UpdateResult{
            .screen = screen,
            .commands = try arrayListOf(Command, ally, cmds),
        };
    }

    fn deinit(self: UpdateResult) void {
        self.commands.deinit();
    }
};

pub const Command = union(enum) {
    playSoundEffect: SoundEffect,
    playPropellerAudio: PropellerAudio,
    switchSubScreen: SubScreen,
};

pub const SubScreen = enum {
    menu,
    game,
};

pub const SoundEffect = enum {
    boom,
    crash,
};

pub const PropellerAudio = struct {
    plane: u1, // 0 for plane 1, 1 for plane 2
    on: bool, // true if sound is on, false if muted
    pan: f32, // 0.0 to 1.0, where 0.0 is left, 1.0 is right
    pitch: f32, // 1.0 is normal, 0.5 is half speed, 2.0 is double speed
};

fn arrayListOf(comptime T: type, ally: std.mem.Allocator, items: []const T) !std.ArrayList(T) {
    var list = std.ArrayList(T).init(ally);
    for (items) |item| {
        try list.append(item);
    }
    return list;
}

fn rndFrac() f32 {
    const random = std.crypto.random;
    return random.float(f32);
}

pub fn updateScreen(ally: std.mem.Allocator, screen: *Screen, msg: Msg) !UpdateResult {
    switch (screen.*) {
        .menu => |menu| {
            switch (msg) {
                .inputClicked => |input| {
                    const boomCmd = Command{
                        .playSoundEffect = SoundEffect.boom,
                    };
                    switch (input) {
                        .GeneralAction => {
                            return UpdateResult.init(
                                ally,
                                screen.*,
                                &.{
                                    boomCmd,
                                    Command{ .switchSubScreen = SubScreen.game },
                                },
                            ) catch |err| {
                                std.debug.panic("Failed to create UpdateResult: {}", .{err});
                            };
                        },
                        else => {},
                    }
                },
                .timePassed => |time| {
                    const numPeriods: f32 = time.totalTime / 0.5;
                    const intNumPeriods: u32 = @intFromFloat(numPeriods);
                    const blink: bool = intNumPeriods % 2 == 1;
                    var newE = menu.e;
                    newE.timePassed(time.deltaTime);
                    var newES = menu.es;
                    if (newE.ageSeconds >= newE.lifetimeSeconds) {
                        newE = randomExplosion();
                        try newES.append(randomExplosion());
                        try newES.append(randomExplosion());
                    }
                    for (0..newES.items.len) |ix| {
                        newES.items[ix].timePassed(time.deltaTime);
                    }
                    // Remove dead explosions
                    var i: usize = 0;
                    while (i < newES.items.len) {
                        if (!newES.items[i].alive) {
                            std.debug.print("Removing dead explosion at index {}\n", .{i});
                            _ = newES.swapRemove(i);
                        }
                        else
                            i += 1;
                    }
                    return UpdateResult.init(
                        ally,
                        Screen{ .menu = MenuState{
                            .blink = blink,
                            .e = newE,
                            .es = newES,
                        } },
                        &.{},
                    );
                },
            }
        },
        .game => |state| {
            var newState = state;
            const maybeResult = try newState.handleMessage(ally, msg);
            if (maybeResult) |result| return result;
        },
    }
    return UpdateResult.init(
        ally,
        screen.*,
        &.{},
    );
}

fn randomExplosion() Explosion {
    return Explosion.init(
        3.0 * rndFrac() + 0.5,
        v(
            window_width * rndFrac(),
            window_height * rndFrac(),
        ),
        100.0 * rndFrac(),
        0.0,
        std.math.pi * 2 * rndFrac(),
    );
}

const std = @import("std");

test "game starts in menu" {
    const ally = std.testing.allocator;
    const actual: Screen = .init(ally);
    const expected: Screen = .{ .menu = MenuState.init(ally) };
    try std.testing.expectEqual(expected, actual);
}

test "hitting action button should switch to game and plays Boom sound" {
    const ally = std.testing.allocator;
    var oldScreen: Screen = .init(ally);
    const actual: UpdateResult = try updateScreen(
        std.testing.allocator,
        &oldScreen,
        Msg{ .inputClicked = Inputs.GeneralAction },
    );
    defer actual.deinit();
    const expected = try UpdateResult.init(
        std.testing.allocator,
        Screen{ .game = GameState.init() },
        &.{
            Command{ .playSoundEffect = SoundEffect.boom },
            Command{ .switchSubScreen = SubScreen.game },
        },
    );
    defer expected.deinit();
    try std.testing.expectEqualSlices(Command, expected.commands.items, actual.commands.items);
}

test "press space blinks every 0.5 second on menu screen" {
    const ally = std.testing.allocator;
    var initialScreen: Screen = .init(ally);
    var menuScreenNoTextExpected: UpdateResult = try updateScreen(
        std.testing.allocator,
        &initialScreen,
        Msg{ .timePassed = .{ .totalTime = 0.40, .deltaTime = 0.40 } },
    );
    defer menuScreenNoTextExpected.deinit();
    try std.testing.expectEqual(menuScreenNoTextExpected.screen.menu.blink, false);
    const menuScreenTextExpected: UpdateResult = try updateScreen(
        std.testing.allocator,
        &menuScreenNoTextExpected.screen,
        Msg{ .timePassed = .{ .totalTime = 0.75, .deltaTime = 0.35 } },
    );
    defer menuScreenTextExpected.deinit();
    try std.testing.expectEqual(menuScreenTextExpected.screen.menu.blink, true);
}

test "both clouds move left by, but the lower cloud moves faster" {
    var gameState: GameState = GameState.init();
    const highCloudX: f32 = gameState.clouds[0][0];
    const lowCloudX: f32 = gameState.clouds[1][0];
    const result: ?UpdateResult = try gameState.handleMessage(
        std.testing.allocator,
        Msg{ .timePassed = TimePassed{ .totalTime = 1.0, .deltaTime = 1.0 } },
    );
    if (result) |newScreen| {
        defer newScreen.deinit();
        try std.testing.expectApproxEqAbs(highCloudX - 5.0, newScreen.screen.game.clouds[0][0], 0.1);
        try std.testing.expectApproxEqAbs(lowCloudX - 8.9, newScreen.screen.game.clouds[1][0], 0.1);
    } else {
        std.debug.print("Expected a result from GameState.handleMsg, but got null\n", .{});
        try std.testing.expect(false);
    }
}

// TODO: to avoid copies, updateScreen could be member, and get a pointer to var Screen
// TODO: wrap clouds around the screen
// TODO: display airplanes left (10 to start with)
// TODO: add planes
// TODO: Break out update logic for menu into separate function
// TODO: anime style explosion via two-three spheres
// TODO: particle system for explosion and debris
