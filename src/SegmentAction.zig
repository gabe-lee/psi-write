const TextSegment = @import("./Document.zig").TextSegment;

const Self = @This();

pub const T_INDEX = u29;
pub const T_COUNT = u16;
pub const T_KINDINT = u3;
const T_DAT = u16;

_dat_1: T_DAT = 0,
_dat_2: T_DAT = 0,
_dat_3: T_DAT = 0,

const IDX_1_MASK: comptime_int = 0b00011111_11111111;
const IDX_1_SHIFT_OUT: comptime_int = 16;
const IDX_2_MASK: comptime_int = 0b11111111_11111111;
const ACT_1_MASK: comptime_int = 0b11100000_00000000;
const ACT_1_SHIFT_IN: comptime_int = 13;

/// If kind == InvertPrevious, this represents the number of previous actions to invert
///
/// Else this represents the segment index to perform the action on
pub inline fn get_index(self: Self) T_INDEX {
    return (@as(T_INDEX, @intCast(self._dat_1 & IDX_1_MASK)) << IDX_1_SHIFT_OUT) | @as(T_INDEX, @intCast(self._dat_2));
}

/// If kind == InvertPrevious, this represents the number of previous actions to invert
///
/// Else this represents the segment index to perform the action on
pub inline fn set_index(self: *Self, idx: T_INDEX) void {
    self._dat_1 = (self._dat_1 & ACT_1_MASK) | (@as(T_DAT, @intCast(idx >> IDX_1_SHIFT_OUT)) & IDX_1_MASK);
    self._dat_2 = @as(T_DAT, @intCast(idx & IDX_2_MASK));
}

/// Describes the action that was performed in the forward direction
pub inline fn get_kind(self: Self) ActionKind {
    return @enumFromInt(@as(T_KINDINT, @intCast(self._dat_1 & ACT_1_MASK)) >> ACT_1_SHIFT_IN);
}

/// Describes the action that was performed in the forward direction
pub inline fn set_kind(self: *Self, kind: ActionKind) void {
    self._dat_1 = (self._dat_1 & IDX_1_MASK) | (@as(T_DAT, @intCast(@intFromEnum(kind))) << ACT_1_SHIFT_IN);
}

/// If kind == InvertPrevious, this represents the number of additional MAX VAL (math.maxInt(T_INDEX)) inversions to add on to the ones from .get_index()
///
/// If kind == RemoveToInactive OR RestoreToActive, this represents the number of segments to transfer to/from incative list
///
/// Else this represents the value to increase/decrease the segment property by
pub inline fn get_count(self: Self) T_COUNT {
    return self._dat_3;
}

/// If kind == InvertPrevious, this represents the number of additional MAX VAL (math.maxInt(T_INDEX)) inversions to add on to the ones from .get_index()
///
/// If kind == RemoveToInactive OR RestoreToActive, this represents the number of segments to transfer to/from incative list
///
/// Else this represents the value to increase/decrease the segment property by
pub inline fn set_count(self: *Self, val: T_COUNT) void {
    self._dat_3 = val;
}

pub inline fn set_all(self: *Self, kind: ActionKind, index: T_INDEX, count: T_COUNT) void {
    self.set_kind(kind);
    self.set_index(index);
    self.set_count(count);
}

pub inline fn new(kind: ActionKind, index: T_INDEX, count: T_COUNT) Self {
    var self = Self{};
    self.set_all(kind, index, count);
    return self;
}

pub const ActionKind = enum(T_KINDINT) {
    IncreaseLen,
    DecreaseLen,
    IncreaseStart,
    DecreaseStart,
    RemoveToInactive,
    RestoreToActive,
    InvertPrevious,
    //Unused
};
