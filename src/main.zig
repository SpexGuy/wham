const std = @import("std");
const mach = @import("mach");
const gpu = mach.gpu;
const levels = @import("levels.zig").levels;
const dims = @import("dimensions.zig");
const StaticMeshes = @import("StaticMeshes.zig");

var allow_debug_commands = false;

const Vec2 = mach.math.Vec2;
const Vec3 = mach.math.Vec3;
const Vec4 = mach.math.Vec4;
const Mat4x4 = mach.math.Mat4x4;

const tau = 2 * std.math.pi;

pub const systems = .{
    .start = .{ .handler = start },
    .init = .{ .handler = init },
    .post_init = .{ .handler = post_init },
    .deinit = .{ .handler = deinit },
    .tick = .{ .handler = update },
};

fn start(core: *mach.Core.Mod, app: *Mod) !void {
    core.schedule(.init);
    app.schedule(.init);
}

pub const name = .app;

pub const App = @This();

pub const Mod = mach.Mod(App);

const ViewUniforms = extern struct {
    view_proj: Mat4x4,
    inv_screen_size: [2]f32,
    flat_look_xz: [2]f32,
};

const ObjectUniforms = extern struct {
    transform_0: Vec4,
    transform_1: Vec4,
    transform_2: Vec4,
    color_a: Vec4,
    color_b: Vec4,
    blend_offset_scale: Vec4,
};

const PostProcessUniforms = extern struct {
    color_rotation_0: Vec4,
    color_rotation_1: Vec4,
    color_rotation_2: Vec4,
    colorblind_mode: u32 align(16),
};

const gpa = std.heap.c_allocator;

meshes: StaticMeshes,

swap_chain_format: gpu.Texture.Format,

view_uniform_buffer: *gpu.Buffer,
view_bindings: *gpu.BindGroup,
held_object_uniform_buffer: *gpu.Buffer,
held_object_bindings: *gpu.BindGroup,
post_process_uniform_buffer: *gpu.Buffer,
post_process_bindings_layout: *gpu.BindGroupLayout,

instanced_pipeline_aabb: *gpu.RenderPipeline,
instanced_pipeline_screenspace: *gpu.RenderPipeline,
object_pipeline: *gpu.RenderPipeline,
post_process_pipeline: *gpu.RenderPipeline,

instance_list: *gpu.Buffer,
yaw_turns: f32 = 0,
pitch_turns: f32 = 0,

last_keys: u8 = 0,
mouse_captured: bool = false,
mouse_pos_valid: bool = false,
last_mouse_x: f32 = 0,
last_mouse_y: f32 = 0,

timer: mach.Timer,

// 0: none,
// 1: simulate no red cones
// 2: simulate no green cones
// 3: simulate no blue cones
colorblind_mode: u2 = 0,
// 0: rgb,
// 1: gbr,
// 2: brg,
target_color_rotation: u2 = 0,
actual_color_rotation: f32 = 0,

room_instance_offset: u32 = 0,
num_visible_rooms: u32 = 0,
wall_instance_offset: u32 = 0,
num_visible_walls: u32 = 0,
door_instance_offset: u32 = 0,
num_visible_doors: u32 = 0,
cube_instance_offset: u32 = 0,
num_visible_cubes: u32 = 0,
seat_instance_offset: u32 = 0,
num_visible_seats: u32 = 0,
total_instances: u32 = 0,

current_room: u30 = 0,
current_rotation: u2 = 0,

/// Direction in absolute coordinates
facing_dir: u2 = 0,

held_cube: u30 = NO_ROOM,

forward_dir: Vec3 = Vec3.init(1, 0, 0),
look_dir: Vec3 = Vec3.init(1, 0, 0),
right_dir: Vec3 = Vec3.init(0, 1, 0),

player_pos: Vec3 = Vec3.init(0, dims.player_height, 0),

level_select_brightness: f32 = 0.0,
last_level_complete: bool = false,

current_level: usize = 0,
level_rotates_colors: bool = false,
map: std.MultiArrayList(Room) = .{},
game_mode: GameMode = .startup,

pub const AABB = struct {
    min: [3]f32,
    max: [3]f32,

    pub const empty = AABB{
        .min = .{ std.math.inf_f32, std.math.inf_f32, std.math.inf_f32 },
        .max = .{ -std.math.inf_f32, -std.math.inf_f32, -std.math.inf_f32 },
    };

    pub fn isEmpty(self: AABB) bool {
        return self.min[0] > self.max[0];
    }

    pub fn rotateXZ(self: *AABB, rotation: u2) void {
        if (rotation != 0) {
            const tmp = self.*;
            self.* = switch (rotation) {
                1 => .{
                    .min = .{ tmp.min[2], tmp.min[1], -tmp.max[0] },
                    .max = .{ tmp.max[2], tmp.max[1], -tmp.min[0] },
                },
                2 => .{
                    .min = .{ -tmp.max[0], tmp.min[1], -tmp.max[2] },
                    .max = .{ -tmp.min[0], tmp.max[1], -tmp.min[2] },
                },
                3 => .{
                    .min = .{ -tmp.max[2], tmp.min[1], tmp.min[0] },
                    .max = .{ -tmp.min[2], tmp.max[1], tmp.max[0] },
                },
                else => unreachable,
            };
        }
    }

    pub fn rotatedXZ(self: AABB, rotation: u2) AABB {
        var rot = self;
        rot.rotateXZ(rotation);
        return rot;
    }
};

pub const Plane2 = struct {
    normal: Vec2,

    pub fn normalize(self: *Plane2) void {
        const tmp = self.normal.normalize(1.0);
        self.normal = tmp;
    }

    pub fn projectPoint(plane: Plane2, point: Vec2) f32 {
        const right = Vec2.init(-plane.normal.v[1], plane.normal.v[0]);
        return right.dot(&point);
    }

    pub fn projectAabb(plane: Plane2, aabb: AABB) [2]f32 {
        var min = projectPoint(plane, Vec2.init(aabb.min[0], aabb.min[2]));
        var max = min;
        {
            const along = projectPoint(plane, Vec2.init(aabb.max[0], aabb.max[2]));
            min = @min(min, along);
            max = @max(max, along);
        }
        {
            const along = projectPoint(plane, Vec2.init(aabb.min[0], aabb.max[2]));
            min = @min(min, along);
            max = @max(max, along);
        }
        {
            const along = projectPoint(plane, Vec2.init(aabb.max[0], aabb.min[2]));
            min = @min(min, along);
            max = @max(max, along);
        }
        return .{ min, max };
    }

    pub fn projectOffsetAabb(plane: Plane2, aabb: AABB, offset: [2]f32) [2]f32 {
        const aligned_offset = projectPoint(plane, Vec2.init(offset[0], offset[1]));
        const range = projectAabb(plane, aabb);
        return .{ range[0] + aligned_offset, range[1] + aligned_offset };
    }
};

pub fn calcOffsetScale(range: [2]f32) Vec4 {
    // let diff = range[1] - range[0]
    // (x - range[0]) / diff = [0..1]
    // x / diff - range[0] / diff = [0..1]
    // x * 1/diff + (range[0] * 1/diff) = [0..1]
    // bake values for a single madd on gpu
    const diff = range[1] - range[0];
    const scale = 1.0 / diff;
    const offset = -range[0] * scale;
    return Vec4.init(offset, scale, 0, 0);
}

pub fn makeOffsetScale(plane: Plane2, aabb: AABB, rotation: u2, translation: [2]f32) Vec4 {
    const range = plane.projectOffsetAabb(aabb.rotatedXZ(rotation), translation);
    return calcOffsetScale(range);
}

fn calculateBoxes(plane: Plane2, aabb: AABB, instances: []InstanceAttrs) void {
    for (instances) |*inst| {
        inst.offset_scale = makeOffsetScale(plane, aabb, @intCast(inst.rotation), inst.translation);
    }
}

const FrameInputs = struct {
    mouse_dx: f32 = 0,
    mouse_dy: f32 = 0,

    grab_block: bool = false,
    color_rotation: bool = false,
    colorblind_change: i32 = 0,

    keys: u8 = 0,
};

const GameMode = enum {
    startup,
    normal,
    level_select,
};

const Dir = struct {
    const up: u8 = 0b0001;
    const down: u8 = 0b0010;
    const left: u8 = 0b0100;
    const right: u8 = 0b1000;
    const shift: u8 = 0b10000;
};

const MAX_ROOMS = 120;
const MAX_DOORS = MAX_ROOMS + 20;
const MAX_WALLS = 20;
const MAX_CUBES = MAX_ROOMS;
const MAX_SEATS = MAX_CUBES;
const MAX_INSTANCES = MAX_ROOMS + MAX_WALLS + MAX_DOORS + MAX_CUBES + MAX_SEATS;

const MSAA_COUNT = 4;

const InstanceAttrs = extern struct {
    translation: [2]f32,
    rotation: u32,
    color_a: u32,
    color_b: u32,
    offset_scale: Vec4 = undefined,
};

pub const NO_ROOM = ~@as(u30, 0);

pub const Edge = packed struct(u32) {
    to_room: u30,
    in_dir: u2,
};

pub const Room = struct {
    color: [2]u32,
    edges: [4]Edge,
    cube: u30,
    type: RoomType = .normal,
};

pub const RoomType = enum {
    normal,
    loading,
    level_select,
};

pub fn init(appm: *Mod, corem: *mach.Core.Mod) !void {
    corem.schedule(.init);
    appm.schedule(.post_init);
}

pub fn post_init(appm: *Mod, corem: *mach.Core.Mod) !void {
    const core = corem.state();

    const swap_chain_format = corem.get(core.main_window, .framebuffer_format).?;

    const instance_list = core.device.createBuffer(&gpu.Buffer.Descriptor{
        .label = "instance_list",
        .usage = .{ .copy_dst = true, .vertex = true },
        .size = @sizeOf(InstanceAttrs) * MAX_INSTANCES,
    });

    const view_buffer = core.device.createBuffer(&gpu.Buffer.Descriptor{
        .label = "view_buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(ViewUniforms),
    });

    const held_object_buffer = core.device.createBuffer(&gpu.Buffer.Descriptor{
        .label = "held_object_buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(ObjectUniforms),
    });

    const post_process_buffer = core.device.createBuffer(&gpu.Buffer.Descriptor{
        .label = "post_process_buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(PostProcessUniforms),
    });

    const view_bindings_layout = core.device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .entries = &.{
            gpu.BindGroupLayout.Entry.buffer(0, .{ .vertex = true, .fragment = true }, .uniform, false, @sizeOf(ViewUniforms)),
        },
    }));

    const object_bindings_layout = core.device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .entries = &.{
            gpu.BindGroupLayout.Entry.buffer(0, .{ .vertex = true }, .uniform, false, @sizeOf(ObjectUniforms)),
        },
    }));

    const post_process_bindings_layout = core.device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .entries = &.{
            gpu.BindGroupLayout.Entry.buffer(0, .{ .fragment = true }, .uniform, false, @sizeOf(PostProcessUniforms)),
            gpu.BindGroupLayout.Entry.texture(1, .{ .fragment = true }, .float, .dimension_2d, false),
        },
    }));

    const view_bindings = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = view_bindings_layout,
        .entries = &.{
            // binding, buffer, offset, size
            gpu.BindGroup.Entry.buffer(0, view_buffer, 0, @sizeOf(ViewUniforms)),
        },
    }));

    const held_object_bindings = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = object_bindings_layout,
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, held_object_buffer, 0, @sizeOf(ObjectUniforms)),
        },
    }));

    const room_shader_module = core.device.createShaderModuleWGSL("room.wgsl", @embedFile("room.wgsl"));
    const post_process_shader_module = core.device.createShaderModuleWGSL("post_process.wgsl", @embedFile("post_process.wgsl"));

    const instanced_layout = core.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &.{
            view_bindings_layout,
        },
    }));

    const object_layout = core.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &.{
            view_bindings_layout,
            object_bindings_layout,
        },
    }));

    const post_process_layout = core.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &.{
            post_process_bindings_layout,
        },
    }));

    const instanced_pipeline_aabb = core.device.createRenderPipeline(&gpu.RenderPipeline.Descriptor{
        .layout = instanced_layout,
        .vertex = gpu.VertexState.init(.{
            .module = room_shader_module,
            .entry_point = "instanced_vert_main_aabb",
            .buffers = &.{
                gpu.VertexBufferLayout.init(.{
                    // vertex buffer
                    .array_stride = 3 * @sizeOf(f32),
                    .step_mode = .vertex,
                    .attributes = &[_]gpu.VertexAttribute{
                        .{
                            // vertex positions
                            .shader_location = 0,
                            .offset = 0,
                            .format = .float32x3,
                        },
                    },
                }),
                gpu.VertexBufferLayout.init(.{
                    // instance buffer
                    .array_stride = @sizeOf(InstanceAttrs),
                    .step_mode = .instance,
                    .attributes = &[_]gpu.VertexAttribute{
                        .{
                            .shader_location = 1,
                            .offset = @offsetOf(InstanceAttrs, "translation"),
                            .format = .float32x2,
                        },
                        .{
                            .shader_location = 2,
                            .offset = @offsetOf(InstanceAttrs, "rotation"),
                            .format = .uint32,
                        },
                        .{
                            .shader_location = 3,
                            .offset = @offsetOf(InstanceAttrs, "color_a"),
                            .format = .unorm8x4,
                        },
                        .{
                            .shader_location = 4,
                            .offset = @offsetOf(InstanceAttrs, "color_b"),
                            .format = .unorm8x4,
                        },
                        .{
                            .shader_location = 5,
                            .offset = @offsetOf(InstanceAttrs, "offset_scale"),
                            .format = .float32x4,
                        },
                    },
                }),
            },
        }),
        .fragment = &gpu.FragmentState.init(.{
            .module = room_shader_module,
            .entry_point = "frag_main",
            .targets = &[_]gpu.ColorTargetState{.{
                .format = swap_chain_format,
                .blend = &gpu.BlendState{},
                .write_mask = gpu.ColorWriteMaskFlags.all,
            }},
        }),
        .depth_stencil = &.{
            .format = .depth32_float,
            .depth_write_enabled = .true,
            .depth_compare = .less,
        },
        .primitive = .{
            .cull_mode = .back,
            .topology = .triangle_list,
        },
        .multisample = .{
            .count = MSAA_COUNT,
        },
    });

    const instanced_pipeline_screenspace = core.device.createRenderPipeline(&gpu.RenderPipeline.Descriptor{
        .layout = instanced_layout,
        .vertex = gpu.VertexState.init(.{
            .module = room_shader_module,
            .entry_point = "instanced_vert_main_screenspace",
            .buffers = &.{
                gpu.VertexBufferLayout.init(.{
                    // vertex buffer
                    .array_stride = 3 * @sizeOf(f32),
                    .step_mode = .vertex,
                    .attributes = &[_]gpu.VertexAttribute{
                        .{
                            // vertex positions
                            .shader_location = 0,
                            .offset = 0,
                            .format = .float32x3,
                        },
                    },
                }),
                gpu.VertexBufferLayout.init(.{
                    // instance buffer
                    .array_stride = @sizeOf(InstanceAttrs),
                    .step_mode = .instance,
                    .attributes = &[_]gpu.VertexAttribute{
                        .{
                            .shader_location = 1,
                            .offset = @offsetOf(InstanceAttrs, "translation"),
                            .format = .float32x2,
                        },
                        .{
                            .shader_location = 2,
                            .offset = @offsetOf(InstanceAttrs, "rotation"),
                            .format = .uint32,
                        },
                        .{
                            .shader_location = 3,
                            .offset = @offsetOf(InstanceAttrs, "color_a"),
                            .format = .unorm8x4,
                        },
                        .{
                            .shader_location = 4,
                            .offset = @offsetOf(InstanceAttrs, "color_b"),
                            .format = .unorm8x4,
                        },
                        .{
                            .shader_location = 5,
                            .offset = @offsetOf(InstanceAttrs, "offset_scale"),
                            .format = .float32x4,
                        },
                    },
                }),
            },
        }),
        .fragment = &gpu.FragmentState.init(.{
            .module = room_shader_module,
            .entry_point = "frag_main_screenspace",
            .targets = &[_]gpu.ColorTargetState{.{
                .format = swap_chain_format,
                .blend = &gpu.BlendState{},
                .write_mask = gpu.ColorWriteMaskFlags.all,
            }},
        }),
        .depth_stencil = &.{
            .format = .depth32_float,
            .depth_write_enabled = .true,
            .depth_compare = .less,
        },
        .primitive = .{
            .cull_mode = .back,
            .topology = .triangle_list,
        },
        .multisample = .{
            .count = MSAA_COUNT,
        },
    });

    const object_pipeline = core.device.createRenderPipeline(&gpu.RenderPipeline.Descriptor{
        .layout = object_layout,
        .vertex = gpu.VertexState.init(.{
            .module = room_shader_module,
            .entry_point = "object_vert_main",
            .buffers = &.{
                gpu.VertexBufferLayout.init(.{
                    // vertex buffer
                    .array_stride = 3 * @sizeOf(f32),
                    .step_mode = .vertex,
                    .attributes = &[_]gpu.VertexAttribute{
                        .{
                            // vertex positions
                            .shader_location = 0,
                            .offset = 0,
                            .format = .float32x3,
                        },
                    },
                }),
            },
        }),
        .fragment = &gpu.FragmentState.init(.{
            .module = room_shader_module,
            .entry_point = "frag_main",
            .targets = &[_]gpu.ColorTargetState{.{
                .format = swap_chain_format,
                .blend = &gpu.BlendState{},
                .write_mask = gpu.ColorWriteMaskFlags.all,
            }},
        }),
        .depth_stencil = &.{
            .format = .depth32_float,
            .depth_write_enabled = .false,
            .depth_compare = .always,
        },
        .primitive = .{
            .cull_mode = .back,
            .topology = .triangle_list,
        },
        .multisample = .{
            .count = MSAA_COUNT,
        },
    });

    const post_process_pipeline = core.device.createRenderPipeline(&gpu.RenderPipeline.Descriptor{
        .layout = post_process_layout,
        .vertex = gpu.VertexState.init(.{
            .module = post_process_shader_module,
            .entry_point = "vert_main",
        }),
        .fragment = &gpu.FragmentState.init(.{
            .module = post_process_shader_module,
            .entry_point = "frag_main",
            .targets = &[_]gpu.ColorTargetState{.{
                .format = swap_chain_format,
                .blend = &gpu.BlendState{},
                .write_mask = gpu.ColorWriteMaskFlags.all,
            }},
        }),
        .primitive = .{
            .cull_mode = .none,
            .topology = .triangle_list,
        },
    });

    appm.init(.{
        .instanced_pipeline_aabb = instanced_pipeline_aabb,
        .instanced_pipeline_screenspace = instanced_pipeline_screenspace,
        .object_pipeline = object_pipeline,
        .post_process_pipeline = post_process_pipeline,

        .view_bindings = view_bindings,
        .view_uniform_buffer = view_buffer,
        .held_object_bindings = held_object_bindings,
        .held_object_uniform_buffer = held_object_buffer,
        .post_process_bindings_layout = post_process_bindings_layout,
        .post_process_uniform_buffer = post_process_buffer,

        .swap_chain_format = swap_chain_format,

        .instance_list = instance_list,

        .timer = mach.Timer.start() catch @panic("Failed to start frame timer"),

        .meshes = undefined,
    });

    appm.state().meshes.init(core.device, core.device.getQueue());

    appm.state().loadLevel(0);

    corem.schedule(.start);
}

pub fn deinit() void {}

fn loadLevelSelect(app: *App) void {
    app.level_select_brightness = 0.0;
    app.level_rotates_colors = false;
    app.target_color_rotation = 0;
    app.map.shrinkRetainingCapacity(0);
    var total_len = levels.len; // select rooms
    for (levels) |l| total_len += l.len; // level rooms
    app.map.ensureTotalCapacity(gpa, total_len + 1) catch @panic("Out of memory!");
    app.map.resize(gpa, total_len) catch unreachable;

    std.debug.assert(levels.len & 1 == 0); // This layout only works with an even number of levels

    // Init the rooms
    var level_start: u30 = @intCast(levels.len);
    for (levels, 0..) |level, i| {
        var left_room: usize = if (i == 0) levels.len - 1 else i - 1;
        var right_room: usize = if (i == levels.len - 1) 0 else i + 1;
        if (i & 1 == 1) {
            const tmp = right_room;
            right_room = left_room;
            left_room = tmp;
        }

        // Level select room
        app.map.set(i, .{
            .color = .{ 0, 0 },
            .edges = .{
                .{ .to_room = level_start, .in_dir = 0 },
                .{ .to_room = @intCast(right_room), .in_dir = 3 },
                .{ .to_room = NO_ROOM, .in_dir = 0 },
                .{ .to_room = @intCast(left_room), .in_dir = 1 },
            },
            .cube = NO_ROOM,
            .type = .level_select,
        });

        // Game rooms
        for (level, 0..) |room, room_id| {
            app.map.set(level_start + room_id, .{
                .color = room.color,
                .edges = .{
                    .{ .to_room = room.edges[0].to_room +| level_start, .in_dir = room.edges[0].in_dir },
                    .{ .to_room = room.edges[1].to_room +| level_start, .in_dir = room.edges[1].in_dir },
                    .{ .to_room = room.edges[2].to_room +| level_start, .in_dir = room.edges[2].in_dir },
                    .{ .to_room = room.edges[3].to_room +| level_start, .in_dir = room.edges[3].in_dir },
                },
                .cube = room.cube +| level_start,
                .type = room.type,
            });
        }

        level_start += @intCast(level.len);
    }
}

fn loadLevel(app: *App, index: usize) void {
    app.current_level = index;
    app.level_rotates_colors = index >= 5;
    app.map.shrinkRetainingCapacity(0);
    app.map.ensureTotalCapacity(gpa, levels[index].len) catch @panic("Out of memory!");
    for (levels[index]) |room| app.map.appendAssumeCapacity(room);
    app.current_room = 0;
    app.held_cube = NO_ROOM;
}

pub fn update(appm: *Mod, corem: *mach.Core.Mod) !void {
    const app = appm.state();
    const core = corem.state();

    const delta_time = app.timer.lap();
    // Poll inputs
    const inputs = app.updateInputState(corem);
    app.updateSimulation(delta_time, inputs);

    const use_post_process = true;

    // Update gpu state
    const queue = core.device.getQueue();
    const size = [_]u32{
        corem.get(core.main_window, .framebuffer_width).?,
        corem.get(core.main_window, .framebuffer_height).?,
    };
    app.updateViewUniforms(queue, size);
    if (app.held_cube != NO_ROOM) {
        app.updateHeldObjectUniforms(queue);
    }
    if (use_post_process) {
        app.updatePostProcessUniforms(queue);
    }

    app.updateInstances(queue);

    // Prepare to render the frame
    // TODO cache the depth buffer
    // Unfortunately, webgpu doesn't have memoryless textures.
    // So we're stuck allocating big MSAA backing memory that will never be used :(
    const color_msaa_texture = core.device.createTexture(&gpu.Texture.Descriptor{
        .size = .{ .width = size[0], .height = size[1] },
        .format = app.swap_chain_format,
        .sample_count = MSAA_COUNT,
        .usage = .{ .render_attachment = true },
    });
    defer color_msaa_texture.release();

    const color_msaa_view = color_msaa_texture.createView(&gpu.TextureView.Descriptor{
        .dimension = .dimension_2d,
        .array_layer_count = 1,
        .mip_level_count = 1,
    });
    defer color_msaa_view.release();

    const depth_texture = core.device.createTexture(&gpu.Texture.Descriptor{
        .size = .{ .width = size[0], .height = size[1] },
        .format = .depth32_float,
        .sample_count = MSAA_COUNT,
        .usage = .{ .render_attachment = true },
    });
    defer depth_texture.release();

    const depth_view = depth_texture.createView(&gpu.TextureView.Descriptor{
        .dimension = .dimension_2d,
        .array_layer_count = 1,
        .mip_level_count = 1,
    });
    defer depth_view.release();

    var color_resolve_buffer: ?*gpu.Texture = null;
    defer if (color_resolve_buffer) |r| r.release();
    var color_resolve_view: ?*gpu.TextureView = null;
    defer if (color_resolve_view) |v| v.release();

    var post_bind_group: ?*gpu.BindGroup = null;
    defer if (post_bind_group) |b| b.release();

    if (use_post_process) {
        color_resolve_buffer = core.device.createTexture(&gpu.Texture.Descriptor{
            .size = .{ .width = size[0], .height = size[1] },
            .format = app.swap_chain_format,
            .usage = .{ .render_attachment = true, .texture_binding = true },
        });

        color_resolve_view = color_resolve_buffer.?.createView(&gpu.TextureView.Descriptor{
            .dimension = .dimension_2d,
            .array_layer_count = 1,
            .mip_level_count = 1,
        });

        post_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
            .label = "post_process_bind_group",
            .layout = app.post_process_bindings_layout,
            .entries = &[_]gpu.BindGroup.Entry{
                gpu.BindGroup.Entry.buffer(0, app.post_process_uniform_buffer, 0, @sizeOf(PostProcessUniforms)),
                gpu.BindGroup.Entry.textureView(1, color_resolve_view.?),
            },
        }));
    }

    const back_buffer_view = mach.core.swap_chain.getCurrentTextureView().?;
    defer back_buffer_view.release();

    const cb = core.device.createCommandEncoder(null);
    defer cb.release();

    // Main pass
    {
        const pass = cb.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
            .color_attachments = &[_]gpu.RenderPassColorAttachment{.{
                .view = color_msaa_view,
                .resolve_target = if (use_post_process) color_resolve_view.? else back_buffer_view,
                .clear_value = gpu.Color{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 1.0 },
                .load_op = .clear,
                .store_op = .store, // discard the msaa target, the resolve still happens
            }},
            .depth_stencil_attachment = &.{
                .view = depth_view,
                .depth_load_op = .clear,
                .depth_store_op = .discard, // no need for depth in post pass (yet)
                .depth_clear_value = 1.0,
            },
        }));
        defer pass.release();

        // Do the rendering
        pass.setPipeline(app.instanced_pipeline_screenspace);
        pass.setBindGroup(0, app.view_bindings, &.{});
        app.meshes.bind(pass, 0);
        pass.setVertexBuffer(1, app.instance_list, 0, app.total_instances * @sizeOf(InstanceAttrs));
        app.meshes.room.draw(pass, app.num_visible_rooms, app.room_instance_offset);
        app.meshes.wall.draw(pass, app.num_visible_walls, app.wall_instance_offset);
        pass.setPipeline(app.instanced_pipeline_aabb);
        app.meshes.door.draw(pass, app.num_visible_doors, app.door_instance_offset);
        app.meshes.cube.draw(pass, app.num_visible_cubes, app.cube_instance_offset);
        app.meshes.seat.draw(pass, app.num_visible_seats, app.seat_instance_offset);

        if (app.held_cube != NO_ROOM) {
            pass.setPipeline(app.object_pipeline);
            pass.setBindGroup(1, app.held_object_bindings, &.{});
            app.meshes.cube.draw(pass, 1, 0);
        }

        // Finish up
        pass.end();
    }

    if (use_post_process) {
        const pass = cb.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
            .color_attachments = &[_]gpu.RenderPassColorAttachment{.{
                .view = back_buffer_view,
                .clear_value = gpu.Color{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 },
                .load_op = .clear, // apparently .undef is different from dont_care?  This is unfortunate, may need to use compute + UAV instead.
                .store_op = .store,
            }},
        }));
        defer pass.release();

        pass.setPipeline(app.post_process_pipeline);
        pass.setBindGroup(0, post_bind_group.?, &.{});
        pass.draw(3, 1, 0, 0); // vertex_count, instance_count, first_vertex, first_instance

        pass.end();
    }

    var command = cb.finish(null);
    defer command.release();

    core.device.getQueue().submit(&.{command});
    mach.core.swap_chain.present();
}

fn updateInputState(app: *App, corem: *mach.Core.Mod) FrameInputs {
    var inputs: FrameInputs = .{};
    var iter = mach.core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .close => corem.schedule(.exit),
            .key_press => |ev| switch (ev.key) {
                .q,
                .escape,
                => {
                    if (app.mouse_captured) {
                        {
                            //core.setCursorMode(.normal) catch break :blk;
                            app.mouse_captured = false;
                            app.mouse_pos_valid = false;
                        }
                    } else {
                        corem.schedule(.exit);
                    }
                },
                .w, .up => {
                    app.last_keys |= Dir.up;
                },
                .s, .down => {
                    app.last_keys |= Dir.down;
                },
                .a, .left => {
                    app.last_keys |= Dir.left;
                },
                .d, .right => {
                    app.last_keys |= Dir.right;
                },
                .left_shift => {
                    app.last_keys |= Dir.shift;
                },
                .e, .space => {
                    inputs.grab_block = true;
                },
                .o => if (allow_debug_commands) {
                    inputs.colorblind_change = -1;
                },
                .p => if (allow_debug_commands) {
                    inputs.colorblind_change = 1;
                },
                .f => if (allow_debug_commands) {
                    inputs.color_rotation = true;
                },
                .l => if (allow_debug_commands) {
                    app.last_level_complete = true;
                },
                .k => if (allow_debug_commands) {
                    app.last_level_complete = false;
                },
                .m => if (app.last_keys & Dir.shift != 0) {
                    allow_debug_commands = !allow_debug_commands;
                },
                else => {},
            },
            .key_release => |ev| switch (ev.key) {
                .w, .up => {
                    app.last_keys &= ~Dir.up;
                },
                .s, .down => {
                    app.last_keys &= ~Dir.down;
                },
                .a, .left => {
                    app.last_keys &= ~Dir.left;
                },
                .d, .right => {
                    app.last_keys &= ~Dir.right;
                },
                .left_shift => {
                    app.last_keys &= ~Dir.shift;
                },
                else => {},
            },
            .mouse_motion => |mm| {
                if (app.mouse_pos_valid and app.mouse_captured) {
                    const dx = mm.pos.x - app.last_mouse_x;
                    const dy = mm.pos.y - app.last_mouse_y;
                    if (dx <= 100 and dy <= 100) {
                        inputs.mouse_dx += @floatCast(dx);
                        inputs.mouse_dy += @floatCast(dy);
                    }
                }

                app.last_mouse_x = @floatCast(mm.pos.x);
                app.last_mouse_y = @floatCast(mm.pos.y);
                app.mouse_pos_valid = true;
            },
            .focus_lost, .focus_gained => {
                app.mouse_pos_valid = false;
            },
            .mouse_press => {
                if (!app.mouse_captured) {
                    {
                        //core.setCursorMode(.disabled) catch break :blk;
                        app.mouse_captured = true;
                        app.mouse_pos_valid = false;
                    }
                }
            },
            else => {},
        }
    }
    inputs.keys = app.last_keys;
    return inputs;
}

fn updateSimulation(app: *App, raw_delta_time: f32, inputs: FrameInputs) void {
    var should_check_solved = false;
    var moving_backwards = false;

    const theta = app.yaw_turns * tau;
    const phi = app.pitch_turns * tau;
    app.forward_dir = Vec3.init(@cos(theta), 0, @sin(theta));
    app.right_dir = Vec3.init(-@sin(theta), 0, @cos(theta));
    app.look_dir = Vec3.init(@cos(theta) * @cos(phi), @sin(phi), @sin(theta) * @cos(phi));

    // Prevent giant timesteps from causing problems
    const delta_time = @min(raw_delta_time, 0.2);

    if (app.game_mode != .startup) {
        app.yaw_turns += inputs.mouse_dx / 2000;
        app.pitch_turns -= inputs.mouse_dy / 2000;

        app.yaw_turns = @mod(app.yaw_turns, 1.0);
        app.pitch_turns = std.math.clamp(app.pitch_turns, -0.249, 0.249);

        const move_speed: f32 = if (inputs.keys & Dir.shift != 0) dims.run_speed else dims.walk_speed;
        const move_len = move_speed * delta_time;

        if (inputs.keys & Dir.right != 0) {
            const tmp = app.player_pos.add(&app.right_dir.mulScalar(move_len));
            app.player_pos = tmp;
        } else if (inputs.keys & Dir.left != 0) {
            const tmp = app.player_pos.sub(&app.right_dir.mulScalar(move_len));
            app.player_pos = tmp;
        }

        if (inputs.keys & Dir.up != 0) {
            const tmp = app.player_pos.add(&app.forward_dir.mulScalar(move_len));
            app.player_pos = tmp;
        } else if (inputs.keys & Dir.down != 0) {
            const tmp = app.player_pos.sub(&app.forward_dir.mulScalar(move_len));
            app.player_pos = tmp;
            moving_backwards = true;
        }
    } else {
        const tmp = app.player_pos.add(&app.forward_dir.mulScalar(delta_time * dims.startup_glide_speed));
        app.player_pos = tmp;
    }

    if (app.last_level_complete) {
        app.level_select_brightness += delta_time * 0.7;
        if (app.level_select_brightness > 1.0) app.level_select_brightness = 1.0;
        const brightness_byte: u32 = @as(u8, @intFromFloat(app.level_select_brightness * 255.0));
        const brightness_color: u32 = 0xFF000000 | brightness_byte | (brightness_byte << 8) | (brightness_byte << 16);
        var i: usize = 0;
        while (i < app.map.len) : (i += 1) {
            if (app.map.items(.type)[i] == .level_select) {
                app.map.items(.color)[i] = .{ brightness_color, brightness_color };
            } else {
                break; // level select is always at the beginning
            }
        }
    }

    const edges = &app.map.items(.edges)[app.current_room];

    // Check if the player is close to a wall.
    if (app.player_pos.v[0] > dims.room_width - dims.collision_tolerance) {
        // Check if they are in the door area
        if (abs(app.player_pos.v[2]) < dims.door_width - dims.collision_tolerance and
            edges[app.current_rotation +% 0].to_room != NO_ROOM and
            !moving_backwards)
        {
            // In the door, check for transfer to next room
            if (app.player_pos.v[0] > dims.room_width + dims.collision_tolerance) {
                app.player_pos.v[0] -= 2 * dims.room_width;
                app.moveCurrentRoom(0);
            }
        } else {
            // Too close to the wall but not in the door, clamp onto the wall
            app.player_pos.v[0] = dims.room_width - dims.collision_tolerance;
        }
    }
    if (app.player_pos.v[2] < -dims.room_width + dims.collision_tolerance) {
        // Check if they are in the door area
        if (abs(app.player_pos.v[0]) < dims.door_width - dims.collision_tolerance and
            edges[app.current_rotation +% 1].to_room != NO_ROOM and
            !moving_backwards)
        {
            // In the door, check for transfer to next room
            if (app.player_pos.v[2] < -dims.room_width - dims.collision_tolerance) {
                app.player_pos.v[2] += 2 * dims.room_width;
                app.moveCurrentRoom(1);
            }
        } else {
            // Too close to the wall but not in the door, clamp onto the wall
            app.player_pos.v[2] = -dims.room_width + dims.collision_tolerance;
        }
    }
    if (app.player_pos.v[0] < -dims.room_width + dims.collision_tolerance) {
        // Check if they are in the door area
        if (abs(app.player_pos.v[2]) < dims.door_width - dims.collision_tolerance and
            edges[app.current_rotation +% 2].to_room != NO_ROOM and
            !moving_backwards)
        {
            // In the door, check for transfer to next room
            if (app.player_pos.v[0] < -dims.room_width - dims.collision_tolerance) {
                app.player_pos.v[0] += 2 * dims.room_width;
                app.moveCurrentRoom(2);
            }
        } else {
            // Too close to the wall but not in the door, clamp onto the wall
            app.player_pos.v[0] = -dims.room_width + dims.collision_tolerance;
        }
    }
    if (app.player_pos.v[2] > dims.room_width - dims.collision_tolerance) {
        // Check if they are in the door area
        if (abs(app.player_pos.v[0]) < dims.door_width - dims.collision_tolerance and
            edges[app.current_rotation +% 3].to_room != NO_ROOM and
            !moving_backwards)
        {
            // In the door, check for transfer to next room
            if (app.player_pos.v[2] > dims.room_width + dims.collision_tolerance) {
                app.player_pos.v[2] -= 2 * dims.room_width;
                app.moveCurrentRoom(3);
            }
        } else {
            // Too close to the wall but not in the door, clamp onto the wall
            app.player_pos.v[2] = dims.room_width - dims.collision_tolerance;
        }
    }

    app.facing_dir = if (abs(app.forward_dir.v[0]) > abs(app.forward_dir.v[2]))
        if (app.forward_dir.v[0] > 0) 0 else 2
    else if (app.forward_dir.v[2] > 0) 3 else 1;

    {
        const cksum = (@as(u32, app.current_room) << 6) |
            (@as(u32, app.facing_dir) << 4) |
            (@as(u32, app.current_rotation) << 2) |
            (@as(u32, app.facing_dir +% app.current_rotation) << 0);

        if (cksum != last_cksum) {
            std.debug.print("room {}, facing {}, room rotation {}, facing edge {}\n", .{
                app.current_room,
                app.facing_dir,
                app.current_rotation,
                app.facing_dir +% app.current_rotation,
            });
            last_cksum = cksum;
        }
    }

    if (inputs.colorblind_change != 0) {
        app.colorblind_mode = app.colorblind_mode +% @as(u2, @truncate(@as(u32, @bitCast(inputs.colorblind_change))));
    }

    var rotate_colors = inputs.color_rotation;

    if (inputs.grab_block) {
        // Make sure we are in a normal room
        if (app.map.items(.type)[app.current_room] == .normal) {
            if (app.game_mode == .startup) {
                app.game_mode = .normal;
            }
            if (app.level_rotates_colors) {
                rotate_colors = true;
            }
            // Swap our cube with the one in this room
            const room_cube = &app.map.items(.cube)[app.current_room];
            const tmp = app.held_cube;
            app.held_cube = room_cube.*;
            room_cube.* = tmp;

            if (room_cube.* != NO_ROOM and app.held_cube == NO_ROOM)
                should_check_solved = true;
        }
    }

    if (rotate_colors) {
        app.target_color_rotation += 1;
        if (app.target_color_rotation == 3) app.target_color_rotation = 0;
        std.debug.print("Color rotation: {}\n", .{app.target_color_rotation});
    }

    const target_color_rotation_f32: f32 = @floatFromInt(app.target_color_rotation);
    var distance = target_color_rotation_f32 - app.actual_color_rotation;
    if (distance < 0) distance += 3.0;
    const rotation_speed = 3.0;
    distance = @min(distance, rotation_speed * raw_delta_time);
    app.actual_color_rotation += distance;
    // app.actual_color_rotation += delta_time * 0.3;
    if (app.actual_color_rotation >= 3.0) app.actual_color_rotation -= 3.0;

    if (should_check_solved and app.isGameSolved()) {
        // transition to the "solved" state
        app.held_cube = NO_ROOM;
        const room = app.map.get(app.current_room);
        // load the level select, and point at it
        var next_level_id = app.current_level + 1;
        if (next_level_id >= levels.len) {
            next_level_id = 0;
            app.last_level_complete = true;
        }

        app.loadLevelSelect();
        const transition_room: u30 = @intCast(next_level_id);
        app.map.appendAssumeCapacity(.{
            .color = room.color,
            .edges = .{
                .{ .to_room = transition_room, .in_dir = 0 },
                .{ .to_room = transition_room, .in_dir = 0 },
                .{ .to_room = transition_room, .in_dir = 0 },
                .{ .to_room = transition_room, .in_dir = 0 },
            },
            .cube = NO_ROOM,
            .type = .loading,
        });
        app.current_room = @intCast(app.map.len - 1);
    }
}

fn isGameSolved(app: *App) bool {
    if (app.map.len < 2) return false;

    for (app.map.items(.cube), 0..) |cube, i| {
        if (cube != @as(u30, @intCast(i))) {
            return false;
        }
    }
    return true;
}

var last_cksum: u32 = 0xFFFFFFFF;

fn moveCurrentRoom(app: *App, direction: u2) void {
    const old_room_index = app.current_room;
    const was_level_select = app.map.items(.type)[app.current_room] == .level_select;

    std.debug.print("moveCurrentRoom({})\n", .{direction});
    const edge_index = app.current_rotation +% direction;
    const edge = app.map.items(.edges)[app.current_room][edge_index];
    std.debug.assert(edge.to_room != NO_ROOM);
    app.current_room = edge.to_room;
    const rotation_delta = edge.in_dir -% edge_index;
    app.current_rotation +%= rotation_delta;

    const is_level_select = app.map.items(.type)[app.current_room] == .level_select;
    if (was_level_select and !is_level_select) {
        // A level was selected, load it properly
        app.loadLevel(old_room_index);
    }
}

fn abs(x: anytype) @TypeOf(x) {
    return if (x < 0) -x else x;
}

fn lookAtRh(eye: Vec3, target: Vec3, up: Vec3) Mat4x4 {
    _ = eye;
    _ = target;
    _ = up;
    // TODO
    @panic("lookAtRh unimplemented");
}

fn perspectiveFovRh(fovy: f32, aspect: f32, near: f32, far: f32) Mat4x4 {
    // TODO
    _ = fovy;
    _ = aspect;
    _ = near;
    _ = far;
    @panic("perspectiveFovRh unimplemented");
}

fn updateViewUniforms(app: *App, queue: *gpu.Queue, size: [2]u32) void {
    const eye_pos = app.player_pos;

    const view = lookAtRh(
        eye_pos, // eye
        eye_pos.add(&app.look_dir), // target
        Vec3.init(0.0, 1.0, 0.0), // up
    );

    const aspect_ratio = @as(f32, @floatFromInt(size[0])) / @as(f32, @floatFromInt(size[1]));

    const proj = perspectiveFovRh(
        45.0, // fovy
        aspect_ratio,
        0.01, // near
        40.0, // far
    );

    // Update the view uniforms
    var uniforms: ViewUniforms = .{
        .view_proj = view.mul(&proj),
        .inv_screen_size = .{ 1.0 / @as(f32, @floatFromInt(size[0])), 1.0 / @as(f32, @floatFromInt(size[1])) },
        .flat_look_xz = .{ app.forward_dir.v[0], app.forward_dir.v[2] },
    };
    queue.writeBuffer(app.view_uniform_buffer, 0, std.mem.asBytes(&uniforms));
}

fn updateHeldObjectUniforms(app: *App, queue: *gpu.Queue) void {
    const fwd_dist: f32 = std.math.sqrt2 * 0.05;
    const right_dist: f32 = std.math.sqrt2 * 0.05;
    const held_scale: f32 = 0.7;
    const object_pos = app.player_pos.add(&app.forward_dir.mulScalar(fwd_dist)).add(&app.right_dir.mulScalar(right_dist)).add(&Vec3.init(0, dims.held_height - dims.player_height, 0));
    const plane = Plane2{
        .normal = Vec2.init(app.forward_dir.v[0], app.forward_dir.v[2]),
    };
    const projected_pos = plane.projectPoint(Vec2.init(object_pos.v[0], object_pos.v[2]));
    const scale = Vec4.init(held_scale, held_scale, held_scale, 1.0);
    const aabb = app.meshes.cube.aabb;
    const uniforms = ObjectUniforms{
        .transform_0 = scale.mul(&Vec4.init(app.forward_dir.v[0], 0, app.right_dir.v[0], object_pos.v[0])),
        .transform_1 = scale.mul(&Vec4.init(app.forward_dir.v[1], 1, app.right_dir.v[1], object_pos.v[1])),
        .transform_2 = scale.mul(&Vec4.init(app.forward_dir.v[2], 0, app.right_dir.v[2], object_pos.v[2])),
        .color_a = colorToVec(app.map.items(.color)[app.held_cube][0]),
        .color_b = colorToVec(app.map.items(.color)[app.held_cube][1]),
        .blend_offset_scale = calcOffsetScale(.{
            projected_pos + aabb.min[2] * held_scale,
            projected_pos + aabb.max[2] * held_scale,
        }),
    };
    queue.writeBuffer(app.held_object_uniform_buffer, 0, std.mem.asBytes(&uniforms));
}

fn matFromNormAxisAngle(axis: Vec3, angle: f32) Mat4x4 {
    _ = axis;
    _ = angle;
    @panic("matFromNormAxisAngle unimplemented");
}

fn updatePostProcessUniforms(app: *App, queue: *gpu.Queue) void {
    const axis = Vec3.init(1.0, 1.0, 1.0).normalize(1.0);
    const angle = app.actual_color_rotation * 0.333333 * std.math.tau;
    const mat = matFromNormAxisAngle(axis, angle);
    const uniforms = PostProcessUniforms{
        .color_rotation_0 = mat.v[0],
        .color_rotation_1 = mat.v[1],
        .color_rotation_2 = mat.v[2],
        .colorblind_mode = app.colorblind_mode,
    };
    queue.writeBuffer(app.post_process_uniform_buffer, 0, std.mem.asBytes(&uniforms));
}

fn colorToVec(color: u32) Vec4 {
    const ucolor = Vec4.init(
        @floatFromInt(@as(u8, @truncate(color >> 0))),
        @floatFromInt(@as(u8, @truncate(color >> 8))),
        @floatFromInt(@as(u8, @truncate(color >> 16))),
        @floatFromInt(@as(u8, @truncate(color >> 24))),
    );
    return ucolor.mulScalar(1.0 / 255.0);
}

fn vecToColor(vec: Vec4) u32 {
    const scaled = vec.mulScalar(255.0);
    const r: u32 = @intCast(std.math.clamp(@as(i32, @intFromFloat(scaled.v[0])), 0, 255));
    const g: u32 = @intCast(std.math.clamp(@as(i32, @intFromFloat(scaled.v[1])), 0, 255));
    const b: u32 = @intCast(std.math.clamp(@as(i32, @intFromFloat(scaled.v[2])), 0, 255));
    const a: u32 = @intCast(std.math.clamp(@as(i32, @intFromFloat(scaled.v[3])), 0, 255));
    return (r << 0) | (g << 8) | (b << 16) | (a << 24);
}

fn darkenColor(color: u32) u32 {
    return vecToColor(colorToVec(color).mulScalar(0.9));
}

fn updateInstances(app: *App, queue: *gpu.Queue) void {
    var b = InstanceBuilder{
        .slice = app.map.slice(),
    };

    b.addRoom(app.current_room, .{ 0, 0 });

    const forward = app.facing_dir;
    const left = app.facing_dir +% 1;
    const right = app.facing_dir -% 1;
    const behind = app.facing_dir +% 2;

    // Draw in front of us and to the sides
    b.addSpineInstances(app, forward, 10);
    b.addSpineInstances(app, left, 10);
    b.addSpineInstances(app, right, 10);
    b.addSpineInstances(app, behind, 1);

    // Diagonals are trickier because there are two of them that overlap in each direction.
    // Worse, the overlaps can disagree on room color or rotation.  Luckily for us though,
    // the narrow doors make it impossible to observe two conflicting rooms at the same time.
    // However, it is possible to observe a diagonal through one door, then move and see
    // a different one through the other door.  So we need to pick the right diagonal based
    // on what you can see.  We can do that by checking where the user is relative to the
    // diagonals of the room.
    // Note that we need the normals, so the one for the left side actually points right.
    var left_diagonal_normal = facing_deltas[forward];
    left_diagonal_normal[0] += facing_deltas[right][0];
    left_diagonal_normal[1] += facing_deltas[right][1];
    var right_diagonal_normal = facing_deltas[forward];
    right_diagonal_normal[0] += facing_deltas[left][0];
    right_diagonal_normal[1] += facing_deltas[left][1];

    // Note that player_pos is an xyz vector but the normals are xz, so the z index doesn't match.
    const left_dot = app.player_pos.v[0] * left_diagonal_normal[0] + app.player_pos.v[2] * left_diagonal_normal[1];
    const right_dot = app.player_pos.v[0] * right_diagonal_normal[0] + app.player_pos.v[2] * right_diagonal_normal[1];

    if (left_dot > 0) {
        b.addDiagonalInstances(app, forward, left);
    } else {
        b.addDiagonalInstances(app, left, forward);
    }

    if (right_dot > 0) {
        b.addDiagonalInstances(app, forward, right);
    } else {
        b.addDiagonalInstances(app, right, forward);
    }

    // Calculate derived instance properties
    // TODO-OPT: This could be done in a compute shader
    // TODO-OPT: This would be an easy place to do culling, since we have AABBs available.
    const facing_plane = Plane2{
        .normal = Vec2.init(app.forward_dir.v[0], app.forward_dir.v[2]),
    };
    calculateBoxes(facing_plane, app.meshes.room.aabb, b.rooms.slice());
    calculateBoxes(facing_plane, app.meshes.wall.aabb, b.walls.slice());
    calculateBoxes(facing_plane, app.meshes.door.aabb, b.doors.slice());
    calculateBoxes(facing_plane, app.meshes.cube.aabb, b.cubes.slice());
    calculateBoxes(facing_plane, app.meshes.seat.aabb, b.seats.slice());

    // Upload streamed instance data to the gpu
    var total_instances: u32 = 0;
    app.room_instance_offset = total_instances;
    app.num_visible_rooms = @intCast(b.rooms.len);
    queue.writeBuffer(app.instance_list, total_instances * @sizeOf(InstanceAttrs), b.rooms.slice());
    total_instances += @intCast(b.rooms.len);

    app.wall_instance_offset = total_instances;
    app.num_visible_walls = @intCast(b.walls.len);
    queue.writeBuffer(app.instance_list, total_instances * @sizeOf(InstanceAttrs), b.walls.slice());
    total_instances += @intCast(b.walls.len);

    app.door_instance_offset = total_instances;
    app.num_visible_doors = @intCast(b.doors.len);
    queue.writeBuffer(app.instance_list, total_instances * @sizeOf(InstanceAttrs), b.doors.slice());
    total_instances += @intCast(b.doors.len);

    app.cube_instance_offset = total_instances;
    app.num_visible_cubes = @intCast(b.cubes.len);
    queue.writeBuffer(app.instance_list, total_instances * @sizeOf(InstanceAttrs), b.cubes.slice());
    total_instances += @intCast(b.cubes.len);

    app.seat_instance_offset = total_instances;
    app.num_visible_seats = @intCast(b.seats.len);
    queue.writeBuffer(app.instance_list, total_instances * @sizeOf(InstanceAttrs), b.seats.slice());
    total_instances += @intCast(b.seats.len);

    app.total_instances = total_instances;
}

const facing_deltas = [4][2]f32{
    .{ 1, 0 },
    .{ 0, -1 },
    .{ -1, 0 },
    .{ 0, 1 },
};

const InstanceBuilder = struct {
    slice: std.MultiArrayList(Room).Slice,

    rooms: std.BoundedArray(InstanceAttrs, MAX_ROOMS) = .{},
    doors: std.BoundedArray(InstanceAttrs, MAX_DOORS) = .{},
    walls: std.BoundedArray(InstanceAttrs, MAX_WALLS) = .{},
    cubes: std.BoundedArray(InstanceAttrs, MAX_CUBES) = .{},
    seats: std.BoundedArray(InstanceAttrs, MAX_SEATS) = .{},

    fn addSpineInstances(b: *InstanceBuilder, app: *App, facing_dir: u2, limit: u32) void {
        const edges = b.slice.items(.edges);
        const delta = facing_deltas[facing_dir];
        var position: [2]f32 = .{ 0, 0 };
        var room = app.current_room;
        var rotation = app.current_rotation +% facing_dir;
        var i: u32 = 0;
        while (i < limit) : (i += 1) {
            if (!b.addPassage(room, position, rotation, facing_dir, false)) break;
            position[0] += delta[0];
            position[1] += delta[1];
            const edge = edges[room][rotation];
            const rotation_delta = edge.in_dir -% rotation;
            rotation +%= rotation_delta;
            room = edge.to_room;
            b.addRoom(room, position);
        } else {
            _ = b.addPassage(room, position, rotation, facing_dir, true);
        }
    }

    fn addDiagonalInstances(b: *InstanceBuilder, app: *App, primary_dir: u2, secondary_dir: u2) void {
        const edges = b.slice.items(.edges);
        const primary_delta = facing_deltas[primary_dir];
        const secondary_delta = facing_deltas[secondary_dir];

        var position: [2]f32 = .{ 0, 0 };
        var room = app.current_room;
        var rotation = app.current_rotation +% primary_dir;

        var i: u32 = 0;
        while (i < 4) : (i += 1) {
            {
                if (!b.addPassage(room, position, rotation, primary_dir, false)) break;
                position[0] += primary_delta[0];
                position[1] += primary_delta[1];
                const edge = edges[room][rotation];
                const rotation_delta = edge.in_dir -% rotation;
                rotation +%= rotation_delta;
                // also turn towards secondary dir
                rotation +%= secondary_dir -% primary_dir;
                room = edge.to_room;

                // The first primary iteration is on a spine, which
                // is drawn separately.  Skip it here.
                if (i != 0) {
                    b.addRoom(room, position);
                }
            }

            {
                if (!b.addPassage(room, position, rotation, secondary_dir, false)) break;
                position[0] += secondary_delta[0];
                position[1] += secondary_delta[1];
                const edge = edges[room][rotation];
                const rotation_delta = edge.in_dir -% rotation;

                rotation +%= rotation_delta;
                // turn back towards primary dir
                rotation +%= primary_dir -% secondary_dir;
                room = edge.to_room;

                b.addRoom(room, position);
            }
        } else {
            _ = b.addPassage(room, position, rotation, primary_dir, true);
        }
    }

    fn addRoom(b: *InstanceBuilder, index: u30, position: [2]f32) void {
        const room_color = b.slice.items(.color)[index];
        b.rooms.appendAssumeCapacity(.{
            .translation = position,
            .rotation = 0,
            .color_a = room_color[0],
            .color_b = room_color[1],
        });
        const cube = b.slice.items(.cube)[index];
        if (cube != NO_ROOM) {
            b.cubes.appendAssumeCapacity(.{
                .translation = position,
                .rotation = 0,
                .color_a = darkenColor(b.slice.items(.color)[cube][0]),
                .color_b = darkenColor(b.slice.items(.color)[cube][1]),
            });
        }
        if (b.slice.items(.type)[index] == .normal) {
            const seat_color = if (cube == index) [2]u32{ 0xFFEFEFEF, 0xFFEFEFEF } else [2]u32{ 0, 0 };
            b.seats.appendAssumeCapacity(.{
                .translation = position,
                .rotation = 0,
                .color_a = darkenColor(seat_color[0]),
                .color_b = darkenColor(seat_color[1]),
            });
        }
    }

    fn addPassage(b: *InstanceBuilder, index: u30, position: [2]f32, edge: u2, abs_rotation: u2, wallProxy: bool) bool {
        const to_room = b.slice.items(.edges)[index][edge].to_room;
        if (to_room == NO_ROOM) {
            b.walls.appendAssumeCapacity(.{
                .translation = position,
                .rotation = abs_rotation,
                .color_a = b.slice.items(.color)[index][0],
                .color_b = b.slice.items(.color)[index][1],
            });
            return false;
        } else {
            const next_color = b.slice.items(.color)[to_room];
            b.doors.appendAssumeCapacity(.{
                .translation = position,
                .rotation = abs_rotation,
                .color_a = darkenColor(next_color[0]),
                .color_b = darkenColor(next_color[1]),
            });
            if (wallProxy) {
                b.walls.appendAssumeCapacity(.{
                    .translation = position,
                    .rotation = abs_rotation,
                    .color_a = next_color[0],
                    .color_b = next_color[1],
                });
            }
            return true;
        }
    }
};

pub const modules = .{
    mach.Core,
    App,
};

pub fn main() !void {
    // Initialize module system
    try mach.core.initModule();

    while (try mach.core.tick()) {}
}
