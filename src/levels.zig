const main = @import("main.zig");
const Room = main.Room;
const NO_ROOM = main.NO_ROOM;

const blue = 0xFFFF0000;
const red = 0xFF0000FF;
const green = 0xFF00FF00;
const yellow = 0xFF00FFFF;

const magenta = 0xFFFF00FF;
const purple = 0xFFFF007f;
const orange = 0xFF007FFF;
const seafoam = 0xFF7FFF00;

const teal = 0xFFFF7F00;
const mustard = 0xFF00FF7F;
const pink = 0xFF7F00FF;

const cyan = 0xFFFFFF00;
const forest_green = 0xFF228B22;

const level_0 = [_]Room{
    .{
        .color = red,
        .edges = .{
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 2, .in_dir = 2 },
            .{ .to_room = 0, .in_dir = 0 },
        },
        .cube = 1,
    },
    .{
        .color = yellow,
        .edges = .{
            .{ .to_room = 2, .in_dir = 0 },
            .{ .to_room = 1, .in_dir = 1 },
            .{ .to_room = 3, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 0 },
        },
        .cube = 2,
    },
    .{
        .color = green,
        .edges = .{
            .{ .to_room = 3, .in_dir = 0 },
            .{ .to_room = 2, .in_dir = 1 },
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 2, .in_dir = 0 },
        },
        .cube = 3,
    },
    .{
        .color = blue,
        .edges = .{
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 3, .in_dir = 1 },
            .{ .to_room = 1, .in_dir = 2 },
            .{ .to_room = 3, .in_dir = 0 },
        },
        .cube = 0,
    },
};

const level_1 = [_]Room{
    .{
        .color = purple,
        .edges = .{
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 3 },
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 1 },
        },
        .cube = 1,
    },
    .{
        .color = orange,
        .edges = .{
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 2, .in_dir = 2 },
        },
        .cube = 2,
    },
    .{
        .color = seafoam,
        .edges = .{
            .{ .to_room = 3, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 3,
    },
    .{
        .color = magenta,
        .edges = .{
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 4, .in_dir = 2 },
        },
        .cube = 4,
    },
    .{
        .color = blue,
        .edges = .{
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 1, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 0,
    },
};

const level_2 = [_]Room{
    .{
        .color = teal,
        .edges = .{
            .{ .to_room = 1, .in_dir = 2 },
            .{ .to_room = 4, .in_dir = 2 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 1,
    },
    .{
        .color = mustard,
        .edges = .{
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 2, .in_dir = 1 },
            .{ .to_room = 4, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 2,
    },
    .{
        .color = pink,
        .edges = .{
            .{ .to_room = 5, .in_dir = 2 },
            .{ .to_room = 1, .in_dir = 3 },
            .{ .to_room = 0, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 3,
    },
    .{
        .color = red,
        .edges = .{
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 6, .in_dir = 2 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 4,
    },
    .{
        .color = forest_green,
        .edges = .{
            .{ .to_room = 1, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 7, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 5,
    },
    .{
        .color = yellow,
        .edges = .{
            .{ .to_room = 4, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 3, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 6,
    },
    .{
        .color = cyan,
        .edges = .{
            .{ .to_room = 1, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = 4, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 7,
    },
    .{
        .color = orange,
        .edges = .{
            .{ .to_room = 4, .in_dir = 2 },
            .{ .to_room = 3, .in_dir = 3 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
            .{ .to_room = NO_ROOM, .in_dir = 0 },
        },
        .cube = 0,
    },
};

const level_3 = [_]Room{
    .{
        .color = red,
        .edges = .{
            .{ .to_room = 3, .in_dir = 0 },
            .{ .to_room = 3, .in_dir = 0 },
            .{ .to_room = 1, .in_dir = 3 },
            .{ .to_room = 3, .in_dir = 0 },
        },
        .cube = 1,
    },
    .{
        .color = green,
        .edges = .{
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 2, .in_dir = 2 },
            .{ .to_room = 0, .in_dir = 0 },
            .{ .to_room = 3, .in_dir = 0 },
        },
        .cube = 2,
    },
    .{
        .color = blue,
        .edges = .{
            .{ .to_room = 0, .in_dir = 2 },
            .{ .to_room = 0, .in_dir = 1 },
            .{ .to_room = 3, .in_dir = 1 },
            .{ .to_room = 0, .in_dir = 3 },
        },
        .cube = 3,
    },
    .{
        .color = yellow,
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
    &level_3,
    &level_1,
    &level_0,
    &level_2,
};
