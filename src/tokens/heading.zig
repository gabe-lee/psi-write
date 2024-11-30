pub const Heading = enum(u8) {
    pub fn from_u128_unchecked(val: u128) Heading {
        return @enumFromInt(@as(u8, @truncate(val)));
    }

    pub fn from_u128(val: u128) Heading {
        return @enumFromInt(@min(@as(u8, @truncate(val)), 7));
    }

    pub fn to_u128(self: Heading) u128 {
        return @as(u128, @intFromEnum(self));
    }

    None = 0,
    H6 = 1,
    H5 = 2,
    H4 = 3,
    H3 = 4,
    H2 = 5,
    H1 = 6,
    H0 = 7,
};
