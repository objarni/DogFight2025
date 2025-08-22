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

pub const GameOverState = struct {
    blink: bool = false,
    winning_player: u1,

    pub fn init(winning_player: u1) GameOverState {
        return GameOverState{
            .blink = false,
            .winning_player = winning_player,
        };
    }

    pub fn handleMsg(self: *GameOverState, msg: Msg, commands: *std.array_list.Managed(Command)) !void {
        switch (msg) {
            .inputPressed => |input| {
                if (input == Inputs.general_action) {
                    try commands.append(Command{
                        .switchScreen = SubScreen.menu,
                    });
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
            },
        }
    }
};

test "GameOverState.handleMsg: hitting action button should switch to menu" {
    const ally = std.testing.allocator;
    var gameover_state = GameOverState.init(ally);
    var actual_commands = std.array_list.Managed(Command).init(ally);
    defer actual_commands.deinit();
    _ = try gameover_state.handleMsg(
        Msg{ .inputPressed = Inputs.general_action },
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

test "GameOverState.handleMsg: press space blinks every 0.5 second on game over screen" {
    const ally = std.testing.allocator;
    var commands = std.array_list.Managed(Command).init(ally);
    defer commands.deinit();

    // No text expected
    var gameover_state: GameOverState = .init(ally);
    const msg = Msg{
        .timePassed = .{
            .totalTime = 0.40,
            .deltaTime = 0.40,
        },
    };
    _ = try gameover_state.handleMsg(msg, &commands);
    try std.testing.expectEqual(gameover_state.blink, false);

    // Text expected
    const msg2 = Msg{
        .timePassed = .{
            .totalTime = 0.75,
            .deltaTime = 0.35,
        },
    };
    _ = try gameover_state.handleMsg(msg2, &commands);

    try std.testing.expectEqual(gameover_state.blink, true);
}
