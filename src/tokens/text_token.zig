const assert = @import("std").debug.assert;

const Align = @import("./align.zig").Align;
const EmbedPosition = @import("./embed_position.zig").EmbedPosition;
const FontSize = @import("./font_size.zig").FontSize;
const Color = @import("./color.zig").ColorRGB8;
const Opacity = @import("./opacity.zig").Opacity;
const IndentChange = @import("./indent_change.zig").IndentChange;
const TableSize = @import("./table_size.zig").TableSize;
const Columns = @import("./columns.zig").Columns;
const Heading = @import("./heading.zig").Heading;
const ListType = @import("./list_type.zig").ListType;
const asc = @import("../../Encoding.zig").UTF8.ASCII;

pub const Format = struct {
    const FORMAT_BEGIN = 1;
    const FORMAT_END = 2;
    const BOLD = 3;
    const ITALIC = 4;
    const UNDERLINE = 5;
    const STRIKETHRU = 6;
    const SMALLCAPS = 7;
    const SUPERSUB = 8;
    const FONT = 9;
    const COLOR = 10;
    const BG_COLOR = 11;
    const OPACITY = 12;
    const BG_OPACITY = 13;
    const LINK = 14;
    const SIZE = 15;
    const ANCHOR = 16;
    const PARAGRAPH = 17;
    const HEADING = 18;

    pub const Inline = struct {
        const BOLD = 1;
        const ITALIC = 2;
        const UNDERLINE = 3;
        const STRIKETHRU = 4;
        const SMALLCAPS = 5;
        const SUPERSUB = 6;
        const FONT = 7;
        const COLOR = 8;
        const BG_COLOR = 9;
        const OPACITY = 10;
        const BG_OPACITY = 11;
        const LINK = 12;
        const SIZE = 13;
        const ANCHOR = 14;
    };

    pub const BlockType = struct {
        const PARAGRAPH = 1;
        const HEADING = 2;
        const COLUMNS = 3;
        const TABLE = 4;
        const LIST = 5;
    };

    pub const BlockFormat = struct {
        const HEADING = 1;
        const TABLE = 2;
        const COLUMNS = 3;
        const ALIGN = 4;
    };
};

pub const TextTokenTag = enum(u8) {
    const E_BOLD_TOGGLE: comptime_int = 0;
    const E_ITALIC_TOGGLE: comptime_int = 1;
    const E_UNDERLINE_TOGGLE: comptime_int = 2;
    const E_STRIKETHRU_TOGGLE: comptime_int = 3;
    const E_SMALLCAPS_TOGGLE: comptime_int = 4;
    const E_SUPERSCRIPT_ON: comptime_int = 5;
    const E_SUBSCRIPT_ON: comptime_int = 6;
    const E_SUPERSUB_OFF: comptime_int = 7;
    const E_MONOSANS_ON: comptime_int = 8;
    const E_MONOSERIF_ON: comptime_int = 9;
    const E_HANDSIMPLE_ON: comptime_int = 10;
    const E_HANDFANCY_ON: comptime_int = 11;
    const E_NORMALSANS_ON: comptime_int = 12;
    const E_NORMALSERIF_ON: comptime_int = 13;
    const E_TEXTSTYLE_OFF: comptime_int = 14;
    const E_COLOR_OFF: comptime_int = 15;
    const E_OPACITY_OFF: comptime_int = 16;
    const E_LINK_OFF: comptime_int = 17;
    const E_TABLE_OFF: comptime_int = 18;
    const E_COLUMNS_OFF: comptime_int = 19;
    const E_HEADING_OFF: comptime_int = 20;
    const E_SPECIFIC_FONT_OFF: comptime_int = 21;
    const E_BG_COLOR_OFF: comptime_int = 22;
    const E_BG_OPACITY_OFF: comptime_int = 23;
    const E_FONT_SIZE_OFF: comptime_int = 24;
    const E_ALIGN_OFF: comptime_int = 25;
    const E_ANCHOR_OFF: comptime_int = 26;
    const E_INVERT_COLOR: comptime_int = 27;
    const E_PAGE_BREAK: comptime_int = 28;
    const E_SCENE_BREAK: comptime_int = 29;
    const E_LINE_BREAK: comptime_int = 30;
    const E_CELL_BREAK: comptime_int = 31;
    const E_UTF8_CODEPOINT: comptime_int = 32;
    const E_CLEAR_ALL_FORMATTING: comptime_int = 33;
    const E_EXTENDED_KEY_VALUE: comptime_int = 34;
    const E_FONT_SIZE_ON: comptime_int = 35;
    const E_COLOR_ON: comptime_int = 36;
    const E_OPACITY_ON: comptime_int = 37;
    const E_ALIGN_ON: comptime_int = 38;
    const E_LINK_ON: comptime_int = 39;
    const E_ANCHOR_ON: comptime_int = 40;
    const E_INDENT: comptime_int = 41;
    const E_LIST_INDENT: comptime_int = 42;
    const E_QUOTE_INDENT: comptime_int = 43;
    const E_TABLE_ON: comptime_int = 44;
    const E_COLUMNS_ON: comptime_int = 45;
    const E_HEADING_ON: comptime_int = 46;
    const E_FONT_EMBED_ON: comptime_int = 47;
    const E_FONT_FAMILY_ON: comptime_int = 48;
    const E_IMAGE_LINK: comptime_int = 49;
    const E_IMAGE_EMBED: comptime_int = 50;
    const E_BG_COLOR_ON: comptime_int = 51;
    const E_BG_OPACITY_ON: comptime_int = 52;
    const E_LIST_TYPE: comptime_int = 53;
    const E_UTF8_ESCAPE: comptime_int = 54;

    const TEXT_MODE_LOOKUP_ENUM_COUNT: comptime_int = 32;
    const ENCODABLE_ENUM_COUNT: comptime_int = 55;

    const E_IGNORE: comptime_int = 254;
    const E_NONE: comptime_int = 255;

    const VAL_BOLD_TOGGLE: comptime_int = 0;
    const VAL_ITALIC_TOGGLE: comptime_int = 1;
    const VAL_UNDERLINE_TOGGLE: comptime_int = 2;
    const VAL_STRIKETHRU_TOGGLE: comptime_int = 3;
    const VAL_SMALLCAPS_TOGGLE: comptime_int = 4;
    const VAL_SUPERSCRIPT_ON: comptime_int = 5;
    const VAL_SUBSCRIPT_ON: comptime_int = 6;
    const VAL_SUPERSUB_OFF: comptime_int = 7;
    const VAL_MONOSANS_ON: comptime_int = 8;
    const VAL_MONOSERIF_ON: comptime_int = 9;
    const VAL_HANDSIMPLE_ON: comptime_int = 10;
    const VAL_HANDFANCY_ON: comptime_int = 11;
    const VAL_NORMALSANS_ON: comptime_int = 12;
    const VAL_NORMALSERIF_ON: comptime_int = 13;
    const VAL_TEXTSTYLE_OFF: comptime_int = 14;
    const VAL_COLOR_OFF: comptime_int = 15;
    const VAL_OPACITY_OFF: comptime_int = 16;
    const VAL_LINK_OFF: comptime_int = 17;
    const VAL_TABLE_OFF: comptime_int = 18;
    const VAL_COLUMNS_OFF: comptime_int = 19;
    const VAL_HEADING_OFF: comptime_int = 20;
    const VAL_SPECIFIC_FONT_OFF: comptime_int = 21;
    const VAL_BG_COLOR_OFF: comptime_int = 22;
    const VAL_BG_OPACITY_OFF: comptime_int = 23;
    const VAL_FONT_SIZE_OFF: comptime_int = 24;
    const VAL_ALIGN_OFF: comptime_int = 25;
    const VAL_ANCHOR_OFF: comptime_int = 26;
    const VAL_INVERT_COLOR: comptime_int = 27;
    const VAL_PAGE_BREAK: comptime_int = 28;
    const VAL_SCENE_BREAK: comptime_int = 29;
    const VAL_LINE_BREAK: comptime_int = 30;
    const VAL_CELL_BREAK: comptime_int = 31;
    const VAL_CLEAR_ALL_FORMATTING: comptime_int = 127;

    const KEY_EXTENDED_KEY_VALUE: comptime_int = 0;
    const KEY_FONT_SIZE_ON: comptime_int = 1;
    const KEY_COLOR_ON: comptime_int = 2;
    const KEY_OPACITY_ON: comptime_int = 3;
    const KEY_ALIGN_ON: comptime_int = 4;
    const KEY_LINK_ON: comptime_int = 5;
    const KEY_ANCHOR_ON: comptime_int = 6;
    const KEY_INDENT: comptime_int = 7;
    const KEY_LIST_INDENT: comptime_int = 8;
    const KEY_QUOTE_INDENT: comptime_int = 9;
    const KEY_TABLE_ON: comptime_int = 10;
    const KEY_COLUMNS_ON: comptime_int = 11;
    const KEY_HEADING_ON: comptime_int = 12;
    const KEY_FONT_EMBED_ON: comptime_int = 13;
    const KEY_FONT_FAMILY_ON: comptime_int = 14;
    const KEY_IMAGE_LINK: comptime_int = 15;
    const KEY_IMAGE_EMBED: comptime_int = 16;
    const KEY_BG_COLOR_ON: comptime_int = 17;
    const KEY_BG_OPACITY_ON: comptime_int = 18;
    const KEY_LIST_TYPE: comptime_int = 19;
    const KEY_UTF8_ESCAPE: comptime_int = 20;

    const KVP_MODE_LOOKUP_KEY_COUNT: comptime_int = 21;
    //*******************
    // TEXT MODE TOKENS *
    //*******************
    BoldToggle = E_BOLD_TOGGLE,
    ItalicToggle = E_ITALIC_TOGGLE,
    UnderlineToggle = E_UNDERLINE_TOGGLE,
    StrikethruToggle = E_STRIKETHRU_TOGGLE,
    SmallcapsToggle = E_SMALLCAPS_TOGGLE,
    SuperScriptOn = E_SUPERSCRIPT_ON,
    SubScriptOn = E_SUBSCRIPT_ON,
    SuperSubOff = E_SUPERSUB_OFF,
    MonoSansOn = E_MONOSANS_ON,
    MonoSerifOn = E_MONOSERIF_ON,
    HandSimpleOn = E_HANDSIMPLE_ON,
    HandFancyOn = E_HANDFANCY_ON,
    NormalSansOn = E_NORMALSANS_ON,
    NormalSerifOn = E_NORMALSERIF_ON,
    TextStyleOff = E_TEXTSTYLE_OFF,
    ColorOff = E_COLOR_OFF,
    OpacityOff = E_OPACITY_OFF,
    LinkOff = E_LINK_OFF,
    TableOff = E_TABLE_OFF,
    ColumnsOff = E_COLUMNS_OFF,
    HeadingOff = E_HEADING_OFF,
    SpecificFontOff = E_SPECIFIC_FONT_OFF,
    BgColorOff = E_BG_COLOR_OFF,
    BgOpacityOff = E_BG_OPACITY_OFF,
    FontSizeOff = E_FONT_SIZE_OFF,
    AlignOff = E_ALIGN_OFF,
    AnchorOff = E_ANCHOR_OFF,
    InvertColor = E_INVERT_COLOR,
    PageBreak = E_PAGE_BREAK,
    SceneBreak = E_SCENE_BREAK,
    LineBreak = E_LINE_BREAK,
    CellBreak = E_CELL_BREAK,
    UTF8CodePoint = E_UTF8_CODEPOINT,
    ClearAllFormatting = E_CLEAR_ALL_FORMATTING,
    //************************
    // 7-BIT KEY MODE TOKENS *
    //************************
    ExtendedKeyValue = E_EXTENDED_KEY_VALUE,
    FontSizeOn = E_FONT_SIZE_ON,
    ColorOn = E_COLOR_ON,
    OpacityOn = E_OPACITY_ON,
    AlignOn = E_ALIGN_ON,
    LinkOn = E_LINK_ON,
    AnchorOn = E_ANCHOR_ON,
    Indent = E_INDENT,
    ListIndent = E_LIST_INDENT,
    QuoteIndent = E_QUOTE_INDENT,
    TableOn = E_TABLE_ON,
    ColumnsOn = E_COLUMNS_ON,
    HeadingOn = E_HEADING_ON,
    FontEmbedOn = E_FONT_EMBED_ON,
    FontFamilyOn = E_FONT_FAMILY_ON,
    ImageLink = E_IMAGE_LINK,
    ImageEmbed = E_IMAGE_EMBED,
    BgColorOn = E_BG_COLOR_ON,
    BgOpacityOn = E_BG_OPACITY_ON,
    ListType = E_LIST_TYPE,
    UTF8Escape = E_UTF8_ESCAPE,
    //***************
    // OTHER TOKENS *
    //***************
    Ignore = E_IGNORE,
    None = E_NONE,
};

pub const TextTokenPayload = union {
    //*******************
    // TEXT MODE TOKENS *
    //*******************
    BoldToggle: void,
    ItalicToggle: void,
    UnderlineToggle: void,
    StrikethruToggle: void,
    SmallcapsToggle: void,
    SuperScriptOn: void,
    SubScriptOn: void,
    SuperSubOff: void,
    MonoSansOn: void,
    MonoSerifOn: void,
    HandSimpleOn: void,
    HandFancyOn: void,
    NormalSansOn: void,
    NormalSerifOn: void,
    TextStyleOff: void,
    ColorOff: void,
    OpacityOff: void,
    LinkOff: void,
    TableOff: void,
    ColumnsOff: void,
    HeadingOff: void,
    SpecificFontOff: void,
    BgColorOff: void,
    BgOpacityOff: void,
    FontSizeOff: void,
    AlignOff: void,
    AnchorOff: void,
    InvertColor: void,
    PageBreak: void,
    SceneBreak: void,
    LineBreak: void,
    CellBreak: void,
    UTF8CodePoint: u32,
    ClearAllFormating: void,
    //************************
    // 7-BIT KEY MODE TOKENS *
    //************************
    ExtendedKeyValue: EmbedPosition,
    FontSizeOn: FontSize,
    ColorOn: Color,
    OpacityOn: Opacity,
    AlignOn: Align,
    LinkOn: EmbedPosition,
    AnchorOn: EmbedPosition,
    Indent: IndentChange,
    ListIndent: IndentChange,
    QuoteIndent: IndentChange,
    TableOn: TableSize,
    ColumnsOn: Columns,
    HeadingOn: Heading,
    FontEmbedOn: EmbedPosition,
    FontFamilyOn: EmbedPosition,
    ImageLink: EmbedPosition,
    ImageEmbed: EmbedPosition,
    BgColorOn: Color,
    BgOpacityOn: Opacity,
    ListType: ListType,
    UTF8Escape: u32,
    //************************
    // 7-BIT KEY MODE TOKENS *
    //************************
    Ignore: void,
    None: void,
};

pub const TextToken = struct {
    tag: TextTokenTag,
    payload: TextTokenPayload,

    const KEY_MASK_7BIT: u8 = 0b01111111;
    const KEY_WIDTH_7BIT: usize = 7;

    const KVP_KEY_MASK: u128 = 127; // Bits 0-6 inclusive set
    const KVP_LOW_VAL_DECODE_MASK: u128 = 0x7FF80; // Bits 7-18 inclusive set
    const KVP_LOW_VAL_ENCODE_MASK: u128 = 4095; // Bits 0-11 inclusive set
    const KVP_UTF8_RANGE_GUARD: u128 = 0x180000; // Bits 19-20 inclusive set
    const KVP_HI_VAL_DECODE_MASK: u128 = 0xFFFFFFFFFFE00000; // Bits 21-127 inclusive set
    const KVP_HI_VAL_ENCODE_MASK: u128 = 0xFFFFFFFFFFF80000; // Bits 19-127 inclusive set
    const KVP_KEY_WIDTH: usize = 7;
    const KVP_LOW_VAL_WIDTH: usize = 12;
    const KVP_GUARD_WIDTH: usize = 2;
    const KVP_LOW_VAL_SHIFT: usize = KVP_KEY_WIDTH;
    const KVP_HI_VAL_SHIFT: usize = KVP_KEY_WIDTH + KVP_LOW_VAL_WIDTH + KVP_GUARD_WIDTH;

    const KVP_RANGE_GUARD_CLEAR: u128 = !KVP_UTF8_RANGE_GUARD;

    pub const UTF8_A_LIMIT_LO: u128 = 31;
    pub const UTF8_A_LIMIT_HI: u128 = 127;
    pub const UTF8_B_LIMIT_LO: u128 = 127;
    pub const UTF8_B_LIMIT_HI: u128 = 0xD800;
    pub const UTF8_C_LIMIT_LO: u128 = 0xDFFF;
    pub const UTF8_C_LIMIT_HI: u128 = 0x110000;

    pub const UTF8_ILLEGAL_SURROGATE_BEGIN: u32 = 0xD800;
    pub const UTF8_ILLEGAL_SURROGATE_END: u32 = 0xDFFF;
    pub const UTF8_ILLEGAL_OUT_OF_BOUNDS_BEGIN: u32 = 0x110000;

    fn create_text_mode_val_to_token_lookup_table() [TextTokenTag.TEXT_MODE_LOOKUP_ENUM_COUNT]TextToken {
        var table: [TextTokenTag.TEXT_MODE_LOOKUP_ENUM_COUNT]TextToken = undefined;
        table[TextTokenTag.E_BOLD_TOGGLE] = .{ .tag = TextTokenTag.BoldToggle, .payload = TextTokenPayload.BoldToggle };
        table[TextTokenTag.E_ITALIC_TOGGLE] = .{ .tag = TextTokenTag.ItalicToggle, .payload = TextTokenPayload.ItalicToggle };
        table[TextTokenTag.E_UNDERLINE_TOGGLE] = .{ .tag = TextTokenTag.UnderlineToggle, .payload = TextTokenPayload.UnderlineToggle };
        table[TextTokenTag.E_STRIKETHRU_TOGGLE] = .{ .tag = TextTokenTag.StrikethruToggle, .payload = TextTokenPayload.StrikethruToggle };
        table[TextTokenTag.E_SMALLCAPS_TOGGLE] = .{ .tag = TextTokenTag.SmallcapsToggle, .payload = TextTokenPayload.SmallcapsToggle };
        table[TextTokenTag.E_SUPERSCRIPT_ON] = .{ .tag = TextTokenTag.SuperScriptOn, .payload = TextTokenPayload.SuperScriptOn };
        table[TextTokenTag.E_SUBSCRIPT_ON] = .{ .tag = TextTokenTag.SubScriptOn, .payload = TextTokenPayload.SubScriptOn };
        table[TextTokenTag.E_SUPERSUB_OFF] = .{ .tag = TextTokenTag.SuperSubOff, .payload = TextTokenPayload.SuperSubOff };
        table[TextTokenTag.E_MONOSANS_ON] = .{ .tag = TextTokenTag.MonoSansOn, .payload = TextTokenPayload.MonoSansOn };
        table[TextTokenTag.E_MONOSERIF_ON] = .{ .tag = TextTokenTag.MonoSerifOn, .payload = TextTokenPayload.MonoSerifOn };
        table[TextTokenTag.E_HANDSIMPLE_ON] = .{ .tag = TextTokenTag.HandSimpleOn, .payload = TextTokenPayload.HandSimpleOn };
        table[TextTokenTag.E_HANDFANCY_ON] = .{ .tag = TextTokenTag.HandFancyOn, .payload = TextTokenPayload.HandFancyOn };
        table[TextTokenTag.E_NORMALSANS_ON] = .{ .tag = TextTokenTag.NormalSansOn, .payload = TextTokenPayload.NormalSansOn };
        table[TextTokenTag.E_NORMALSERIF_ON] = .{ .tag = TextTokenTag.NormalSerifOn, .payload = TextTokenPayload.NormalSerifOn };
        table[TextTokenTag.E_TEXTSTYLE_OFF] = .{ .tag = TextTokenTag.TextStyleOff, .payload = TextTokenPayload.TextStyleOff };
        table[TextTokenTag.E_COLOR_OFF] = .{ .tag = TextTokenTag.ColorOff, .payload = TextTokenPayload.ColorOff };
        table[TextTokenTag.E_OPACITY_OFF] = .{ .tag = TextTokenTag.OpacityOff, .payload = TextTokenPayload.OpacityOff };
        table[TextTokenTag.E_LINK_OFF] = .{ .tag = TextTokenTag.LinkOff, .payload = TextTokenPayload.LinkOff };
        table[TextTokenTag.E_TABLE_OFF] = .{ .tag = TextTokenTag.TableOff, .payload = TextTokenPayload.TableOff };
        table[TextTokenTag.E_COLUMNS_OFF] = .{ .tag = TextTokenTag.ColumnsOff, .payload = TextTokenPayload.ColumnsOff };
        table[TextTokenTag.E_HEADING_OFF] = .{ .tag = TextTokenTag.HeadingOff, .payload = TextTokenPayload.HeadingOff };
        table[TextTokenTag.E_SPECIFIC_FONT_OFF] = .{ .tag = TextTokenTag.SpecificFontOff, .payload = TextTokenPayload.SpecificFontOff };
        table[TextTokenTag.E_BG_COLOR_OFF] = .{ .tag = TextTokenTag.BgColorOff, .payload = TextTokenPayload.BgColorOff };
        table[TextTokenTag.E_BG_OPACITY_OFF] = .{ .tag = TextTokenTag.BgOpacityOff, .payload = TextTokenPayload.BgOpacityOff };
        table[TextTokenTag.E_FONT_SIZE_OFF] = .{ .tag = TextTokenTag.FontSizeOff, .payload = TextTokenPayload.FontSizeOff };
        table[TextTokenTag.E_ALIGN_OFF] = .{ .tag = TextTokenTag.AlignOff, .payload = TextTokenPayload.AlignOff };
        table[TextTokenTag.E_ANCHOR_OFF] = .{ .tag = TextTokenTag.AnchorOff, .payload = TextTokenPayload.AnchorOff };
        table[TextTokenTag.E_INVERT_COLOR] = .{ .tag = TextTokenTag.InvertColor, .payload = TextTokenPayload.InvertColor };
        table[TextTokenTag.E_PAGE_BREAK] = .{ .tag = TextTokenTag.PageBreak, .payload = TextTokenPayload.PageBreak };
        table[TextTokenTag.E_SCENE_BREAK] = .{ .tag = TextTokenTag.SceneBreak, .payload = TextTokenPayload.SceneBreak };
        table[TextTokenTag.E_LINE_BREAK] = .{ .tag = TextTokenTag.LineBreak, .payload = TextTokenPayload.LineBreak };
        table[TextTokenTag.E_CELL_BREAK] = .{ .tag = TextTokenTag.CellBreak, .payload = TextTokenPayload.CellBreak };
        return table;
    }

    const TEXT_MODE_VAL_TO_TOKEN_LOOKUP_TABLE = create_text_mode_val_to_token_lookup_table(TextTokenTag.TEXT_MODE_LOOKUP_ENUM_COUNT);

    inline fn val_to_token_extended_key_value(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.ExtendedKeyValue, .payload = .{ .ExtendedKeyValue = EmbedPosition.from_u128(val) } };
    }
    inline fn val_to_token_font_size_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.FontSizeOn, .payload = .{ .FontSizeOn = FontSize.from_u128(val) } };
    }
    inline fn val_to_token_color_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.ColorOn, .payload = .{ .ColorOn = Color.from_u128(val) } };
    }
    inline fn val_to_token_opacity_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.OpacityOn, .payload = .{ .OpacityOn = Opacity.from_u128(val) } };
    }
    inline fn val_to_token_align_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.AlignOn, .payload = .{ .AlignOn = Align.from_u128(val) } };
    }
    inline fn val_to_token_link_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.LinkOn, .payload = .{ .LinkOn = EmbedPosition.from_u128(val) } };
    }
    inline fn val_to_token_anchor_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.AnchorOn, .payload = .{ .AnchorOn = EmbedPosition.from_u128(val) } };
    }
    inline fn val_to_token_indent(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.Indent, .payload = .{ .Indent = IndentChange.from_u128(val) } };
    }
    inline fn val_to_token_list_indent(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.ListIndent, .payload = .{ .ListIndent = IndentChange.from_u128(val) } };
    }
    inline fn val_to_token_quote_indent(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.QuoteIndent, .payload = .{ .QuoteIndent = IndentChange.from_u128(val) } };
    }
    inline fn val_to_token_table_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.TableOn, .payload = .{ .TableOn = TableSize.from_u128(val) } };
    }
    inline fn val_to_token_columns_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.ColumnsOn, .payload = .{ .ColumnsOn = Columns.from_u128(val) } };
    }
    inline fn val_to_token_heading_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.HeadingOn, .payload = .{ .HeadingOn = Heading.from_u128(val) } };
    }
    inline fn val_to_token_font_embed_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.FontEmbedOn, .payload = .{ .FontEmbedOn = EmbedPosition.from_u128(val) } };
    }
    inline fn val_to_token_font_family_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.FontFamilyOn, .payload = .{ .FontFamilyOn = EmbedPosition.from_u128(val) } };
    }
    inline fn val_to_token_image_link(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.ImageLink, .payload = .{ .ImageLink = EmbedPosition.from_u128(val) } };
    }
    inline fn val_to_token_image_embed(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.ImageEmbed, .payload = .{ .ImageEmbed = EmbedPosition.from_u128(val) } };
    }
    inline fn val_to_token_bg_color_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.BgColorOn, .payload = .{ .BgColorOn = Color.from_u128(val) } };
    }
    inline fn val_to_token_bg_opacity_on(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.BgOpacityOn, .payload = .{ .BgOpacityOn = Opacity.from_u128(val) } };
    }
    inline fn val_to_token_list_type(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.ListType, .payload = .{ .ListType = ListType.from_u128(val) } };
    }
    inline fn val_to_token_utf8_escape(val: u128) TextToken {
        return TextToken{ .tag = TextTokenTag.UTF8Escape, .payload = .{ .UTF8Escape = @truncate(val) } };
    }
    fn create_kvp_val_to_token_lookup_table() [TextTokenTag.KVP_MODE_LOOKUP_KEY_COUNT]fn (val: u128) TextTokenPayload {
        var table: [TextTokenTag.KVP_MODE_LOOKUP_KEY_COUNT]fn (val: u128) TextTokenPayload = undefined;
        table[TextTokenTag.KEY_EXTENDED_KEY_VALUE] = val_to_token_extended_key_value;
        table[TextTokenTag.KEY_FONT_SIZE_ON] = val_to_token_font_size_on;
        table[TextTokenTag.KEY_COLOR_ON] = val_to_token_color_on;
        table[TextTokenTag.KEY_OPACITY_ON] = val_to_token_opacity_on;
        table[TextTokenTag.KEY_ALIGN_ON] = val_to_token_align_on;
        table[TextTokenTag.KEY_LINK_ON] = val_to_token_link_on;
        table[TextTokenTag.KEY_ANCHOR_ON] = val_to_token_anchor_on;
        table[TextTokenTag.KEY_INDENT] = val_to_token_indent;
        table[TextTokenTag.KEY_LIST_INDENT] = val_to_token_list_indent;
        table[TextTokenTag.KEY_QUOTE_INDENT] = val_to_token_quote_indent;
        table[TextTokenTag.KEY_TABLE_ON] = val_to_token_table_on;
        table[TextTokenTag.KEY_COLUMNS_ON] = val_to_token_columns_on;
        table[TextTokenTag.KEY_HEADING_ON] = val_to_token_heading_on;
        table[TextTokenTag.KEY_FONT_EMBED_ON] = val_to_token_font_embed_on;
        table[TextTokenTag.KEY_FONT_FAMILY_ON] = val_to_token_font_family_on;
        table[TextTokenTag.KEY_IMAGE_LINK] = val_to_token_image_link;
        table[TextTokenTag.KEY_IMAGE_EMBED] = val_to_token_image_embed;
        table[TextTokenTag.KEY_BG_COLOR_ON] = val_to_token_bg_color_on;
        table[TextTokenTag.KEY_BG_OPACITY_ON] = val_to_token_bg_opacity_on;
        table[TextTokenTag.KEY_LIST_TYPE] = val_to_token_list_type;
        table[TextTokenTag.KEY_UTF8_ESCAPE] = val_to_token_utf8_escape;
        return table;
    }
    const KVP_VAL_TO_TOKEN_LOOKUP_TABLE = create_kvp_val_to_token_lookup_table();

    inline fn combine_key_value_into_kvp(key: u128, value: u128) u128 {
        return ((value & KVP_HI_VAL_ENCODE_MASK) << KVP_HI_VAL_SHIFT) | KVP_UTF8_RANGE_GUARD | ((value & KVP_LOW_VAL_ENCODE_MASK) << KVP_LOW_VAL_SHIFT) | key;
    }
    inline fn token_to_val_bold_toggle(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_BOLD_TOGGLE;
    }
    inline fn token_to_val_italic_toggle(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_ITALIC_TOGGLE;
    }
    inline fn token_to_val_underline_toggle(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_UNDERLINE_TOGGLE;
    }
    inline fn token_to_val_strikethru_toggle(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_STRIKETHRU_TOGGLE;
    }
    inline fn token_to_val_smallcaps_toggle(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_SMALLCAPS_TOGGLE;
    }
    inline fn token_to_val_superscript_on(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_SUPERSCRIPT_ON;
    }
    inline fn token_to_val_subscript_on(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_SUBSCRIPT_ON;
    }
    inline fn token_to_val_supersub_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_SUPERSUB_OFF;
    }
    inline fn token_to_val_monosans_on(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_MONOSANS_ON;
    }
    inline fn token_to_val_monoserif_on(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_MONOSERIF_ON;
    }
    inline fn token_to_val_handsimple_on(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_HANDSIMPLE_ON;
    }
    inline fn token_to_val_handfancy_on(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_HANDFANCY_ON;
    }
    inline fn token_to_val_normalsans_on(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_NORMALSANS_ON;
    }
    inline fn token_to_val_normalserif_on(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_NORMALSERIF_ON;
    }
    inline fn token_to_val_textstyle_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_TEXTSTYLE_OFF;
    }
    inline fn token_to_val_color_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_COLOR_OFF;
    }
    inline fn token_to_val_opacity_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_OPACITY_OFF;
    }
    inline fn token_to_val_link_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_LINK_OFF;
    }
    inline fn token_to_val_table_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_TABLE_OFF;
    }
    inline fn token_to_val_columns_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_COLUMNS_OFF;
    }
    inline fn token_to_val_heading_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_HEADING_OFF;
    }
    inline fn token_to_val_specific_font_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_SPECIFIC_FONT_OFF;
    }
    inline fn token_to_val_bg_color_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_BG_COLOR_OFF;
    }
    inline fn token_to_val_bg_opacity_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_BG_OPACITY_OFF;
    }
    inline fn token_to_val_font_size_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_FONT_SIZE_OFF;
    }
    inline fn token_to_val_align_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_ALIGN_OFF;
    }
    inline fn token_to_val_anchor_off(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_ANCHOR_OFF;
    }
    inline fn token_to_val_invert_color(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_INVERT_COLOR;
    }
    inline fn token_to_val_page_break(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_PAGE_BREAK;
    }
    inline fn token_to_val_scene_break(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_SCENE_BREAK;
    }
    inline fn token_to_val_line_break(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_LINE_BREAK;
    }
    inline fn token_to_val_cell_break(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_CELL_BREAK;
    }
    inline fn token_to_val_utf8_codepoint(tok: TextToken) u128 {
        return @as(u128, tok.payload.UTF8CodePoint);
    }
    inline fn token_to_val_clear_all_formatting(tok: TextToken) u128 {
        _ = tok;
        return TextTokenTag.VAL_CLEAR_ALL_FORMATTING;
    }
    inline fn token_to_val_extended_kvp(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_EXTENDED_KEY_VALUE, tok.payload.ExtendedKeyValue.to_u128());
    }
    inline fn token_to_val_font_size_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_FONT_SIZE_ON, tok.payload.FontSizeOn.to_u128());
    }
    inline fn token_to_val_color_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_COLOR_ON, tok.payload.ColorOn.to_u128());
    }
    inline fn token_to_val_opacity_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_OPACITY_ON, tok.payload.OpacityOn.to_u128());
    }
    inline fn token_to_val_align_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_ALIGN_ON, tok.payload.AlignOn.to_u128());
    }
    inline fn token_to_val_link_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_LINK_ON, tok.payload.LinkOn.to_u128());
    }
    inline fn token_to_val_anchor_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_ANCHOR_ON, tok.payload.AnchorOn.to_u128());
    }
    inline fn token_to_val_indent(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_INDENT, tok.payload.Indent.to_u128());
    }
    inline fn token_to_val_list_indent(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_LIST_INDENT, tok.payload.ListIndent.to_u128());
    }
    inline fn token_to_val_quote_indent(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_QUOTE_INDENT, tok.payload.QuoteIndent.to_u128());
    }
    inline fn token_to_val_table_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_TABLE_ON, tok.payload.TableOn.to_u128());
    }
    inline fn token_to_val_columns_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_COLUMNS_ON, tok.payload.ColumnsOn.to_u128());
    }
    inline fn token_to_val_heading_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_HEADING_ON, tok.payload.HeadingOn.to_u128());
    }
    inline fn token_to_val_font_embed_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_FONT_EMBED_ON, tok.payload.FontEmbedOn.to_u128());
    }
    inline fn token_to_val_font_family_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_FONT_FAMILY_ON, tok.payload.FontFamilyOn.to_u128());
    }
    inline fn token_to_val_image_link(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_IMAGE_LINK, tok.payload.ImageLink.to_u128());
    }
    inline fn token_to_val_image_embed(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_IMAGE_EMBED, tok.payload.ImageEmbed.to_u128());
    }
    inline fn token_to_val_bg_color_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_BG_COLOR_ON, tok.payload.BgColorOn.to_u128());
    }
    inline fn token_to_val_bg_opacity_on(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_BG_OPACITY_ON, tok.payload.BgOpacityOn.to_u128());
    }
    inline fn token_to_val_list_type(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_LIST_TYPE, tok.payload.ListType.to_u128());
    }
    inline fn token_to_val_utf8_escape(tok: TextToken) u128 {
        return combine_key_value_into_kvp(TextTokenTag.KEY_UTF8_ESCAPE, @as(u128, tok.payload.UTF8Escape));
    }
    fn create_token_to_val_lookup_table() [TextTokenTag.ENCODABLE_ENUM_COUNT]fn (tok: TextToken) u128 {
        var table: [TextTokenTag.ENCODABLE_ENUM_COUNT]fn (tok: TextToken) u128 = undefined;
        table[TextTokenTag.E_BOLD_TOGGLE] = token_to_val_bold_toggle;
        table[TextTokenTag.E_ITALIC_TOGGLE] = token_to_val_italic_toggle;
        table[TextTokenTag.E_UNDERLINE_TOGGLE] = token_to_val_underline_toggle;
        table[TextTokenTag.E_STRIKETHRU_TOGGLE] = token_to_val_strikethru_toggle;
        table[TextTokenTag.E_SMALLCAPS_TOGGLE] = token_to_val_smallcaps_toggle;
        table[TextTokenTag.E_SUPERSCRIPT_ON] = token_to_val_superscript_on;
        table[TextTokenTag.E_SUBSCRIPT_ON] = token_to_val_subscript_on;
        table[TextTokenTag.E_SUPERSUB_OFF] = token_to_val_supersub_off;
        table[TextTokenTag.E_MONOSANS_ON] = token_to_val_monosans_on;
        table[TextTokenTag.E_MONOSERIF_ON] = token_to_val_monoserif_on;
        table[TextTokenTag.E_HANDSIMPLE_ON] = token_to_val_handsimple_on;
        table[TextTokenTag.E_HANDFANCY_ON] = token_to_val_handfancy_on;
        table[TextTokenTag.E_NORMALSANS_ON] = token_to_val_normalsans_on;
        table[TextTokenTag.E_NORMALSERIF_ON] = token_to_val_normalserif_on;
        table[TextTokenTag.E_TEXTSTYLE_OFF] = token_to_val_textstyle_off;
        table[TextTokenTag.E_COLOR_OFF] = token_to_val_color_off;
        table[TextTokenTag.E_OPACITY_OFF] = token_to_val_opacity_off;
        table[TextTokenTag.E_LINK_OFF] = token_to_val_link_off;
        table[TextTokenTag.E_TABLE_OFF] = token_to_val_table_off;
        table[TextTokenTag.E_COLUMNS_OFF] = token_to_val_columns_off;
        table[TextTokenTag.E_HEADING_OFF] = token_to_val_heading_off;
        table[TextTokenTag.E_SPECIFIC_FONT_OFF] = token_to_val_specific_font_off;
        table[TextTokenTag.E_BG_COLOR_OFF] = token_to_val_bg_color_off;
        table[TextTokenTag.E_BG_OPACITY_OFF] = token_to_val_bg_opacity_off;
        table[TextTokenTag.E_FONT_SIZE_OFF] = token_to_val_font_size_off;
        table[TextTokenTag.E_ALIGN_OFF] = token_to_val_align_off;
        table[TextTokenTag.E_ANCHOR_OFF] = token_to_val_anchor_off;
        table[TextTokenTag.E_INVERT_COLOR] = token_to_val_invert_color;
        table[TextTokenTag.E_PAGE_BREAK] = token_to_val_page_break;
        table[TextTokenTag.E_SCENE_BREAK] = token_to_val_scene_break;
        table[TextTokenTag.E_LINE_BREAK] = token_to_val_line_break;
        table[TextTokenTag.E_CELL_BREAK] = token_to_val_cell_break;
        table[TextTokenTag.E_UTF8_CODEPOINT] = token_to_val_utf8_codepoint;
        table[TextTokenTag.E_CLEAR_ALL_FORMATTING] = token_to_val_clear_all_formatting;
        table[TextTokenTag.E_EXTENDED_KEY_VALUE] = token_to_val_extended_kvp;
        table[TextTokenTag.E_FONT_SIZE_ON] = token_to_val_font_size_on;
        table[TextTokenTag.E_COLOR_ON] = token_to_val_color_on;
        table[TextTokenTag.E_OPACITY_ON] = token_to_val_opacity_on;
        table[TextTokenTag.E_ALIGN_ON] = token_to_val_align_on;
        table[TextTokenTag.E_LINK_ON] = token_to_val_link_on;
        table[TextTokenTag.E_ANCHOR_ON] = token_to_val_anchor_on;
        table[TextTokenTag.E_INDENT] = token_to_val_indent;
        table[TextTokenTag.E_LIST_INDENT] = token_to_val_list_indent;
        table[TextTokenTag.E_QUOTE_INDENT] = token_to_val_quote_indent;
        table[TextTokenTag.E_TABLE_ON] = token_to_val_table_on;
        table[TextTokenTag.E_COLUMNS_ON] = token_to_val_columns_on;
        table[TextTokenTag.E_HEADING_ON] = token_to_val_heading_on;
        table[TextTokenTag.E_FONT_EMBED_ON] = token_to_val_font_embed_on;
        table[TextTokenTag.E_FONT_FAMILY_ON] = token_to_val_font_family_on;
        table[TextTokenTag.E_IMAGE_LINK] = token_to_val_image_link;
        table[TextTokenTag.E_IMAGE_EMBED] = token_to_val_image_embed;
        table[TextTokenTag.E_BG_COLOR_ON] = token_to_val_bg_color_on;
        table[TextTokenTag.E_BG_OPACITY_ON] = token_to_val_bg_opacity_on;
        table[TextTokenTag.E_LIST_TYPE] = token_to_val_list_type;
        table[TextTokenTag.E_UTF8_ESCAPE] = token_to_val_utf8_escape;
        return table;
    }
    const TOKEN_TO_VAL_LOOKUP_TABLE = create_token_to_val_lookup_table();

    pub fn value_to_token(value: u128) TextToken {
        return if (value < TextTokenTag.TEXT_MODE_LOOKUP_ENUM_COUNT) {
            TEXT_MODE_VAL_TO_TOKEN_LOOKUP_TABLE[@as(usize, @truncate(value))];
        } else if (value < UTF8_A_LIMIT_HI or (value > UTF8_B_LIMIT_LO and value < UTF8_B_LIMIT_HI) or (value > UTF8_C_LIMIT_LO and value < UTF8_C_LIMIT_HI)) {
            TextToken{ .tag = TextTokenTag.UTF8CodePoint, .payload = .{ .UTF8CodePoint = @as(u32, @truncate(value)) } };
        } else if (value == TextTokenTag.VAL_CLEAR_ALL_FORMATTING) {
            TextToken{ .tag = TextTokenTag.ClearAllFormatting, .payload = .{ .ClearAllFormating = void } };
        } else if (value & KVP_UTF8_RANGE_GUARD == KVP_UTF8_RANGE_GUARD) {
            const key: u8 = @truncate(value & KVP_KEY_MASK);
            const val: u128 = ((value & KVP_HI_VAL_DECODE_MASK) >> KVP_HI_VAL_SHIFT) | ((value & KVP_LOW_VAL_DECODE_MASK) >> KVP_LOW_VAL_SHIFT);
            if (key < TextTokenTag.KVP_MODE_LOOKUP_KEY_COUNT) {
                KVP_VAL_TO_TOKEN_LOOKUP_TABLE[key](val);
            } else TextToken{ .tag = TextTokenTag.Ignore, .payload = .{ .Ignore = void } };
        } else TextToken{ .tag = TextTokenTag.Ignore, .payload = .{ .Ignore = void } };
    }

    pub fn token_to_value(token: TextToken) u128 {
        const enum_key = @intFromEnum(token.tag);
        assert(enum_key < TextTokenTag.ENCODABLE_ENUM_COUNT);
        return TOKEN_TO_VAL_LOOKUP_TABLE[enum_key](token);
    }
};
