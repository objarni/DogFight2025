const std = @import("std");
const Explosion = @import("Explosion.zig").Explosion;
const basics = @import("basics.zig");
const Command = basics.Command;
const SoundEffect = basics.SoundEffect;
const SubScreen = basics.SubScreen;
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

    pub fn handleMessage(self: *MenuState, ally: std.mem.Allocator, msg: Msg) !std.ArrayList(Command) {
        var cmds = std.ArrayList(Command).init(ally);
        switch (msg) {
            .inputClicked => |input| {
                if (input == Inputs.GeneralAction) {
                    try cmds.appendSlice(&.{
                        Command{ .playSoundEffect = SoundEffect.boom },
                        Command{ .switchSubScreen = SubScreen.game },
                    });
                }
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
        return cmds;
    }
};

fn randomExplosion() Explosion {
    return Explosion.init(
        3.0 * rndFrac() + 0.5,
        v(
            window_width * rndFrac(),
            window_height * rndFrac(),
        ),
        100.0 * rndFrac(),
        std.math.pi * 2 * rndFrac(),
    );
}

fn rndFrac() f32 {
    const random = std.crypto.random;
    return random.float(f32);
}

test "MenuState: hitting action button should switch to game and play Boom sound" {
    const ally = std.testing.allocator;
    var menuState = MenuState.init(ally);
    const actual = try menuState.handleMessage(
        ally,
        Msg{ .inputClicked = Inputs.GeneralAction },
    );
    defer actual.deinit();
    var expected = std.ArrayList(Command).init(ally);
    defer expected.deinit();
    try expected.appendSlice(
        &.{
            Command{ .playSoundEffect = SoundEffect.boom },
            Command{ .switchSubScreen = SubScreen.game },
        },
    );
    try std.testing.expectEqualSlices(
        Command,
        expected.items,
        actual.items,
    );
}

test "MenuState: press space blinks every 0.5 second on menu screen" {
    const ally = std.testing.allocator;

    // No text expected
    var menuState: MenuState = .init(ally);
    const msg = Msg{ .timePassed = .{ .totalTime = 0.40, .deltaTime = 0.40 } };
    _ = try menuState.handleMessage(ally, msg);
    try std.testing.expectEqual(menuState.blink, false);

    // Text expected
    const msg2 = Msg{ .timePassed = .{ .totalTime = 0.75, .deltaTime = 0.35 } };
    _ = try menuState.handleMessage(ally, msg2);

    try std.testing.expectEqual(menuState.blink, true);
}
