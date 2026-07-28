thread_should_continue: std.atomic.Value(bool) = .init(true),
thread: ?std.Thread = null,

ws_client: *zigcord.Ws.WsClient,
arena: *std.heap.ArenaAllocator,
io: std.Io,
packet_lookup_interval: u32,
token: []const u8,
intents: root.Intents,
dispatcher: root.Dispatcher,
debug_options: GatewayClientDebugOptions,

pub const GatewayClientOptions = struct {
    ws_client: *zigcord.Ws.WsClient,
    arena: *std.heap.ArenaAllocator,
    io: std.Io,
    packet_lookup_interval: u32 = 50,
    token: []const u8,
    intents: root.Intents,
    dispatcher: root.Dispatcher,
    debug_options: GatewayClientDebugOptions = .{},
};

pub const GatewayClientDebugOptions = struct {
    received_inbound_messages: bool = true,
    received_dispatch_messages: bool = true,
    received_heartbeats: bool = false,
};

pub fn init(opts: GatewayClientOptions) @This() {
    return .{
        .ws_client = opts.ws_client,
        .arena = opts.arena,
        .io = opts.io,
        .packet_lookup_interval = opts.packet_lookup_interval,
        .token = opts.token,
        .intents = opts.intents,
        .dispatcher = opts.dispatcher,
        .debug_options = opts.debug_options,
    };
}

pub fn spawnThread(self: *@This()) !void {
    self.thread = try std.Thread.spawn(.{}, threadLoop, .{self});
}

fn threadLoop(self: *@This()) !void {
    while (self.thread_should_continue.load(.acquire)) {
        try self.io.sleep(std.Io.Duration.fromMilliseconds(self.packet_lookup_interval), std.Io.Clock.real);

        const packets: [][]const u8 = self.ws_client.getAndDropInboundPackets(self.arena.allocator()) catch |err| {
            log.err("error trying to receive inbound packets: {any}", .{err});
            continue;
        };
        defer self.arena.allocator().free(packets);

        for (packets) |raw_data| {
            if (std.mem.eql(u8, raw_data, zigcord.Ws.CLOSE_PACKET_SIGNAL)) {
                self.shutdown();
                break;
            }

            const data = std.json.parseFromSlice(
                std.json.Value,
                self.arena.allocator(),
                raw_data,
                .{ .ignore_unknown_fields = true },
            ) catch |err| {
                log.err("error trying to parse json message: {any}", .{err});
                continue;
            };
            defer data.deinit();

            const op_int = data.value.object.get("op") orelse {
                log.warn("received invalid packet with no 'op' field", .{});
                continue;
            };
            const op: zigcord.Opcodes = @enumFromInt(op_int.integer);

            const d = data.value.object.get("d") orelse {
                log.warn("received invalid packet with no 'd' field", .{});
                continue;
            };

            // will be freed after the packet is handled
            var packet_arena = std.heap.ArenaAllocator.init(self.arena.allocator());

            if (self.debug_options.received_inbound_messages)
                log.debug("received message '{s}'", .{@tagName(op)});

            switch (op) {
                .dispatch => {
                    const t_value = data.value.object.get("t") orelse {
                        log.warn("received invalid 'dispatch' message without a 't' field", .{});
                        continue;
                    };
                    const t_str = t_value.string;

                    if (self.debug_options.received_dispatch_messages)
                        log.debug("received dispatch event '{s}'", .{t_str});

                    const dp_event = root.Dispatcher.parseDispatch(packet_arena.allocator(), t_str, d) catch |err| {
                        log.err("error trying to parse dispatch event '{s}': {any}", .{ t_str, err });
                        continue;
                    };

                    switch (dp_event) {
                        inline else => |msg| {
                            self.dispatcher.fireEvent(@TypeOf(msg), msg);
                        },
                    }
                },
                .heartbeat => {
                    self.ws_client.handle_inbound_heartbeat() catch |err| {
                        log.err("error trying to send 'heartbeat' message: {any}", .{err});
                    };
                },
                .hello => {
                    const token = std.mem.replaceOwned(u8, packet_arena.allocator(), self.token, "\n", "") catch @panic("OOM");
                    defer packet_arena.allocator().free(token);

                    const identify: root.Messages.Packet = .{
                        .data = .{ .identify = .{
                            .op = .identify,
                            .d = .{
                                .token = token,
                                .properties = .{
                                    .os = @import("builtin").os.tag,
                                    .library = "zigcord",
                                    .device = "zigcord",
                                },
                                .intents = self.intents,
                            },
                        } },
                        .arena = &packet_arena,
                    };

                    const json = zigcord.Util.stringify(packet_arena.allocator(), identify.data.identify);
                    defer packet_arena.allocator().free(json);

                    self.ws_client.addOutboundPacket(json) catch |err| {
                        log.err("error trying to add outbound packet to queue: {any}", .{err});
                    };
                },
                .heartbeat_ack => {
                    if (self.debug_options.received_heartbeats)
                        log.debug("received heartbeat ack", .{});

                    self.ws_client.acknowledge_heartbeat_ack();
                },
                else => {},
            }
        }
    }
}

pub fn join(self: *@This()) void {
    if (self.thread) |t| {
        t.join();
        self.thread = null;
    }
}

pub fn shutdown(self: *@This()) void {
    self.thread_should_continue.store(false, .release);
}

pub const GatewayClient = @This();

const log = std.log.scoped(.gateway);

const root = @import("root.zig");
const zigcord = @import("zigcord");

const std = @import("std");
