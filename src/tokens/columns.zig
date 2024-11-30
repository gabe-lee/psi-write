pub const Columns = struct {
    pub fn from_u128(val: u128) Columns {
        return Columns{ .val = @truncate(val) };
    }

    pub fn to_u128(self: Columns) u128 {
        return @as(u128, self.val);
    }

    val: u8,
};
