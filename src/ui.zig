const std = @import("std");
const engine = @import("engine.zig");
const gl = @import("gl");
const Program = engine.Program;
const m = engine.math;
const c = engine.c;

var ft: c.FT_Library = undefined;

pub var text_renderer: *TextRenderer = undefined;
pub var atlas_text_renderer: *AtlasTextRenderer = undefined;

pub const Font = struct {
    const Character = struct {
        tex_id: u32,
        size: m.Vec2i,
        bearing: m.Vec2i,
        advance: u32,
    };

    // Restricted to only first 128 ASCII characters for simplicity
    // Indexed by u8 characters
    characters: [128]Character,

    line_height: u32 = 0,

    pub fn init(font_path: []const u8, height: c_uint) !Font {
        var font: Font = undefined;

        var face: c.FT_Face = undefined;
        if (c.FT_New_Face(ft, font_path.ptr, 0, &face) != 0) return error.FreeTypeFontFace;
        if (c.FT_Set_Pixel_Sizes(face, 0, height) != 0) return error.FreeTypeFontSize;

        font.line_height = @intCast(face.*.size.*.metrics.height >> 6);

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
        }

        if (c.FT_Done_Face(face) != 0) return error.FreeTypeFaceFree;

        std.log.debug("Initialised font: '{s}'.", .{font_path});

        return font;
    }
};

// Atlas font
// Similar font implementation, but combines all character bitmaps into one atlas texture.
pub const AtlasFont = struct {
    const Character = struct {
        tex_pos: m.Vec2i,
        size: m.Vec2i,
        bearing: m.Vec2i,
        advance: u32,
    };

    characters: [128]Character,
    tex_id: u32,
    line_height: u32 = 0,

    tex_size: m.Vec2i,

    pub fn init(allocator: std.mem.Allocator, font_path: []const u8, height: c_uint) !AtlasFont {
        // Taken from https://gist.github.com/baines/b0f9e4be04ba4e6f56cab82eef5008ff
        var font: AtlasFont = undefined;

        var face: c.FT_Face = undefined;
        if (c.FT_New_Face(ft, font_path.ptr, 0, &face) != 0) return error.FreeTypeFontFace;
        if (c.FT_Set_Pixel_Sizes(face, 0, height) != 0) return error.FreeTypeFontSize;

        font.line_height = @intCast(face.*.size.*.metrics.height >> 6);

        // Estimate atlas size
        const max_dim = (1 + (font.line_height)) * 12; // @ceil(@sqrt(128))
        var tex_width: u32 = 1;
        while (tex_width < max_dim) tex_width = tex_width << 1;
        const tex_height: u32 = tex_width;

        font.tex_size = m.vec2i(@intCast(tex_width), @intCast(tex_height));

        var data = try allocator.alloc(u8, tex_width * tex_height);
        defer allocator.free(data);

        var ix: u32 = 0;
        var iy: u32 = 0;
        for (0..128) |char| {
            // For each character from 0 to 128
            // Skip missing characters
            if (c.FT_Load_Char(face, char, c.FT_LOAD_RENDER) != 0) continue;
            const bitmap = &face.*.glyph.*.bitmap;

            if (ix + bitmap.*.width >= tex_width) {
                ix = 0;
                iy += @intCast(font.line_height + 1);
            }

            for (0..bitmap.*.rows) |row| {
                for (0..bitmap.*.width) |col| {
                    const x = ix + col;
                    const y = iy + row;
                    data[y * tex_width + x] = bitmap.*.buffer[row * @as(usize, @intCast(bitmap.*.pitch)) + col];
                }
            }

            font.characters[char] = .{
                .tex_pos = m.vec2i(@intCast(ix), @intCast(iy)),
                .size = m.vec2i(@intCast(bitmap.*.width), @intCast(bitmap.*.rows)),
                .bearing = m.vec2i(@intCast(face.*.glyph.*.bitmap_left), @intCast(face.*.glyph.*.bitmap_top)),
                .advance = @intCast(face.*.glyph.*.advance.x),
            };

            ix += @intCast(bitmap.*.width + 1);
        }

        if (c.FT_Done_Face(face) != 0) return error.FreeTypeFaceFree;

        // Disable byte-alignment restriction
        gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);

        gl.GenTextures(1, (&font.tex_id)[0..1]);
        gl.BindTexture(gl.TEXTURE_2D, font.tex_id);
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            @intCast(tex_width),
            @intCast(tex_height),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            data.ptr,
        );

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        std.log.debug("Initialised font: '{s}'.", .{font_path});

        return font;
    }
};

pub const TextRenderer = struct {
    /// This is a very naive implementation. If you want something faster, I would reccomend using AtlasRenderer
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
                y = y - @as(f32, @floatFromInt(font.line_height)) * scale;
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
        const s = scale * @as(f32, @floatFromInt(engine.window.width)) / 1920;

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
        var renderer: *TextRenderer = try allocator.create(TextRenderer);
        renderer.prog = try Program.init(vertex_source, fragment_source);

        renderer.proj_loc = gl.GetUniformLocation(renderer.prog.id, "proj");
        updateProj(renderer, engine.window.width, engine.window.height);
        try engine.window.registerFrameBufferSizeCallbackOwned(engine.allocator, renderer, updateProj);

        renderer.color_loc = gl.GetUniformLocation(renderer.prog.id, "text_color");

        gl.GenVertexArrays(1, (&renderer.vao)[0..1]);
        gl.GenBuffers(1, (&renderer.vbo)[0..1]);
        gl.GenBuffers(1, (&renderer.ebo)[0..1]);

        gl.BindVertexArray(renderer.vao);

        gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, renderer.ebo);

        gl.BufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(f32) * 4 * 4), null, gl.DYNAMIC_DRAW);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * 2 * 3), &[6]u32{ 0, 2, 3, 0, 3, 1 }, gl.STATIC_DRAW);

        gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, @intCast(@sizeOf(f32) * 4), 0);
        gl.EnableVertexAttribArray(0);

        return renderer;
    }
};

pub const AtlasTextRenderer = struct {
    /// Better, more performant (maybe), text renderer.
    /// Known issues:
    ///     - Ghosting artifacts around glyph borders at some resolution / height mismatches
    const BufferItem = packed struct {
        x: f32 = 0,
        y: f32 = 0,

        width: f32 = 0,
        height: f32 = 0,

        tex_orig_x: f32 = 0,
        tex_orig_y: f32 = 0,

        tex_width: f32 = 0,
        tex_height: f32 = 0,
    };

    const buffer_item_size = @sizeOf(BufferItem);

    prog: Program,

    ssbo: c_uint,
    bind_point: c_uint,
    buffer_size: usize,

    buffer_prep: []BufferItem,

    proj_loc: c_int,
    color_loc: c_int,
    scale_loc: c_int,

    pub fn updateProj(generic_self: *anyopaque, width: c_int, height: c_int) void {
        const self: *AtlasTextRenderer = @ptrCast(@alignCast(generic_self));

        const proj: m.Mat4 = m.Mat4.orthographic(0, @floatFromInt(width), 0, @floatFromInt(height), 0, 100).transpose();

        self.prog.use();
        gl.UniformMatrix4fv(self.proj_loc, 1, gl.FALSE, @ptrCast(&proj.data));
    }

    pub fn drawStringBuffer(self: *const AtlasTextRenderer, font: *const AtlasFont, str: []const u8, pos: m.Vec2, global_pos: m.Vec2, color: m.Vec3, scale: f32) !m.Vec2 {
        if (str.len > self.buffer_size) {
            return error.StringOverflowsBuffer;
        }

        self.prog.use();
        gl.Uniform3f(self.color_loc, color.data[0], color.data[1], color.data[2]);

        gl.BindTexture(gl.TEXTURE_2D, font.tex_id);

        gl.BindVertexArray(engine.empty_vao);
        gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, self.bind_point, self.ssbo);

        gl.Enable(gl.BLEND);
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

        var x: f32 = pos.data[0];
        var y: f32 = pos.data[1];
        for (str, 0..) |char, i| {
            if (char == '\n') {
                y = y - @as(f32, @floatFromInt(font.line_height)) * scale;
                x = global_pos.data[0];
                // Empty Slot
                self.buffer_prep[i] = .{};
                continue;
            }

            const ch = font.characters[char];

            const xpos = x + @as(f32, @floatFromInt(ch.bearing.data[0])) * scale;
            const ypos = y - @as(f32, @floatFromInt((ch.size.data[1] - ch.bearing.data[1]))) * scale;

            const item = BufferItem{
                .x = xpos,
                .y = ypos,

                .width = @as(f32, @floatFromInt(ch.size.data[0])) * scale,
                .height = @as(f32, @floatFromInt(ch.size.data[1])) * scale,

                .tex_orig_x = @as(f32, @floatFromInt(ch.tex_pos.data[0])) / @as(f32, @floatFromInt(font.tex_size.data[0])),
                .tex_orig_y = @as(f32, @floatFromInt(ch.tex_pos.data[1])) / @as(f32, @floatFromInt(font.tex_size.data[1])),

                .tex_width = @as(f32, @floatFromInt(ch.size.data[0])) / @as(f32, @floatFromInt(font.tex_size.data[0])),
                .tex_height = @as(f32, @floatFromInt(ch.size.data[1])) / @as(f32, @floatFromInt(font.tex_size.data[1])),
            };

            // gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, @intCast(i * buffer_item_size), @intCast(buffer_item_size), &item);
            self.buffer_prep[i] = item;

            x += @as(f32, @floatFromInt((ch.advance >> 6))) * scale;
        }

        const bytes = std.mem.sliceAsBytes(self.buffer_prep);
        gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, @intCast(buffer_item_size * str.len), bytes.ptr);

        // Draw 6 * #chars verts
        gl.DrawArrays(gl.TRIANGLES, 0, @intCast(str.len * 6));

        gl.Disable(gl.BLEND);
        return m.vec2(x, y);
    }

    pub fn drawString(self: *const AtlasTextRenderer, font: *const AtlasFont, str: []const u8, pos: m.Vec2, color: m.Vec3, scale: f32) !void {
        var iter = std.mem.window(u8, str, self.buffer_size, self.buffer_size);
        var i_pos: m.Vec2 = pos;
        while (iter.next()) |slice| {
            i_pos = try self.drawStringBuffer(font, slice, i_pos, pos, color, scale);
        }
    }

    pub fn drawStringRelative(self: *const AtlasTextRenderer, font: *const AtlasFont, str: []const u8, pos: m.Vec2, color: m.Vec3, scale: f32) !void {
        const s = scale * (@as(f32, @floatFromInt(engine.window.width)) / 1920) * (32 / @as(f32, @floatFromInt(font.line_height)));

        try self.drawString(
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

    pub fn init(allocator: std.mem.Allocator, vertex_source: []const u8, fragment_source: []const u8, buffer_size: usize, bind_point: c_uint) !*AtlasTextRenderer {
        var renderer: *AtlasTextRenderer = try allocator.create(AtlasTextRenderer);
        renderer.prog = try Program.init(vertex_source, fragment_source);

        renderer.buffer_size = buffer_size;
        renderer.bind_point = bind_point;
        renderer.buffer_prep = try allocator.alloc(BufferItem, buffer_size);

        renderer.proj_loc = gl.GetUniformLocation(renderer.prog.id, "proj");
        updateProj(renderer, engine.window.width, engine.window.height);
        try engine.window.registerFrameBufferSizeCallbackOwned(engine.allocator, renderer, updateProj);

        renderer.color_loc = gl.GetUniformLocation(renderer.prog.id, "text_color");

        gl.GenBuffers(1, (&renderer.ssbo)[0..1]);
        gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, renderer.ssbo);

        gl.BufferData(gl.SHADER_STORAGE_BUFFER, @intCast(buffer_size * @sizeOf(BufferItem)), null, gl.DYNAMIC_DRAW);

        return renderer;
    }

    pub fn deinit(self: *AtlasTextRenderer, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer_prep);
        allocator.destroy(self);
    }
};

pub fn init(allocator: std.mem.Allocator, opts: struct { text_buffer_size: usize = 256 }) !void {
    if (c.FT_Init_FreeType(&ft) != 0) return error.FreeTypeInit;

    var major: c_int = undefined;
    var minor: c_int = undefined;
    var patch: c_int = undefined;
    c.FT_Library_Version(ft, &major, &minor, &patch);
    std.log.debug("Initialised FreeType {}.{}.{}.", .{ major, minor, patch });

    text_renderer = try TextRenderer.init(allocator, @embedFile("shader/text_vert.glsl"), @embedFile("shader/text_frag.glsl"));
    atlas_text_renderer = try AtlasTextRenderer.init(allocator, @embedFile("shader/atlas_text_vert.glsl"), @embedFile("shader/atlas_text_frag.glsl"), opts.text_buffer_size, 0);
}

pub fn deinit(allocator: std.mem.Allocator) !void {
    allocator.destroy(text_renderer);
    atlas_text_renderer.deinit(allocator);

    if (c.FT_Done_FreeType(ft) != 0) return error.FreeTypeFree;
}
