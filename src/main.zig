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

fn widthConsoleScreenBuffer() usize {
    var terminal: std.fs.File = std.io.getStdErr();

    var info: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;

    _ = std.os.windows.kernel32.GetConsoleScreenBufferInfo(terminal.handle, &info);

    return @intCast(usize, info.dwSize.X);
}

// Print utility struct.
const P = struct {
    _level: usize = 0,

    // Indent. Do this at the start of functions and defer P.o() to outdent.
    fn i(self: *P) void {
        self._level += 2;
    }

    // Outdent.
    fn o(self: *P) void {
        self._level -= 2;
    }

    // Convenience function for enabling and disabling the decimal line drawing character set.
    fn characterSetDecimalLineDrawing(allocator: std.mem.Allocator, comptime message: []const u8, args: anytype) ![]const u8 {
        return try std.fmt.allocPrint(allocator, ascii_codes.character_set_decimal_line_drawing ++ message ++ ascii_codes.character_set_ansii, args);
    }

    fn lenLineMax(self: *P, allocator: std.mem.Allocator, message_formatted: zigstr, padding: usize) !usize {
        // Tokenize the formatted message by newlines.
        var iter_message_formatted = message_formatted.lineIter();

        var len_line_max: usize = 0;

        var message_line = try zigstr.fromBytes(allocator, "");
        defer message_line.deinit();

        // TODO This should only count combining or visible characters. That may involve accounting for specific terminals.
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

        const width_console_screen_buffer = widthConsoleScreenBuffer();

        if (len_line_max > width_console_screen_buffer - self._level - padding) {
            len_line_max = width_console_screen_buffer - self._level - padding;
        }

        return len_line_max;
    }

    // TODO For every word, add to the length, store the word, if the next word plus any punctuation is excess, treat line up to that point as the current line
    fn surroundBox(self: *P, allocator: std.mem.Allocator, message_formatted: zigstr, len_line_max: usize) ![]const u8 {
        // Tokenize the formatted message by newlines.
        var iter_message_formatted = message_formatted.lineIter();

        // This will store each line of the string.
        var message_new = try zigstr.fromBytes(allocator, "");
        errdefer message_new.deinit();

        var message_line = try zigstr.fromBytes(allocator, "");
        defer message_line.deinit();

        var message_line_wrapped = try zigstr.fromBytes(allocator, "");
        defer message_line_wrapped.deinit();

        var temp_word = try zigstr.fromBytes(allocator, "");
        defer temp_word.deinit();

        var message_word = try zigstr.fromBytes(allocator, "");
        defer message_word.deinit();

        iter_message_formatted.reset();

        const spaces: []const u8 = try self.generate_spaces(allocator);

        // For every line of the message.
        while (iter_message_formatted.next()) |line| {
            try message_line.reset(line);

            var iter_word = try ziglyph.Word.WordIterator.init(line);

            // For every word of the line.
            while (iter_word.next()) |word| {
                try temp_word.reset(word.bytes);

                // If this 'word' is just spaces.
                if (try temp_word.isBlank()) {
                    // If the word fits in the console.
                    if ((try message_line_wrapped.graphemeCount()) + (try message_word.graphemeCount()) + 1 < len_line_max) {
                        try message_line_wrapped.concat(" ");
                        try message_line_wrapped.concat(message_word.bytes.items);
                    }
                    // If the word does not fit in the console.
                    else {
                        try message_new.concat(spaces);
                        try message_new.concat(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
                        try message_new.concat(" ");
                        try message_new.concat(message_line_wrapped.bytes.items);

                        // If the length of the slice is less than the max line length.
                        // If the slice doesn't fill the max line length.
                        if ((try message_line_wrapped.graphemeCount()) < len_line_max) {
                            // DELETED
                            //std.debug.print("entuhenu\n", .{});

                            // DELETED
                            // var blah: usize = 0;
                            // if (@subWithOverflow(usize, len_line_max, (try message_line_wrapped.graphemeCount()) + 1, &blah)) {
                            //     @panic("aousnthu");
                            // }

                            // Add padding spaces between the text and the right box line so all the lines are the same length.
                            var n: usize = len_line_max - (try message_line_wrapped.graphemeCount()) + 1;

                            while (n != 0) : (n -= 1) {
                                try message_new.concat(" ");
                            }

                            try message_new.concat(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
                            try message_new.concat("\n");

                            break;
                        }
                        // If the slice fills the max line length.
                        else {
                            try message_new.concat(" ");

                            try message_new.concat(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
                            try message_new.concat("\n");
                        }

                        try message_line_wrapped.reset(message_word.bytes.items);
                    }

                    try message_word.reset("");
                }
                // If this 'word' is not just spaces.
                else {
                    try message_word.concat(word.bytes);
                }
            }

            // DELETED
            // var grapheme_count: usize = try message_line.graphemeCount();
            //
            // // If the line is longer than can fit.
            // if (grapheme_count > len_line_max) {
            //     var start_slice: usize = 0;
            //     var end_slice: usize = 0;
            //
            //     // While `start_slice` is less than the length of the current line plus the max line length minus 1. This is because the last slice might not fill the max line length.
            //     while (start_slice < line.len) : (start_slice += len_line_max) {
            //         try message_new.concat(spaces);
            //         try message_new.concat(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
            //         try message_new.concat(" ");
            //
            //         // If the start of this slice plus the maximum line length does not exceed the length of this line of the message.
            //         end_slice = if (start_slice + len_line_max < line.len) start_slice + len_line_max else line.len;
            //
            //         var slice = line[start_slice..end_slice];
            //
            //         // DELETED
            //         // std.debug.print("start slice: {d}, end slice: {d}, line length: {d}, max line length: {d}, console width: {d}, slice len: {d}, grapheme count: {d}.\n", .{ start_slice, end_slice, line.len, len_line_max, widthConsoleScreenBuffer(), slice.len, grapheme_count });
            //
            //         try message_new.concat(slice);
            //
            //         // If the length of the slice is less than the max line length.
            //         // If the slice doesn't fill the max line length.
            //         if (slice.len < len_line_max) {
            //             // DELETED
            //             //std.debug.print("entuhenu\n", .{});
            //
            //             // Add padding spaces between the text and the right box line so all the lines are the same length.
            //             var n: usize = len_line_max - slice.len + 1;
            //             while (n != 0) : (n -= 1) {
            //                 try message_new.concat(" ");
            //             }
            //
            //             try message_new.concat(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
            //             try message_new.concat("\n");
            //
            //             break;
            //         }
            //         // If the slice fills the max line length.
            //         else {
            //             try message_new.concat(" ");
            //
            //             try message_new.concat(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
            //             try message_new.concat("\n");
            //         }
            //     }
            // }
            // // If the line fits.
            // else {
            //     try message_new.concat(spaces);
            //     try message_new.concat(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
            //     try message_new.concat(" ");
            //
            //     try message_new.concat(line);
            //     try message_new.concat(" ");
            //
            //     // Add padding spaces between the text and the right box line so all the lines are the same length.
            //     var n: usize = len_line_max - line.len;
            //     while (n != 0) : (n -= 1) {
            //         try message_new.concat(" ");
            //     }
            //
            //     try message_new.concat(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
            //     try message_new.concat("\n");
            // }
        }

        try message_new.insert(spaces, 0);
        try message_new.insert(ascii_codes.character_set_decimal_line_drawing ++ ascii_codes.box_top_left, self._level);
        try message_new.concat(spaces);
        try message_new.concat(ascii_codes.character_set_decimal_line_drawing ++ ascii_codes.box_bottom_left);

        const len_top_left = ascii_codes.character_set_decimal_line_drawing.len + ascii_codes.box_top_left.len;

        var j: usize = len_top_left + self._level;

        // Create the horizontal lines for the box.
        //
        // Messages are variable in length, so this also needs to be.
        while (j < (len_line_max + len_top_left + 2 + self._level)) : (j += 1) {
            try message_new.insert(ascii_codes.box_horizontal, j);
            try message_new.concat(ascii_codes.box_horizontal);
        }

        try message_new.insert(ascii_codes.box_top_right ++ ascii_codes.character_set_ansii ++ "\n", j);
        try message_new.concat(ascii_codes.box_bottom_right ++ ascii_codes.character_set_ansii ++ "\n");

        // Return the entire message.
        return try message_new.toOwnedSlice();
    }

    // Determine useful line max
    // insert newlines where necessary
    // pad to terminal width
    //
    // surroundbox would need to be aware of the number of indentations
    fn surroundBoxMax(self: *P, allocator: std.mem.Allocator, comptime message: []const u8, args: anytype) ![]const u8 {
        // Format the message so we can get the true length, and convert it to a more useful string.
        var message_formatted = try zigstr.fromBytes(allocator, try std.fmt.allocPrint(allocator, message, args));
        defer message_formatted.deinit();

        return try self.surroundBox(allocator, message_formatted, widthConsoleScreenBuffer() - 4 - self._level);
    }

    // TODO Why is the decimal line drawing character set necessary? Windows Terminal seems to understand the raw characters, is it something on the Zig side? Isn't ASCII a subset of UTF-8?
    //
    // Return the input of a single or multiline string surrounded by a box, which can then be printed.
    // Utilizes the decimal line drawing character set for the box characters.
    //
    // A limitation of this is that the line length count does not account for the ascii escape characters for the terminal perfectly, so the input is restricted to multiline strings of UTF-8 characters and zig string escapes.
    //
    // Example:
    // ```
    // Input:
    // surroundBox(
    //   \\Hi
    //   \\World.
    //   ,.{});
    //
    // Output:
    // ┌────────┐
    // │ Hi     │
    // │ World. │
    // └────────┘
    // ```
    //
    // TODO Alternative to the decimal line drawing character set is the following. Not quite so neat.
    // ```
    // +--------+
    // | Hi     |
    // | World. |
    // +--------+
    // ```
    fn surroundBoxFit(self: *P, allocator: std.mem.Allocator, comptime message: []const u8, args: anytype) ![]const u8 {
        // Format the message so we can get the true length, and convert it to a more useful string.
        var message_formatted = try zigstr.fromBytes(allocator, try std.fmt.allocPrint(allocator, message, args));
        defer message_formatted.deinit();

        return try self.surroundBox(allocator, message_formatted, try self.lenLineMax(allocator, message_formatted, 4));
    }

    // TODO Take input, wrap it in preparation for indent()
    fn wrap(self: *P, allocator: std.mem.Allocator, comptime message: []const u8, args: anytype) ![]const u8 {
        // Format the message so we can get the true length, and convert it to a more useful string.
        var message_formatted = try zigstr.fromBytes(allocator, try std.fmt.allocPrint(allocator, message, args));
        defer message_formatted.deinit();

        // Tokenize the formatted message by newlines.
        var iter_message_formatted = message_formatted.lineIter();

        // Determine the longest line.
        const len_line_max: usize = try self.lenLineMax(allocator, message_formatted, 0);

        iter_message_formatted.reset();

        // This will store each line of the output string.
        var message_new = try zigstr.fromBytes(allocator, "");
        errdefer message_new.deinit();

        var message_line = try zigstr.fromBytes(allocator, "");
        defer message_line.deinit();

        // For every line of the message.
        while (iter_message_formatted.next()) |iter| {
            try message_line.reset(iter);

            const grapheme_count: usize = try message_line.graphemeCount();

            // If the line is longer than can fit.
            if (grapheme_count > len_line_max) {
                var start_slice: usize = 0;
                var end_slice: usize = 0;

                // While `start_slice` is less than the length of the current line plus the max line length minus 1. This is because the last slice might not fill the max line length.
                while (true) {
                    // TODO Need to wrap by words.

                    // If the start of this slice plus the maximum line length does not exceed the length of this line of the message.
                    end_slice = if (start_slice + len_line_max < iter.len) len_line_max else iter.len;

                    //std.debug.print("start slice: {d}, end slice: {d}, iter length: {d}, console width: {d}.\n", .{ start_slice, end_slice, iter.len, len_line_max });

                    var slice = iter[start_slice..end_slice];
                    try message_new.concat(slice);
                    try message_new.concat("\n");

                    start_slice += len_line_max;

                    if (start_slice >= iter.len) {
                        break;
                    }
                }
            }
            // If the line fits.
            else {
                try message_new.concat(iter);
                try message_new.concat("\n");
            }
        }

        // Return the entire message.
        return try message_new.toOwnedSlice();
    }

    fn generate_spaces(self: *P, allocator: std.mem.Allocator) ![]const u8 {
        var string_spaces = try zigstr.fromBytes(allocator, " ");
        defer string_spaces.deinit();

        // Repeat the spaces by the number of indentations required.
        try string_spaces.repeat(self._level);

        return try string_spaces.toOwnedSlice();
    }

    // Indent using spaces, each indentation is 2 spaces.
    fn indent(self: *P, allocator: std.mem.Allocator, comptime message: []const u8, args: anytype) ![]const u8 {
        var message_formatted = try zigstr.fromBytes(allocator, try self.wrap(allocator, message, args));
        defer message_formatted.deinit();

        // Tokenize the formatted message by newlines.
        var iter_message_formatted = message_formatted.lineIter();

        // This will store each line of the string.
        var message_new = try zigstr.fromBytes(allocator, "");
        errdefer message_new.deinit();

        const spaces: []const u8 = try self.generate_spaces(allocator);

        // For every line of the message.
        while (iter_message_formatted.next()) |iter| {
            // If the last line of the input message has a `\n` at the end of it, then the tokenization will count that as a blank line, so we don't want to add spaces for that last line.
            if (iter.len > 1) {
                try message_new.concat(spaces);
            }
            try message_new.concat(iter);

            var iter_message_formatted_next = iter_message_formatted;

            if (iter_message_formatted_next.next() != null) {
                try message_new.concat("\n");
            }
        }

        return message_new.toOwnedSlice();
    }

    // TODO make box max width of terminal, while accounting for indentations
    //
    // Debug printing utility.
    fn printHeading(self: *P, comptime message: []const u8, args: anytype) !void {
        // Memory allocator.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // TODO Get coloured background to output as expected.

        const surrounded: []const u8 = try self.surroundBoxFit(arena_allocator, message, args);
        //const indented: []const u8 = try self.indent(arena_allocator, "{s}", .{surrounded});

        std.debug.print("{s}", .{surrounded});
    }

    // Debug printing utility.
    fn printNormal(self: *P, comptime message: []const u8, args: anytype) !void {
        // Memory allocator.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // TODO Account for max width of the console so wrapping is properly wrapped.

        const indented = try self.indent(arena_allocator, message ++ "\n", args);

        std.debug.print("{s}", .{indented});
    }
};

var p = P{};

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
        clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &clap_diagnostic,
    }) catch |err| {
        // Report useful error and exit.
        clap_diagnostic.report(std.io.getStdErr().writer(), err) catch {};

        return err;
    };
    defer arguments.deinit();

    if (arguments.args.help)
        try p.printNormal(
            \\NAME
            \\    Serpentine
            \\
            \\SYNOPSIS
            \\    TODO
        , .{});

    if (arguments.args.@"test-number") |n|
        try p.printNormal("Test number = {d}.", .{n});

    for (arguments.args.@"test-string") |s|
        try p.printNormal("Test string = {s}.", .{s});

    for (arguments.positionals) |pos|
        try p.printNormal("{s}", .{pos});
}

pub fn main() !void {
    try p.printNormal(
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
    , .{});

    try p.printHeading("Starting Serpentine.", .{});
    defer p.printHeading("Ending Serpentine.", .{}) catch @panic("");

    p.i();
    p.i();
    try p.printNormal(
        \\A-test-sentence-that-has-no-repeating-words-which-is-assisting-in-determining-what-error-bares-responibility-of-erroneous-output.
        \\Test line short.
    , .{});
    try p.printHeading(
        \\A-test-sentence-that-has-no-repeating-words-which-is-assisting-in-determining-what-error-bares-responibility-of-erroneous-output.
        \\Test line short.
    , .{});
    p.o();
    p.o();

    try manageArguments();
}

test "surround box" {
    // Memory allocator.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    try std.testing.expect(try p.surroundBox(arena_allocator,
        \\Surround
        \\box.
    , .{}) ==
        \\┌──────────┐
        \\│ Surround │
        \\│ box.     │
        \\└──────────┘
    );
}
