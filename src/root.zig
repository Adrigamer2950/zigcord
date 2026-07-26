pub const Opcodes = enum(usize) {
    dispatch = 0,
    heartbeat = 1,
    identify = 2,
    presence_update = 3,
    voice_state_update = 4,
    @"resume" = 6,
    reconnect = 7,
    request_guild_members = 8,
    invalid_session = 9,
    hello = 10,
    heartbeat_ack = 11,
    request_soundboard_sounds = 31,
    request_channel_info = 43,

    pub fn jsonStringify(self: Opcodes, jw: anytype) !void {
        try jw.write(@intFromEnum(self));
    }
};

pub const Util = @import("util.zig");
pub const Gateway = @import("gateway/root.zig");
pub const Ws = @import("websocket/root.zig");
pub const Structs = @import("structs/root.zig");
