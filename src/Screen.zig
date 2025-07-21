pub const Screen = union(enum) {
    menu: MenuScreen,
    game: GameScreen,

    pub fn init() Screen {
        return Screen{ .menu = MenuScreen{} };
    }
};

pub const MenuScreen = struct {
    blink: bool = false,
};

const V: type = @Vector(2, f32);
fn v(x: f32, y: f32) V {
    return V{ x, y };
}

pub const GameScreen = struct {
    clouds: [2]V,

    fn init() GameScreen {
        return GameScreen{ .clouds = .{ v(555.0, 305.0), v(100.0, 100.0) } };
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
};

const SideEffects = struct {
    sound: ?Sound,
};

pub const Sound = enum { boom };

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
                                Screen{ .game = GameScreen.init() },
                                &.{Command{ .playSound = Sound.boom }},
                            ) catch |err| {
                                std.debug.panic("Failed to create UpdateResult: {}", .{err});
                            };
                        },
                        else => {},
                    }
                },
                .timePassed => |time| {
                    const t: f32 = time.totalTime;
                    const numPeriods: f32 = t / 0.5;
                    const intNumPeriods: u32 = @intFromFloat(numPeriods);
                    const two: u32 = 2;
                    const blink: bool = intNumPeriods % two == 1;
                    return UpdateResult.init(
                        ally,
                        Screen{ .menu = MenuScreen{ .blink = blink } },
                        &.{},
                    );
                },
            }
        },
        .game => |state| {
            switch (msg) {
                .timePassed => |time| {
                    const deltaX: f32 = time.deltaTime;
                    var newState = state;
                    newState.clouds[0][0] -= deltaX * 5.0;
                    newState.clouds[1][0] -= deltaX * 8.9; // lower cloud moves faster
                    return UpdateResult.init(ally, Screen{ .game = newState }, &.{});
                },
                else => {},
            }
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
    const expected: Screen = .{ .menu = MenuScreen{} };
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
        Screen{ .game = GameScreen.init() },
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
    const initialScreen: Screen = Screen{ .game = GameScreen.init() };
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
// add planes
