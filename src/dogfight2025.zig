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
    //
    const res = Resources{
        .boomSound = rl.LoadSound("assets/Boom.wav"),
        .crashSound = rl.LoadSound("assets/Crash.mp3"),
        .planeTex = rl.LoadTexture("assets/Plane.png"),
        .cloudTex = rl.LoadTexture("assets/CloudBig.png"),
        .propellerAudio1 = rl.LoadMusicStream("assets/PropellerPlane.mp3"),
    };
    defer {
        rl.UnloadSound(res.boomSound);
        rl.UnloadSound(res.crashSound);
        rl.UnloadTexture(res.planeTex);
        rl.UnloadTexture(res.cloudTex);
        rl.UnloadMusicStream(res.propellerAudio1);
    }

    const screen_w = rl.GetScreenWidth();
    const screen_h = rl.GetScreenHeight();
    const fb_w = rl.GetRenderWidth();
    const fb_h = rl.GetRenderHeight();
    std.debug.print("Window: {d}x{d}, Framebuffer: {d}x{d}\n", .{
        screen_w, screen_h, fb_w, fb_h,
    });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();

    var currentScreen = screen.Screen.init(ally);
    var drawAverage: i128 = 0;
    var drawAverageCount: u32 = 0;

    var allMsgs: std.ArrayList(screen.Msg) = .init(ally);
    defer ally.free(allMsgs.items);
    try allMsgs.ensureTotalCapacity(10);

    while (!rl.WindowShouldClose()) {
        // if (!rl.IsMusicStreamPlaying(res.propellerAudio1))
        //     rl.PlayMusicStream(res.propellerAudio1);
        rl.BeginDrawing();

        // Draw
        const before: i128 = std.time.nanoTimestamp();
        switch (currentScreen) {
            .menu => |_| {
                drawMenu(currentScreen.menu);
            },
            .game => |_| {
                drawGame(currentScreen.game, res);
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

        // Update music streams
        rl.UpdateMusicStream(res.propellerAudio1);

        collectMessages(&allMsgs);
        for (allMsgs.items) |msg| {
            const result = try screen.updateScreen(
                ally,
                &currentScreen,
                msg,
            );
            currentScreen = result.screen;
            executeCommands(ally, result.commands.items, res, &currentScreen);
            result.commands.deinit();
        }
        allMsgs.clearAndFree();

        rl.EndDrawing();
    }

    const leaked = gpa.detectLeaks();
    std.debug.print("Leaked allocations: {any}\n", .{leaked});
}

fn collectMessages(allMsgs: *std.ArrayList(screen.Msg)) void {
    if (rl.IsKeyPressed(rl.KEY_SPACE))
        allMsgs.append(screen.Msg{ .inputClicked = screen.Inputs.GeneralAction }) catch |err| {
            std.debug.print("Error appending message: {}\n", .{err});
        };
    if (rl.IsKeyPressed(rl.KEY_A))
        allMsgs.append(screen.Msg{ .inputClicked = screen.Inputs.Plane1Rise }) catch |err| {
            std.debug.print("Error appending message: {}\n", .{err});
        };
    const timePassed = screen.Msg{ .timePassed = screen.TimePassed{
        .totalTime = @floatCast(rl.GetTime()),
        .deltaTime = @floatCast(rl.GetFrameTime()),
    } };
    allMsgs.append(timePassed) catch |err| {
        std.debug.print("Error appending time message: {}\n", .{err});
    };
}

fn centerText(text: []const u8, y: u16, fontSize: u16, color: rl.Color) void {
    const textWidth: u16 = @intCast(rl.MeasureText(text.ptr, fontSize));
    const xPos: u16 = (window_width - textWidth) / 2;
    rl.DrawText(text.ptr, xPos, y, fontSize, color);
}

fn drawMenu(menu: screen.MenuState) void {
    rl.ClearBackground(rl.SKYBLUE);
    const textSize = 40;
    centerText("Dogfight 2025", 180, textSize, rl.DARKGREEN);
    if (menu.blink)
        centerText("Press SPACE to START!", 220, 20, rl.DARKGRAY);
    rl.DrawCircle(
        @intFromFloat(menu.e.outerPosition[0]),
        @intFromFloat(menu.e.outerPosition[1]),
        menu.e.outerDiameter / 2 + 1,
        rl.ORANGE,
    );
    rl.DrawCircle(
        @intFromFloat(menu.e.outerPosition[0]),
        @intFromFloat(menu.e.outerPosition[1]),
        menu.e.outerDiameter / 2,
        rl.YELLOW,
    );
    rl.DrawCircle(
        @intFromFloat(menu.e.innerPosition[0]),
        @intFromFloat(menu.e.innerPosition[1]),
        menu.e.innerDiameter / 2,
        rl.SKYBLUE,
    );
}

const Resources = struct {
    boomSound: rl.Sound,
    crashSound: rl.Sound,
    planeTex: rl.Texture2D,
    cloudTex: rl.Texture2D,
    propellerAudio1: rl.Music,
};

fn drawGame(
    state: screen.GameState,
    res: Resources,
) void {
    rl.ClearBackground(rl.RAYWHITE);

    rl.DrawCircle(200, 200, 50, rl.RED);

    rl.DrawTexture(res.planeTex, 50, 50, rl.WHITE);
    rl.DrawTexture(res.planeTex, 150, 50, rl.GREEN);

    rl.DrawTexture(
        res.planeTex,
        @intFromFloat(state.plane1.position[0]),
        @intFromFloat(state.plane1.position[1]),
        rl.WHITE,
    );

    for (state.clouds) |cloud| {
        const color = if (cloud[1] < 300) rl.LIGHTGRAY else rl.GRAY;
        rl.DrawTexture(res.cloudTex, @intFromFloat(cloud[0]), @intFromFloat(cloud[1]), color);
    }
}

fn executeCommands(
    ally: std.mem.Allocator,
    cmds: []const screen.Command,
    res: Resources,
    currentScreen: *screen.Screen,
) void {
    for (cmds) |command| {
        switch (command) {
            .playSoundEffect => |sfx| {
                switch (sfx) {
                    .boom => {
                        rl.PlaySound(res.boomSound);
                        std.debug.print("Playing boom sound effect\n", .{});
                    },
                    .crash => {
                        rl.PlaySound(res.crashSound);
                        std.debug.print("Playing crash sound effect\n", .{});
                    },
                }
            },
            .playPropellerAudio => |audio| {
                if (audio.on) {
                    if (!rl.IsMusicStreamPlaying(res.propellerAudio1)) {
                        rl.PlayMusicStream(res.propellerAudio1);
                    }
                    rl.SetMusicPitch(res.propellerAudio1, audio.pitch);
                    // std.debug.print("Playing propeller audio with pitch: {}\n", .{audio.pitch});
                    rl.SetMusicPan(res.propellerAudio1, audio.pan);
                    // std.debug.print("Setting propeller audio pan: {}\n", .{audio.pan});
                } else {
                    if (rl.IsMusicStreamPlaying(res.propellerAudio1))
                        rl.StopMusicStream(res.propellerAudio1);
                }
            },
            .switchSubScreen => |subScreen| {
                std.debug.print("Switching to sub-screen: {}\n", .{subScreen});
                switch (subScreen) {
                    .menu => |_| {
                        currentScreen.* = screen.Screen{
                            .menu = screen.MenuState.init(ally),
                        };
                    },
                    .game => |_| {
                        currentScreen.* = screen.Screen{
                            .game = screen.GameState.init(),
                        };
                    },
                }
            },
        }
    }
}
