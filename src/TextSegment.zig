const assert = @import("std").debug.assert;
const std = @import("std");
const math = std.math;

const Self = @This();

pub const T_BUF_IDX = u16;
pub const T_BYTE_IDX = u16;

pub const NO_DATA_BUF = math.maxInt(T_BUF_IDX);

buffer_idx: T_BUF_IDX = NO_DATA_BUF,
byte_start: T_BYTE_IDX = 0,
byte_count: T_BYTE_IDX = 0,
