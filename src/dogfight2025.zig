const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});

const window_width: u32 = 960;
const window_height: u32 = 540;

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
