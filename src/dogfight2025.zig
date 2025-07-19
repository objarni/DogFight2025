const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});

const window_width: u32 = 960;
const window_height: u32 = 540;

const screen = @import("Screen.zig");

test {
    _ = @import("Screen.zig");
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

    var currentScreen = screen.Screen.init();

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();

        // Draw
        switch (currentScreen) {
            .menu => |_| {
                drawMenu(currentScreen.menu);
            },
            .game => |_| {
                drawGame(currentScreen.game, planeTexture, boomSound);
            },
        }

        // Update - handle input
        if (rl.IsKeyPressed(rl.KEY_SPACE)) {
            const result = screen.updateScreen(currentScreen, screen.Msg{ .inputClicked = screen.Inputs.GeneralAction });
            currentScreen = result.screen;
        }

        rl.EndDrawing();
    }
}

fn drawMenu(_: screen.MenuScreen) void {
    rl.ClearBackground(rl.RAYWHITE);
    rl.DrawText("DogFight 2025", 200, 180, 20, rl.LIGHTGRAY);
    rl.DrawText("Press SPACE to START!", 200, 220, 20, rl.LIGHTGRAY);
}

fn drawGame(_: screen.GameScreen, planeTexture: rl.Texture2D, boomSound: rl.Sound) void {
    rl.ClearBackground(rl.RAYWHITE);

    rl.DrawText("Press SPACE to PLAY the WAV sound!", 200, 180, 20, rl.LIGHTGRAY);
    if (rl.IsKeyPressed(rl.KEY_SPACE)) rl.PlaySound(boomSound);

    rl.DrawTexture(planeTexture, 50, 50, rl.WHITE);
    rl.DrawTexture(planeTexture, 150, 50, rl.GREEN);
}
