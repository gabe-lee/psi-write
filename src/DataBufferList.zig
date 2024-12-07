const std = @import("std");
const assert = @import("std").debug.assert;

const block_alloc = @import("pooled_block_alloc");
const PooledBlockAllocator = block_alloc.PooledBlockAllocator;
const BlockAllocator = block_alloc.BlockAllocator;
const StaticAllocBuffer = block_alloc.StaticAllocBuffer;

const global = @import("./Global.zig");

const Data_SAB = global.U8Buf_1024;
pub const DataBuf = Data_SAB.List;
const DataBuf_SAB = StaticAllocBuffer.define(DataBuffer, global.block_allocator_256);
pub const DataBufList = DataBuf_SAB.List;
const FreeSpaceOrder_SAB = StaticAllocBuffer.define(T_BUF_IDX, global.block_allocator_256);
pub const FreeSpaceOrderList = FreeSpaceOrder_SAB.List;

const TextSegment = @import("./TextSegment.zig");
const T_BUF_IDX = TextSegment.T_BUF_IDX;
const T_BYTE_IDX = TextSegment.T_BYTE_IDX;

const Self = @This();

buffers: DataBufList,
/// Sorted: LESS SPACE -> MORE SPACE
buffers_with_free_space: FreeSpaceOrderList,

pub inline fn create_new() Self {
    return Self{
        .buffers = DataBufList.create(),
        .buffers_with_free_space = FreeSpaceOrderList.create(),
    };
}

pub inline fn release(self: *Self) void {
    var i = 0;
    while (i < self.buffers.len) : (i += 1) {
        self.buffers.ptr[i].release();
    }
    self.buffers.release();
    self.buffers_with_free_space.release();
}

pub fn add_new_buffer_with_capacity(self: *Self, min_cap: T_BYTE_IDX) T_BUF_IDX {
    assert(min_cap > 0);
    const data_buffer = DataBuffer{
        .data = DataBuf.create_with_capacity(min_cap),
        .free_idx = self.buffers_with_free_space.len,
    };

    const new_idx: T_BUF_IDX = self.buffers.len;
    self.buffers.append(data_buffer);
    self.buffers_with_free_space.append(new_idx);
    self.resort_single_buffer_free_space(new_idx);
    return new_idx;
}

pub fn resize_buffer(self: *Self, buf_idx: T_BUF_IDX) void {
    _ = self;
    _ = buf_idx;
    //TODO
}

pub fn sort_entire_free_list(self: *Self) void {
    assert(self.buffers_with_free_space.len != 0);
    const last_index = self.buffers_with_free_space.len - 1;
    var left_sorted_limit: T_BUF_IDX = 0;
    while (left_sorted_limit < last_index) {
        var new_left_sorted_limit: T_BUF_IDX = last_index;
        var i: T_BUF_IDX = last_index;
        while (i > left_sorted_limit) : (i -= 1) {
            const buf_idx_on_right = self.buffers_with_free_space.ptr[i];
            const buf_idx_on_left = self.buffers_with_free_space.ptr[i - 1];
            assert(buf_idx_on_left < self.buffer_list.len and buf_idx_on_right < self.buffer_list.len);
            const free_space_on_right = self.buffers.ptr[buf_idx_on_right].free_bytes();
            const free_space_on_left = self.buffers.ptr[buf_idx_on_right].free_bytes();
            assert(free_space_on_left > 0 and free_space_on_right > 0);
            if (free_space_on_left > free_space_on_right) {
                self.buffers_with_free_space.ptr[i] = buf_idx_on_left;
                self.buffers_with_free_space.ptr[i - 1] = buf_idx_on_right;
                new_left_sorted_limit = i;
            }
        }
        left_sorted_limit = new_left_sorted_limit;
    }
    var i: T_BUF_IDX = 0;
    while (i < self.buffers_with_free_space.len) : (i += 1) {
        const b = self.buffers_with_free_space.ptr[i];
        assert(b < self.buffers.len);
        self.buffers.ptr[b].free_idx = i;
    }
}

pub fn resort_single_buffer_free_space(self: *Self, buf_idx: T_BUF_IDX) void {
    assert(buf_idx < self.buffers.len);
    var i = self.buffers.ptr[buf_idx].free_idx;
    const this_free_space = self.buffers.ptr[buf_idx].free_bytes();
    if (this_free_space == 0) {
        self.buffers_with_free_space.delete(i);
        i = 0;
        while (i < self.buffers_with_free_space.len) : (i += 1) {
            const b = self.buffers_with_free_space.ptr[i];
            assert(b < self.buffers.len);
            self.buffers.ptr[b].free_idx = i;
        }
        return;
    }
    while (i > 0) : (i -= 1) {
        const buf_idx_on_left = self.buffers_with_free_space.ptr[i - 1];
        assert(buf_idx_on_left < self.buffers.len);
        const free_space_on_left = self.buffers.ptr[buf_idx_on_left].free_bytes();
        if (free_space_on_left <= this_free_space) break;
        self.buffers_with_free_space.ptr[i] = buf_idx_on_left;
        self.buffers_with_free_space.ptr[i - 1] = buf_idx;
        self.buffers.ptr[buf_idx_on_left].free_idx = i;
        self.buffers.ptr[buf_idx].free_idx = i - 1;
    }
}

pub inline fn largest_free_buffer_can_hold_bytes(self: *Self, bytes: T_BYTE_IDX) bool {
    if (self.buffers_with_free_space.len == 0) return false;
    const buffer_with_largest_free = self.buffers_with_free_space.ptr[self.buffers_with_free_space.len - 1];
    assert(buffer_with_largest_free < self.buffers.len);
    return self.buffers.ptr[buffer_with_largest_free].free_bytes() >= bytes;
}

pub inline fn largest_free_buffer_idx(self: *Self) T_BUF_IDX {
    assert(self.buffers_with_free_space.len > 0);
    return self.buffers_with_free_space.ptr[self.buffers_with_free_space.len - 1];
}

pub const DataBuffer = struct {
    data: DataBuf,
    free_idx: T_BUF_IDX,

    pub inline fn release(self: *DataBuffer) void {
        self.data.release();
        self.free_idx = 0;
    }

    pub inline fn free_bytes(self: *DataBuffer) T_BYTE_IDX {
        return @intCast(self.data.cap - self.data.len);
    }
};
