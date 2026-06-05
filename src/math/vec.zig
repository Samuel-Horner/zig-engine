const std = @import("std");

pub fn Vec(comptime T: type, comptime len: comptime_int) type {
    return struct {
        const Self = @This();

        data: [len]T,

        pub fn zero() Self {
            return .{ .data = @splat(0) };
        }

        pub fn splat(v: T) Self {
            return .{ .data = @splat(v) };
        }

        pub fn add(self: Self, other: Self) Self {
            var res: Self = undefined;
            inline for (0..len) |i| {
                res.data[i] = self.data[i] + other.data[i];
            }
            return res;
        }

        pub fn sub(self: Self, other: Self) Self {
            var res: Self = undefined;
            inline for (0..len) |i| {
                res.data[i] = self.data[i] - other.data[i];
            }
            return res;
        }

        pub fn mul(self: Self, other: Self) Self {
            var res: Self = undefined;
            inline for (0..len) |i| {
                res.data[i] = self.data[i] * other.data[i];
            }
            return res;
        }

        pub fn div(self: Self, other: Self) Self {
            var res: Self = undefined;
            inline for (0..len) |i| {
                res.data[i] = self.data[i] / other.data[i];
            }
            return res;
        }

        pub fn muls(self: Self, scalar: T) Self {
            var res: Self = undefined;
            inline for (0..len) |i| {
                res.data[i] = self.data[i] * scalar;
            }
            return res;
        }

        pub fn divs(self: Self, scalar: T) Self {
            var res: Self = undefined;
            inline for (0..len) |i| {
                res.data[i] = self.data[i] / scalar;
            }
            return res;
        }

        pub fn dot(self: Self, other: Self) T {
            var sum: T = 0;
            inline for (0..len) |i| {
                sum += self.data[i] * other.data[i];
            }
            return sum;
        }

        pub fn lengthSquared(self: Self) T {
            return self.dot(self);
        }

        pub fn length(self: Self) T {
            comptime if (@typeInfo(T) != .float) {
                @compileError("Vec length is not supported for non-float types.");
            };
            return @sqrt(self.lengthSquared());
        }

        pub fn norm(self: Self) Self {
            const mag = self.length();
            std.debug.assert(mag != 0);
            return self.divs(mag);
        }

        pub fn distanceSquared(self: Self, other: Self) T {
            var sum: T = 0;
            inline for (0..len) |i| {
                const delta = self.data[i] - other.data[i];
                sum += delta * delta;
            }
            return sum;
        }

        pub fn distance(self: Self, other: Self) T {
            comptime if (@typeInfo(T) != .float) {
                @compileError("Vec distance is not supported for non-float types.");
            };
            return @sqrt(self.distanceSquared(other));
        }

        pub fn angle(a: Self, b: Self) T {
            comptime if (@typeInfo(T) != .float) {
                @compileError("Vec angle is not supported for non-float types.");
            };
            return std.math.acos(a.dot(b) / (a.length() * b.length()));
        }

        pub fn lerp(a: Self, b: Self, t: T) Self {
            var res: Self = undefined;
            inline for (0..len) |i| {
                res.data[i] = @mulAdd(T, b.data[i] - a.data[i], t, a.data[i]);
            }
            return res;
        }

        /// Requires normal to be normalised.
        pub fn reflect(self: Self, normal: Self) Self {
            const dot_ = self.dot(normal);
            var res: Self = undefined;
            inline for (0..len) |i| {
                res.data[i] = self.data[i] - 2 * dot_ * normal.data[i];
            }
            return res;
        }

        /// Right-handed cross product
        pub fn cross(self: Self, other: Self) Self {
            comptime if (len != 3) {
                @compileError("Vec cross is only defined for 3-vectors");
            };

            return .{
                .data = .{
                    self.data[1] * other.data[2] - self.data[2] * other.data[1],
                    self.data[2] * other.data[0] - self.data[0] * other.data[2],
                    self.data[0] * other.data[1] - self.data[1] * other.data[0],
                },
            };
        }

        pub fn invert(self: Self) Self {
            return .{ .data = .{
                -self.data[0],
                -self.data[1],
                -self.data[2],
            } };
        }
    };
}

// Tests
const root = @import("root.zig");
const Vec3 = root.Vec3;
const vec3 = root.vec3;

fn vec3_eq(x: Vec3, y: Vec3) !void {
    const float_tolerance = std.math.floatEps(f32);
    try std.testing.expectApproxEqAbs(y.data[0], x.data[0], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[1], x.data[1], float_tolerance);
    try std.testing.expectApproxEqAbs(y.data[2], x.data[2], float_tolerance);
}

test "Vec" {
    const float_tolerance = std.math.floatEps(f32);

    const zero = Vec3.zero();
    try std.testing.expectApproxEqAbs(0, zero.data[0], float_tolerance);
    try std.testing.expectApproxEqAbs(0, zero.data[1], float_tolerance);
    try std.testing.expectApproxEqAbs(0, zero.data[2], float_tolerance);

    const foo = vec3(2, 3, 4);
    try std.testing.expectApproxEqAbs(2, foo.data[0], float_tolerance);
    try std.testing.expectApproxEqAbs(3, foo.data[1], float_tolerance);
    try std.testing.expectApproxEqAbs(4, foo.data[2], float_tolerance);

    const bar = vec3(5, 6, 7);
    try vec3_eq(foo.add(bar), vec3(7, 9, 11));
    try vec3_eq(bar.sub(foo), vec3(3, 3, 3));
    try vec3_eq(foo.mul(bar), vec3(10, 18, 28));
    try vec3_eq(foo.div(bar), vec3(2.0 / 5.0, 3.0 / 6.0, 4.0 / 7.0));

    try vec3_eq(foo.muls(2), vec3(4, 6, 8));
    try vec3_eq(foo.divs(2), vec3(1, 3.0 / 2.0, 2));

    try std.testing.expectApproxEqAbs(10 + 18 + 28, foo.dot(bar), float_tolerance);
    try std.testing.expectApproxEqAbs(4 + 9 + 16, foo.lengthSquared(), float_tolerance);
    try std.testing.expectApproxEqAbs(@sqrt(@as(f32, 4 + 9 + 16)), foo.length(), float_tolerance);

    const length = foo.length();
    try vec3_eq(foo.norm(), foo.divs(length));

    try std.testing.expectApproxEqAbs(foo.sub(bar).lengthSquared(), foo.distanceSquared(bar), float_tolerance);
    try std.testing.expectApproxEqAbs(foo.sub(bar).length(), foo.distance(bar), float_tolerance);

    try std.testing.expectApproxEqAbs(std.math.acos((foo.dot(bar)) / (foo.length() * bar.length())), foo.angle(bar), float_tolerance);

    try vec3_eq(foo.lerp(bar, 0.5), vec3(3.5, 4.5, 5.5));

    try vec3_eq(foo.reflect(vec3(0, 1, 0)), vec3(2, -3, 4));

    try vec3_eq(foo.cross(bar), vec3(-3, 6, -3));

    try vec3_eq(foo.invert(), vec3(-2, -3, -4));
}
