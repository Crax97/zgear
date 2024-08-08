const std = @import("std");
const vec = @import("vec.zig");
const mat = @import("mat.zig");
const main = @import("main.zig");

const cos = std.math.cos;
const sin = std.math.sin;
const acos = std.math.acos;
const asin = std.math.asin;
const atan2 = std.math.atan2;

pub fn quat_t(comptime T: type) type {
    return struct {
        const This = @This();
        const Vec = vec.vec_t(T, 3);
        const Mat = mat.mat_t(T, 4);

        pub const ZERO = new(.{ 0.0, 0.0, 0.0, 0.0 });
        pub const IDENTITY = new(.{ 1.0, 0.0, 0.0, 0.0 });
        data: extern union {
            vec: @Vector(4, T),
            fields: extern struct {
                w: T,
                x: T,
                y: T,
                z: T,
            },
            array: [4]T,
        },

        pub fn new(data: [4]T) This {
            return .{
                .data = .{
                    .array = data,
                },
            };
        }

        // angle is in radians, axis must be normalized
        pub fn new_angle_axis(angle: T, rotation_axis: Vec) This {
            const a = angle * 0.5;
            const c = std.math.cos(a);
            const s = std.math.cos(a);
            return This.new(c, s * rotation_axis.x(), s * rotation_axis.y(), s * rotation_axis.z());
        }

        pub fn new_from_euler(pitch: T, yaw: T, roll: T) This {
            // TODO: expand properly
            const pquat = new(.{ cos(pitch / 2.0), sin(pitch / 2.0), 0.0, 0.0 });
            const yquat = new(.{ cos(yaw / 2.0), 0.0, sin(yaw / 2.0), 0.0 });
            const rquat = new(.{ cos(roll / 2.0), 0.0, 0.0, sin(roll / 2.0) });
            return pquat.mul(rquat).mul(yquat);
        }

        pub fn to_matrix(this: *const This) Mat {
            const qw, const qx, const qy, const qz = this.data.array;
            return Mat.new_rows(.{
                1.0 - 2.0 * qy * qy - 2.0 * qz * qz, 2.0 * qx * qy + 2.0 * qw * qz,       2.0 * qx * qz - 2.0 * qw * qy,       0.0,
                2.0 * qx * qy - 2.0 * qw * qz,       1.0 - 2.0 * qx * qx - 2.0 * qz * qz, 2.0 * qy * qz + 2.0 * qw * qx,       0.0,
                2.0 * qx * qz + 2.0 * qw * qy,       2.0 * qy * qz - 2.0 * qw * qx,       1.0 - 2.0 * qx * qx - 2.0 * qy * qy, 0.0,
                0.0,                                 0.0,                                 0.0,                                 1.0,
            });
        }

        pub fn to_euler(this: *const This) Vec {
            return main.mat_to_euler_t(T, this.to_matrix());
        }

        pub fn x(this: *const This) T {
            return this.data[0];
        }

        pub fn y(this: *const This) T {
            return this.data[1];
        }

        pub fn z(this: *const This) T {
            return this.data[2];
        }

        pub fn w(this: *const This) T {
            return this.data[3];
        }

        pub fn magnitude_squared(this: *const This) T {
            const m = this.data.vec * this.data.vec;
            return @reduce(.Add, m);
        }

        pub fn magnitude(this: *const This) T {
            return @sqrt(this.magnitude_squared());
        }

        pub fn axis(this: *const This) Vec {
            return Vec.new(.{
                this.data.fields.x,
                this.data.fields.y,
                this.data.fields.z,
            });
        }

        pub fn add(this: *const This, other: This) This {
            return This{ .data = .{
                .vec = this.data.vec + other.data.vec,
            } };
        }

        pub fn sub(this: *const This, other: This) This {
            return This{ .data = .{
                .vec = this.data.vec - other.data.vec,
            } };
        }

        pub fn diff(this: *const This, other: This) This {
            const inv = this.inverse();
            return other.mul(inv);
        }
        // q = [cosa, sina * n]
        // log(q) = [0, n * a]
        pub fn log(this: *const This) This {
            std.debug.assert(std.math.approxEqAbs(T, this.magnitude(), 1.0, 0.005));
            const d = this.dot(this.*);
            const ang = std.math.acos(d);
            const s = std.math.sin(ang);
            const n = this.axis().scale(1.0 / s);
            const v = n.scale(ang);
            return new(.{ 0.0, v.x, v.y, v.z });
        }

        // q = [0, a * n]
        // exp(q) = [cosa, sina * n]
        pub fn exp(this: *const This) This {
            std.debug.assert(std.math.approxEqAbs(T, this.data.fields.w, 0.0, 0.005));
            const v = this.axis();
            const a = v.magnitude_squared();
            const n = v.scale(1.0 / a);
            const s = std.math.sin(a);
            const c = std.math.cos(a);
            return new(.{ c, n.x() * s, n.y() * s, n.z() * s });
        }

        // q^t = exp(t * log(q)), with t usually in [0,1]
        // It can be interpreted as a fraction of thee rotation expressed by q
        // e.g with t = 0.5, it returns half the rotation expressed by q
        pub fn pow(this: *const This, t: T) This {
            return this.log().scale(t).exp();
        }

        pub fn dot(this: *const This, other: This) T {
            return @reduce(.Add, this.data.vec * other.data.vec);
        }

        pub fn scale(this: *const This, s: T) This {
            return This{ .data = .{
                .fields = .{
                    .w = s * this.data.fields.w,
                    .x = s * this.data.fields.x,
                    .y = s * this.data.fields.y,
                    .z = s * this.data.fields.z,
                },
            } };
        }

        pub fn mul(this: *const This, other: This) This {
            const w1, const x1, const y1, const z1 = this.data.array;
            const w2, const x2, const y2, const z2 = other.data.array;

            const nw = w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2;
            const nx = w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2;
            const ny = w1 * y2 + y1 * w2 + z1 * x2 - x1 * z2;
            const nz = w1 * z2 + z1 * w2 + x1 * y2 - y1 * x2;

            return new(.{ nw, nx, ny, nz });
        }

        pub fn rotate(this: *const This, p: vec.vec_t(T, 3)) vec.vec_t(T, 3) {
            const p_quat = new(0.0, p.x(), p.y(), p.z());
            const inv = this.inverse();
            const r = this.mul(p_quat).mul(inv);
            return vec.vec_t(T, 3).new(.{ r.data.fields.x, r.data.fields.y, r.data.fields.z });
        }

        pub fn conjugate(this: *const This) This {
            return This{ .data = .{
                .fields = .{
                    .w = this.data.fields.w,
                    .x = -this.data.fields.x,
                    .y = -this.data.fields.y,
                    .z = -this.data.fields.z,
                },
            } };
        }

        pub fn inverse(this: *const This) This {
            const mag = this.magnitude_squared();
            if (std.math.approxEqAbs(f32, mag, 1.0, 0.005)) {
                return this.conjugate();
            } else {
                return this.conjugate().scale(1.0 / @sqrt(mag));
            }
        }

        pub fn eq_approx(this: *const This, other: This, tolerance: T) bool {
            inline for (0..4) |i| {
                if (!std.math.approxEqAbs(T, this.data.array[i], other.data.array[i], tolerance)) {
                    return false;
                }
            }

            return true;
        }

        pub fn eq(this: *const This, other: This) bool {
            inline for (0..4) |i| {
                if (this.data.array[i] != other.data.array[i]) {
                    return false;
                }
            }

            return true;
        }
    };
}
