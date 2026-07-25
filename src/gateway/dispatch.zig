pub fn Dispatcher(comptime listeners: []const type) type {
    return struct {
        pub fn fireEvent(_: @This(), Event: type, data: Event) void {
            inline for (listeners) |ns| {
                inline for (comptime std.meta.declarations(ns)) |decl| {
                    const field = @field(ns, decl.name);

                    const info = @typeInfo(@TypeOf(field));
                    const fn_info = info.@"fn";

                    if (fn_info.params.len != 1) continue;
                    if (fn_info.params[0].type != Event) continue;

                    field(data);
                }
            }
        }
    };
}

pub fn parseDispatch(alloc: std.mem.Allocator, t_str: []const u8, d: std.json.Value) !root.Messages.DispatchEvent {
    const Tag = std.meta.FieldEnum(root.Messages.DispatchEvent);
    const tag = std.meta.stringToEnum(Tag, t_str) orelse return .{ .unknown = {} };

    return switch (tag) {
        .unknown => .{ .unknown = {} },
        inline else => |comptime_tag| blk: {
            const T = @FieldType(root.Messages.DispatchEvent, @tagName(comptime_tag));
            const parsed = try std.json.parseFromValueLeaky(T, alloc, d, .{ .ignore_unknown_fields = true });
            break :blk @unionInit(root.Messages.DispatchEvent, @tagName(comptime_tag), parsed);
        },
    };
}

const root = @import("root.zig");
const std = @import("std");
