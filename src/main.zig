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
        else => {
            std.debug.print("Unknown program number: {d}\n", .{programNumber});
            return error.InvalidArgument;
        },
    }
}

fn program1() !void {
    c.InitWindow(1280, 800, "DogFight 2025");
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

    const boomSound = c.LoadSound("src/boom.wav");
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

    const keys: [2]Key = .{
        Key{ .keyId = c.KEY_SPACE, .namePressed = "SPACE!", .nameNotPressed = "No space" },
        Key{ .keyId = c.KEY_A, .namePressed = "A", .nameNotPressed = "a" },
    };

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);
        for (keys) |k| {
            const text = if(c.IsKeyDown(k.keyId)) k.namePressed else k.nameNotPressed;
            c.DrawText(text.ptr, 10, 10, 20, c.LIGHTGRAY);
        }

        c.EndDrawing();
    }
}

test "training" {
    _ = @import("training.zig");
}
