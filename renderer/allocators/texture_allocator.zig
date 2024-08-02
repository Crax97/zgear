const std = @import("std");
const types = @import("../types.zig");
const c = @import("../clibs.zig");
const sampler_allocator = @import("./sampler_allocator.zig");
const renderer = @import("../renderer.zig");

const Allocator = std.mem.Allocator;
const Texture = types.Texture;
const TextureFlags = types.TextureFlags;
const TextureHandle = types.TextureHandle;
const VkDevice = renderer.VkDevice;

const Textures = std.ArrayList(?Texture);
pub const TextureAllocation = struct { texture: Texture, handle: TextureHandle };

const vk_check = renderer.vk_check;
pub const TextureAllocator = struct {
    const num_descriptors: u32 = 16536;
    const bindless_textures_binding: u32 = 1;

    all_textures: Textures,

    allocator: Allocator,
    vk_allocator: c.VmaAllocator,
    unused_handles: std.ArrayList(TextureHandle),

    pub fn init(allocator: Allocator, vma: c.VmaAllocator) !TextureAllocator {
        return .{
            .allocator = allocator,
            .all_textures = Textures.init(allocator),
            .vk_allocator = vma,
            .unused_handles = std.ArrayList(TextureHandle).init(allocator),
        };
    }

    pub fn alloc_texture(this: *TextureAllocator, device: VkDevice, sam_allocator: *sampler_allocator.SamplerAllocator, description: Texture.CreateInfo) !TextureAllocation {
        var texture_handle: TextureHandle = undefined;
        var texture: *?Texture = undefined;

        const sampler = try sam_allocator.get(description.sampler_config);

        if (this.unused_handles.items.len > 0) {
            texture_handle = this.unused_handles.pop();
            texture = &this.all_textures.items[texture_handle.id];
        } else {
            const len = this.all_textures.items.len;
            texture = try this.all_textures.addOne();
            texture_handle = TextureHandle{
                .id = @intCast(len),
            };
        }

        var usage: u32 = c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT;
        if (description.flags.render_attachment) {
            const attachment_bit = types.vk_attachment_usage(description.format);
            usage |= attachment_bit;
        }
        if (description.flags.trasfer_src) {
            usage |= c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
        }
        const format = types.vk_format(description.format);
        const image_type = c.VK_IMAGE_TYPE_2D;
        const image_desc = c.VkImageCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .extent = c.VkExtent3D{
                .width = description.width,
                .height = description.height,
                .depth = description.depth,
            },
            .usage = usage,
            .tiling = if (description.flags.cpu_readable) c.VK_IMAGE_TILING_LINEAR else c.VK_IMAGE_TILING_OPTIMAL,
            .format = format,
            .imageType = image_type,
            .samples = c.VK_SAMPLE_COUNT_1_BIT,
            .mipLevels = 1,
            .arrayLayers = 1,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .pQueueFamilyIndices = &[_]u32{device.queue.qfi},
            .queueFamilyIndexCount = 1,
        };

        var image = std.mem.zeroes(c.VkImage);

        const mem_alloc_info = c.VmaAllocationCreateInfo{ .flags = 0, .usage = c.VMA_MEMORY_USAGE_AUTO, .memoryTypeBits = 0, .requiredFlags = 0 };
        var allocation = std.mem.zeroes(c.VmaAllocation);
        vk_check(c.vmaCreateImage(this.vk_allocator, &image_desc, &mem_alloc_info, &image, &allocation, null), "Failed to create image through vma");

        const swizzle = if (description.format == .r_8) c.VkComponentMapping{
            .r = c.VK_COMPONENT_SWIZZLE_R,
            .g = c.VK_COMPONENT_SWIZZLE_R,
            .b = c.VK_COMPONENT_SWIZZLE_R,
            .a = c.VK_COMPONENT_SWIZZLE_R,
        } else c.VkComponentMapping{
            .r = c.VK_COMPONENT_SWIZZLE_R,
            .g = c.VK_COMPONENT_SWIZZLE_G,
            .b = c.VK_COMPONENT_SWIZZLE_B,
            .a = c.VK_COMPONENT_SWIZZLE_A,
        };

        const image_view_desc = c.VkImageViewCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .pNext = null,
            .image = image,
            .format = format,
            .flags = 0,
            .components = swizzle,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .subresourceRange = c.VkImageSubresourceRange{
                .layerCount = 1,
                .levelCount = 1,
                .baseMipLevel = 0,
                .baseArrayLayer = 0,
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            },
        };
        var image_view = std.mem.zeroes(c.VkImageView);
        vk_check(c.vkCreateImageView(device.handle, &image_view_desc, null, &image_view), "Could not create image view");

        texture.* = Texture{
            .handle = texture_handle,
            .view = image_view,
            .image = image,
            .sampler = sampler,
            .allocation = allocation,
        };

        return TextureAllocation{
            .handle = texture_handle,
            .texture = texture.*.?,
        };
    }

    pub fn free_texture(this: *TextureAllocator, device: VkDevice, tex_handle: TextureHandle) void {
        const texture = this.all_textures.items[tex_handle.id].?;
        this.all_textures.items[tex_handle.id] = null;

        c.vkDestroyImageView(device.handle, texture.view, null);
        c.vmaDestroyImage(this.vk_allocator, texture.image, texture.allocation);
    }

    pub fn deinit(this: *TextureAllocator, device: VkDevice) void {
        for (this.all_textures.items) |tex_maybe| {
            if (tex_maybe) |*tex| {
                this.free_texture(device, tex.handle);
            }
        }
    }
};
