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
pub const GameState = @import("GameState.zig").GameState;

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

    pub fn handleMsg(self: *Screen, _: std.mem.Allocator, msg: Msg, effects: []Command) !u4 {
        switch (self.*) {
            .menu => |menu| {
                var menuCopy = menu;
                const numberOfCommands: u4 = @as(u4, @intCast(try menuCopy.handleMsg(msg, effects)));
                self.menu = menuCopy; // Update the menu state
                return numberOfCommands;
            },
            .game => |state| {
                var gameCopy = state;
                const numberOfCommands: u4 = @intCast(gameCopy.handleMsg(msg, effects));
                self.game = gameCopy; // Update the game state
                return numberOfCommands;
            },
        }
    }
};

test "game starts in menu" {
    const ally = std.testing.allocator;
    const actual: Screen = .init(ally);
    const expected: Screen = .{ .menu = MenuState.init(ally) };
    try std.testing.expectEqual(expected, actual);
}

// TODO: wrap clouds around the screen
// TODO: display airplanes left (10 to start with)
// TODO: particle system for explosion and debris
// TODO: switch from slices to FixedBufferAllocator in effects parameters
