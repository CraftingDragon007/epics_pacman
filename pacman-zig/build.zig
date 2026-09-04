const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "pacman-zig-ioc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.link_libc = true;
    exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/lib/epics/include" });
    exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/lib/epics/include/os/Linux" });
    exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/lib/epics/include/compiler/gcc" });
    exe.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib/epics/lib/linux-x86_64" });
    exe.root_module.linkSystemLibrary("dbRecStd", .{});
    exe.root_module.linkSystemLibrary("dbCore", .{});
    exe.root_module.linkSystemLibrary("Com", .{});
    // EPICS packages the standard-record registrar as generated C++ next to
    // Base's debug sources.  A normal Base source build generates this file
    // from softIoc.dbd during its own build.
    exe.root_module.addCSourceFile(.{ .file = .{ .cwd_relative = "/usr/src/debug/epics-base/base-7.0.10/modules/database/src/std/O.linux-x86_64/softIoc_registerRecordDeviceDriver.cpp" }, .flags = &.{} });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run the embedded Zig Pacman IOC");
    run_step.dependOn(&run.step);

    const tests = b.addTest(.{ .root_module = exe.root_module });
    const test_step = b.step("test", "Run deterministic game-logic tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
