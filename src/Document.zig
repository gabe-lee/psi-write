const assert = @import("std").debug.assert;
const std = @import("std");
const mem = std.mem;
const PageAllocator = std.heap.page_allocator;
const Allocator = mem.Allocator;
const List = @import("std").ArrayListUnmanaged;
const Encoding = @import("./Encoding.zig");
const UTF8 = Encoding.UTF8;
const VarInt128 = Encoding.VarInt128;
const FullPageAllocator = @import("./FullPageAllocator.zig");

const Self = @This();

const TextToken = @import("./tokens/text_token.zig").TextToken;
const TextTokenTag = @import("./tokens/text_token.zig").TextTokenTag;
const TextTokenPayload = @import("./tokens/text_token.zig").TextTokenPayload;

//=================
// STATIC MEMBERS |
//=================
var list_allocator: Allocator = undefined;

//===================
// INSTANCE MEMBERS |
//===================
file_name: List(u8),
file_path: List(u8),
buffers: List(DataBuffer),
segments: Segments,
cursor: TextCursor,
text_changes: List(TextSegmentChange),
change_groups: List(ChangeGroup),
current_change_idx: u32,
current_change_group_idx: u32,
last_change_group_finalized: bool,
last_edit_action: EditAction,
last_edit_action_end_cursor_segment_idx: u32,
last_edit_action_end_cursor_byte_idx: u8,
last_change_timestamp: i64,
//text_cursor_format_state: ?,
total_lines: u32,
total_words: u32,
total_chars: u32,
serial_bytes: u32,
memory_bytes: u32,
/// Sorted: LESS SPACE -> MORE SPACE
buffers_with_free_space: List(u16),

//===================
// PUBLIC FUNCTIONS |
//===================
pub inline fn insert_single_utf8_char_at_cursor(self: *Self, char: u32) void {
    assert( // char must be legal UTF-8 and also not one of the ASCII control codes
        (char > TextToken.UTF8_A_LIMIT_LO and char < TextToken.UTF8_A_LIMIT_HI) or
        (char > TextToken.UTF8_B_LIMIT_LO and char < TextToken.UTF8_B_LIMIT_HI) or
        (char > TextToken.UTF8_C_LIMIT_LO and char < TextToken.UTF8_C_LIMIT_HI));
    //TODO: Handle current change idx isnt last change idx
    if (!self._eligible_to_combine_with_last_change_group(EditAction.SingleCharInsert)) {
        self._create_new_change_group();
    }
    Self.input_staging.reset();
    const token = TextToken{ .tag = TextTokenTag.UTF8CodePoint, .payload = TextTokenPayload{ .UTF8CodePoint = char } };
    const raw_val: u128 = @intCast(char);
    const encoded_len = VarInt128.encoded_length(raw_val);
    Self.write_token_to_staging(token, raw_val, encoded_len);
    self._insert_staging_segment_at_cursor();
}

pub inline fn insert_utf8_string_at_cursor(self: *Self, str: []u8) void {
    _ = self; // autofix
    _ = str; // autofix

}

pub inline fn insert_token_at_cursor(self: *Self, token: TextToken) void {
    Self.input_staging.reset();
    const raw_val = token.token_to_value();
    const encoded_len = VarInt128.encoded_length(raw_val);
    Self.write_token_to_staging(token, raw_val, encoded_len);
    self.insert_staging_segment_at_all_cursors();
}

//*********************
// INTERNAL FUNCTIONS *
//*********************
inline fn _eligible_to_combine_with_last_change_group(self: *Self, this_action: EditAction) bool {
    return (!self.last_change_group_finalized and
        self.last_edit_action == this_action and
        self.last_edit_action_end_cursor_segment_idx == self.cursor_segment_idx and
        self.last_edit_action_end_cursor_byte_idx == self.text_cursor_segment_byte_idx);
}

inline fn _create_new_change_group(self: *Self) bool {
    if (!self.last_change_group_finalized) {
        self._finalize_last_change_group();
    }
    self.change_groups.append(Self.list_allocator, ChangeGroup{
        .segment_change_count = 0,
    });
    self.last_change_group_finalized = false;
}

inline fn _finalize_last_change_group(self: *Self) void {
    _ = self; // autofix

    //TODO
}

inline fn _insert_single_token_at_cursor(self: *Self, cursor_idx: usize) void {
    _ = self; // autofix
    _ = cursor_idx; // autofix
    //TODO
}

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
fn _insert_staging_segment_at_cursor(self: *Self) !void {
    const cursor_segment_idx = self.cursor_segment_idx;
    const cursor_segment: TextSegment = self.text_content.text_segments.items[cursor_segment_idx];
    const cursor_buffer_idx: u16 = cursor_segment.buffer_idx;
    const cursor_buffer: *DataBuffer = self.text_content.text_buffers.items[cursor_buffer_idx];
    const cursor_buffer_location: u16 = cursor_segment.byte_start + @as(u16, self.text_cursor_segment_byte_idx);
    const cursor_at_end_of_written_buffer = cursor_buffer_location == cursor_buffer.len;
    const cursor_at_end_of_segment = self.text_cursor_segment_byte_idx == cursor_segment.byte_count;
    const buffer_has_enough_space_for_staging = cursor_buffer.bytes_left() >= Self.staging_segment_total_length;
    const segment_has_enough_space_for_staging = TextSegment.MAX_BYTE_COUNT - cursor_segment.byte_count >= Self.staging_segment_total_length;
    // If cursor is on the last byte of the last segment in a buffer and has room for staging, simply extend it
    const can_write_directly_to_end_of_segment = cursor_at_end_of_written_buffer and buffer_has_enough_space_for_staging and segment_has_enough_space_for_staging and cursor_at_end_of_segment;
    if (can_write_directly_to_end_of_segment) { // [1]
        const buf_write = self._write_staging_segment_to_end_of_buffer(cursor_buffer_idx); // [2]
        const cursor_buffer_free_list_idx = self._find_buffer_idx_in_free_list(cursor_buffer_idx).?; // [3]
        self._sort_down_buffer_by_free_space(cursor_buffer.bytes_left(), cursor_buffer_idx, cursor_buffer_free_list_idx); // [3]
        const before_snap = self._get_segment_snapshot(cursor_segment_idx); // [4]
        //[5] unneeded
        self._extend_segment_right_n_bytes(cursor_segment_idx, buf_write.byte_count); // [6]
        //TODO: estimate words in segment [6]
        //TODO: update estimated words in segment and document total [6]
        const after_snap = self._get_segment_snapshot(cursor_segment_idx); // [7]
        const change = before_snap._create_text_segment_change_to_end_of_segment(after_snap); // [8]
        self._add_segment_change_to_last_change_group(change); // [9]
        //TODO: [10]
        return;
    }
    // Otherwise do the standard paths...
    var host_buffer = FoundBufferResult{}; // [1]
    if (cursor_buffer.bytes_left() >= Self.input_staging.segment_length) { // [1]
        host_buffer.ptr = cursor_buffer; // [1]
        host_buffer.idx = cursor_buffer_idx; // [1]
        host_buffer.free_idx = self._find_buffer_idx_in_free_list(cursor_buffer_idx); // [1]
    } else { // [1]
        host_buffer = self._find_buffer_with_smallest_adequate_free_space(Self.input_staging.segment_length); // [1]
        if (host_buffer.ptr == null) { // [1]
            host_buffer = try self._create_new_text_buffer(); // [1]
        } // [1]
    } // [1]
    const buf_write = self._write_staging_segment_to_end_of_buffer(host_buffer.idx); // [2]
    self._sort_down_buffer_by_free_space(host_buffer.ptr.?.bytes_left(), host_buffer.idx, host_buffer.free_idx); // [3]
    if (cursor_at_end_of_segment) {
        const before_snaps = self._create_before_snapshots_for_change_to_right_side(cursor_segment_idx); // [4]
        const new_segment_on_right_idx = try self._insert_new_segment_on_right(cursor_segment_idx, buf_write); // [5/6]
        const change_pair = self._finish_after_snapshots_for_change_to_right_side(before_snaps); // [7/8]
        self._add_change_pair_to_last_change_group(change_pair); // [9]
        _ = new_segment_on_right_idx; //TODO: [10]
        return;
    }
    const cursor_at_beginning_of_segment = self.text_cursor_segment_byte_idx == 0;
    if (cursor_at_beginning_of_segment) {
        const before_snaps = self._create_before_snapshots_for_change_to_left_side(cursor_segment_idx); // [4]
        const new_segment_on_right_idx = try self._insert_new_segment_on_right(cursor_segment_idx, buf_write); // [5/6]
        const change_pair = self._finish_after_snapshots_for_change_to_right_side(before_snaps); // [7/8]
        self._add_change_pair_to_last_change_group(change_pair); // [9]
        _ = new_segment_on_right_idx; //TODO: [10]
        return;
    }
    // Else: cursor is in middle of segment
    //TODO: Handle split-and-insert-middle case
    return;
}

inline fn _walk_cursor_over_staging_segment_tokens(self: *Self) void {
    var tokens_walked: u8 = 0;
    while (tokens_walked < Self.input_staging.token_count) : (tokens_walked += 1) {
        //TODO: handle cursor state changes while walking over tokens
        //TODO: Count lines, words, chars while walking over tokens
    }
    self.text_cursor_segment_byte_idx += Self.input_staging.segment_length;
}

inline fn _move_cursor_from_end_of_segment_to_start_of_next_segment(self: *Self) void {
    assert(self.cursor_segment_idx < TextSegment.NONE_IDX);
    assert(self.text_segments.items[self.cursor_segment_idx].next_segment_idx < TextSegment.NONE_IDX);
    assert(self.text_cursor_segment_byte_idx == self.text_segments.items[self.cursor_segment_idx].byte_count);
    self.cursor_segment_idx = self.text_segments.items[self.cursor_segment_idx].next_segment_idx;
    self.text_cursor_segment_byte_idx = 0;
}

inline fn _extend_segment_right_n_bytes(self: *Self, segment_idx: u32, byte_count: u8) void {
    self.text_segments.items[segment_idx].byte_count += byte_count;
}

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

inline fn _find_buffer_idx_in_free_list(self: *Self, buf_idx: u16) ?u16 {
    var free_list_idx: ?u16 = null;
    var idx: u16 = 0;
    while (idx < self.buffers_with_free_space.items.len and free_list_idx == null) : (idx += 1) {
        if (self.buffers_with_free_space.items[idx] == buf_idx) {
            free_list_idx = idx;
        }
    }
    return free_list_idx;
}

inline fn _sort_down_buffer_by_free_space(self: *Self, this_buf_space: u16, this_buf_idx: u16, this_buf_idx_in_free_list: u16) void {
    assert(self.buffers_with_free_space.items.len > this_buf_idx_in_free_list);
    var idx = this_buf_idx_in_free_list;
    if (this_buf_space == 0) {
        self.buffers_with_free_space.orderedRemove(this_buf_idx_in_free_list);
        return;
    }
    while (idx != 0) : (idx -= 1) {
        const idx_of_buffer_below = self.buffers_with_free_space.items[idx - 1];
        const space_in_buffer_below = self.text_buffers.items[idx_of_buffer_below].bytes_left();
        if (space_in_buffer_below > this_buf_space) {
            self.buffers_with_free_space[idx] = idx_of_buffer_below;
            self.buffers_with_free_space[idx - 1] = this_buf_idx;
        }
    }
}

fn _bubblesort_buffers_by_free_space(self: *Self) void {
    assert(self.buffers_with_free_space.items.len != 0);
    const last_index = self.buffers_with_free_space.items.len - 1;
    var left_sorted_limit: usize = 0;
    while (left_sorted_limit < last_index) {
        var new_left_sorted_limit: usize = last_index;
        var i: usize = last_index;
        while (i > left_sorted_limit) : (i -= 1) {
            const buf_idx_on_right = self.buffers_with_free_space[i];
            const buf_idx_on_left = self.buffers_with_free_space[i - 1];
            const free_space_on_right = self.text_buffers.items[buf_idx_on_right].bytes_left();
            const free_space_on_left = self.text_buffers.items[buf_idx_on_left].bytes_left();
            if (free_space_on_left > free_space_on_right) {
                self.buffers_with_free_space[i] = buf_idx_on_left;
                self.buffers_with_free_space[i - 1] = buf_idx_on_right;
                new_left_sorted_limit = i;
            }
        }
        left_sorted_limit = new_left_sorted_limit;
    }
}

inline fn _find_buffer_with_smallest_adequate_free_space(self: *Self, free_space_needed: u16) FoundBufferResult {
    var result = FoundBufferResult{};
    while (result.free_idx < self.buffers_with_free_space.items.len and result.ptr == null) : (result.free_idx += 1) {
        const buffer_idx = self.buffers_with_free_space.items[result.free_idx];
        const buffer_ptr = self.text_buffers.items[buffer_idx];
        const buffer_space = buffer_ptr.bytes_left();
        if (buffer_space >= free_space_needed) {
            result.ptr = buffer_ptr;
            result.idx = buffer_idx;
        }
    }
    return result;
}

inline fn _create_new_text_buffer(self: *Self) !FoundBufferResult {
    const new_buffer_ptr = try DataBuffer.create();
    const new_buffer_idx: u16 = @truncate(self.text_buffers.items.len);
    const new_buffer_free_idx: u16 = @truncate(self.buffers_with_free_space.items.len);
    self.text_buffers.append(Self.list_allocator, new_buffer_ptr);
    self.buffers_with_free_space.append(Self.list_allocator, new_buffer_idx);
    return FoundBufferResult{ .ptr = new_buffer_ptr, .idx = new_buffer_idx, .free_idx = new_buffer_free_idx };
}

inline fn _create_before_snapshots_for_change_to_right_side(self: *Self, segment_idx: u32) SnapshotPair {
    var snaps = SnapshotPair{};
    snaps.has_left = true;
    snaps.left_before = self._get_segment_snapshot(segment_idx);
    if (snaps.left_before.next_segment_idx != TextSegment.NONE_IDX) {
        snaps.has_right = true;
        snaps.right_before = self._get_segment_snapshot(snaps.left_before.next_segment_idx);
    }
    return snaps;
}

inline fn _create_before_snapshots_for_change_to_left_side(self: *Self, segment_idx: u32) SnapshotPair {
    var snaps = SnapshotPair{};
    snaps.has_right = true;
    snaps.right_before = self._get_segment_snapshot(segment_idx);
    if (snaps.right_before.prev_segment_idx != TextSegment.NONE_IDX) {
        snaps.has_left = true;
        snaps.left_before = self._get_segment_snapshot(snaps.right_before.prev_segment_idx);
    }
    return snaps;
}

inline fn _finish_after_snapshots_for_change_to_right_side(self: *Self, snaps: SnapshotPair) ChangePair {
    var changes = ChangePair{};
    changes.has_left = true;
    snaps.left_after = self._get_segment_snapshot(snaps.left_before.segment_idx);
    changes.left_change = TextSegmentSnapshot._create_text_segment_change_to_end_of_segment(snaps.left_before, snaps.left_after);
    if (snaps.has_right) {
        changes.has_right = true;
        snaps.right_after = self._get_segment_snapshot(snaps.left_before.next_segment_idx);
        changes.right_change = TextSegmentSnapshot._create_text_segment_change_to_begin_of_segment(snaps.right_before, snaps.right_after);
    }
    return changes;
}
// ***********
// Sub-Types *
// ***********
const Segments = struct { logical_order: List(u32), by_id: List(TextSegment) };

const TextCursor = struct { logical_idx: u32, byte_offset: u16 };

const FoundBufferResult = struct {
    ptr: ?*DataBuffer = null,
    idx: u16 = 0,
    free_idx: u16 = 0,
};

pub const DataBuffer = struct {
    ptr: [*]u8,
    len: u32,
    cap: u32,

    pub const EMBED_IMAGE_DATA: u16 = std.math.maxInt(u16);
    pub const EMBED_IMAGE_LINK: u16 = EMBED_IMAGE_DATA - 1;
    pub const EMBED_FONT: u16 = EMBED_IMAGE_LINK - 1;
    pub const EMBED_LINK: u16 = EMBED_FONT - 1;
    pub const EMBED_ANCHOR: u16 = EMBED_LINK - 1;
    pub const EMBED_FONT_FAMILY: u16 = EMBED_ANCHOR - 1;
    pub const INTRINSIC_A: u16 = EMBED_FONT_FAMILY - 1;
    pub const INTRINSIC_B: u16 = INTRINSIC_A - 1;
    pub const INTRINSIC_COLOR: u16 = INTRINSIC_B - 1;
    pub const INTRINSIC_OPACITY: u16 = INTRINSIC_COLOR - 1;
    pub const INTRINSIC_COLOR_OPACITY: u16 = INTRINSIC_OPACITY - 1;
    pub const INTRINSIC_BG_COLOR: u16 = INTRINSIC_COLOR_OPACITY - 1;
    pub const INTRINSIC_BG_OPACITY: u16 = INTRINSIC_BG_COLOR - 1;
    pub const INTRINSIC_BG_COLOR_OPACITY: u16 = INTRINSIC_BG_OPACITY - 1;
    pub const INTRINSIC_TABLE_LAYOUT: u16 = INTRINSIC_BG_COLOR_OPACITY - 1;
    pub const MAX_IDX: u16 = INTRINSIC_TABLE_LAYOUT - 1;

    pub inline fn bytes_left(self: DataBuffer) u16 {
        return self.cap - self.len;
    }

    pub inline fn bytes_left_including_grows_within_u16(self: DataBuffer) u16 {
        return std.math.maxInt(u16) - self.len;
    }

    pub inline fn bytes_left_including_grows_within_u32(self: DataBuffer) u32 {
        return std.math.maxInt(u32) - self.len;
    }

    pub inline fn create() !DataBuffer {
        const ptr = try FullPageAllocator.alloc(1);
        return DataBuffer{
            .ptr = ptr,
            .len = 0,
            .cap = FullPageAllocator.PAGE_SIZE,
        };
    }

    pub inline fn can_grow_within_u16_range(self: DataBuffer) bool {
        return self.cap + FullPageAllocator.PAGE_SIZE <= std.math.maxInt(u16);
    }

    pub inline fn can_grow_within_u32_range(self: DataBuffer) bool {
        return self.cap + FullPageAllocator.PAGE_SIZE <= std.math.maxInt(u32);
    }

    pub inline fn grow(self: *DataBuffer) !void {
        const old_pages = FullPageAllocator.pages_needed_for_bytes(self.cap);
        const new_pages = old_pages + 1;
        const new_ptr = try FullPageAllocator.realloc(self.ptr, old_pages, new_pages);
        self.ptr = new_ptr;
        self.cap = FullPageAllocator.bytes_in_pages(new_pages);
    }

    pub inline fn destroy(self: DataBuffer) void {
        const pages = FullPageAllocator.pages_needed_for_bytes(self.cap);
        FullPageAllocator.free(self.ptr, pages);
    }
};

pub const BufferEncoding = enum(u8) {
    UTF8,
    VarInt128,
    Raw,
};

pub const TextSegment = struct {
    buffer_idx: u16 = DataBuffer.NONE,
    byte_start: u16 = 0,
    byte_count: u16 = 0,

    pub inline fn get_intrinsic_a(self: TextSegment) IntrinsicBlockA {
        return @bitCast(self._intrinsic_data());
    }

    pub inline fn set_intrinsic_a(self: *TextSegment, intrinsic_a: IntrinsicBlockA) void {
        self._set_intrinsic_data(@bitCast(intrinsic_a));
    }

    pub inline fn get_intrinsic_b(self: TextSegment) IntrinsicBlockB {
        return @bitCast(self._intrinsic_data());
    }

    pub inline fn set_intrinsic_b(self: *TextSegment, intrinsic_b: IntrinsicBlockB) void {
        self._set_intrinsic_data(@bitCast(intrinsic_b));
    }

    pub inline fn get_intrinsic_color(self: TextSegment) IntrinsicColor {
        return @bitCast(self._intrinsic_data());
    }

    pub inline fn set_intrinsic_color(self: *TextSegment, intrinsic_color: IntrinsicColor) void {
        self._set_intrinsic_data(@bitCast(intrinsic_color));
    }

    pub inline fn get_intrinsic_table(self: TextSegment) IntrinsicTable {
        return @bitCast(self._intrinsic_data());
    }

    pub inline fn set_intrinsic_table(self: *TextSegment, intrinsic_table: IntrinsicTable) void {
        self._set_intrinsic_data(@bitCast(intrinsic_table));
    }

    pub inline fn get_embed_location(self: TextSegment) u32 {
        return @bitCast(self._intrinsic_data());
    }

    pub inline fn set_embed_location(self: *TextSegment, embed_location: u32) void {
        self._set_intrinsic_data(embed_location);
    }

    inline fn _get_intrinsic_data(self: TextSegment) u32 {
        return (@as(u32, self.byte_start) << 16) | @as(u32, self.byte_count);
    }

    inline fn _set_intrinsic_data(self: *TextSegment, data: u32) void {
        self.byte_start = @intCast(data >> 16);
        self.byte_count = @intCast(data & std.math.maxInt(u16));
    }

    comptime {
        assert(@sizeOf(TextSegment) == 6);
        assert(@alignOf(TextSegment) == 2);
    }
};

pub const IntrinsicBlockA = packed struct {
    bold: BinaryIntrinsic,
    italic: BinaryIntrinsic,
    underline: BinaryIntrinsic,
    strikethru: BinaryIntrinsic,
    smallcaps: BinaryIntrinsic,
    super_sub: SuperSubIntrinsic,
    text_style: TextStyleIntrinsic,
    color_off: bool,
    opacity_off: bool,
    link_off: bool,
    table_off: bool,
    heading_off: bool,
    specific_font_off: bool,
    bg_color_off: bool,
    bg_opacity_off: bool,
    font_scale_off: bool,
    anchor_off: bool,
    invert_color: bool,
    text_align: AlignIntrinsic,
    clear_all_formatting: bool,
    block_end: bool,
    // 1 bits left

    comptime {
        assert(@sizeOf(TextSegment) == 4);
        assert(@alignOf(TextSegment) == 4);
    }
};

pub const IntrinsicBlockB = packed struct {
    font_scale: u16,
    heading: HeadingIntrinsic,
    list_type: ListTypeIntrinsic,
    block_type: BlockIntrinsic,
    // 4 bits left

    comptime {
        assert(@sizeOf(TextSegment) == 4);
        assert(@alignOf(TextSegment) == 4);
    }
};

pub const IntrinsicColor = packed struct {
    opacity: u8,
    red: u8,
    blue: u8,
    green: u8,

    comptime {
        assert(@sizeOf(TextSegment) == 4);
        assert(@alignOf(TextSegment) == 4);
    }
};

pub const IntrinsicTable = packed struct {
    columns: u8,
    rows: u8,
    borders_north: bool,
    borders_south: bool,
    borders_east: bool,
    borders_west: bool,
    borders_outline: bool,
    borders_between: bool,
    // 10 bits left

    comptime {
        assert(@sizeOf(TextSegment) == 4);
        assert(@alignOf(TextSegment) == 4);
    }
};

pub const BinaryIntrinsic = enum(u2) {
    Unchanged,
    On,
    Off,
    // 1 key left
};

pub const SuperSubIntrinsic = enum(u2) {
    Unchanged,
    BothOff,
    SuperscriptOn,
    SubscriptOn,
};

pub const TextStyleIntrinsic = enum(u3) {
    Unchanged,
    MonoSansOn,
    MonoSerifOn,
    NormalSansOn,
    NormalSerifOn,
    HandSimpleOn,
    HandFancyOn,
    TextStyleOff,
};

pub const AlignIntrinsic = enum(u3) {
    Unchanged,
    Left,
    Center,
    Right,
    Justify,
    // 3 keys left
};

pub const BlockIntrinsic = enum(u4) {
    Unchanged,
    Indent,
    Quote,
    List,
    // 12 keys left
};

pub const HeadingIntrinsic = enum(u3) {
    Unchanged,
    H0,
    H1,
    H2,
    H3,
    H4,
    H5,
    H6,
};

pub const ListTypeIntrinsic = enum(u5) {
    Unchanged,
    Number,
    AlphaUpper,
    AlphaLower,
    RomanUpper,
    RomanLower,
    CircleFilled,
    CircleHollow,
    SquareFilled,
    SquareHollow,
    ArrowFilled,
    ArrowHollow,
    ChecklistDone,
    ChecklistTodo,
    // 18 keys left
};

pub const ChangeGroup = struct {
    segment_change_count: u32,
};

pub const TextSegmentChange = struct {
    segment_idx_lo: u16 = 0,
    segment_idx_hi: u16 = 0,
    change_flags: TextSegmentChangeFlags = TextSegmentChangeFlags.BLANK,
    byte_count_delta: u8 = 0,
    adjacent_segment_idx_delta_lo: u16 = 0,
    adjacent_segment_idx_delta_hi: u16 = 0,

    pub inline fn get_segment_idx(self: TextSegmentChange) u32 {
        return @as(u32, self.segment_idx_hi) << 16 | @as(u32, self.segment_idx_lo);
    }

    pub inline fn set_segment_idx(self: *TextSegmentChange, segment_idx: u32) void {
        self.segment_idx_hi = @truncate(segment_idx >> 16);
        self.segment_idx_lo = @truncate(segment_idx);
    }

    pub inline fn get_adjacent_segment_idx_delta(self: TextSegmentChange) u32 {
        return @as(u32, self.adjacent_segment_idx_delta_hi) << 16 | @as(u32, self.adjacent_segment_idx_delta_lo);
    }

    pub inline fn set_adjacent_segment_delta(self: *TextSegmentChange, adjacent_segment_idx_delta: u32) void {
        self.adjacent_segment_idx_delta_hi = @truncate(adjacent_segment_idx_delta >> 16);
        self.adjacent_segment_idx_delta_lo = @truncate(adjacent_segment_idx_delta);
    }
};

pub const TextSegmentChangeFlags = struct {
    flags: u8 = 0,

    const LEFT_SIDE_CHANGE_SET: u8 = 0b00000001;
    const LEFT_SIDE_CHANGE_CLEAR: u8 = 0b11111110;
    const SIZE_SHRINK_SET: u8 = 0b00000010;
    const SIZE_SHRINK_CLEAR: u8 = 0b11111101;
    const ADJACENT_SEGMENT_IDX_DECR_SET: u8 = 0b00000100;
    const ADJACENT_SEGMENT_IDX_DECR_CLEAR: u8 = 0b11111011;

    pub inline fn set_left_side_change(self: *TextSegmentChangeFlags) void {
        self.flags = self.flags | TextSegmentChangeFlags.LEFT_SIDE_CHANGE;
    }

    pub inline fn set_right_side_change(self: *TextSegmentChangeFlags) void {
        self.flags = self.flags & TextSegmentChangeFlags.LEFT_SIDE_CHANGE_CLEAR;
    }

    pub inline fn set_size_shrink(self: *TextSegmentChangeFlags) void {
        self.flags = self.flags | TextSegmentChangeFlags.SIZE_SHRINK_SET;
    }

    pub inline fn set_size_grow(self: *TextSegmentChangeFlags) void {
        self.flags = self.flags & TextSegmentChangeFlags.SIZE_SHRINK_CLEAR;
    }

    pub inline fn set_adjacent_segment_idx_decrease(self: *TextSegmentChangeFlags) void {
        self.flags = self.flags | TextSegmentChangeFlags.ADJACENT_SEGMENT_IDX_DECR_SET;
    }

    pub inline fn set_adjacent_segment_idx_increase(self: *TextSegmentChangeFlags) void {
        self.flags = self.flags & TextSegmentChangeFlags.ADJACENT_SEGMENT_IDX_DECR_CLEAR;
    }

    pub inline fn is_left_side_change(self: TextSegmentChangeFlags) bool {
        return self.flags & TextSegmentChangeFlags.LEFT_SIDE_CHANGE_SET == TextSegmentChangeFlags.LEFT_SIDE_CHANGE_SET;
    }

    pub inline fn is_right_side_change(self: TextSegmentChangeFlags) bool {
        return self.flags & TextSegmentChangeFlags.LEFT_SIDE_CHANGE_SET == 0;
    }

    pub inline fn is_size_shrink(self: TextSegmentChangeFlags) bool {
        return self.flags & TextSegmentChangeFlags.SIZE_SHRINK_SET == TextSegmentChangeFlags.SIZE_SHRINK_SET;
    }

    pub inline fn is_size_grow(self: TextSegmentChangeFlags) bool {
        return self.flags & TextSegmentChangeFlags.SIZE_SHRINK_SET == 0;
    }

    pub inline fn is_adjacent_segment_idx_decrease(self: TextSegmentChangeFlags) bool {
        return self.flags & TextSegmentChangeFlags.ADJACENT_SEGMENT_IDX_DECR_SET == TextSegmentChangeFlags.ADJACENT_SEGMENT_IDX_DECR_SET;
    }

    pub inline fn is_adjacent_segment_idx_increase(self: TextSegmentChangeFlags) bool {
        return self.flags & TextSegmentChangeFlags.ADJACENT_SEGMENT_IDX_DECR_SET == 0;
    }
};

const TextSegmentSnapshot = struct {
    segment_idx: u32,
    byte_start: u16,
    byte_count: u8,
    next_segment_idx: u32,
    prev_segment_idx: u32,

    const BLANK = TextSegmentSnapshot{ .segment_idx = 0, .byte_start = 0, .byte_count = 0, .next_segment_idx = TextSegment.NONE_IDX, .prev_segment_idx = TextSegment.NONE_IDX };

    fn _create_text_segment_change_to_end_of_segment(before: TextSegmentSnapshot, after: TextSegmentSnapshot) TextSegmentChange {
        assert(before.segment_idx == after.segment_idx);
        var change = TextSegmentChange{};
        change.set_segment_idx(before.segment_idx);
        change.change_flags.set_right_side_change();
        if (after.byte_count > before.byte_count) {
            change.change_flags.set_size_grow();
            change.byte_count_delta = after.byte_count - before.byte_count;
        } else {
            change.change_flags.set_size_shrink();
            change.byte_count_delta = before.byte_count - after.byte_count;
        }
        if (after.next_segment_idx > before.next_segment_idx) {
            change.change_flags.set_adjacent_segment_idx_increase();
            change.set_adjacent_segment_delta(after.next_segment_idx - before.next_segment_idx);
        } else {
            change.change_flags.set_adjacent_segment_idx_decrease();
            change.set_adjacent_segment_delta(before.next_segment_idx - after.next_segment_idx);
        }
        return change;
    }

    fn _create_text_segment_change_to_begin_of_segment(before: TextSegmentSnapshot, after: TextSegmentSnapshot) TextSegmentChange {
        assert(before.segment_idx == after.segment_idx);
        var change = TextSegmentChange{};
        change.set_segment_idx(before.segment_idx);
        change.change_flags.set_left_side_change();
        if (after.byte_start > before.byte_start) {
            change.change_flags.set_size_shrink();
            change.byte_count_delta = after.byte_start - before.byte_start;
        } else {
            change.change_flags.set_size_grow();
            change.byte_count_delta = before.byte_start - after.byte_start;
        }
        if (after.prev_segment_idx > before.prev_segment_idx) {
            change.change_flags.set_adjacent_segment_idx_increase();
            change.set_adjacent_segment_delta(after.prev_segment_idx - before.prev_segment_idx);
        } else {
            change.change_flags.set_adjacent_segment_idx_decrease();
            change.set_adjacent_segment_delta(before.prev_segment_idx - after.prev_segment_idx);
        }
        return change;
    }
};

pub const SnapshotPair = struct {
    has_left: bool = false,
    left_before: TextSegmentSnapshot = TextSegmentSnapshot.BLANK,
    left_after: TextSegmentSnapshot = TextSegmentSnapshot.BLANK,
    has_right: bool = false,
    right_before: TextSegmentSnapshot = TextSegmentSnapshot.BLANK,
    right_after: TextSegmentSnapshot = TextSegmentSnapshot.BLANK,
};

pub const ChangePair = struct {
    has_left: bool = false,
    left_change: TextSegmentChange = TextSegmentChange{},
    has_right: bool = false,
    right_change: TextSegmentChange = TextSegmentChange{},
};

pub const EditAction = enum { SingleCharInsert, SingleCharDelete, Other };

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
