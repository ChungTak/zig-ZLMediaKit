const std = @import("std");
const c = @import("c.zig").c;
const errors = @import("errors.zig");
const std_mem = std.mem;
const Allocator = std_mem.Allocator;

/// 推流器
pub const Pusher = struct {
    /// 推流器句柄
    handle: c.mk_pusher,
    /// 是否已释放
    released: bool = false,

    /// 推流器事件类型
    pub const EventType = struct {
        /// 推流器已准备好
        pub const ready: u8 = 0;
        /// 推流成功
        pub const success: u8 = 1;
        /// 推流失败
        pub const failed: u8 = 2;

        /// 从C API的值转换
        pub fn fromCValue(value: i32) u8 {
            return switch (value) {
                0 => ready,
                1 => success,
                2 => failed,
                else => failed,
            };
        }
    };

    /// 推流器配置选项
    pub const Options = struct {
        /// 推流地址，支持rtsp/rtmp等
        url: []const u8,
        /// 超时时间，单位毫秒，默认10000
        timeout_ms: u32 = 10000,
        /// 重试次数，默认3次
        retry_count: u32 = 3,
        /// 使用TCP传输RTSP流，默认开启
        use_tcp: bool = true,
    };

    /// 创建推流器
    pub fn create(media_source: []const u8, options: Options) errors.MediaKitError!Pusher {
        // 解析媒体源地址
        var schema: []const u8 = "__defaultVhost__";
        var app: []const u8 = "live";
        var stream: []const u8 = "";

        if (std.mem.indexOf(u8, media_source, "/")) |pos1| {
            if (std.mem.indexOf(u8, media_source[pos1 + 1 ..], "/")) |pos2| {
                schema = media_source[0..pos1];
                app = media_source[pos1 + 1 .. pos1 + 1 + pos2];
                stream = media_source[pos1 + 1 + pos2 + 1 ..];
            }
        }

        const handle = c.mk_pusher_create(schema.ptr, "__defaultVhost__".ptr, app.ptr, stream.ptr);
        if (handle == null) {
            return errors.MediaKitError.Failed;
        }

        // 设置选项
        const timeout_str = std.fmt.allocPrint(std.heap.c_allocator, "{d}", .{options.timeout_ms}) catch return errors.MediaKitError.NoMem;
        defer std.heap.c_allocator.free(timeout_str);
        c.mk_pusher_set_option(handle, "timeout_ms", timeout_str.ptr);

        const retry_str = std.fmt.allocPrint(std.heap.c_allocator, "{d}", .{options.retry_count}) catch return errors.MediaKitError.NoMem;
        defer std.heap.c_allocator.free(retry_str);
        c.mk_pusher_set_option(handle, "retry_count", retry_str.ptr);

        c.mk_pusher_set_option(handle, "rtsp_use_tcp", if (options.use_tcp) "1" else "0");

        return Pusher{
            .handle = handle,
        };
    }

    /// 开始推流
    pub fn start(self: *Pusher) errors.MediaKitError!void {
        _ = c.mk_pusher_publish(self.handle, null);
        // 由于我们不需要检查返回值，直接忽略它
    }

    /// 停止推流
    pub fn stop(self: *Pusher) void {
        c.mk_pusher_stop(self.handle);
    }

    /// 释放推流器
    pub fn release(self: *Pusher) void {
        if (!self.released) {
            c.mk_pusher_release(self.handle);
            self.released = true;
        }
    }

    /// 设置推流器配置项
    pub fn setOption(self: *Pusher, key: []const u8, val: []const u8) void {
        c.mk_pusher_set_option(self.handle, key.ptr, val.ptr);
    }

    /// 事件回调函数类型
    pub const OnEventCallback = *const fn (user_data: ?*anyopaque, event_type: u8, msg: ?[]const u8) void;
    var event_callback: ?OnEventCallback = null;
    var event_callback_user_data: ?*anyopaque = null;

    /// 设置推流器事件回调
    pub fn setOnEvent(self: *Pusher, cb: OnEventCallback, user_data: ?*anyopaque) void {
        event_callback = cb;
        event_callback_user_data = user_data;

        // 转发到C回调
        const c_func = struct {
            pub fn callback(user_data_ptr: ?*anyopaque, event_type_val: i32, msg_ptr: ?[*:0]const u8) callconv(.C) void {
                if (event_callback) |callback_fn| {
                    const event_type = EventType.fromCValue(event_type_val);
                    const msg_slice = if (msg_ptr) |ptr| std.mem.span(ptr) else null;
                    callback_fn(user_data_ptr, event_type, msg_slice);
                }
            }
        }.callback;

        c.mk_pusher_set_on_result(self.handle, c_func, user_data);
        c.mk_pusher_set_on_shutdown(self.handle, c_func, user_data);
    }
};
