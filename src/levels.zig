const main = @import("main.zig");
const Room = main.Room;
const NO_ROOM = main.NO_ROOM;

const high_contrast = [3]u32{
    0xFF33AADD, // yellow
    0xFF6655BB, // red
    0xFF884400, // blue
};

const bright = [6]u32{
    0xFFAA7744, // blue
    0xFFEECC66, // cyan
    0xFF338822, // green
    0xFF44BBCC, // yellow
    0xFF7766EE, // red
    0xFF7733AA, // purple
};

const vibrant = [6]u32{
    0xFFBB7700, // blue
    0xFFEEBB33, // cyan
    0xFF889900, // teal
    0xFF3377EE, // orange
    0xFF1133CC, // red
    0xFF7733EE, // magenta
};

const muted = [9]u32{
    0xFF882233, // indigo
    0xFFEECC88, // cyan
    0xFF99AA44, // teal
    0xFF337711, // green
    0xFF339999, // olive
    0xFF77CCDD, // sand
    0xFF7766CC, // rose
    0xFF552288, // wine
    0xFF9944AA, // purple
};


const l0_colors = [2]u32{
    high_contrast[1],
    high_contrast[2],
};
const level_0 = [_]Room{
    .{
        .color = l0_colors[0],
        .edges = .{
            .{ .to_room = 1, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 1, .in_dir = 2 },
            .{ .to_room = 0, .in_dir = 3 },
        },
        .cube = 1,
    },
    .{
        .color = l0_colors[1],
        .edges = .{
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 1, .in_dir = 1 },
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 3 },
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

const l2_colors = [4]u32{
    bright[0],
    bright[2],
    bright[4],
    bright[5],
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

pub const levels: []const []const Room = &[_][]const Room {
    &level_0,
    &level_1,
    &level_2,
    &level_3,
    &level_4,
    &level_5,
};
