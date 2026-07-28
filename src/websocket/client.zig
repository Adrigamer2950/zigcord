loop_should_continue: std.atomic.Value(bool) = .init(true),

arena: *std.heap.ArenaAllocator,
io: std.Io,
client: *websocket.Client,
handshake_host: []const u8,
handshake_port: u16,
handshake_path: []const u8,
handshake_headers: []const u8,
handshake_timeout_ms: u32,
message_lookup_interval: u32,
heartbeat: *root.Heartbeat,
debug_options: WsClientDebugOptions,

inbound_packets_mutex: std.Io.Mutex = .init,
inbound_packets: std.ArrayList([]const u8) = .empty,

outbound_packets_mutex: std.Io.Mutex = .init,
outbound_packets: std.ArrayList([]const u8) = .empty,

pub const WsClientOptions = struct {
    arena: *std.heap.ArenaAllocator,
    io: std.Io,
    host: []const u8,
    port: u16 = 443,
    path: []const u8,
    headers: []const u8 = "",
    timeout_ms: u32 = 5000,
    message_lookup_interval: u32 = 50,
    debug_options: WsClientDebugOptions = .{},
};

pub const WsClientDebugOptions = struct {
    ws_handshake_result: bool = true,
    sent_outbound_messages: bool = false,
    received_raw_inbound_messages: bool = false,
    sent_heartbeats: bool = false,
};

pub fn init(opts: WsClientOptions) !WsClient {
    const client = try opts.arena.allocator().create(websocket.Client);
    errdefer opts.arena.allocator().destroy(client);

    client.* = try websocket.Client.init(opts.io, opts.arena.allocator(), .{
        .host = opts.host,
        .port = opts.port,
        .tls = true,
    });

    const heartbeat = opts.arena.allocator().create(root.Heartbeat) catch @panic("OOM");
    errdefer opts.arena.allocator().destroy(heartbeat);
    heartbeat.* = .init(std.Io.Timestamp.now(opts.io, std.Io.Clock.real).toMilliseconds());

    return .{
        .arena = opts.arena,
        .io = opts.io,
        .client = client,
        .handshake_host = opts.host,
        .handshake_port = opts.port,
        .handshake_path = opts.path,
        .handshake_headers = opts.headers,
        .handshake_timeout_ms = opts.timeout_ms,
        .message_lookup_interval = opts.message_lookup_interval,
        .heartbeat = heartbeat,
        .debug_options = opts.debug_options,
    };
}

pub fn deinit(self: *WsClient) void {
    self.shutdown();
    self.client.deinit();
    self.arena.allocator().destroy(self.client);
    self.arena.allocator().destroy(self.heartbeat);
}

pub fn addInboundPacket(self: *@This(), raw_data: []const u8) !void {
    const owned_raw_data = self.arena.allocator().dupe(u8, raw_data) catch @panic("OOM");

    try self.inbound_packets_mutex.lock(self.io);
    defer self.inbound_packets_mutex.unlock(self.io);

    self.inbound_packets.append(self.arena.allocator(), owned_raw_data) catch @panic("OOM");
}

pub fn getAndDropInboundPackets(self: *@This(), allocator: std.mem.Allocator) ![][]const u8 {
    try self.inbound_packets_mutex.lock(self.io);
    defer self.inbound_packets_mutex.unlock(self.io);

    const items = allocator.dupe([]const u8, self.inbound_packets.items) catch @panic("OOM");
    self.inbound_packets.clearAndFree(self.arena.allocator());

    return items;
}

pub fn addOutboundPacket(self: *@This(), raw_data: []const u8) !void {
    const owned = self.arena.allocator().dupe(u8, raw_data) catch @panic("OOM");

    try self.outbound_packets_mutex.lock(self.io);
    defer self.outbound_packets_mutex.unlock(self.io);

    self.outbound_packets.append(self.arena.allocator(), owned) catch @panic("OOM");
}

pub fn getAndDropOutboundPackets(self: *@This()) ![][]const u8 {
    try self.outbound_packets_mutex.lock(self.io);
    defer self.outbound_packets_mutex.unlock(self.io);

    const items = self.arena.allocator().dupe([]const u8, self.outbound_packets.items) catch @panic("OOM");
    self.outbound_packets.clearAndFree(self.arena.allocator());

    return items;
}

pub fn acknowledge_heartbeat_ack(self: *WsClient) void {
    self.heartbeat.acknowledge_heartbeat_ack();
}

pub fn handle_inbound_heartbeat(self: *WsClient) !void {
    try self.heartbeat.handle_inbound_heartbeat(self.arena.allocator(), self.io, self.client, self.debug_options.sent_heartbeats);
}

pub fn sendHandshake(self: *WsClient) !void {
    const headers = std.fmt.allocPrint(self.arena.allocator(), "Host: {s}\r\n{s}", .{ self.handshake_host, self.handshake_headers }) catch @panic("OOM");
    defer self.arena.allocator().free(headers);

    try self.client.handshake(self.handshake_path, .{
        .timeout_ms = self.handshake_timeout_ms,
        .headers = headers,
    });

    if (self.debug_options.ws_handshake_result)
        log.debug("ws handshake for wss://{s}{s} was successful", .{ self.handshake_host, self.handshake_path });
}

pub fn shutdown(self: *WsClient) void {
    self.loop_should_continue.store(false, .release);
}

pub fn messageLoop(self: *WsClient) !void {
    try self.client.readTimeout(self.message_lookup_interval);

    while (self.loop_should_continue.load(.acquire)) {
        const now = std.Io.Timestamp.now(self.io, std.Io.Clock.real);

        if (!try self.heartbeat.ack_check(now.toMilliseconds())) {
            try self.client.close(.{ .code = 3008, .reason = "haven't received heartbeat_ack in 30 secs since last heartbeat" });
            break;
        }

        try self.heartbeat.check_and_send_heartbeat(self.arena.allocator(), self.client, now.toMilliseconds(), self.debug_options.sent_heartbeats);

        const outbound_packets = try self.getAndDropOutboundPackets();
        defer self.arena.allocator().free(outbound_packets);

        for (outbound_packets) |raw_data| {
            if (self.debug_options.sent_outbound_messages)
                log.debug("sending outbound packet: {s}", .{raw_data});

            try self.client.write(@constCast(raw_data));
        }

        const message = (self.client.read() catch |err| {
            if (self.loop_should_continue.load(.acquire)) continue;

            return err;
        }) orelse continue;
        defer self.client.done(message);

        switch (message.type) {
            .text, .binary => {
                if (self.debug_options.received_raw_inbound_messages)
                    log.debug("received inbound packet: {s}", .{message.data});

                try self.addInboundPacket(message.data);
            },
            .ping => try self.client.writePong(message.data),
            .pong => {},
            .close => {
                try self.client.close(.{});
                break;
            },
        }
    }

    log.debug("closing websocket connection", .{});

    try self.addInboundPacket(root.CLOSE_PACKET_SIGNAL);

    try self.client.close(.{
        .code = 1000,
    });
}

pub const WsClient = @This();

const log = std.log.scoped(.ws);

const websocket = @import("websocket");

const root = @import("root.zig");

const std = @import("std");
