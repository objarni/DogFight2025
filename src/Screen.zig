const Screen = union(enum) {
    menu: MenuScreen,
    game: GameScreen,

    fn init() Screen {
        return Screen{ .menu = MenuScreen{} };
    }
};

const MenuScreen = struct {
    // ...
};

const GameScreen = struct {
    // ...
};

const Msg = union(enum) {
    inputClicked: Inputs,
    // Define messages that can be sent to the model
    // e.g., StartGame, QuitGame, etc.
};

const Inputs = enum {
    Plane1Rise,
    Plane1Dive,
    Plane2Rise,
    Plane2Dive,
    GeneralAction, // This is starting game, pausing/unpausing, switching from game over to menu etc
};

fn updateScreen(screen: Screen, msg: Msg) Screen {
    switch (screen) {
        .menu => |_| {
            switch (msg) {
                .inputClicked => |input| {
                    switch (input) {
                        .GeneralAction => {
                            return Screen{ .game = GameScreen{} };
                        },
                        else => {},
                    }
                },
            }
        },
        .game => |_| {},
    }
    return screen;
}

const std = @import("std");

test "game starts in menu" {
    const actual: Screen = .init();
    const expected: Screen = .{ .menu = MenuScreen{} };
    try std.testing.expectEqual(expected, actual);
}

test "hitting action button should switch to game" {
    const oldScreen: Screen = .init();
    const newScreen = updateScreen(oldScreen, Msg{ .inputClicked = Inputs.GeneralAction });
    try std.testing.expectEqual(
        GameScreen{},
        switch (newScreen) {
            .game => |game| game,
            else => unreachable,
        },
    );
}
