pub const EmbedPosition = struct {
    pub fn from_u128(val: u128) EmbedPosition {
        return EmbedPosition{ .offset = @truncate(val >> 32), .len = @truncate(val) };
    }

    pub fn to_u128(self: EmbedPosition) u128 {
        return (@as(u128, self.offset) << 32) | @as(u128, self.len);
    }

    offset: u32,
    len: u32,
};
