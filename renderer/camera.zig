const std = @import("std");

const math = @import("math");

const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;

const vec3 = math.vec3;

pub const ProjectionModeType = enum { Ortho, Perspective };

pub const ProjectionMode = union(ProjectionModeType) {
    Ortho: struct {
        plane_size: f32 = 1024.0,
        zoom: f32 = 1.0,
        extents: Vec2 = Vec2.new(.{ 1240, 720 }),
    },
    Perspective: struct {
        fov_degs: f32 = 90.0,
    },
};

pub const Camera = struct {
    position: Vec3 = Vec3.ZERO,
    rotation: f32 = 0.0,
    projection_mode: ProjectionMode = ProjectionMode{
        .Ortho = .{},
    },

    pub fn view_matrix(this: *const Camera) Mat4 {
        return switch (this.projection_mode) {
            .Ortho => |p| {
                return math.transformation(
                    this.position,
                    vec3(p.zoom, p.zoom, 1.0),
                    vec3(0.0, 0.0, std.math.degreesToRadians(this.rotation)),
                )
                    .invert().?;
            },
            .Perspective => unreachable,
        };
    }

    pub fn projection_matrix(this: *const Camera, viewport_extents: Vec2) Mat4 {
        return switch (this.projection_mode) {
            .Ortho => |p| {
                const V = viewport_extents.x() / viewport_extents.y();
                const A = p.extents.x() / p.extents.y();
                const m = V / A;
                const w = p.extents.x() * 0.5;
                const h = p.extents.y() * 0.5;
                const s = p.plane_size * 0.5;
                return math.ortho(-m * w, m * w, -h, h, -s, s);
            },

            .Perspective => unreachable,
        };
    }
};
