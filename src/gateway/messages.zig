pub const PacketData = union(enum) {
    dispatch: Message(DispatchEvent),
    heartbeat: Message(u64),
    identify: Message(Identify),
    hello: Message(Hello),
    heartbeat_ack: Message(?u1),

    pub fn jsonStringify(self: PacketData, jw: anytype) !void {
        switch (self) {
            inline else => |message| try jw.write(message),
        }
    }
};

pub const Packet = struct {
    data: PacketData,
    arena: *std.heap.ArenaAllocator,

    pub fn deinit(self: Packet) void {
        self.arena.deinit();
    }

    pub fn jsonStringify(self: Packet, jw: anytype) !void {
        try jw.write(self.data);
    }
};

pub fn Message(T: type) type {
    return struct {
        t: ?[]const u8 = null,
        s: ?u64 = null,
        op: zigcord.Opcodes,
        d: Data,

        pub const Data = T;
    };
}

pub const DispatchEvent = union(enum) {
    READY: root.Events.Ready,
    MESSAGE_CREATE: root.Events.MessageCreate,
    unknown: void,
};

pub const Hello = struct {
    heartbeat_interval: u32,
};

pub const Identify = struct {
    token: []const u8,
    properties: ConnectionProperties,
    intents: root.Intents,

    pub const ConnectionProperties = struct {
        os: std.Target.Os.Tag,
        library: []const u8,
        device: []const u8,
    };
};

const root = @import("root.zig");
const zigcord = @import("zigcord");
const ws = zigcord.Ws;

const std = @import("std");
