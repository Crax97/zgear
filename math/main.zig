const std = @import("std");

const vec = @import("vec.zig");
const mat = @import("mat.zig");
const qua = @import("quat.zig");

const cos = std.math.cos;
const sin = std.math.sin;
const acos = std.math.acos;
const asin = std.math.asin;
const atan2 = std.math.atan2;

fn rect_t(comptime T: type, comptime N: comptime_int) type {
    return struct {
        const This = @This();
        const Vec = vec.vec_t(T, N);
        offset: Vec,
        extent: Vec,

        pub fn points(this: *const This) [4 * (N - 1)]Vec {
            const NP = 4 * (N - 1);
            var pts = std.mem.zeroes([NP]Vec);
            if (N == 2) {
                pts[0] = vec2(this.offset.x() - this.extent.x() * 0.5, this.offset.y() - this.extent.y() * 0.5);
                pts[1] = vec2(this.offset.x() - this.extent.x() * 0.5, this.offset.y() + this.extent.y() * 0.5);
                pts[2] = vec2(this.offset.x() + this.extent.x() * 0.5, this.offset.y() - this.extent.y() * 0.5);
                pts[3] = vec2(this.offset.x() + this.extent.x() * 0.5, this.offset.y() + this.extent.y() * 0.5);
            }

            if (N == 3) {
                @compileError("TODO");
            }

            if (N > 4) {
                @compileError("TODO");
            }

            return pts;
        }

        pub fn contains(this: *const This, pt: Vec) bool {
            inline for (0..N) |i| {
                if (this.offset.data[i] - this.extent.data[i] * 0.5 > pt.data[i] or this.offset.data[i] + this.extent.data[i] * 0.5 < pt.data[i]) {
                    return false;
                }
            }

            return true;
        }

        pub fn intersects(this: *const This, other: This) bool {
            const pts = other.points();
            inline for (pts) |pt| {
                if (this.contains(pt)) {
                    return true;
                }
            }
            return false;
        }
    };
}

pub const Real = f32;

pub const Vec2 = vec.vec_t(f32, 2);
pub const Vec3 = vec.vec_t(f32, 3);
pub const Vec4 = vec.vec_t(f32, 4);

pub const Mat2 = mat.mat_t(f32, 2);
pub const Mat3 = mat.mat_t(f32, 3);
pub const Mat4 = mat.mat_t(f32, 4);

pub const Rect2 = rect_t(f32, 2);
pub const Rect3 = rect_t(f32, 3);

pub const Quat = qua.quat_t(Real);

pub fn vec2(x: f32, y: f32) Vec2 {
    return Vec2.new(.{ x, y });
}
pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3.new(.{ x, y, z });
}
pub fn vec4(x: f32, y: f32, z: f32, w: f32) Vec4 {
    return Vec4.new(.{ x, y, z, w });
}

pub fn quat(w: Real, x: Real, y: Real, z: Real) Quat {
    return Quat.new(.{ w, x, y, z });
}

pub fn cross(this: *const Vec3, other: Vec3) Vec3 {
    const c1: @Vector(3, f32) = .{ this.data[1], this.data[2], this.data[0] };
    const c2: @Vector(3, f32) = .{ other.data[2], other.data[0], other.data[1] };
    const a = c1 * c2;

    const c3: @Vector(3, f32) = .{ this.data[2], this.data[0], this.data[1] };
    const c4: @Vector(3, f32) = .{ other.data[1], other.data[2], other.data[0] };
    const b = c3 * c4;
    const ret = a - b;

    return Vec3{ .data = [3]f32{ ret[0], ret[1], ret[2] } };
}

pub fn transformation(location: Vec3, scale: Vec3, rotation_euler: Vec3) Mat4 {
    const r = rot_x(rotation_euler.x())
        .mul(rot_y(rotation_euler.y())
        .mul(rot_z(rotation_euler.z())));
    return r.mul(scaling(scale))
        .mul(translation(location));
}

pub fn translation(location: Vec3) Mat4 {
    const data = location.data;
    return Mat4.new_cols(.{
        1.0,     0.0,     0.0,     0.0,
        0.0,     1.0,     0.0,     0.0,
        0.0,     0.0,     1.0,     0.0,
        data[0], data[1], data[2], 1.0,
    });
}
pub fn scaling(amount: Vec3) Mat4 {
    const data = amount.data;
    return Mat4.new_cols(.{
        data[0], 0.0,     0.0,     0.0,
        0.0,     data[1], 0.0,     0.0,
        0.0,     0.0,     data[2], 0.0,
        0.0,     0.0,     0.0,     1.0,
    });
}

pub fn rot_x(angle: f32) Mat4 {
    return rot_x_t(f32, angle);
}

pub fn rot_y(angle: f32) Mat4 {
    return rot_y_t(f32, angle);
}

pub fn rot_z(angle: f32) Mat4 {
    return rot_z_t(f32, angle);
}

pub fn rot_x_t(comptime T: type, angle: T) mat.mat_t(T, 4) {
    const s = @sin(angle);
    const c = @cos(angle);
    return mat.mat_t(T, 4).new_rows(.{
        1.0, 0.0, 0.0, 0.0,
        0.0, c,   -s,  0.0,
        0.0, s,   c,   0.0,
        0.0, 0.0, 0.0, 1.0,
    });
}

pub fn rot_y_t(comptime T: type, angle: T) mat.mat_t(T, 4) {
    const s = @sin(angle);
    const c = @cos(angle);
    return mat.mat_t(T, 4).new_rows(.{
        c,   0.0, s,   0.0,
        0.0, 1.0, 0.0, 0.0,
        -s,  0.0, c,   0.0,
        0.0, 0.0, 0.0, 1.0,
    });
}

pub fn rot_z_t(comptime T: type, angle: T) mat.mat_t(T, 4) {
    const s = @sin(angle);
    const c = @cos(angle);
    return mat.mat_t(T, 4).new_rows(.{
        c,   -s,  0.0, 0.0,
        s,   c,   0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    });
}

pub fn mat_to_euler(m: Mat4) Vec3 {
    return mat_to_euler_t(f32, m);
}

pub fn mat_to_euler_t(comptime T: type, m: mat.mat_t(T, 4)) vec.vec_t(T, 3) {
    var p: f32 = undefined;
    var b: f32 = undefined;
    var h: f32 = undefined;
    const sp = -m.el(2, 0);
    if (sp <= -1.0) {
        p = -std.math.pi / 2.0;
    } else if (sp >= 1.0) {
        p = std.math.pi / 2.0;
    } else {
        p = asin(sp);
    }

    if (@abs(sp) > 0.9999) {
        b = 0.0;
        h = atan2(-m.el(0, 2), m.el(0, 0));
    } else {
        h = atan2(m.el(2, 0), m.el(2, 2));
        b = atan2(m.el(0, 1), m.el(1, 1));
    }
    return vec3(p, b, h);
}

pub fn ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
    return ortho_t(f32, left, right, bottom, top, near, far);
}

pub fn ortho_t(comptime T: type, left: T, right: T, bottom: T, top: T, near: T, far: T) mat.mat_t(T, 4) {
    const rl = right - left;
    const tb = top - bottom;
    const fan = far - near;

    return mat.mat_t(T, 4).new_cols(.{
        2.0 / rl,             0.0,                  0.0,                 0.0,
        0.0,                  2.0 / tb,             0.0,                 0.0,
        0.0,                  0.0,                  -2.0 / fan,          0.0,
        -(right + left) / rl, -(top + bottom) / tb, -(far + near) / fan, 1.0,
    });
}

pub fn perspective(aspect: f32, fovy_degrees: f32, near: f32, far: f32) Mat4 {
    return perspective_t(f32, aspect, fovy_degrees, near, far);
}

pub fn perspective_t(comptime T: type, aspect: T, fovy_degrees: T, near: T, far: T) mat.mat_t(T, 4) {
    const half_fov_rad = std.math.degreesToRadians(fovy_degrees) * 0.5;
    const tan = std.math.tan(half_fov_rad);
    return mat.mat_t(T, 4).new_rows(.{
        aspect / tan, 0.0,        0.0,                 0.0,
        0.0,          -1.0 / tan, 0.0,                 0.0,
        0.0,          0.0,        -far / (near - far), (far * near) / (near - far),
        0.0,          0.0,        1,                   0.0,
    });
}

pub fn look_at(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
    return look_at_t(f32, eye, target, up);
}

pub fn look_at_t(comptime T: type, eye: vec.vec_t(T, 3), target: vec.vec_t(T, 3), up: vec.vec_t(T, 3)) mat.mat_t(T, 4) {
    const d = target.sub(eye).normalize();
    const r = cross(&d, up).normalize();
    const u = cross(&d, r).normalize();

    return mat.mat_t(T, 4).new_cols(.{
        r.x(), u.x(), d.x(), 0.0,
        r.y(), u.y(), d.y(), 0.0,
        r.z(), u.z(), d.z(), 0.0,
        0.0,   0.0,   0.0,   1.0,
    });
}

test "Array" {
    const v = Vec4.new(.{ 1.0, 2.0, 3.0, 4.0 });
    try std.testing.expectEqual(1.0, v.array()[0]);
    try std.testing.expectEqual(2.0, v.array()[1]);
    try std.testing.expectEqual(3.0, v.array()[2]);
    try std.testing.expectEqual(4.0, v.array()[3]);
}

test "Identity" {
    const ID = Mat4.IDENTITY;
    const ID_TRANSP = ID.transpose();

    inline for (0..4) |i| {
        inline for (0..4) |j| {
            const check = if (i == j) 1.0 else 0.0;
            try std.testing.expectEqual(check, ID_TRANSP.cols[i].data[j]);
        }
    }

    const ID_MUL = ID.mul(ID);
    inline for (0..4) |i| {
        inline for (0..4) |j| {
            const check = if (i == j) 1.0 else 0.0;
            try std.testing.expectEqual(check, ID_MUL.cols[i].data[j]);
        }
    }
}

test "Matrices are column major" {
    const arr = .{
        1.0,  2.0,  3.0,  4.0,
        5.0,  6.0,  7.0,  8.0,
        9.0,  10.0, 11.0, 12.0,
        13.0, 14.0, 15.0, 16.0,
    };
    const nums = Mat4.new_cols(arr);

    try std.testing.expect(nums.col(0).eql(vec4(1.0, 2.0, 3.0, 4.0)));
    try std.testing.expect(nums.col(1).eql(vec4(5.0, 6.0, 7.0, 8.0)));
    try std.testing.expect(nums.col(2).eql(vec4(9.0, 10.0, 11.0, 12.0)));
    try std.testing.expect(nums.col(3).eql(vec4(13.0, 14.0, 15.0, 16.0)));

    try std.testing.expect(nums.row(0).eql(vec4(1.0, 5.0, 9.0, 13.0)));
    try std.testing.expect(nums.row(1).eql(vec4(2.0, 6.0, 10.0, 14.0)));
    try std.testing.expect(nums.row(2).eql(vec4(3.0, 7.0, 11.0, 15.0)));
    try std.testing.expect(nums.row(3).eql(vec4(4.0, 8.0, 12.0, 16.0)));
    try std.testing.expectEqual(arr, nums.flat_arr());
}

test "Matrix translation" {
    const trans_1 = vec3(10.0, 5.0, 15.0);
    const trans_simple = translation(trans_1);
    const trans_row = trans_simple.col(3);
    try std.testing.expect(trans_row.truncate().eql(trans_1));
    const vec_zero = Vec3.ZERO;
    const trans_2 = vec_zero.transform(trans_simple).truncate();
    try std.testing.expect(trans_1.eql(trans_2));
}

test "Matrix transformation" {
    const scale_1 = Vec3.splat(2.0);
    const trans_1 = vec3(10.0, 5.0, 15.0);
    const trans_simple = scaling(scale_1).mul(translation(trans_1));
    const vec_base = Vec3.ONE;
    const trans_2 = vec_base.transform(trans_simple).truncate();

    try std.testing.expect(trans_1.add(Vec3.splat(2.0)).eql(trans_2));
}

test "Matrix rotation" {
    {
        const vec_up = vec3(0.0, 1.0, 0.0);
        const rot_z_90 = rot_z(std.math.degreesToRadians(90.0));
        const rotated = vec_up.transform(rot_z_90).truncate();

        try std.testing.expect(rotated.eql_approx(vec3(-1.0, 0.0, 0.0), 0.005));
    }

    {
        const vec_fwd = vec3(0.0, 0.0, 1.0);
        const rot_x_90 = rot_x(std.math.degreesToRadians(90.0));
        const rotated = vec_fwd.transform(rot_x_90).truncate();

        try std.testing.expect(rotated.eql_approx(vec3(0.0, -1.0, 0.0), 0.005));
    }

    {
        const vec_left = vec3(1.0, 0.0, 0.0);
        const rot_y_90 = rot_y(std.math.degreesToRadians(90.0));
        const rotated = vec_left.transform(rot_y_90).truncate();
        try std.testing.expect(rotated.eql_approx(vec3(0.0, 0.0, -1.0), 0.005));
    }
}

test "Matrix determinant" {
    try std.testing.expectEqual(Mat4.IDENTITY.det(), 1.0);
    const five = Mat4.IDENTITY.scaled(5.0);

    try std.testing.expectEqual(five.det(), 625.0);
    try std.testing.expectEqual(Mat4.IDENTITY.scaled(10.0).det(), 10.0 * 10.0 * 10.0 * 10.0);

    const random_mat = Mat4.new_cols(.{
        2.0, 9.0, 7.0, 4.0,
        7.0, 1.0, 6.0, 7.0,
        9.0, 6.0, 4.0, 8.0,
        3.0, 4.0, 9.0, 9.0,
    });

    try std.testing.expect(std.math.approxEqAbs(f32, random_mat.det(), 1536.0, 0.05));
}

test "Matrix inverse" {
    inline for (1..4) |N| {
        const Mat = mat.mat_t(f32, N);
        const ID = Mat.IDENTITY;
        const inv = Mat.IDENTITY.invert().?;

        for (0..N) |i| {
            for (0..N) |j| {
                try std.testing.expectApproxEqAbs(ID.el(i, j), inv.el(i, j), 0.05);
            }
        }
    }

    const random_mat = Mat4.new_cols(.{
        2.0, 9.0, 7.0, 4.0,
        7.0, 1.0, 6.0, 7.0,
        9.0, 6.0, 4.0, 8.0,
        3.0, 4.0, 9.0, 9.0,
    });
    const inv_random_mat = random_mat.invert().?;
    const ID_hopefully = inv_random_mat.mul(random_mat);
    const ID = Mat4.IDENTITY;
    for (0..4) |i| {
        for (0..4) |j| {
            try std.testing.expectApproxEqAbs(ID.el(i, j), ID_hopefully.el(i, j), 0.05);
        }
    }

    try std.testing.expect(std.math.approxEqAbs(f32, random_mat.det(), 1536.0, 0.05));
}

test "Lookat" {
    const m = look_at(vec3(0.0, 10.0, 0.0), vec3(0.0, 10.0, 5.0), vec3(0.0, 1.0, 0.0));
    try std.testing.expect(m.row(2).eql_approx(vec4(0.0, 0.0, 1.0, 0.0), 0.05));
}

fn print_mat(comptime N: comptime_int, m: mat.mat_t(f32, N)) void {
    for (0..N) |j| {
        for (0..N) |i| {
            std.debug.print("{d} ", .{m.el(i, j)});
        }
        std.debug.print("\n", .{});
    }
}

fn print_vec(comptime N: comptime_int, m: vec.vec_t(f32, N)) void {
    for (0..N) |i| {
        std.debug.print("{d} ", .{m.data[i]});
    }
    std.debug.print("\n", .{});
}

fn print_quat(q: Quat) void {
    for (0..4) |i| {
        std.debug.print("{d} ", .{q.data.array[i]});
    }
    std.debug.print("\n", .{});
}

fn random_real() Real {
    const r = struct {
        var rand = std.rand.DefaultPrng.init(0);
        var random = rand.random();
    };

    return r.random.float(Real);
}
fn random_quat() Quat {
    return Quat.new(.{
        random_real(),
        random_real(),
        random_real(),
        random_real(),
    });
}

fn random_rotation_quat() Quat {
    const angl = random_real() * 2.0 * std.math.pi;
    const axis = vec3(random_real(), random_real(), random_real()).normalize();
    return Quat.new_angle_axis(.{ angl, axis });
}
