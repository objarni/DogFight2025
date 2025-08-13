const std = @import("std");
const Explosion = @import("Explosion.zig").Explosion;
const basics = @import("basics.zig");
const randomExplosion = @import("Explosion.zig").randomExplosion;
const Command = basics.Command;
const SoundEffect = basics.SoundEffect;
const SubScreen = basics.State;
const Msg = basics.Msg;
const Inputs = basics.Inputs;
const v2 = @import("V.zig");
const V = v2.V;
const v = v2.v;
const window_width: u16 = basics.window_width;
const window_height: u16 = basics.window_height;

pub const MenuState = struct {
    blink: bool = false,
    es: std.ArrayList(Explosion),
    e: Explosion,

    pub fn init(ally: std.mem.Allocator) MenuState {
        const explosionsArray = std.ArrayList(Explosion).init(ally);
        return MenuState{
            .blink = false,
            .e = Explosion.init(
                2.0,
                v(180.0, 270.0),
                100.0,
                std.math.pi / 4.0,
            ),
            .es = explosionsArray,
        };
    }

    pub fn deinit(self: MenuState) void {
        self.es.deinit();
    }

    pub fn handleMsg(self: *MenuState, msg: Msg, commands: *std.ArrayList(Command)) !u4 {
        switch (msg) {
            .inputPressed => |input| {
                if (input == Inputs.GeneralAction) {
                    try commands.append(Command{
                        .playSoundEffect = SoundEffect.boom,
                    });
                    try commands.append(Command{
                        .switchScreen = SubScreen.game,
                    });
                    return 2;
                }
            },
            .inputReleased => |_| {
                // Handle input release if needed
            },
            .timePassed => |time| {
                const numPeriods: f32 = time.totalTime / 0.5;
                const intNumPeriods: u32 = @intFromFloat(numPeriods);
                const blink: bool = intNumPeriods % 2 == 1;
                self.blink = blink;
                self.e.timePassed(time.deltaTime);
                if (!self.e.alive) {
                    self.e = randomExplosion();
                    try self.es.append(randomExplosion());
                    try self.es.append(randomExplosion());
                }
                for (0..self.es.items.len) |ix| {
                    self.es.items[ix].timePassed(time.deltaTime);
                }
                // Remove dead explosions
                var i: usize = 0;
                while (i < self.es.items.len) {
                    if (!self.es.items[i].alive) {
                        std.debug.print("Removing dead explosion at index {}\n", .{i});
                        _ = self.es.swapRemove(i);
                    } else i += 1;
                }
            },
        }
        return 0;
    }
};

test "MenuState.handleMsg: hitting action button should switch to game and play Boom sound" {
    const ally = std.testing.allocator;
    var menu_state = MenuState.init(ally);
    var actual_commands = std.ArrayList(Command).init(ally);
    defer actual_commands.deinit();
    _ = try menu_state.handleMsg(
        Msg{ .inputPressed = Inputs.GeneralAction },
        &actual_commands,
    );
    const expected: [2]Command = .{
        Command{ .playSoundEffect = SoundEffect.boom },
        Command{ .switchScreen = SubScreen.game },
    };
    try std.testing.expectEqualSlices(
        Command,
        &expected,
        actual_commands.items,
    );
}

test "MenuState.handleMsg: press space blinks every 0.5 second on menu screen" {
    const ally = std.testing.allocator;
    var commands = std.ArrayList(Command).init(ally);
    defer commands.deinit();

    // No text expected
    var menuState: MenuState = .init(ally);
    const msg = Msg{
        .timePassed = .{
            .totalTime = 0.40,
            .deltaTime = 0.40,
        },
    };
    _ = try menuState.handleMsg(msg, &commands);
    try std.testing.expectEqual(menuState.blink, false);

    // Test expected
    const msg2 = Msg{
        .timePassed = .{
            .totalTime = 0.75,
            .deltaTime = 0.35,
        },
    };
    _ = try menuState.handleMsg(msg2, &commands);

    try std.testing.expectEqual(menuState.blink, true);
}
