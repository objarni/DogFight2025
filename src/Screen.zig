pub const Screen = union(enum) {
    menu: MenuState,
    game: GameState,

    pub fn init() Screen {
        return Screen{ .menu = MenuState{} };
    }
};

pub const MenuState = struct {
    blink: bool = false,
};

const v2 = @import("v.zig");
const V = v2.V;
const v = v2.v;

const Plane = @import("Plane.zig").Plane;

pub const GameState = struct {
    clouds: [2]V,
    plane1: Plane,

    fn init() GameState {
        return GameState{
            .clouds = .{ v(555.0, 305.0), v(100.0, 100.0) },
            .plane1 = Plane.init(.{
                .initialPos = v(100.0, 200.0),
                .takeoffSpeed = 50.0,
                .groundAccelerationPerS = 10.0,
            }),
        };
    }

    fn handleMsg(ally: std.mem.Allocator, state: GameState, msg: Msg) !?UpdateResult {
        return switch (msg) {
            .timePassed => |time| {

                std.debug.print("plane position: {d}, {d}\n", .{
                    state.plane1.position[0],
                    state.plane1.position[1],
                });

                const deltaX: f32 = time.deltaTime;
                var newState = state;
                newState.clouds[0][0] -= deltaX * 5.0;
                newState.clouds[1][0] -= deltaX * 8.9; // lower cloud moves faster
                newState.plane1 = newState.plane1.timePassed(time.deltaTime);
                return try UpdateResult.init(ally, Screen{ .game = newState }, &.{});
            },
            .inputClicked => |input| {
                var newState = state;
                switch (input) {
                    .Plane1Rise => newState.plane1 = newState.plane1.rise(),
                    .Plane2Rise => {}, // TODO: Implement second plane
                    else => {},
                }
                return try UpdateResult.init(ally, Screen{ .game = newState }, &.{});
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
};

const Command = union(enum) {
    playSound: Sound,
    playPropellerSound: PlaneAudio,
};


pub const Sound = enum { boom };
pub const PlaneAudio = struct {
    plane: i1, // 1 for plane 1, 2 for plane 2
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

pub fn updateScreen(ally: std.mem.Allocator, screen: Screen, msg: Msg) !UpdateResult {
    switch (screen) {
        .menu => |_| {
            switch (msg) {
                .inputClicked => |input| {
                    switch (input) {
                        .GeneralAction => {
                            return UpdateResult.init(
                                ally,
                                Screen{ .game = GameState.init() },
                                &.{Command{ .playSound = Sound.boom }},
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
                    return UpdateResult.init(
                        ally,
                        Screen{ .menu = MenuState{ .blink = blink } },
                        &.{},
                    );
                },
            }
        },
        .game => |state| {
            const maybeResult = try GameState.handleMsg(ally, state, msg);
            if (maybeResult) |result| return result;
        },
    }
    return UpdateResult.init(
        ally,
        screen,
        &.{},
    );
}

const std = @import("std");

test "game starts in menu" {
    const actual: Screen = .init();
    const expected: Screen = .{ .menu = MenuState{} };
    try std.testing.expectEqual(expected, actual);
}

test "hitting action button should switch to game and plays Boom sound" {
    const oldScreen: Screen = .init();
    const actual: UpdateResult = try updateScreen(
        std.testing.allocator,
        oldScreen,
        Msg{ .inputClicked = Inputs.GeneralAction },
    );
    const expected = try UpdateResult.init(
        std.testing.allocator,
        Screen{ .game = GameState.init() },
        &.{Command{ .playSound = Sound.boom }},
    );
    try std.testing.expectEqual(expected, actual);
}

test "press space blinks every 0.5 second on menu screen" {
    const initialScreen: Screen = .init();
    const menuScreenNoTextExpected: UpdateResult = try updateScreen(
        std.testing.allocator,
        initialScreen,
        Msg{ .timePassed = .{ .totalTime = 0.40, .deltaTime = 0.40 } },
    );
    try std.testing.expectEqual(menuScreenNoTextExpected.screen.menu.blink, false);
    const menuScreenTextExpected: UpdateResult = try updateScreen(
        std.testing.allocator,
        menuScreenNoTextExpected.screen,
        Msg{ .timePassed = .{ .totalTime = 0.75, .deltaTime = 0.35 } },
    );
    try std.testing.expectEqual(menuScreenTextExpected.screen.menu.blink, true);
}

test "both clouds move left by, but the lower cloud moves faster" {
    const initialScreen: Screen = Screen{ .game = GameState.init() };
    const highCloudX: f32 = initialScreen.game.clouds[0][0];
    const lowCloudX: f32 = initialScreen.game.clouds[1][0];
    const updatedScreen: UpdateResult = try updateScreen(
        std.testing.allocator,
        initialScreen,
        Msg{ .timePassed = TimePassed{ .totalTime = 1.0, .deltaTime = 1.0 } },
    );
    try std.testing.expectApproxEqAbs(highCloudX - 5.0, updatedScreen.screen.game.clouds[0][0], 0.1);
    try std.testing.expectApproxEqAbs(lowCloudX - 8.9, updatedScreen.screen.game.clouds[1][0], 0.1);
}

// TODO
// wrap clouds around the screen
// display airplanes left (10 to start with)
// add planes
// figure out how to write unit tests that avoid hard coded values (so simple to tweak in the future)
// figure out how to express state machines in Zig
// Break out update logic for menu and game screens into separate functions
// 'Collect' all commands from updates and execute in a loop after all updates?
