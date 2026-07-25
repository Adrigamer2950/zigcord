pub fn Extend(comptime Base: type, comptime Extra: type) type {
    const base_fields = @typeInfo(Base).@"struct".fields;
    const extra_fields = @typeInfo(Extra).@"struct".fields;

    const total = base_fields.len + extra_fields.len;

    comptime var names: [total][]const u8 = undefined;
    comptime var types: [total]type = undefined;
    comptime var attrs: [total]std.builtin.Type.StructField.Attributes = undefined;

    inline for (base_fields, 0..) |f, i| {
        names[i] = f.name;
        types[i] = f.type;
        attrs[i] = .{
            .default_value_ptr = f.default_value_ptr,
            .@"comptime" = f.is_comptime,
            .@"align" = f.alignment,
        };
    }

    inline for (extra_fields, 0..) |f, i| {
        names[base_fields.len + i] = f.name;
        types[base_fields.len + i] = f.type;
        attrs[base_fields.len + i] = .{
            .default_value_ptr = f.default_value_ptr,
            .@"comptime" = f.is_comptime,
            .@"align" = f.alignment,
        };
    }

    return @Struct(.auto, null, &names, &types, &attrs);
}

const std = @import("std");
