const std = @import("std");
const vk = @cImport(@cInclude("vulkan/vulkan.h"));

usingnamespace vk;

const Gpa = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    var gpa = Gpa{};
    var alloc = &gpa.allocator;
    defer _ = gpa.deinit();

    const application_info = std.mem.zeroInit(VkApplicationInfo, .{
        .sType = VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "zig-vk",
        .applicationVersion = 1,
        .apiVersion = VK_API_VERSION_1_0,
    });

    const enabled_layers = [_][]const u8 {"VK_LAYER_KHRONOS_validation"};
    const enabled_extensions = [_][]const u8 {
        VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
    };

    const debug_utils_messenger_create_info = std.mem.zeroInit(VkDebugUtilsMessengerCreateInfoEXT, .{
        .sType = VkStructureType.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = ~@as(VkDebugUtilsMessageSeverityFlagsEXT, 0),
        .messageType = ~@as(VkDebugUtilsMessageTypeFlagsEXT, 0),
        .pfnUserCallback = debug_callback
    });

    const instance_create_info = std.mem.zeroInit(VkInstanceCreateInfo, .{
        .sType = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = &debug_utils_messenger_create_info,
        .pApplicationInfo = &application_info,
        .enabledLayerCount = enabled_layers.len,
        .ppEnabledLayerNames = @ptrCast([*]const [*:0]const u8, &enabled_layers),
        .enabledExtensionCount = enabled_extensions.len,
        .ppEnabledExtensionNames = @ptrCast([*]const [*:0]const u8, &enabled_extensions),
    });

    var instance: VkInstance = null;
    try handle_vk_error(vkCreateInstance(&instance_create_info, null, &instance));

    var physical_device_count: u32 = 0;
    try handle_vk_error(vkEnumeratePhysicalDevices(instance, &physical_device_count, null));

    var physical_devices = try alloc.alloc(VkPhysicalDevice, physical_device_count);
    defer alloc.free(physical_devices);

    try handle_vk_error(vkEnumeratePhysicalDevices(instance, &physical_device_count, @ptrCast([*c]VkPhysicalDevice, &physical_devices)));

    for (physical_devices) |device| {
        var properties = std.mem.zeroes(VkPhysicalDeviceProperties);
        vkGetPhysicalDeviceProperties(device, @ptrCast([*c]VkPhysicalDeviceProperties, &properties));
        std.debug.print("{}\n", .{properties});
    }

}

fn handle_vk_error(result: VkResult) !void {
    if (result != VkResult.VK_SUCCESS) {
        std.debug.print("Failed with: {}\n", .{ result });
        return error.VulkanFailure;
    }
}

fn debug_callback(severity: VkDebugUtilsMessageSeverityFlagBitsEXT, message_type: VkDebugUtilsMessageTypeFlagsEXT, callback_data: [*c]const VkDebugUtilsMessengerCallbackDataEXT, _user_data: ?*c_void) callconv(.C) VkBool32 {
    const message = callback_data.*.pMessage;

    const severity_str = switch (severity) {
        VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "verbose",
        VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "info",
        VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "warning",
        VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "error",
        VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_FLAG_BITS_MAX_ENUM_EXT => "",
        _ => ""
    };

    const message_type_str = switch (message_type) {
        VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT => "general",
        VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT => "validation",
        VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT => "performance",
        VK_DEBUG_UTILS_MESSAGE_TYPE_FLAG_BITS_MAX_ENUM_EXT => "all",
        else => ""
    };

    std.debug.print("[{s}][{s}] {s}\n", .{ severity_str, message_type_str, message });

    return VK_FALSE;
}
