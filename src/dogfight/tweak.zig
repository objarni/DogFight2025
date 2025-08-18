const std = @import("std");

pub fn number(comptime T: type) !f32 {
    const file = try std.fs.cwd().openFile("tweak.txt", .{});
    defer file.close();
    var buf: [32]u8 = undefined;
    const len = try file.readAll(&buf);
    return std.fmt.parseFloat(T, buf[0..len]) catch {
        return 10.0;
    };
}