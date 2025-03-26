const std = @import("std");
const c = @import("c.zig").c;
pub const errors = @import("errors.zig");

/// ZLMediaKit API
pub const MediaKit = struct {
    /// 日志级别
    pub const LogLevel = struct {
        /// 调试级别
        pub const debug: u8 = 0;
        /// 信息级别
        pub const info: u8 = 1;
        /// 警告级别
        pub const warn: u8 = 2;
        /// 错误级别
        pub const err: u8 = 3;
        /// 禁用日志
        pub const disable: u8 = 4;
    };

    /// 日志输出掩码
    pub const LogMask = struct {
        /// 输出到控制台
        console: bool = true,
        /// 输出到文件
        file: bool = false,
        /// 输出到回调函数
        callback: bool = false,

        /// 转换为C API的掩码
        pub fn toCMask(self: LogMask) c_int {
            var mask: c_int = 0;
            if (self.console) mask |= c.LOG_CONSOLE;
            if (self.file) mask |= c.LOG_FILE;
            if (self.callback) mask |= c.LOG_CALLBACK;
            return mask;
        }
    };

    /// 配置选项
    pub const Config = struct {
        /// 线程数
        thread_num: u32 = 1,
        /// 日志级别
        log_level: u8 = LogLevel.info,
        /// 日志掩码
        log_mask: LogMask = .{},
        /// 日志文件路径
        log_file_path: ?[]const u8 = null,
        /// 日志文件保存天数
        log_file_days: u32 = 7,
        /// 配置文件路径
        ini_path: ?[]const u8 = null,
        /// 是否是文件路径而非内容
        ini_is_path: bool = true,
        /// SSL证书路径
        ssl_path: ?[]const u8 = null,
        /// 是否是文件路径而非内容
        ssl_is_path: bool = true,
        /// SSL证书密码
        ssl_pwd: ?[]const u8 = null,

        /// 转换为C API的配置结构
        pub fn toCConfig(self: Config) c.mk_config {
            return c.mk_config{
                .thread_num = @intCast(self.thread_num),
                .log_level = @intCast(self.log_level),
                .log_mask = self.log_mask.toCMask(),
                .log_file_path = if (self.log_file_path) |path| path.ptr else null,
                .log_file_days = @intCast(self.log_file_days),
                .ini_is_path = if (self.ini_is_path) 1 else 0,
                .ini = if (self.ini_path) |path| path.ptr else null,
                .ssl_is_path = if (self.ssl_is_path) 1 else 0,
                .ssl = if (self.ssl_path) |path| path.ptr else null,
                .ssl_pwd = if (self.ssl_pwd) |pwd| pwd.ptr else null,
            };
        }
    };

    /// 初始化ZLMediaKit环境
    pub fn init(config: Config) void {
        const c_config = config.toCConfig();
        c.mk_env_init(&c_config);
    }

    /// 停止所有服务器
    pub fn stopAllServer() void {
        c.mk_stop_all_server();
    }

    /// 设置日志文件
    pub fn setLogFile(file_max_size: u32, file_max_count: u32) void {
        c.mk_set_log(@intCast(file_max_size), @intCast(file_max_count));
    }

    /// 设置配置项
    pub fn setOption(key: []const u8, val: []const u8) void {
        c.mk_set_option(key.ptr, val.ptr);
    }

    /// 获取配置项
    pub fn getOption(key: []const u8) ?[]const u8 {
        const c_str = c.mk_get_option(key.ptr);
        if (c_str == null) return null;
        return std.mem.span(c_str);
    }

    /// 启动HTTP服务器
    pub fn startHttpServer(port: u16, ssl: bool) errors.MediaKitError!u16 {
        const result = c.mk_http_server_start(port, if (ssl) 1 else 0);
        if (result == 0) {
            return errors.MediaKitError.Failed;
        }
        return result;
    }

    /// 启动RTSP服务器
    pub fn startRtspServer(port: u16, ssl: bool) errors.MediaKitError!u16 {
        const result = c.mk_rtsp_server_start(port, if (ssl) 1 else 0);
        if (result == 0) {
            return errors.MediaKitError.Failed;
        }
        return result;
    }

    /// 启动RTMP服务器
    pub fn startRtmpServer(port: u16, ssl: bool) errors.MediaKitError!u16 {
        const result = c.mk_rtmp_server_start(port, if (ssl) 1 else 0);
        if (result == 0) {
            return errors.MediaKitError.Failed;
        }
        return result;
    }

    /// 启动RTP服务器
    pub fn startRtpServer(port: u16) errors.MediaKitError!u16 {
        const result = c.mk_rtp_server_start(port);
        if (result == 0) {
            return errors.MediaKitError.Failed;
        }
        return result;
    }

    /// 启动RTC服务器
    pub fn startRtcServer(port: u16) errors.MediaKitError!u16 {
        const result = c.mk_rtc_server_start(port);
        if (result == 0) {
            return errors.MediaKitError.Failed;
        }
        return result;
    }

    /// 启动SRT服务器
    pub fn startSrtServer(port: u16) errors.MediaKitError!u16 {
        const result = c.mk_srt_server_start(port);
        if (result == 0) {
            return errors.MediaKitError.Failed;
        }
        return result;
    }

    /// 启动Shell服务器（用于调试）
    pub fn startShellServer(port: u16) errors.MediaKitError!u16 {
        const result = c.mk_shell_server_start(port);
        if (result == 0) {
            return errors.MediaKitError.Failed;
        }
        return result;
    }
};

/// 媒体源管理
pub const Media = @import("media.zig").Media;

/// 播放器管理
pub const Player = @import("player.zig").Player;

/// 推流器管理
pub const Pusher = @import("pusher.zig").Pusher;
