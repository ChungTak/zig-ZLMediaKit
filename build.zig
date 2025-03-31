const std = @import("std");

// 创建ZLMEDIAKIT库模块
fn createZLMediakitModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    lib_path: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
) *std.Build.Module {
    // 创建库模块
    const zlmediakit_module = b.addModule("zlmediakit", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    zlmediakit_module.addLibraryPath(lib_path);
    zlmediakit_module.addIncludePath(include_path);
    return zlmediakit_module;
}

// 为可执行文件设置ZLMEDIAKIT依赖
fn setupZLMediakitForExecutable(
    exe: *std.Build.Step.Compile,
    lib_path: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
    zlmediakit_module: *std.Build.Module,
) void {
    // 链接ZLMEDIAKIT库
    exe.linkSystemLibrary("mk_api");
    exe.addLibraryPath(lib_path);
    exe.addIncludePath(include_path);
    // 添加模块依赖
    exe.root_module.addImport("zlmediakit", zlmediakit_module);
}

// 构建示例
fn buildExamples(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    lib_path: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
    zlmediakit_module: *std.Build.Module,
) void {
    // 批量构建示例可执行文件
    const examples = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "server", .path = "src/examples/server.zig" },
        .{ .name = "pusher", .path = "src/examples/pusher.zig" },
    };
    for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = b.path(example.path),
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibC();

        // 设置example的ZLMEDIAKIT依赖
        setupZLMediakitForExecutable(exe, lib_path, include_path, zlmediakit_module);

        // 安装example
        b.installArtifact(exe);

        // 添加运行example的步骤
        const run_example = b.addRunArtifact(exe);
        run_example.step.dependOn(b.getInstallStep());

        const example_step_desc = std.fmt.allocPrint(b.allocator, "Build and run the {s}", .{example.name}) catch unreachable;
        const example_step = b.step(example.name, example_step_desc);
        example_step.dependOn(&run_example.step);

        // 添加只编译不运行的步骤
        const step_name = std.fmt.allocPrint(b.allocator, "build-{s}", .{example.name}) catch unreachable;
        const step_desc = std.fmt.allocPrint(b.allocator, "Build the {s} without running it", .{example.name}) catch unreachable;
        const build_example_step = b.step(step_name, step_desc);
        const install_example = b.addInstallArtifact(exe, .{});
        build_example_step.dependOn(&install_example.step);
    }
}

pub fn build(b: *std.Build) void {
    // 获取标准目标选项
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .gnu,
        },
    });
    const target_str = std.fmt.allocPrint(b.allocator, "{s}-{s}-{s}", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag), @tagName(target.result.abi) }) catch "x86_64-linux-gnu";
    const optimize = b.standardOptimizeOption(.{});

    // 获取ZLMEDIAKIT库路径ZLMEDIAKIT_LIBRARIES环境变量
    const zlmediakit_lib = std.process.getEnvVarOwned(std.heap.page_allocator, "ZLMEDIAKIT_LIBRARIES") catch null;

    // 获取库文件路径
    const lib_path = std.fmt.allocPrint(std.heap.page_allocator, "runtime/lib/{s}", .{target_str}) catch unreachable;

    // 确定库路径：优先使用使用环境变量
    const final_lib_path = if (zlmediakit_lib) |env_dir| env_dir else lib_path;
    const final_include_path = "runtime/include";

    // 创建库模块
    const zlmediakit_module = createZLMediakitModule(b, target, optimize, b.path(final_lib_path), b.path(final_include_path));

    // 创建静态库
    const lib = b.addStaticLibrary(.{
        .name = "zlmediakit",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // 添加C库链接
    lib.linkLibC();
    lib.linkSystemLibrary("mk_api");
    lib.addLibraryPath(b.path(final_lib_path));
    lib.addIncludePath(b.path(final_include_path));

    // 安装库
    b.installArtifact(lib);

    // 创建测试
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 设置测试的库路径和头文件路径
    main_tests.linkLibC();
    main_tests.linkSystemLibrary("mk_api");
    main_tests.addLibraryPath(b.path(final_lib_path));
    main_tests.addIncludePath(b.path(final_include_path));

    const run_main_tests = b.addRunArtifact(main_tests);

    // 添加测试步骤
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // 构建示例
    buildExamples(b, target, optimize, b.path(final_lib_path), b.path(final_include_path), zlmediakit_module);
}
