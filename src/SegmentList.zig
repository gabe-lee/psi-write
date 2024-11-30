const assert = @import("std").debug.assert;
const std = @import("std");
const mem = std.mem;
const FullPageAllocator = @import("./FullPageAllocator.zig");
const TextSegment = @import("./Document.zig").TextSegment;

rings_ptr: [*]Ring,
rings_len: u32,
segs_len: u32,
last_ring_len: u32,
last_ring_start_idx: u16,
bytes_left_in_allocation: u32,
removed_ptr: [*]TextSegment,
removed_len: u32,
pages_allocated: u16,

const RING_SIZE = @sizeOf(Ring);
const SEG_SIZE = @sizeOf(TextSegment);
const RING_CAPACITY = 256;
const RING_LAST_IDX = RING_CAPACITY - 1;

const Self = @This();
const Ring = struct {
    limit_idx: u16 = 0,
    items: [RING_CAPACITY]TextSegment = undefined,
};
const Index = struct { ring: u32, within_ring_rel: u16, within_ring_abs: u16 };

pub inline fn create_new() !Self {
    return Self.create_with_capacity(RING_SIZE + SEG_SIZE);
}

pub fn create_with_capacity(required_bytes: usize) !Self {
    const alloc_pages = FullPageAllocator.pages_needed_for_bytes(required_bytes);
    const alloc_ptr = try FullPageAllocator.alloc(alloc_pages);
    const alloc_bytes = FullPageAllocator.bytes_in_pages(alloc_pages);
    const list = Self{ .rings_ptr = @ptrCast(alloc_ptr), .rings_len = 1, .segs_len = 0, .last_ring_len = 0, .last_ring_start_idx = 0, .bytes_left_in_allocation = alloc_bytes - RING_SIZE, .removed_ptr = @ptrCast(alloc_ptr + alloc_bytes), .removed_len = 0, .pages_allocated = alloc_pages };
    list.rings_ptr[0] = Ring{};
    return list;
}

fn _grow_if_needed_for_n_more_bytes(self: *Self, n: usize) !void {
    if (self.bytes_left_in_allocation > n) {
        return;
    }
    const extra_bytes_required = n - self.bytes_left_in_allocation;
    const extra_pages_required = FullPageAllocator.pages_needed_for_bytes(extra_bytes_required);
    const new_total_pages = self.pages_allocated + extra_pages_required;
    const new_total_bytes = FullPageAllocator.bytes_in_pages(new_total_pages);
    const new_ptr = try FullPageAllocator.alloc(new_total_pages);
    const ring_bytes_to_copy = self.rings_len * RING_SIZE;
    @memcpy(new_ptr[0..ring_bytes_to_copy], self.rings_ptr[0..ring_bytes_to_copy]);
    self.bytes_left_in_allocation = new_total_bytes - ring_bytes_to_copy;
    if (self.removed_len > 0) {
        const old_total_bytes = FullPageAllocator.bytes_in_pages(self.pages_allocated);
        const removed_bytes_to_copy = self.removed_len * SEG_SIZE;
        const removed_new_start_byte = new_total_bytes - removed_bytes_to_copy;
        const removed_old_start_byte = old_total_bytes - removed_bytes_to_copy;
        @memcpy(new_ptr[removed_new_start_byte..new_total_bytes], self.rings_ptr[removed_old_start_byte..old_total_bytes]);
        self.removed_ptr = @ptrCast(new_ptr + removed_new_start_byte);
        self.bytes_left_in_allocation -= removed_bytes_to_copy;
    } else {
        self.removed_ptr = @ptrCast(new_ptr + new_total_bytes);
    }
    FullPageAllocator.dealloc(@ptrCast(self.rings_ptr), self.pages_allocated);
    self.rings_ptr = @ptrCast(new_ptr);
    self.pages_allocated = new_total_pages;
}

pub inline fn destroy(self: *Self) void {
    FullPageAllocator.dealloc(@ptrCast(self.rings_ptr), self.pages_allocated);
}

inline fn get_true_index(self: *Self, abs_idx: u32) Index {
    assert(abs_idx < self.segs_len);
    const ring_idx = abs_idx / RING_CAPACITY;
    assert(ring_idx < self.rings_len);
    const within_ring_idx = abs_idx % RING_CAPACITY;
    const ring_start_idx = if (ring_idx == self.rings_len - 1) self.last_ring_start_idx else self.rings_ptr[ring_idx].limit_idx;
    const true_within_ring_idx = (ring_start_idx + within_ring_idx) % RING_CAPACITY;
    return Index{
        .ring = ring_idx,
        .within_ring_rel = within_ring_idx,
        .within_ring_abs = true_within_ring_idx,
    };
}

pub inline fn get_seg_copy(self: *Self, idx: Index) TextSegment {
    return self.rings_ptr[idx.ring].items[idx.within_ring_abs];
}

pub inline fn get_seg_ptr(self: *Self, idx: Index) *TextSegment {
    return &self.rings_ptr[idx.ring].items[idx.within_ring_abs];
}

pub inline fn set_seg_with_idx(self: *Self, idx: Index, seg_val: TextSegment) void {
    self.rings_ptr[idx.ring].items[idx.within_ring_abs] = seg_val;
}

pub inline fn set_seg_with_ptr(self: *TextSegment, seg_val: TextSegment) void {
    self.* = seg_val;
}

pub fn insert(self: *Self, idx: u32, seg: TextSegment) !void {
    assert(idx <= self.segs_len);
    const true_idx = self.get_true_index(idx);
    if (true_idx.ring == self.rings_len - 1 and self.last_ring_len != RING_CAPACITY) {
        switch (true_idx.within_ring_rel) {
            self.last_ring_len => self._insert_end_last_ring_not_full(seg),
            0 => self._insert_start_last_ring_not_full(seg),
            else => self._insert_in_last_ring_not_full(true_idx.within_ring_abs, seg),
        }
    } else {
        var popped = switch (true_idx.within_ring_rel) {
            0 => self._insert_start_pop_end(true_idx.ring, seg),
            RING_LAST_IDX => self._insert_or_remove_end_val(true_idx.ring, seg),
            else => self._insert_and_pop_end(true_idx.ring, true_idx.within_ring_abs, seg),
        };
        if (self.last_ring_len == RING_CAPACITY) {
            try self._add_ring_to_end();
        }
        var next_ring_idx = true_idx.ring + 1;
        while (next_ring_idx != self.rings_len - 1) : (next_ring_idx += 1) {
            popped = self._insert_start_pop_end(next_ring_idx, popped);
        }
        self._insert_start_last_ring_not_full(popped);
    }
    self.segs_len += 1;
}

inline fn _add_ring_to_end(self: *Self) !void {
    assert(self.last_ring_len == RING_CAPACITY);
    try self._grow_if_needed_for_n_more_bytes(RING_SIZE);
    self.rings_ptr[self.rings_len] = Ring{};
    self.rings_len += 1;
    self.last_ring_len = 0;
    self.last_ring_start_idx = 0;
    self.bytes_left_in_allocation -= RING_SIZE;
}

inline fn _exchange_val(self: *Self, ring_idx: u32, sub_idx: u16, val: TextSegment) TextSegment {
    const ret = self.rings_ptr[ring_idx].items[sub_idx];
    self.rings_ptr[ring_idx].items[sub_idx] = val;
    return ret;
}

inline fn _exchange_2_vals(self: *Self, ring_idx: u32, sub_idx_1: u16, sub_idx_2: u16, vals: [2]TextSegment) [2]TextSegment {
    const ret = [2]TextSegment{ self.rings_ptr[ring_idx].items[sub_idx_1], self.rings_ptr[ring_idx].items[sub_idx_2] };
    self.rings_ptr[ring_idx].items[sub_idx_1] = vals[0];
    self.rings_ptr[ring_idx].items[sub_idx_2] = vals[1];
    return ret;
}

/// Ring must be at max capacity
inline fn _insert_start_pop_end(self: *Self, ring_idx: u32, val: TextSegment) TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    const idx = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    const popped = self._exchange_val(ring_idx, idx, val);
    self.rings_ptr[ring_idx].limit_idx = idx;
    return popped;
}

/// Ring must be at max capacity
inline fn _insert_2_start_pop_2_end(self: *Self, ring_idx: u32, vals: [2]TextSegment) [2]TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    const idx_1 = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 2) % RING_CAPACITY;
    const idx_2 = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    const popped = self._exchange_2_vals(ring_idx, idx_1, idx_2, vals);
    self.rings_ptr[ring_idx].limit_idx = idx_1;
    return popped;
}

/// Ring must be at max capacity
inline fn _pop_start_fill_end(self: *Self, ring_idx: u32, end_val: TextSegment) TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    const popped = self._exchange_val(ring_idx, self.rings_ptr[ring_idx].limit_idx, end_val);
    self.rings_ptr[ring_idx].limit_idx = (self.rings_ptr[ring_idx].limit_idx + 1) % RING_CAPACITY;
    return popped;
}

/// Ring must be at max capacity
inline fn _pop_2_start_fill_2_end(self: *Self, ring_idx: u32, end_vals: [2]TextSegment) [2]TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    const idx_1 = self.rings_ptr[ring_idx].limit_idx;
    const idx_2 = (self.rings_ptr[ring_idx].limit_idx + 1) % RING_CAPACITY;
    const popped = self._exchange_2_vals(ring_idx, idx_1, idx_2, end_vals);
    self.rings_ptr[ring_idx].limit_idx = (self.rings_ptr[ring_idx].limit_idx + 1) % RING_CAPACITY;
    return popped;
}

/// Ring must be at max capacity
inline fn _insert_or_remove_end_val(self: *Self, ring_idx: u32, new_val: TextSegment) TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    const last_idx = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    return self._exchange_val(ring_idx, last_idx, new_val);
}

/// Ring must be at max capacity
inline fn _insert_or_remove_2_end_vals(self: *Self, ring_idx: u32, new_vals: [2]TextSegment) [2]TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    const idx_1 = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 2) % RING_CAPACITY;
    const idx_2 = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    return self._exchange_2_vals(ring_idx, idx_1, idx_2, new_vals);
}

/// Ring must be at max capacity
fn _insert_and_pop_end(self: *Self, ring_idx: u32, ins_idx: u16, ins_val: TextSegment) TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    var idx_to_replace = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    var idx_to_move_up = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 2) % RING_CAPACITY;
    const popped = self.rings_ptr[ring_idx].items[idx_to_replace];
    while (idx_to_replace != ins_idx) {
        self.rings_ptr[ring_idx].items[idx_to_replace] = self.rings_ptr[ring_idx].items[idx_to_move_up];
        idx_to_replace = (idx_to_replace + RING_CAPACITY - 1) % RING_CAPACITY;
        idx_to_move_up = (idx_to_move_up + RING_CAPACITY - 1) % RING_CAPACITY;
    }
    self.rings_ptr[ring_idx].items[idx_to_replace] = ins_val;
    return popped;
}

/// Ring must be at max capacity
fn _insert_2_and_pop_2_end(self: *Self, ring_idx: u32, ins_idx: u16, ins_vals: [2]TextSegment) [2]TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    const idx_1 = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 3) % RING_CAPACITY;
    const idx_2 = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 2) % RING_CAPACITY;
    const idx_3 = (self.rings_ptr[ring_idx].limit_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    const idx_after_ins = (ins_idx + 1) % RING_CAPACITY;
    const popped = [2]TextSegment{
        self.rings_ptr[ring_idx].items[idx_2],
        self.rings_ptr[ring_idx].items[idx_3],
    };
    var idx_to_replace = idx_3;
    var idx_to_move_up = idx_1;
    while (idx_to_replace != idx_after_ins) {
        self.rings_ptr[ring_idx].items[idx_to_replace] = self.rings_ptr[ring_idx].items[idx_to_move_up];
        idx_to_replace = (idx_to_replace + RING_CAPACITY - 1) % RING_CAPACITY;
        idx_to_move_up = (idx_to_move_up + RING_CAPACITY - 1) % RING_CAPACITY;
    }
    self.rings_ptr[ring_idx].items[ins_idx] = ins_vals[0];
    self.rings_ptr[ring_idx].items[idx_to_replace] = ins_vals[1];
    return popped;
}

/// Ring must be at max capacity
fn _remove_and_fill_end(self: *Ring, ring_idx: u32, rem_idx: u16, end_val: TextSegment) TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    const popped = self.ptr[ring_idx].items[rem_idx];
    var idx_to_replace = rem_idx;
    var idx_to_move_down = (rem_idx + 1) % RING_CAPACITY;
    while (idx_to_move_down != self.ptr[ring_idx].limit_idx) {
        self.ptr[ring_idx].items[idx_to_replace] = self.ptr[ring_idx].items[idx_to_move_down];
        idx_to_move_down = (idx_to_move_down + 1) % RING_CAPACITY;
        idx_to_replace = (idx_to_replace + 1) % RING_CAPACITY;
    }
    self.ptr[ring_idx].items[idx_to_replace] = end_val;
    return popped;
}

/// Ring must be at max capacity
fn _remove_2_and_fill_2_end(self: *Ring, ring_idx: u32, rem_idx: u16, end_vals: [2]TextSegment) [2]TextSegment {
    assert((ring_idx != self.rings_len - 1) || (self.last_ring_len == RING_CAPACITY));
    const idx_after_rem = (rem_idx + 1) % RING_CAPACITY;
    const popped = [2]TextSegment{ self.ptr[ring_idx].items[rem_idx], self.ptr[ring_idx].items[idx_after_rem] };
    var idx_to_replace = rem_idx;
    var idx_to_move_down = (idx_after_rem + 1) % RING_CAPACITY;
    while (idx_to_move_down != self.ptr[ring_idx].limit_idx) {
        self.ptr[ring_idx].items[idx_to_replace] = self.ptr[ring_idx].items[idx_to_move_down];
        idx_to_move_down = (idx_to_move_down + 1) % RING_CAPACITY;
        idx_to_replace = (idx_to_replace + 1) % RING_CAPACITY;
    }
    const last_idx = (idx_to_replace + 1) % RING_CAPACITY;
    self.ptr[ring_idx].items[idx_to_replace] = end_vals[0];
    self.ptr[ring_idx].items[last_idx] = end_vals[1];
    return popped;
}

/// Only for use when last ring not full
inline fn _insert_start_last_ring_not_full(self: *Self, last_ring_idx: u32, val: TextSegment) void {
    assert(self.last_ring_len < RING_CAPACITY);
    self.last_ring_start_idx = (self.last_ring_start_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    self.last_ring_len += 1;
    self.rings_ptr[last_ring_idx].items[self.last_ring_start_idx] = val;
}

/// Only for use when last ring not full
inline fn _insert_2_start_last_ring_not_full(self: *Self, last_ring_idx: u32, vals: [2]TextSegment) void {
    assert(self.last_ring_len < RING_CAPACITY - 1);
    self.last_ring_start_idx = (self.last_ring_start_idx + RING_CAPACITY - 2) % RING_CAPACITY;
    const idx_after_start = (self.last_ring_start_idx + 1) % RING_CAPACITY;
    self.last_ring_len += 2;
    self.rings_ptr[last_ring_idx].items[self.last_ring_start_idx] = vals[0];
    self.rings_ptr[last_ring_idx].items[idx_after_start] = vals[1];
}

inline fn _remove_start_last_ring(self: *Self, last_ring_idx: u32) TextSegment {
    assert(self.last_ring_len > 0);
    const popped = self.rings_ptr[last_ring_idx].items[self.last_ring_start_idx];
    self.last_ring_start_idx = (self.last_ring_start_idx + 1) % RING_CAPACITY;
    self.last_ring_len -= 1;
    return popped;
}

inline fn _remove_2_start_last_ring(self: *Self, last_ring_idx: u32) [2]TextSegment {
    assert(self.last_ring_len > 1);
    const idx_after_start = (self.last_ring_start_idx + 1) % RING_CAPACITY;
    const popped = [2]TextSegment{
        self.rings_ptr[last_ring_idx].items[self.last_ring_start_idx],
        self.rings_ptr[last_ring_idx].items[idx_after_start],
    };
    self.last_ring_start_idx = (self.last_ring_start_idx + 2) % RING_CAPACITY;
    self.last_ring_len -= 2;
    return popped;
}

/// Only for use when last ring not full
inline fn _insert_end_last_ring_not_full(self: *Self, last_ring_idx: u32, val: TextSegment) void {
    assert(self.last_ring_len < RING_CAPACITY);
    self.rings_ptr[last_ring_idx].items[self.rings_ptr[last_ring_idx].limit_idx] = val;
    self.rings_ptr[last_ring_idx].limit_idx = (self.rings_ptr[last_ring_idx].limit_idx + 1) % RING_CAPACITY;
    self.last_ring_len += 1;
}

/// Only for use when last ring not full
inline fn _insert_2_end_last_ring_not_full(self: *Self, last_ring_idx: u32, vals: [2]TextSegment) void {
    assert(self.last_ring_len < RING_CAPACITY - 1);
    const idx_after_limit = (self.rings_ptr[last_ring_idx].limit_idx + 1) % RING_CAPACITY;
    self.rings_ptr[last_ring_idx].items[self.rings_ptr[last_ring_idx].limit_idx] = vals[0];
    self.rings_ptr[last_ring_idx].items[idx_after_limit] = vals[1];
    self.rings_ptr[last_ring_idx].limit_idx = (self.rings_ptr[last_ring_idx].limit_idx + 2) % RING_CAPACITY;
    self.last_ring_len += 2;
}

inline fn _remove_end_last_ring(self: *Self, last_ring_idx: u32) TextSegment {
    assert(self.last_ring_len > 0);
    self.rings_ptr[last_ring_idx].limit_idx = (self.rings_ptr[last_ring_idx].limit_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    self.last_ring_len -= 1;
    return self.rings_ptr[last_ring_idx].items[self.rings_ptr[last_ring_idx].limit_idx];
}

inline fn _remove_2_end_last_ring(self: *Self, last_ring_idx: u32) [2]TextSegment {
    assert(self.last_ring_len > 1);
    self.rings_ptr[last_ring_idx].limit_idx = (self.rings_ptr[last_ring_idx].limit_idx + RING_CAPACITY - 2) % RING_CAPACITY;
    const idx_after_new_limit = (self.rings_ptr[last_ring_idx].limit_idx + 1) % RING_CAPACITY;
    self.last_ring_len -= 2;
    return [2]TextSegment{ self.rings_ptr[last_ring_idx].items[self.rings_ptr[last_ring_idx].limit_idx], self.rings_ptr[last_ring_idx].items[idx_after_new_limit] };
}

/// Only for use when last ring not full
fn _insert_in_last_ring_not_full(self: *Self, last_ring_idx: u32, ins_idx: u16, ins_val: TextSegment) void {
    assert(self.last_ring_len < RING_CAPACITY);
    var idx_to_replace = self.rings_ptr[last_ring_idx].limit_idx;
    self.rings_ptr[last_ring_idx].limit_idx = (self.rings_ptr[last_ring_idx].limit_idx + 1) % RING_CAPACITY;
    self.last_ring_len += 1;
    var idx_to_move_up = (idx_to_replace + RING_CAPACITY - 1) % RING_CAPACITY;
    while (idx_to_replace != ins_idx) {
        self.rings_ptr[last_ring_idx].items[idx_to_replace] = self.rings_ptr[last_ring_idx].items[idx_to_move_up];
        idx_to_replace = (idx_to_replace + RING_CAPACITY - 1) % RING_CAPACITY;
        idx_to_move_up = (idx_to_move_up + RING_CAPACITY - 1) % RING_CAPACITY;
    }
    self.rings_ptr[last_ring_idx].items[idx_to_replace] = ins_val;
}

/// Only for use when last ring not full
fn _insert_2_in_last_ring_not_full(self: *Self, last_ring_idx: u32, ins_idx: u16, ins_vals: [2]TextSegment) void {
    assert(self.last_ring_len < RING_CAPACITY - 1);
    var idx_to_replace = (self.rings_ptr[last_ring_idx].limit_idx + 1) % RING_CAPACITY;
    var idx_to_move_up = (self.rings_ptr[last_ring_idx].limit_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    const idx_after_ins_idx = (ins_idx + 1) % RING_CAPACITY;
    self.rings_ptr[last_ring_idx].limit_idx = (self.rings_ptr[last_ring_idx].limit_idx + 2) % RING_CAPACITY;
    self.last_ring_len += 2;
    while (idx_to_replace != idx_after_ins_idx) {
        self.rings_ptr[last_ring_idx].items[idx_to_replace] = self.rings_ptr[last_ring_idx].items[idx_to_move_up];
        idx_to_replace = (idx_to_replace + RING_CAPACITY - 1) % RING_CAPACITY;
        idx_to_move_up = (idx_to_move_up + RING_CAPACITY - 1) % RING_CAPACITY;
    }
    self.rings_ptr[last_ring_idx].items[ins_idx] = ins_vals[0];
    self.rings_ptr[last_ring_idx].items[idx_to_replace] = ins_vals[1];
}

fn _remove_from_last_ring(self: *Self, last_ring_idx: u32, rem_idx: u16) TextSegment {
    assert(self.last_ring_len > 0);
    const popped = self.rings_ptr[last_ring_idx].items[rem_idx];
    var idx_to_replace = rem_idx;
    var idx_to_move_down = (rem_idx + 1) % RING_CAPACITY;
    while (idx_to_move_down != self.rings_ptr[last_ring_idx].limit_idx) {
        self.rings_ptr[last_ring_idx].items[idx_to_replace] = self.rings_ptr[last_ring_idx].items[idx_to_move_down];
        idx_to_move_down = (idx_to_move_down + 1) % RING_CAPACITY;
        idx_to_replace = (idx_to_replace + 1) % RING_CAPACITY;
    }
    self.last_ring_len -= 1;
    self.rings_ptr[last_ring_idx].limit_idx = (self.rings_ptr[last_ring_idx].limit_idx + RING_CAPACITY - 1) % RING_CAPACITY;
    return popped;
}

fn _remove_2_from_last_ring(self: *Self, last_ring_idx: u32, rem_idx: u16) [2]TextSegment {
    assert(self.last_ring_len > 1);
    var idx_to_replace = rem_idx;
    var idx_to_move_down = (rem_idx + 2) % RING_CAPACITY;
    const rem_idx_2 = (rem_idx + 1) % RING_CAPACITY;
    const popped = [2]TextSegment{
        self.rings_ptr[last_ring_idx].items[rem_idx],
        self.rings_ptr[last_ring_idx].items[rem_idx_2],
    };
    while (idx_to_move_down != self.rings_ptr[last_ring_idx].limit_idx) {
        self.rings_ptr[last_ring_idx].items[idx_to_replace] = self.rings_ptr[last_ring_idx].items[idx_to_move_down];
        idx_to_move_down = (idx_to_move_down + 1) % RING_CAPACITY;
        idx_to_replace = (idx_to_replace + 1) % RING_CAPACITY;
    }
    self.last_ring_len -= 2;
    self.rings_ptr[last_ring_idx].limit_idx = (self.rings_ptr[last_ring_idx].limit_idx + RING_CAPACITY - 2) % RING_CAPACITY;
    return popped;
}
