const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});

const window_width: u32 = 960;
const window_height: u32 = 540;

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

pub fn run() !void {
    rl.InitWindow(window_width, window_height, "DogFight 2025");
    defer rl.CloseWindow();
    rl.InitAudioDevice();
    // rl.ToggleFullscreen();

    const boomSound = rl.LoadSound("assets/boom.wav");
    defer rl.UnloadSound(boomSound);

    const planeTexture = rl.LoadTexture("assets/plane.png");
    defer rl.UnloadTexture(planeTexture);

    var model = Screen.init();

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();

        // Draw
        switch (model) {
            .menu => |_| {
                drawMenu(model.menu);
            },
            .game => |_| {
                drawGame(model.game, planeTexture, boomSound);
            },
        }

        // Update - handle input
        if (rl.IsKeyPressed(rl.KEY_SPACE)) {
            model = updateScreen(model, Msg{ .inputClicked = Inputs.GeneralAction });
        }

        rl.EndDrawing();
    }
}

fn drawMenu(_: MenuScreen) void {
    rl.ClearBackground(rl.RAYWHITE);
    rl.DrawText("DogFight 2025", 200, 180, 20, rl.LIGHTGRAY);
    rl.DrawText("Press SPACE to START!", 200, 220, 20, rl.LIGHTGRAY);

    if (rl.IsKeyPressed(rl.KEY_SPACE)) {
        // Transition to game state
        // This would typically be handled by updating the model
    }
}

fn drawGame(_: GameScreen, planeTexture: rl.Texture2D, boomSound: rl.Sound) void {
    rl.ClearBackground(rl.RAYWHITE);

    rl.DrawText("Press SPACE to PLAY the WAV sound!", 200, 180, 20, rl.LIGHTGRAY);
    if (rl.IsKeyPressed(rl.KEY_SPACE)) rl.PlaySound(boomSound);

    rl.DrawTexture(planeTexture, 50, 50, rl.WHITE);
    rl.DrawTexture(planeTexture, 150, 50, rl.GREEN);
}
