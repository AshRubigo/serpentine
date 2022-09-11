// 2022-08-02-04-51-07

const std = @import("std");
const clap = @import("clap");
const zigstr = @import("zigstr");

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

const P = struct {
    _level: usize = 0,

    fn i(self: *P) void {
        self._level += 2;
    }

    fn o(self: *P) void {
        self._level -= 2;
    }

    // Convenience function for enabling and disabling the decimal line drawing character set.
    fn characterSetDecimalLineDrawing(allocator: std.mem.Allocator, comptime message: []const u8, args: anytype) ![]const u8 {
        return try std.fmt.allocPrint(allocator, ascii_codes.character_set_decimal_line_drawing ++ message ++ ascii_codes.character_set_ansii, args);
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
    fn surroundBox(self: *P, allocator: std.mem.Allocator, comptime message: []const u8, args: anytype) ![]const u8 {
        // Format the message so we can get the true length, and convert it to a more useful string.
        var message_formatted = try zigstr.fromBytes(allocator, try std.fmt.allocPrint(allocator, message, args));
        defer message_formatted.deinit();

        // Tokenize the formatted message by newlines.
        var iter_message_formatted = message_formatted.lineIter();
        var iter_message_formatted_2 = iter_message_formatted;

        var len_line_max: usize = 0;

        var message_line = try zigstr.fromBytes(allocator, "");
        defer message_line.deinit();

        // TODO This should only count combining or visible characters. That may involve accounting for specific terminals.
        //
        // For every line of the message.
        while (iter_message_formatted_2.next()) |iter| {
            try message_line.reset(iter);
            const iter_len = try message_line.graphemeCount();

            // Update the length of the longest line.
            if (iter_len > len_line_max) {
                len_line_max = iter_len;
            }
        }

        // This will store each line of the string.
        var message_new = try zigstr.fromBytes(allocator, "");
        errdefer message_new.deinit();

        // For every line of the message.
        while (iter_message_formatted.next()) |iter| {
            // Surround the line of the message with a vertical box line.
            try message_new.concat(try self.characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
            try message_new.concat(" ");
            try message_new.concat(iter);
            try message_new.concat(" ");

            // Add padding spaces between the text and the right box line so all the lines are the same length.
            var n: usize = len_line_max - iter.len;
            while (n != 0) : (n -= 1) {
                try message_new.concat(" ");
            }

            try message_new.concat(try self.characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
            try message_new.concat("\n");
        }

        try message_new.insert(ascii_codes.character_set_decimal_line_drawing ++ ascii_codes.box_top_left, 0);
        try message_new.concat(ascii_codes.character_set_decimal_line_drawing ++ ascii_codes.box_bottom_left);

        const len_top_left = ascii_codes.character_set_decimal_line_drawing.len + ascii_codes.box_top_left.len;

        var j: usize = len_top_left;

        // Create the horizontal lines for the box.
        //
        // Messages are variable in length, so this also needs to be.
        while (j < (len_line_max + len_top_left + 2)) : (j += 1) {
            try message_new.insert(ascii_codes.box_horizontal, j);
            try message_new.concat(ascii_codes.box_horizontal);
        }

        try message_new.insert(ascii_codes.box_top_right ++ ascii_codes.character_set_ansii ++ "\n", j);
        try message_new.concat(ascii_codes.box_bottom_right ++ ascii_codes.character_set_ansii ++ "\n");

        // Return the entire message.
        return message_new.toOwnedSlice();
    }

    // Indent using spaces.
    fn dent(allocator: std.mem.Allocator, comptime message: []const u8, args: anytype, indentations: usize) ![]const u8 {
        var message_formatted = try zigstr.fromBytes(allocator, try std.fmt.allocPrint(allocator, message, args));
        defer message_formatted.deinit();

        // Tokenize the formatted message by newlines.
        var iter_message_formatted = message_formatted.lineIter();

        // This will store each line of the string.
        var message_new = try zigstr.fromBytes(allocator, "");
        errdefer message_new.deinit();

        var string_spaces = try zigstr.fromBytes(allocator, "  ");
        defer string_spaces.deinit();

        try string_spaces.repeat(indentations);

        const spaces: []const u8 = try string_spaces.toOwnedSlice();

        // For every line of the message.
        while (iter_message_formatted.next()) |iter| {
            try message_new.concat(spaces);
            try message_new.concat(iter);
            try message_new.concat("\n");
        }

        return message_new.toOwnedSlice();
    }

    // TODO Implement indentation for the debug printing functions, which is helpful for debugging. `p.u(); defer p.d();` for `print.indent(); print.outdent();`.

    // Debug printing utility.
    fn printHeading(self: *P, comptime message: []const u8, args: anytype) !void {
        // Memory allocator.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // TODO Get coloured background to output as expected.

        const surrounded: []const u8 = try self.surroundBox(arena_allocator, message, args);
        const dented: []const u8 = try self.dent(arena_allocator, "{s}", .{surrounded}, self._level);

        std.debug.print("{s}", .{dented});
    }

    // Debug printing utility.
    fn printNormal(self: *P, comptime message: []const u8, args: anytype) !void {
        // Memory allocator.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        const surrounded: []const u8 = try self.surroundBox(arena_allocator, ascii_codes.character_set_ansii ++ message ++ "\n", args);
        const dented: []const u8 = try self.dent(arena_allocator, "{s}", .{surrounded}, self._level);

        std.debug.print("{s}", .{dented});
    }
};

var p = P{};

fn manageArguments() !void {
    // Specify what parameters our program can take.
    // Can use `parseParamsComptime` to parse a string into an array of `Param(Help)`.
    //
    // Short arguments must be only 1 letter long.
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
        try p.printNormal("Test number = {}.", .{n});

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

    try manageArguments();
}

test "surround box" {
    // Memory allocator.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    try std.testing.expect(p.surroundBox(arena_allocator,
        \\Surround
        \\box.
    , .{}) ==
        \\┌──────────┐
        \\│ Surround │
        \\│ box.     │
        \\└──────────┘
    );
}
