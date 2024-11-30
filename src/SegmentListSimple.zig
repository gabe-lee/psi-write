const block_alloc = @import("block_alloc");
const PooledBlockAllocator = block_alloc.PooledBlockAllocator;
const BlockAllocator = block_alloc.BlockAllocator;
const StaticAllocBuffer = block_alloc.StaticAllocBuffer;

const assert = @import("std").debug.assert;
const std = @import("std");
const mem = std.mem;
const TextSegment = @import("./Document.zig").TextSegment;
const global = @import("./Global.zig");

active_list: ActiveBuf.List,
inactive_list: InactiveBuf.List,

const SEG_SIZE = @sizeOf(TextSegment);

const Self = @This();
const ActiveBuf = StaticAllocBuffer.define(TextSegment, &global.medium_block_alloc);
const InactiveBuf = StaticAllocBuffer.define(TextSegment, &global.small_block_alloc);

pub inline fn create() !Self {
    return Self.create_with_min_capacity(0, 0);
}

pub fn create_with_min_capacity(active_segments: usize, inactive_segments: usize) Self {
    const active: ActiveBuf.List = if (active_segments == 0) ActiveBuf.List.create() else ActiveBuf.List.create_with_capacity(active_segments);
    const inactive: InactiveBuf.List = if (inactive_segments == 0) InactiveBuf.List.create() else InactiveBuf.List.create_with_capacity(inactive_segments);
    return Self{
        .active_list = active,
        .inactive_list = inactive,
    };
}

pub inline fn destroy(self: *Self) void {
    self.active_list.release();
    self.inactive_list.release();
}

// pub inline fn get_seg_copy(self: *Self, idx: u32) TextSegment {
//     return self.rings_ptr[idx.ring].items[idx.within_ring_abs];
// }

// pub inline fn get_seg_ptr(self: *Self, idx: Index) *TextSegment {
//     return &self.rings_ptr[idx.ring].items[idx.within_ring_abs];
// }

// pub inline fn set_seg_with_idx(self: *Self, idx: Index, seg_val: TextSegment) void {
//     self.rings_ptr[idx.ring].items[idx.within_ring_abs] = seg_val;
// }

// pub inline fn set_seg_with_ptr(self: *TextSegment, seg_val: TextSegment) void {
//     self.* = seg_val;
// }

//TODO: Fix insert() func to a version using only simple array

pub fn insert(self: *Self, idx: u32, seg: TextSegment) void {
    self.active_list.in
}

inline fn _exchange_val(self: *Self, seg_idx: u32, val: TextSegment) TextSegment {
    const ret = self.ptr[seg_idx];
    self.ptr[seg_idx] = val;
    return ret;
}

inline fn _exchange_2_vals(self: *Self, seg_idxs: [2]u32, vals: [2]TextSegment) [2]TextSegment {
    const ret = [2]TextSegment{ self.ptr[seg_idxs[0]], self.ptr[seg_idxs[1]] };
    self.ptr[seg_idxs[0]] = vals[0];
    self.ptr[seg_idxs[1]] = vals[1];
    return ret;
}
