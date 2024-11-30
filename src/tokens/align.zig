pub const Align = enum(u8) {
    pub fn from_u128_unchecked(val: u128) Align {
        return @enumFromInt(@as(u8, @truncate(val)));
    }

    pub fn from_u128(val: u128) Align {
        return @enumFromInt(@min(@as(u8, @truncate(val)), 3));
    }

    pub fn to_u128(self: Align) u128 {
        return @as(u128, @intFromEnum(self));
    }

    Left = 0,
    Center = 1,
    Right = 2,
    Justify = 3,
};
