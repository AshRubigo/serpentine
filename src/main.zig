// 2022-08-02-04-51-07

const std = @import("std");
const clap = @import("clap");

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

// TODO Put these functions in the `AsciiCodes` struct somehow.

// Convenience function for enabling and disabling the decimal line drawing character set.
fn characterSetDecimalLineDrawing(allocator: std.mem.Allocator, comptime message: []const u8, args: anytype) ![]const u8 {
    return try std.fmt.allocPrint(allocator, ascii_codes.character_set_decimal_line_drawing ++ message ++ ascii_codes.character_set_ansii, args);
}

// TODO Why is the decimal line drawing character set necessary? Windows Terminal seems to understand the raw characters, is it something on the Zig side? Isn't ASCII a subset of UTF-8?
//
// Return the input of a single or multiline string surrounded by a box, which can then be printed.
// Utilizes the decimal line drawing character set for the box characters.
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
fn surroundBox(allocator: std.mem.Allocator, comptime message: []const u8, args: anytype) ![]const u8 {
    // Format the message so we can get the true length.
    const message_formatted = try std.fmt.allocPrint(allocator, message, args);

    // Tokenize the formatted message by newlines.
    var iter_message = std.mem.tokenize(u8, message_formatted, "\n");
    var iter_message_2 = iter_message;

    var len_line_max: usize = 0;

    // This will store each line of the string.
    var message_new = std.ArrayList(u8).init(allocator);
    defer message_new.deinit();

    // For every line of the message.
    while (iter_message_2.next()) |iter| {
        // Update the length of the longest line.
        if (iter.len > len_line_max) {
            len_line_max = iter.len;
        }
    }

    // For every line of the message.
    while (iter_message.next()) |iter| {
        // TODO Need to add padding spaces between the text and the right box line so all the lines are the same length.
        // Surround the line of the message with a vertical box line.
        try message_new.appendSlice(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
        try message_new.appendSlice(" ");
        try message_new.appendSlice(iter);
        try message_new.appendSlice(" ");

        var n: usize = len_line_max - iter.len;
        while (n != 0) : (n -= 1) {
            try message_new.appendSlice(" ");
        }

        try message_new.appendSlice(try characterSetDecimalLineDrawing(allocator, ascii_codes.box_vertical, .{}));
        try message_new.appendSlice("\n");
    }

    // // Create the horizontal lines for the box.
    // //
    // // Messages are variable in length, so this also needs to be.
    // var horizontal = std.ArrayList(u8).init(arena_allocator);
    // defer horizontal.deinit();

    try message_new.insertSlice(0, ascii_codes.character_set_decimal_line_drawing ++ ascii_codes.box_top_left);
    try message_new.appendSlice(ascii_codes.character_set_decimal_line_drawing ++ ascii_codes.box_bottom_left);

    var j: usize = ascii_codes.character_set_decimal_line_drawing.len + ascii_codes.box_top_left.len;
    // TODO Why `+ 6`, thought it would be `+ 4`?
    while (j < (len_line_max + 6)) : (j += 1) {
        try message_new.insertSlice(j, ascii_codes.box_horizontal);
        try message_new.appendSlice(ascii_codes.box_horizontal);
    }

    try message_new.insertSlice(j, ascii_codes.box_top_right ++ ascii_codes.character_set_ansii ++ "\n");
    try message_new.appendSlice(ascii_codes.box_bottom_right ++ ascii_codes.character_set_ansii ++ "\n");

    const message_return = message_new.items;

    // TODO This is just here as a test.
    std.debug.print("{s}", .{message_return});

    // Return the entire message.
    return message_new.items;
}

// TODO Implement indentation for the debug printing functions, which is helpful for debugging. `p.u(); defer p.d();` for `print.indent(); print.outdent();`.

// TODO `fn printTitle()` Double box maybe? Is it even necessary?

// Debug printing utility.
fn printHeading(comptime message: []const u8, args: anytype) !void {
    // Memory allocator.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // TODO Get coloured background to output as expected.

    std.debug.print("{s}", .{try surroundBox(arena_allocator, message, args)});
}

// Debug printing utility.
fn printNormal(comptime message: []const u8, args: anytype) !void {
    std.debug.print(ascii_codes.character_set_ansii ++ message ++ "\n", args);
}

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
        try printNormal(
            \\NAME
            \\    Serpentine
            \\
            \\SYNOPSIS
            \\    TODO
            \\
        , .{});

    if (arguments.args.@"test-number") |n|
        try printNormal("Test number = {}.", .{n});

    for (arguments.args.@"test-string") |s|
        try printNormal("Test string = {s}.", .{s});

    for (arguments.positionals) |pos|
        try printNormal("{s}", .{pos});
}

// TODO Alternate text, not sure which looks better. Chose other style because the first character should be high.
//                                    _
//      ___      _ ___      _ __  _  (_)       ___
// ___ / _ \_ __| '_  \ ___| '_ \| |_| | __   / _ \
/// __|  __/ '__| |_)  | _ \ | | | __| | '_ \|  __/
//\__ \\___| |  | .___/  __/_| |_| |_|_| | | |\___|
//|___/    |_|  |_|    \___|     |___| |_| |_|
//
pub fn main() !void {
    try printNormal(
        \\                                _
        \\ ___      _ __        ___      | |_ _ _ __
        \\/ __| ___| '__| ___  / _ \_ __ | __(_) '_ \  ___
        \\\__ \/ _ \ | | '_  \|  __/ '_ \| |_| | | | |/ _ \
        \\|___/  __/_| | |_)  |\___| | | |___| |_| |_|  __/
        \\     \___|   | .___/     |_| |_|   |_|      \___|
        \\             |_|
        \\
    , .{});

    try printHeading(
        \\Test
        \\{d}.
    , .{1});

    // try printHeading("Starting Serpentine.", .{});
    // defer printHeading("Ending Serpentine.", .{}) catch @panic("");

    try manageArguments();
}

test "surround box" {
    // Memory allocator.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    try std.testing.expect(surroundBox(arena_allocator,
        \\Surround
        \\box.
    , .{}) ==
        \\┌──────────┐
        \\│ Surround │
        \\│ box.     │
        \\└──────────┘
    );
}
