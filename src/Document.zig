const assert = @import("std").debug.assert;
const std = @import("std");
const mem = std.mem;

const block_alloc = @import("pooled_block_alloc");
const PooledBlockAllocator = block_alloc.PooledBlockAllocator;
const BlockAllocator = block_alloc.BlockAllocator;
const StaticAllocBuffer = block_alloc.StaticAllocBuffer;

const Encoding = @import("./Encoding.zig");
const global = @import("./Global.zig");
const settings = @import("./Settings.zig").user_settings;
const SegmentList = @import("./SegmentList.zig");
const UTF8 = Encoding.UTF8;
const VI21 = Encoding.VarInt21;
const PSIFMT = Encoding.PSIFMT;

const DataBuf = global.U8Buf_1024.List;
const SmallByteBuf = global.U8Buf_256.List;
const DataBufBuf = StaticAllocBuffer.define(DataBuf, global.block_allocator_256);
const DataBufList = DataBufBuf.List;
const FreeSpaceOrderBuf = StaticAllocBuffer.define(u16, global.block_allocator_256);
const FreeSpaceOrderList = FreeSpaceOrderBuf.List;

const Self = @This();

// const TextToken = @import("./tokens/text_token.zig").TextToken;
// const TextTokenTag = @import("./tokens/text_token.zig").TextTokenTag;
// const TextTokenPayload = @import("./tokens/text_token.zig").TextTokenPayload;

//=================
// STATIC MEMBERS |
//=================

//===================
// INSTANCE MEMBERS |
//===================
file_path: SmallByteBuf,
file_name_start: usize,
file_name_end: usize,
buffer_list: DataBufList,
segment_list: SegmentList,
cursor: TextCursor,
//text_cursor_format_state: ?,
total_lines: u32,
total_words: u32,
total_chars: u32,
serial_bytes: u32,
memory_bytes: u32,


//===================
// PUBLIC FUNCTIONS |
//===================
// pub inline fn insert_single_utf8_char_at_cursor(self: *Self, char: u32) void {
//     assert( // char must be legal UTF-8 and also not one of the ASCII control codes
//         (char > TextToken.UTF8_A_LIMIT_LO and char < TextToken.UTF8_A_LIMIT_HI) or
//         (char > TextToken.UTF8_B_LIMIT_LO and char < TextToken.UTF8_B_LIMIT_HI) or
//         (char > TextToken.UTF8_C_LIMIT_LO and char < TextToken.UTF8_C_LIMIT_HI));
//     //TODO: Handle current change idx isnt last change idx
//     if (!self._eligible_to_combine_with_last_change_group(EditAction.SingleCharInsert)) {
//         self._create_new_change_group();
//     }
//     Self.input_staging.reset();
//     const token = TextToken{ .tag = TextTokenTag.UTF8CodePoint, .payload = TextTokenPayload{ .UTF8CodePoint = char } };
//     const raw_val: u128 = @intCast(char);
//     const encoded_len = VarInt128.encoded_length(raw_val);
//     Self.write_token_to_staging(token, raw_val, encoded_len);
//     self._insert_staging_segment_at_cursor();
// }

// pub inline fn insert_utf8_string_at_cursor(self: *Self, str: []u8) void {
//     _ = self; // autofix
//     _ = str; // autofix

// }

// pub inline fn insert_token_at_cursor(self: *Self, token: TextToken) void {
//     Self.input_staging.reset();
//     const raw_val = token.token_to_value();
//     const encoded_len = VarInt128.encoded_length(raw_val);
//     Self.write_token_to_staging(token, raw_val, encoded_len);
//     self.insert_staging_segment_at_all_cursors();
// }

//*********************
// INTERNAL FUNCTIONS *
//*********************
fn bubble_sort_entire_free_list(self: *Self) void {
    assert(self.buffers_with_free_space.len != 0);
    const last_index = self.buffers_with_free_space.len - 1;
    var left_sorted_limit: usize = 0;
    while (left_sorted_limit < last_index) {
        var new_left_sorted_limit: usize = last_index;
        var i: usize = last_index;
        while (i > left_sorted_limit) : (i -= 1) {
            const buf_idx_on_right = self.buffers_with_free_space[i];
            const buf_idx_on_left = self.buffers_with_free_space[i - 1];
            assert(buf_idx_on_left < self.buffer_list.len and buf_idx_on_right < self.buffer_list.len);
            const free_space_on_right = self.buffer_list.ptr[buf_idx_on_right].;
            const free_space_on_left = self.text_buffers.ptr[buf_idx_on_left].bytes_left();
            if (free_space_on_left > free_space_on_right) {
                self.buffers_with_free_space[i] = buf_idx_on_left;
                self.buffers_with_free_space[i - 1] = buf_idx_on_right;
                new_left_sorted_limit = i;
            }
        }
        left_sorted_limit = new_left_sorted_limit;
    }
}
// inline fn _eligible_to_combine_with_last_change_group(self: *Self, this_action: EditAction) bool {
//     return (!self.last_change_group_finalized and
//         self.last_edit_action == this_action and
//         self.last_edit_action_end_cursor_segment_idx == self.cursor_segment_idx and
//         self.last_edit_action_end_cursor_byte_idx == self.text_cursor_segment_byte_idx);
// }

// inline fn _create_new_change_group(self: *Self) bool {
//     if (!self.last_change_group_finalized) {
//         self._finalize_last_change_group();
//     }
//     self.change_groups.append(Self.list_allocator, ChangeGroup{
//         .segment_change_count = 0,
//     });
//     self.last_change_group_finalized = false;
// }

// inline fn _finalize_last_change_group(self: *Self) void {
//     _ = self; // autofix

//     //TODO
// }

// inline fn _insert_single_token_at_cursor(self: *Self, cursor_idx: usize) void {
//     _ = self; // autofix
//     _ = cursor_idx; // autofix
//     //TODO
// }

// inline fn _write_token_to_staging(token: TextToken, raw_val: u128, encoded_len: usize) void {
//     assert(Self.input_staging.segment_length + encoded_len <= 256);
//     VarInt128.encode_value_to_buffer_unchecked(raw_val, encoded_len, Self.input_staging.segment[Self.input_staging.segment_length..256]);
//     Self.input_staging.segment_length += encoded_len;
//     Self.input_staging.token_tags[Self.input_staging.token_count] = token.tag;
//     Self.input_staging.token_payloads[Self.input_staging.token_count] = token.payload;
//     Self.input_staging.token_encoded_lens[Self.input_staging.token_count] = encoded_len;
//     Self.input_staging.token_count += 1;
// }

/// The core function for inserting new data to document
///
/// Every path for data insertion must follow the following steps, in order:
/// [BEFORE THIS FUNCTION]
/// [0.0]: Determine if the insert can be merged with current last change group
/// [0.1]: If not, finalize previous change group
/// [0.2]: If not, add a new change group to end of history
/// [INSIDE THIS FUNCTION]
/// [1]: Find buffer that can hold the new segment, create new one if needed
/// [2]: Insert data to buffer and update buffer.len
/// [3]: Sort buffer in free-list with new len
/// [4]: Take 'before' snapshots of existing segments will have changes made to them
/// [5]: Create new segment if needed
/// [6]: Update existing segments with new next/prev pointers and lengths
/// [7]: Take 'after' snapshots of existing segments that were changed
/// [8]: Create segment change entries using the before and after snapshots
/// [9]: Push each segment change to history and increment change group counts by 1 for each
/// [10]: Walk cursor over new segment data
/// [AFTER THIS FUNCTION]
/// [X.1]: Determine if the changes pushed to history are eligible to be merged
/// [X.2]: If not, finalize last merge group
// fn _insert_staging_segment_at_cursor(self: *Self) !void {
//     const cursor_segment_idx = self.cursor_segment_idx;
//     const cursor_segment: TextSegment = self.text_content.text_segments.items[cursor_segment_idx];
//     const cursor_buffer_idx: u16 = cursor_segment.buffer_idx;
//     const cursor_buffer: *DataBuffer = self.text_content.text_buffers.items[cursor_buffer_idx];
//     const cursor_buffer_location: u16 = cursor_segment.byte_start + @as(u16, self.text_cursor_segment_byte_idx);
//     const cursor_at_end_of_written_buffer = cursor_buffer_location == cursor_buffer.len;
//     const cursor_at_end_of_segment = self.text_cursor_segment_byte_idx == cursor_segment.byte_count;
//     const buffer_has_enough_space_for_staging = cursor_buffer.bytes_left() >= Self.staging_segment_total_length;
//     const segment_has_enough_space_for_staging = TextSegment.MAX_BYTE_COUNT - cursor_segment.byte_count >= Self.staging_segment_total_length;
//     // If cursor is on the last byte of the last segment in a buffer and has room for staging, simply extend it
//     const can_write_directly_to_end_of_segment = cursor_at_end_of_written_buffer and buffer_has_enough_space_for_staging and segment_has_enough_space_for_staging and cursor_at_end_of_segment;
//     if (can_write_directly_to_end_of_segment) { // [1]
//         const buf_write = self._write_staging_segment_to_end_of_buffer(cursor_buffer_idx); // [2]
//         const cursor_buffer_free_list_idx = self._find_buffer_idx_in_free_list(cursor_buffer_idx).?; // [3]
//         self._sort_down_buffer_by_free_space(cursor_buffer.bytes_left(), cursor_buffer_idx, cursor_buffer_free_list_idx); // [3]
//         const before_snap = self._get_segment_snapshot(cursor_segment_idx); // [4]
//         //[5] unneeded
//         self._extend_segment_right_n_bytes(cursor_segment_idx, buf_write.byte_count); // [6]
//         //TODO: estimate words in segment [6]
//         //TODO: update estimated words in segment and document total [6]
//         const after_snap = self._get_segment_snapshot(cursor_segment_idx); // [7]
//         const change = before_snap._create_text_segment_change_to_end_of_segment(after_snap); // [8]
//         self._add_segment_change_to_last_change_group(change); // [9]
//         //TODO: [10]
//         return;
//     }
//     // Otherwise do the standard paths...
//     var host_buffer = FoundBufferResult{}; // [1]
//     if (cursor_buffer.bytes_left() >= Self.input_staging.segment_length) { // [1]
//         host_buffer.ptr = cursor_buffer; // [1]
//         host_buffer.idx = cursor_buffer_idx; // [1]
//         host_buffer.free_idx = self._find_buffer_idx_in_free_list(cursor_buffer_idx); // [1]
//     } else { // [1]
//         host_buffer = self._find_buffer_with_smallest_adequate_free_space(Self.input_staging.segment_length); // [1]
//         if (host_buffer.ptr == null) { // [1]
//             host_buffer = try self._create_new_text_buffer(); // [1]
//         } // [1]
//     } // [1]
//     const buf_write = self._write_staging_segment_to_end_of_buffer(host_buffer.idx); // [2]
//     self._sort_down_buffer_by_free_space(host_buffer.ptr.?.bytes_left(), host_buffer.idx, host_buffer.free_idx); // [3]
//     if (cursor_at_end_of_segment) {
//         const before_snaps = self._create_before_snapshots_for_change_to_right_side(cursor_segment_idx); // [4]
//         const new_segment_on_right_idx = try self._insert_new_segment_on_right(cursor_segment_idx, buf_write); // [5/6]
//         const change_pair = self._finish_after_snapshots_for_change_to_right_side(before_snaps); // [7/8]
//         self._add_change_pair_to_last_change_group(change_pair); // [9]
//         _ = new_segment_on_right_idx; //TODO: [10]
//         return;
//     }
//     const cursor_at_beginning_of_segment = self.text_cursor_segment_byte_idx == 0;
//     if (cursor_at_beginning_of_segment) {
//         const before_snaps = self._create_before_snapshots_for_change_to_left_side(cursor_segment_idx); // [4]
//         const new_segment_on_right_idx = try self._insert_new_segment_on_right(cursor_segment_idx, buf_write); // [5/6]
//         const change_pair = self._finish_after_snapshots_for_change_to_right_side(before_snaps); // [7/8]
//         self._add_change_pair_to_last_change_group(change_pair); // [9]
//         _ = new_segment_on_right_idx; //TODO: [10]
//         return;
//     }
//     // Else: cursor is in middle of segment
//     //TODO: Handle split-and-insert-middle case
//     return;
// }

// inline fn _walk_cursor_over_staging_segment_tokens(self: *Self) void {
//     var tokens_walked: u8 = 0;
//     while (tokens_walked < Self.input_staging.token_count) : (tokens_walked += 1) {
//         //TODO: handle cursor state changes while walking over tokens
//         //TODO: Count lines, words, chars while walking over tokens
//     }
//     self.text_cursor_segment_byte_idx += Self.input_staging.segment_length;
// }

// inline fn _move_cursor_from_end_of_segment_to_start_of_next_segment(self: *Self) void {
//     assert(self.cursor_segment_idx < TextSegment.NONE_IDX);
//     assert(self.text_segments.items[self.cursor_segment_idx].next_segment_idx < TextSegment.NONE_IDX);
//     assert(self.text_cursor_segment_byte_idx == self.text_segments.items[self.cursor_segment_idx].byte_count);
//     self.cursor_segment_idx = self.text_segments.items[self.cursor_segment_idx].next_segment_idx;
//     self.text_cursor_segment_byte_idx = 0;
// }

// inline fn _extend_segment_right_n_bytes(self: *Self, segment_idx: u32, byte_count: u8) void {
//     self.text_segments.items[segment_idx].byte_count += byte_count;
// }

// inline fn _add_any_segment_changes_to_last_change_group(self: *Self, snap_changes: ChangePair) void {
//     if (snap_changes.has_left) {
//         self._add_segment_change_to_last_change_group(snap_changes.left_change);
//     }
//     if (snap_changes.has_right) {
//         self._add_segment_change_to_last_change_group(snap_changes.right_change);
//     }
// }

// inline fn _add_change_pair_to_last_change_group(self: *Self, changes: ChangePair) void {
//     if (changes.has_left) {
//         self.text_changes.append(Self.list_allocator, changes.left_change);
//         self.change_groups.items[self.change_groups.items.len-1] += 1;
//     }
//     if (changes.has_right) {
//         self.text_changes.append(Self.list_allocator, changes.right_change);
//         self.change_groups.items[self.change_groups.items.len-1] += 1;
//     }
// }

// inline fn _add_segment_change_to_last_change_group(self: *Self, change: TextSegmentChange) void {
//     self.text_changes.append(Self.list_allocator, change);
//     self.change_groups.items[self.change_groups.items.len-1] += 1;
// }

// inline fn _get_segment_snapshot(self: *Self, segment_idx: u32) TextSegmentSnapshot {
//     assert(segment_idx < self.text_segments.items.len);
//     return TextSegmentSnapshot{
//         .segment_idx = segment_idx,
//         .byte_start = self.text_segments.items[segment_idx].byte_start,
//         .byte_count = self.text_segments.items[segment_idx].byte_count,
//         .prev_segment_idx = self.text_segments.items[segment_idx].prev_segment_idx,
//         .next_segment_idx = self.text_segments.items[segment_idx].next_segment_idx,
//     };
// }

// inline fn _write_staging_segment_to_end_of_buffer(self: *Self, buffer_idx: u16) BufferWriteResult {
//     assert(buffer_idx < self.text_buffers.items.len);
//     const buffer_ptr = self.text_buffers.items[buffer_idx];
//     assert(buffer_ptr.len + Self.input_staging.segment_length <= DataBuffer.CAPACITY);
//     const result = BufferWriteResult{
//         .buf_idx = buffer_idx,
//         .byte_start = buffer_ptr.len,
//         .byte_len = Self.input_staging.segment_length,
//     };
//     @memcpy(buffer_ptr.data[buffer_ptr.len..][0..Self.input_staging.segment_length], Self.input_staging.segment[0..Self.input_staging.segment_length]);
//     buffer_ptr.len += Self.input_staging.segment_length;
//     return result;
// }

// inline fn _insert_new_segment_on_left(self: *Self, this_segment_idx: u32, buf_write: BufferWriteResult) !u32 {
//     assert(buf_write.buf_idx < self.text_buffers.items.len);
//     if (self.text_segments.items.len > TextSegment.MAX_IDX) {
//         return error.MaximumTextSegmentsReached;
//     }
//     const new_segment_idx: u32 = @truncate(self.text_segments.items.len);
//     var new_segment = TextSegment{
//         .buffer_idx = buf_write.buf_idx,
//         .byte_start = buf_write.byte_start,
//         .byte_count = buf_write.byte_count,
//     };
//     const this_segment_ptr: *TextSegment = &self.text_segments.items[this_segment_idx];
//     new_segment.set_next_segment_idx(this_segment_idx);
//     new_segment.prev_segment_idx_lo = this_segment_ptr.prev_segment_idx_lo;
//     new_segment.prev_segment_idx_hi = this_segment_ptr.prev_segment_idx_hi;
//     if (this_segment_ptr.has_valid_prev_idx()) {
//         const prev_segment_ptr: *TextSegment = &self.text_segments.items[this_segment_ptr.get_prev_segment_idx()];
//         prev_segment_ptr.set_next_segment_idx(new_segment_idx);
//     }
//     this_segment_ptr.set_prev_segment_idx(new_segment_idx);
//     self.text_segments.append(Self.list_allocator, new_segment);
//     return new_segment_idx;
// }

// inline fn _insert_new_segment_on_right(self: *Self, this_segment_idx: u32, buf_write: BufferWriteResult) !u32 {
//     assert(buf_write.buf_idx < self.text_buffers.items.len);
//     if (self.text_segments.items.len > TextSegment.MAX_IDX) {
//         return error.MaximumTextSegmentsReached;
//     }
//     const new_segment_idx: u32 = @truncate(self.text_segments.items.len);
//     var new_segment = TextSegment{
//         .buffer_idx = buf_write.buf_idx,
//         .byte_start = buf_write.byte_start,
//         .byte_count = buf_write.byte_count,
//     };
//     const this_segment_ptr: *TextSegment = &self.text_segments.items[this_segment_idx];
//     new_segment.set_prev_segment_idx(this_segment_idx);
//     new_segment.next_segment_idx_lo = this_segment_ptr.next_segment_idx_lo;
//     new_segment.next_segment_idx_hi = this_segment_ptr.next_segment_idx_hi;
//     if (this_segment_ptr.has_valid_next_idx()) {
//         const next_segment_ptr: *TextSegment = &self.text_segments.items[this_segment_ptr.get_next_segment_idx()];
//         next_segment_ptr.set_prev_segment_idx(new_segment_idx);
//     }
//     this_segment_ptr.set_next_segment_idx(new_segment_idx);
//     self.text_segments.append(Self.list_allocator, new_segment);
//     return new_segment_idx;
// }

// inline fn _find_buffer_idx_in_free_list(self: *Self, buf_idx: u16) ?u16 {
//     var free_list_idx: ?u16 = null;
//     var idx: u16 = 0;
//     while (idx < self.buffers_with_free_space.items.len and free_list_idx == null) : (idx += 1) {
//         if (self.buffers_with_free_space.items[idx] == buf_idx) {
//             free_list_idx = idx;
//         }
//     }
//     return free_list_idx;
// }

// inline fn _sort_down_buffer_by_free_space(self: *Self, this_buf_space: u16, this_buf_idx: u16, this_buf_idx_in_free_list: u16) void {
//     assert(self.buffers_with_free_space.items.len > this_buf_idx_in_free_list);
//     var idx = this_buf_idx_in_free_list;
//     if (this_buf_space == 0) {
//         self.buffers_with_free_space.orderedRemove(this_buf_idx_in_free_list);
//         return;
//     }
//     while (idx != 0) : (idx -= 1) {
//         const idx_of_buffer_below = self.buffers_with_free_space.items[idx - 1];
//         const space_in_buffer_below = self.text_buffers.items[idx_of_buffer_below].bytes_left();
//         if (space_in_buffer_below > this_buf_space) {
//             self.buffers_with_free_space[idx] = idx_of_buffer_below;
//             self.buffers_with_free_space[idx - 1] = this_buf_idx;
//         }
//     }
// }

// fn _bubblesort_buffers_by_free_space(self: *Self) void {
//     assert(self.buffers_with_free_space.items.len != 0);
//     const last_index = self.buffers_with_free_space.items.len - 1;
//     var left_sorted_limit: usize = 0;
//     while (left_sorted_limit < last_index) {
//         var new_left_sorted_limit: usize = last_index;
//         var i: usize = last_index;
//         while (i > left_sorted_limit) : (i -= 1) {
//             const buf_idx_on_right = self.buffers_with_free_space[i];
//             const buf_idx_on_left = self.buffers_with_free_space[i - 1];
//             const free_space_on_right = self.text_buffers.items[buf_idx_on_right].bytes_left();
//             const free_space_on_left = self.text_buffers.items[buf_idx_on_left].bytes_left();
//             if (free_space_on_left > free_space_on_right) {
//                 self.buffers_with_free_space[i] = buf_idx_on_left;
//                 self.buffers_with_free_space[i - 1] = buf_idx_on_right;
//                 new_left_sorted_limit = i;
//             }
//         }
//         left_sorted_limit = new_left_sorted_limit;
//     }
// }

// inline fn _find_buffer_with_smallest_adequate_free_space(self: *Self, free_space_needed: u16) FoundBufferResult {
//     var result = FoundBufferResult{};
//     while (result.free_idx < self.buffers_with_free_space.items.len and result.ptr == null) : (result.free_idx += 1) {
//         const buffer_idx = self.buffers_with_free_space.items[result.free_idx];
//         const buffer_ptr = self.text_buffers.items[buffer_idx];
//         const buffer_space = buffer_ptr.bytes_left();
//         if (buffer_space >= free_space_needed) {
//             result.ptr = buffer_ptr;
//             result.idx = buffer_idx;
//         }
//     }
//     return result;
// }

// inline fn _create_new_text_buffer(self: *Self) !FoundBufferResult {
//     const new_buffer_ptr = try DataBuffer.create();
//     const new_buffer_idx: u16 = @truncate(self.text_buffers.items.len);
//     const new_buffer_free_idx: u16 = @truncate(self.buffers_with_free_space.items.len);
//     self.text_buffers.append(Self.list_allocator, new_buffer_ptr);
//     self.buffers_with_free_space.append(Self.list_allocator, new_buffer_idx);
//     return FoundBufferResult{ .ptr = new_buffer_ptr, .idx = new_buffer_idx, .free_idx = new_buffer_free_idx };
// }

// inline fn _create_before_snapshots_for_change_to_right_side(self: *Self, segment_idx: u32) SnapshotPair {
//     var snaps = SnapshotPair{};
//     snaps.has_left = true;
//     snaps.left_before = self._get_segment_snapshot(segment_idx);
//     if (snaps.left_before.next_segment_idx != TextSegment.NONE_IDX) {
//         snaps.has_right = true;
//         snaps.right_before = self._get_segment_snapshot(snaps.left_before.next_segment_idx);
//     }
//     return snaps;
// }

// inline fn _create_before_snapshots_for_change_to_left_side(self: *Self, segment_idx: u32) SnapshotPair {
//     var snaps = SnapshotPair{};
//     snaps.has_right = true;
//     snaps.right_before = self._get_segment_snapshot(segment_idx);
//     if (snaps.right_before.prev_segment_idx != TextSegment.NONE_IDX) {
//         snaps.has_left = true;
//         snaps.left_before = self._get_segment_snapshot(snaps.right_before.prev_segment_idx);
//     }
//     return snaps;
// }

// inline fn _finish_after_snapshots_for_change_to_right_side(self: *Self, snaps: SnapshotPair) ChangePair {
//     var changes = ChangePair{};
//     changes.has_left = true;
//     snaps.left_after = self._get_segment_snapshot(snaps.left_before.segment_idx);
//     changes.left_change = TextSegmentSnapshot._create_text_segment_change_to_end_of_segment(snaps.left_before, snaps.left_after);
//     if (snaps.has_right) {
//         changes.has_right = true;
//         snaps.right_after = self._get_segment_snapshot(snaps.left_before.next_segment_idx);
//         changes.right_change = TextSegmentSnapshot._create_text_segment_change_to_begin_of_segment(snaps.right_before, snaps.right_after);
//     }
//     return changes;
// }
// ***********
// Sub-Types *
// ***********

const TextCursor = struct { logical_idx: u32, byte_offset: u16 };

const FoundBufferResult = struct {
    ptr: ?*DataBuffer = null,
    idx: u16 = 0,
    free_idx: u16 = 0,
};

const InputStaging = struct {
    segment: [TextSegment.MAX_BYTE_COUNT]u8,
    segment_length: u8,
    token_tags: [TextSegment.MAX_BYTE_COUNT]TextTokenTag,
    token_payloads: [TextSegment.MAX_BYTE_COUNT]TextTokenPayload,
    token_encoded_lens: [TextSegment.MAX_BYTE_COUNT]u8,
    token_count: u8,

    inline fn reset() void {
        Self.input_staging.segment_length = 0;
        Self.input_staging.token_count = 0;
    }

    inline fn can_fit_encoded_len(encoded_len: usize) bool {
        return Self.input_staging.segment_length + encoded_len <= Self.input_staging.segment.len;
    }
};

pub const OptionSource = enum { InheritedFromGlobal, DocumentSpecified };

pub const MaxEditLengthType = enum { chars, words, bytes, unlimited };

pub const MaxEditTimeType = enum {
    seconds,
    milliseconds,
    unlimited,
};
