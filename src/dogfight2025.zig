const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});

const window_width: u32 = 960;
const window_height: u32 = 540;

// Loosely TEA inspired architecture
// Model = All state of the game
// Msg = Messages that can be sent to the model
// Update = Function that updates the model given a message
// View = Function that draws the model to the screen, this is most different from TEA
//        since it will call raylib directly rather than returning a list of commands

const Model = union(enum) {
    menu: MenuModel,
    game: GameModel,

    fn init() Model {
        return Model{ .menu = MenuModel{} };
    }
};

const MenuModel = struct {
    // ...
};

const GameModel = struct {
    // ...
};

const Msg = union(enum) {
    keyPressed: Keys,
    // Define messages that can be sent to the model
    // e.g., StartGame, QuitGame, etc.
};

const Keys = enum {
    Plane1Rise,
    Plane1Dive,
    Plane2Rise,
    Plane2Dive,
    GeneralAction, // This is starting game, pausing/unpausing, switching from game over to menu etc
};

fn updateModel(model: Model, msg: Msg) Model {
    switch(model)
    {
        .menu => |_| {
            switch(msg) {
                .keyPressed => |key| {
                    // Handle key presses in the menu
                    switch (key) {
                        .GeneralAction => {
                            return Model{ .game = GameModel{} };
                        },
                        else => {},
                    }
                }
            }
        },
        .game => |_| {
        },
    }
    return model; // Return the updated model
}



test "scene transition behaviour" {
    // game starts in menu
    const actual: Model = .init();
    const expected: Model = .{ .menu = MenuModel{} };
    try std.testing.expectEqual(expected, actual);

    // hitting action button should switch to game
    const newState = updateModel(actual, Msg{ .keyPressed = Keys.GeneralAction });
    try std.testing.expectEqual(
        GameModel{},
        switch (newState) {
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

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.RAYWHITE);

        rl.DrawText("Press SPACE to PLAY the WAV sound!", 200, 180, 20, rl.LIGHTGRAY);
        if (rl.IsKeyPressed(rl.KEY_SPACE)) rl.PlaySound(boomSound);

        rl.DrawTexture(planeTexture, 50, 50, rl.WHITE);
        rl.DrawTexture(planeTexture, 150, 50, rl.GREEN);

        rl.EndDrawing();
    }
}
