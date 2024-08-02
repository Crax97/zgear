#version 460

#extension GL_EXT_nonuniform_qualifier : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_shader_explicit_arithmetic_types : require

struct Vertex {
  vec4 pos_uvx;
  vec4 norm_uvy;
  vec4 vertex_color;
};

struct TexData {
  mat4 transform;
  vec4 offset_extent_px;
  vec4 color;
  uint tex_id;
};

struct SceneData {
  mat4 projection;
  mat4 view;
};

layout(set = 0, binding = 0) readonly buffer Geometry { Vertex vertices[]; };
layout(set = 0, binding = 6) uniform sampler2D[] tex2d_samplers;

layout(buffer_reference, std430,
       buffer_reference_align = 16) readonly buffer TextureDrawInfoBase {
  TexData data[];
};

layout(buffer_reference, std430,
       buffer_reference_align = 16) readonly buffer SceneDataBase {
  SceneData scene_data[];
};

layout(push_constant) uniform TexDrawConstants {
  TextureDrawInfoBase base;
  SceneDataBase scene_base;
};

layout(location = 0) out vec2 uv;
layout(location = 1) flat out uint inst_index;
layout(location = 2) out vec4 vertex_color;
layout(location = 3) out vec3 normal;
layout(location = 4) out vec3 vert_position;
layout(location = 5) out vec3 world_position;
void main() {

  Vertex vert = vertices[gl_VertexIndex];

  TexData tex_data = base.data[gl_InstanceIndex];
  vec2 tex_size = textureSize(tex2d_samplers[tex_data.tex_id], 0);

  mat4 proj = scene_base.scene_data[0].projection;
  mat4 view = scene_base.scene_data[0].view;
  mat4 vp = view * tex_data.transform;

  vec4 position_world = vp * vec4(vert.pos_uvx.xyz, 1.0);

  vec4 position_camera = proj * position_world;

  gl_Position = position_camera;
  uv = vec2(vert.pos_uvx.w, vert.norm_uvy.w);
  inst_index = gl_InstanceIndex;
  vertex_color = vert.vertex_color;
  normal = vert.norm_uvy.xyz;
  vert_position = vert.pos_uvx.xyz;
  world_position = position_world.xyz;
}
