const vec = @import("vec.zig");
const mat = @import("mat.zig");

// Largely taken from ZM.
pub fn Quaternion(comptime T: type) type {
    comptime if (@typeInfo(T) != .float) {
        @compileError("Quaternion is not supported for non-float types");
    };

    return struct {
        w: T,
        x: T,
        y: T,
        z: T,

        const Self = @This();

        pub fn identity() Self {
            return .{ .w = 1, .x = 0, .y = 0, .z = 0 };
        }

        pub fn init(w: T, x: T, y: T, z: T) Self {
            return .{ .w = w, .x = x, .y = y, .z = z };
        }

        pub fn fromVec3(w: T, axis: vec.Vec(T, 3)) Self {
            return Self.init(w, axis.data[0], axis.data[1], axis.data[2]);
        }

        pub fn fromAxisAngle(axis: vec.Vec(T, 3), radians: T) Self {
            const sin_half_angle = @sin(radians / 2);
            const w = @cos(radians / 2);
            return Self.fromVec3(w, axis.norm().muls(sin_half_angle));
        }

        pub fn fromEulerAngles(v: vec.Vec(3, T), order: enum { xyz, xzy, yxz, yzx, zxy, zyx }) Self {
            const x = Self.fromAxisAngle(vec.Vec(3, T){ .data = .{ 1, 0, 0 } }, v.data[0]);
            const y = Self.fromAxisAngle(vec.Vec(3, T){ .data = .{ 0, 1, 0 } }, v.data[1]);
            const z = Self.fromAxisAngle(vec.Vec(3, T){ .data = .{ 0, 0, 1 } }, v.data[2]);

            return switch (order) {
                .xyz => x.mul(y).mul(z),
                .xzy => x.mul(z).mul(y),
                .yxz => y.mul(x).mul(z),
                .yzx => y.mul(x).mul(z),
                .zxy => z.mul(x).mul(y),
                .zyx => z.mul(y).mul(x),
            };
        }

        pub fn fromMat3(m: mat.Mat(T, 3, 3)) Self {
            // https://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
            const trace = m.trace();
            var q: Self = undefined;

            if (trace > 0) {
                const s = @sqrt(trace + 1.0) * 2.0;
                q.w = 0.25 * s;
                q.x = (m.data[2][1] - m.data[1][2]) / s;
                q.y = (m.data[0][2] - m.data[2][0]) / s;
                q.z = (m.data[1][0] - m.data[0][1]) / s;
            } else if (m.data[0][0] > m.data[1][1] and m.data[0][0] > m.data[2][2]) {
                const s = @sqrt(1.0 + m.data[0][0] - m.data[1][1] - m.data[2][2]) * 2.0;
                q.w = (m.data[2][1] - m.data[1][2]) / s;
                q.x = 0.25 * s;
                q.y = (m.data[0][1] + m.data[1][0]) / s;
                q.z = (m.data[0][2] + m.data[2][0]) / s;
            } else if (m.data[1][1] > m.data[2][2]) {
                const s = @sqrt(1.0 + m.data[1][1] - m.data[0][0] - m.data[2][2]) * 2.0;
                q.w = (m.data[0][2] - m.data[2][0]) / s;
                q.x = (m.data[0][1] + m.data[1][0]) / s;
                q.y = 0.25 * s;
                q.z = (m.data[1][2] + m.data[2][1]) / s;
            } else {
                const s = @sqrt(1.0 + m.data[2][2] - m.data[0][0] - m.data[1][1]) * 2.0;
                q.w = (m.data[1][0] - m.data[0][1]) / s;
                q.x = (m.data[0][2] + m.data[2][0]) / s;
                q.y = (m.data[1][2] + m.data[2][1]) / s;
                q.z = 0.25 * s;
            }

            return q;
        }

        pub fn fromMat4(m: mat.Mat(T, 4, 4)) Self {
            // https://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
            const trace = m.data[0][0] + m.data[1][1] + m.data[2][2];
            var q: Self = undefined;

            if (trace > 0) {
                const s = @sqrt(trace + 1.0) * 2.0;
                q.w = 0.25 * s;
                q.x = (m.data[2][1] - m.data[1][2]) / s;
                q.y = (m.data[0][2] - m.data[2][0]) / s;
                q.z = (m.data[1][0] - m.data[0][1]) / s;
            } else if (m.data[0][0] > m.data[1][1] and m.data[0][0] > m.data[2][2]) {
                const s = @sqrt(1.0 + m.data[0][0] - m.data[1][1] - m.data[2][2]) * 2.0;
                q.w = (m.data[2][1] - m.data[1][2]) / s;
                q.x = 0.25 * s;
                q.y = (m.data[0][1] + m.data[1][0]) / s;
                q.z = (m.data[0][2] + m.data[2][0]) / s;
            } else if (m.data[1][1] > m.data[2][2]) {
                const s = @sqrt(1.0 + m.data[1][1] - m.data[0][0] - m.data[2][2]) * 2.0;
                q.w = (m.data[0][2] - m.data[2][0]) / s;
                q.x = (m.data[0][1] + m.data[1][0]) / s;
                q.y = 0.25 * s;
                q.z = (m.data[1][2] + m.data[2][1]) / s;
            } else {
                const s = @sqrt(1.0 + m.data[2][2] - m.data[0][0] - m.data[1][1]) * 2.0;
                q.w = (m.data[1][0] - m.data[0][1]) / s;
                q.x = (m.data[0][2] + m.data[2][0]) / s;
                q.y = (m.data[1][2] + m.data[2][1]) / s;
                q.z = 0.25 * s;
            }

            return q;
        }

        pub fn add(lhs: Self, rhs: Self) Self {
            return Self.init(lhs.w + rhs.w, lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z);
        }

        pub fn sub(lhs: Self, rhs: Self) Self {
            return Self.init(lhs.w - rhs.w, lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z);
        }

        pub fn mul(lhs: Self, rhs: Self) Self {
            return .{
                .w = lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
                .x = lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
                .y = lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
                .z = lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w,
            };
        }

        pub fn invert(self: Self) Self {
            return .{ .w = -self.w, .x = -self.x, .y = -self.y, .z = -self.z };
        }

        pub fn norm(self: Self) Self {
            const m = @sqrt(self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z);
            if (m > 0.0) {
                const i_m = 1.0 / m;
                return .{ .w = self.w * i_m, .x = self.x * i_m, .y = self.y * i_m, .z = self.z * i_m };
            } else {
                return Self.identity();
            }
        }

        pub fn conjugate(self: Self) Self {
            return .{ .w = self.w, .x = -self.x, .y = -self.y, .z = -self.z };
        }

        pub fn dot(lhs: Self, rhs: Self) T {
            return lhs.w * rhs.w + lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
        }
    };
}

test "Quaternion" {
    // TODO: Write quaternion tests
}
