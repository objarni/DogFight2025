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
        return GameScreen{
            .clouds = .{ v(5.0, 305.0), v(100.0, 100.0) }
        };
    }
};

pub const Msg = union(enum) {
    inputClicked: Inputs,
    timePassed: f32,
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
    sideEffects: SideEffects,
};

const SideEffects = struct {
    sound: ?Sound,
};

const Sound = enum { boom };

pub fn updateScreen(screen: Screen, msg: Msg) UpdateResult {
    switch (screen) {
        .menu => |_| {
            switch (msg) {
                .inputClicked => |input| {
                    switch (input) {
                        .GeneralAction => {
                            return UpdateResult{
                                .screen = Screen{ .game = GameScreen.init() },
                                .sideEffects = SideEffects{ .sound = Sound.boom },
                            };
                        },
                        else => {},
                    }
                },
                .timePassed => |time| {
                    const t: f32 = time;
                    const numPeriods: f32 = t / 0.5;
                    const intNumPeriods: u32 = @intFromFloat(numPeriods);
                    const two: u32 = 2;
                    const one: u32 = 1;
                    const blink: bool = intNumPeriods % two == one;
                    return UpdateResult{
                        .screen = Screen{ .menu = MenuScreen{ .blink = blink } },
                        .sideEffects = SideEffects{ .sound = null },
                    };
                },
            }
        },
        .game => |_| {},
    }
    return UpdateResult{
        .screen = screen,
        .sideEffects = SideEffects{ .sound = null },
    };
}

const std = @import("std");

test "game starts in menu" {
    const actual: Screen = .init();
    const expected: Screen = .{ .menu = MenuScreen{} };
    try std.testing.expectEqual(expected, actual);
}

test "hitting action button should switch to game and plays Boom sound" {
    const oldScreen: Screen = .init();
    const actual: UpdateResult = updateScreen(oldScreen, Msg{ .inputClicked = Inputs.GeneralAction });
    const expected: UpdateResult = .{
        .screen = Screen{ .game = GameScreen{} },
        .sideEffects = SideEffects{ .sound = Sound.boom },
    };
    try std.testing.expectEqual(expected, actual);
}

test "press space blinks every 0.5 second on menu screen" {
    const oldScreen: Screen = .init();
    const actual: UpdateResult = updateScreen(oldScreen, Msg{ .timePassed = 0.25 });
    try std.testing.expectEqual(actual.screen.menu.blink, false);
    const actual2: UpdateResult = updateScreen(actual.screen, Msg{ .timePassed = 0.75 });
    try std.testing.expectEqual(actual2.screen.menu.blink, true);
}

// TODO
// Make updateScreen return 'side effects' which describe what sounds to play, plane pan/pitch audio, possibly
// even screen transition 'requests'
