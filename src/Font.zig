const std = @import("std");
const bfnt = @import("bfnt");
const mach = @import("mach");
const gpu = @import("gpu");
const Allocator = std.mem.Allocator;

const Font = @This();



const KernKey = extern struct {
    first: u16,
    second: u16,
};

const CharCpuData = struct {
    x_advance: f32,
    gpu_id: u16,
    min_pos_offset: [2]f32,
    max_pos_offset: [2]f32,
};

const FontLayout = struct {
    vertices: u32,
    aspect: f32,
};

pub fn layoutText(self: *Font, buffer: []align(4) u8, start_index: usize) usize {
    var idx = start_index;

}

pub fn calcInstancesNeeded(string: []const u8) usize {
    var it = SafeUtf8Iterator.init(string);
    var length: usize = 0;
    while (true) {
        _ = (it.nextCodepoint() catch |_| 0) orelse break;
        length += 1;
    }
    return length;
}

pub fn writeInstanceData(self: *Font, string: []const u8, data: [*]align(4) u8) void {
    var pos = -self.padding[0];
    var prev_char: u16 = 0;

}

pub fn deinit(self: *Font, allocator: Allocator) void {
    self.extended_chars.deinit(allocator);
    self.kerns.deinit(allocator);
    if (self.pages_view) |v| v.deinit();
    if (self.pages) |p| p.deinit();
}

pub fn loadFromReader(self: *Font, label: []const u8, device: *gpu.Device, queue: *gpu.Queue, allocator: Allocator, reader: anytype) !void {
    var magic = reader.readIntLittle(u32);
    if (magic != bfnt.MAGIC) return error.InvalidFormat;

    var header: bfnt.HeaderData = undefined;
    try reader.readAll(std.mem.asBytes(&header)[@sizeOf(u32)..]); 

    {
        var char_index: usize = 0;
        while (char_index < header.num_chars) : (char_index += 1) {
            var char: bfnt.BfntChar = undefined;
            try reader.readAll(std.mem.asBytes(&char));
            var result: *CharData = if (char.char < 128) &self.ascii_chars[char.char]
                else (try self.extended_chars.getOrPut(allocator, char.char)).value_ptr;
            result.* = CharData.fromBfnt(char);
        }
    }

    {
        try self.kerns.ensureUnusedCapacity(allocator, header.num_kerns);
        var kern_index: usize = 0;
        while (kern_index < header.num_kerns) : (kern_index += 1) {
            var kern: bfnt.BfntKern = undefined;
            try reader.readAll(std.mem.asBytes(&kern));
            try self.kerns.putNoClobber(allocator, .{ .first = kern.first, .second = kern.second }, kern.amount);
        }
    }

    {
        const extent = gpu.Extent3D{
            .width = header.page_size[0],
            .height = header.page_size[1],
            .depth_or_array_layers = header.num_pages,
        };
        self.pages = device.createTexture(&gpu.Texture.Descriptor.init(.{
            .label = label,
            .usage = .{ .texture_binding = true, .copy_dst = true },
            .dimension = .dimension_2d,
            .size = extent,
            .format = .r8_unorm,
        }));

        self.pages_view = self.pages.?.createView(&gpu.TextureView.Descriptor{
            .label = label,
            .format = .r8_unorm,
            .dimension = .dimension_2d,
        });

        const texture_data_size = @as(usize, header.page_size[0]) * @as(usize, header.page_size[1]) * @as(usize, header.num_pages);

        var buffer = device.createBuffer(&gpu.Buffer.Descriptor{
            .label = "font_staging",
            .usage = .{ .copy_src = true, .map_write = true },
            .size = texture_data_size,
            .mapped_at_creation = true,
        });
        defer buffer.release();

        const data = buffer.getMappedRange(u8, 0, texture_data_size).?;
        try reader.readAll(data);
        buffer.unmap();

        const encoder = device.createCommandEncoder(null);
        defer encoder.release();

        encoder.copyBufferToTexture(
            &gpu.ImageCopyBuffer{
                .layout = gpu.Texture.DataLayout{
                    .bytes_per_row = header.page_size[0],
                    .rows_per_image = header.page_size[1],
                },
                .buffer = buffer,
            },
            &gpu.ImageCopyTexture{
                .texture = self.pages.?,
            },
            &extent,
        );

        const cb = encoder.finish(null);
        defer cb.release();

        queue.submit(&.{cb});
    }
}

