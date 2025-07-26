const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
        .linux_display_backend = .X11,
    });
    const raylib = raylib_dep.artifact("raylib");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "DogFight2025",
        .root_module = exe_mod,
    });
    exe.linkLibrary(raylib);

    // Add check step for ZLS - try this when I've got zig build test working again!
    // const exe_check = b.addExecutable(.{
    //     .name = "DogFight2025-check",
    //     .root_module = exe_mod,
    // });
    // const check = b.step("check", "Check if DogFight compiles");
    // check.dependOn(&exe_check.step);

    b.installArtifact(exe);

    const asset_dir = b.path("assets/");
    const install_step = b.addInstallDirectory(.{
        .source_dir = asset_dir,
        .install_dir = .bin,
        .install_subdir = "assets/",
    });

    b.getInstallStep().dependOn(&install_step.step);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
