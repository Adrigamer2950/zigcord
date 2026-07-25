pub const Ready = struct {
    v: root.ApiVersion,
    user: structs.User,
    session_id: []const u8,
    resume_gateway_url: []const u8,
};

const MessageCreateExtraFields = struct {
    guild_id: []const u8,
    // TODO: member,
    // TODO: mentions,
    channel_type: structs.Channel.ChannelType,
};
pub const MessageCreate = util.Extend(structs.Message, MessageCreateExtraFields);

const structs = @import("zigcord").Structs;
const root = @import("root.zig");
const util = @import("./util.zig");

const std = @import("std");
