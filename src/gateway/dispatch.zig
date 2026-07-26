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
            const parsed = std.json.parseFromValueLeaky(T, alloc, d, .{ .ignore_unknown_fields = true }) catch |err| {
                if (err == error.MissingField) {
                    logMissingFields(T, d, @tagName(comptime_tag));
                }

                return err;
            };
            break :blk @unionInit(root.Messages.DispatchEvent, @tagName(comptime_tag), parsed);
        },
    };
}

fn logMissingFields(comptime T: type, value: std.json.Value, path: []const u8) void {
    const info = @typeInfo(T);
    if (info != .@"struct") return;

    if (value != .object) {
        std.log.err("expected object for '{s}', got {s}", .{ path, @tagName(value) });
        return;
    }

    inline for (std.meta.fields(T)) |field| {
        const maybe_val = value.object.get(field.name);
        const is_optional = @typeInfo(field.type) == .optional;
        const has_default = field.default_value_ptr != null;

        if (maybe_val) |val| {
            const child_info = @typeInfo(field.type);

            if (child_info == .@"struct") {
                logMissingFields(field.type, val, field.name);
            } else if (child_info == .optional and @typeInfo(child_info.optional.child) == .@"struct") {
                logMissingFields(child_info.optional.child, val, field.name);
            }
        } else {
            if (!is_optional and !has_default) {
                std.log.err("missing required field '{s}.{s}'", .{ path, field.name });
            }
        }
    }
}

const root = @import("root.zig");
const std = @import("std");
