const std = @import("std");
const main = @import("main.zig");

const Mat4 = main.Mat4;
const Vec3 = main.Vec3;
const Quat = main.Quat;

pub const Transform = struct {
    pub const IDENTITY = Transform{};
    position: Vec3 = Vec3.ZERO,
    rotation: Quat = Quat.IDENTITY,
    scale: Vec3 = Vec3.ONE,
    changed: bool = false,
    local_to_world: Mat4 = Mat4.IDENTITY,

    pub fn add_position_offset(this: *Transform, offset: Vec3) void {
        this.position = this.position.add(offset);
        this.changed = true;
    }

    pub fn add_scale_offset(this: *Transform, offset: Vec3) void {
        this.position = this.scale.add(offset);
        this.changed = true;
    }

    pub fn add_rotation_offset(this: *Transform, offset: Quat) void {
        std.debug.assert(std.math.approxEqAbs(main.Real, offset.magnitude_squared(), 1.0, 0.05));
        this.rotation = this.rotation.mul(offset);
    }

    pub fn add_rotation_offset_euler(this: *Transform, offset: Vec3) void {
        const quat = Quat.new_from_euler(offset);
        this.add_rotation_offset(quat);
    }

    pub fn set_position(this: *Transform, value: Vec3) void {
        this.position = value;
        this.changed = true;
    }

    pub fn set_scale(this: *Transform, value: Vec3) void {
        this.scale = value;
        this.changed = true;
    }

    pub fn set_rotation(this: *Transform, value: Quat) void {
        std.debug.assert(std.math.approxEqAbs(main.Real, value.magnitude_squared(), 1.0, 0.05));
        this.rotation = value;
        this.changed = true;
    }

    pub fn left(this: *Transform) Vec3 {
        this.recompute_local_to_world_if_needed();
        return this.local_to_world.row(0).truncate().normalize();
    }

    pub fn up(this: *Transform) Vec3 {
        this.recompute_local_to_world_if_needed();
        return this.local_to_world.row(1).truncate().normalize();
    }

    pub fn forward(this: *Transform) Vec3 {
        this.recompute_local_to_world_if_needed();
        return this.local_to_world.row(2).truncate().normalize();
    }

    pub fn matrix(this: *Transform) Mat4 {
        this.recompute_local_to_world_if_needed();
        return this.local_to_world;
    }

    fn recompute_local_to_world_if_needed(this: *Transform) void {
        if (!this.changed) {
            return;
        }
        this.changed = false;
        this.local_to_world = main.quat_to_mat(this.rotation)
            .mul(main.scaling(this.scale))
            .mul(main.translation(this.position));
    }
};
