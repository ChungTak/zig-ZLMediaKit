const std = @import("std");
const c = @import("c.zig").c;
const errors = @import("errors.zig");
const std_mem = std.mem;
const Allocator = std_mem.Allocator;

/// 媒体类型
pub const MediaCodecId = enum(i32) {
    /// H264编码
    h264 = 0,
    /// H265编码
    h265 = 1,
    /// AAC编码
    aac = 2,
    /// G711A编码
    g711a = 3,
    /// G711U编码
    g711u = 4,
    /// OPUS编码
    opus = 5,
};

/// 视频帧类型
pub const FrameType = enum(u8) {
    /// 未知类型
    unknown = 0,
    /// I帧
    i_frame = 1,
    /// P帧
    p_frame = 2,
    /// B帧
    b_frame = 3,
    /// 音频帧
    audio = 4,
    /// 配置帧
    config = 5,
};

/// 媒体源
pub const Media = struct {
    /// 媒体源句柄
    handle: c.mk_media,
    /// 是否已初始化完成
    initialized: bool = false,
    /// 是否已释放
    released: bool = false,

    /// 媒体源参数
    pub const Options = struct {
        /// 虚拟主机名，默认为__defaultVhost__
        vhost: []const u8 = "__defaultVhost__",
        /// 应用名，默认为live
        app: []const u8 = "live",
        /// 流ID，例如camera
        stream: []const u8,
        /// 时长（秒），直播为0
        duration: f32 = 0,
        /// 是否生成HLS
        hls_enabled: bool = false,
        /// 是否生成MP4
        mp4_enabled: bool = false,
    };

    /// 创建媒体源
    pub fn create(options: Options) errors.MediaKitError!Media {
        const handle = c.mk_media_create(
            options.vhost.ptr,
            options.app.ptr,
            options.stream.ptr,
            options.duration,
            if (options.hls_enabled) 1 else 0,
            if (options.mp4_enabled) 1 else 0,
        );
        if (handle == null) {
            return errors.MediaKitError.Failed;
        }
        return Media{
            .handle = handle,
        };
    }

    /// 创建媒体源（带协议选项）
    pub fn createWithOptions(options: Options, protocol_option: ?*c.mk_ini) errors.MediaKitError!Media {
        const handle = c.mk_media_create2(
            options.vhost.ptr,
            options.app.ptr,
            options.stream.ptr,
            options.duration,
            protocol_option orelse null,
        );
        if (handle == null) {
            return errors.MediaKitError.Failed;
        }
        return Media{
            .handle = handle,
        };
    }

    /// 释放媒体源
    pub fn release(self: *Media) void {
        if (!self.released) {
            c.mk_media_release(self.handle);
            self.released = true;
        }
    }

    /// 视频参数
    pub const VideoOptions = struct {
        /// 编码类型
        codec_id: MediaCodecId = .h264,
        /// 视频宽度
        width: u32,
        /// 视频高度
        height: u32,
        /// 帧率
        fps: f32 = 25,
        /// 比特率（bps）
        bit_rate: u32 = 4000000,
    };

    /// 初始化视频轨道
    pub fn initVideo(self: *Media, options: VideoOptions) errors.MediaKitError!void {
        const ret = c.mk_media_init_video(
            self.handle,
            @intFromEnum(options.codec_id),
            @intCast(options.width),
            @intCast(options.height),
            options.fps,
            @intCast(options.bit_rate),
        );
        if (ret == 0) {
            return errors.MediaKitError.Failed;
        }
    }

    /// 音频参数
    pub const AudioOptions = struct {
        /// 编码类型
        codec_id: MediaCodecId = .aac,
        /// 采样率
        sample_rate: u32 = 44100,
        /// 通道数
        channels: u32 = 2,
        /// 采样位数
        sample_bit: u32 = 16,
    };

    /// 初始化音频轨道
    pub fn initAudio(self: *Media, options: AudioOptions) errors.MediaKitError!void {
        const ret = c.mk_media_init_audio(
            self.handle,
            @intFromEnum(options.codec_id),
            @intCast(options.sample_rate),
            @intCast(options.channels),
            @intCast(options.sample_bit),
        );
        if (ret == 0) {
            return errors.MediaKitError.Failed;
        }
    }

    /// 初始化完成
    pub fn initComplete(self: *Media) void {
        c.mk_media_init_complete(self.handle);
        self.initialized = true;
    }

    /// 输入H264视频帧
    pub fn inputH264(self: *Media, data: []const u8, dts: u64, pts: u64) errors.MediaKitError!void {
        const ret = c.mk_media_input_h264(
            self.handle,
            data.ptr,
            @intCast(data.len),
            dts,
            pts,
        );
        if (ret == 0) {
            return errors.MediaKitError.Failed;
        }
    }

    /// 输入H265视频帧
    pub fn inputH265(self: *Media, data: []const u8, dts: u64, pts: u64) errors.MediaKitError!void {
        const ret = c.mk_media_input_h265(
            self.handle,
            data.ptr,
            @intCast(data.len),
            dts,
            pts,
        );
        if (ret == 0) {
            return errors.MediaKitError.Failed;
        }
    }

    /// 输入YUV视频帧
    pub fn inputYuv(self: *Media, yuv: [3][]const u8, linesize: [3]i32, cts: u64) void {
        var yuv_ptrs: [3]*const u8 = undefined;
        for (0..3) |i| {
            yuv_ptrs[i] = yuv[i].ptr;
        }
        c.mk_media_input_yuv(
            self.handle,
            &yuv_ptrs,
            &linesize,
            cts,
        );
    }

    /// 输入AAC音频帧
    pub fn inputAac(self: *Media, data: []const u8, dts: u64, adts: ?*anyopaque) errors.MediaKitError!void {
        const ret = c.mk_media_input_aac(
            self.handle,
            data.ptr,
            @intCast(data.len),
            dts,
            adts,
        );
        if (ret == 0) {
            return errors.MediaKitError.Failed;
        }
    }

    /// 输入PCM音频帧
    pub fn inputPcm(self: *Media, data: []const u8, pts: u64) errors.MediaKitError!void {
        const ret = c.mk_media_input_pcm(
            self.handle,
            @constCast(data.ptr),
            @intCast(data.len),
            pts,
        );
        if (ret == 0) {
            return errors.MediaKitError.Failed;
        }
    }

    /// 输入一般音频帧
    pub fn inputAudio(self: *Media, data: []const u8, dts: u64) errors.MediaKitError!void {
        const ret = c.mk_media_input_audio(
            self.handle,
            data.ptr,
            @intCast(data.len),
            dts,
        );
        if (ret == 0) {
            return errors.MediaKitError.Failed;
        }
    }

    /// 初始化轨道
    pub fn initTrack(self: *Media, track: c.mk_track) errors.MediaKitError!void {
        c.mk_media_init_track(self.handle, track);
    }

    /// 输入媒体帧
    pub fn inputFrame(self: *Media, frame: *anyopaque) errors.MediaKitError!void {
        const ret = c.mk_media_input_frame(self.handle, @ptrCast(frame));
        if (ret == 0) {
            return errors.MediaKitError.Failed;
        }
    }

    /// 媒体源注册/注销事件回调函数类型
    pub const OnRegistFunc = *const fn (?*anyopaque, *anyopaque, bool) void;
    var media_regist_callback: ?OnRegistFunc = null;
    var media_regist_user_data: ?*anyopaque = null;

    /// 设置媒体源注册/注销事件回调
    pub fn setOnRegist(self: *Media, callback: OnRegistFunc, user_data: ?*anyopaque) void {
        media_regist_callback = callback;
        media_regist_user_data = user_data;

        const cb: c.on_mk_media_source_regist = struct {
            fn cb(ud: ?*anyopaque, sender: c.mk_media_source, regist: c_int) callconv(.C) void {
                if (media_regist_callback) |callback_fn| {
                    callback_fn(ud, @ptrCast(sender), regist != 0);
                }
            }
        }.cb;

        c.mk_media_set_on_regist(self.handle, cb, user_data);
    }

    /// 获取当前总订阅人数
    pub fn totalReaderCount(self: *const Media) i32 {
        return c.mk_media_total_reader_count(self.handle);
    }

    /// 开始发送RTP流
    pub fn startSendRtp(self: *Media, dst_url: []const u8, dst_port: u16, ssrc: []const u8, is_tcp: bool) errors.MediaKitError!void {
        // 这是一个简化版本，不包含回调处理
        c.mk_media_start_send_rtp(
            self.handle,
            dst_url.ptr,
            dst_port,
            ssrc.ptr,
            if (is_tcp) 1 else 0,
            null, // 回调函数
            null, // 用户数据
        );
    }

    /// 停止发送RTP流
    pub fn stopSendRtp(self: *Media, ssrc: []const u8) void {
        c.mk_media_stop_send_rtp(self.handle, ssrc.ptr);
    }
};
