const gpu = @import("gpu");
const dims = @import("dimensions.zig");
const main = @import("main.zig");
const StaticMeshes = @This();

const AABB = main.AABB;

pub const MeshChunk = struct {
    base_vertex: i32,
    base_index: u32,
    indices_count: u32,
    aabb: main.AABB,

    pub inline fn draw(chunk: MeshChunk, pass: *gpu.RenderPassEncoder, instance_count: u32, first_instance: u32) void {
        pass.drawIndexed(chunk.indices_count, instance_count, chunk.base_index, chunk.base_vertex, first_instance);
    }
};

mesh_buffer: *gpu.Buffer,
mesh_vertex_offset: u32,
mesh_vertex_size: u32,
mesh_indices_offset: u32,
mesh_indices_size: u32,

room: MeshChunk,
wall: MeshChunk,
door: MeshChunk,
cube: MeshChunk,

pub fn init(meshes: *StaticMeshes, device: *gpu.Device, queue: *gpu.Queue) void {
    // zig fmt: off
    const room_verts = [6*4][3]f32{
        .{ -dims.door_width, 0, -dims.room_width },
        .{ -dims.door_width, dims.door_height, -dims.room_width },
        .{  dims.door_width, dims.door_height, -dims.room_width },
        .{  dims.door_width, 0, -dims.room_width },
        .{  dims.room_width, 0, -dims.room_width },
        .{  dims.room_width, dims.room_height, -dims.room_width },

        .{ dims.room_width, 0, -dims.door_width },
        .{ dims.room_width, dims.door_height, -dims.door_width },
        .{ dims.room_width, dims.door_height,  dims.door_width },
        .{ dims.room_width, 0,  dims.door_width },
        .{ dims.room_width, 0,  dims.room_width },
        .{ dims.room_width, dims.room_height, dims.room_width },

        .{  dims.door_width, 0, dims.room_width },
        .{  dims.door_width, dims.door_height, dims.room_width },
        .{ -dims.door_width, dims.door_height, dims.room_width },
        .{ -dims.door_width, 0, dims.room_width },
        .{ -dims.room_width, 0, dims.room_width },
        .{ -dims.room_width, dims.room_height, dims.room_width },

        .{ -dims.room_width, 0, dims.door_width },
        .{ -dims.room_width, dims.door_height, dims.door_width },
        .{ -dims.room_width, dims.door_height, -dims.door_width },
        .{ -dims.room_width, 0, -dims.door_width },
        .{ -dims.room_width, 0, -dims.room_width },
        .{ -dims.room_width, dims.room_height, -dims.room_width },
    };

    const room_aabb = main.AABB{
        .min = .{ -dims.room_width, 0, -dims.room_width },
        .max = .{  dims.room_width, dims.room_height,  dims.room_width },
    };
    const wall_aabb = room_aabb; // walls should blend seamlessly into rooms


    const room_indices = [_]u16{
        0, 1, 22,
        22, 1, 23,
        23, 1, 5,
        5, 1, 2,
        5, 2, 4,
        4, 2, 3,

        6, 7, 4,
        4, 7, 5,
        5, 7, 11,
        11, 7, 8,
        11, 8, 10,
        10, 8, 9,

        12, 13, 10,
        10, 13, 11,
        11, 13, 17,
        17, 13, 14,
        17, 14, 16,
        16, 14, 15,

        18, 19, 16,
        16, 19, 17,
        17, 19, 23,
        23, 19, 20,
        23, 20, 22,
        22, 20, 21,

        5, 11, 17,
        17, 23, 5,

        4, 16, 10,
        16, 4, 22,
    };

    const wall_indices = [_]u16{
        6, 8, 7,
        8, 6, 9,
    };

    const door_verts = [_][3]f32{
        .{ dims.room_width, 0, -dims.door_width - dims.frame_depth },
        .{ dims.room_width - dims.frame_depth, 0, -dims.door_width - dims.frame_depth },
        .{ dims.room_width - dims.frame_depth, 0, -dims.door_width + dims.frame_depth },
        .{ dims.room_width, 0, -dims.door_width + dims.frame_depth },

        .{ dims.room_width, dims.door_height + dims.frame_depth, -dims.door_width - dims.frame_depth },
        .{ dims.room_width - dims.frame_depth, dims.door_height + dims.frame_depth, -dims.door_width - dims.frame_depth },
        .{ dims.room_width - dims.frame_depth, dims.door_height - dims.frame_depth, -dims.door_width + dims.frame_depth },
        .{ dims.room_width, dims.door_height - dims.frame_depth, -dims.door_width + dims.frame_depth },

        .{ dims.room_width, dims.door_height + dims.frame_depth, dims.door_width + dims.frame_depth },
        .{ dims.room_width - dims.frame_depth, dims.door_height + dims.frame_depth, dims.door_width + dims.frame_depth },
        .{ dims.room_width - dims.frame_depth, dims.door_height - dims.frame_depth, dims.door_width - dims.frame_depth },
        .{ dims.room_width, dims.door_height - dims.frame_depth, dims.door_width - dims.frame_depth },

        .{ dims.room_width, 0, dims.door_width + dims.frame_depth },
        .{ dims.room_width - dims.frame_depth, 0, dims.door_width + dims.frame_depth },
        .{ dims.room_width - dims.frame_depth, 0, dims.door_width - dims.frame_depth },
        .{ dims.room_width, 0, dims.door_width - dims.frame_depth },
    };
    const door_aabb = main.AABB{
        .min = .{ dims.room_width - dims.frame_depth, 0, -dims.door_width - dims.frame_depth },
        .max = .{ dims.room_width, dims.door_height + dims.frame_depth, dims.door_width + dims.frame_depth },
    };


    const door_indices = [_]u16{
        4, 0, 1,
        1, 5, 4,
        5, 1, 2,
        2, 6, 5,
        6, 2, 3,
        3, 7, 6,

        8, 4, 5,
        5, 9, 8,
        9, 5, 6,
        6, 10, 9,
        10, 6, 7,
        7, 11, 10,

        12, 8, 9,
        9, 13, 12,
        13, 9, 10,
        10, 14, 13,
        14, 10, 11,
        11, 15, 14,
    };

    const cube_verts = [_][3]f32{
        .{  0.05, 0.05,  0.05 },
        .{ -0.05, 0.05,  0.05 },
        .{ -0.05, 0.0 ,  0.05 },
        .{  0.05, 0.0 ,  0.05 },
        .{  0.05, 0.0 , -0.05 },
        .{ -0.05, 0.0 , -0.05 },
        .{ -0.05, 0.05, -0.05 },
        .{  0.05, 0.05, -0.05 },
    };

    const cube_aabb = main.AABB{
        .min = .{ -0.05, 0.0 , -0.05 },
        .max = .{  0.05, 0.05,  0.05 },
    };

    const cube_indices = [_]u16{
        0, 1, 2,
        2, 3, 0,
        
        4, 3, 2,
        2, 5, 4,

        6, 4, 5,
        4, 6, 7,

        1, 0, 7,
        7, 6, 1,

        2, 1, 6,
        6, 5, 2,

        0, 3, 4,
        4, 7, 0,
    };
    // zig fmt: on

    // Lay out the buffer
    var buffer_size: u32 = 0;
    const room_vertex_offset = buffer_size;
    const room_base_vertex = @divExact(buffer_size, @sizeOf([3]f32));
    const wall_base_vertex = room_base_vertex;
    buffer_size += @sizeOf(@TypeOf(room_verts));
    const door_vertex_offset = buffer_size;
    const door_base_vertex = @divExact(buffer_size, @sizeOf([3]f32));
    buffer_size += @sizeOf(@TypeOf(door_verts));
    const cube_vertex_offset = buffer_size;
    const cube_base_vertex = @divExact(buffer_size, @sizeOf([3]f32));
    buffer_size += @sizeOf(@TypeOf(cube_verts));
    const mesh_vertices_size = buffer_size;

    var index_offset: u32 = 0;
    const mesh_indices_offset = buffer_size;
    const room_indices_offset = mesh_indices_offset;
    const room_base_index = index_offset;
    buffer_size += @sizeOf(@TypeOf(room_indices));
    index_offset += @intCast(u32, room_indices.len);
    const wall_indices_offset = buffer_size;
    const wall_base_index = index_offset;
    buffer_size += @sizeOf(@TypeOf(wall_indices));
    index_offset += @intCast(u32, wall_indices.len);
    const door_indices_offset = buffer_size;
    const door_base_index = index_offset;
    buffer_size += @sizeOf(@TypeOf(door_indices));
    index_offset += @intCast(u32, door_indices.len);
    const cube_indices_offset = buffer_size;
    const cube_base_index = index_offset;
    buffer_size += @sizeOf(@TypeOf(cube_indices));
    index_offset += @intCast(u32, cube_indices.len);
    const mesh_indices_size = buffer_size - mesh_indices_offset;

    const mesh_buffer = device.createBuffer(&gpu.Buffer.Descriptor{
        .label = "mesh_buffer",
        .usage = .{ .copy_dst = true, .vertex = true, .index = true },
        .size = buffer_size,
    });
    queue.writeBuffer(mesh_buffer, room_vertex_offset, &room_verts);
    queue.writeBuffer(mesh_buffer, door_vertex_offset, &door_verts);
    queue.writeBuffer(mesh_buffer, cube_vertex_offset, &cube_verts);
    queue.writeBuffer(mesh_buffer, room_indices_offset, &room_indices);
    queue.writeBuffer(mesh_buffer, wall_indices_offset, &wall_indices);
    queue.writeBuffer(mesh_buffer, door_indices_offset, &door_indices);
    queue.writeBuffer(mesh_buffer, cube_indices_offset, &cube_indices);

    meshes.* = .{
        .mesh_buffer = mesh_buffer,
        .mesh_vertex_offset = 0,
        .mesh_vertex_size = mesh_vertices_size,
        .mesh_indices_offset = mesh_indices_offset,
        .mesh_indices_size = mesh_indices_size,

        .room = .{
            .base_vertex = @intCast(i32, room_base_vertex),
            .base_index = room_base_index,
            .indices_count = room_indices.len,
            .aabb = room_aabb,
        },
        .wall = .{
            .base_vertex = @intCast(i32, wall_base_vertex),
            .base_index = wall_base_index,
            .indices_count = wall_indices.len,
            .aabb = wall_aabb,
        },
        .door = .{
            .base_vertex = @intCast(i32, door_base_vertex),
            .base_index = door_base_index,
            .indices_count = door_indices.len,
            .aabb = door_aabb,
        },
        .cube = .{
            .base_vertex = @intCast(i32, cube_base_vertex),
            .base_index = cube_base_index,
            .indices_count = cube_indices.len,
            .aabb = cube_aabb,
        },
    };
}

pub fn bind(meshes: *StaticMeshes, pass: *gpu.RenderPassEncoder, vertex_binding_slot: u32) void {
    pass.setVertexBuffer(vertex_binding_slot, meshes.mesh_buffer, meshes.mesh_vertex_offset, meshes.mesh_vertex_size);
    pass.setIndexBuffer(meshes.mesh_buffer, .uint16, meshes.mesh_indices_offset, meshes.mesh_indices_size);
}
