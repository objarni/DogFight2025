const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});

const window_width: u16 = 960;
const window_height: u16 = 540;

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

    const planeTex = rl.LoadTexture("assets/plane.png");
    defer rl.UnloadTexture(planeTex);

    const cloudTex = rl.LoadTexture("assets/Cloud.png");
    defer rl.UnloadTexture(cloudTex);

    var currentScreen = screen.Screen.init();
    var drawAverage: i128 = 0;
    var drawAverageCount: u32 = 0;

    const ally : std.mem.Allocator = std.heap.page_allocator;

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();

        // Draw
        const before : i128 = std.time.nanoTimestamp();
        switch (currentScreen) {
            .menu => |_| {
                drawMenu(currentScreen.menu);
            },
            .game => |_| {
                drawGame(currentScreen.game, planeTex, cloudTex);
            },
        }
        const after : i128 = std.time.nanoTimestamp();
        drawAverage += after - before;
        drawAverageCount += 1;
        if(drawAverageCount == 10000) {
            const average: i128 = @divTrunc(@divTrunc(drawAverage, drawAverageCount), 1000);
            std.debug.print("average draw time: {d} ms\n", .{average});
            drawAverage = 0;
            drawAverageCount = 0;
        }

        // Update - handle input
        if (rl.IsKeyPressed(rl.KEY_SPACE)) {
            const result = try screen.updateScreen(
                ally,
                currentScreen,
                screen.Msg{ .inputClicked = screen.Inputs.GeneralAction },
            );
            currentScreen = result.screen;
            if (result.sideEffects.sound != null) {
                rl.PlaySound(boomSound);
            }
        }
        // Update - handle time
        const result = try screen.updateScreen(
            ally,
            currentScreen,
            screen.Msg{
                .timePassed = screen.TimePassed{
                    .totalTime = @floatCast(rl.GetTime()),
                    .deltaTime = @floatCast(rl.GetFrameTime()),
                },
            },
        );
        currentScreen = result.screen;
        if (result.sideEffects.sound != null) {
            rl.PlaySound(boomSound);
        }

        rl.EndDrawing();
    }
}

fn centerText(text: []const u8, y: u16, fontSize: u16, color: rl.Color) void {
    const textWidth: u16 = @intCast(rl.MeasureText(text.ptr, fontSize));
    const xPos: u16 = (window_width - textWidth) / 2;
    rl.DrawText(text.ptr, xPos, y, fontSize, color);
}

fn drawMenu(menu: screen.MenuScreen) void {
    rl.ClearBackground(rl.BLACK);
    const textSize = 40;
    centerText("Dogfight 2025", 180, textSize, rl.GREEN);
    if (menu.blink)
        centerText("Press SPACE to START!", 220, 20, rl.LIGHTGRAY);
}

fn drawGame(state: screen.GameScreen, planeTex: rl.Texture2D, cloudTex: rl.Texture2D) void {
    rl.ClearBackground(rl.RAYWHITE);

    rl.DrawTexture(planeTex, 50, 50, rl.WHITE);
    rl.DrawTexture(planeTex, 150, 50, rl.GREEN);
    for (state.clouds) |cloud| {
        const color = if (cloud[1] < 300) rl.LIGHTGRAY else rl.GRAY;
        rl.DrawTexture(cloudTex, @intFromFloat(cloud[0]), @intFromFloat(cloud[1]), color);
    }
}
