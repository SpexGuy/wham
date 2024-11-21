const main = @import("main.zig");
const Room = main.Room;
const NO_ROOM = main.NO_ROOM;

fn double(color: u32) [2]u32 {
    return .{ color, color };
}
fn grad_a(color: u32) [2]u32 {
    if (comptime @import("builtin").cpu.arch.endian() != .little)
        @compileError("The following code assumes little endian");
    const bytes: [4]u8 = @bitCast(color);
    const rot = [4]u8{ bytes[1], bytes[2], bytes[0], bytes[3] };
    return .{ color, @bitCast(rot) };
}
fn grad_b(color: u32) [2]u32 {
    if (comptime @import("builtin").cpu.arch.endian() != .little)
        @compileError("The following code assumes little endian");
    const bytes: [4]u8 = @bitCast(color);
    const rot = [4]u8{ bytes[2], bytes[0], bytes[1], bytes[3] };
    return .{ color, @bitCast(rot) };
}
fn grad_c(color: u32) [2]u32 {
    const a = grad_a(color);
    return .{ a[1], a[0] };
}

const high_contrast = [3][2]u32{
    double(0xFF22bbFF), // yellow
    double(0xFFFF22bb), // purple
    double(0xFFbbFF22), // cyan
};

const bright = [6][2]u32{
    double(0xFFAA7744), // blue
    double(0xFFEECC66), // cyan
    double(0xFF338822), // green
    double(0xFF44BBCC), // yellow
    double(0xFF7766EE), // red
    double(0xFF7733AA), // purple
};

const vibrant = [6][2]u32{
    grad_b(0xFFBB7700), // blue
    grad_c(0xFFEEBB33), // cyan
    grad_a(0xFF889900), // teal
    grad_a(0xFF3377EE), // orange
    grad_b(0xFF1133CC), // red
    grad_a(0xFF7733EE), // magenta
};

const muted = [9][2]u32{
    grad_a(0xFF882233), // indigo
    grad_a(0xFFEECC88), // cyan
    grad_a(0xFF99AA44), // teal
    grad_a(0xFF337711), // green
    grad_a(0xFF339999), // olive
    grad_a(0xFF77CCDD), // sand
    grad_b(0xFF7766CC), // rose
    grad_a(0xFF552288), // wine
    grad_a(0xFF9944AA), // purple
};

const l0_colors = [2][2]u32{
    high_contrast[1],
    high_contrast[2],
};
const level_0 = [_]Room{
    .{
        .color = l0_colors[0],
        .edges = .{
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 1, .in_dir = 1 },
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 3 },
        },
        .cube = 1,
    },
    .{
        .color = l0_colors[1],
        .edges = .{
            .{ .to_room = 1, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 1, .in_dir = 2 },
            .{ .to_room = 0, .in_dir = 3 },
        },
        .cube = 0,
    },
};

const l1_colors = high_contrast;
const level_1 = [_]Room{
    .{
        .color = l1_colors[0],
        .edges = .{
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 0 },
            .{ .to_room = 2, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 2,
    },
    .{
        .color = l1_colors[1],
        .edges = .{
            .{ .to_room = 1, .in_dir = 2 },
            .{ .to_room = 2, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 0,
    },
    .{
        .color = l1_colors[2],
        .edges = .{
            .{ .to_room = 2, .in_dir = 2 },
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 1, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 1,
    },
};

const l2_colors = [4][2]u32{
    bright[0],
    bright[1],
    bright[4],
    bright[3],
};
const level_2 = [_]Room{
    .{
        .color = l2_colors[0],
        .edges = .{
            .{ .to_room = 3, .in_dir = 0 },
            .{ .to_room = 3, .in_dir = 0 },
            .{ .to_room = 1, .in_dir = 3 },
            .{ .to_room = 3, .in_dir = 0 },
        },
        .cube = 1,
    },
    .{
        .color = l2_colors[1],
        .edges = .{
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 2, .in_dir = 2 },
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 3, .in_dir = 0 },
        },
        .cube = 2,
    },
    .{
        .color = l2_colors[2],
        .edges = .{
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 3, .in_dir = 1 },
            .{ .to_room = 0, .in_dir = 3 },
        },
        .cube = 3,
    },
    .{
        .color = l2_colors[3],
        .edges = .{
            .{ .to_room = 1, .in_dir = 3 },
            .{ .to_room = 3, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 3 },
            .{ .to_room = 1, .in_dir = 3 },
        },
        .cube = 0,
    },
};

const l3_colors = vibrant[0..5];
const level_3 = [_]Room{
    .{
        .color = l3_colors[0],
        .edges = .{
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 3 },
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 1 },
        },
        .cube = 1,
    },
    .{
        .color = l3_colors[1],
        .edges = .{
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 2, .in_dir = 2 },
        },
        .cube = 2,
    },
    .{
        .color = l3_colors[2],
        .edges = .{
            .{ .to_room = 3, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 3,
    },
    .{
        .color = l3_colors[3],
        .edges = .{
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 4, .in_dir = 2 },
        },
        .cube = 4,
    },
    .{
        .color = l3_colors[4],
        .edges = .{
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 1, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 0,
    },
};

const l4_colors = bright[0..4];
const level_4 = [_]Room{
    .{
        .color = l4_colors[0],
        .edges = .{
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 2, .in_dir = 2 },
            .{ .to_room = 0, .in_dir = 0 },
        },
        .cube = 1,
    },
    .{
        .color = l4_colors[1],
        .edges = .{
            .{ .to_room = 2, .in_dir = 0 },
            .{ .to_room = 1, .in_dir = 1 },
            .{ .to_room = 3, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 0 },
        },
        .cube = 2,
    },
    .{
        .color = l4_colors[2],
        .edges = .{
            .{ .to_room = 3, .in_dir = 0 },
            .{ .to_room = 2, .in_dir = 1 },
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 2, .in_dir = 0 },
        },
        .cube = 3,
    },
    .{
        .color = l4_colors[3],
        .edges = .{
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 3, .in_dir = 1 },
            .{ .to_room = 1, .in_dir = 2 },
            .{ .to_room = 3, .in_dir = 0 },
        },
        .cube = 0,
    },
};

const l5_colors = muted[0..4] ++ muted[5..9];
const level_5 = [_]Room{
    .{
        .color = l5_colors[0],
        .edges = .{
            .{ .to_room = 1, .in_dir = 2 },
            .{ .to_room = 4, .in_dir = 2 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 1,
    },
    .{
        .color = l5_colors[1],
        .edges = .{
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 2, .in_dir = 1 },
            .{ .to_room = 4, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 2,
    },
    .{
        .color = l5_colors[2],
        .edges = .{
            .{ .to_room = 5, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 3 },
            .{ .to_room = 0, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 3,
    },
    .{
        .color = l5_colors[3],
        .edges = .{
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 6, .in_dir = 2 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 4,
    },
    .{
        .color = l5_colors[4],
        .edges = .{
            .{ .to_room = 1, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 7, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 5,
    },
    .{
        .color = l5_colors[5],
        .edges = .{
            .{ .to_room = 4, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 3, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 6,
    },
    .{
        .color = l5_colors[6],
        .edges = .{
            .{ .to_room = 1, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 4, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 7,
    },
    .{
        .color = l5_colors[7],
        .edges = .{
            .{ .to_room = 4, .in_dir = 2 },
            .{ .to_room = 3, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 0,
    },
};

pub const levels: []const []const Room = &[_][]const Room{
    &level_0,
    &level_1,
    &level_2,
    &level_3,
    &level_4,
    &level_5,
};
