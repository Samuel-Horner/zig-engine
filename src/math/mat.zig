const std = @import("std");
const math = std.math;
const Vec = @import("vec.zig").Vec;
const Quaternion = @import("quaternion.zig").Quaternion;

/// Row-major matrix type
pub fn Mat(comptime T: type, r: comptime_int, c: comptime_int) type {
    if (r < 1 or c < 1) {
        @compileError("Invalid matrix dimensions.");
    }

    return struct {
        const Self = @This();

        data: [r][c]T,

        pub fn rows() comptime_int {
            return r;
        }

        pub fn cols() comptime_int {
            return c;
        }

        pub fn zero() Self {
            var res: Self = undefined;
            inline for (0..r) |i| {
                inline for (0..c) |j| {
                    res.data[i][j] = 0;
                }
            }
            return res;
        }

        pub fn diagonal(v: T) Self {
            comptime if (r != c) {
                @compileError("Mat diagonal is not supported for non-square matrices.");
            };
            var res = Self.zero();
            inline for (0..r) |i| {
                res.data[i][i] = v;
            }
            return res;
        }

        pub fn identity() Self {
            comptime if (r != c) {
                @compileError("Mat identity is not supported for non-square matrices.");
            };
            return diagonal(1);
        }

        pub fn add(self: Self, other: Self) Self {
            var res: Self = undefined;
            inline for (0..r) |i| {
                inline for (0..c) |j| {
                    res.data[i][j] = self.data[i][j] + other.data[i][j];
                }
            }
            return res;
        }

        pub fn sub(self: Self, other: Self) Self {
            var res: Self = undefined;
            inline for (0..r) |i| {
                inline for (0..c) |j| {
                    res.data[i][j] = self.data[i][j] - other.data[i][j];
                }
            }
            return res;
        }

        pub fn muls(self: Self, scalar: T) Self {
            var res: Self = undefined;
            inline for (0..r) |i| {
                inline for (0..c) |j| {
                    res.data[i][j] = self.data[i][j] * scalar;
                }
            }
            return res;
        }

        pub fn divs(self: Self, scalar: T) Self {
            var res: Self = undefined;
            inline for (0..r) |i| {
                inline for (0..c) |j| {
                    res.data[i][j] = self.data[i][j] / scalar;
                }
            }
            return res;
        }

        pub fn transpose(self: Self) Mat(T, c, r) {
            var res: Mat(T, c, r) = undefined;
            inline for (0..r) |i| {
                inline for (0..c) |j| {
                    res.data[j][i] = self.data[i][j];
                }
            }
            return res;
        }

        pub fn mul(self: Self, other: anytype) Mat(T, r, @TypeOf(other).cols()) {
            comptime if (c != @TypeOf(other).rows()) {
                @compileError("Mat mul - invalid matrix sizes");
            };

            var res: Mat(T, r, @TypeOf(other).cols()) = undefined;

            inline for (0..r) |i| {
                inline for (0..@TypeOf(other).cols()) |j| {
                    var sum: T = 0;
                    inline for (0..c) |l| {
                        sum += self.data[i][l] * other.data[l][j];
                    }
                    res.data[i][j] = sum;
                }
            }
            return res;
        }

        pub fn mulv(self: Self, v: Vec(T, c)) Vec(T, r) {
            var res: Vec(T, r) = undefined;

            inline for (0..r) |i| {
                var sum: T = 0;
                inline for (0..c) |j| {
                    sum += self.data[i][j] * v.data[j];
                }
                res.data[i] = sum;
            }

            return res;
        }

        /// Returns the sum of the diagonal
        pub fn trace(self: Self) T {
            comptime if (r != c) {
                @compileError("Mat trace is not supported for non-square matrices.");
            };

            var res: T = 0;
            inline for (0..c) |i| {
                res += self.data[i][i];
            }
            return res;
        }

        /// Recursive Laplace expansion. O(N!)
        pub fn det(self: Self) T {
            comptime if (r != c) {
                @compileError("Mat det is not supported for non-square matrices.");
            };

            if (r == 1) {
                return self.data[0][0];
            } else if (r == 2) {
                return self.data[0][0] * self.data[1][1] -
                    self.data[0][1] * self.data[1][0];
            }

            var res: T = 0;
            inline for (0..c) |col| {
                const sign: T = if (col % 2 == 0) 1 else -1;
                const minor_matrix = self.minor(0, col);
                res += sign * self.data[0][col] * minor_matrix.det();
            }
            return res;
        }

        /// Compute the minor matrix after removing row and col
        pub fn minor(self: Self, row: usize, col: usize) Mat(T, r - 1, c - 1) {
            var res = Mat(T, r - 1, c - 1).zero();

            var rr: usize = 0;
            for (0..r) |i| {
                if (i == row) continue;
                var cc: usize = 0;
                for (0..c) |j| {
                    if (j == col) continue;
                    res.data[rr][cc] = self.data[i][j];
                    cc += 1;
                }
                rr += 1;
            }
            return res;
        }

        /// generic inverse, optimised in the 4x4 case.
        pub fn inverse(self: Self) !Self {
            comptime if (r != c) {
                @compileError("Mat inverse is not supported for non-square matrices.");
            };

            if (r == 4 and c == 4) {
                return try self.fastInverse();
            }

            const det_ = self.det();
            if (det_ == 0) return error.singular;

            var cof: Self = undefined;

            inline for (0..r) |i| {
                inline for (0..c) |j| {
                    const m = self.minor(i, j);
                    const sign: T = if (((i + j) % 2) == 0) 1 else -1;
                    cof.data[i][j] = sign * m.det();
                }
            }

            const adj = cof.transpose();
            var inv: Self = undefined;

            inline for (0..r) |i| {
                inline for (0..c) |j| {
                    inv.data[i][j] = adj.data[i][j] / det_;
                }
            }

            return inv;
        }

        pub fn fastInverse(self: Self) !Self {
            comptime if (r != c) {
                @compileError("Mat inverse is not supported for non-square matrices.");
            };

            const m = self.data;

            const t0 = m[2][2] * m[3][3];
            const t1 = m[3][2] * m[2][3];
            const t2 = m[1][2] * m[3][3];
            const t3 = m[3][2] * m[1][3];
            const t4 = m[1][2] * m[2][3];
            const t5 = m[2][2] * m[1][3];
            const t6 = m[0][2] * m[3][3];
            const t7 = m[3][2] * m[0][3];
            const t8 = m[0][2] * m[2][3];
            const t9 = m[2][2] * m[0][3];
            const t10 = m[0][2] * m[1][3];
            const t11 = m[1][2] * m[0][3];
            const t12 = m[2][0] * m[3][1];
            const t13 = m[3][0] * m[2][1];
            const t14 = m[1][0] * m[3][1];
            const t15 = m[3][0] * m[1][1];
            const t16 = m[1][0] * m[2][1];
            const t17 = m[2][0] * m[1][1];
            const t18 = m[0][0] * m[3][1];
            const t19 = m[3][0] * m[0][1];
            const t20 = m[0][0] * m[2][1];
            const t21 = m[2][0] * m[0][1];
            const t22 = m[0][0] * m[1][1];
            const t23 = m[1][0] * m[0][1];

            var res = Self.zero();

            res.data[0][0] = (t0 * m[1][1] + t3 * m[2][1] + t4 * m[3][1]) - (t1 * m[1][1] + t2 * m[2][1] + t5 * m[3][1]);
            res.data[0][1] = (t1 * m[0][1] + t6 * m[2][1] + t9 * m[3][1]) - (t0 * m[0][1] + t7 * m[2][1] + t8 * m[3][1]);
            res.data[0][2] = (t2 * m[0][1] + t7 * m[1][1] + t10 * m[3][1]) - (t3 * m[0][1] + t6 * m[1][1] + t11 * m[3][1]);
            res.data[0][3] = (t5 * m[0][1] + t8 * m[1][1] + t11 * m[2][1]) - (t4 * m[0][1] + t9 * m[1][1] + t10 * m[2][1]);

            const d = 1.0 / (m[0][0] * res.data[0][0] +
                m[1][0] * res.data[0][1] +
                m[2][0] * res.data[0][2] +
                m[3][0] * res.data[0][3]);

            if (std.math.isNan(d)) {
                return error.singular;
            }

            res.data[0][0] *= d;
            res.data[0][1] *= d;
            res.data[0][2] *= d;
            res.data[0][3] *= d;

            res.data[1][0] = d * ((t1 * m[1][0] + t2 * m[2][0] + t5 * m[3][0]) - (t0 * m[1][0] + t3 * m[2][0] + t4 * m[3][0]));
            res.data[1][1] = d * ((t0 * m[0][0] + t7 * m[2][0] + t8 * m[3][0]) - (t1 * m[0][0] + t6 * m[2][0] + t9 * m[3][0]));
            res.data[1][2] = d * ((t3 * m[0][0] + t6 * m[1][0] + t11 * m[3][0]) - (t2 * m[0][0] + t7 * m[1][0] + t10 * m[3][0]));
            res.data[1][3] = d * ((t4 * m[0][0] + t9 * m[1][0] + t10 * m[2][0]) - (t5 * m[0][0] + t8 * m[1][0] + t11 * m[2][0]));

            res.data[2][0] = d * ((t12 * m[1][3] + t15 * m[2][3] + t16 * m[3][3]) - (t13 * m[1][3] + t14 * m[2][3] + t17 * m[3][3]));
            res.data[2][1] = d * ((t13 * m[0][3] + t18 * m[2][3] + t21 * m[3][3]) - (t12 * m[0][3] + t19 * m[2][3] + t20 * m[3][3]));
            res.data[2][2] = d * ((t14 * m[0][3] + t19 * m[1][3] + t22 * m[3][3]) - (t15 * m[0][3] + t18 * m[1][3] + t23 * m[3][3]));
            res.data[2][3] = d * ((t17 * m[0][3] + t20 * m[1][3] + t23 * m[2][3]) - (t16 * m[0][3] + t21 * m[1][3] + t22 * m[2][3]));

            res.data[3][0] = d * ((t14 * m[2][2] + t17 * m[3][2] + t13 * m[1][2]) - (t16 * m[3][2] + t12 * m[1][2] + t15 * m[2][2]));
            res.data[3][1] = d * ((t20 * m[3][2] + t12 * m[0][2] + t19 * m[2][2]) - (t18 * m[2][2] + t21 * m[3][2] + t13 * m[0][2]));
            res.data[3][2] = d * ((t18 * m[1][2] + t23 * m[3][2] + t15 * m[0][2]) - (t22 * m[3][2] + t14 * m[0][2] + t19 * m[1][2]));
            res.data[3][3] = d * ((t22 * m[2][2] + t16 * m[0][2] + t21 * m[1][2]) - (t20 * m[1][2] + t23 * m[2][2] + t17 * m[0][2]));

            return res;
        }

        pub fn fromQuaternion(q: Quaternion(T)) Self {
            comptime if (r != 4 or c != 4) {
                    @compileError("Mat fromQuaternion is only defined for 4x4 matrices.");
            };

            // From https://www.euclideanspace.com/maths/geometry/rotations/conversions/quaternionToMatrix/index.htm
            var res = Self.identity();

            // Row 0
            res.data[0][0] = 1 - 2 * q.y * q.y - 2 * q.z * q.z;
            res.data[0][1] = 2 * q.x * q.y - 2 * q.z * q.w;
            res.data[0][2] = 2 * q.x * q.z + 2 * q.y * q.w;

            // Row 1
            res.data[1][0] = 2 * q.x * q.y + 2 * q.z * q.w;
            res.data[1][1] = 1 - 2 * q.x * q.x - 2 * q.z * q.z;
            res.data[1][2] = 2 * q.y * q.z - 2 * q.x * q.w;

            // Row 2
            res.data[2][0] = 2 * q.x * q.z - 2 * q.y * q.w;
            res.data[2][1] = 2 * q.y * q.z + 2 * q.x * q.w;
            res.data[2][2] = 1 - 2 * q.x * q.x - 2 * q.y * q.y;

            return res;
        }

        /// Right-handed lookAt matrix
        pub fn lookAt(eye: Vec(T, 3), target: Vec(T, 3), up: Vec(T, 3)) Self {
            comptime if (r != 4 or c != 4) {
                @compileError("Mat lookAt is only defined for 4x4 matrices.");
            };

            const f = target.sub(eye).norm();
            const s = f.cross(up).norm();
            const u = s.cross(f).norm();

            return Self{
                .data = .{
                    .{ s.data[0], s.data[1], s.data[2], -s.dot(eye) },
                    .{ u.data[0], u.data[1], u.data[2], -u.dot(eye) },
                    .{ -f.data[0], -f.data[1], -f.data[2], f.dot(eye) },
                    .{ 0, 0, 0, 1 },
                },
            };
        }

        /// Right-handed orthographic projection
        pub fn orthographic(left: T, right: T, bottom: T, top: T, near: T, far: T) Self {
            comptime if (r != 4 or c != 4) {
                @compileError("Mat orthographic is only defined for 4x4 matrices.");
            };

            const rl = right - left;
            const tb = top - bottom;
            const fnf = far - near;

            return Self{
                .data = .{
                    .{ 2 / rl, 0, 0, -(right + left) / rl },
                    .{ 0, 2 / tb, 0, -(top + bottom) / tb },
                    .{ 0, 0, -2 / fnf, -(far + near) / fnf },
                    .{ 0, 0, 0, 1 },
                },
            };
        }

        /// Right-handed perspective projection (OpenGL-style: Z ∈ [-1,1]).
        ///
        /// `fov` in radians
        pub fn perspective(fov: T, aspect: T, near: T, far: T) Self {
            comptime if (r != 4 or c != 4) {
                @compileError("Mat perspective is only defined for 4x4 matrices.");
            };

            const f = 1 / math.tan(fov / 2);
            const fnf = far - near;

            return Self{
                .data = .{
                    .{ f / aspect, 0, 0, 0 },
                    .{ 0, f, 0, 0 },
                    .{ 0, 0, -(far + near) / fnf, -(2 * far * near) / fnf },
                    .{ 0, 0, -1, 0 },
                },
            };
        }

        pub fn translation(x: T, y: T, z: T) Self {
            comptime if (r != 4 or c != 4) {
                @compileError("Mat translation is only defined for 4x4 matrices.");
            };

            return Self{
                .data = .{
                    .{ 1, 0, 0, x },
                    .{ 0, 1, 0, y },
                    .{ 0, 0, 1, z },
                    .{ 0, 0, 0, 1 },
                },
            };
        }

        pub fn translationVec3(v: Vec(T, 3)) Self {
            comptime if (r != 4 or c != 4) {
                @compileError("Mat translationVec3 is only defined for 4x4 matrices");
            };

            return Self.translation(v.data[0], v.data[1], v.data[2]);
        }

        /// Returns a right-handed rotation transformation matrix.
        /// `angle` takes in radians.
        pub fn rotation(axis: Vec(T, 3), angle: T) Self {
            comptime if (r != 4 or c != 4) {
                @compileError("Mat rotation is only defined for 4x4 matrices");
            };

            var res = Self.identity();

            const cos_rads = math.cos(angle);
            const s = math.sin(angle);
            const omc = 1.0 - cos_rads;

            const x = axis.data[0];
            const y = axis.data[1];
            const z = axis.data[2];

            res.data[0][0] = x * x * omc + c;
            res.data[0][1] = x * y * omc - z * s;
            res.data[0][2] = x * z * omc + y * s;

            res.data[1][0] = y * x * omc + z * s;
            res.data[1][1] = y * y * omc + c;
            res.data[1][2] = y * z * omc - x * s;

            res.data[2][0] = z * x * omc - y * s;
            res.data[2][1] = z * y * omc + x * s;
            res.data[2][2] = z * z * omc + c;

            return res;
        }

        pub fn scaling(x: T, y: T, z: T) Self {
            comptime if (r != 4 or c != 4) {
                @compileError("Mat scaling is only defined for 4x4 matrices");
            };

            return Self{
                .data = .{
                    .{ x, 0, 0, 0 },
                    .{ 0, y, 0, 0 },
                    .{ 0, 0, z, 0 },
                    .{ 0, 0, 0, 1 },
                },
            };
        }

        pub fn scalingVec3(v: Vec(T, 3)) Self {
            comptime if (r != 4 or c != 4) {
                @compileError("Mat scalingVec3 is only defined for 4x4 matrices");
            };

            return Self.scaling(v.data[0], v.data[1], v.data[2]);
        }
    };
}

// Tests
const root = @import("root.zig");
const Mat2 = root.Mat2;
const Mat3 = root.Mat3;
const Mat4 = root.Mat4;

const vec2 = root.vec2;

fn mat2_eq(x: Mat2, y: Mat2) !void {
    const float_tolerance = std.math.floatEps(f32);
    try std.testing.expectApproxEqAbs(y.data[0][0], x.data[0][0], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[0][1], x.data[0][1], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[1][0], x.data[1][0], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[1][1], x.data[1][1], float_tolerance);
}

fn mat4_eq(x: Mat4, y: Mat4) !void {
    const float_tolerance = std.math.floatEps(f32);
    try std.testing.expectApproxEqAbs(y.data[0][0], x.data[0][0], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[0][1], x.data[0][1], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[0][2], x.data[0][2], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[0][3], x.data[0][3], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[1][0], x.data[1][0], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[1][1], x.data[1][1], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[1][2], x.data[1][2], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[1][3], x.data[1][3], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[2][0], x.data[2][0], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[2][1], x.data[2][1], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[2][2], x.data[2][2], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[2][3], x.data[2][3], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[3][0], x.data[3][0], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[3][1], x.data[3][1], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[3][2], x.data[3][2], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[3][3], x.data[3][3], float_tolerance);
}

test "Mat" {
    const float_tolerance = std.math.floatEps(f32);

    const zero = Mat2.zero();
    try std.testing.expectApproxEqAbs(0, zero.data[0][0], float_tolerance);
    try std.testing.expectApproxEqAbs(0, zero.data[0][1], float_tolerance);
    try std.testing.expectApproxEqAbs(0, zero.data[1][0], float_tolerance);
    try std.testing.expectApproxEqAbs(0, zero.data[1][1], float_tolerance);

    const id = Mat2.identity();
    try std.testing.expectApproxEqAbs(1, id.data[0][0], float_tolerance);
    try std.testing.expectApproxEqAbs(0, id.data[0][1], float_tolerance);
    try std.testing.expectApproxEqAbs(0, id.data[1][0], float_tolerance);
    try std.testing.expectApproxEqAbs(1, id.data[1][1], float_tolerance);

    const diag = Mat2.diagonal(2);
    try std.testing.expectApproxEqAbs(2, diag.data[0][0], float_tolerance);
    try std.testing.expectApproxEqAbs(0, diag.data[0][1], float_tolerance);
    try std.testing.expectApproxEqAbs(0, diag.data[1][0], float_tolerance);
    try std.testing.expectApproxEqAbs(2, diag.data[1][1], float_tolerance);

    const foo: Mat2 = .{ .data = .{ .{ 1, 2 }, .{ 3, 4 } } };
    const bar: Mat2 = .{ .data = .{ .{ 5, 6 }, .{ 7, 8 } } };

    try mat2_eq(foo.add(bar), .{ .data = .{ .{ 6, 8 }, .{ 10, 12 } } });
    try mat2_eq(foo.sub(bar), .{ .data = .{ .{ -4, -4 }, .{ -4, -4 } } });
    try mat2_eq(foo.muls(2), .{ .data = .{ .{ 2, 4 }, .{ 6, 8 } } });
    try mat2_eq(foo.divs(2), .{ .data = .{ .{ 0.5, 1 }, .{ 1.5, 2 } } });

    try mat2_eq(foo.transpose(), .{ .data = .{ .{ 1, 3 }, .{ 2, 4 } } });

    try mat2_eq(foo.mul(bar), .{ .data = .{ .{ 19, 22 }, .{ 43, 50 } } });

    const v = foo.mulv(vec2(5, 6));
    try std.testing.expectApproxEqAbs(17, v.data[0], float_tolerance);
    try std.testing.expectApproxEqAbs(39, v.data[1], float_tolerance);

    try std.testing.expectApproxEqAbs(5, foo.trace(), float_tolerance);

    try std.testing.expectApproxEqAbs(-2, foo.det(), float_tolerance);

    try mat2_eq(foo, (Mat3{ .data = .{ .{ 1, 3, 2 }, .{ 7, 8, 9 }, .{ 3, 5, 4 } } }).minor(1, 1));

    try mat2_eq(try foo.inverse(), .{ .data = .{ .{ -2, 1 }, .{ 1.5, -0.5 } } });
    const foo4 = Mat4{ .data = .{
        .{ 1, 2, 3, 4 },
        .{ 2, 2, 5, 6 },
        .{ 3, 5, 3, 7 },
        .{ 4, 6, 7, 4 },
    } };

    try mat4_eq(try foo4.inverse(), (Mat4{ .data = .{
        .{ -138, 60, 24, 6 },
        .{ 60, -47, 2, 7 },
        .{ 24, 2, -20, 8 },
        .{ 6, 7, 8, -11 },
    } }).divs(78));

    // TODO: Test other methods!
}
