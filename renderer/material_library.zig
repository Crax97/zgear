const std = @import("std");
const Allocator = std.mem.Allocator;

pub const MaterialHandle = struct {
    id: usize,
    pub const NULL: MaterialHandle = MaterialHandle{ .id = std.math.maxInt(usize) };
};

pub const Material = struct {};
pub const MaterialLibrary = struct {
    const Materials = std.ArrayList(Material);

    materials: Materials,
    allocator: Allocator,

    pub fn init(alloc: Allocator) MaterialLibrary {
        return .{
            .materials = Materials.init(alloc),
            .allocator = alloc,
        };
    }

    pub fn deinit(this: *MaterialLibrary) void {
        this.materials.deinit();
    }
};
