const std = @import("std");
const c = @import("c.zig").c;
const errors = @import("errors.zig");
const std_mem = std.mem;
const Allocator = std_mem.Allocator;

/// 播放器
pub const Player = struct {
    /// 播放器句柄
    handle: c.mk_player,
    /// 是否已释放
    released: bool = false,

    /// 播放器事件类型
    pub const EventType = struct {
        /// 播放器已准备好
        pub const ready: u8 = 0;
        /// 播放到达文件尾部(直播流不会触发)
        pub const end: u8 = 1;
        /// 播放被停止
        pub const stopped: u8 = 2;
        /// 播放出错
        pub const err: u8 = 3;

        /// 从C API的值转换
        pub fn fromCValue(value: i32) u8 {
            return switch (value) {
                0 => ready,
                1 => end,
                2 => stopped,
                3 => err,
                else => err,
            };
        }
    };

    /// 播放器配置选项
    pub const Options = struct {
        /// 播放地址，支持rtsp/rtmp/http-flv/http-ts/hls/http-mp4等
        url: []const u8,
        /// 最大缓存秒数，默认为3秒
        max_buffer_ms: u32 = 3000,
        /// 是否开启音频，默认开启
        enable_audio: bool = true,
        /// 是否开启视频，默认开启
        enable_video: bool = true,
        /// 使用TCP传输RTSP流，默认开启
        use_tcp: bool = true,
        /// 是否开启GOP缓存，开启后会对关键帧前面的数据进行缓存
        enable_gop_cache: bool = true,
        /// 是否开启按需转协议，不开启则缓存所有数据
        enable_convert: bool = false,
        /// 超时时间，单位毫秒，默认10000
        timeout_ms: u32 = 10000,
        /// 使用多少个线程解码视频，默认为0，表示自动
        decode_thread_num: u32 = 0,
    };

    /// 创建播放器
    pub fn create(options: Options) errors.MediaKitError!Player {
        const handle = c.mk_player_create();
        if (handle == null) {
            return errors.MediaKitError.Failed;
        }

        // 设置选项
        const max_buffer_str = std.fmt.allocPrint(std.heap.c_allocator, "{d}", .{options.max_buffer_ms}) catch return errors.MediaKitError.NoMem;
        defer std.heap.c_allocator.free(max_buffer_str);
        c.mk_player_set_option(handle, "max_buffer_ms", max_buffer_str.ptr);
        c.mk_player_set_option(handle, "enable_audio", if (options.enable_audio) "1" else "0");
        c.mk_player_set_option(handle, "enable_video", if (options.enable_video) "1" else "0");
        const timeout_str = std.fmt.allocPrint(std.heap.c_allocator, "{d}", .{options.timeout_ms}) catch return errors.MediaKitError.NoMem;
        defer std.heap.c_allocator.free(timeout_str);
        c.mk_player_set_option(handle, "protocol_timeout_ms", timeout_str.ptr);
        c.mk_player_set_option(handle, "retry_count", "3");
        c.mk_player_set_option(handle, "rtsp_use_tcp", if (options.use_tcp) "1" else "0");
        c.mk_player_set_option(handle, "enable_gop_cache", if (options.enable_gop_cache) "1" else "0");
        c.mk_player_set_option(handle, "enable_convert", if (options.enable_convert) "1" else "0");
        const thread_str = std.fmt.allocPrint(std.heap.c_allocator, "{d}", .{options.decode_thread_num}) catch return errors.MediaKitError.NoMem;
        defer std.heap.c_allocator.free(thread_str);
        c.mk_player_set_option(handle, "thread_num", thread_str.ptr);

        return Player{
            .handle = handle,
        };
    }

    /// 播放指定URL
    pub fn play(self: *Player, url: []const u8) errors.MediaKitError!void {
        c.mk_player_play(self.handle, url.ptr);
    }

    /// 暂停播放
    pub fn pause(self: *Player, is_pause: bool) errors.MediaKitError!void {
        c.mk_player_pause(self.handle, if (is_pause) 1 else 0);
    }

    /// 设置播放速度
    pub fn setSpeed(self: *Player, speed: f32) errors.MediaKitError!void {
        c.mk_player_speed(self.handle, speed);
    }

    /// 跳转至指定位置播放
    pub fn seekTo(self: *Player, seek_ms: u32) errors.MediaKitError!void {
        c.mk_player_seekto_pos(self.handle, @intCast(seek_ms));
    }

    /// 停止播放
    pub fn stop(self: *Player) void {
        c.mk_player_stop(self.handle);
    }

    /// 释放播放器
    pub fn release(self: *Player) void {
        if (!self.released) {
            c.mk_player_release(self.handle);
            self.released = true;
        }
    }

    /// 获取总时长，单位毫秒
    pub fn getTotalDuration(self: *const Player) u32 {
        return c.mk_player_get_total_duration(self.handle);
    }

    /// 获取当前播放进度，单位毫秒
    pub fn getProgress(self: *const Player) u32 {
        return c.mk_player_get_progress(self.handle);
    }

    /// 获取缓冲进度，单位毫秒
    pub fn getBufferProgress(self: *const Player) u32 {
        return c.mk_player_get_buffer_progress(self.handle);
    }

    /// 获取播放器状态
    pub fn getState(self: *const Player) i32 {
        return c.mk_player_get_state(self.handle);
    }

    /// 视频输出回调函数类型
    pub const OnVideoCallback = *const fn (?*anyopaque, []const u8, i32, i32, i64) void;
    var video_callback: ?OnVideoCallback = null;
    var video_callback_user_data: ?*anyopaque = null;

    /// 设置视频渲染回调
    pub fn setOnVideo(self: *Player, cb: OnVideoCallback, user_data: ?*anyopaque) void {
        video_callback = cb;
        video_callback_user_data = user_data;

        // 转发到C回调
        const c_func = struct {
            pub fn callback(user_data_ptr: ?*anyopaque, data_ptr: ?*anyopaque, len: i32, width_val: i32, height_val: i32, timestamp_val: i64) callconv(.C) void {
                if (video_callback) |callback_fn| {
                    const data_slice = @as([*]const u8, @ptrCast(data_ptr orelse return))[0..@intCast(len)];
                    callback_fn(user_data_ptr, data_slice, width_val, height_val, timestamp_val);
                }
            }
        }.callback;

        c.mk_player_set_on_video(self.handle, c_func, user_data);
    }

    /// 事件回调函数类型
    pub const OnEventCallback = *const fn (?*anyopaque, u8, ?[]const u8, ?[*]c.mk_track, i32) void;
    var event_callback: ?OnEventCallback = null;
    var event_callback_user_data: ?*anyopaque = null;

    /// 设置播放器事件回调
    pub fn setOnEvent(self: *Player, cb: OnEventCallback, user_data: ?*anyopaque) void {
        event_callback = cb;
        event_callback_user_data = user_data;

        // 转发到C回调
        const c_func = struct {
            pub fn callback(user_data_ptr: ?*anyopaque, event_type_val: i32, msg_ptr: ?[*:0]const u8, tracks: [*c]c.mk_track, track_count: i32) callconv(.C) void {
                if (event_callback) |callback_fn| {
                    const event_type = EventType.fromCValue(event_type_val);
                    const msg_slice = if (msg_ptr) |ptr| std.mem.span(ptr) else null;
                    callback_fn(user_data_ptr, event_type, msg_slice, tracks, track_count);
                }
            }
        }.callback;

        c.mk_player_set_on_result(self.handle, c_func, user_data);
    }

    /// 轨道帧输出回调函数类型
    pub const OnFrameOutCallback = *const fn (?*anyopaque, *anyopaque) void;
    var track_frame_callback: ?OnFrameOutCallback = null;
    var track_frame_user_data: ?*anyopaque = null;

    /// 为轨道添加代理，用于接收轨道帧数据
    pub fn trackAddDelegate(track: c.mk_track, cb: OnFrameOutCallback, user_data: ?*anyopaque) ?*anyopaque {
        track_frame_callback = cb;
        track_frame_user_data = user_data;

        const c_func = struct {
            fn callback(ud: ?*anyopaque, frame: c.mk_frame) callconv(.C) void {
                if (track_frame_callback) |callback_fn| {
                    callback_fn(ud, @ptrCast(frame));
                }
            }
        }.callback;

        return c.mk_track_add_delegate(track, c_func, user_data);
    }
};
