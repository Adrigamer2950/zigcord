pub fn ready(data: zigcord.Events.Ready) void {
    log.info("ready as {s} ({s})", .{ data.user.username, data.user.id });
}

pub fn message_create(msg: zigcord.Events.MessageCreate) void {
    log.info("message id: {s}", .{msg.id});
    log.info("message content: {s}", .{msg.content});
}

const log = std.log.scoped(.example_listener);

const zigcord = @import("zigcord").Gateway;

const std = @import("std");
