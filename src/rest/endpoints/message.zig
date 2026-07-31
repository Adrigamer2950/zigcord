pub const GetMessages = struct {
    pub const PATH = "channels/{s}/messages?{s}";

    time: ?union(enum) {
        around: []const u8,
        before: []const u8,
        after: []const u8,
    } = null,
    limit: usize = 50,
};

pub const SearchGuildMessages = struct {
    pub const PATH = "guilds/{s}/messages/search?{s}";

    limit: u32 = 25,
    offset: u32 = 0,
    max_id: ?[]const u8 = null,
    min_id: ?[]const u8 = null,
    slop: u32 = 100,
    content: ?[]const u8 = null,
    channel_id: ?[][]const u8 = null,
    author_type: ?[]enum(u8) {
        user,
        bot,
        webhook,
    } = null,
    author_id: ?[][]const u8 = null,
    mentions: ?[][]const u8 = null,
    mentions_role_id: ?[][]const u8 = null,
    mention_everyone: bool = false,
    replied_to_user_id: ?[][]const u8 = null,
    replied_to_message_id: ?[][]const u8 = null,
    pinned: bool = false,
    has: ?[]enum(u8) {
        image,
        sound,
        video,
        file,
        sticker,
        embed,
        link,
        poll,
        snapshot,
    } = null,
    embed_type: ?[]enum(u8) {
        image,
        video,
        gif,
        sound,
        article,
    } = null,
    embed_provider: ?[][]const u8 = null,
    link_hostname: ?[][]const u8 = null,
    attachment_filename: ?[][]const u8 = null,
    attachment_extension: ?[][]const u8 = null,
    sort_by: ?enum(u8) {
        timestamp,
        relevance,
    } = null,
    sort_order: ?[]const u8 = null,
    include_nsfw: bool = false,

    pub const Response = struct {
        messages: [][]zigcord.Structs.Message,
        doing_deep_historical_index: bool,
        total_results: u32,
        documents_indexed: ?u32 = 0,
        // TODO: threads
        // TODO: members
    };
};

pub const GetMessage = struct {
    pub const PATH = "channels/{s}/messages/{s}";
};

pub const CreateMessage = struct {
    pub const PATH = "channels/{s}/messages";

    content: ?[]const u8 = null,
    nonce: ?[]const u8 = null,
    tts: bool = false,
    // TODO: embeds
    // TODO: allowed_mentions
    message_reference: ?zigcord.Structs.Message.MessageReference = null,
    // TODO: components
    // TODO: sticker_ids
    // TODO: files
    // TODO: payload_json
    // TODO: attachments
    flags: u32 = 0,
    enforce_nonce: bool = false,
    // TODO: poll
    // TODO: shared_client_theme
};

pub const CrosspostMessage = struct {
    pub const PATH = "channels/{s}/messages/{s}/crosspost";
};

pub const CreateReaction = struct {
    pub const PATH = "channels/{s}/messages/{s}/reactions/{s}/@me";
};

pub const DeleteOwnReaction = struct {
    pub const PATH = "channels/{s}/messages/{s}/reactions/{s}/@me";
};

pub const DeleteUserReaction = struct {
    pub const PATH = "channels/{s}/messages/{s}/reactions/{s}/{s}";
};

pub const GetReactions = struct {
    pub const PATH = "channels/{s}/messages/{s}/reactions/{s}";
};

pub const DeleteAllReactions = struct {
    pub const PATH = "channels/{s}/messages/{s}/reactions";
};

pub const DeleteAllReactionsForEmoji = struct {
    pub const PATH = "channels/{s}/messages/{s}/reactions/{s}";
};

pub const EditMessage = struct {
    pub const PATH = "channels/{s}/messages/{s}";

    content: []const u8,
    // TODO: embeds
    // TODO: flags
    // TODO: allowed_mentions
    // TODO: components
    // TODO: files
    // TODO: payload_json
    // TODO: attachments
};

pub const DeleteMessage = struct {
    pub const PATH = "channels/{s}/messages/{s}";
};

pub const BulkDeleteMessages = struct {
    pub const PATH = "channels/{s}/messages/bulk-delete";

    messages: [][]const u8,
};

pub const GetChannelPins = struct {
    pub const PATH = "channels/{s}/messages/pins";

    before: ?[]const u8 = null, // ISO8601 timestamp
    limit: u32 = 50,

    pub const Response = struct {
        items: []struct {
            pinned_at: []const u8, // ISO8601 timestamp
            message: zigcord.Structs.Message,
        },
        has_more: bool,
    };
};

pub const PinMessage = struct {
    pub const PATH = "channels/{s}/messages/pins/{s}";
};

pub const UnPinMessage = struct {
    pub const PATH = "channels/{s}/messages/pins/{s}";
};

pub fn getMessages(rest: *root.RestClient, channel_id: []const u8, payload: GetMessages) !std.json.Parsed([]zigcord.Structs.Message) {
    const query = try root.http.buildQuery(rest.arena.allocator(), payload);
    defer rest.arena.allocator().free(query);

    return try rest.get([]zigcord.Structs.Message, GetMessages.PATH, .{ channel_id, query });
}

pub fn searchMessages(rest: *root.RestClient, guild_id: []const u8, payload: SearchGuildMessages) !std.json.Parsed(SearchGuildMessages.Response) {
    const query = try root.http.buildQuery(rest.arena.allocator(), payload);
    defer rest.arena.allocator().free(query);

    return try rest.get(SearchGuildMessages.Response, SearchGuildMessages.PATH, .{ guild_id, query });
}

pub fn getMessage(rest: *root.RestClient, channel_id: []const u8, message_id: []const u8) !std.json.Parsed(zigcord.Structs.Message) {
    return try rest.get(zigcord.Structs.Message, GetMessage.PATH, .{ channel_id, message_id });
}

pub fn sendMessage(rest: *root.RestClient, channel_id: []const u8, payload: CreateMessage) !std.json.Parsed(zigcord.Structs.Message) {
    return try rest.post(zigcord.Structs.Message, CreateMessage.PATH, .{channel_id}, payload);
}

pub fn crosspostMessage(rest: *root.RestClient, channel_id: []const u8, message_id: []const u8) !std.json.Parsed(zigcord.Structs.Message) {
    return try rest.post(zigcord.Structs.Message, CrosspostMessage.PATH, .{ channel_id, message_id });
}

pub fn createReaction(
    rest: *root.RestClient,
    channel_id: []const u8,
    message_id: []const u8,
    emoji_id: []const u8,
) !void {
    try rest.put(void, CreateReaction.PATH, .{ channel_id, message_id, emoji_id }, null);
}

pub fn deleteOwnReaction(
    rest: *root.RestClient,
    channel_id: []const u8,
    message_id: []const u8,
    emoji_id: []const u8,
) !void {
    const buf = std.ArrayList(u8).initCapacity(rest.arena.allocator(), 1) catch @panic("OOM");
    defer buf.deinit(rest.arena.allocator());

    buf.appendSlice(rest.arena.allocator(), emoji_id);

    try rest.delete(void, DeleteOwnReaction.PATH, .{ channel_id, message_id, buf.items }, null);
}

pub fn deleteUserReaction(
    rest: *root.RestClient,
    channel_id: []const u8,
    message_id: []const u8,
    emoji_id: []const u8,
    user_id: []const u8,
) !void {
    const buf = std.ArrayList(u8).initCapacity(rest.arena.allocator(), 1) catch @panic("OOM");
    defer buf.deinit(rest.arena.allocator());

    buf.appendSlice(rest.arena.allocator(), emoji_id);

    try rest.delete(void, DeleteUserReaction.PATH, .{ channel_id, message_id, buf.items, user_id }, null);
}

pub fn getReactions(
    rest: *root.RestClient,
    channel_id: []const u8,
    message_id: []const u8,
    emoji_id: []const u8,
) !std.json.Parsed([]zigcord.Structs.User) {
    const buf = std.ArrayList(u8).initCapacity(rest.arena.allocator(), 1) catch @panic("OOM");
    defer buf.deinit(rest.arena.allocator());

    buf.appendSlice(rest.arena.allocator(), emoji_id);

    return try rest.get([]zigcord.Structs.User, GetReactions.PATH, .{ channel_id, message_id, buf.items });
}

pub fn deleteAllReactions(rest: *root.RestClient, channel_id: []const u8, message_id: []const u8) !void {
    try rest.delete(void, DeleteAllReactions.PATH, .{ channel_id, message_id }, null);
}

pub fn deleteAllReactionsForEmoji(
    rest: *root.RestClient,
    channel_id: []const u8,
    message_id: []const u8,
    emoji_id: []const u8,
) !void {
    const buf = std.ArrayList(u8).initCapacity(rest.arena.allocator(), 1) catch @panic("OOM");
    defer buf.deinit(rest.arena.allocator());

    buf.appendSlice(rest.arena.allocator(), emoji_id);

    try rest.delete(void, DeleteAllReactionsForEmoji.PATH, .{ channel_id, message_id, buf.items }, null);
}

pub fn editMessage(
    rest: *root.RestClient,
    channel_id: []const u8,
    message_id: []const u8,
    payload: EditMessage,
) !std.json.Parsed(zigcord.Structs.Message) {
    return try rest.patch(zigcord.Structs.Message, EditMessage.PATH, .{ channel_id, message_id }, payload);
}

// TODO: add "X-Audit-Log-Reason" header
pub fn deleteMessage(
    rest: *root.RestClient,
    channel_id: []const u8,
    message_id: []const u8,
) !std.json.Parsed(zigcord.Structs.Message) {
    return try rest.delete(zigcord.Structs.Message, DeleteMessage.PATH, .{ channel_id, message_id }, null);
}

pub fn bulkDeleteMessages(rest: *root.RestClient, channel_id: []const u8, payload: BulkDeleteMessages) !void {
    try rest.post(void, BulkDeleteMessages.PATH, .{channel_id}, payload);
}

pub fn getChannelPins(rest: *root.RestClient, channel_id: []const u8, payload: GetChannelPins) !std.json.ParseError(GetChannelPins.Response) {
    return try rest.get(GetChannelPins.Response, GetChannelPins.PATH, .{channel_id}, payload);
}

// TODO: add "X-Audit-Log-Reason" header
pub fn pinMessage(rest: *root.RestClient, channel_id: []const u8, message_id: []const u8) !void {
    try rest.put(void, PinMessage.PATH, .{ channel_id, message_id }, null);
}

// TODO: add "X-Audit-Log-Reason" header
pub fn unPinMessage(rest: *root.RestClient, channel_id: []const u8, message_id: []const u8) !void {
    try rest.delete(void, PinMessage.PATH, .{ channel_id, message_id }, null);
}

const root = @import("../root.zig");
const zigcord = @import("zigcord");
const std = @import("std");
