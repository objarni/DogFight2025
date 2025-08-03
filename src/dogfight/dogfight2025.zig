const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});

const window_width: u16 = 960;
const window_height: u16 = 540;

const screen = @import("Screen.zig");
const Explosion = @import("Explosion.zig").Explosion;

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
        .boom = rl.LoadSound("assets/Boom.wav"),
        .crash = rl.LoadSound("assets/Crash.mp3"),
        .game_over = rl.LoadSound("assets/GameOver.mp3"),
        .plane = rl.LoadTexture("assets/Plane.png"),
        .cloud = rl.LoadTexture("assets/CloudBig.png"),
        .propeller = rl.LoadMusicStream("assets/PropellerPlane.mp3"),
        .background = rl.LoadTexture("assets/Background.png"),
    };
    defer {
        rl.UnloadSound(res.boom);
        rl.UnloadSound(res.crash);
        rl.UnloadTexture(res.plane);
        rl.UnloadTexture(res.cloud);
        rl.UnloadTexture(res.background);
        rl.UnloadMusicStream(res.propeller);
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

    var currentScreen : screen.Screen = .init(ally);
    defer currentScreen.deinit();
    var drawAverage: i128 = 0;
    var drawAverageCount: u32 = 0;

    var allMsgs: std.ArrayList(screen.Msg) = .init(ally);
    defer allMsgs.deinit();
    try allMsgs.ensureTotalCapacity(10);

    var allCommands: std.ArrayList(screen.Command) = .init(ally);
    defer ally.free(allCommands.items);
    try allCommands.ensureTotalCapacity(10);

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
        rl.UpdateMusicStream(res.propeller);

        allMsgs.clearRetainingCapacity();
        collectMessages(&allMsgs);
        // std.debug.print("Collected messages: {d}\n", .{allMsgs.items.len});
        for (allMsgs.items) |msg| {
            var cmdsFromHandlingMsg: [10]screen.Command = undefined;
            const commandCount = try currentScreen.handleMsg(
                ally,
                msg,
                &cmdsFromHandlingMsg,
            );
            // std.debug.print("Commands from handling message: {d}\n", .{commandCount});
            const cmds = cmdsFromHandlingMsg[0..@intCast(commandCount)];
            executeCommands(ally, cmds, res, &currentScreen);
        }

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
    drawExplosion(menu.e);
    for (menu.es.items) |e| {
        drawExplosion(e);
    }
}

fn drawExplosion(e: Explosion) void {
    if (!e.alive) return;

    rl.DrawCircle(
        @intFromFloat(e.outerPosition[0]),
        @intFromFloat(e.outerPosition[1]),
        e.outerDiameter / 2 + 1,
        rl.ORANGE,
    );
    rl.DrawCircle(
        @intFromFloat(e.outerPosition[0]),
        @intFromFloat(e.outerPosition[1]),
        e.outerDiameter / 2,
        rl.YELLOW,
    );
    rl.DrawCircle(
        @intFromFloat(e.innerPosition[0]),
        @intFromFloat(e.innerPosition[1]),
        e.innerDiameter / 2,
        rl.SKYBLUE,
    );
}

const Resources = struct {
    boom: rl.Sound,
    crash: rl.Sound,
    game_over: rl.Sound,
    plane: rl.Texture2D,
    cloud: rl.Texture2D,
    background: rl.Texture2D,
    propeller: rl.Music,
};

fn drawGame(
    state: screen.GameState,
    res: Resources,
) void {
    rl.ClearBackground(rl.SKYBLUE);

    rl.DrawCircle(window_width-50, window_height-100, 50, rl.RED);
    rl.DrawTexture(res.background, 0, window_height - res.background.height, rl.WHITE);

    const sourceR = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(res.plane.width),
        .height = @floatFromInt(res.plane.height),
    };
    const planeWidth: f32 = @floatFromInt(res.plane.width);
    const planeHeight: f32 = @floatFromInt(res.plane.height);
    const destR = rl.Rectangle{
        .x = state.plane1.position[0],
        .y = state.plane1.position[1],
        .width = planeWidth,
        .height = planeHeight,
    };
    const anchor = rl.Vector2{
        .x = planeWidth / 2,
        .y = planeHeight / 2,
    };
    rl.DrawTexturePro(res.plane, sourceR, destR, anchor, state.plane1.direction, rl.WHITE);

    for (state.clouds) |cloud| {
        const color = if (cloud[1] < 300) rl.LIGHTGRAY else rl.GRAY;
        rl.DrawTexture(res.cloud, @intFromFloat(cloud[0]), @intFromFloat(cloud[1]), color);
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
                std.debug.print("Playing sound effect: {}\n", .{sfx});
                switch (sfx) {
                    .boom => {
                        rl.PlaySound(res.boom);
                    },
                    .crash => {
                        rl.PlaySound(res.crash);
                        std.debug.print("Playing crash sound effect\n", .{});
                    },
                    .game_over => {
                        rl.PlaySound(res.game_over);
                        std.debug.print("Playing game over sound effect\n", .{});
                    }
                }
            },
            .playPropellerAudio => |audio| {
                if (audio.on) {
                    if (!rl.IsMusicStreamPlaying(res.propeller)) {
                        rl.PlayMusicStream(res.propeller);
                    }
                    rl.SetMusicPitch(res.propeller, audio.pitch);
                    rl.SetMusicPan(res.propeller, audio.pan);
                } else {
                    if (rl.IsMusicStreamPlaying(res.propeller))
                        rl.StopMusicStream(res.propeller);
                }
            },
            .switchSubScreen => |subScreen| {
                std.debug.print("Switching to sub-screen: {}\n", .{subScreen});
                currentScreen.deinit();
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
