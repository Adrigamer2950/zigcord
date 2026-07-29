pub const DISPATCHER: zigcord.Gateway.Dispatcher = .{
    .ready = ready,
    .message_create = messageCreate,
};

pub fn ready(data: zigcord.Gateway.Events.Ready, _: *zigcord.Client) void {
    log.info("ready as {s} ({s})", .{ data.user.username, data.user.id });
}

pub fn messageCreate(msg: zigcord.Gateway.Events.MessageCreate, client: *zigcord.Client) void {
    log.info("message id: {s}", .{msg.id});
    log.info("message content: {s}", .{msg.content});
}

const log = std.log.scoped(.example_listener);

const zigcord = @import("zigcord");
const root = @import("root");

const std = @import("std");
