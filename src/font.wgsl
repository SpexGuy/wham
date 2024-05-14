struct CharGpuData {
    x_bounds: array<f32, 2>,
    y_bounds: array<f32, 2>,
    x_uvs: array<f32, 2>,
    y_uvs: array<f32, 2>,
};

struct TextUniforms {
    scales: vec2<f32>,
    neg_pixel_threshold: f32,
    inv_pixel_distance: f32,
    color: vec4<f32>,
};

@group(0) @binding(0) var font_sampler : sampler;

@group(1) @binding(0) var font_texture : texture_2d<f32>;
@group(1) @binding(1) var<storage, read> char_data : array<CharGpuData>;

@group(2) @binding(0) var<uniform> text_uniforms : TextUniforms;

struct VertexOut {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

@vertex
fn vert_main(
  @builtin(vertex_index) vert_id : u32,
  @location(0) x_offset : f32,
  @location(1) char_idx : u32,
) -> VertexOut {
  let x_idx = vert_id & 1;
  let y_idx = (vert_id & 2) >> 1;
  let char = char_data[char_idx];
  let x = (char.x_bounds[x_idx] + x_offset) * text_uniforms.scales.x;
  let y = char.y_bounds[y_idx] * text_uniforms.scales.y;
  let u = char.x_uvs[x_idx];
  let v = char.x_uvs[y_idx];
  var result : VertexOut;
  result.position = vec4<f32>(x, y, 0, 1);
  result.uv = vec2<f32>(u, v);
  return result;
}

fn frag_main(
    @location(0) uv: vec2<f32>,
) -> @location(0) vec4<f32> {
    let tex = textureSample(font_texture, font_sampler, uv).r;
    let alpha = saturate(tex * text_uniforms.inv_pixel_distance + text_uniforms.neg_pixel_threshold);
    return alpha * text_uniforms.color;
}
