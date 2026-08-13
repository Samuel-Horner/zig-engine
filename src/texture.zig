/// Immutable storage OpenGL texture
const std = @import("std");
const gl = @import("gl");

pub const Format = struct {
    const channels = enum {
        RGBA,
        RGB,
        RG,
        R,
    };

    const sizes = enum {
        @"2",
        @"4",
        @"5",
        @"8",
        @"10",
        @"12",
        @"16",
        @"32",
    };

    const types = enum {
        /// Signed normalised
        _SNORM,
        F,
        I,
        UI,
    };

    /// Dynamically fetches image format, e.g.
    /// ``` Zig
    ///     Format.get(.RGBA, 16, .F);
    /// ```
    /// returns gl.RGBA16F
    ///
    /// Pass null as the size to not specify it.
    /// Pass null as the type to use normalised int.
    ///
    /// Some combintations will not be valid - check [https://wikis.khronos.org/opengl/Image_Format](https://wikis.khronos.org/opengl/Image_Format).
    pub fn get(comptime channel: channels, comptime size: ?sizes, comptime storage_type: ?types) c_int {
        const name = @tagName(channel) ++ (if (size != null) @tagName(size.?) else "") ++ (if (storage_type != null) @tagName(storage_type.?) else "");
        return @field(gl, name);
        
    }
};

const Parameter = struct {
    name: c_uint,
    value: c_int,
    type: enum {
        i,
    } = .i,
};

id: c_uint,
target: c_uint,

const Self = @This();

pub fn bind(self: *const Self, unit: ?c_uint) void {
    if (unit != null) {
        gl.ActiveTexture(unit.?);
    }

    gl.BindTexture(self.target, self.id);
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn init(data: []u8, width: c_int, height: c_int, opts: struct {
    target: c_uint = gl.TEXTURE_2D,
    format: c_uint = gl.RGB,
    data_type: c_uint = gl.UNSIGNED_BYTE,
    border: c_int = 0,

    parameters: []const Parameter = &.{
        .{ .name = gl.TEXTURE_WRAP_S, .value = gl.REPEAT },
        .{ .name = gl.TEXTURE_WRAP_T, .value = gl.REPEAT },
        .{ .name = gl.TEXTURE_MIN_FILTER, .value = gl.LINEAR_MIPMAP_LINEAR },
        .{ .name = gl.TEXTURE_MAG_FILTER, .value = gl.LINEAR },
    },

    gen_mip_maps: bool = true,
}) !Self {
    var self: Self = undefined;

    self.target = opts.target;

    gl.GenTextures(1, (&self.id)[0..1]);
    gl.BindTexture(self.target, self.id);

    for (opts.parameters) |parameter| {
        switch (parameter.type) {
            .i => gl.TexParameteri(self.target, parameter.name, parameter.value),
            // else => return error.UnsuportedParameterType,
        }
    }

    switch (self.target) {
        gl.TEXTURE_2D => gl.TexImage2D(self.target, 0, @intCast(opts.format), width, height, opts.border, opts.format, opts.data_type, data.ptr),
        else => return error.UnsuportedTextureType,
    }

    gl.GenerateMipmap(self.target);

    return self;
}
