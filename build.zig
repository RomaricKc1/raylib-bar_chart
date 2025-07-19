const std = @import("std");

/// Lib name.
const version = "0.1.0";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // mods
    const mod = b.addModule("raylib_bar_chart", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // deps
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const exe = b.addExecutable(.{
        .name = "raylib_bar_chart",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib_bar_chart", .module = mod },
            },
        }),
    });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    mod.linkLibrary(raylib_artifact);
    mod.addImport("raylib", raylib);
    mod.addImport("raygui", raylib);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .name = "mod",
        .root_module = mod,
    });
    const exe_tests = b.addTest(.{
        .name = "exe",
        .root_module = exe.root_module,
    });

    // code coverage
    const allocator = std.heap.page_allocator;
    const xgd_home = std.process.getEnvVarOwned(allocator, "HOME") catch "";
    defer allocator.free(xgd_home);
    const exclude_pat = b.fmt("--exclude-path={s}/.cache/zig", .{xgd_home});

    const code_cov = b.option(bool, "test_coverage", "Gen the code coverage") orelse false;
    const arg: []const ?[]const u8 = &[_]?[]const u8{
        "kcov",
        "--clean",
        exclude_pat,
        "--include-pattern=src/",
        "kcov-out",
        null,
    };

    if (code_cov) {
        mod_tests.setExecCmd(arg);
        exe_tests.setExecCmd(arg);
    }

    const run_mod_tests = b.addRunArtifact(mod_tests);
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);
}
