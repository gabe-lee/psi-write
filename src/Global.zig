const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const time = std.time;

const block_alloc = @import("pooled_block_alloc");
const PooledBlockAllocator = block_alloc.PooledBlockAllocator;
const BlockAllocator = block_alloc.BlockAllocator;
const StaticAllocBuffer = block_alloc.StaticAllocBuffer;

const Self = @This();

pub var root_alloc: Allocator = undefined;
pub var allocator_4096: Allocator = undefined;
pub var block_allocator_4096: BlockAllocator = undefined;
pub var pba_allocator_4096: PBA4096 = undefined;
pub var allocator_1024: Allocator = undefined;
pub var block_allocator_1024: BlockAllocator = undefined;
pub var pba_allocator_1024: PBA1024 = undefined;
pub var allocator_256: Allocator = undefined;
pub var block_allocator_256: BlockAllocator = undefined;
pub var pba_allocator_256: PBA256 = undefined;

const PBA4096 = PooledBlockAllocator.define(PooledBlockAllocator.Config{
    .block_size = 4096,
    .backing_request_size = mem.page_size,
    .alloc_error_behavior = .PANICS,
    .safety_checks = .RELEASE_SAFE_AND_BELOW,
    .safety_check_severity = .PANIC,
    .auto_shrink = .SIMPLE,
    .auto_shrink_threshold = .{ .PERCENT_MIN_MAX = .{ .min = 0.25, .max = 0.5 } },
    .index_type = u32,
    .secure_wipe_freed_memory = false,
});

const PBA1024 = PooledBlockAllocator.define(PooledBlockAllocator.Config{
    .block_size = 1024,
    .backing_request_size = 4096,
    .alloc_error_behavior = .PANICS,
    .safety_checks = .RELEASE_SAFE_AND_BELOW,
    .safety_check_severity = .PANIC,
    .auto_shrink = .SIMPLE,
    .auto_shrink_threshold = .{ .PERCENT_MIN_MAX = .{ .min = 0.25, .max = 0.5 } },
    .index_type = u32,
    .secure_wipe_freed_memory = false,
});

const PBA256 = PooledBlockAllocator.define(PooledBlockAllocator.Config{
    .block_size = 256,
    .backing_request_size = 1024,
    .alloc_error_behavior = .PANICS,
    .safety_checks = .RELEASE_SAFE_AND_BELOW,
    .safety_check_severity = .PANIC,
    .auto_shrink = .SIMPLE,
    .auto_shrink_threshold = .{ .PERCENT_MIN_MAX = .{ .min = 0.25, .max = 0.5 } },
    .index_type = u32,
    .secure_wipe_freed_memory = false,
});

pub fn init(use_root_alloc: Allocator) void {
    Self.root_alloc = use_root_alloc;

    Self.pba_allocator_4096 = PBA4096.new(Self.root_alloc);
    Self.allocator_4096 = Self.pba_allocator_4096.allocator();
    Self.block_allocator_4096 = Self.pba_allocator_4096.block_allocator();

    Self.pba_allocator_1024 = PBA1024.new(Self.allocator_4096);
    Self.allocator_1024 = Self.pba_allocator_1024.allocator();
    Self.block_allocator_1024 = Self.pba_allocator_1024.block_allocator();

    Self.pba_allocator_256 = PBA256.new(Self.allocator_1024);
    Self.allocator_256 = Self.pba_allocator_256.allocator();
    Self.block_allocator_256 = Self.pba_allocator_256.block_allocator();
}

pub fn cleanup() void {
    Self.pba_allocator_256.release_all_memory(false);
    Self.pba_allocator_1024.release_all_memory(false);
    Self.pba_allocator_4096.release_all_memory(false);
}

pub const U8Buf_256 = StaticAllocBuffer.define(u8, &Self.block_allocator_256);
pub const U8Buf_1024 = StaticAllocBuffer.define(u8, &Self.block_allocator_1024);
pub const U8Buf_4096 = StaticAllocBuffer.define(u8, &Self.block_allocator_4096);

// pub const BufSpan = struct {
//     start: u32,
//     end: u32,

//     pub inline fn new(start: u32, end: u32) BufSpan {
//         return BufSpan{
//             .start = start,
//             .end = end,
//         };
//     }

//     pub inline fn new_usize(start: usize, end: usize) BufSpan {
//         return BufSpan{
//             .start = @intCast(start),
//             .end = @intCast(end),
//         };
//     }
// };

// pub const BufSpanBufSmall = StaticAllocBuffer.define(BufSpan, &Self.small_block_alloc);
// pub const BufSpanBufMedium = StaticAllocBuffer.define(BufSpan, &Self.medium_block_alloc);
// pub const BufSpanBufLarge = StaticAllocBuffer.define(BufSpan, &Self.large_block_alloc);
