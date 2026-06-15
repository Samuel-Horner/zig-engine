const std = @import("std");
const engine = @import("engine.zig");
const gl = @import("gl");
const Program = engine.Program;
const m = engine.math;
const c = engine.c;

var ft: c.FT_Library = undefined;

pub const Font = struct {
    pub const Character = struct {
        tex_id: u32,
        size: m.Vec2i,
        bearing: m.Vec2i,
        advance: u32,
    };

    // Restricted to only first 128 ASCII characters for simplicity
    // Indexed by u8 characters
    characters: [128]Character,

    line_height: i32 = 0,

    pub fn init(font_path: []const u8, height: c_uint) !Font {
        var font: Font = undefined;

        var face: c.FT_Face = undefined;
        if (c.FT_New_Face(ft, font_path.ptr, 0, &face) != 0) return error.FreeTypeFontFace;
        if (c.FT_Set_Pixel_Sizes(face, 0, height) != 0) return error.FreeTypeFontSize;

        // Disable byte-alignment restriction
        gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);

        for (0..128) |char| {
            // For each character from 0 to 128

            // Skip missing characters
            if (c.FT_Load_Char(face, char, c.FT_LOAD_RENDER) != 0) continue;

            // Create GL texture
            var tex_id: u32 = undefined;
            gl.GenTextures(1, (&tex_id)[0..1]);
            gl.BindTexture(gl.TEXTURE_2D, tex_id);
            gl.TexImage2D(
                gl.TEXTURE_2D,
                0,
                gl.RED,
                @intCast(face.*.glyph.*.bitmap.width),
                @intCast(face.*.glyph.*.bitmap.rows),
                0,
                gl.RED,
                gl.UNSIGNED_BYTE,
                face.*.glyph.*.bitmap.buffer,
            );

            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

            font.characters[char] = .{
                .tex_id = tex_id,
                .size = m.vec2i(@intCast(face.*.glyph.*.bitmap.width), @intCast(face.*.glyph.*.bitmap.rows)),
                .bearing = m.vec2i(@intCast(face.*.glyph.*.bitmap_left), @intCast(face.*.glyph.*.bitmap_top)),
                .advance = @intCast(face.*.glyph.*.advance.x),
            };

            if (font.characters[char].size.data[1] > font.line_height) font.line_height = font.characters[char].size.data[1];
        }

        if (c.FT_Done_Face(face) != 0) return error.FreeTypeFaceFree;

        std.log.debug("Initialised font: '{s}'.", .{font_path});

        return font;
    }
};

pub const TextRenderer = struct {
    prog: Program,

    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint,

    proj_loc: c_int,
    color_loc: c_int,

    pub fn updateProj(abstract_self: *anyopaque, width: c_int, height: c_int) void {
        const self: *TextRenderer = @ptrCast(@alignCast(abstract_self));

        const proj: m.Mat4 = m.Mat4.orthographic(0, @floatFromInt(width), 0, @floatFromInt(height), 0, 100).transpose();

        self.prog.use();
        gl.UniformMatrix4fv(self.proj_loc, 1, gl.FALSE, @ptrCast(&proj.data));
    }

    pub fn drawString(self: *const TextRenderer, font: *const Font, str: []const u8, pos: m.Vec2, color: m.Vec3, scale: f32) void {
        self.prog.use();
        gl.Uniform3f(self.color_loc, color.data[0], color.data[1], color.data[2]);
        gl.BindVertexArray(self.vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, self.vbo);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);

        gl.Enable(gl.BLEND);
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

        var x: f32 = pos.data[0];
        var y: f32 = pos.data[1];
        for (str) |char| {
            if (char == '\n') {
                y = pos.data[1] - @as(f32, @floatFromInt(font.line_height)) * scale;
                x = pos.data[0];
                continue;
            }

            const ch = font.characters[char];

            const xpos = x + @as(f32, @floatFromInt(ch.bearing.data[0])) * scale;
            const ypos = y - @as(f32, @floatFromInt((ch.size.data[1] - ch.bearing.data[1]))) * scale;

            const w = @as(f32, @floatFromInt(ch.size.data[0])) * scale;
            const h = @as(f32, @floatFromInt(ch.size.data[1])) * scale;

            const verts: [16]f32 = .{
                xpos,     ypos + h, 0, 0,
                xpos + w, ypos + h, 1, 0,
                xpos,     ypos,     0, 1,
                xpos + w, ypos,     1, 1,
            };

            gl.BindTexture(gl.TEXTURE_2D, ch.tex_id);
            gl.BufferSubData(gl.ARRAY_BUFFER, 0, @sizeOf(f32) * verts.len, &verts);
            gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);

            x += @as(f32, @floatFromInt((ch.advance >> 6))) * scale;
        }

        gl.Disable(gl.BLEND);
    }

    pub fn drawStringRelative(self: *const TextRenderer, font: *const Font, str: []const u8, pos: m.Vec2, color: m.Vec3, scale: f32) void {
        const s = scale * @as(f32, @floatFromInt(engine.window.width)) / 1080;

        self.drawString(
            font,
            str,
            m.vec2(
                pos.data[0] * @as(f32, @floatFromInt(engine.window.width)),
                pos.data[1] * @as(f32, @floatFromInt(engine.window.height)) - @as(f32, @floatFromInt(font.line_height)) * s,
            ),
            color,
            s,
        );
    }

    /// Returns a pointer. Remember to free this object.
    pub fn init(allocator: std.mem.Allocator, vertex_source: []const u8, fragment_source: []const u8) !*TextRenderer {
        var text_renderer: *TextRenderer = try allocator.create(TextRenderer);
        text_renderer.prog = try Program.init(vertex_source, fragment_source);

        text_renderer.proj_loc = gl.GetUniformLocation(text_renderer.prog.id, "proj");
        updateProj(text_renderer, engine.window.width, engine.window.height);
        try engine.window.registerFrameBufferSizeCallbackOwned(engine.allocator, text_renderer, updateProj);

        text_renderer.color_loc = gl.GetUniformLocation(text_renderer.prog.id, "text_color");

        gl.GenVertexArrays(1, (&text_renderer.vao)[0..1]);
        gl.GenBuffers(1, (&text_renderer.vbo)[0..1]);
        gl.GenBuffers(1, (&text_renderer.ebo)[0..1]);

        gl.BindVertexArray(text_renderer.vao);

        gl.BindBuffer(gl.ARRAY_BUFFER, text_renderer.vbo);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, text_renderer.ebo);

        gl.BufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(f32) * 4 * 4), null, gl.DYNAMIC_DRAW);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * 2 * 3), &[6]u32{ 0, 2, 3, 0, 3, 1 }, gl.STATIC_DRAW);

        gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, @intCast(@sizeOf(f32) * 4), 0);
        gl.EnableVertexAttribArray(0);

        return text_renderer;
    }
};

pub fn init() !void {
    if (c.FT_Init_FreeType(&ft) != 0) return error.FreeTypeInit;

    var major: c_int = undefined;
    var minor: c_int = undefined;
    var patch: c_int = undefined;
    c.FT_Library_Version(ft, &major, &minor, &patch);
    std.log.debug("Initialised FreeType {}.{}.{}.", .{ major, minor, patch });
}

pub fn deinit() !void {
    if (c.FT_Done_FreeType(ft) != 0) return error.FreeTypeFree;
}
