pub fn buildQuery(allocator: std.mem.Allocator, params: anytype) ![]u8 {
    var buf = std.ArrayList(u8).initCapacity(allocator, 1) catch @panic("OOM");
    errdefer buf.deinit(allocator);

    var first = true;
    const T = @TypeOf(params);
    inline for (std.meta.fields(T)) |field| {
        const value = @field(params, field.name);
        try appendField(&buf, allocator, field.name, value, &first);
    }

    return buf.toOwnedSlice(allocator);
}

fn appendField(
    buf: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    name: []const u8,
    value: anytype,
    first: *bool,
) !void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    switch (info) {
        .optional => {
            if (value) |v| {
                try appendField(buf, allocator, name, v, first);
            }
        },
        .bool => {
            try appendPair(buf, allocator, name, if (value) "true" else "false", first);
        },
        .int => {
            var num_buf: [20]u8 = undefined;
            const s = std.fmt.bufPrint(&num_buf, "{d}", .{value}) catch unreachable;
            try appendPair(buf, allocator, name, s, first);
        },
        .@"enum" => {
            try appendPair(buf, allocator, name, @tagName(value), first);
        },
        .pointer => |ptr| {
            if (ptr.size == .slice) {
                if (ptr.child == u8) { // []const u8
                    try appendPair(buf, allocator, name, value, first);
                } else { // [][]const u8
                    for (value) |item| {
                        try appendField(buf, allocator, name, item, first);
                    }
                }
            }
        },
        .@"union" => |u| {
            inline for (u.fields) |uf| {
                if (value == @field(std.meta.Tag(T), uf.name)) {
                    const v = @field(value, uf.name);
                    try appendField(buf, allocator, uf.name, v, first);
                }
            }
        },
        else => @compileError("unsupported field type for " ++ name),
    }
}

fn appendPair(
    buf: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    key: []const u8,
    value: []const u8,
    first: *bool,
) !void {
    if (!first.*) try buf.appendSlice(allocator, "&");
    first.* = false;
    try buf.appendSlice(allocator, key);
    try buf.appendSlice(allocator, "=");
    try urlEscape(buf, allocator, value);
}

pub fn urlEscape(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => try buf.append(allocator, c),
            ' ' => try buf.appendSlice(allocator, "%20"),
            else => {
                var buf2: [3]u8 = undefined;
                const escaped = try std.fmt.bufPrint(&buf2, "%{X:0>2}", .{c});
                try buf.appendSlice(allocator, escaped); // string slice
            },
        }
    }
}

const std = @import("std");
