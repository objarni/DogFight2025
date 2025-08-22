const std = @import("std");
const parseInt = std.fmt.parseInt;

test "parse integers" {
    const input = "123 67 89,99";
    const ally = std.testing.allocator;

    var list = std.array_list.Managed(u32).init(ally);
    // Ensure the list is freed at scope exit.
    // Try commenting out this line!
    defer list.deinit();

    var it = std.mem.tokenizeAny(u8, input, " ,");
    while (it.next()) |num| {
        const n = try parseInt(u32, num, 10);
        try list.append(n);
    }

    const expected = [_]u32{ 123, 67, 89, 99 };

    for (expected, list.items) |exp, actual| {
        try std.testing.expectEqual(exp, actual);
    }
}

pub fn leapYear(year: u16) bool {
    if (year % 400 == 0)
        return true;
    if (year % 100 == 0)
        return false;
    return year % 4 == 0;
}

test "leapYear" {
    try std.testing.expectEqual(true, leapYear(1904));
    try std.testing.expectEqual(false, leapYear(1903));
    try std.testing.expectEqual(false, leapYear(1900));
    try std.testing.expectEqual(true, leapYear(2000));
}

pub fn fizzBuzz(n: u7) []const u8 {
    if (n % 15 == 0)
        return "FizzBuzz";
    if (n % 5 == 0)
        return "Buzz";
    if (n % 3 == 0)
        return "Fizz";
    return ".";
}

test "fizzBuss" {
    try std.testing.expectEqual("Fizz", fizzBuzz(3));
    try std.testing.expectEqual(".", fizzBuzz(1));
    try std.testing.expectEqual("Buzz", fizzBuzz(5));
    try std.testing.expectEqual("FizzBuzz", fizzBuzz(15));
}

const Rover = struct {
    x: u8,
    y: u8,
    direction: Direction,

    fn fromString(s: []const u8) !Rover {
        const parts = try split3(s);

        const x = try parseInt(u8, parts[0], 10);
        const y = try parseInt(u8, parts[1], 10);
        const dir = parts[2];
        if (dir.len != 1)
            return error.InvalidArgument;
        const direction = switch (dir[0]) {
            'N' => Direction.north,
            'S' => Direction.south,
            'E' => Direction.east,
            'W' => Direction.west,
            else => return error.InvalidArgument,
        };

        return .{ .x = x, .y = y, .direction = direction };
    }
};

fn split3(input: []const u8) !([3][]const u8) {
    var splitter = std.mem.splitSequence(u8, input, " ");

    const a = splitter.next() orelse return error.TooFewParts;
    const b = splitter.next() orelse return error.TooFewParts;
    const c = splitter.next() orelse return error.TooFewParts;

    if (splitter.next() != null) return error.TooManyParts;

    return .{ a, b, c };
}

const Direction = enum { north, south, east, west };

test "mars rover parser - positive examples" {
    try std.testing.expectEqual(Rover{ .x = 3, .y = 4, .direction = Direction.north }, Rover.fromString("3 4 N"));
    try std.testing.expectEqual(Rover{ .x = 5, .y = 6, .direction = Direction.south }, Rover.fromString("5 6 S"));
    try std.testing.expectEqual(Rover{ .x = 5, .y = 6, .direction = Direction.east }, Rover.fromString("5 6 E"));
    try std.testing.expectEqual(Rover{ .x = 5, .y = 6, .direction = Direction.west }, Rover.fromString("5 6 W"));
}

test "mars rover parser - error examples" {
    try std.testing.expectError(error.InvalidArgument, Rover.fromString("3 4 X"));
    try std.testing.expectError(error.InvalidCharacter, Rover.fromString("doh! 4 X"));
    try std.testing.expectError(error.TooManyParts, Rover.fromString("0 1 2 3 4 N"));
    try std.testing.expectError(error.InvalidArgument, Rover.fromString("0 1 North"));
}

const List = std.array_list.Managed;

const MarsRoverProblem = struct {
    rovers: List(Rover),
    instructions: List([]const u8),

    fn init(ally: std.mem.Allocator, input: []const u8) !MarsRoverProblem {
        var rovers = std.array_list.Managed(Rover).init(ally);
        var instructions = std.array_list.Managed([]const u8).init(ally);

        var it = std.mem.splitScalar(u8, input, '\n');
        if (it.next() == null) return error.TooFewParts;
        while (true) {
            const roverString = it.next() orelse break;
            const instructionString = it.next() orelse return error.TooFewParts;
            try rovers.append(try Rover.fromString(roverString));
            try instructions.append(instructionString);
        }

        return MarsRoverProblem{
            .rovers = rovers,
            .instructions = instructions,
        };
    }

    fn deinit(self: *MarsRoverProblem) void {
        self.rovers.deinit();
        self.instructions.deinit();
    }
};

test "mars rover problem parser" {
    // Arrange
    const rovers = [_]Rover{
        Rover{ .x = 1, .y = 2, .direction = Direction.north },
        Rover{ .x = 3, .y = 4, .direction = Direction.east },
    };
    const instruction1: []const u8 = "LRLRMM";
    const instruction2: []const u8 = "RMMRMM";
    const instructions = [_][]const u8{ instruction1, instruction2 };

    // Act
    var problemDesc = try MarsRoverProblem.init(std.testing.allocator, "5 5\n1 2 N\nLRLRMM\n3 4 E\nRMMRMM");
    defer problemDesc.deinit();

    // Assert
    try std.testing.expectEqualSlices(Rover, &rovers, problemDesc.rovers.items);
    std.log.debug("{}", .{instructions.len});
    for (instructions, problemDesc.instructions.items) |exp, actual| {
        try std.testing.expectEqualSlices(u8, exp, actual);
    }
}

// Example of 'fat union return value'

const ParseError = struct {
    kind: enum {
        UnexpectedToken,
        UnterminatedString,
        InvalidNumber,
    },
    line: usize,
    column: usize,
    message: []const u8,
};

const ParseResult = union(enum) {
    success: []const u8,
    err: ParseError,
};

test "floating point arithmetic" {
    const t: f32 = 0.2;
    const numPeriods: f32 = t/0.5;
    const intNumPeriods: i32 = @intFromFloat(numPeriods);
    const blink: bool = intNumPeriods % 2 == 1;
    try std.testing.expectEqual(false, blink);
}

test "modulo is available for unsigned integers" {
    const a: u32 = 500;
    const b: u32 = 5;
    const result: u32 = a % b;
    try std.testing.expectEqual(0, result);
}

test "@mod is needed for signed integers" {
    const a: i32 = 10;
    const b: i32 = 3;
    const result: i32 = @mod(a, b);
    try std.testing.expectEqual(1, result);
}

test "@rem meaning" {
    try std.testing.expectEqual(1, @rem(3, 2));
    try std.testing.expectEqual(0, @rem(2, 2));
    try std.testing.expectEqual(1, @rem(1, 2));
    try std.testing.expectEqual(0, @rem(0, 2));
    try std.testing.expectEqual(-1, @rem(-1, 2));
    try std.testing.expectEqual(0, @rem(-2, 2));
}
