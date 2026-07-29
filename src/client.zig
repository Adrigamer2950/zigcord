allocator: ?std.mem.Allocator = null,

gateway: *root.Gateway.GatewayClient,
gateway_is_owned: bool,

ws: *root.Ws.WsClient,
ws_is_owned: bool,

pub const ClientOptions = union(enum) {
    create: struct {
        allocator: std.mem.Allocator,
        io: std.Io,
        token: []const u8,
        intents: root.Gateway.Intents,
        dispatcher: root.Gateway.Dispatcher,
        gateway_debug_options: root.Gateway.GatewayClient.GatewayClientDebugOptions = .{},
        ws_debug_options: root.Ws.WsClient.WsClientDebugOptions = .{},
    },

    existing: struct {
        gateway: *root.Gateway.GatewayClient,
        ws: *root.Ws.WsClient,
    },
};

pub fn init(opts: ClientOptions) !@This() {
    switch (opts) {
        .create => |create| {
            const ws_arena = create.allocator.create(std.heap.ArenaAllocator) catch @panic("OOM");
            errdefer create.allocator.destroy(ws_arena);

            ws_arena.* = std.heap.ArenaAllocator.init(create.allocator);
            errdefer ws_arena.deinit();

            const ws_client = create.allocator.create(root.Ws.WsClient) catch @panic("OOM");
            errdefer create.allocator.destroy(ws_client);

            ws_client.* = try root.Ws.WsClient.init(.{
                .arena = ws_arena,
                .io = create.io,
                .host = "gateway.discord.gg",
                .path = "/?v=10&encoding=json",
                .timeout_ms = 2000,
                .debug_options = create.ws_debug_options,
            });
            errdefer ws_client.deinit();

            const gateway_arena = create.allocator.create(std.heap.ArenaAllocator) catch @panic("OOM");
            errdefer create.allocator.destroy(gateway_arena);

            gateway_arena.* = std.heap.ArenaAllocator.init(create.allocator);
            errdefer gateway_arena.deinit();

            const gateway_client = create.allocator.create(root.Gateway.GatewayClient) catch @panic("OOM");
            errdefer create.allocator.destroy(gateway_client);

            gateway_client.* = .init(.{
                .ws_client = ws_client,
                .arena = gateway_arena,
                .io = create.io,
                .token = create.token,
                .intents = create.intents,
                .dispatcher = create.dispatcher,
                .debug_options = create.gateway_debug_options,
            });

            return .{
                .allocator = create.allocator,

                .gateway = gateway_client,
                .gateway_is_owned = true,

                .ws = ws_client,
                .ws_is_owned = true,
            };
        },
        .existing => |existing| {
            return .{
                .gateway = existing.gateway,
                .gateway_is_owned = false,

                .ws = existing.ws,
                .ws_is_owned = false,
            };
        },
    }
}

pub fn shutdown(self: *@This()) void {
    self.gateway.shutdown();
    self.ws.shutdown();
}

pub fn deinit(self: *@This()) void {
    self.shutdown();

    if (self.gateway_is_owned) {
        self.gateway.arena.deinit();
        self.allocator.?.destroy(self.gateway.arena);
        self.allocator.?.destroy(self.gateway);
    }

    if (self.ws_is_owned) {
        self.ws.deinit();
        self.ws.arena.deinit();
        self.allocator.?.destroy(self.ws.arena);
        self.allocator.?.destroy(self.ws);
    }
}

pub fn start(self: *@This()) !void {
    self.gateway.dispatcher.client = self;

    try self.ws.sendHandshake();

    try self.gateway.spawnThread();
    try self.ws.messageLoop();

    self.gateway.shutdown();
    self.gateway.join();
}

pub const Client = @This();

const root = @import("root.zig");

const std = @import("std");
