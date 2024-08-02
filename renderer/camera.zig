const std = @import("std");

const math = @import("math");

const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;

const vec3 = math.vec3;

pub const ProjectionModeType = enum { Ortho, Perspective };

pub const ProjectionMode = union(ProjectionModeType) {
    Ortho: struct {},
    Perspective: struct {},
};

pub const Camera = struct {
    position: Vec3 = Vec3.ZERO,
    rotation: f32 = 0.0,

    fov_degs: f32 = 90.0,
    near: f32 = 0.01,
    far: f32 = 1000.0,

    plane_size: f32 = 1024.0,
    zoom: f32 = 1.0,
    extents: Vec2 = Vec2.new(.{ 1240, 720 }),
    pub fn view_matrix(this: *const Camera) Mat4 {
        return math.transformation(
            this.position,
            vec3(this.zoom, this.zoom, 1.0),
            vec3(0.0, 0.0, std.math.degreesToRadians(this.rotation)),
        )
            .invert().?;
    }

    pub fn ortho_matrix(this: *const Camera, viewport_extents: Vec2) Mat4 {
        const V = viewport_extents.x() / viewport_extents.y();
        const A = this.extents.x() / this.extents.y();
        const m = V / A;
        const w = this.extents.x() * 0.5;
        const h = this.extents.y() * 0.5;
        const s = this.plane_size * 0.5;
        return math.ortho(-m * w, m * w, -h, h, -s, s);
    }

    pub fn perspective_matrix(this: *const Camera, viewport_extents: Vec2) Mat4 {
        const V = viewport_extents.x() / viewport_extents.y();
        const A = this.extents.x() / this.extents.y();
        const m = V / A;
        return math.perspective(m, this.fov_degs, this.near, this.far);
    }
};
