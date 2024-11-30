pub const FontSize = struct {
    pub fn from_u128(val: u128) FontSize {
        return FontSize{ .size = @truncate(val) };
    }

    pub fn to_u128(self: FontSize) u128 {
        return @as(u128, self.size);
    }

    pub fn to_f32_scale(self: FontSize) f32 {
        return self.size * 0.01;
    }

    size: u16,
};
