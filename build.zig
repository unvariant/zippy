const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zippy", "src/zippy.zig");
    lib.setBuildMode(mode);
    lib.install();

    const tests = b.addTest("src/test.zig");
    tests.setTarget(target);
    tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&tests.step);

    const docs = b.addStaticLibrary("zippy", "src/zippy.zig");
    docs.emit_docs = .{
        .emit_to = "docs",
    };

    const doc_step = b.step("docs", "Build the documentation");
    doc_step.dependOn(&docs.step);
}
