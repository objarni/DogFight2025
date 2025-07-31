const std = @import("std");

const v2 = @import("V.zig");
const V = v2.V;
const v = v2.v;

const basics = @import("basics.zig");
pub const Command = basics.Command;
const SoundEffect = basics.SoundEffect;
const PropellerAudio = basics.PropellerAudio;
const SubScreen = basics.SubScreen;
pub const Msg = basics.Msg;
pub const Inputs = basics.Inputs;
pub const TimePassed = basics.TimePassed;
const window_width: u16 = basics.window_width;
const window_height: u16 = basics.window_height;

const plane = @import("Plane.zig");
const Plane = plane.Plane;
const PlaneState = plane.PlaneState;
const Explosion = @import("Explosion.zig").Explosion;

pub const MenuState = @import("MenuState.zig").MenuState;

pub const Screen = union(enum) {
    menu: MenuState,
    game: GameState,

    pub fn init(ally: std.mem.Allocator) Screen {
        return Screen{ .menu = .init(ally) };
    }

    pub fn deinit(self: Screen) void {
        switch (self) {
            .menu => |menu| menu.deinit(),
            .game => |_| {}, // GameState does not need deinit
        }
    }

    pub fn handleMessage(self: *Screen, ally: std.mem.Allocator, msg: Msg) ![]Command {
        var result = try updateScreen(ally, self, msg);
        defer result.deinit();
        self.* = result.screen;
        return result.commands.toOwnedSlice();
    }
};

pub const GameState = struct {
    clouds: [2]V,
    plane1: Plane,

    pub fn init() GameState {
        return GameState{
            .clouds = .{ v(555.0, 305.0), v(100.0, 100.0) },
            .plane1 = Plane.init(.{
                .initialPos = v(100.0, 200.0),
                .takeoffSpeed = 50.0,
                .groundAccelerationPerS = 10.0,
            }),
        };
    }

    fn handleMessage(self: *GameState, ally: std.mem.Allocator, msg: Msg) !?UpdateResult {
        return switch (msg) {
            .timePassed => |time| {
                const propellerPitch: f32 = @max(0.5, @min(2.0, self.plane1.velocity[0] / 50.0));
                const propellerPan: f32 = @max(0.0, @min(1.0, self.plane1.position[0] / window_width));
                const propellerOn = self.plane1.state != PlaneState.STILL;

                const propellerCmd = Command{
                    .playPropellerAudio = PropellerAudio{
                        .plane = 0, // 0 for plane 1
                        .on = propellerOn,
                        .pan = propellerPan,
                        .pitch = propellerPitch,
                    },
                };

                const deltaX: f32 = time.deltaTime;
                self.clouds[0][0] -= deltaX * 5.0;
                self.clouds[1][0] -= deltaX * 8.9; // lower cloud moves faster
                self.plane1 = self.plane1.timePassed(time.deltaTime);

                return try UpdateResult.init(
                    ally,
                    Screen{ .game = self.* },
                    &.{propellerCmd},
                );
            },
            .inputClicked => |input| {
                const plane1oldState = self.plane1.state;
                switch (input) {
                    .Plane1Rise => self.plane1 = self.plane1.rise(),
                    .Plane2Rise => {}, // TODO: Implement second plane
                    else => {},
                }
                if (self.plane1.state == PlaneState.CRASH and plane1oldState != PlaneState.CRASH) {
                    return try UpdateResult.init(ally, Screen{ .game = self.* }, &.{
                        Command{ .playSoundEffect = SoundEffect.crash },
                    });
                }
                return try UpdateResult.init(ally, Screen{ .game = self.* }, &.{});
            },
        };
    }
};

test "GameState: both clouds move left by, but the lower cloud moves faster" {
    var gameState: GameState = GameState.init();
    const highCloudX: f32 = gameState.clouds[0][0];
    const lowCloudX: f32 = gameState.clouds[1][0];
    const result: ?UpdateResult = try gameState.handleMessage(
        std.testing.allocator,
        Msg{ .timePassed = TimePassed{ .totalTime = 1.0, .deltaTime = 1.0 } },
    );
    if (result) |newScreen| {
        defer newScreen.deinit();
        try std.testing.expectApproxEqAbs(highCloudX - 5.0, newScreen.screen.game.clouds[0][0], 0.1);
        try std.testing.expectApproxEqAbs(lowCloudX - 8.9, newScreen.screen.game.clouds[1][0], 0.1);
    } else {
        std.debug.print("Expected a result from GameState.handleMsg, but got null\n", .{});
        try std.testing.expect(false);
    }
}

pub const UpdateResult = struct {
    screen: Screen,
    commands: std.ArrayList(Command),

    fn init(ally: std.mem.Allocator, screen: Screen, cmds: []const Command) !UpdateResult {
        return UpdateResult{
            .screen = screen,
            .commands = try arrayListOf(Command, ally, cmds),
        };
    }

    fn deinit(self: UpdateResult) void {
        self.commands.deinit();
    }
};

fn arrayListOf(comptime T: type, ally: std.mem.Allocator, items: []const T) !std.ArrayList(T) {
    var list = std.ArrayList(T).init(ally);
    for (items) |item| {
        try list.append(item);
    }
    return list;
}

pub fn updateScreen(ally: std.mem.Allocator, screen: *Screen, msg: Msg) !UpdateResult {
    switch (screen.*) {
        .menu => |menu| {
            var menuCopy = menu;
            const cmds = try menuCopy.handleMessage(ally, msg);
            defer cmds.deinit();
            return UpdateResult.init(
                ally,
                Screen{ .menu = menuCopy },
                cmds.items,
            );
        },
        .game => |state| {
            var newState = state;
            const maybeResult = try newState.handleMessage(ally, msg);
            if (maybeResult) |result| return result;
        },
    }
    return UpdateResult.init(
        ally,
        screen.*,
        &.{},
    );
}

test "game starts in menu" {
    const ally = std.testing.allocator;
    const actual: Screen = .init(ally);
    const expected: Screen = .{ .menu = MenuState.init(ally) };
    try std.testing.expectEqual(expected, actual);
}

// TODO: to avoid copies, updateScreen could be member, and get a pointer to var Screen
// TODO: wrap clouds around the screen
// TODO: display airplanes left (10 to start with)
// TODO: add planes
// TODO: particle system for explosion and debris
// TODO: Move Game state to its own file
// TODO: Get rid of UpdateResult, just return list of commands from states
