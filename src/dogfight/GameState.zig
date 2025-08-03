const std = @import("std");

const plane = @import("Plane.zig");
const Plane = plane.Plane;
const PlaneState = plane.PlaneState;

const basics = @import("basics.zig");
const Command = basics.Command;
const TimePassed = basics.TimePassed;
const SoundEffect = basics.SoundEffect;
const PropellerAudio = basics.PropellerAudio;
const Msg = basics.Msg;
const Inputs = basics.Inputs;
const window_width: u16 = basics.window_width;
const window_height: u16 = basics.window_height;

const v2 = @import("V.zig");
const V = v2.V;
const v = v2.v;

pub const GameState = struct {
    clouds: [2]V,
    plane1: Plane,

    pub fn init() GameState {
        return GameState{
            .clouds = .{ v(555.0, 305.0), v(100.0, 100.0) },
            .plane1 = Plane.init(.{
                .initialPos = v(20.0, window_height - 50),
                .towerDistance = 330.0,
                .groundAccelerationPerS = 10.0,
            }),
        };
    }

    pub fn handleMsg(self: *GameState, msg: Msg, effects: []Command) u8 {
        switch (msg) {
            .timePassed => |time| {

                // Move plane
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
                effects[0] = propellerCmd;
                self.plane1.timePassed(time.deltaTime);

                // Move clouds
                const deltaX: f32 = time.deltaTime;
                self.clouds[0][0] -= deltaX * 5.0;
                self.clouds[1][0] -= deltaX * 8.9; // lower cloud moves faster

                return 1;
            },
            .inputClicked => |input| {
                const plane1oldState = self.plane1.state;
                switch (input) {
                    .Plane1Rise => self.plane1.rise(),
                    .Plane2Rise => {}, // TODO: Implement second plane
                    else => {},
                }
                if (self.plane1.state == PlaneState.CRASH and plane1oldState != PlaneState.CRASH) {
                    effects[0] = Command{ .playSoundEffect = SoundEffect.crash };
                    return 1;
                }
            },
        }
        return 0;
    }
};

test "GameState: both clouds move left by, but the lower cloud moves faster" {
    var gameState: GameState = GameState.init();
    const highCloudX: f32 = gameState.clouds[0][0];
    const lowCloudX: f32 = gameState.clouds[1][0];
    var effects: [10]Command = undefined;
    _ = gameState.handleMsg(
        Msg{
            .timePassed = TimePassed{
                .totalTime = 1.0,
                .deltaTime = 1.0,
            },
        },
        &effects,
    );
    try std.testing.expectApproxEqAbs(
        highCloudX - 5.0,
        gameState.clouds[0][0],
        0.1,
    );
    try std.testing.expectApproxEqAbs(
        lowCloudX - 8.9,
        gameState.clouds[1][0],
        0.1,
    );
}
