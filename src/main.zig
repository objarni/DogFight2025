//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    const ally = std.heap.page_allocator;

    // Grab argv to pass to raylib.
    const argv = try std.process.argsAlloc(ally);
    defer std.process.argsFree(ally, argv);

    if (argv.len != 2) {
        std.debug.print("Usage: {s} <program number>\n", .{argv});
        return error.InvalidArgument;
    }

    const programNumber = std.fmt.parseInt(i32, argv[1], 10) catch |err| {
        std.debug.print("Invalid program number: {s}\n", .{argv[1]});
        return err;
    };

    switch (programNumber) {
        1 => try program1(),
        2 => try program2(),
        3 => try program3(),
        4 => try program4(),
        5 => try program5(),
        else => {
            std.debug.print("Unknown program number: {d}\n", .{programNumber});
            return error.InvalidArgument;
        },
    }
}

fn program1() !void {
    c.InitWindow(1280, 800, "program1");
    defer c.CloseWindow();

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);
        c.DrawText("Hello, world!", 10, 10, 20, c.DARKGRAY);
        c.EndDrawing();
    }
}

fn program2() !void {
    c.InitWindow(1280, 800, "program2");
    defer c.CloseWindow();
    c.InitAudioDevice();

    const boomSound = c.LoadSound("assets/boom.wav");
    defer c.UnloadSound(boomSound);

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);

        c.DrawText("Press SPACE to PLAY the WAV sound!", 200, 180, 20, c.LIGHTGRAY);
        if (c.IsKeyPressed(c.KEY_SPACE)) c.PlaySound(boomSound);

        c.EndDrawing();
    }
}

fn program3() !void {
    c.InitWindow(1280, 800, "program3");
    defer c.CloseWindow();

    const Key = struct {
        keyId: u16,
        namePressed: []const u8,
        nameNotPressed: []const u8,
    };

    const keys: [5]Key = .{
        Key{ .keyId = c.KEY_SPACE, .namePressed = "SPACE!", .nameNotPressed = "No space" },
        Key{ .keyId = c.KEY_A, .namePressed = "A", .nameNotPressed = "a" },
        Key{ .keyId = c.KEY_S, .namePressed = "S", .nameNotPressed = "s" },
        Key{ .keyId = c.KEY_J, .namePressed = "J", .nameNotPressed = "j" },
        Key{ .keyId = c.KEY_K, .namePressed = "K", .nameNotPressed = "k" },
    };

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);
        var y: i32 = 10;
        for (keys) |k| {
            y += 30;
            const text = if (c.IsKeyDown(k.keyId)) k.namePressed else k.nameNotPressed;
            c.DrawText(text.ptr, 10, y, 20, c.LIGHTGRAY);
        }

        c.EndDrawing();
    }
}

fn program4() !void {
    const winWidth = 1280;
    const winHeight = 800;
    c.InitWindow(winWidth, winHeight, "program4");
    defer c.CloseWindow();

    const planeTexture = c.LoadTexture("assets/plane.png");
    defer c.UnloadTexture(planeTexture);

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.ClearBackground(c.SKYBLUE);

        c.DrawFPS(0, 0);
        const sourceRect = c.Rectangle{ .x = 0, .y = 0, .width = -1.0 * @as(f32, @floatFromInt(planeTexture.width)), .height = @floatFromInt(planeTexture.height) };
        const destRect = c.Rectangle{ .x = winWidth / 2, .y = winHeight / 2, .width = 2.0 * @as(f32, @floatFromInt(planeTexture.width)), .height = 2.0 * @as(f32, @floatFromInt(planeTexture.height)) };
        const rotation = @as(f32, @floatCast(c.GetTime())) * 50.0; // Rotate at 50 degrees per second
        const origin = c.Vector2{ .x = 32, .y = 32 };
        c.DrawTexturePro(planeTexture, sourceRect, destRect, origin, rotation, c.WHITE);

        c.EndDrawing();
    }
}

fn program5() !void {
    // Trying out Vectors for frame-rate independent movement.
    //
    const winWidth = 800;
    const winHeight = 800;
    c.InitWindow(winWidth, winHeight, "program5");
    defer c.CloseWindow();
    c.InitAudioDevice();

    const planeTexture = c.LoadTexture("assets/plane.png");
    defer c.UnloadTexture(planeTexture);

    const boomSound = c.LoadSound("assets/boom.wav");
    defer c.UnloadSound(boomSound);

    var position: @Vector(2, f32) = .{ 300, 400 };
    var velocity: @Vector(2, f32) = .{ 50, 450 };

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.ClearBackground(c.SKYBLUE);

        const sourceRect = c.Rectangle{ .x = 0, .y = 0, .width = -1.0 * @as(f32, @floatFromInt(planeTexture.width)), .height = @floatFromInt(planeTexture.height) };
        const destRect = c.Rectangle{ .x = position[0], .y = position[1], .width = 2.0 * @as(f32, @floatFromInt(planeTexture.width)), .height = 2.0 * @as(f32, @floatFromInt(planeTexture.height)) };
        const rotation = @as(f32, @floatCast(c.GetTime())) * 50.0; // Rotate at 50 degrees per second
        const origin = c.Vector2{ .x = 32, .y = 32 };
        c.DrawTexturePro(planeTexture, sourceRect, destRect, origin, rotation, c.WHITE);

        c.EndDrawing();

        // Update position based on direction and frame time
        const dt = @as(f32, c.GetFrameTime());
        position += velocity * @as(@Vector(2, f32), @splat(dt));

        for (0..2) |i| {
            if (c.IsKeyDown(c.KEY_RIGHT)) {
                velocity[i] += 100 * dt; // Increase speed
            } else if (c.IsKeyDown(c.KEY_LEFT)) {
                velocity[i] -= 100 * dt; // Decrease speed
            }
        }
        for (0..2) |i| {
            if(position[i] < 0) {
                velocity[i] = -velocity[i];
                position[i] = 10;
            } else if (position[i] > 800) {
                velocity[i] = -velocity[i];
                position[i] = 790;
            }
        }
        // if (position[0] < 0) {
        //     velocity[0] = -velocity[0];
        //     position[0] = 10;
        // }
        // if (position[0] > 800) {
        //     velocity[0] = -velocity[0];
        //     position[0] = 790;
        // }
        // if (position[1] < 0) {
        //     velocity[1] = -velocity[1];
        //     position[1] = 10;
        // }
        // if (position[1] > 800) {
        //     velocity[1] = -velocity[1];
        //     position[1] = 790;
        // }
    }
}

test "training" {
    _ = @import("training.zig");
}
