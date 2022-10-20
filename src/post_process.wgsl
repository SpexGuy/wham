struct PostProcessUniforms {
  color_rotation: mat3x3<f32>,
  colorblind_mode: u32,
}

// No vertex data, generate a triangle like this with vertex id:
// Backface culling is disabled, so we don't need to worry about winding.
// (-1, 3) .
//         .   .
//         .      .
// (-1, 1) +---------+ (1,1)
//         |         |  .
//         |         |     .
// (-1,-1) +---------+  .  .  . (3,-1)
@vertex
fn vert_main(
  @builtin(vertex_index) vert_id : u32,
) -> @builtin(position) vec4<f32> {
  var x = f32(vert_id & 1) * 4 - 1;
  var y = f32(vert_id & 2) * 2 - 1;
  return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> uniforms: PostProcessUniforms;
@group(0) @binding(1) var resolved_color: texture_2d<f32>;

const rgbToLms = mat3x3(
  17.8824, 43.5161, 4.1193,
  3.4557, 27.1554, 3.8671,
  0.02996, 0.18431, 1.4700,
);

const lmsToRgb = mat3x3(
  0.0809, -0.1305, 0.1167,
  -0.0102, 0.0540, -0.1136,
  -0.0003, -0.0041, 0.6932,
);

const protanopiaLms = mat3x3(
  0, 2.02344, -2.52581,
  0, 1, 0,
  0, 0, 1,
);

const deuteranopiaLms = mat3x3(
  1, 0, 0,
  0.4942, 0, 1.2483,
  0, 0, 1,
);

const tritanopiaLms = mat3x3(
  1, 0, 0,
  0, 1, 0,
  -0.03959, 0.08011, 0,
);

@fragment
fn frag_main(
  @builtin(position) device_pos : vec4<f32>,
) -> @location(0) vec4<f32> {
    let protanopia = rgbToLms * protanopiaLms * lmsToRgb;
    let deuteranopia = rgbToLms * deuteranopiaLms * lmsToRgb;
    let tritanopia = rgbToLms * tritanopiaLms * lmsToRgb;

    let base_color = textureLoad(resolved_color, vec2<i32>(device_pos.xy), 0);
    var adjusted = base_color.rgb;
    adjusted = uniforms.color_rotation * adjusted;

    if (uniforms.colorblind_mode == 1) {
        adjusted = adjusted * protanopia;
    } else if (uniforms.colorblind_mode == 2) {
        adjusted = adjusted * deuteranopia;
    } else if (uniforms.colorblind_mode == 3) {
        adjusted = adjusted * tritanopia;
    }
    return vec4<f32>(adjusted, base_color.a);
}
