

pub fn v(x: f32, y: f32) V {
    return V{ x, y };
}

pub const V: type = @Vector(2, f32);
