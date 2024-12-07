const std = @import("std");
const math = std.math;
const assert = std.debug.assert;

pub const UTF8 = struct {
    pub const REPLACEMENT_CHAR: u32 = 0xFFFD;

    const SINGLE_BYTE_FLAG: comptime_int = 0b00000000;
    const SINGLE_BYTE_FLAG_MASK: comptime_int = 0b10000000;
    const SINGLE_BYTE_DATA_MASK: comptime_int = 0b01111111;
    const CONTINUE_BYTE_FLAG: comptime_int = 0b10000000;
    const CONTINUE_BYTE_FLAG_MASK: comptime_int = 0b11000000;
    const CONTINUE_BYTE_DATA_MASK: comptime_int = 0b00111111;
    const TWO_BYTE_FLAG: comptime_int = 0b11000000;
    const TWO_BYTE_FLAG_MASK: comptime_int = 0b11100000;
    const TWO_BYTE_DATA_MASK: comptime_int = 0b00011111;
    const THREE_BYTE_FLAG: comptime_int = 0b11100000;
    const THREE_BYTE_FLAG_MASK: comptime_int = 0b11110000;
    const THREE_BYTE_DATA_MASK: comptime_int = 0b00001111;
    const FOUR_BYTE_FLAG: comptime_int = 0b11110000;
    const FOUR_BYTE_FLAG_MASK: comptime_int = 0b11111000;
    const FOUR_BYTE_DATA_MASK: comptime_int = 0b00000111;
    const CONTINUE_BYTE_SHIFT: comptime_int = 6;

    pub const ASCII = struct {
        pub const NUL: u8 = 0;
        pub const SOH: u8 = 1;
        pub const STX: u8 = 2;
        pub const ETX: u8 = 3;
        pub const EOT: u8 = 4;
        pub const ENQ: u8 = 5;
        pub const ACK: u8 = 6;
        pub const BEL: u8 = 7;
        pub const BS: u8 = 8;
        pub const HT: u8 = 9;
        pub const LF: u8 = 10;
        pub const VT: u8 = 11;
        pub const FF: u8 = 12;
        pub const CR: u8 = 13;
        pub const SO: u8 = 14;
        pub const SI: u8 = 15;
        pub const DLE: u8 = 16;
        pub const DC1: u8 = 17;
        pub const DC2: u8 = 18;
        pub const DC3: u8 = 19;
        pub const DC4: u8 = 20;
        pub const NAK: u8 = 21;
        pub const SYN: u8 = 22;
        pub const ETB: u8 = 23;
        pub const CAN: u8 = 24;
        pub const EM: u8 = 25;
        pub const SUB: u8 = 26;
        pub const ESC: u8 = 27;
        pub const FS: u8 = 28;
        pub const GS: u8 = 29;
        pub const RS: u8 = 30;
        pub const US: u8 = 31;
        pub const SPACE: u8 = 32;
        //TODO: All other printable chars
        pub const DEL: u8 = 127;
    };

    pub fn is_valid_codepoint(char: u32) bool {
        return switch (char) {
            0xD800...0xDFFF => false,
            0x110000...0xFFFFFFFF => false,
            else => true,
        };
    }

    pub fn encoded_length(char: u32) u8 {
        assert(UTF8.is_valid_codepoint(char));
        if (char < 0x80) return 1;
        if (char < 0x800) return 2;
        if (char < 0x10000) return 3;
        return 4;
    }

    pub fn decoded_length(first_byte: u8) !u8 {
        if (first_byte & SINGLE_BYTE_FLAG_MASK == SINGLE_BYTE_FLAG) {
            return 1;
        }
        if (first_byte & TWO_BYTE_FLAG_MASK == TWO_BYTE_FLAG) {
            return 2;
        }
        if (first_byte & THREE_BYTE_FLAG_MASK == THREE_BYTE_FLAG) {
            return 3;
        }
        if (first_byte & FOUR_BYTE_FLAG_MASK == FOUR_BYTE_FLAG) {
            return 4;
        }
        return error.UTF8_FirstByteInvalid;
    }

    pub fn encode(char: u32, encoded_len: u8, buf: []u8) void {
        assert(UTF8.is_valid_codepoint(char));
        assert(buf.len >= encoded_len);
        switch (encoded_len) {
            1 => buf[0] = @intCast(char),
            2 => {
                buf[0] = TWO_BYTE_FLAG | @as(u8, @intCast(char >> (1 * CONTINUE_BYTE_SHIFT)));
                buf[1] = CONTINUE_BYTE_FLAG | @as(u8, @intCast(char & CONTINUE_BYTE_DATA_MASK));
            },
            3 => {
                buf[0] = THREE_BYTE_FLAG | @as(u8, @intCast(char >> (2 * CONTINUE_BYTE_SHIFT)));
                buf[1] = CONTINUE_BYTE_FLAG | @as(u8, @intCast((char >> (1 * CONTINUE_BYTE_SHIFT)) & CONTINUE_BYTE_DATA_MASK));
                buf[2] = CONTINUE_BYTE_FLAG | @as(u8, @intCast(char & CONTINUE_BYTE_DATA_MASK));
            },
            4 => {
                buf[0] = FOUR_BYTE_FLAG | @as(u8, @intCast(char >> (3 * CONTINUE_BYTE_SHIFT)));
                buf[1] = CONTINUE_BYTE_FLAG | @as(u8, @intCast((char >> (2 * CONTINUE_BYTE_SHIFT)) & CONTINUE_BYTE_DATA_MASK));
                buf[2] = CONTINUE_BYTE_FLAG | @as(u8, @intCast((char >> (1 * CONTINUE_BYTE_SHIFT)) & CONTINUE_BYTE_DATA_MASK));
                buf[3] = CONTINUE_BYTE_FLAG | @as(u8, @intCast(char & CONTINUE_BYTE_DATA_MASK));
            },
            else => unreachable,
        }
    }

    pub fn decode_first(buf: []const u8) u32 {
        _ = buf; // autofix
        @panic("unimplemented"); //TODO:
    }

    pub fn decode_last(buf: []const u8) u32 {
        _ = buf; // autofix
        @panic("unimplemented"); //TODO:
    }

    pub fn is_whitespace(char: u32) bool {
        //TODO: Add more comprehensive whitespace checks
        return (char >= ASCII.HT and char <= ASCII.CR) or (char >= ASCII.FS and char <= ASCII.SPACE);
    }

    pub fn is_linebreak(char: u32) bool {
        //TODO: Add more comprehensive linebreak checks
        return (char >= ASCII.LF and char <= ASCII.FF) or (char >= ASCII.FS and char <= ASCII.GS);
    }
};

pub const PSIFMT = struct {
    pub const BEGIN_FMT = 0;
    pub const END_FMT = 1;
    pub const BOLD_ON = 2;
    pub const BOLD_OFF = 3;
    pub const ITALIC_ON = 4;
    pub const ITALIC_OFF = 5;
    pub const UNDERLINE_ON = 6;
    pub const UNDERLINE_OFF = 7;
    pub const STRIKETHRU_ON = 8;
    pub const STRIKETHRU_OFF = 9;
    pub const SMALLCAPS_ON = 10;
    pub const SMALLCAPS_OFF = 11;
    pub const SUPERSUB_ON = 12;
    pub const SUPERSUB_OFF = 13;
    pub const FONT_STYLE_ON = 14;
    pub const FONT_STYLE_OFF = 15;
    pub const COLOR_ON = 16;
    pub const COLOR_OFF = 17;
    pub const HL_COLOR_ON = 18;
    pub const HL_COLOR_OFF = 19;
    pub const OPACITY_ON = 20;
    pub const OPACITY_OFF = 21;
    pub const HL_OPACITY_ON = 22;
    pub const HL_OPACITY_OFF = 23;
    pub const LINK_ON = 24;
    pub const LINK_OFF = 25;
    pub const SIZE_ON = 26;
    pub const SIZE_OFF = 27;
    pub const ANCHOR_LOC = 28;
    pub const INDENT_IN = 29;
    pub const INDENT_OUT = 30;
    pub const LIST_START = 31;
    pub const LIST_END = 32;
    pub const QUOTE_START = 33;
    pub const QUOTE_END = 34;
    pub const TABLE_START = 35;
    pub const TABLE_END = 36;
    pub const COLUMNS_START = 37;
    pub const COLUMNS_END = 38;
    pub const HEADER_ON = 39;
    pub const HEADER_OFF = 40;
    pub const ALIGN_ON = 41;
    pub const ALIGN_OFF = 42;
    pub const IMAGE = 43;
    pub const CELL_START = 44;
    pub const CELL_END = 45;
    pub const PARA_START = 46;
    pub const PARA_END = 47;
    pub const SCENE_SEP = 48;
    pub const SPEAKER_START = 49;
    pub const SPEAKER_END = 50;
    pub const PROPER_TERM_START = 51;
    pub const PROPER_TERM_END = 52;
    pub const ENTITY_ATTR_START = 53;
    pub const ENTITY_ATTR_END = 54;
    pub const NARRATOR_START = 55;
    pub const NARRATOR_END = 56;
    pub const CODE_START = 57;
    pub const CODE_END = 58;
    pub const FORMULA_START = 59;
    pub const FORMULA_END = 60;
    const _UNUSED_START = 61;
    const _MAX_KEY = 127;

    const BYTE_DATA_MASK: u8 = 0b01111111;
    const VAL_SIGNAL_BIT: u8 = 0b10000000;
    const LAST_BYTE_DATA_MASK: u8 = 0b00000001;
    const LAST_BYTE_EX_MASK: u8 = 0b01111110;
    const LAST_BYTE_EX_SHIFT: comptime_int = 1;

    pub fn read_next_keyval(buf: []u8) ReadKeyValResult {
        assert(buf.len != 0);

        var result = ReadKeyValResult{};

        if (buf[result.len] & VAL_SIGNAL_BIT == VAL_SIGNAL_BIT) {
            result.err |= ERROR.FIRST_BYTE_ISNT_KEY;
        }

        result.key = @as(u32, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;

        if (result.key >= _UNUSED_START) {
            result.err |= ERROR.UNKNOWN_KEY;
        }

        // Handle extended keys here, if needed in future

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = @as(u64, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;
        result.has_val = true;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = (result.val << 7) | @as(u64, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = (result.val << 7) | @as(u64, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = (result.val << 7) | @as(u64, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = (result.val << 7) | @as(u64, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = (result.val << 7) | @as(u64, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = (result.val << 7) | @as(u64, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = (result.val << 7) | @as(u64, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = (result.val << 7) | @as(u64, @intCast(buf[result.len] & BYTE_DATA_MASK));
        result.len += 1;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.val = (result.val << 1) | @as(u64, @intCast(buf[result.len] & LAST_BYTE_DATA_MASK));
        result.val_ex = @as(u64, @intCast((buf[result.len] & LAST_BYTE_EX_MASK) >> LAST_BYTE_EX_SHIFT));
        result.len += 1;

        if (buf.len == result.len or ((buf[result.len] & VAL_SIGNAL_BIT) != VAL_SIGNAL_BIT)) return result;

        result.err |= ERROR.VAL_OVERFLOW;

        while ((result.len < buf.len) and (result.len < 255) and ((buf[result.len] & VAL_SIGNAL_BIT) == VAL_SIGNAL_BIT)) {
            result.len += 1;
        }

        return result;
    }

    pub fn find_idx_of_last_keyval(buf: []u8) FindLastKeyValResult {
        assert(buf.len != 0);

        var result = FindLastKeyValResult{};

        result.idx = buf.len - 1;

        while (result.idx > 0 and ((buf[result.idx] & VAL_SIGNAL_BIT) == VAL_SIGNAL_BIT)) {
            result.idx -= 1;
        }

        if ((buf[result.idx] & VAL_SIGNAL_BIT) != 0) {
            result.err |= ERROR.NO_KEYS_FOUND_IN_BUF;
        }

        return result;
    }

    pub const ReadKeyValResult = struct {
        key: u32 = 0,
        val: u64 = 0,
        val_ex: u8 = 0,
        has_val: bool = false,
        len: u8 = 0,
        err: u8 = ERROR.NONE,
    };

    pub const FindLastKeyValResult = struct {
        idx: usize = 0,
        err: u8 = ERROR.NONE,
    };

    pub const ERROR = struct {
        pub const NONE: u8 = 0;
        pub const UNKNOWN_KEY: u8 = 1 << 0;
        pub const VAL_OVERFLOW: u8 = 1 << 1;
        pub const FIRST_BYTE_ISNT_KEY: u8 = 1 << 2;
        pub const NO_KEYS_FOUND_IN_BUF: u8 = 1 << 3;
    };
};

pub const VarInt21 = struct {
    pub const CONINUE_BIT: u8 = 0b10000000;
    pub const DATA_BITS: u8 = 0b01111111;

    pub fn read_first(buf: []u8) ReadResult {
        assert(buf.len != 0);

        var result = ReadResult{};
        var more_bytes: bool = false;

        result.val = @as(u32, @intCast(buf[result.len] & DATA_BITS));
        more_bytes = (buf[result.len] & CONINUE_BIT) == CONINUE_BIT;
        result.len += 1;

        if (!more_bytes) return result;

        if (buf.len == result.len) {
            result.err |= ERROR.BUF_END_BEFORE_TERMINAL_BYTE;
            return result;
        }

        result.val = (result.val << 7) | @as(u32, @intCast(buf[result.len] & DATA_BITS));
        more_bytes = (buf[result.len] & CONINUE_BIT) == CONINUE_BIT;
        result.len += 1;

        if (!more_bytes) return result;

        if (buf.len == result.len) {
            result.err |= ERROR.BUF_END_BEFORE_TERMINAL_BYTE;
            return result;
        }

        result.val = (result.val << 7) | @as(u32, @intCast(buf[result.len] & DATA_BITS));
        more_bytes = (buf[result.len] & CONINUE_BIT) == CONINUE_BIT;
        result.len += 1;

        if (!more_bytes) return result;

        result.err |= ERROR.VAL_BYTE_3_NOT_TERMINAL;

        while ((result.len < buf.len) and (result.len < 255) and ((buf[result.len] & CONINUE_BIT) == CONINUE_BIT)) {
            result.len += 1;
        }

        if (result.len == buf.len and ((buf[result.len] & CONINUE_BIT) == CONINUE_BIT)) {
            result.err |= ERROR.BUF_END_BEFORE_TERMINAL_BYTE;
        }

        return result;
    }

    pub fn read_last(buf: []u8) ReadResult {
        assert(buf.len != 0);

        var result = ReadResult{};

        result.len += 1;
        result.val = @as(u32, @intCast(buf[buf.len - result.len] & DATA_BITS));

        if (buf[buf.len - result.len] & CONINUE_BIT != 0) {
            result.err |= ERROR.BUF_END_BEFORE_TERMINAL_BYTE;
        }

        if (buf.len == result.len or ((buf[buf.len - result.len - 1] & CONINUE_BIT) == 0)) return result;

        result.len += 1;
        result.val |= (@as(u32, @intCast(buf[buf.len - result.len] & DATA_BITS)) << 7);

        if (buf.len == result.len or ((buf[buf.len - result.len - 1] & CONINUE_BIT) == 0)) return result;

        result.len += 1;
        result.val |= (@as(u32, @intCast(buf[buf.len - result.len] & DATA_BITS)) << 14);

        if (buf.len == result.len or ((buf[buf.len - result.len - 1] & CONINUE_BIT) == 0)) return result;

        result.err |= ERROR.BYTE_PRECEDING_BYTE_1_ISNT_TERMINAL;

        while ((result.len < buf.len) and (result.len < 255) and ((buf[buf.len - result.len - 1] & CONINUE_BIT) == CONINUE_BIT)) {
            result.len += 1;
        }

        return result;
    }

    pub const ReadResult = struct {
        val: u32 = 0,
        len: u8 = 0,
        err: u8 = ERROR.NONE,
    };

    pub const ERROR = struct {
        pub const NONE: u8 = 0;
        pub const BUF_END_BEFORE_TERMINAL_BYTE: u8 = 1 << 0;
        pub const BYTE_PRECEDING_BYTE_1_ISNT_TERMINAL: u8 = 1 << 1;
        pub const BUFFER_ZERO_LENGTH: u8 = 1 << 2;
        pub const VAL_BYTE_3_NOT_TERMINAL: u8 = 1 << 3;
    };
};
