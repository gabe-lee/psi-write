const block_alloc = @import("pooled_block_alloc");
const PooledBlockAllocator = block_alloc.PooledBlockAllocator;
const BlockAllocator = block_alloc.BlockAllocator;
const StaticAllocBuffer = block_alloc.StaticAllocBuffer;

const assert = @import("std").debug.assert;
const std = @import("std");
const mem = std.mem;
const time = std.time;
const math = std.math;
const TextSegment = @import("./Document.zig").TextSegment;
const SegmentAction = @import("SegmentAction.zig");
const global = @import("./Global.zig");
const settings = @import("./Settings.zig").user_settings;

const Self = @This();
const ActiveBuf = StaticAllocBuffer.define(TextSegment, &global.medium_block_alloc);
const InactiveBuf = StaticAllocBuffer.define(TextSegment, &global.small_block_alloc);
const ActionBuf = StaticAllocBuffer.define(SegmentAction, &global.small_block_alloc);
const GroupBuf = StaticAllocBuffer.define(u32, &global.small_block_alloc);

const T_SEG_IDX = SegmentAction.T_INDEX;
const T_COUNT = SegmentAction.T_COUNT;

active_list: ActiveBuf.List,
inactive_list: InactiveBuf.List,
action_list: ActionBuf.List,
group_list: GroupBuf.List,
current_group_idx: u32,
current_action_idx: u32,
current_history_group_locks: u32,
last_action_group_min_timestamp: i64,
last_action_group_max_timestamp: i64,
last_action_group_refresh_timestamp: i64,
last_group_action_count: u32,
last_group_byte_count: u32,

pub inline fn create() !Self {
    return Self.create_with_min_capacity(0, 0, 0, 0);
}

pub fn create_with_min_capacity(active_segments: usize, inactive_segments: usize, history_groups: usize, action_count: usize) Self {
    const active: ActiveBuf.List = if (active_segments == 0) ActiveBuf.List.create() else ActiveBuf.List.create_with_capacity(active_segments);
    const inactive: InactiveBuf.List = if (inactive_segments == 0) InactiveBuf.List.create() else InactiveBuf.List.create_with_capacity(inactive_segments);
    const action: ActionBuf.List = if (action_count == 0) ActionBuf.List.create() else ActionBuf.List.create_with_capacity(action_count);
    const group: GroupBuf.List = if (history_groups == 0) GroupBuf.List.create() else GroupBuf.List.create_with_capacity(history_groups);
    return Self{
        .active_list = active,
        .inactive_list = inactive,
        .action_list = action,
        .group_list = group,
        .current_group_idx = 0,
        .current_action_idx = 0,
        .current_history_group_locks = 0,
        .last_action_group_min_timestamp = 0,
        .last_action_group_max_timestamp = 0,
        .last_action_group_refresh_timestamp = 0,
        .last_group_action_count = 0,
        .last_group_byte_count = 0,
    };
}

pub inline fn destroy(self: *Self) void {
    self.active_list.release();
    self.inactive_list.release();
    self.action_list.release();
    self.group_list.release();
    self.current_group_idx = 0;
    self.current_action_idx = 0;
    self.current_history_group_locks = 0;
    self.last_action_group_min_timestamp = 0;
    self.last_action_group_max_timestamp = 0;
    self.last_action_group_refresh_timestamp = 0;
    self.last_group_action_count = 0;
    self.last_group_byte_count = 0;
}

pub fn should_start_new_history_group(self: *Self) bool {
    const time_now = time.milliTimestamp();
    const history_group_not_locked = self.current_history_group_locks == 0;
    const has_no_existing_groups = self.group_list.len == 0;
    const not_at_end_of_history = !self.at_end_of_history();
    const group_meets_minimum_actions = self.last_group_action_count >= settings.HistoryGroupMinActions;
    const group_meets_minimum_bytes = self.last_group_byte_count >= settings.HistoryGroupMinBytes;
    const group_has_exceeded_max_time = time_now > self.last_action_group_max_timestamp;
    const group_has_exceeded_min_time_and_refresh = time_now > self.last_action_group_min_timestamp and time_now > self.last_action_group_refresh_timestamp;
    return (has_no_existing_groups or not_at_end_of_history or (history_group_not_locked and group_meets_minimum_actions and group_meets_minimum_bytes and (group_has_exceeded_max_time or group_has_exceeded_min_time_and_refresh)));
}

pub inline fn at_end_of_history(self: *Self) bool {
    assert(if (self.current_group_idx == self.group_list.len) self.current_action_idx == self.action_list.len else true);
    return self.current_group_idx == self.group_list.len;
}

pub inline fn at_beginning_of_history(self: *Self) bool {
    assert(if (self.current_group_idx == 0) self.current_action_idx == 0 else true);
    return self.current_group_idx == self.group_list.len;
}

pub fn start_new_history_group(self: *Self) void {
    assert(self.current_group_idx <= self.group_list.len);
    const time_now = time.milliTimestamp();
    self.last_action_group_min_timestamp = time_now + settings.HistoryGroupMinTime;
    self.last_action_group_max_timestamp = time_now + settings.HistoryGroupMaxTime;
    if (!self.at_end_of_history()) {
        var group_to_invert_idx = self.group_list.len - 1;
        var action_count: u32 = 0;
        while (group_to_invert_idx >= self.current_group_idx) {
            action_count += self.group_list.ptr[group_to_invert_idx];
            if (group_to_invert_idx == 0) break;
            group_to_invert_idx -= 1;
        }
        const max_invert_count: T_COUNT = @as(T_COUNT, @intCast(action_count / math.maxInt(T_SEG_IDX)));
        const leftover_inverts: T_SEG_IDX = @as(T_SEG_IDX, @intCast(action_count % math.maxInt(T_SEG_IDX)));
        var action = SegmentAction{};
        action.set_index(leftover_inverts);
        action.set_count(max_invert_count);
        action.set_kind(.InvertPrevious);
        self.group_list.append(1);
        self.action_list.append(SegmentAction);
        while (self.current_action_idx < self.action_list.len) {
            self.move_forward_one_history_action();
        }
    } else {
        self.compress_finished_history_group();
    }
    self.current_group_idx = self.group_list.len;
    self.group_list.append(0);
    self.current_action_idx = self.action_list.len;
}

pub inline fn add_lock_to_current_history_group(self: *Self) void {
    self.current_history_group_locks += 1;
}

pub inline fn remove_lock_from_current_history_group(self: *Self) void {
    self.current_history_group_locks -= 1;
}

pub inline fn move_backward_one_history_group(self: *Self) void {
    assert(self.current_history_group_locks == 0);
    assert(self.current_group_idx > 0);
    self.current_group_idx -= 1;
    const final_action_idx = self.current_action_idx - self.group_list.ptr[self.current_group_idx];
    while (self.current_action_idx > final_action_idx) {
        self.move_backward_one_history_action();
    }
}

pub inline fn move_forward_one_history_group(self: *Self) void {
    assert(self.current_history_group_locks == 0);
    assert(self.current_group_idx < self.group_list.len - 1);
    self.current_group_idx += 1;
    const final_action_idx = self.current_action_idx + self.group_list.ptr[self.current_group_idx];
    assert(final_action_idx <= self.action_list.len);
    while (self.current_action_idx <= final_action_idx) {
        self.move_forward_one_history_action();
    }
}

inline fn move_backward_one_history_action(self: *Self) void {
    assert(self.current_history_group_locks == 0);
    assert(self.current_action_idx < self.action_list.len);
    assert(self.current_action_idx != 0);
    const action = self.action_list.ptr[self.current_action_idx];
    const segment_idx = action.get_index();
    const action_kind = action.get_kind();
    const action_count = action.get_count();
    const final_current_action_idx = self.current_action_idx - 1;
    switch (action_kind) {
        .DecreaseLen => {
            assert(segment_idx < self.active_list.len);
            assert(self.active_list.ptr[segment_idx].byte_count <= math.maxInt(T_COUNT) - action_count);
            self.active_list.ptr[segment_idx].byte_count += action_count;
        },
        .IncreaseLen => {
            assert(segment_idx < self.active_list.len);
            assert(self.active_list.ptr[segment_idx].byte_count >= action_count);
            self.active_list.ptr[segment_idx].byte_count -= action_count;
        },
        .DecreaseStart => {
            assert(segment_idx < self.active_list.len);
            assert(self.active_list.ptr[segment_idx].byte_start <= math.maxInt(T_COUNT) - action_count);
            self.active_list.ptr[segment_idx].byte_start += action_count;
        },
        .IncreaseStart => {
            assert(segment_idx < self.active_list.len);
            assert(self.active_list.ptr[segment_idx].byte_start >= action_count);
            self.active_list.ptr[segment_idx].byte_start -= action_count;
        },
        .RemoveToInactive => {
            assert(segment_idx <= self.active_list.len);
            assert(self.inactive_list.len != 0);
            const segment = self.inactive_list.pop();
            self.active_list.insert(segment_idx, segment);
        },
        .RestoreToActive => {
            assert(segment_idx < self.active_list.len);
            const segment = self.action_list.remove(segment_idx);
            self.inactive_list.append(segment);
        },
        .InvertPrevious => {
            assert(self.current_action_idx > 0);
            const total_inverts = (action_count * math.maxInt(T_SEG_IDX)) + segment_idx;
            assert(total_inverts <= self.current_action_idx);
            self.current_action_idx -= total_inverts;
            while (self.current_action_idx < final_current_action_idx) {
                self.move_forward_one_history_action();
            }
        },
    }
    self.current_action_idx = final_current_action_idx;
}

fn move_forward_one_history_action(self: *Self) void {
    assert(self.current_history_group_locks == 0);
    assert(self.current_action_idx < self.action_list.len);
    const action = self.action_list.ptr[self.current_action_idx];
    const segment_idx = action.get_index();
    const action_kind = action.get_kind();
    const action_count = action.get_count();
    const final_current_action_idx = self.current_action_idx + 1;
    switch (action_kind) {
        .DecreaseLen => {
            assert(segment_idx < self.active_list.len);
            assert(self.active_list.ptr[segment_idx].byte_count >= action_count);
            self.active_list.ptr[segment_idx].byte_count -= action_count;
        },
        .IncreaseLen => {
            assert(segment_idx < self.active_list.len);
            assert(self.active_list.ptr[segment_idx].byte_count <= math.maxInt(T_COUNT) - action_count);
            self.active_list.ptr[segment_idx].byte_count += action_count;
        },
        .DecreaseStart => {
            assert(segment_idx < self.active_list.len);
            assert(self.active_list.ptr[segment_idx].byte_start >= action_count);
            self.active_list.ptr[segment_idx].byte_start -= action_count;
        },
        .IncreaseStart => {
            assert(segment_idx < self.active_list.len);
            assert(self.active_list.ptr[segment_idx].byte_start <= math.maxInt(T_COUNT) - action_count);
            self.active_list.ptr[segment_idx].byte_start += action_count;
        },
        .RemoveToInactive => {
            assert(segment_idx < self.active_list.len);
            const segment = self.action_list.remove(segment_idx);
            self.inactive_list.append(segment);
        },
        .RestoreToActive => {
            assert(segment_idx <= self.active_list.len);
            assert(self.inactive_list.len != 0);
            const segment = self.inactive_list.pop();
            self.active_list.insert(segment_idx, segment);
        },
        .InvertPrevious => {
            assert(self.current_action_idx > 0);
            const total_inverts = (action_count * math.maxInt(T_SEG_IDX)) + segment_idx;
            assert(total_inverts <= self.current_action_idx);
            const last_invert_idx = self.current_action_idx - total_inverts;
            self.current_action_idx -= 1;
            while (self.current_action_idx >= last_invert_idx) {
                self.move_backward_one_history_action();
            }
        },
    }
    self.current_action_idx = final_current_action_idx;
}

pub inline fn compress_finished_history_group(self: *Self) void {
    _ = self;
    //TODO
}

pub inline fn is_at_end_of_segment(self: *Self, segment_idx: T_SEG_IDX, byte_offset: T_COUNT) bool {
    return byte_offset == self.active_list.ptr[segment_idx].byte_count;
}

pub inline fn is_at_start_of_segment(byte_offset: T_COUNT) bool {
    return byte_offset == 0;
}

pub inline fn assert_sane_segment_location(self: *Self, segment_idx: T_SEG_IDX, byte_offset: T_COUNT) void {
    assert(segment_idx < self.active_list.len);
    assert(byte_offset <= self.active_list.ptr[segment_idx].byte_count);
}

pub inline fn decrease_segment_length(self: *Self, segment_idx: T_SEG_IDX, delta: T_COUNT) void {
    assert(delta != 0);
    assert(self.current_action_idx == self.action_list.len);
    self.active_list.ptr[segment_idx].byte_count -= delta;
    self.action_list.append(SegmentAction.new(.DecreaseLen, segment_idx, delta));
    self.group_list.ptr[self.current_group_idx] += 1;
    self.current_action_idx += 1;
}

pub inline fn increase_segment_length(self: *Self, segment_idx: T_SEG_IDX, delta: T_COUNT) void {
    assert(delta != 0);
    assert(self.current_action_idx == self.action_list.len);
    self.active_list.ptr[segment_idx].byte_count += delta;
    self.action_list.append(SegmentAction.new(.IncreaseLen, segment_idx, delta));
    self.group_list.ptr[self.current_group_idx] += 1;
    self.current_action_idx += 1;
}

pub inline fn decrease_segment_start(self: *Self, segment_idx: T_SEG_IDX, delta: T_COUNT) void {
    assert(delta != 0);
    assert(self.current_action_idx == self.action_list.len);
    self.active_list.ptr[segment_idx].byte_start -= delta;
    self.action_list.append(SegmentAction.new(.DecreaseStart, segment_idx, delta));
    self.group_list.ptr[self.current_group_idx] += 1;
    self.current_action_idx += 1;
}

pub inline fn increase_segment_start(self: *Self, segment_idx: T_SEG_IDX, delta: T_COUNT) void {
    assert(delta != 0);
    assert(self.current_action_idx == self.action_list.len);
    self.active_list.ptr[segment_idx].byte_start += delta;
    self.action_list.append(SegmentAction.new(.IncreaseStart, segment_idx, delta));
    self.group_list.ptr[self.current_group_idx] += 1;
    self.current_action_idx += 1;
}

pub inline fn restore_segments_to_active(self: *Self, insert_idx: T_SEG_IDX, count: T_COUNT) void {
    assert(count != 0);
    assert(self.current_action_idx == self.action_list.len);
    const new_slots = self.active_list.insert_slots(insert_idx, count);
    const slice_to_move = self.inactive_list.slice()[self.inactive_list.len - new_slots.len ..];
    @memcpy(new_slots, slice_to_move);
    self.inactive_list.shrink_len_by_count(new_slots.len);
    self.action_list.append(SegmentAction.new(.RestoreToActive, insert_idx, count));
    self.group_list.ptr[self.current_group_idx] += 1;
    self.current_action_idx += 1;
}

pub inline fn remove_segments_from_active(self: *Self, remove_idx: usize, count: T_COUNT) void {
    assert(count != 0);
    assert(self.current_action_idx == self.action_list.len);
    const new_inactive_slots = self.inactive_list.append_slots_slice_ptr(count);
    self.active_list.transplant_range(remove_idx, count, new_inactive_slots);
    self.action_list.append(SegmentAction.new(.RemoveToInactive, remove_idx, count));
    self.group_list.ptr[self.current_group_idx] += 1;
    self.current_action_idx += 1;
}

pub inline fn add_brand_new_segments(self: *Self, insert_idx: T_SEG_IDX, segments: []const TextSegment) void {
    assert(segments.len != 0);
    assert(self.current_action_idx == self.action_list.len);
    self.inactive_list.append_slice(segments);
    self.restore_segments_to_active(insert_idx, segments.len);
}
