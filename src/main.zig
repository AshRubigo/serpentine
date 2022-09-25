// 2022-08-02-04-51-07

const std = @import("std");
const clap = @import("clap");
const zigstr = @import("zigstr");
const ziglyph = @import("ziglyph");

// TODO Test these ascii codes on Linux.
// TODO Need to put this in the `AsciiCodes` struct. How to access within the struct?
const ascii_escape = "\x1b";

const AsciiCodes = struct {
    reset: []const u8,
    bold: []const u8,

    character_set_decimal_line_drawing: []const u8,
    character_set_ansii: []const u8,

    background_black: []const u8,
    background_red: []const u8,
    background_green: []const u8,
    background_yellow: []const u8,
    background_blue: []const u8,
    background_purple: []const u8,
    background_cyan: []const u8,
    background_white: []const u8,

    foreground_black: []const u8,
    foreground_red: []const u8,
    foreground_green: []const u8,
    foreground_yellow: []const u8,
    foreground_blue: []const u8,
    foreground_purple: []const u8,
    foreground_cyan: []const u8,
    foreground_white: []const u8,

    box_top_left: []const u8,
    box_top_right: []const u8,
    box_bottom_left: []const u8,
    box_bottom_right: []const u8,
    box_horizontal: []const u8,
    box_vertical: []const u8,
    box_t_right: []const u8,
    box_t_left: []const u8,
    box_t_top: []const u8,
    box_t_bottom: []const u8,
    box_cross: []const u8,
};

// Doesn't include them all, not all may be necessary for debugging purposes.
// Retrieved from https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences.
const ascii_codes = AsciiCodes{
    .reset = ascii_escape ++ "[0m",
    .bold = ascii_escape ++ "[1m",

    .character_set_decimal_line_drawing = ascii_escape ++ "(0",
    .character_set_ansii = ascii_escape ++ "(B",

    .background_black = ascii_escape ++ "[40m",
    .background_red = ascii_escape ++ "[41m",
    .background_green = ascii_escape ++ "[42m",
    .background_yellow = ascii_escape ++ "[43m",
    .background_blue = ascii_escape ++ "[44m",
    .background_purple = ascii_escape ++ "[45m",
    .background_cyan = ascii_escape ++ "[46m",
    .background_white = ascii_escape ++ "[47m",

    .foreground_black = ascii_escape ++ "[30m",
    .foreground_red = ascii_escape ++ "[31m",
    .foreground_green = ascii_escape ++ "[32m",
    .foreground_yellow = ascii_escape ++ "[33m",
    .foreground_blue = ascii_escape ++ "[34m",
    .foreground_purple = ascii_escape ++ "[35m",
    .foreground_cyan = ascii_escape ++ "[36m",
    .foreground_white = ascii_escape ++ "[37m",

    .box_top_left = "l",
    .box_top_right = "k",
    .box_bottom_left = "m",
    .box_bottom_right = "j",
    .box_horizontal = "q",
    .box_vertical = "x",
    .box_t_right = "t",
    .box_t_left = "u",
    .box_t_top = "w",
    .box_t_bottom = "v",
    .box_cross = "n",
};

fn widthConsoleScreenBuffer() !usize {
    var terminal = std.io.getStdErr();

    var info: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;

    _ = std.os.windows.kernel32.GetConsoleScreenBufferInfo(
        terminal.handle,
        &info,
    );

    try std.testing.expect(info.dwSize.X >= 0);

    return @intCast(
        usize,
        info.dwSize.X,
    );
}

// Print utility struct.
const Print = struct {
    _level: usize = 0,

    // Indent. Do this at the start of functions and defer P.o() to outdent.
    fn i(self: *Print) void {
        self._level += 2;
    }

    // Outdent.
    fn o(self: *Print) void {
        self._level -= 2;
    }

    // Convenience function for enabling and disabling the decimal line drawing character set.
    fn characterSetDecimalLineDrawing(
        allocator: std.mem.Allocator,
        comptime message: []const u8,
        args: anytype,
    ) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            ascii_codes.character_set_decimal_line_drawing ++ message ++ ascii_codes.character_set_ansii,
            args,
        );
    }

    fn lenLineMax(
        self: *Print,
        allocator: std.mem.Allocator,
        message_formatted: zigstr,
        border: usize,
    ) !usize {
        // Tokenize the formatted message by newlines.
        var iter_message_formatted = message_formatted.lineIter();

        var len_line_max: usize = 0;

        var message_line = try zigstr.fromBytes(
            allocator,
            "",
        );
        defer message_line.deinit();

        // TODO This only works for UTF-8, it does not understand terminal specific escape sequences.
        //
        // For every line of the message.
        while (iter_message_formatted.next()) |iter| {
            try message_line.reset(iter);
            const iter_len = try message_line.graphemeCount();

            // Update the length of the longest line.
            if (iter_len > len_line_max) {
                len_line_max = iter_len;
            }
        }

        const width_console_screen_buffer = try widthConsoleScreenBuffer();

        try std.testing.expect(width_console_screen_buffer - self._level - border >= 0);

        const len_line_max_console = width_console_screen_buffer - self._level - border;

        if (len_line_max > len_line_max_console) len_line_max = len_line_max_console;

        return len_line_max;
    }

    fn boxLeft(
        allocator: std.mem.Allocator,
        spaces: []const u8,
    ) ![]const u8 {
        var box = try zigstr.fromBytes(
            allocator,
            "",
        );
        errdefer box.deinit();

        try box.concat(spaces);
        try box.concat(
            try characterSetDecimalLineDrawing(
                allocator,
                ascii_codes.box_vertical,
                .{},
            ),
        );
        try box.concat(" ");

        return box.toOwnedSlice();
    }

    fn boxRight(allocator: std.mem.Allocator) ![]const u8 {
        var box = try zigstr.fromBytes(
            allocator,
            "",
        );
        errdefer box.deinit();

        try box.concat(" ");
        try box.concat(
            try characterSetDecimalLineDrawing(
                allocator,
                ascii_codes.box_vertical,
                .{},
            ),
        );
        try box.concat("\n");

        return box.toOwnedSlice();
    }

    fn padding(
        allocator: std.mem.Allocator,
        len_line: usize,
        len_line_max: usize,
    ) ![]const u8 {
        var return_padding = try zigstr.fromBytes(
            allocator,
            "",
        );
        errdefer return_padding.deinit();

        // Add padding spaces between the text and the right box line so all the lines are the same length.
        var n: usize = len_line_max - len_line;

        while (n != 0) : (n -= 1) {
            try return_padding.concat(" ");
        }

        return return_padding.toOwnedSlice();
    }

    fn concatLineWrapped(
        allocator: std.mem.Allocator,
        message_new: *zigstr,
        line_wrapped: *zigstr,
        len_line_max: usize,
        prepend: []const u8,
        append: []const u8,
    ) !void {
        try message_new.concat(prepend);

        try message_new.concat(line_wrapped.bytes.items);

        const count_grapheme_line_wrapped: usize = try line_wrapped.graphemeCount();

        // If the length of the wrapped line is less than the max line length.
        // If the wrapped line doesn't fill the max line length.
        if (count_grapheme_line_wrapped < len_line_max) {
            try message_new.concat(
                padding(
                    allocator,
                    message_new,
                    count_grapheme_line_wrapped,
                    len_line_max,
                ),
            );
        }

        try message_new.concat(append);
    }

    // Note: The word will start on a new line, but might not end on a new line.
    fn concatLineByGrapheme(
        allocator: std.mem.Allocator,
        message_new: *zigstr,
        line_wrapped: *zigstr,
        indentation: *zigstr,
        len_line_max: usize,
        word_next_null: bool,
        line_next_null: bool,
    ) !void {
        try std.testing.expect(line_wrapped.bytes.items.len > 0);

        // Graphemes.
        var iter_grapheme = try ziglyph.Grapheme.GraphemeIterator.init(line_wrapped.bytes.items);

        var line_wrapped_grapheme = try zigstr.fromBytes(
            allocator,
            "",
        );
        defer line_wrapped_grapheme.deinit();

        var count_i: usize = 1;

        // For every grapheme of the line.
        while (iter_grapheme.next()) |grapheme| : (count_i += 1) {
            try line_wrapped_grapheme.concat(grapheme.bytes);

            var iter_grapheme_next = iter_grapheme;

            // If we have reached the max line length.
            if (count_i + (try indentation.graphemeCount()) == len_line_max) {
                count_i = 0;

                try message_new.concat(indentation.bytes.items);

                try message_new.concat(line_wrapped_grapheme.bytes.items);

                if (word_next_null and !line_next_null) try message_new.concat("\n");

                // If there is no next grapheme.
                if (iter_grapheme_next.next() == null) {
                    // This wrapped line is full, so we can reset it and the spaces hit.
                    try line_wrapped.reset("");
                } else {
                    try line_wrapped_grapheme.reset("");
                }
            }
            // If there is no next grapheme.
            else if (iter_grapheme_next.next() == null) {
                // If there are no more words on this line.
                if (word_next_null) {
                    try message_new.concat(indentation.bytes.items);

                    try message_new.concat(line_wrapped_grapheme.bytes.items);

                    if (!line_next_null) try message_new.concat("\n");

                    try line_wrapped.reset("");
                }
                // If there are more words on this line.
                else {
                    // There are words after the last part of this word, so if the last part of this word doesn't fill the max line length should be concatenated to message_line_wrapped and the loop should continue as normal.
                    try resetNormalWordToLineWrapped(
                        line_wrapped,
                        &line_wrapped_grapheme,
                    );
                }
            }
        }
    }

    // Concatenate a normal word to the wrapped line.
    fn concatNormalWordToLineWrapped(
        line_wrapped: *zigstr,
        word_normal: *zigstr,
    ) !void {
        try line_wrapped.concat(word_normal.bytes.items);
    }

    // Concatenate a normal word to the wrapped line.
    fn resetNormalWordToLineWrapped(
        line_wrapped: *zigstr,
        word_normal: *zigstr,
    ) !void {
        try line_wrapped.reset(word_normal.bytes.items);
    }

    // Concatenate the wrapped line to the new message.
    fn concatLineWrappedToMessageNew(
        allocator: std.mem.Allocator,
        message_new: *zigstr,
        line_wrapped: *zigstr,
        indentation: *zigstr,
        len_line_max: usize,
        word_next_null: bool,
        line_next_null: bool,
    ) !void {
        // If the wrapped line fits in the console.
        if ((try line_wrapped.graphemeCount()) <= len_line_max) {
            try message_new.concat(indentation.bytes.items);

            try message_new.concat(line_wrapped.bytes.items);

            if (!line_next_null) try message_new.concat("\n");

            try line_wrapped.reset("");
        }
        // If the wrapped line doesn't fit in the console, this means it only has one word, but that word is longer than the console width.
        else {
            try concatLineByGrapheme(
                allocator,
                message_new,
                line_wrapped,
                indentation,
                len_line_max,
                word_next_null,
                line_next_null,
            );
        }
    }

    // Expects:
    // - a non-empty normal word.
    //
    // Results:
    // - an empty or non-empty wrapped line.
    // - an empty normal word.
    fn wrapUtil(
        allocator: std.mem.Allocator,
        message_new: *zigstr,
        line_wrapped: *zigstr,
        word_normal: *zigstr,
        indentation: *zigstr,
        len_line_max: usize,
        first_word: bool,
        word_next_null: bool,
        line_next_null: bool,
    ) !void {
        try std.testing.expect(word_normal.bytes.items.len > 0);

        // The length of the current line if the next word would be concatenated, notwithstanding indentation or box.
        var len_line: usize = (try indentation.graphemeCount()) + (try line_wrapped.graphemeCount()) + (try word_normal.graphemeCount());

        // If the wrapped line and the word plus a space fits in the console.
        if (!first_word and len_line + 1 + (try indentation.graphemeCount()) <= len_line_max) {
            try line_wrapped.concat(" ");

            try concatNormalWordToLineWrapped(
                line_wrapped,
                word_normal,
            );
        }
        // If the wrapped line and the word fits in the console.
        else if (first_word and len_line + (try indentation.graphemeCount()) <= len_line_max) {
            try concatNormalWordToLineWrapped(
                line_wrapped,
                word_normal,
            );
        }
        // If the wrapped line and the word doesn't fit in the console.
        else {
            // If the wrapped line is not empty.
            if (line_wrapped.bytes.items.len != 0) {
                try concatLineWrappedToMessageNew(
                    allocator,
                    message_new,
                    line_wrapped,
                    indentation,
                    len_line_max,
                    word_next_null,
                    line_next_null,
                );
            }

            try resetNormalWordToLineWrapped(
                line_wrapped,
                word_normal,
            );
        }

        // We are done with this word. The loop will start constructing a new word now.
        try word_normal.reset("");
    }

    // - Input must be UTF-8 only.
    // - Trims spaces at the end of each line.
    // - Multiple spaces between words are reduced to 1 space.
    // - Spaces between words that have been separated onto different lines by wrapping are removed.
    // - Preserves spaces at the start of each line. These spaces are considered indentations and will be prepended to wrapped lines.
    // - Indentations are considered part of the first word of each line, which is revelant to wrapping.
    // - Can handle words longer than the max width will allow.
    fn wrap(
        allocator: std.mem.Allocator,
        message_formatted: *zigstr,
        len_line_max: usize,
    ) ![]const u8 {
        try std.testing.expect(message_formatted.bytes.items.len > 0);

        // Stores the string that this function will return.
        var message_new = try zigstr.fromBytes(
            allocator,
            "",
        );
        errdefer message_new.deinit();

        // Each input line might be longer that the console, so will need wrapping. This holds each wrapped line as they are created.
        var line_wrapped = try zigstr.fromBytes(
            allocator,
            "",
        );
        defer line_wrapped.deinit();

        // This is just for a function from zigstr that is useful.
        var word_unicode = try zigstr.fromBytes(
            allocator,
            "",
        );
        defer word_unicode.deinit();

        // This holds each word of each line. Words are separated by spaces and might contain punctuation. This is different from the unicode idea of a word.
        var word_normal = try zigstr.fromBytes(
            allocator,
            "",
        );
        defer word_normal.deinit();

        var indentation = try zigstr.fromBytes(
            allocator,
            "",
        );
        errdefer indentation.deinit();

        // This will store each line of the input string.
        var line_raw = try zigstr.fromBytes(
            allocator,
            "",
        );
        defer line_raw.deinit();

        // Tokenize the formatted message by newlines.
        var iter_lines_raw = message_formatted.lineIter();

        // For every line of the message.
        while (iter_lines_raw.next()) |line_raw_temp| {
            try line_raw.reset(line_raw_temp);
            try indentation.reset("");

            try line_raw.trimRight(" ");

            var iter_lines_raw_next = iter_lines_raw;

            var first_word = true;
            var line_start = true;
            const line_next_null = iter_lines_raw_next.next() == null;

            // If the entire line is blank.
            // No need to bother with all the logic.
            if (try line_raw.isBlank()) {
                try std.testing.expect(line_wrapped.bytes.items.len == 0);

                if (!line_next_null) {
                    if (len_line_max != 0) {
                        try message_new.concat(try padding(allocator, 0, len_line_max));
                    }

                    if (!line_next_null) try message_new.concat("\n");
                }
            }
            // If the entire line isn't blank.
            else {
                try std.testing.expect(try line_wrapped.isBlank());
                try std.testing.expect(try word_normal.isBlank());

                // Unicode words.
                var iter_words_unicode = try ziglyph.Word.WordIterator.init(line_raw_temp);

                // For every word of the line.
                //
                // We are doing 3 things here:
                // - Concatenating to the word. Expects a non empty unicode word.
                // - Concatenating to the wrapped line. Expects a non empty normal word.
                // - Concatenating to the new message. Expects a wrapped line.
                while (iter_words_unicode.next()) |word_unicode_temp| {
                    try word_unicode.reset(word_unicode_temp.bytes);

                    var iter_word_next = iter_words_unicode;

                    // Whether the current unicode word only contains spaces.
                    const word_unicode_blank = try word_unicode.isBlank();
                    // Whether the next unicode word is null.
                    const word_next_null = iter_word_next.next() == null;

                    // If this unicode word is just spaces.
                    // Note: Because we trimmed each line, we know the next unicode word cannot be null if this one is spaces.
                    if (word_unicode_blank) {
                        // If we have not hit normal word character.
                        if (line_start) {
                            try indentation.concat(word_unicode_temp.bytes);
                        }
                        // If we have hit a normal word character.
                        else {
                            try wrapUtil(
                                allocator,
                                &message_new,
                                &line_wrapped,
                                &word_normal,
                                &indentation,
                                len_line_max,
                                first_word,
                                word_next_null,
                                line_next_null,
                            );

                            // If the next word is null, we need to do this here, because there won't be another iteration for this to happen.
                            if (!(try line_wrapped.isBlank()) and word_next_null) {
                                try concatLineWrappedToMessageNew(
                                    allocator,
                                    &message_new,
                                    &line_wrapped,
                                    &indentation,
                                    len_line_max,
                                    word_next_null,
                                    line_next_null,
                                );

                                try std.testing.expect((try line_wrapped.isBlank()));
                            }

                            if (first_word) first_word = false;
                        }
                    }
                    // If this 'word' is not just spaces.
                    else {
                        // Construct a word.
                        try word_normal.concat(word_unicode_temp.bytes);

                        line_start = false;

                        // If the next word is null, we need to do this here, because there won't be another iteration for this to happen.
                        if (word_next_null) {
                            // If there are no other words in the wrapped line.
                            if (line_wrapped.bytes.items.len == 0) {
                                try concatNormalWordToLineWrapped(
                                    &line_wrapped,
                                    &word_normal,
                                );
                            }
                            // If there are already words in the wrapped line.
                            else {
                                try wrapUtil(
                                    allocator,
                                    &message_new,
                                    &line_wrapped,
                                    &word_normal,
                                    &indentation,
                                    len_line_max,
                                    first_word,
                                    word_next_null,
                                    line_next_null,
                                );
                            }

                            try concatLineWrappedToMessageNew(
                                allocator,
                                &message_new,
                                &line_wrapped,
                                &indentation,
                                len_line_max,
                                word_next_null,
                                line_next_null,
                            );

                            try word_normal.reset("");

                            try std.testing.expect(line_wrapped.bytes.items.len == 0);
                        }
                    }
                }
            }
        }

        // If message_new is empty at this point, an integer overflow occurs in message_new.insert(), not sure why, but it shouldn't be empty anyway.
        try std.testing.expect(message_new.bytes.items.len > 0);

        // Return the entire message.
        return try message_new.toOwnedSlice();
    }

    // Surround the input text in a box, where the width of the box is as large as the console will allow.
    //
    // // Example:
    // ```
    // Input:
    // surroundBoxMax(
    //   \\Hi
    //   \\World.
    //   ,.{});
    //
    // Output:
    // ┌─────────────┐// Console width.
    // │ Hi          │//
    // │ World.      │//
    // └─────────────┘//
    // ```
    fn surroundBoxMax(
        self: *Print,
        allocator: std.mem.Allocator,
        comptime message: []const u8,
        args: anytype,
    ) ![]const u8 {
        // Format the message so we can get the true length, and convert it to a more useful string.
        var message_formatted = try zigstr.fromBytes(
            allocator,
            try std.fmt.allocPrint(
                allocator,
                message,
                args,
            ),
        );
        defer message_formatted.deinit();

        const len_border: usize = 4;

        return try self.indentBox(
            allocator,
            &message_formatted,
            (try widthConsoleScreenBuffer()) - len_border - self._level,
        );
    }

    // Example:
    // ```
    // Input:
    // surroundBoxFit(
    //   \\Hi
    //   \\World.
    //   ,.{});
    //
    // Output:
    // ┌────────┐     // Console width.
    // │ Hi     │     //
    // │ World. │     //
    // └────────┘     //
    // ```
    fn surroundBoxFit(
        self: *Print,
        allocator: std.mem.Allocator,
        comptime message: []const u8,
        args: anytype,
    ) ![]const u8 {
        // Format the message so we can get the true length, and convert it to a more useful string.
        var message_formatted = try zigstr.fromBytes(
            allocator,
            try std.fmt.allocPrint(
                allocator,
                message,
                args,
            ),
        );
        defer message_formatted.deinit();

        return try self.indentBox(
            allocator,
            &message_formatted,
            try self.lenLineMax(
                allocator,
                message_formatted,
                4,
            ),
        );
    }

    fn generateSpaces(
        self: *Print,
        allocator: std.mem.Allocator,
        extra: usize,
    ) ![]const u8 {
        var string_spaces = try zigstr.fromBytes(
            allocator,
            " ",
        );
        defer string_spaces.deinit();

        // Repeat the spaces by the number of indentations required.
        try string_spaces.repeat(self._level + extra);

        return try string_spaces.toOwnedSlice();
    }

    // Indent using spaces, each indentation is 2 spaces.
    fn indent(
        self: *Print,
        allocator: std.mem.Allocator,
        comptime message: []const u8,
        args: anytype,
    ) ![]const u8 {
        // Format the message so we can get the true length, and convert it to a more useful string.
        var message_formatted = try zigstr.fromBytes(
            allocator,
            try std.fmt.allocPrint(
                allocator,
                message,
                args,
            ),
        );
        defer message_formatted.deinit();

        var message_wrapped = try zigstr.fromBytes(
            allocator,
            try wrap(
                allocator,
                &message_formatted,
                try self.lenLineMax(
                    allocator,
                    message_formatted,
                    0,
                ),
            ),
        );
        defer message_wrapped.deinit();

        var message_new = try zigstr.fromBytes(
            allocator,
            "",
        );
        errdefer message_new.deinit();

        const spaces = try self.generateSpaces(
            allocator,
            2,
        );

        // Tokenize the formatted message by newlines.
        var iter_lines = message_wrapped.lineIter();

        // For every line of the message.
        while (iter_lines.next()) |line| {
            var iter_lines_next = iter_lines;

            // If there is no next line.
            //
            // TODO Not sure why this is necessary. Maybe something to do with the way zigstr splits the lines.
            if (iter_lines_next.next() != null) {
                try message_new.concat(spaces);

                try message_new.concat(line);

                try message_new.concat("\n");
            }
        }

        return message_new.toOwnedSlice();
    }

    // TODO Why is the decimal line drawing character set necessary? Windows Terminal seems to understand the raw characters, is it something on the Zig side? Isn't ASCII a subset of UTF-8?
    //
    // Return the input of a single or multiline string surrounded by a box, which can then be printed.
    // Utilizes the decimal line drawing character set for the box characters.
    //
    // A limitation of this is that the line length count does not account for the ascii escape characters for the terminal perfectly, so the input is restricted to multiline strings of UTF-8 characters and zig string escapes. This means the result of this function cannot be fed into the function.
    fn indentBox(
        self: *Print,
        allocator: std.mem.Allocator,
        message_formatted: *zigstr,
        len_line_max: usize,
    ) ![]const u8 {
        var message_wrapped = try zigstr.fromBytes(
            allocator,
            try wrap(
                allocator,
                message_formatted,
                len_line_max,
            ),
        );
        errdefer message_wrapped.deinit();

        var message_new = try zigstr.fromBytes(
            allocator,
            "",
        );
        errdefer message_new.deinit();

        const spaces = try self.generateSpaces(
            allocator,
            0,
        );

        // Tokenize the new message by newlines.
        var iter_lines = message_wrapped.lineIter();

        // For every line of the message.
        while (iter_lines.next()) |line| {
            try message_new.concat(
                try boxLeft(
                    allocator,
                    spaces,
                ),
            );

            try message_new.concat(line);

            try message_new.concat(
                try padding(
                    allocator,
                    line.len,
                    len_line_max,
                ),
            );

            try message_new.concat(
                try boxRight(allocator),
            );
        }

        // Add the left corners.
        try message_new.insert(
            spaces,
            0,
        );
        try message_new.insert(
            ascii_codes.character_set_decimal_line_drawing ++ ascii_codes.box_top_left,
            self._level,
        );
        try message_new.concat(spaces);
        try message_new.concat(ascii_codes.character_set_decimal_line_drawing ++ ascii_codes.box_bottom_left);

        const len_top_left = ascii_codes.character_set_decimal_line_drawing.len + ascii_codes.box_top_left.len;

        var j = len_top_left + self._level;

        // Create the horizontal borders.
        //
        // Messages are variable in length, so this also needs to be.
        while (j < (len_line_max + len_top_left + 2 + self._level)) : (j += 1) {
            try message_new.insert(
                ascii_codes.box_horizontal,
                j,
            );
            try message_new.concat(ascii_codes.box_horizontal);
        }

        // Add the right corners.
        try message_new.insert(
            ascii_codes.box_top_right ++ ascii_codes.character_set_ansii ++ "\n",
            j,
        );
        try message_new.concat(
            ascii_codes.box_bottom_right ++ ascii_codes.character_set_ansii ++ "\n",
        );

        return try message_new.toOwnedSlice();
    }

    // TODO make box max width of terminal, while accounting for indentations
    //
    // Debug printing utility.
    fn heading(
        self: *Print,
        comptime message: []const u8,
        args: anytype,
    ) !void {
        // Memory allocator.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // TODO Get coloured background to output as expected.

        const surrounded = try self.surroundBoxMax(
            arena_allocator,
            message,
            args,
        );
        //const indented: []const u8 = try self.indent(arena_allocator, "{s}", .{surrounded});

        std.debug.print(
            "{s}",
            .{surrounded},
        );
    }

    // Debug printing utility.
    fn normal(
        self: *Print,
        comptime message: []const u8,
        args: anytype,
    ) !void {
        // Memory allocator.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // TODO Account for max width of the console so wrapping is properly wrapped.

        const indented = try self.indent(
            arena_allocator,
            message ++ "\n",
            args,
        );

        std.debug.print(
            "{s}",
            .{indented},
        );
    }

    // Useful for ascii art.
    // Just prepends indentation spaces to to the front of each line, does not do any wrapping.
    fn dumbUtil(
        allocator: std.mem.Allocator,
        message_formatted: *zigstr,
        spaces: []const u8,
    ) ![]const u8 {
        var message_new = try zigstr.fromBytes(
            allocator,
            "",
        );
        errdefer message_new.deinit();

        // Tokenize the formatted message by newlines.
        var iter_lines = message_formatted.lineIter();

        // For every line of the message.
        while (iter_lines.next()) |line| {
            try message_new.concat(spaces);

            try message_new.concat(line);

            try message_new.concat("\n");
        }

        return message_new.toOwnedSlice();
    }

    // Useful for ascii art.
    // Just prepends indentation spaces to to the front of each line, does not do any wrapping.
    fn dumbCentred(
        self: *Print,
        comptime message: []const u8,
        args: anytype,
    ) !void {
        // Memory allocator.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        // Format the message so we can get the true length, and convert it to a more useful string.
        var message_formatted = try zigstr.fromBytes(
            allocator,
            try std.fmt.allocPrint(
                allocator,
                message,
                args,
            ),
        );
        defer message_formatted.deinit();

        const len_line_max = try self.lenLineMax(
            allocator,
            message_formatted,
            0,
        );

        var spaces = try zigstr.fromBytes(
            allocator,
            " ",
        );
        defer spaces.deinit();

        // Repeat the spaces by the number of indentations required.
        try spaces.repeat(((try widthConsoleScreenBuffer()) - len_line_max) / 2);

        var dumbed = try dumbUtil(
            allocator,
            &message_formatted,
            spaces.bytes.items,
        );

        std.debug.print(
            "{s}",
            .{dumbed},
        );
    }

    // Useful for ascii art.
    // Just prepends indentation spaces to to the front of each line, does not do any wrapping.
    fn dumb(
        self: *Print,
        comptime message: []const u8,
        args: anytype,
    ) !void {
        // Memory allocator.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        // Format the message so we can get the true length, and convert it to a more useful string.
        var message_formatted = try zigstr.fromBytes(
            allocator,
            try std.fmt.allocPrint(
                allocator,
                message,
                args,
            ),
        );
        defer message_formatted.deinit();

        var dumbed = try dumbUtil(
            allocator,
            &message_formatted,
            try self.generateSpaces(
                allocator,
                0,
            ),
        );

        std.debug.print(
            "{s}",
            .{dumbed},
        );
    }
};

var p = Print{};

fn manageArguments() !void {
    // Specify what parameters our program can take.
    // Can use `parseParamsComptime` to parse a string into an array of `Param(Help)`.
    //
    // Short arguments must be only 1 letter long.
    //
    // TODO Print this when `-h` is used.
    const params =
        comptime clap.parseParamsComptime(
        \\-h, --help                   Display this help and exit.
        \\-n, --test-number <usize>    An option parameter, which takes a value.
        \\-s, --test-string <str>...   An option parameter which can be specified multiple times.
        \\<str>...
        \\
    );

    // Initalise diagnostics, which can be used for reporting useful errors.
    // This is optional. `.{}` can also be passed to `clap.parse` if we don't care about the extra information `Diagnostics` provides.
    var clap_diagnostic = clap.Diagnostic{};

    var arguments =
        clap.parse(
        clap.Help,
        &params,
        clap.parsers.default,
        .{ .diagnostic = &clap_diagnostic },
    ) catch |err| {
        // Report useful error and exit.
        clap_diagnostic.report(
            std.io.getStdErr().writer(),
            err,
        ) catch {};

        return err;
    };
    defer arguments.deinit();

    if (arguments.args.help)
        try p.normal(
            \\NAME
            \\    Serpentine
            \\
            \\SYNOPSIS
            \\    TODO
        ,
            .{},
        );

    if (arguments.args.@"test-number") |test_number|
        try p.normal(
            "Test number = {d}.",
            .{test_number},
        );

    for (arguments.args.@"test-string") |test_string|
        try p.normal(
            "Test string = {s}.",
            .{test_string},
        );

    for (arguments.positionals) |positionals|
        try p.normal(
            "{s}",
            .{positionals},
        );
}

pub fn main() !void {
    try p.dumbCentred(
        \\                                _
        \\ ___      _ __        ___      | |_ _ _ __
        \\/ __| ___| '__| ___  / _ \_ __ | __(_) '_ \  ___
        \\\__ \/ _ \ | | '_  \|  __/ '_ \| |_| | | | |/ _ \
        \\|___/  __/_| | |_)  |\___| | | |___| |_| |_|  __/
        \\     \___|   | .___/     |_| |_|   |_|      \___|
        \\             |_|                           __
        \\|\      _____      ______      _____      / o\__/
        \\| \____/ ___ \____/ ____ \____/ ___ \____/ __/  \
        \\ \______/   \______/    \______/   \______/
        \\
    ,
        .{},
    );

    try p.heading(
        "Serpentine start.",
        .{},
    );

    try manageArguments();

    try p.heading(
        "Serpentine end.",
        .{},
    );
}

test "surround box" {
    // Memory allocator.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    try std.testing.expect(
        try p.surroundBoxFit(
            arena_allocator,
            \\Surround
            \\box.
        ,
            .{},
        ) ==
            \\┌──────────┐
            \\│ Surround │
            \\│ box.     │
            \\└──────────┘
        ,
    );
}
