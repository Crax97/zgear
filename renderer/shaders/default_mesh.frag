#version 460

#extension GL_EXT_nonuniform_qualifier : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_EXT_shader_explicit_arithmetic_types : require

struct Vertex {
  vec3 position;
  float uv_x;
  vec3 normal;
  float uv_y;
  vec3 vertex_color;
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

layout(set = 0, binding = 0) uniform Geometry { Vertex vertices[]; };
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

layout(location = 0) in vec2 uv;
layout(location = 1) flat in uint inst_index;
layout(location = 2) in vec4 vertex_color;
layout(location = 3) in vec3 normal;
layout(location = 4) in vec3 position;
layout(location = 5) in vec3 world_position;

layout(location = 0) out vec4 color;

void main() {
    vec3 lightdir = normalize(vec3(-5.0, 10.0, -2.0) - world_position);
    float d = clamp(dot(normal, lightdir), 0.0, 1.0) * 0.3;
    vec3 base = vertex_color.xyz + vec3(d);
    color = vec4(base, 1.0);
}
