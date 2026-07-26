pub fn stringify(allocator: std.mem.Allocator, payload: anytype) []u8 {
    return std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(payload, .{
        .emit_null_optional_fields = false,
    })}) catch @panic("OOM");
}

const std = @import("std");
