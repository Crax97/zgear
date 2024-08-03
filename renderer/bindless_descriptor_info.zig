const std = @import("std");
const c = @import("clibs.zig");
const types = @import("types.zig");
const renderer = @import("renderer.zig");
const vk_check = renderer.vk_check;

const Texture = types.Texture;

const Allocator = std.mem.Allocator;

pub const BindlessDescriptorInfo = struct {
    const BindlessTextureUpdate = struct {
        view: c.VkImageView,
        sampler: c.VkSampler,
        position_in_array: u32,
    };

    const num_descriptors: u32 = 16536;
    const geometry_buffer_binding: u32 = 0;
    const indices_buffer_binding: u32 = 1;
    const bindless_textures_binding: u32 = 6;

    bindless_descriptor_set: c.VkDescriptorSet,
    bindless_descriptor_set_layout: c.VkDescriptorSetLayout,
    bindless_descriptor_pool: c.VkDescriptorPool,
    allocator: Allocator,

    updates: std.ArrayList(BindlessTextureUpdate),

    pub fn init(device: c.VkDevice, allocator: Allocator, global_geometry_buffer: c.VkBuffer, global_indices_buffer: c.VkBuffer) BindlessDescriptorInfo {
        var layout: c.VkDescriptorSetLayout = undefined;
        const bindings = [_]c.VkDescriptorSetLayoutBinding{
            c.VkDescriptorSetLayoutBinding{
                .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .descriptorCount = 1,
                .binding = geometry_buffer_binding,
                .stageFlags = c.VK_SHADER_STAGE_ALL,
                .pImmutableSamplers = null,
            },
            c.VkDescriptorSetLayoutBinding{
                .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .descriptorCount = 1,
                .binding = indices_buffer_binding,
                .stageFlags = c.VK_SHADER_STAGE_ALL,
                .pImmutableSamplers = null,
            },
            c.VkDescriptorSetLayoutBinding{
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = num_descriptors,
                .binding = bindless_textures_binding,
                .stageFlags = c.VK_SHADER_STAGE_ALL,
                .pImmutableSamplers = null,
            },
        };

        const bindless_flags: [3]u32 = [_]u32{
            0,
            0,
            @intCast(c.VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT | c.VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT),
        };
        const bindless_info = c.VkDescriptorSetLayoutBindingFlagsCreateInfoEXT{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
            .pNext = null,
            .bindingCount = 3,
            .pBindingFlags = &bindless_flags,
        };

        const info = c.VkDescriptorSetLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = &bindless_info,
            .flags = c.VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT,
            .pBindings = &bindings,
            .bindingCount = @intCast(bindings.len),
        };

        vk_check(c.vkCreateDescriptorSetLayout(device, &info, null, &layout), "Failed to create vk descriptor set layout");

        const pool_sizes = [_]c.VkDescriptorPoolSize{
            c.VkDescriptorPoolSize{
                .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .descriptorCount = 2,
            },
            c.VkDescriptorPoolSize{
                .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = num_descriptors,
            },
        };
        const pool_info = c.VkDescriptorPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            .flags = c.VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT,
            .maxSets = 4,
            .poolSizeCount = @intCast(pool_sizes.len),
            .pPoolSizes = &pool_sizes,
        };
        var descriptor_pool: c.VkDescriptorPool = undefined;
        vk_check(c.vkCreateDescriptorPool(device, &pool_info, null, &descriptor_pool), "Failed to create bindless descriptor pool");

        const max_bindings = num_descriptors - 1;
        const bindless_set_info = c.VkDescriptorSetVariableDescriptorCountAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_ALLOCATE_INFO,
            .pNext = null,
            .descriptorSetCount = 1,
            .pDescriptorCounts = &max_bindings,
        };
        const alloc_info = c.VkDescriptorSetAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .pNext = &bindless_set_info,
            .descriptorSetCount = 1,
            .descriptorPool = descriptor_pool,
            .pSetLayouts = &layout,
        };
        var descriptor_set: c.VkDescriptorSet = null;
        vk_check(c.vkAllocateDescriptorSets(device, &alloc_info, &descriptor_set), "Failed to allocate bindless descriptor set");
        const geom_buf_info = c.VkDescriptorBufferInfo{
            .buffer = global_geometry_buffer,
            .offset = 0,
            .range = c.VK_WHOLE_SIZE,
        };

        const ind_buf_info = c.VkDescriptorBufferInfo{
            .buffer = global_indices_buffer,
            .offset = 0,
            .range = c.VK_WHOLE_SIZE,
        };

        const writes = [_]c.VkWriteDescriptorSet{
            c.VkWriteDescriptorSet{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstArrayElement = 0,
                .dstSet = descriptor_set,
                .dstBinding = geometry_buffer_binding,
                .pTexelBufferView = null,
                .pBufferInfo = &geom_buf_info,
                .pImageInfo = null,
                .descriptorCount = 1,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            },
            c.VkWriteDescriptorSet{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstArrayElement = 0,
                .dstSet = descriptor_set,
                .dstBinding = indices_buffer_binding,
                .pTexelBufferView = null,
                .pBufferInfo = &ind_buf_info,
                .pImageInfo = null,
                .descriptorCount = 1,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            },
        };

        c.vkUpdateDescriptorSets(device, @intCast(writes.len), &writes, 0, null);

        return .{
            .bindless_descriptor_set = descriptor_set,
            .bindless_descriptor_set_layout = layout,
            .bindless_descriptor_pool = descriptor_pool,
            .updates = std.ArrayList(BindlessTextureUpdate).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(this: *BindlessDescriptorInfo, device: c.VkDevice) void {
        this.updates.deinit();
        c.vkDestroyDescriptorSetLayout(device, this.bindless_descriptor_set_layout, null);
        c.vkDestroyDescriptorPool(device, this.bindless_descriptor_pool, null);
    }

    pub fn add_write_texture_to_descriptor_set(this: *BindlessDescriptorInfo, texture: Texture, position_in_array: u32) !void {
        try this.updates.append(BindlessTextureUpdate{
            .view = texture.view,
            .sampler = texture.sampler,
            .position_in_array = position_in_array,
        });
    }

    pub fn flush_updates(this: *BindlessDescriptorInfo, device: c.VkDevice) !void {
        if (this.updates.items.len == 0) {
            return;
        }

        const image_infos = try this.allocator.alloc(c.VkDescriptorImageInfo, this.updates.items.len);
        const writes = try this.allocator.alloc(c.VkWriteDescriptorSet, this.updates.items.len);
        defer this.allocator.free(image_infos);
        defer this.allocator.free(writes);
        defer this.updates.clearRetainingCapacity();

        for (this.updates.items, 0..) |update, i| {
            image_infos[i] = c.VkDescriptorImageInfo{
                .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                .imageView = update.view,
                .sampler = update.sampler,
            };

            writes[i] = c.VkWriteDescriptorSet{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstArrayElement = update.position_in_array,
                .dstSet = this.bindless_descriptor_set,
                .dstBinding = bindless_textures_binding,
                .pTexelBufferView = null,
                .pBufferInfo = null,
                .pImageInfo = &image_infos[i],
                .descriptorCount = 1,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            };
        }

        c.vkUpdateDescriptorSets(device, @intCast(this.updates.items.len), writes.ptr, 0, null);
    }
};
