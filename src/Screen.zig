pub const Screen = union(enum) {
    menu: MenuScreen,
    game: GameScreen,

    pub fn init() Screen {
        return Screen{ .menu = MenuScreen{} };
    }
};

pub const MenuScreen = struct {
    // ...
};

pub const GameScreen = struct {
    // ...
};

pub const Msg = union(enum) {
    inputClicked: Inputs,
    // Define messages that can be sent to the model
    // e.g., StartGame, QuitGame, etc.
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
                                .screen = Screen{ .game = GameScreen{} },
                                .sideEffects = SideEffects{ .sound = Sound.boom },
                            };
                        },
                        else => {},
                    }
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

// TODO
// Make updateScreen return 'side effects' which describe what sounds to play, plane pan/pitch audio, possibly
// even screen transition 'requests'
