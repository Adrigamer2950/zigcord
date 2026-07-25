id: []const u8,
username: []const u8,
discriminator: []const u8 = "",
global_name: ?[]const u8 = null,
avatar: ?[]const u8 = null,
bot: bool = true,
system: bool = false,
mfa_enabled: bool = false,
banner: ?[]const u8 = null,
accent_color: ?u32 = null,
locale: ?[]const u8 = null,
verified: bool = false,
email: ?[]const u8 = null,
flags: u32 = 0,
premium_type: u32 = 0,
public_flags: u32 = 0,
// TODO: avatar_decoration_data
// TOOD: collectibles
// TODO: primary_guild

pub const User = @This();
