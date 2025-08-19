const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});

const basics = @import("basics.zig");
const Msg = basics.Msg;
const Command = basics.Command;
const Inputs = basics.Inputs;
const TimePassed = basics.TimePassed;
const State = basics.State;

const window_width: u16 = 960;
const window_height: u16 = 540;

const Explosion = @import("Explosion.zig").Explosion;
const MenuState = @import("MenuState.zig").MenuState;
const GameState = @import("GameState.zig").GameState;
const GameOverState = @import("GameOverState.zig").GameOverState;

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
    // rl.ToggleFullscreen();

    const res = Resources{
        .boom = rl.LoadSound("assets/Boom.wav"),
        .crash = rl.LoadSound("assets/Crash.mp3"),
        .shoot = rl.LoadSound("assets/Shoot.wav"),
        .hit = rl.LoadSound("assets/Hit.wav"),
        .game_over = rl.LoadSound("assets/GameOver.mp3"),
        .plane = rl.LoadTexture("assets/Plane.png"),
        .cloud = rl.LoadTexture("assets/CloudBig.png"),
        .propellers = .{
            rl.LoadMusicStream("assets/PropellerPlane.mp3"),
            rl.LoadMusicStream("assets/PropellerPlane.mp3"),
        },
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
    rl.UnloadSound(res.shoot);
    rl.UnloadSound(res.game_over);
    rl.UnloadTexture(res.plane);
    rl.UnloadTexture(res.cloud);
    rl.UnloadTexture(res.background);
    rl.UnloadMusicStream(res.propellers[0]);
    rl.UnloadMusicStream(res.propellers[1]);
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
    var game: GameState = .init(ally);
    defer game.deinit();
    var game_over: GameOverState = .init(0);
    var currentState = State.menu;

    var effects: std.ArrayList(Command) = .init(ally);
    defer effects.deinit();
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
            .game_over => |_| {
                drawGameOver(game_over, res);
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
        rl.UpdateMusicStream(res.propellers[0]);
        rl.UpdateMusicStream(res.propellers[1]);

        allMsgs.clearRetainingCapacity();
        try collectMessages(&allMsgs);
        for (allMsgs.items) |msg| {
            effects.clearRetainingCapacity();
            switch (currentState) {
                .menu => |_| {
                    try menu.handleMsg(msg, &effects);
                },
                .game => |_| {
                    try game.handleMsg(msg, &effects);
                },
                .game_over => |_| {
                    try game_over.handleMsg(msg, &effects);
                },
            }
            const result = executeCommands(effects.items, res, currentState);
            currentState = result.new_state;
            if (result.state_changed) {
                if (currentState == State.game)
                    game = GameState.init(ally);
            }
        }

        // TODO: this 'hack' is just so ugly :P
        // If any of the players lives are 0, there is a winner
        if (game.players[0].lives == 0 or game.players[1].lives == 0)
            game_over.winning_player = if (game.players[0].lives > 0) 0 else 1;
        rl.EndDrawing();
    }
}

fn collectMessages(allMsgs: *std.ArrayList(Msg)) !void {
    if (rl.IsKeyPressed(rl.KEY_SPACE))
        try allMsgs.append(Msg{ .inputPressed = Inputs.general_action });

    if (rl.IsKeyPressed(rl.KEY_LEFT_CONTROL))
        try allMsgs.append(Msg{ .inputPressed = Inputs.plane1_fire });
    if (rl.IsKeyPressed(rl.KEY_A))
        try allMsgs.append(Msg{ .inputPressed = Inputs.plane1_rise });
    if (rl.IsKeyReleased(rl.KEY_A))
        try allMsgs.append(Msg{ .inputReleased = Inputs.plane1_rise });

    if (rl.IsKeyPressed(rl.KEY_S))
        try allMsgs.append(Msg{ .inputPressed = Inputs.plane1_dive });
    if (rl.IsKeyReleased(rl.KEY_S))
        try allMsgs.append(Msg{ .inputReleased = Inputs.plane1_dive });

    if (rl.IsKeyPressed(rl.KEY_PERIOD))
        try allMsgs.append(Msg{ .inputPressed = Inputs.plane2_fire });
    if (rl.IsKeyPressed(rl.KEY_J))
        try allMsgs.append(Msg{ .inputPressed = Inputs.plane2_rise });
    if (rl.IsKeyReleased(rl.KEY_J))
        try allMsgs.append(Msg{ .inputReleased = Inputs.plane2_rise });

    if (rl.IsKeyPressed(rl.KEY_K))
        try allMsgs.append(Msg{ .inputPressed = Inputs.plane2_dive });
    if (rl.IsKeyReleased(rl.KEY_K))
        try allMsgs.append(Msg{ .inputReleased = Inputs.plane2_dive });

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

fn drawTextCenteredAt(text: []const u8, x: i16, y: i16, fontSize: i16, color: rl.Color) void {
    const text_width: i16 = @intCast(rl.MeasureText(text.ptr, fontSize));
    const x_pos = x - @divFloor(text_width, 2);
    const y_pos = y - @divFloor(fontSize, 2);
    // std.debug.print("x: {d} y: {d} Text width: {d}", .{x_pos, y_pos, text_width});
    rl.DrawText(text.ptr, x_pos, y_pos, fontSize, color);
}

fn drawMenu(menu: MenuState) void {
    rl.ClearBackground(rl.DARKBLUE);
    const textSize = 40;
    drawCenteredText("Dogfight 2025", 180, textSize, rl.GREEN);
    if (menu.blink)
        drawCenteredText("Press SPACE to START!", 220, 20, rl.GRAY);
    drawExplosion(menu.e);
    for (menu.es.items) |e| {
        drawExplosion(e);
    }
}

fn drawGameOver(game_over: GameOverState, res: Resources) void {
    rl.ClearBackground(rl.DARKPURPLE);
    const textSize = 40;
    drawCenteredText("GAME OVER", 180, textSize, rl.WHITE);
    const red_won = game_over.winning_player == 0;
    const color = if (red_won) rl.RED else rl.GREEN;
    rl.DrawTextureEx(
        res.plane,
        rl.Vector2{
            .x = @floatFromInt(@divFloor(window_width - res.plane.width * 2, 2)),
            .y = @floatFromInt(@divFloor(window_height - res.plane.height * 2, 2)),
        },
        0,
        2.0,
        color,
    );
    if (game_over.blink) {
        drawCenteredText(if (red_won) "Red player won" else "Green player won", 320, 20, color);
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
    shoot: rl.Sound,
    game_over: rl.Sound,
    hit: rl.Sound,
    plane: rl.Texture2D,
    cloud: rl.Texture2D,
    background: rl.Texture2D,
    propellers: [2]rl.Music,
};

const tweak = @import("tweak.zig");

fn drawGame(
    state: GameState,
    res: Resources,
) !void {
    rl.ClearBackground(rl.SKYBLUE);

    var buffer: [10:0]u8 = undefined;
    for (0..2) |i| {
        const x_pos = if (i == 0) 10 else window_width - 100;
        const text_color = if (i == 0) rl.RED else rl.DARKGREEN;
        var display_text: [:0]u8 = undefined;
        if (i == 0)
            display_text = try std.fmt.bufPrintZ(
                &buffer,
                "Red: {d}",
                .{state.players[i].lives},
            )
        else
            display_text = try std.fmt.bufPrintZ(
                &buffer,
                "Green: {d}",
                .{state.players[i].lives},
            );
        rl.DrawText(display_text.ptr, x_pos, 10, 20, text_color);
    }

    rl.DrawCircle(window_width - 50, window_height - 100, 50, rl.RED);
    rl.DrawTexture(res.background, 0, window_height - res.background.height, rl.WHITE);
    drawTextCenteredAt(
        "Red controls: A rise, S dive, LCtrl fire",
        210,
        40,
        20,
        rl.BLACK,
    );
    drawTextCenteredAt(
        "Green controls: J rise, K dive, . is fire",
        730,
        40,
        20,
        rl.BLACK,
    );

    for (state.shots.items) |shot| {
        rl.DrawCircle(
            @intFromFloat(shot.position[0]),
            @intFromFloat(shot.position[1]),
            1.0,
            rl.WHITE,
        );
    }

    for (0..2) |plane_ix| {
        if (state.players[plane_ix].resurrect_timeout <= 0) {
            const plane = state.players[plane_ix].plane;
            const texture = res.plane;
            const position = plane.position;
            const rotation_deg = plane.direction;
            const color = if (plane_ix == 0) rl.WHITE else rl.GREEN;
            drawRotatedTexture(texture, position, rotation_deg, color);
        }
    }

    for (state.clouds) |cloud| {
        const color = if (cloud[1] < 300) rl.LIGHTGRAY else rl.GRAY;
        rl.DrawTexture(res.cloud, @intFromFloat(cloud[0]), @intFromFloat(cloud[1]), color);
    }

    for (0..state.num_explosions) |ix| {
        drawExplosion(state.explosions[ix]);
    }
}

fn drawRotatedTexture(texture: rl.struct_Texture, position: @Vector(2, f32), rotation_deg: f32, color: anytype) void {
    const source_rect = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(texture.width),
        .height = @floatFromInt(texture.height),
    };
    const w: f32 = @floatFromInt(texture.width);
    const h: f32 = @floatFromInt(texture.height);
    const dest_rect = rl.Rectangle{
        .x = position[0],
        .y = position[1],
        .width = w,
        .height = h,
    };
    const anchor = rl.Vector2{
        .x = w / 2,
        .y = h / 2,
    };
    rl.DrawTexturePro(
        texture,
        source_rect,
        dest_rect,
        anchor,
        rotation_deg,
        color,
    );
}

const ExecuteCommandsResult = struct {
    new_state: State,
    state_changed: bool,
};

fn executeCommands(
    cmds: []const Command,
    res: Resources,
    currentState: State,
) ExecuteCommandsResult {
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
                    .shoot => {
                        rl.PlaySound(res.shoot);
                    },
                    .game_over => {
                        rl.PlaySound(res.game_over);
                        std.debug.print("Playing game over sound effect\n", .{});
                    },
                    .hit => {
                        rl.PlaySound(res.hit);
                    }
                }
            },
            .playPropellerAudio => |audio| {
                const plane = audio.plane;
                if (audio.on) {
                    if (!rl.IsMusicStreamPlaying(res.propellers[plane])) {
                        rl.PlayMusicStream(res.propellers[plane]);
                    }
                    rl.SetMusicVolume(res.propellers[plane], 0.5);
                    rl.SetMusicPitch(res.propellers[plane], audio.pitch);
                    rl.SetMusicPan(res.propellers[plane], 1 - audio.pan);
                    // TODO: tween the pan value so that it doesn't jump left/right instantly
                } else {
                    if (rl.IsMusicStreamPlaying(res.propellers[plane]))
                        rl.StopMusicStream(res.propellers[plane]);
                }
            },
            .switchScreen => |state| {
                std.debug.print("Switching to state: {}\n", .{state});
                switch (state) {
                    .menu => |_| return ExecuteCommandsResult{
                        .new_state = State.menu,
                        .state_changed = true,
                    },
                    .game => |_| return ExecuteCommandsResult{
                        .new_state = State.game,
                        .state_changed = true,
                    },
                    .game_over => |_| return ExecuteCommandsResult{
                        .new_state = State.game_over,
                        .state_changed = true,
                    },
                }
            },
        }
    }

    return ExecuteCommandsResult{
        .new_state = currentState,
        .state_changed = false,
    };
}

test {
    _ = @import("basics.zig");
    _ = @import("MenuState.zig");
    _ = @import("GameState.zig");
    _ = @import("Plane.zig");
    _ = @import("Explosion.zig");
}

// TODO: wrap clouds around the screen
// TODO: wrap planes around the screen
// TODO: shots
// TODO: particle system for explosion and debris
