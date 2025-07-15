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

test "training" {
    _ = @import("training.zig");
}
