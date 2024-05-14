const std = @import("std");
const gpu = @import("gpu");
const SharedResources = @This();

const TextUniforms = extern struct {
    scales: [2]f32,
    neg_pixel_threshold: f32,
    inv_pixel_distance: f32,
    color: Vec,
};

const CharGpuData = extern struct {
    x_offset: [2]f32,
    y_offset: [2]f32,
    x_uvs: [2]f32,
    y_uvs: [2]f32,
};

const FontInstanceData = extern struct {
    x_position: f32,
    char_gpu_id: u32,
};

pub const CachedText = struct {
    instances_buffer: *gpu.Buffer,
    instances_count: usize,

    pub fn release(self: *CachedText) void {
        self.instances_buffer.release();
    }

    pub fn render(text: *CachedText, cb: *gpu.RenderPassEncoder) void {
        cb.setVertexBuffer(0, self.instances_buffer, 0, self.instances_count * @sizeOf(FontInstanceData));
        cb.draw(4, text.instances_count, 0, 0);
    }

    pub fn renderSubstring(text: *CachedText, start: usize, length: usize, cb: *gpu.RenderPassEncoder) void {
        std.debug.assert(start + length < self.instances_count);
        cb.setVertexBuffer(0, self.instances_buffer, 0, self.instances_count * @sizeOf(FontInstanceData));
        cb.draw(4, length, 0, start);
    }
};

pub const Font = struct {
    name: [64]u8,

    ascii_chars: [128]CharData,
    extended_chars: std.HashMapUnmanaged(u16, CharCpuData),

    kerns: std.HashMapUnmanaged(KernKey, i16),

    glyphs: GlyphResources,

    pub fn createSizeResources(
        font: Font,
        device: *gpu.Device,
        shared: SharedResources,
        font_height: f32,
        screen_size: [2]f32,
        color: Vec,
    ) SizeResources {
        var uniforms: TextUniforms = .{
            .scales = .{},
            .neg_pixel_threshold = 0,
            .inv_pixel_distance = 0,
            .color = color,
        };
        var sized_name: [128]u8 = undefined;
        const printed = std.fmt.bufPrintZ(&sized_name, "{s}@{}", .{std.mem.sliceTo(&font.name, 0), font_height});
        const label: ?[*:0]const u8 = if (printed) |p| p.ptr else |err| null;
        const buffer = device.createBuffer(&gpu.Buffer.Descriptor{
            .label = label,
            .usage = .{ .uniform = true },
            .size = @sizeOf(TextUniforms),
            .mapped_at_creation = true,
        });
        const data = buffer.getMappedRange(TextUniforms, 0, @sizeOf(TextUniforms))
            orelse @panic("Could not fetch mapped buffer range");
        data[0] = uniforms;
        buffer.unmap();
        const bindings = device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
            .label = label,
            .layout = shared.font_size_bindings_layout,
            .entries = &[_]gpu.BindGroup.Entry{
                gpu.BindGroup.Entry.buffer(0, buffer, 0, @sizeOf(TextUniforms)),
            },
        }));
        return SizeResources{
            .buffer = buffer,
            .bindings = bindings,
        };
    }
};

pub const SizeResources = struct {
    buffer: *gpu.Buffer,
    bindings: *gpu.BindGroup,

    pub fn release(self: *SizeResources) void {
        self.bindings.release();
        self.buffer.release();
    }
};

pub const GlyphResources = struct {
    texture: *gpu.Texture,
    char_data_buffer: *gpu.Buffer,
    bindings: *gpu.BindGroup,

    pub fn release(self: *SizeResources) void {
        self.texture.release();
        self.char_data_buffer.release();
        self.bindings.release();
    }
};

pub const SharedResources = struct {
    page_sampler: *gpu.Sampler,
    font_shared_bindings: *gpu.BindGroup,
    font_glyph_bindings_layout: *gpu.BindGroupLayout,
    font_size_bindings_layout: *gpu.BindGroupLayout,
    pipeline: *gpu.RenderPipeline,

    pub fn create(device: *gpu.Device, multisample: u32) SharedResources {
        const page_sampler = device.createSampler(&gpu.Sampler.Descriptor{
            .label = "font_sampler",
            .mag_filter = .linear,
            .min_filter = .linear,
        });

        const font_shared_bindings_layout = device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
            .label = "font_shared_bindings_layout",
            .entries = &.{
                gpu.BindGroupLayout.Entry.sampler(0, .{ .fragment = true }, .filtering),
            },
        }));
        defer font_shared_bindings_layout.release();

        const font_glyph_bindings_layout = device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
            .label = "font_glyph_bindings_layout",
            .entries = &.{
                gpu.BindGroupLayout.Entry.texture(0, .{ .fragment = true }, .float, .dimension_2d, false),
                gpu.BindGroupLayout.Entry.buffer(1, .{ .vertex = true }, .read_only_storage, true, 0),
            },
        }));

        const font_size_bindings_layout = device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
            .label = "font_size_bindings_layout",
            .entries = &.{
                gpu.BindGroupLayout.Entry.buffer(0, .{ .vertex = true, .fragment = true }, .uniform, false, @sizeOf(TextUniforms)),
            },
        }));

        const font_shared_bindings = device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
            .label = "font_shared_bindings",
            .layout = font_shared_bindings_layout,
            .entries = &.{
                gpu.BindGroup.Entry.sampler(0, page_sampler),
            },
        }));

        const pipeline_layout = device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
            .label = "font_pipeline_layout",
            .bind_group_layouts = &.{
                font_shared_bindings_layout,
                font_glyph_bindings_layout,
                font_size_bindings_layout,
            },
        }));
        defer pipeline_layout.release();

        const font_wgsl = device.createShaderModuleWGSL("font.wgsl:vert_main", @embedFile("font.wgsl"));
        defer font_wgsl.release();

        const use_alpha_to_coverage = multisample > 2;

        const pipeline = device.createRenderPipeline(&gpu.RenderPipeline.Descriptor{
            .label = "font_pipeline",
            .layout = pipeline_layout,
            .vertex = gpu.VertexState.init(.{
                .module = font_wgsl,
                .entry_point = "vert_main",
                .buffers = &[_]gpu.VertexBufferLayout{
                    gpu.VertexBufferLayout.init(.{
                        .array_stride = @sizeOf(FontInstanceData),
                        .step_mode = .instance,
                        .attributes = &[_]gpu.VertexAttribute{
                            .{ .format = .float32, .offset = @offsetOf(FontInstanceData, "x_position" ), .shader_location = 0 },
                            .{ .format = .uint32,  .offset = @offsetOf(FontInstanceData, "char_gpu_id"), .shader_location = 1 },
                        },
                    }),
                },
            }),
            .primitive = gpu.PrimitiveState{
                .topology = .triangle_strip,
                .strip_index_format = .undef,
                .front_face = .ccw,
                .cull_mode = .none,
            },
            .depth_stencil = null,
            .multisample = .{
                .count = multisample,
                .alpha_to_coverage_enabled = use_alpha_to_coverage,
            },
            .fragment = &gpu.FragmentState.init(.{
                .module = font_wgsl,
                .entry_point = "frag_main",
                .targets = &[_]gpu.ColorTargetState{ .{
                    .format = core.swap_chain_format,
                    .blend = if (use_alpha_to_coverage) null
                        else &gpu.BlendState{
                            .color = .{
                                .operation = .add,
                                .src_factor = .src_alpha,
                                .dst_factor = .one_minus_src_alpha,
                            },
                            .alpha = .{
                                .operation = .add,
                                .src_factor = .one,
                                .dst_factor = .one_minus_src_alpha,
                            }
                        },
                }},
            }),
        });

        return SharedResources{
            .page_sampler = page_sampler,
            .font_shared_bindings = font_shared_bindings,
            .font_glyph_bindings_layout = font_glyph_bindings_layout,
            .font_size_bindings_layout = font_size_bindings_layout,
            .pipeline = pipeline,
        };
    }

    pub fn release() void {
        self.pipeline.release();
        self.font_size_bindings_layout.release();
        self.font_glyph_bindings_layout.release();
        self.font_shared_bindings.release();
        self.page_sampler.release();
    }
};

pub fn bindPipeline(resources: SharedResources, cb: *gpu.RenderPassEncoder) void {
    cb.setPipeline(resources.pipeline);
    cb.setBindGroup(0, resources.font_shared_bindings);
}

pub fn bindGlyphs(resources: GlyphResources, cb: *gpu.RenderPassEncoder) void {
    cb.setBindGroup(1, resources.bindings);
}

pub fn bindSize(resources: SizeResources, cb: *gpu.RenderPassEncoder) void {
    cb.setBindGroup(2, resources.bindings);
}



// Copy of the stdlib Utf8Iterator but skips over invalid codepoints
pub const SafeUtf8Iterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn init(string: []const u8) SafeUtf8Iterator {
        return .{ .bytes = string, .i = 0 };
    }

    pub fn nextCodepointSlice(it: *SafeUtf8Iterator) !?[]const u8 {
        if (it.i >= it.bytes.len) {
            return null;
        }

        const cp_len = std.unicode.utf8ByteSequenceLength(it.bytes[it.i]) catch |_| {
            it.i += 1;
            return error.Utf8InvalidCharacter;
        };
        if (it.i + cp_len > it.bytes.len) {
            it.i = it.bytes.len;
            return error.Utf8InvalidCharacter;
        }
        it.i += cp_len;
        return it.bytes[it.i - cp_len .. it.i];
    }

    pub fn nextCodepoint(it: *SafeUtf8Iterator) !?u21 {
        const slice = (try it.nextCodepointSlice()) orelse return null;
        return std.unicode.utf8Decode(slice) catch |_| error.Utf8InvalidCharacter;
    }

    /// Look ahead at the next n codepoints without advancing the iterator.
    /// If fewer than n codepoints are available, then return the remainder of the string.
    pub fn peek(it: *SafeUtf8Iterator, n: usize) []const u8 {
        const original_i = it.i;
        defer it.i = original_i;

        var end_ix = original_i;
        var found: usize = 0;
        while (found < n) : (found += 1) {
            const next_codepoint = (try it.nextCodepointSlice()) orelse return it.bytes[original_i..];
            end_ix += next_codepoint.len;
        }

        return it.bytes[original_i..end_ix];
    }
};