const std = @import("std");
const main = @import("main.zig");

const Mat4 = main.Mat4;
const Vec3 = main.Vec3;
const Quat = main.Quat;

pub const Transform = struct { position: Vec3 = Vec3.ZERO, rotation: Quat = Quat.IDENTITY, scale: Vec3 = Vec3.ONE, changed: bool = false, local_to_world: Mat4 };
