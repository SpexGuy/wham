const std = @import("std");

pub const MAGIC = @bitCast(u32, @as(*const [4]u8, "BFNT").*);

pub const BfntHeader = extern struct {
    magic: u32 = MAGIC,
    num_chars: u32,
    num_kerns: u32,
    num_pages: u32,
    padding: [4]i32,
    spacing: [2]i32,
    page_size: [2]u32,
    line_height: i32,
    line_base: i32,
    native_size: u32,
    spread: u32,

    pub fn chars(self: *const BfntHeader) []const BfntChar {
        return @ptrCast([*]const BfntChar, @ptrCast([*]const align(2) u8, self)
            + @sizeOf(BfntHeader))
                [0..self.num_chars];
    }

    pub fn kerns(self: *const BfntHeader) []const BfntKern {
        return @ptrCast([*]const BfntKern, @ptrCast([*]const align(2) u8, self)
            + @sizeOf(BfntHeader)
            + self.num_chars * @sizeOf(BfntChar))
                [0..self.num_kerns];
    }

    pub fn pages(self: *const BfntHeader) BfntPages {
        return .{
            .page_bytes = @as(usize, self.page_size[0]) * @as(usize, self.page_size[1]),
            .base = @ptrCast([*]const u8, self)
                + @sizeOf(BfntHeader)
                + self.num_chars * @sizeOf(BfntChar)
                + self.num_kerns * @sizeOf(BfntKern),
            .num_pages = self.num_pages,
        };
    }

    pub fn calcSize(num_chars: u32, num_kerns: u32, num_pages: u32, page_size: [2]u32) usize {
        return @sizeOf(BfntHeader) +
            @sizeOf(BfntChar) * @as(usize, num_chars) +
            @sizeOf(BfntKern) * @as(usize, num_kerns) +
            @as(usize, page_size[0]) * @as(usize, page_size[1]) * @as(usize, num_pages);
    }
};

pub const BfntPages = struct {
    page_bytes: usize,
    base: [*]const u8,
    num_pages: u32,

    pub fn page(self: BfntPages, index: usize) []const u8 {
        std.debug.assert(index < self.num_pages);
        return self.base[self.page_bytes * index..][0..self.page_bytes];
    }
};

pub const BfntChar = extern struct {
    char: u16,
    x: i16,
    y: i16,
    width: i16,
    height: i16,
    x_offset: i16,
    y_offset: i16,
    x_advance: i16,
    page: u16,
};

pub const BfntKern = extern struct {
    first: u16,
    second: u16,
    amount: i16,
};


