token: []const u8,
auth_header: []const u8,
api_version: zigcord.Gateway.ApiVersion,

arena: *std.heap.ArenaAllocator,
io: std.Io,
http_client: *std.http.Client,

pub const BASE_URL = "https://discord.com/api";

pub const RestClientOptions = struct {
    arena: *std.heap.ArenaAllocator,
    io: std.Io,
    token: []const u8,
    api_version: zigcord.Gateway.ApiVersion = .v10,
};

pub fn init(opts: RestClientOptions) RestClient {
    const http_client = opts.arena.allocator().create(std.http.Client) catch @panic("OOM");
    http_client.* = std.http.Client{
        .allocator = opts.arena.allocator(),
        .io = opts.io,
    };

    return .{
        .token = opts.token,
        .auth_header = std.fmt.allocPrint(opts.arena.allocator(), "Bot {s}", .{opts.token}) catch @panic("OOM"),
        .api_version = opts.api_version,
        .arena = opts.arena,
        .io = opts.io,
        .http_client = http_client,
    };
}

pub fn deinit(self: RestClient) void {
    self.http_client.deinit();
    self.arena.allocator().destroy(self.http_client);

    self.arena.allocator().free(self.auth_header);
}

pub fn request(
    self: RestClient,
    method: std.http.Method,
    ReturnType: type,
    comptime path_fmt: []const u8,
    path_args: anytype,
    payload: anytype,
) !if (ReturnType == void) void else std.json.Parsed(ReturnType) {
    var req_arena = std.heap.ArenaAllocator.init(self.arena.child_allocator);
    defer req_arena.deinit();

    const path = if (std.mem.count(u8, path_fmt, "{s}") > 0) blk: {
        const alloc = std.fmt.allocPrint(req_arena.allocator(), path_fmt, path_args) catch @panic("OOM");
        break :blk alloc;
    } else path_fmt;

    const has_payload = comptime @TypeOf(payload) != @TypeOf(null);

    const url = std.fmt.allocPrint(
        req_arena.allocator(),
        "{s}/{s}/{s}",
        .{
            BASE_URL,
            @tagName(self.api_version),
            path,
        },
    ) catch @panic("OOM");

    const uri = try std.Uri.parse(url);

    var req = try self.http_client.request(
        method,
        uri,
        .{ .headers = .{
            .authorization = .{ .override = self.auth_header },
            .accept_encoding = .{ .override = "identity" },
            .content_type = .{ .override = "application/json" },
        } },
    );
    defer req.deinit();

    if (has_payload) {
        const json_payload = zigcord.Util.stringify(req_arena.allocator(), payload);
        try req.sendBodyComplete(json_payload);
    } else if (method.requestHasBody()) {
        try req.sendBodyComplete("");
    } else {
        try req.sendBodiless();
    }

    var redirect_buffer: [1024]u8 = undefined;
    var response = try req.receiveHead(&redirect_buffer);

    var transfer_buffer: [1024]u8 = undefined;
    var body_reader = response.reader(&transfer_buffer);

    var body = std.ArrayList(u8).empty;
    defer body.deinit(req_arena.allocator());

    var read_buf: [8192]u8 = undefined;
    while (true) {
        const n = try body_reader.readSliceShort(&read_buf);
        if (n == 0) break;
        try body.appendSlice(req_arena.allocator(), read_buf[0..n]);
    }

    std.log.debug("status: {any}", .{response.head.status});

    const wants_body = ReturnType != void;

    if (wants_body) {
        return parseJson(ReturnType, self.arena.allocator(), body.items);
    }
}

pub fn parseJson(ReturnType: type, allocator: std.mem.Allocator, json: []u8) !std.json.Parsed(ReturnType) {
    return try std.json.parseFromSlice(
        ReturnType,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
}

pub fn get(
    self: RestClient,
    ReturnType: type,
    comptime path_fmt: []const u8,
    path_args: anytype,
) !if (ReturnType == void) void else std.json.Parsed(ReturnType) {
    return try self.request(.GET, ReturnType, path_fmt, path_args, null);
}

pub fn post(
    self: RestClient,
    ReturnType: type,
    comptime path_fmt: []const u8,
    path_args: anytype,
    payload: anytype,
) !if (ReturnType == void) void else std.json.Parsed(ReturnType) {
    return try self.request(.POST, ReturnType, path_fmt, path_args, payload);
}

pub fn put(
    self: RestClient,
    ReturnType: type,
    comptime path_fmt: []const u8,
    path_args: anytype,
    payload: anytype,
) !if (ReturnType == void) void else std.json.Parsed(ReturnType) {
    return try self.request(.PUT, ReturnType, path_fmt, path_args, payload);
}

pub fn delete(
    self: RestClient,
    ReturnType: type,
    comptime path_fmt: []const u8,
    path_args: anytype,
    payload: anytype,
) !if (ReturnType == void) void else std.json.Parsed(ReturnType) {
    return try self.request(.DELETE, ReturnType, path_fmt, path_args, payload);
}

pub fn patch(
    self: RestClient,
    ReturnType: type,
    comptime path_fmt: []const u8,
    path_args: anytype,
    payload: anytype,
) !if (ReturnType == void) void else std.json.Parsed(ReturnType) {
    return try self.request(.PATCH, ReturnType, path_fmt, path_args, payload);
}

pub const RestClient = @This();

const root = @import("root.zig");
const zigcord = @import("zigcord");

const std = @import("std");
