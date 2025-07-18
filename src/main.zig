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

    if(argv.len == 1) {
        try DogFight2025();
        return;
    }

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
        6 => try program6(),
        7 => try program7(),
        else => {
            std.debug.print("Unknown program number: {d}\n", .{programNumber});
            return error.InvalidArgument;
        },
    }
}

fn DogFight2025() !void {
    // This is a placeholder for the DogFight2005 program.
    // You can implement it as needed.
    std.debug.print("DogFight2005 program is not implemented yet.\n", .{});
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
            if (position[i] < 0) {
                velocity[i] = -velocity[i];
                position[i] = 10;
            } else if (position[i] > 800) {
                velocity[i] = -velocity[i];
                position[i] = 790;
            }
        }
    }
}

fn program6() !void {
    c.InitWindow(1280, 800, "program6");
    defer c.CloseWindow();
    c.InitAudioDevice();

    const propellerPlane = c.LoadMusicStream("assets/PropellerPlane.mp3");
    defer c.UnloadMusicStream(propellerPlane);
    const secondPlane = c.LoadMusicStream("assets/PropellerPlane.mp3");
    defer c.UnloadMusicStream(secondPlane);

    var pitch: f32 = 1.0;
    var oldPitch: f32 = 1.0;
    while (!c.WindowShouldClose()) {
        if (!c.IsMusicStreamPlaying(propellerPlane)) {
            c.PlayMusicStream(propellerPlane);
            c.SetMusicPan(propellerPlane, 0.0); // Pan to the left
        }
        if (!c.IsMusicStreamPlaying(secondPlane)) {
            c.PlayMusicStream(secondPlane);
            c.SetMusicPan(secondPlane, 1.0); // Pan to the right
        }

        c.UpdateMusicStream(propellerPlane);
        c.UpdateMusicStream(secondPlane);

        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);

        if (c.IsKeyDown(c.KEY_S) and pitch < 4.0)
            pitch += 0.0001;
        if (c.IsKeyDown(c.KEY_A) and pitch > 0.001)
            pitch -= 0.0001;

        if (oldPitch != pitch) {
            oldPitch = pitch;
            c.SetMusicPitch(propellerPlane, pitch);
        }

        c.EndDrawing();
    }
}

fn program7() !void {
    const winWidth = 1280;
    const winHeight = 800;
    c.InitWindow(winWidth, winHeight, "program7");
    c.InitAudioDevice();
    defer c.CloseWindow();

    const rainSound = c.LoadMusicStream("assets/rain.mp3");
    defer c.UnloadMusicStream(rainSound);
    c.PlayMusicStream(rainSound);
    c.SetMusicPitch(rainSound, 0.5);
    const raindropTex = c.LoadTexture("assets/raindrop.gif");

    const debrisTex: [2]c.Texture2D = .{
        c.LoadTexture("assets/Debris1.gif"),
        c.LoadTexture("assets/Debris2.gif"),
    };

    var random = std.crypto.random;

    const V2 = @Vector(2, f32);
    const Debris = struct {
        pos: V2,
    };

    // Rainy city.
    // One structure for the houses - xstart, xend, height.
    // One structure for the rain - x, y, speed.

    const RainDrop = struct {
        x: f32,
        y: f32,
    };

    const House = struct {
        x: f32,
        width: f32,
        height: f32,
    };

    var debris = std.ArrayList(Debris).init(std.heap.page_allocator);
    defer debris.deinit();

    var houses = std.ArrayList(House).init(std.heap.page_allocator);
    defer houses.deinit();

    const numHouses = 20;
    const maxWidth = 150.0;
    const minWidth = 50.0;
    const minHeight = 20.0;
    const maxHeight = 400.0;
    for (0..numHouses) |_| {
        const x = 10 + random.float(f32) * (winWidth - maxWidth);
        const width = minWidth + random.float(f32) * (maxWidth - minWidth);
        const height = minHeight + random.float(f32) * maxHeight;
        try houses.append(House{ .x = x, .width = width, .height = height });
    }

    var raindrops = std.ArrayList(RainDrop).init(std.heap.page_allocator);
    defer raindrops.deinit();
    const numRaindrops = 2000;
    for(0..numRaindrops) |_| {
        const x = random.float(f32) * winWidth;
        const y = random.float(f32) * winHeight;
        try raindrops.append(RainDrop{ .x = x, .y = y });
    }

    // Rain drop algorithm
    // Every frame, move all 'alive' drops. If they are below the window, push a random distance
    // 'backwards'. This way, there will be a constant number of raindrops on the screen. No allocations.
    //


    while (!c.WindowShouldClose()) {
        // Update world state
        for (0..numRaindrops) |ix| {
            var drop = &raindrops.items[ix];
            drop.x -= c.GetFrameTime() * 250.0;
            drop.y += 1000.0 * c.GetFrameTime() * random.float(f32); // Move down
            if (drop.y > winHeight) {
                // Reset the raindrop to a random position at the top
                drop.x = random.float(f32) * (winWidth + winHeight/2);
                drop.y -= winHeight; // Start above the window
            }
        }
        if(c.IsKeyPressed(c.KEY_SPACE)) {
            const x = random.float(f32) * winWidth;
            const y = random.float(f32) * winHeight;
            const pos:@Vector(2, f32) = .{ x, y };
            const d: Debris = .{ .pos = pos };
            try debris.append(d);
        }

        c.UpdateMusicStream(rainSound);
        c.BeginDrawing();

        // Draw
        c.ClearBackground(c.DARKBLUE);

        c.DrawFPS(0, 0);

        // Draw houses
        for (houses.items) |h| {
            c.DrawRectangle(
                @intFromFloat(h.x),
                @intFromFloat(winHeight - h.height),
                @intFromFloat(h.width),
                @intFromFloat(h.height),
                c.BLACK,
            );
        }

        for(raindrops.items) |drop| {
            c.DrawTexture(raindropTex, @intFromFloat(drop.x), @intFromFloat(drop.y), c.WHITE);
        }

        for(0..debris.items.len) |ix| {
            const d = debris.items[ix];
            c.DrawTexture(debrisTex[ix % 2], @intFromFloat(d.pos[0]), @intFromFloat(d.pos[1]), c.WHITE);
        }

        c.EndDrawing();
    }
}

test "training" {
    _ = @import("training.zig");
}
