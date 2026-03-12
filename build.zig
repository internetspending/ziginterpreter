const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ast_mod = b.createModule(.{
        .root_source_file = b.path("src/ast.zig"),
    });
    const value_mod = b.createModule(.{
        .root_source_file = b.path("src/value.zig"),
    });
    const env_mod = b.createModule(.{
        .root_source_file = b.path("src/env.zig"),
    });
    const examples_mod = b.createModule(.{
        .root_source_file = b.path("src/examples.zig"),
    });
    const interp_mod = b.createModule(.{
        .root_source_file = b.path("src/interp.zig"),
    });

    // wire up internal dependencies
    value_mod.addImport("ast.zig", ast_mod);
    env_mod.addImport("value.zig", value_mod);
    env_mod.addImport("ast.zig", ast_mod);
    examples_mod.addImport("ast.zig", ast_mod);
    interp_mod.addImport("ast.zig", ast_mod);
    interp_mod.addImport("value.zig", value_mod);
    interp_mod.addImport("env.zig", env_mod);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // wire up what tests.zig imports
    tests.root_module.addImport("../src/ast.zig", ast_mod);
    tests.root_module.addImport("../src/value.zig", value_mod);
    tests.root_module.addImport("../src/env.zig", env_mod);
    tests.root_module.addImport("../examples.zig", examples_mod);
    tests.root_module.addImport("../src/interp.zig", interp_mod);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
}