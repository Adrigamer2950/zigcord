pub const GatewayClient = @import("client.zig").GatewayClient;
pub const Messages = @import("messages.zig");
pub const Events = @import("events.zig");
pub const Dispatcher = @import("dispatcher.zig");

pub const Intents = struct {
    bits: u64 = 0,

    pub fn init(bits: []const Bits) Intents {
        var intents: Intents = .{};

        intents.addIntents(bits);

        return intents;
    }

    pub fn addIntent(self: *Intents, intent: Bits) void {
        self.bits = self.bits | @intFromEnum(intent);
    }

    pub fn addIntents(self: *Intents, intents: []const Bits) void {
        for (intents) |intent| {
            self.addIntent(intent);
        }
    }

    pub fn jsonStringify(self: Intents, jw: anytype) !void {
        try jw.write(self.bits);
    }

    const Bits = enum(u64) {
        guilds = 1 << 0,
        guild_members = 1 << 1,
        guild_moderation = 1 << 2,
        guild_expressions = 1 << 3,
        guild_integrations = 1 << 4,
        guild_webhooks = 1 << 5,
        guild_invites = 1 << 6,
        guild_voice_states = 1 << 7,
        guild_presences = 1 << 8,
        guild_messages = 1 << 9,
        guild_message_reactions = 1 << 10,
        guild_message_typing = 1 << 11,
        direct_messages = 1 << 12,
        direct_message_reactions = 1 << 13,
        direct_message_typing = 1 << 14,
        message_content = 1 << 15,
        guild_scheduled_events = 1 << 16,
        auto_moderation_configuration = 1 << 20,
        auto_moderation_execution = 1 << 21,
    };
};

pub const ApiVersion = enum(u8) {
    v10 = 10,
};

const ws = @import("ws");
const std = @import("std");
