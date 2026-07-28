var client: zigcord.Client = undefined;

fn handleSigint(_: c_int) callconv(.c) void {
    client.shutdown();
}

pub fn main(init: std.process.Init) !void {
    const intents = gateway.Intents.init(&.{
        .guild_messages,
        .message_content,
    });

    client = try .init(.{ .create = .{
        .allocator = init.gpa,
        .io = init.io,
        .token = @embedFile("token.txt"),
        .intents = intents,
        .dispatcher = @import("events/example.zig").DISPATCHER,
    } });
    defer client.deinit();

    const act = std.posix.Sigaction{
        .handler = .{ .handler = @ptrCast(&handleSigint) },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
    std.posix.sigaction(std.posix.SIG.TERM, &act, null);

    try client.start();
}

const zigcord = @import("zigcord");
const ws = zigcord.Ws;
const gateway = zigcord.Gateway;

const std = @import("std");
