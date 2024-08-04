const std = @import("std");
const renderer = @import("../renderer.zig");
const vk_check = renderer.vk_check;
const c = renderer.c;
const types = @import("../types.zig");
const Mesh = types.Mesh;
const MeshHandle = types.MeshHandle;

const Allocator = std.mem.Allocator;

pub const MeshAllocator = struct {
    pub const Settings = struct {
        buffer_size: usize = 1024 * 1024 * 512,
    };
    pub const Allocation = struct { mesh: Mesh, handle: MeshHandle };

    const Meshes = std.ArrayList(?Mesh);

    device: c.VkDevice,
    allocator: Allocator,
    vk_allocator: c.VmaAllocator,
    mesh_storage_buffer: c.VkBuffer,
    mesh_indices_buffer: c.VkBuffer,
    mesh_storage_allocation: c.VmaAllocation,
    mesh_indices_allocation: c.VmaAllocation,
    mesh_storage_address: c.VkDeviceAddress,
    mesh_buffer_block: c.VmaVirtualBlock,
    index_buffer_block: c.VmaVirtualBlock,
    unused_handles: std.ArrayList(MeshHandle),
    all_meshes: Meshes,

    pub fn init(device: renderer.VkDevice, allocator: Allocator, vk_allocator: c.VmaAllocator, settings: Settings) MeshAllocator {
        var mesh_storage_buffer: c.VkBuffer = undefined;
        var mesh_indices_buffer: c.VkBuffer = undefined;
        var mesh_storage_allocation: c.VmaAllocation = undefined;
        var mesh_indices_allocation: c.VmaAllocation = undefined;
        const buf_create_info = c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .usage = c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | c.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
            .flags = 0,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 1,
            .pQueueFamilyIndices = &[_]u32{device.queue.qfi},
            .size = @intCast(settings.buffer_size),
        };
        var alloc_info = std.mem.zeroes(c.VmaAllocationCreateInfo);
        alloc_info.usage = c.VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE;
        alloc_info.flags = c.VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT | c.VMA_ALLOCATION_CREATE_MAPPED_BIT;
        alloc_info.requiredFlags = c.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;

        vk_check(
            c.vmaCreateBuffer(
                vk_allocator,
                &buf_create_info,
                &alloc_info,
                &mesh_storage_buffer,
                &mesh_storage_allocation,
                null,
            ),
            "Failed to allocate mesh data buffer",
        );

        vk_check(
            c.vmaCreateBuffer(
                vk_allocator,
                &buf_create_info,
                &alloc_info,
                &mesh_indices_buffer,
                &mesh_indices_allocation,
                null,
            ),
            "Failed to allocate mesh data buffer",
        );

        const mesh_storage_address = c.vkGetBufferDeviceAddress(device.handle, &c.VkBufferDeviceAddressInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,
            .pNext = null,
            .buffer = mesh_storage_buffer,
        });

        var mesh_buffer_block: c.VmaVirtualBlock = undefined;
        vk_check(c.vmaCreateVirtualBlock(&c.VmaVirtualBlockCreateInfo{
            .size = @intCast(settings.buffer_size),
            .flags = 0,
            .pAllocationCallbacks = null,
        }, &mesh_buffer_block), "Failed to create mesh virtual memory block");

        var index_buffer_block: c.VmaVirtualBlock = undefined;
        vk_check(c.vmaCreateVirtualBlock(&c.VmaVirtualBlockCreateInfo{
            .size = @intCast(settings.buffer_size),
            .flags = 0,
            .pAllocationCallbacks = null,
        }, &index_buffer_block), "Failed to create index virtual memory block");

        return .{
            .device = device.handle,
            .allocator = allocator,
            .vk_allocator = vk_allocator,
            .mesh_storage_buffer = mesh_storage_buffer,
            .mesh_storage_allocation = mesh_storage_allocation,
            .mesh_indices_buffer = mesh_indices_buffer,
            .mesh_indices_allocation = mesh_indices_allocation,
            .mesh_storage_address = mesh_storage_address,
            .mesh_buffer_block = mesh_buffer_block,
            .index_buffer_block = index_buffer_block,
            .unused_handles = std.ArrayList(MeshHandle).init(allocator),
            .all_meshes = Meshes.init(allocator),
        };
    }

    pub fn deinit(this: *MeshAllocator) void {
        this.unused_handles.deinit();
        this.all_meshes.deinit();
        c.vmaDestroyBuffer(this.vk_allocator, this.mesh_storage_buffer, this.mesh_storage_allocation);
        c.vmaDestroyBuffer(this.vk_allocator, this.mesh_indices_buffer, this.mesh_indices_allocation);
        c.vmaDestroyVirtualBlock(this.mesh_buffer_block);
        c.vmaDestroyVirtualBlock(this.index_buffer_block);
    }

    pub fn alloc_mesh(this: *MeshAllocator, info: *const Mesh.CreateInfo) !Allocation {
        std.debug.assert(info.vertices.len > 0);
        std.debug.assert(info.indices.len > 0);
        var mesh_handle: MeshHandle = undefined;
        var mesh: *?Mesh = undefined;

        if (this.unused_handles.items.len > 0) {
            mesh_handle = this.unused_handles.pop();
            mesh = &this.all_meshes.items[mesh_handle.id];
        } else {
            const len = this.all_meshes.items.len;
            mesh = try this.all_meshes.addOne();
            mesh_handle = MeshHandle{
                .id = @intCast(len),
            };
        }

        var geom_alloc_info = std.mem.zeroes(c.VmaVirtualAllocationCreateInfo);
        geom_alloc_info.size = @sizeOf(types.Vertex) * info.vertices.len;
        var geom_offset: c.VkDeviceSize = 0;
        var geom_virtual_alloc: c.VmaVirtualAllocation = undefined;

        const res_geom = c.vmaVirtualAllocate(this.mesh_buffer_block, &geom_alloc_info, &geom_virtual_alloc, &geom_offset);

        var index_alloc_info = std.mem.zeroes(c.VmaVirtualAllocationCreateInfo);
        index_alloc_info.size = @sizeOf(u32) * info.indices.len;
        var index_offset: c.VkDeviceSize = 0;
        var index_virtual_alloc: c.VmaVirtualAllocation = undefined;
        const res_index = c.vmaVirtualAllocate(this.index_buffer_block, &index_alloc_info, &index_virtual_alloc, &index_offset);
        std.debug.print("alloc mesh geo off {d} ind {d}\n", .{ geom_offset, index_offset });
        if (res_geom == c.VK_SUCCESS and res_index == c.VK_SUCCESS) {
            mesh.* = Mesh{
                .geom_allocation = geom_virtual_alloc,
                .geometry_span = types.Span{
                    .value_offset = geom_offset / @sizeOf(types.Vertex),
                    .offset = geom_offset,
                    .size = geom_alloc_info.size,
                },
                .index_allocation = index_virtual_alloc,
                .index_span = types.Span{
                    .value_offset = index_offset / @sizeOf(u32),
                    .offset = index_offset,
                    .size = index_alloc_info.size,
                },
                .num_vertices = @intCast(info.indices.len),
            };
            return .{
                .mesh = mesh.*.?,
                .handle = mesh_handle,
            };
        } else {
            try this.unused_handles.append(mesh_handle);
            mesh.* = null;

            return error.MeshAllocationFailed;
        }
    }

    pub fn get(this: *MeshAllocator, mesh_handle: MeshHandle) Mesh {
        std.debug.assert(!mesh_handle.is_null());
        return this.all_meshes.items[mesh_handle.id].?;
    }

    pub fn free_mesh(this: *MeshAllocator, mesh_handle: MeshHandle) void {
        const mesh = this.all_meshes.items[mesh_handle.id].?;
        this.all_meshes.items[mesh_handle.id] = null;
        c.vmaVirtualFree(this.mesh_buffer_block, mesh.geom_allocation);
        c.vmaVirtualFree(this.index_buffer_block, mesh.index_allocation);
    }
};
