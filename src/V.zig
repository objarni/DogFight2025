pub fn v(x: f32, y: f32) V {
    return V{ x, y };
}

pub fn lerp(a: V, b: V, t: f32) V {
    return v(
        std.math.lerp(a[0], b[0], t),
        std.math.lerp(a[1], b[1], t),
    );
}

pub const V: type = @Vector(2, f32);

const std = @import("std");

test "lerp" {
    const v1 = v(0, 0);
    const v2 = v(10, 5);
    const t = 0.5;
    const expected = v(5, 2.5);
    const actual = lerp(v1, v2, t);
    try std.testing.expectEqual(expected, actual);
    try std.testing.expectEqual(v(0, 0), lerp(v1, v2, 0.0));
    try std.testing.expectEqual(v(10, 5), lerp(v1, v2, 1.0));
}
