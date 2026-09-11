const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Explicit build options work for installed packages and source builds.
    // Defaults preserve this workspace's current EPICS layout.
    const epics_base = b.option([]const u8, "epics-base", "EPICS Base installation or source root") orelse "/usr/lib/epics";
    const epics_host_arch = b.option([]const u8, "epics-host-arch", "EPICS host architecture (for example linux-x86_64)") orelse "linux-x86_64";
    const default_registrar = if (std.mem.eql(u8, epics_base, "/usr/lib/epics"))
        "/usr/src/debug/epics-base/base-7.0.10/modules/database/src/std/O.linux-x86_64/softIoc_registerRecordDeviceDriver.cpp"
    else
        b.fmt("{s}/modules/database/src/std/O.{s}/softIoc_registerRecordDeviceDriver.cpp", .{ epics_base, epics_host_arch });
    const epics_registrar = b.option([]const u8, "epics-registrar", "Path to softIoc_registerRecordDeviceDriver.cpp") orelse default_registrar;

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "epics_base", epics_base);
    const exe = b.addExecutable(.{
        .name = "pacman-zig-ioc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    exe.root_module.link_libc = true;
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{epics_base}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include/os/Linux", .{epics_base}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include/compiler/gcc", .{epics_base}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/lib/{s}", .{ epics_base, epics_host_arch }) });
    exe.root_module.linkSystemLibrary("dbRecStd", .{});
    exe.root_module.linkSystemLibrary("dbCore", .{});
    exe.root_module.linkSystemLibrary("Com", .{});
    // EPICS packages the standard-record registrar as generated C++ next to
    // Base's debug sources.  A normal Base source build generates this file
    // from softIoc.dbd during its own build.
    exe.root_module.addCSourceFile(.{ .file = .{ .cwd_relative = epics_registrar }, .flags = &.{} });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run the embedded Zig Pacman IOC");
    run_step.dependOn(&run.step);

    const tests = b.addTest(.{ .root_module = exe.root_module });
    const test_step = b.step("test", "Run deterministic game-logic tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
