const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const websocket = b.dependency("websocket", .{
        .target = target,
        .optimize = optimize,
    });

    const zigcord = b.addModule("zigcord", .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            .{ .name = "websocket", .module = websocket.module("websocket") },
        },
        .target = target,
        .optimize = optimize,
    });
    zigcord.addImport("zigcord", zigcord);

    const example_exe = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example/src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigcord", .module = zigcord },
            },
        }),
    });

    b.installArtifact(example_exe);

    const run_example_step = b.step("run-example", "Run example");

    const run_example_cmd = b.addRunArtifact(example_exe);
    run_example_step.dependOn(&run_example_cmd.step);

    run_example_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_example_cmd.addArgs(args);
    }
}
