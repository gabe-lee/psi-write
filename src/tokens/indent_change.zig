pub const IndentChange = struct {
    pub fn from_u128(val: u128) IndentChange {
        return IndentChange{ .val = @truncate(val) };
    }

    pub fn to_u128(self: IndentChange) u128 {
        return @as(u128, self.val);
    }

    val: i8,
};
