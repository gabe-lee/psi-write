const std = @import("std");

const Self = @This();

HistoryGroupMaxTime: Setting(i64),
HistoryGroupMinTime: Setting(i64),
HistoryGroupIntermediateTimeout: Setting(i64),
HistoryGroupMinActions: Setting(u32),
HistoryGroupMinBytes: Setting(u32),

pub var user_settings: Self = DEFAULT;

pub const SettingSource = enum(u8) {
    Default,
    User,
    LiteraryUniverse,
    LiteraryStory,
    LiteraryFile,
};

pub fn Setting(T: type) type {
    return struct {
        source: SettingSource,
        val: T,

        const SettingSelf: type = @This();

        pub fn new(source: SettingSource, val: T) SettingSelf {
            return SettingSelf{
                .source = source,
                .val = val,
            };
        }
    };
}

const DEFAULT = Self{
    .HistoryGroupMaxTime = Setting(i64).new(.Default, 10000),
    .HistoryGroupMinTime = Setting(i64).new(.Default, 3000),
    .HistoryGroupIntermediateTimeout = Setting(i64).new(.Default, 1000),
    .HistoryGroupMinActions = Setting(u32).new(.Default, 1),
    .HistoryGroupMinBytes = Setting(u32).new(.Default, 10),
};
