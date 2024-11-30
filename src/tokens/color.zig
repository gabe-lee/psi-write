pub const ColorRGB8 = struct {
    pub const BLACK: ColorRGB8 = ColorRGB8{ .val = [3]u8{ 0, 0, 0 } };
    pub const WHITE: ColorRGB8 = ColorRGB8{ .val = [3]u8{ 255, 255, 255 } };
    pub const PURE_RED: ColorRGB8 = ColorRGB8{ .val = [3]u8{ 255, 0, 0 } };
    pub const PURE_YELLOW: ColorRGB8 = ColorRGB8{ .val = [3]u8{ 255, 255, 0 } };
    pub const PURE_GREEN: ColorRGB8 = ColorRGB8{ .val = [3]u8{ 0, 255, 0 } };
    pub const PURE_CYAN: ColorRGB8 = ColorRGB8{ .val = [3]u8{ 0, 255, 255 } };
    pub const PURE_BLUE: ColorRGB8 = ColorRGB8{ .val = [3]u8{ 0, 0, 255 } };
    pub const PURE_MAGENTA: ColorRGB8 = ColorRGB8{ .val = [3]u8{ 255, 0, 255 } };

    pub fn from_u32(val: u32) ColorRGB8 {
        return ColorRGB8{ .val = [3]u8{ @as(u8, val >> 16), @as(u8, val >> 8), @as(u8, val) } };
    }

    pub fn to_u32(self: ColorRGB8) u32 {
        return (@as(u32, self.val[0]) << 16) | (@as(u32, self.val[1]) << 8) | @as(u32, self.val[2]);
    }

    pub fn from_u128(val: u128) ColorRGB8 {
        return ColorRGB8{ .val = [3]u8{ @as(u8, val >> 16), @as(u8, val >> 8), @as(u8, val) } };
    }

    pub fn to_u128(self: ColorRGB8) u128 {
        return (@as(u128, self.val[0]) << 16) | (@as(u128, self.val[1]) << 8) | @as(u128, self.val[2]);
    }

    val: [3]u8,
};
