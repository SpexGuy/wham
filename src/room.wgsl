struct ViewUniforms {
  view_proj: mat4x4<f32>,
  inv_screen_size: vec2<f32>,
  forward: vec2<f32>,
};

struct ObjectUniforms {
  transform: mat3x4<f32>,
  color_a: vec4<f32>,
  color_b: vec4<f32>,
  blend_offset_scale: vec2<f32>,
}

@group(0) @binding(0) var<uniform> view: ViewUniforms;
@group(1) @binding(0) var<uniform> object: ObjectUniforms;

struct Interpolators {
  @location(0) color: vec3<f32>,
  @location(1) depth: f32,
  // This definition is repeated in VertexOut, don't forget to modify both.
};

struct ScreenspaceInterpolators {
  @location(0) color_a: vec3<f32>,
  @location(1) color_b: vec3<f32>,
  @location(2) depth: f32,
  // This definition is repeated in ScreenspaceVertexOut, don't forget to modify both.
};

struct VertexOut {
  // Can't nest structs apparently so Interpolators definition is repeated here.
  // Will likely need to start using a preprocessor if there's no workaround for that.
  @location(0) color: vec3<f32>,
  @location(1) depth: f32,
  @builtin(position) position: vec4<f32>,
}

struct ScreenspaceVertexOut {
  // Can't nest structs apparently so Interpolators definition is repeated here.
  // Will likely need to start using a preprocessor if there's no workaround for that.
  @location(0) color_a: vec3<f32>,
  @location(1) color_b: vec3<f32>,
  @location(2) depth: f32,
  @builtin(position) position: vec4<f32>,
}

// Transform the vertex position by the instance rotation and translation
// Rotation is decoded as follows, with each value being the number of
// counter-clockwise quarter turns when viewed from above.
// 0:       1:        2:         3:
// [1 0 0]  [0 0 -1]  [-1 0  0]  [ 0 0 1]
// [0 1 0]  [0 1  0]  [ 0 1  0]  [ 0 1 0]
// [0 0 1]  [1 0  0]  [ 0 0 -1]  [-1 0 0]
// Instead of actually calculating these matrices, we do a simpler
// but equivalent swizzle and conditional negate.
fn transform_instance_vertex(
  position: vec3<f32>,
  rotation: u32,
  translation: vec2<f32>,
) -> vec3<f32> {
  var rotated: vec3<f32>;
  if (rotation == 0) {
    rotated = position;
  } else if (rotation == 1) {
    rotated = vec3<f32>(position.z, position.y, -position.x);
  } else if (rotation == 2) {
    rotated = vec3<f32>(-position.x, position.y, -position.z);
  } else {
    rotated = vec3<f32>(-position.z, position.y, position.x);
  }
  return rotated + vec3<f32>(translation.x, 0, translation.y);
}

fn calculate_aabb_blend(blend_offset_scale: vec2<f32>, position: vec3<f32>) -> f32 {
  let across = vec3<f32>(view.forward.y, 0, -view.forward.x);
  let along = dot(across, position);
  return blend_offset_scale.y * along + blend_offset_scale.x;
}

@vertex
fn instanced_vert_main_aabb(
  @location(0) a_pos : vec3<f32>,
  @location(1) a_translation: vec2<f32>,
  @location(2) a_rotation: u32,
  @location(3) a_color_a: vec4<f32>,
  @location(4) a_color_b: vec4<f32>,
  @location(5) a_blend_offset_scale: vec2<f32>,
) -> VertexOut {
  var result: VertexOut;
  let world_pos = transform_instance_vertex(a_pos, a_rotation, a_translation);
  let blend = calculate_aabb_blend(a_blend_offset_scale, world_pos);
  result.position = view.view_proj * vec4<f32>(world_pos, 1.0);
  result.color = mix(a_color_a.rgb, a_color_b.rgb, blend);
  result.depth = result.position.w;
  return result;
}

@vertex
fn instanced_vert_main_screenspace(
  @location(0) a_pos : vec3<f32>,
  @location(1) a_translation: vec2<f32>,
  @location(2) a_rotation: u32,
  @location(3) a_color_a: vec4<f32>,
  @location(4) a_color_b: vec4<f32>,
) -> ScreenspaceVertexOut {
  var result: ScreenspaceVertexOut;
  let world_pos = transform_instance_vertex(a_pos, a_rotation, a_translation);
  result.position = view.view_proj * vec4<f32>(world_pos, 1.0);
  result.color_a = a_color_a.rgb;
  result.color_b = a_color_b.rgb;
  result.depth = result.position.w;
  return result;
}

@vertex
fn object_vert_main(
  @location(0) a_pos : vec3<f32>,
) -> VertexOut {
  var result: VertexOut;
  let world_pos = transpose(object.transform) * vec4<f32>(a_pos, 1.0);
  let blend = calculate_aabb_blend(object.blend_offset_scale, world_pos);
  result.position = view.view_proj * vec4<f32>(world_pos, 1.0);
  result.color = mix(object.color_a.rgb, object.color_b.rgb, blend);
  result.depth = result.position.w;
  return result;
}

@fragment
fn frag_main_screenspace(
  @builtin(position) device_pos : vec4<f32>,
  inputs: ScreenspaceInterpolators,
) -> @location(0) vec4<f32> {
  let blend = 1.0 - device_pos.x * view.inv_screen_size.x;
  let color = mix(inputs.color_a, inputs.color_b, blend);
  let brightness = 1.0 - smoothstep(-0.8, 4.0, inputs.depth);
  return vec4<f32>(vec3<f32>(brightness) * color, 1.0);
}

@fragment
fn frag_main(
  @builtin(position) device_pos : vec4<f32>,
  inputs: Interpolators,
) -> @location(0) vec4<f32> {
  let brightness = 1.0 - smoothstep(-0.8, 4.0, inputs.depth);
  return vec4<f32>(vec3<f32>(brightness) * inputs.color, 1.0);
}
