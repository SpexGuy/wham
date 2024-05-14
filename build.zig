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
            .{ .name = "bfnt", .source = .{ .path = "font/bfnt.zig" } },
        },
    }) catch unreachable;
    app.setBuildMode(mode);
    app.link(.{}) catch unreachable;
    app.install();

    const bake_exe = b.addExecutable("font_bake", "font/bake.zig");
    bake_exe.addPackagePath("zigimg", "mach/examples/libs/zigimg/zigimg.zig");
    bake_exe.setBuildMode(mode);

    const bake_fonts = bake_exe.run();
    bake_fonts.addArg("font/orbitron_32.fnt");

    const bake = b.step("bake", "Bake assets");
    bake.dependOn(&bake_fonts.step);

    const run_cmd = app.run() catch unreachable;
    run_cmd.dependOn(b.getInstallStep());
    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(run_cmd);
}
