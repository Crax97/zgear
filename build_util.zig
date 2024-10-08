const std = @import("std");

fn sdk_path_relative(b: *std.Build, comptime path: []const u8) []const u8 {
    const src = @src();
    const source = comptime std.fs.path.dirname(src.file) orelse ".";
    const rel = std.fs.path.relative(b.allocator, ".", source) catch @panic("OOM");
    return b.pathJoin(&[2][]const u8{ rel, path });
}

pub fn install_binaries(b: *std.Build) void {
    b.installBinFile(sdk_path_relative(b, "thirdparty/sdl/x86_64-w64/bin/SDL2.dll"), "SDL2.dll");
    b.installBinFile(sdk_path_relative(b, "thirdparty/openal/bin/Win64/soft_oal.dll"), "OpenAL32.dll");
}

pub fn setup_zgear(target: *std.Build.Step.Compile, zgear: *std.Build.Dependency) void {
    target.root_module.addImport("engine", zgear.module("engine"));
    target.root_module.addImport("core", zgear.module("core"));
    target.root_module.addImport("math", zgear.module("math"));
    target.root_module.addImport("ecs", zgear.module("ecs"));
    target.root_module.addImport("renderer", zgear.module("renderer"));
}
