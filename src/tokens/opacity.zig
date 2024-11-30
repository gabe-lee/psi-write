pub const Opacity = struct {
    pub fn from_u128(val: u128) Opacity {
        return Opacity{ .val = @truncate(val) };
    }

    pub fn to_u128(self: Opacity) u128 {
        return @as(u128, self.val);
    }

    val: u8,
};
