pub const ListType = enum(u8) {
    pub fn from_u128_unchecked(val: u128) ListType {
        return @enumFromInt(@as(u8, @truncate(val)));
    }

    pub fn from_u128(val: u128) ListType {
        return @enumFromInt(@min(@as(u8, @truncate(val)), 12));
    }

    pub fn to_u128(self: ListType) u128 {
        return @as(u128, @intFromEnum(self));
    }

    Number = 0,
    AlphaUpper = 1,
    AlphaLower = 2,
    RomanUpper = 3,
    RomanLower = 4,
    CircleFilled = 5,
    CircleHollow = 6,
    SquareFilled = 7,
    SquareHollow = 8,
    ArrowFilled = 9,
    ArrowHollow = 10,
    ChecklistDone = 11,
    ChecklistTodo = 12,
};
