const std = @import("std");
const mach = @import("mach/build.zig");
const build_zmath = @import("mach/examples/libs/zmath/build.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const app = mach.App.init(b, .{
        .name = "wham",
        .src = "src/main.zig",
        .target = target,
        .deps = &[_]std.build.Pkg{
            .{ .name = "zmath", .source = .{ .path = "mach/examples/libs/zmath/src/zmath.zig" } },
        },
    }) catch unreachable;
    app.setBuildMode(mode);
    app.link(.{}) catch unreachable;
    app.install();

    const run_cmd = app.run() catch unreachable;
    run_cmd.dependOn(b.getInstallStep());
    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(run_cmd);
}
