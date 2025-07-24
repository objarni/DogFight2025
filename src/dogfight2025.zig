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
    rl.SetConfigFlags(rl.FLAG_WINDOW_HIGHDPI);
    rl.InitWindow(window_width, window_height, "DogFight 2025");
    defer rl.CloseWindow();
    rl.InitAudioDevice();
    // rl.ToggleFullscreen();

    const screen_w = rl.GetScreenWidth();
    const screen_h = rl.GetScreenHeight();
    const fb_w = rl.GetRenderWidth();
    const fb_h = rl.GetRenderHeight();
    std.debug.print("Window: {d}x{d}, Framebuffer: {d}x{d}\n", .{
        screen_w, screen_h, fb_w, fb_h,
    });

    const boomSound = rl.LoadSound("assets/boom.wav");
    defer rl.UnloadSound(boomSound);

    const planeTex = rl.LoadTexture("assets/plane.png");
    if (!rl.IsTextureValid(planeTex)) {
        std.debug.print("Texture failed!\n", .{});
    }
    defer rl.UnloadTexture(planeTex);

    const cloudTex = rl.LoadTexture("assets/CloudBig.png");
    if (!rl.IsTextureValid(cloudTex)) {
        std.debug.print("Texture failed!\n", .{});
    }
    defer rl.UnloadTexture(cloudTex);

    var currentScreen = screen.Screen.init();
    var drawAverage: i128 = 0;
    var drawAverageCount: u32 = 0;

    const ally: std.mem.Allocator = std.heap.page_allocator;

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();

        // Draw
        const before: i128 = std.time.nanoTimestamp();
        switch (currentScreen) {
            .menu => |_| {
                drawMenu(currentScreen.menu);
            },
            .game => |_| {
                drawGame(currentScreen.game, planeTex, cloudTex);
            },
        }
        const after: i128 = std.time.nanoTimestamp();
        drawAverage += after - before;
        drawAverageCount += 1;
        if (drawAverageCount == 10000) {
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
            for (result.commands.items) |command| {
                switch (command) {
                    .playSound => |sound| {
                        if (sound == screen.Sound.boom) {
                            rl.PlaySound(boomSound);
                        }
                    },
                    .playPropellerSound => |_| {
                    }
                }
            }
        }
        if (rl.IsKeyPressed(rl.KEY_A)) {
            const result = try screen.updateScreen(
                ally,
                currentScreen,
                screen.Msg{ .inputClicked = screen.Inputs.Plane1Rise },
            );
            currentScreen = result.screen;
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

        rl.EndDrawing();
    }
}

fn centerText(text: []const u8, y: u16, fontSize: u16, color: rl.Color) void {
    const textWidth: u16 = @intCast(rl.MeasureText(text.ptr, fontSize));
    const xPos: u16 = (window_width - textWidth) / 2;
    rl.DrawText(text.ptr, xPos, y, fontSize, color);
}

fn drawMenu(menu: screen.MenuState) void {
    rl.ClearBackground(rl.YELLOW);
    const textSize = 40;
    centerText("Dogfight 2025", 180, textSize, rl.GREEN);
    if (menu.blink)
        centerText("Press SPACE to START!", 220, 20, rl.LIGHTGRAY);
}

fn drawGame(state: screen.GameState, planeTex: rl.Texture2D, cloudTex: rl.Texture2D) void {
    rl.ClearBackground(rl.RAYWHITE);

    rl.DrawCircle(200, 200, 50, rl.RED);

    rl.DrawTexture(planeTex, 50, 50, rl.WHITE);
    rl.DrawTexture(planeTex, 150, 50, rl.GREEN);

    rl.DrawTexture(
        planeTex,
        @intFromFloat(state.plane1.position[0]),
        @intFromFloat(state.plane1.position[1]),
        rl.WHITE,
    );

    for (state.clouds) |cloud| {
        const color = if (cloud[1] < 300) rl.LIGHTGRAY else rl.GRAY;
        rl.DrawTexture(cloudTex, @intFromFloat(cloud[0]), @intFromFloat(cloud[1]), color);
    }
}
