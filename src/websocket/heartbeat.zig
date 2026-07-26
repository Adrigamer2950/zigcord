received_heartbeat_ack: bool = true,
last_heartbeat_timestamp: i64 = 0,
last_heartbeat_counter: u64 = 0,

pub fn init(now: i64) Heartbeat {
    return .{
        .last_heartbeat_timestamp = now,
    };
}

// true if we should keep going, false if we should close the socket
pub fn ack_check(self: *Heartbeat, now: i64) !bool {
    if (!self.received_heartbeat_ack and now - self.last_heartbeat_timestamp >= 30000) {
        log.err("no heartbeat has been detected in the last 30 seconds. closing connection...", .{});
        return false;
    }

    return true;
}

pub fn check_and_send_heartbeat(self: *Heartbeat, alloc: std.mem.Allocator, client: *websocket.Client, now: i64, should_send_debug: bool) !void {
    if (self.last_heartbeat_timestamp != 0 and now - self.last_heartbeat_timestamp >= 41250) {
        try self.force_send_heartbeat(alloc, client, now, should_send_debug);
    }
}

fn force_send_heartbeat(self: *Heartbeat, alloc: std.mem.Allocator, client: *websocket.Client, now: i64, should_send_debug: bool) !void {
    const message: struct { op: zigcord.Opcodes, d: u64 } = .{ .op = .heartbeat, .d = self.last_heartbeat_counter };

    self.last_heartbeat_counter += 1;
    self.last_heartbeat_timestamp = now;
    self.received_heartbeat_ack = false;

    const json = zigcord.Util.stringify(alloc, message);
    defer alloc.free(json);

    if (should_send_debug)
        log.debug("sending heartbeat with index {d}", .{self.last_heartbeat_counter});

    try client.write(json);
}

pub fn acknowledge_heartbeat_ack(self: *Heartbeat) void {
    self.received_heartbeat_ack = true;
}

pub fn handle_inbound_heartbeat(self: *Heartbeat, alloc: std.mem.Allocator, io: std.Io, client: *websocket.Client, should_send_debug: bool) !void {
    if (should_send_debug)
        log.debug("received heartbeat packet. sending heartbeat", .{});

    const now = std.Io.Timestamp.now(io, std.Io.Clock.real);
    try self.force_send_heartbeat(alloc, client, now.toMilliseconds(), should_send_debug);
}

pub const Heartbeat = @This();

const log = std.log.scoped(.heartbeat);

const websocket = @import("websocket");
const std = @import("std");

const zigcord = @import("zigcord");
const root = @import("root.zig");
