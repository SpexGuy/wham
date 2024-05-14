const std = @import("std");
const zimg = @import("zigimg");
const bfnt = @import("bfnt.zig");

var permanent = std.heap.ArenaAllocator.init(std.heap.page_allocator);

pub fn main() !void {
    const args = try std.process.argsAlloc(permanent.allocator());

    for (args[1..]) |arg| {
        bakeFont(arg) catch |err| {
            if (err != error.FontBake_ErrorReported) {
                std.debug.print("Unknown error: {}\n", .{ err });
            }
            std.debug.print("Failed to bake {s}\n", .{ arg });
        };
    }
}

fn bakeFont(filename: []const u8) !void {
    var baker = FontBake{
        .filename = filename,
        .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
    };
    defer baker.arena.deinit();
    return baker.bake();
}

const page_unused: u8 = 0xFF;

const Page = struct {
    filename: []const u8,
    id: i32,
    actual_index: u8 = page_unused,
};

const FontBake = struct {
    arena: std.heap.ArenaAllocator,
    filename: []const u8,
    linenum: usize = 0,
    lines: std.mem.SplitIterator(u8) = undefined,
    line: []const u8 = "",
    line_pos: usize = 0,
    used_pages: u8 = 0,

    pub fn bake(self: *FontBake) !void {
        const file_contents = std.fs.cwd().readFileAlloc(self.arena.allocator(), self.filename, 1 * 1024 * 1024)
            catch |e| return self.err("Failed to read file: {}", .{e});
        self.lines = std.mem.split(u8, file_contents, "\n");

        try self.requireNextLine("info");
        try self.requireKVIgnore("face");
        const font_size = try self.requireKVInt(u32, "size");
        try self.requireKVIgnore("bold");
        try self.requireKVIgnore("italic");
        try self.requireKVIgnore("charset");
        try self.requireKVIgnore("unicode");
        try self.requireKVIgnore("stretchH");
        try self.requireKVIgnore("smooth");
        try self.requireKVIgnore("aa");
        const padding = try self.requireKVIntArray(4, i32, "padding");
        const spacing = try self.requireKVIntArray(2, i32, "spacing");
        try self.requireEOL();
        
        try self.requireNextLine("common");
        const lineHeight = try self.requireKVInt(i32, "lineHeight");
        const base = try self.requireKVInt(i32, "base");
        const scaleW = try self.requireKVInt(u32, "scaleW");
        const scaleH = try self.requireKVInt(u32, "scaleH");
        const num_pages = try self.requireKVInt(u32, "pages");
        try self.requireKVIgnore("packed");
        try self.requireEOL();

        const pages = try self.arena.allocator().alloc(Page, num_pages);
        for (pages) |*page| {
            try self.requireNextLine("page");
            const id = try self.requireKVInt(i32, "id");
            const filename = try self.requireKVString("file");
            try self.requireEOL();

            page.* = .{
                .id = id,
                .filename = filename,
            };
        }

        try self.requireNextLine("chars");
        const num_chars = try self.requireKVInt(u32, "count");
        try self.requireEOL();

        const chars = try self.arena.allocator().alloc(bfnt.BfntChar, num_chars);
        for (chars) |*char| {
            try self.requireNextLine("char");
            const id = try self.requireKVInt(u16, "id");
            const x = try self.requireKVInt(i16, "x");
            const y = try self.requireKVInt(i16, "y");
            const width = try self.requireKVInt(i16, "width");
            const height = try self.requireKVInt(i16, "height");
            const xoffset = try self.requireKVInt(i16, "xoffset");
            const yoffset = try self.requireKVInt(i16, "yoffset");
            const xadvance = try self.requireKVInt(i16, "xadvance");
            const page = try self.requireKVInt(i16, "page");
            const channel = try self.requireKVInt(u16, "chnl");
            try self.requireEOL();

            if (channel != 0)
                return self.err("TODO: Implement handling for input images with multiple channels.  Channel was {}", .{channel});

            char.* = .{
                .char = id,
                .x = x,
                .y = y,
                .width = width,
                .height = height,
                .x_offset = xoffset,
                .y_offset = yoffset,
                .x_advance = xadvance,
                .page = try self.markPage(pages, page),
            };
        }

        try self.requireNextLine("kernings");
        const num_kerns = try self.requireKVInt(u32, "count");
        try self.requireEOL();

        const kerns = try self.arena.allocator().alloc(bfnt.BfntKern, num_kerns);
        for (kerns) |*kern| {
            try self.requireNextLine("kerning");
            const first = try self.requireKVInt(u16, "first");
            const second = try self.requireKVInt(u16, "second");
            const amount = try self.requireKVInt(i16, "amount");
            try self.requireEOL();

            kern.* = .{
                .first = first,
                .second = second,
                .amount = amount,
            };
        }

        try self.requireEOF();

        // We have all of the parts of the file now, next we need to create
        // the output file layout, and then import the image data
        const file_layout_size = bfnt.BfntHeader.calcSize(num_chars, num_kerns, self.used_pages, .{scaleW, scaleH});
        const file_layout_bytes = try self.arena.allocator().alignedAlloc(u8, @alignOf(bfnt.BfntHeader), file_layout_size);
        var write_ptr: [*]u8 = file_layout_bytes.ptr;
        const header = ptrAlignCast(*bfnt.BfntHeader, write_ptr);
        write_ptr += @sizeOf(bfnt.BfntHeader);
        header.* = .{
            .num_chars = num_chars,
            .num_kerns = num_kerns,
            .num_pages = self.used_pages,
            .padding = padding,
            .spacing = spacing,
            .page_size = .{scaleW, scaleH},
            .line_height = lineHeight,
            .line_base = base,
            .native_size = font_size,
            .spread = 6, // TODO don't hardcode this
        };
        @memcpy(write_ptr, @ptrCast([*]const u8, chars.ptr), chars.len * @sizeOf(bfnt.BfntChar));
        write_ptr += chars.len * @sizeOf(bfnt.BfntChar);
        @memcpy(write_ptr, @ptrCast([*]const u8, kerns.ptr), kerns.len * @sizeOf(bfnt.BfntKern));
        write_ptr += kerns.len * @sizeOf(bfnt.BfntKern);

        const dirname = std.fs.path.dirname(self.filename);
        const basename = std.fs.path.basename(self.filename);
        const extension = std.fs.path.extension(basename);
        const bfnt_name = try std.mem.concat(self.arena.allocator(), u8, &[_][]const u8{
            self.filename[0..self.filename.len-extension.len], ".bfnt"
        });

        // Now the pages of texture memory
        const page_size = @as(usize, scaleW) * @as(usize, scaleH);
        var page_relative_dir = try std.fs.cwd().openDir(dirname orelse ".", .{});
        defer page_relative_dir.close();
        for (pages) |page, i| if (page.actual_index != page_unused) {
            var page_file = page_relative_dir.openFile(page.filename, .{})
                catch |e| return self.err("Failed to open page image '{s}': {}", .{page.filename, e});
            defer page_file.close();

            var image = zimg.Image.fromFile(self.arena.allocator(), &page_file)
                catch |e| return self.err("Failed to load page image '{s}': {}", .{page.filename, e});
            defer image.deinit();

            if (image.width != scaleW or image.height != scaleH)
                return self.err("On page {}, expected image '{s}' to be {}x{}, but actual image is {}x{}.",
                    .{i, page.filename, scaleW, scaleH, image.width, image.height});

            const page_data = (write_ptr + page_size * page.actual_index)[0..page_size];
            // The iterator() function is buggy, we need to do it manually.
            // That function makes a stack copy of the pixels and then returns
            // that address.  WTF.
            var it = zimg.color.PixelStorageIterator.init(&image.pixels);
            for (page_data) |*pxl| {
                // TODO PERF: This loop is not great.  If the compiler decides to unswitch
                // it that's a start, but we also do a needless int -> float -> int roundtrip
                // in most cases.  Ideally this sort of loop should be provided by the zimg
                // storage implementation to avoid the need to unswitch.
                const color = it.next().?;
                pxl.* = zimg.color.toIntColor(u8, color.a);
            }
            std.debug.assert(it.next() == null);
        };        
        
        std.fs.cwd().writeFile(bfnt_name, file_layout_bytes)
            catch |e| return self.err("Failed to write bfnt file at '{s}': {}", .{bfnt_name, e});
    }

    fn markPage(self: *FontBake, pages: []Page, page_id: i16) !u16 {
        for (pages) |*page| {
            if (page.id == page_id) {
                if (page.actual_index == page_unused) {
                    page.actual_index = self.used_pages;
                    self.used_pages += 1;
                }
                return page.actual_index;
            }
        }
        return self.err("Character references page id {}, but no page with that id was declared.", .{page_id});
    }

    fn requireNextLine(self: *FontBake, tag: []const u8) !void {
        const line = self.lines.next() orelse {
            self.linenum = 0; // don't output a relevant line
            return self.err("Unexpected end of file, expected line starting with '{s}'", .{tag});
        };
        self.linenum += 1;
        self.line = std.mem.trimRight(u8, line, " \r");
        self.line_pos = 0;
        try self.requireToken(tag, ' ');
    }

    fn skipDelimiters(self: *FontBake, delim: u8) void {
        // skip over any repeated delimeters
        while (self.line_pos < self.line.len and self.line[self.line_pos] == delim) self.line_pos += 1;
    }

    fn requireToken(self: *FontBake, required: []const u8, delim: u8) !void {
        const end_index = std.mem.indexOfScalar(u8, self.line[self.line_pos..], delim) orelse self.line.len - self.line_pos;
        const actual = self.line[self.line_pos..][0..end_index];
        if (!std.mem.eql(u8, actual, required)) {
            return self.err("Expected '{s}', found '{s}'", .{required, actual});
        }
        self.line_pos += end_index;
        self.skipDelimiters(delim);
    }

    fn requireKVIgnore(self: *FontBake, key: []const u8) !void {
        try self.requireToken(key, '=');
        _ = try self.readRawValue();
    }

    fn requireKVString(self: *FontBake, key: []const u8) ![]const u8 {
        try self.requireToken(key, '=');
        return try self.readValue();
    }

    fn requireKVInt(self: *FontBake, comptime IntType: type, key: []const u8) !IntType {
        try self.requireToken(key, '=');
        const value_pos = self.line_pos;
        const string = try self.readValue();
        return std.fmt.parseInt(IntType, string, 10) catch |e| {
            self.line_pos = value_pos;
            return self.err("Expected an int of type {s}, but found '{s}'. error: {}", .{@typeName(IntType), string, e});
        };
    }

    fn requireKVIntArray(self: *FontBake, comptime num: usize, comptime IntType: type, key: []const u8) ![num]IntType {
        try self.requireToken(key, '=');
        const value_pos = self.line_pos;
        const string = try self.readValue();
        var result: [num]IntType = undefined;
        var it = std.mem.tokenize(u8, string, ", ");
        for (result) |*item, i| {
            const number_str = it.next() orelse {
                self.line_pos = value_pos;
                return self.err("Expected {} numbers in value, but only found {}", .{num, i});
            };
            item.* = std.fmt.parseInt(IntType, number_str, 10) catch |e| {
                self.line_pos = value_pos;
                return self.err("Expected an int of type {s}, but found '{s}'. error: {}", .{@typeName(IntType), string, e});
            };
        }
        if (it.next()) |_| {
            self.line_pos = value_pos;
            return self.err("Expected {} numbers in value, but more are present.", .{num});
        }
        return result;
    }

    fn requireEOL(self: *FontBake) !void {
        self.skipDelimiters(' ');
        if (self.line_pos != self.line.len) {
            return self.err("Expected end of line", .{});
        }
        self.line_pos = 0;
    }

    fn requireEOF(self: *FontBake) !void {
        while (self.lines.next()) |line| {
            self.line = line;
            self.line_pos = 0;
            self.linenum += 1;
            try self.requireEOL();
        }
        self.line = "";
        self.line_pos = 0;
        self.linenum = 0;
    }

    fn readRawValue(self: *FontBake) ![]const u8 {
        var end_index: usize = 0;
        const rest = self.line[self.line_pos..];
        if (rest.len == 0) return self.err("Line ends with no value", .{});

        if (rest[0] == '"') {
            end_index += 1;
            while (end_index < rest.len) {
                if (rest[end_index] == '"') {
                    end_index += 1;
                    break;
                }
                if (rest[end_index] == '\\' and end_index + 1 < rest.len) {
                    end_index += 2;
                } else {
                    end_index += 1;
                }
            } else return self.err("Missing end quote", .{});
        } else {
            end_index = std.mem.indexOfScalar(u8, rest, ' ') orelse self.line.len - self.line_pos;
        }

        if (end_index == 0) return self.err("Property is missing a value", .{});

        const value = self.line[self.line_pos..][0..end_index];
        self.line_pos += end_index;
        self.skipDelimiters(' ');
        return value;
    }

    fn readValue(self: *FontBake) ![]const u8 {
        const raw = try self.readRawValue();
        if (raw[0] != '"') return raw;
        std.debug.assert(raw.len >= 2);
        var escaped_contents = raw[1..raw.len-1];
        var slash = std.mem.indexOfScalar(u8, escaped_contents, '\\')
            orelse return escaped_contents;
        var contents = std.ArrayList(u8).init(self.arena.allocator());
        defer contents.deinit();
        try contents.ensureUnusedCapacity(escaped_contents.len);
        while (true) {
            try contents.appendSlice(escaped_contents[0..slash]);
            const escaped_char = escaped_contents[slash+1];
            try contents.append(switch(escaped_char) {
                't' => '\t',
                'n' => '\n',
                'r' => '\r',
                '0' => 0,
                else => |chr| chr,
            });
        }
        return contents.toOwnedSlice();
    }

    fn err(self: *FontBake, comptime fmt: []const u8, args: anytype) error{FontBake_ErrorReported} {
        std.debug.print("Error in font {s}", .{self.filename});
        if (self.linenum != 0) {
            std.debug.print(" on line {}", .{self.linenum});
        }
        std.debug.print(fmt ++ "\n", args);
        if (self.linenum != 0) {
            std.debug.print("    {s}\n", .{self.line});
            var chars = self.line_pos + 4;
            while (chars >= 4) : (chars -= 4) {
                std.debug.print("    ", .{});
            }
            while (chars >= 1) : (chars -= 1) {
                std.debug.print(" ", .{});
            }
            std.debug.print("^\n", .{});
        }
        return error.FontBake_ErrorReported;
    }
};

fn ptrAlignCast(comptime T: type, ptr: anytype) T {
    if (@typeInfo(T) != .Pointer) @compileError("ptrAlignCast only supports pointers");
    if (@typeInfo(T).Pointer.size == .Slice) @compileError("ptrAlignCast does not support slices");
    const alignment = @typeInfo(T).Pointer.alignment;
    return @ptrCast(T, @alignCast(alignment, ptr));
}

fn Mut(ptr: type) type {
    const info = @typeInfo(ptr);
    if (info != .Pointer) @compileError("Mut only accepts pointers and slices");
    if (!info.Pointer.is_const) @compileError("Pointer is already mutable");
    var mut_info = info;
    mut_info.Pointer.is_const = false;
    return @Type(mut_info);
}

fn mut(ptr: anytype) Mut(@TypeOf(ptr)) {
    const info = @typeInfo(@TypeOf(ptr));
    if (info.Pointer.size == .Slice) {
        return mut(ptr.ptr)[0..ptr.len];
    } else {
        return @intToPtr(Mut(@TypeOf(ptr)), @ptrToInt(ptr));
    }
}

