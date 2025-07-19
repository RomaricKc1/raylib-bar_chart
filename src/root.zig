//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const rl = @import("raylib");
const Color = rl.Color;

/// error that can occurs
pub const BarGraphError = error{
    EMPTY_DATA,
};

/// Main struct for the Bar graph widget
pub const BarGraphDat = struct {
    /// name of the widget
    name: []const u8,
    /// title of the widget
    title: []const u8,
    /// x-axis labels
    x_list: std.ArrayList([]const u8),
    /// y-axis values
    y_list: std.ArrayList(i32),
    /// color for the bar graph widget
    bar_color: rl.Color,
    /// color for the bars' bins
    bin_color: rl.Color,
    /// color for the bars' text related
    bin_text_color: rl.Color,
    /// is the text inside the bin or outside?
    text_in_bin: bool = true,

    pub fn new(
        allocator: std.mem.Allocator,
        name: []const u8,
        title: []const u8,
        bar_color: rl.Color,
        bin_color: rl.Color,
        text_color: rl.Color,
    ) !BarGraphDat {
        const y_list = std.ArrayList(i32).init(allocator);
        const x_list = std.ArrayList([]const u8).init(allocator);

        const self = BarGraphDat{
            .name = name,
            .title = title,
            .y_list = y_list,
            .x_list = x_list,
            .bar_color = bar_color,
            .bin_color = bin_color,
            .bin_text_color = text_color,
            .text_in_bin = true,
        };
        return self;
    }

    pub fn set_ylist(self: *BarGraphDat, arr: []const i32) !void {
        try self.y_list.appendSlice(arr);
    }

    pub fn set_xlist(self: *BarGraphDat, arr: []const []const u8) !void {
        for (arr) |this_elm| {
            try self.x_list.append(this_elm);
        }
    }

    pub fn cleanup(self: *BarGraphDat) void {
        self.y_list.deinit();
        self.x_list.deinit();
    }

    pub fn remove_elms(self: *BarGraphDat) void {
        self.y_list.clearRetainingCapacity();
        self.x_list.clearRetainingCapacity();
    }
};

/// structs for the bins
pub const BinInfo = struct {
    /// its id
    id: i32,
    /// its height
    h: i32,
    /// its widget
    w: i32,
    /// its position on x
    p_x: i32,
    /// its position on y
    p_y: i32,
    /// the actual value for y-axis
    actual_val: i32 = 0,
    /// the actual content for the bin
    content: []const u8,
};

// //////////////////////////////////////////////////////////////////////////////////////
// other functions here
pub fn gen_bin_data(
    allocator: std.mem.Allocator,
    bar: BarGraphDat,
    posX: i32,
    posY: i32,
    width: i32,
    height: i32,
) anyerror!?std.ArrayList(BinInfo) {
    var bins_arr = std.ArrayList(BinInfo).init(allocator);

    const x_len: i32 = @intCast(bar.x_list.items.len);
    const y_len: i32 = @intCast(bar.y_list.items.len);
    if (x_len < 1 or y_len < 1) {
        return BarGraphError.EMPTY_DATA;
    }

    const max_y_val: i32 = if (get_max_al(i32, bar.y_list)) |val| val else 0;
    if (max_y_val == 0) {
        return null;
    }

    const ind_bar_width: i32 = @intCast(@divTrunc(width, (x_len + 1)));
    const bar_sep: i32 = @intCast(@divTrunc(ind_bar_width, x_len));

    const clearance: i32 = 20;
    const used_posY: i32 = posY + clearance;

    for (bar.x_list.items, bar.y_list.items, 0..) |bar_x_val, bar_y_val, idx| {
        var this_p_x: i32 = undefined;
        this_p_x = posX + @as(i32, @intCast(idx)) * (ind_bar_width + bar_sep);
        const this_bar_w: i32 = ind_bar_width;

        const scaled_bar_y_val: i32 = @divTrunc((bar_y_val * height), max_y_val);
        const this_p_y: i32 = height - scaled_bar_y_val + used_posY;

        const this_bar_h: i32 = scaled_bar_y_val;

        try bins_arr.append(BinInfo{
            .h = this_bar_h,
            .id = @as(i32, @intCast(idx)),
            .p_x = this_p_x,
            .p_y = this_p_y,
            .w = this_bar_w,
            .content = bar_x_val,
            .actual_val = bar_y_val,
        });
    }

    return bins_arr;
}

pub fn bar_graph(
    allocator: std.mem.Allocator,
    bar: BarGraphDat,
    posX: i32,
    posY: i32,
    width: i32,
    height: i32,
    font_size: i32,
    text_in_bin: bool,
) anyerror!void {
    // creates the vertical bins
    var bins_arr = std.ArrayList(BinInfo).init(allocator);
    defer bins_arr.deinit();

    const tmp = try gen_bin_data(allocator, bar, posX, posY, width, height);
    // drawing the bin color first, and then cutting off the remaining from the top
    // creates base box
    rl.drawRectangle(posX, posY, width, height, bar.bar_color);

    if (tmp == null) {
        // draws empty screen
        const text: [:0]const u8 = try format_text(allocator, "Empty data", "");
        rl.drawText(text, posX + 30, posY + 30, font_size * 2, .red);
        return;
    }

    bins_arr = tmp.?;

    // creates rectangles with the bars dimensions
    // derives these values from the dimensions of the list widget
    const content_y_offset: i32 = 10;
    var content_x_offset: i32 = undefined;

    for (bins_arr.items) |bin_info| {
        rl.drawRectangle(bin_info.p_x, bin_info.p_y, bin_info.w, bin_info.h, bar.bin_color);

        // adds the text on the x_axis to the bin containing the current height
        const new_content = try std.fmt.allocPrint(
            allocator,
            "{d}, {s}",
            .{ bin_info.actual_val, bin_info.content },
        );
        defer allocator.free(new_content);

        for (new_content, 0..) |char, idx_| {
            content_x_offset = @divTrunc(bin_info.w, 2) - font_size;

            const idx: i32 = @intCast(idx_);
            const this_char: []const u8 = &[1]u8{char};
            const text: [:0]const u8 = try format_text(allocator, this_char, "");

            if (text_in_bin) {
                rl.drawText(
                    text,
                    bin_info.p_x + content_x_offset,
                    bin_info.p_y + 2 * idx * content_y_offset,
                    font_size,
                    bar.bin_text_color,
                );
            } else {
                rl.drawText(
                    text,
                    bin_info.p_x + content_x_offset,
                    posY + 2 * idx * content_y_offset,
                    font_size,
                    bar.bin_text_color,
                );
            }
        }
    }

    return;
}

pub fn format_text(allocator: std.mem.Allocator, command: ?[]const u8, text: []const u8) ![:0]const u8 {
    if (command) |cmd| {
        const anytext = try std.fmt.allocPrint(allocator, "{s} {s}", .{ text, cmd });
        defer allocator.free(anytext);
        return rl.textFormat("%s", .{anytext.ptr});
    } else {
        return rl.textFormat("%s", .{text.ptr});
    }
}

pub fn get_max_al(comptime T: type, arr_list: std.ArrayList(T)) ?T {
    switch (@typeInfo(T)) {
        .int, .float => {
            var max_y_val: T = undefined;
            if (arr_list.items.len > 0) {
                max_y_val = arr_list.items[0];
            } else {
                return null;
            }
            for (arr_list.items) |val| {
                if (val > max_y_val) max_y_val = val;
            }
            return max_y_val;
        },
        else => {
            @compileError("Not implemented.");
        },
    }

    return null;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////
// tests here
test "BarGraphDat" {
    const allocator = std.testing.allocator;

    var bar: BarGraphDat = try BarGraphDat.new(
        allocator,
        "test",
        "test",
        rl.Color.yellow,
        rl.Color.yellow,
        rl.Color.yellow,
    );
    defer bar.cleanup();

    const arr = &[_]i32{ 40, 100, 30, 55 };
    try bar.set_ylist(arr);

    try std.testing.expect(bar.y_list.items.len != 0);
    for (0..arr.len) |idx| {
        try std.testing.expectEqual(arr[idx], bar.y_list.items[idx]);
    }

    const arr_str: []const []const u8 = &.{ "apple", "banana" };
    try bar.set_xlist(arr_str);

    try std.testing.expect(bar.x_list.items.len != 0);
    for (0..arr_str.len) |idx| {
        try std.testing.expect(std.mem.eql(u8, bar.x_list.items[idx], arr_str[idx]));
    }
}
test "bin position and stuff" {
    const allocator = std.testing.allocator;

    const window_width = 800;
    const window_height = 540;

    const pos_x = 250;
    const pos_y = 100;
    const width = window_width - 250;
    const height = window_height - 100;

    var x_list = std.ArrayList([]const u8).init(allocator);
    defer x_list.deinit();

    var y_list = std.ArrayList(i32).init(allocator);
    defer y_list.deinit();

    const bar_mpty = BarGraphDat{
        .name = "",
        .title = "",
        .x_list = x_list,
        .y_list = y_list,
        .bar_color = .yellow,
        .bin_color = .blue,
        .bin_text_color = .white,
    };

    const empty_res = gen_bin_data(allocator, bar_mpty, pos_x, pos_y, width, height);
    try std.testing.expectEqual(BarGraphError.EMPTY_DATA, empty_res);

    // full e.g. test
    try x_list.appendSlice(&.{ "apple", "blueberry", "cherry", "orange" });
    const y_dat = [_]i32{ 40, 100, 30, 55 };
    try y_list.appendSlice(&y_dat);

    const bar = BarGraphDat{
        .name = "Test",
        .title = "The test command",
        .x_list = x_list,
        .y_list = y_list,
        .bar_color = .yellow,
        .bin_color = .blue,
        .bin_text_color = .white,
    };

    const tmp = try gen_bin_data(allocator, bar, pos_x, pos_y, width, height);
    const res: std.ArrayList(BinInfo) = tmp.?;
    defer res.deinit();

    const max_y_val: i32 = get_max_al(i32, y_list) orelse -1;
    const scaled_bar_y_val: i32 = @divTrunc((40 * height), max_y_val);
    const clearance: i32 = 20;
    const p_x: i32 = pos_x;
    const p_y: i32 = height - scaled_bar_y_val + pos_y + clearance;

    const expected_res = [_]BinInfo{
        BinInfo{ .id = 0, .h = scaled_bar_y_val, .w = 110, .p_x = p_x, .p_y = p_y, .content = "apple", .actual_val = 40 },
        BinInfo{ .id = 1, .h = 440, .w = 110, .p_x = 387, .p_y = 120, .content = "blueberry", .actual_val = 100 },
        BinInfo{ .id = 2, .h = 132, .w = 110, .p_x = 524, .p_y = 428, .content = "cherry", .actual_val = 30 },
        BinInfo{ .id = 3, .h = 242, .w = 110, .p_x = 661, .p_y = 318, .content = "orange", .actual_val = 55 },
    };

    for (0..expected_res.len) |this_idx| {
        try std.testing.expectEqual(expected_res[this_idx], res.items[this_idx]);
    }
}

test "format_text" {
    const allocator = std.testing.allocator;

    const txt = "test";
    const some = try format_text(allocator, txt, "anything");
    try std.testing.expect(std.mem.eql(u8, some, "anything test"));
}

test "get max array list" {
    const allocator = std.testing.allocator;

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    const dat = [_]u8{ 40, 100, 30, 55 };
    try list.appendSlice(&dat);

    var max_val: ?u8 = get_max_al(u8, list);
    try std.testing.expectEqual(100, max_val.?);

    list.deinit();

    // empty list
    list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    max_val = get_max_al(u8, list);
    try std.testing.expectEqual(null, max_val);
}
