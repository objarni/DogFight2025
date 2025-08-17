pub const TimePassed = struct {
    deltaTime: f32,
    totalTime: f32,
};

pub const Msg = union(enum) {
    inputPressed: Inputs,
    inputReleased: Inputs,
    timePassed: TimePassed,
};

pub const Inputs = enum {
    Plane1Rise,
    Plane1Dive,
    Plane1Fire,
    Plane2Rise,
    Plane2Dive,
    Plane2Fire,
    GeneralAction, // This is starting game, pausing/unpausing, switching from game over to menu etc
};

pub const Command = union(enum) {
    playSoundEffect: SoundEffect,
    playPropellerAudio: PropellerAudio,
    switchScreen: State,
};

pub const State = enum {
    menu,
    game,
};

pub const SoundEffect = enum {
    boom,
    crash,
    shoot,
    game_over,
};

pub const PropellerAudio = struct {
    plane: u1, // 0 for plane 1, 1 for plane 2
    on: bool, // true if sound is on, false if muted
    pan: f32, // 0.0 to 1.0, where 0.0 is left, 1.0 is right
    pitch: f32, // 1.0 is normal, 0.5 is half speed, 2.0 is double speed
};

pub const window_width: u16 = 960;
pub const window_height: u16 = 540;
