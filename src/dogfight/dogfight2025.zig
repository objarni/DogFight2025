const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});

const basics = @import("basics.zig");
const Msg = basics.Msg;
const Command = basics.Command;
const Inputs = basics.Inputs;
const TimePassed = basics.TimePassed;
const Screen = basics.State;

const window_width: u16 = 960;
const window_height: u16 = 540;

const Explosion = @import("Explosion.zig").Explosion;
const MenuState = @import("MenuState.zig").MenuState;
const GameState = @import("GameState.zig").GameState;

pub fn run() !void {
    const res = initRaylib();
    defer deinitRaylib(res);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const ally = gpa.allocator();

    try mainLoop(ally, res);

    const leaked = gpa.detectLeaks();
    std.debug.print("Leaked allocations: {any}\n", .{leaked});
}

fn initRaylib() Resources {
    rl.SetConfigFlags(rl.FLAG_WINDOW_HIGHDPI);
    rl.InitWindow(window_width, window_height, "DogFight 2025");
    rl.InitAudioDevice();

    const res = Resources{
        .boom = rl.LoadSound("assets/Boom.wav"),
        .crash = rl.LoadSound("assets/Crash.mp3"),
        .game_over = rl.LoadSound("assets/GameOver.mp3"),
        .plane = rl.LoadTexture("assets/Plane.png"),
        .cloud = rl.LoadTexture("assets/CloudBig.png"),
        .propeller = rl.LoadMusicStream("assets/PropellerPlane.mp3"),
        .background = rl.LoadTexture("assets/Background.png"),
    };

    const screen_w = rl.GetScreenWidth();
    const screen_h = rl.GetScreenHeight();
    const fb_w = rl.GetRenderWidth();
    const fb_h = rl.GetRenderHeight();
    std.debug.print("Window: {d}x{d}, Framebuffer: {d}x{d}\n", .{
        screen_w, screen_h, fb_w, fb_h,
    });

    return res;
}

fn deinitRaylib(res: Resources) void {
    rl.UnloadSound(res.boom);
    rl.UnloadSound(res.crash);
    rl.UnloadSound(res.game_over);
    rl.UnloadTexture(res.plane);
    rl.UnloadTexture(res.cloud);
    rl.UnloadTexture(res.background);
    rl.UnloadMusicStream(res.propeller);
    rl.CloseAudioDevice();
    rl.CloseWindow();
}

fn mainLoop(ally: std.mem.Allocator, res: Resources) !void {
    var drawAverage: i128 = 0;
    var drawAverageCount: u32 = 0;

    var allMsgs: std.ArrayList(Msg) = .init(ally);
    defer allMsgs.deinit();
    try allMsgs.ensureTotalCapacity(10);

    var menu: MenuState = .init(ally);
    defer menu.deinit();
    var game: GameState = .init();
    var currentState = Screen.menu;

    while (!rl.WindowShouldClose()) {
        // if (!rl.IsMusicStreamPlaying(res.propellerAudio1))
        //     rl.PlayMusicStream(res.propellerAudio1);
        rl.BeginDrawing();

        // Draw
        const before: i128 = std.time.nanoTimestamp();
        switch (currentState) {
            .menu => |_| {
                drawMenu(menu);
            },
            .game => |_| {
                try drawGame(game, res);
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
        try collectMessages(&allMsgs);
        // std.debug.print("Collected messages: {d}\n", .{allMsgs.items.len});
        for (allMsgs.items) |msg| {
            var cmdsFromHandlingMsg: [10]Command = undefined;
            var cmdsCount: u8 = 0;
            switch (currentState) {
                .menu => |_| {
                    cmdsCount = try menu.handleMsg(msg, &cmdsFromHandlingMsg);
                },
                .game => |_| {
                    cmdsCount = game.handleMsg(msg, &cmdsFromHandlingMsg);
                },
            }
            const cmds = cmdsFromHandlingMsg[0..@intCast(cmdsCount)];
            currentState = executeCommands(cmds, res, currentState);
        }

        rl.EndDrawing();
    }
}

fn collectMessages(allMsgs: *std.ArrayList(Msg)) !void {
    if (rl.IsKeyPressed(rl.KEY_SPACE))
        try allMsgs.append(Msg{ .inputPressed = Inputs.GeneralAction });

    if (rl.IsKeyPressed(rl.KEY_A))
        try allMsgs.append(Msg{ .inputPressed = Inputs.Plane1Rise });
    if (rl.IsKeyReleased(rl.KEY_A))
        try allMsgs.append(Msg{ .inputReleased = Inputs.Plane1Rise });

    if (rl.IsKeyPressed(rl.KEY_S))
        try allMsgs.append(Msg{ .inputPressed = Inputs.Plane1Dive });
    if (rl.IsKeyReleased(rl.KEY_S))
        try allMsgs.append(Msg{ .inputReleased = Inputs.Plane1Dive });

    const timePassed = Msg{ .timePassed = TimePassed{
        .totalTime = @floatCast(rl.GetTime()),
        .deltaTime = @floatCast(rl.GetFrameTime()),
    } };

    allMsgs.append(timePassed) catch |err| {
        std.debug.print("Error appending time message: {}\n", .{err});
    };
}

fn drawCenteredText(text: []const u8, y: u16, fontSize: u16, color: rl.Color) void {
    const textWidth: u16 = @intCast(rl.MeasureText(text.ptr, fontSize));
    const xPos: u16 = (window_width - textWidth) / 2;
    rl.DrawText(text.ptr, xPos, y, fontSize, color);
}

fn drawMenu(menu: MenuState) void {
    rl.ClearBackground(rl.SKYBLUE);
    const textSize = 40;
    drawCenteredText("Dogfight 2025", 180, textSize, rl.DARKGREEN);
    if (menu.blink)
        drawCenteredText("Press SPACE to START!", 220, 20, rl.DARKGRAY);
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
    state: GameState,
    res: Resources,
) !void {
    rl.ClearBackground(rl.SKYBLUE);

    var redPlanes: [10:0]u8 = undefined;
    const redText = try std.fmt.bufPrintZ(
        &redPlanes,
        "Red:{d}\n",
        .{state.plane1_lives},
    );
    rl.DrawText(redText.ptr, 10, 10, 20, rl.RED);

    rl.DrawCircle(window_width - 50, window_height - 100, 50, rl.RED);
    rl.DrawTexture(res.background, 0, window_height - res.background.height, rl.WHITE);

    if (state.plane1_resurrect_timeout <= 0) {
        const sourceR = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(res.plane.width),
            .height = @floatFromInt(res.plane.height),
        };
        const plane = state.plane1;
        const planeWidth: f32 = @floatFromInt(res.plane.width);
        const planeHeight: f32 = @floatFromInt(res.plane.height);
        const destR = rl.Rectangle{
            .x = plane.position[0],
            .y = plane.position[1],
            .width = planeWidth,
            .height = planeHeight,
        };
        const anchor = rl.Vector2{
            .x = planeWidth / 2,
            .y = planeHeight / 2,
        };
        rl.DrawTexturePro(res.plane, sourceR, destR, anchor, state.plane1.direction, rl.WHITE);
    }

    for (state.clouds) |cloud| {
        const color = if (cloud[1] < 300) rl.LIGHTGRAY else rl.GRAY;
        rl.DrawTexture(res.cloud, @intFromFloat(cloud[0]), @intFromFloat(cloud[1]), color);
    }

    for (0..state.num_explosions) |ix| {
        drawExplosion(state.explosions[ix]);
    }
}

fn executeCommands(
    cmds: []const Command,
    res: Resources,
    currentState: Screen,
) Screen {
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
                    },
                }
            },
            .playPropellerAudio => |audio| {
                if (audio.on) {
                    if (!rl.IsMusicStreamPlaying(res.propeller)) {
                        rl.PlayMusicStream(res.propeller);
                    }
                    rl.SetMusicPitch(res.propeller, audio.pitch);
                    rl.SetMusicPan(res.propeller, 1 - audio.pan);
                } else {
                    if (rl.IsMusicStreamPlaying(res.propeller))
                        rl.StopMusicStream(res.propeller);
                }
            },
            .switchScreen => |screen| {
                std.debug.print("Switching to screen: {}\n", .{screen});
                switch (screen) {
                    .menu => |_| {
                        return Screen.menu;
                    },
                    .game => |_| {
                        return Screen.game;
                    },
                }
            },
        }
    }
    return currentState;
}

test {
    _ = @import("basics.zig");
    _ = @import("MenuState.zig");
    _ = @import("GameState.zig");
    _ = @import("Plane.zig");
    _ = @import("Explosion.zig");
}

// TODO: wrap clouds around the screen
// TODO: shots
// TODO: particle system for explosion and debris
// TODO: switch from slices to FixedBufferAllocator in effects parameters
