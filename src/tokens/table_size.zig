pub const TableSize = struct {
    pub fn from_u128(val: u128) TableSize {
        return TableSize{ .rows = @truncate(val >> 8), .cols = @truncate(val) };
    }

    pub fn to_u128(self: TableSize) u128 {
        return (@as(u128, self.rows) << 8) | @as(u128, self.cols);
    }

    rows: u8,
    cols: u8,
};
