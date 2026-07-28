var ws_client: ws.WsClient = undefined;
var gateway_client: gateway.GatewayClient = undefined;

fn handleSigint(_: c_int) callconv(.c) void {
    ws_client.shutdown();

    gateway_client.shutdown();
    gateway_client.join();
}

pub fn main(init: std.process.Init) !void {
    var ws_arena = std.heap.ArenaAllocator.init(init.gpa);
    defer ws_arena.deinit();

    ws_client = try ws.WsClient.init(.{
        .allocator = ws_arena.allocator(),
        .io = init.io,
        .host = "gateway.discord.gg",
        .path = "/?v=10&encoding=json",
        .timeout_ms = 2000,
    });
    defer ws_client.deinit();

    try ws_client.sendHandshake();

    var intents: gateway.Intents = .init;
    intents.addIntent(.guild_messages);
    intents.addIntent(.message_content);

    var gateway_arena = std.heap.ArenaAllocator.init(init.gpa);
    defer gateway_arena.deinit();

    gateway_client = .init(.{
        .ws_client = &ws_client,
        .allocator = gateway_arena.allocator(),
        .io = init.io,
        .token = @embedFile("token.txt"),
        .intents = intents,
        .dispatcher = example_listener.DISPATCHER,
    });

    const act = std.posix.Sigaction{
        .handler = .{ .handler = @ptrCast(&handleSigint) },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
    std.posix.sigaction(std.posix.SIG.TERM, &act, null);

    try gateway_client.spawnThread();
    try ws_client.messageLoop();

    gateway_client.shutdown();
    gateway_client.join();
}

const example_listener = @import("events/example.zig");
const zigcord = @import("zigcord");
const ws = zigcord.Ws;
const gateway = zigcord.Gateway;

const std = @import("std");
