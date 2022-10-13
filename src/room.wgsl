struct ViewUniforms {
  view_proj: mat4x4<f32>,
};

struct ObjectUniforms {
  transform: mat3x4<f32>,
  color: vec4<f32>,
}

@group(0) @binding(0) var<uniform> view: ViewUniforms;
@group(1) @binding(0) var<uniform> object: ObjectUniforms;

struct Interpolators {
  @location(0) color: vec3<f32>,
  @location(1) depth: f32,
  // This definition is repeated in VertexOut, don't forget to modify both.
};

struct VertexOut {
  // Can't nest structs apparently so Interpolators definition is repeated here.
  // Will likely need to start using a preprocessor if there's no workaround for that.
  @location(0) color: vec3<f32>,
  @location(1) depth: f32,
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

@vertex
fn instanced_vert_main(
  @location(0) a_pos : vec3<f32>,
  @location(1) a_translation: vec2<f32>,
  @location(2) a_rotation: u32,
  @location(3) a_color: vec4<f32>,
) -> VertexOut {
  var result: VertexOut;
  var inst_pos = transform_instance_vertex(a_pos, a_rotation, a_translation);
  result.color = a_color.rgb;
  result.position = view.view_proj * vec4<f32>(inst_pos, 1.0);
  result.depth = result.position.w;
  return result;
}

@vertex
fn object_vert_main(
  @location(0) a_pos : vec3<f32>,
) -> VertexOut {
  var result: VertexOut;
  var inst_pos = transpose(object.transform) * vec4<f32>(a_pos, 1.0);
  result.color = object.color.rgb;
  result.position = view.view_proj * vec4<f32>(inst_pos, 1.0);
  result.depth = result.position.w;
  return result;
}

@fragment
fn frag_main(
  @builtin(position) device_pos : vec4<f32>,
  inputs: Interpolators,
) -> @location(0) vec4<f32> {
  let brightness = 1.0 - smoothstep(-0.4, 3.0, inputs.depth);
  return vec4<f32>(vec3<f32>(brightness) * inputs.color, 1.0);
}
