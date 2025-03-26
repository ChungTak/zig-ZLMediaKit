const std = @import("std");
const zlm = @import("zlmediakit");
const c = zlm.c;
const MediaKit = zlm.MediaKit;
const errors = zlm.errors;

/// 日志级别
const LOG_LEV: u8 = 4;

/// 打印日志
fn logPrint(comptime format: []const u8, args: anytype) void {
    std.debug.print(format ++ "\n", args);
}

/// 注册或反注册MediaSource事件广播
fn onMediaChanged(regist: i32, sender: c.mk_media_source) callconv(.C) void {
    logPrint("[媒体变化] {d} {s}/{s}/{s}/{s}", .{
        regist,
        std.mem.span(c.mk_media_source_get_schema(sender)),
        std.mem.span(c.mk_media_source_get_vhost(sender)),
        std.mem.span(c.mk_media_source_get_app(sender)),
        std.mem.span(c.mk_media_source_get_stream(sender)),
    });
}

/// 收到rtsp/rtmp推流事件广播，通过该事件控制推流鉴权
fn onMediaPublish(url_info: c.mk_media_info, invoker: c.mk_publish_auth_invoker, sender: c.mk_sock_info) callconv(.C) void {
    var ip: [64]u8 = undefined;
    logPrint(
        \\[推流] 客户端信息, 本地: {s}:{d}, 对端: {s}:{d}
        \\{s}/{s}/{s}/{s}, url参数: {s}
    , .{
        std.mem.span(c.mk_sock_info_local_ip(sender, &ip[0])),
        c.mk_sock_info_local_port(sender),
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip[32])),
        c.mk_sock_info_peer_port(sender),
        std.mem.span(c.mk_media_info_get_schema(url_info)),
        std.mem.span(c.mk_media_info_get_vhost(url_info)),
        std.mem.span(c.mk_media_info_get_app(url_info)),
        std.mem.span(c.mk_media_info_get_stream(url_info)),
        std.mem.span(c.mk_media_info_get_params(url_info)),
    });

    // 允许推流，并且允许转hls/mp4
    c.mk_publish_auth_invoker_do(invoker, null, 1, 1);
}

/// 播放rtsp/rtmp/http-flv/hls事件广播，通过该事件控制播放鉴权
fn onMediaPlay(url_info: c.mk_media_info, invoker: c.mk_auth_invoker, sender: c.mk_sock_info) callconv(.C) void {
    var ip: [64]u8 = undefined;
    logPrint(
        \\[播放] 客户端信息, 本地: {s}:{d}, 对端: {s}:{d}
        \\{s}/{s}/{s}/{s}, url参数: {s}
    , .{
        std.mem.span(c.mk_sock_info_local_ip(sender, &ip[0])),
        c.mk_sock_info_local_port(sender),
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip[32])),
        c.mk_sock_info_peer_port(sender),
        std.mem.span(c.mk_media_info_get_schema(url_info)),
        std.mem.span(c.mk_media_info_get_vhost(url_info)),
        std.mem.span(c.mk_media_info_get_app(url_info)),
        std.mem.span(c.mk_media_info_get_stream(url_info)),
        std.mem.span(c.mk_media_info_get_params(url_info)),
    });

    // 允许播放
    c.mk_auth_invoker_do(invoker, null);
}

/// 未找到流后会广播该事件，请在监听该事件后去拉流或其他方式产生流，这样就能按需拉流了
fn onMediaNotFound(url_info: c.mk_media_info, sender: c.mk_sock_info) callconv(.C) i32 {
    var ip: [64]u8 = undefined;
    logPrint(
        \\[未找到流] 客户端信息, 本地: {s}:{d}, 对端: {s}:{d}
        \\{s}/{s}/{s}/{s}, url参数: {s}
    , .{
        std.mem.span(c.mk_sock_info_local_ip(sender, &ip[0])),
        c.mk_sock_info_local_port(sender),
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip[32])),
        c.mk_sock_info_peer_port(sender),
        std.mem.span(c.mk_media_info_get_schema(url_info)),
        std.mem.span(c.mk_media_info_get_vhost(url_info)),
        std.mem.span(c.mk_media_info_get_app(url_info)),
        std.mem.span(c.mk_media_info_get_stream(url_info)),
        std.mem.span(c.mk_media_info_get_params(url_info)),
    });
    return 0; // 等待流注册
}

/// 某个流无人消费时触发，目的为了实现无人观看时主动断开拉流等业务逻辑
fn onMediaNoReader(sender: c.mk_media_source) callconv(.C) void {
    logPrint("[无消费] {s}/{s}/{s}/{s}", .{
        std.mem.span(c.mk_media_source_get_schema(sender)),
        std.mem.span(c.mk_media_source_get_vhost(sender)),
        std.mem.span(c.mk_media_source_get_app(sender)),
        std.mem.span(c.mk_media_source_get_stream(sender)),
    });
}

/// 流量统计回调
fn onFlowReport(url_info: c.mk_media_info, total_bytes: usize, total_seconds: usize, is_player: i32, sender: c.mk_sock_info) callconv(.C) void {
    var ip: [64]u8 = undefined;
    logPrint("[流量统计] {s}/{s}/{s}/{s}, url参数: {s}, 总字节: {d}, 总秒数: {d}, 是否播放器: {d}, 对端IP: {s}, 对端端口: {d}", .{
        std.mem.span(c.mk_media_info_get_schema(url_info)),
        std.mem.span(c.mk_media_info_get_vhost(url_info)),
        std.mem.span(c.mk_media_info_get_app(url_info)),
        std.mem.span(c.mk_media_info_get_stream(url_info)),
        std.mem.span(c.mk_media_info_get_params(url_info)),
        total_bytes,
        total_seconds,
        is_player,
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip)),
        c.mk_sock_info_peer_port(sender),
    });
}

/// 收到http api请求广播
fn onHttpRequest(parser: c.mk_parser, invoker: c.mk_http_response_invoker, consumed: [*c]c_int, sender: c.mk_sock_info) callconv(.C) void {
    // 简化实现，只记录请求
    var ip: [64]u8 = undefined;
    _ = parser; // 未使用参数
    _ = invoker; // 未使用参数
    _ = consumed; // 未使用参数
    logPrint("[HTTP请求] 客户端: {s}:{d}", .{
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip)),
        c.mk_sock_info_peer_port(sender),
    });
}

/// HTTP访问文件和目录事件
fn onHttpAccess(parser: c.mk_parser, path: [*c]const u8, is_dir: i32, invoker: c.mk_http_access_path_invoker, sender: c.mk_sock_info) callconv(.C) void {
    var ip: [64]u8 = undefined;
    _ = parser; // 未使用参数
    logPrint("[HTTP访问] 路径: {s}, 是否目录: {d}, 客户端: {s}:{d}", .{
        std.mem.span(path),
        is_dir,
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip)),
        c.mk_sock_info_peer_port(sender),
    });

    // 允许访问
    c.mk_http_access_path_invoker_do(invoker, null, null, 0);
}

/// HTTP访问文件和目录前的拦截事件
fn onHttpBeforeAccess(parser: c.mk_parser, path: [*c]u8, sender: c.mk_sock_info) callconv(.C) void {
    var ip: [64]u8 = undefined;
    _ = parser; // 未使用参数
    logPrint("[HTTP前置访问] 路径: {s}, 客户端: {s}:{d}", .{
        std.mem.span(path),
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip)),
        c.mk_sock_info_peer_port(sender),
    });
}

/// 获取rtsp专有鉴权信息事件
fn onRtspGetRealm(url_info: c.mk_media_info, invoker: c.mk_rtsp_get_realm_invoker, sender: c.mk_sock_info) callconv(.C) void {
    var ip: [64]u8 = undefined;
    logPrint("[RTSP获取Realm] {s}/{s}/{s}/{s}, 客户端: {s}:{d}", .{
        std.mem.span(c.mk_media_info_get_schema(url_info)),
        std.mem.span(c.mk_media_info_get_vhost(url_info)),
        std.mem.span(c.mk_media_info_get_app(url_info)),
        std.mem.span(c.mk_media_info_get_stream(url_info)),
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip)),
        c.mk_sock_info_peer_port(sender),
    });

    // 使用默认realm
    c.mk_rtsp_get_realm_invoker_do(invoker, "ZLMediaKit");
}

/// RTSP鉴权事件
fn onRtspAuth(url_info: c.mk_media_info, realm: [*c]const u8, user_name: [*c]const u8, must_no_encrypt: i32, invoker: c.mk_rtsp_auth_invoker, sender: c.mk_sock_info) callconv(.C) void {
    var ip: [64]u8 = undefined;
    _ = must_no_encrypt; // 未使用参数
    logPrint("[RTSP鉴权] {s}/{s}/{s}/{s}, Realm: {s}, 用户名: {s}, 客户端: {s}:{d}", .{
        std.mem.span(c.mk_media_info_get_schema(url_info)),
        std.mem.span(c.mk_media_info_get_vhost(url_info)),
        std.mem.span(c.mk_media_info_get_app(url_info)),
        std.mem.span(c.mk_media_info_get_stream(url_info)),
        std.mem.span(realm),
        std.mem.span(user_name),
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip)),
        c.mk_sock_info_peer_port(sender),
    });

    // 允许任何鉴权，第一个参数0表示不加密，第二个参数为密码
    c.mk_rtsp_auth_invoker_do(invoker, 0, null);
}

/// 录制MP4完成后通知事件
fn onRecordMp4(mp4_info: c.mk_record_info) callconv(.C) void {
    // 计算结束时间 = 开始时间 + 时长
    const start_time = c.mk_record_info_get_start_time(mp4_info);
    const time_len = c.mk_record_info_get_time_len(mp4_info);
    const end_time = start_time + @as(u64, @intFromFloat(time_len));

    logPrint("[MP4录制] 路径: {s}, 应用: {s}, 流ID: {s}, 文件夹: {s}, 文件名: {s}, 开始时间: {d}, 结束时间: {d}, 时长(秒): {d}, 文件大小: {d}", .{
        std.mem.span(c.mk_record_info_get_vhost(mp4_info)),
        std.mem.span(c.mk_record_info_get_app(mp4_info)),
        std.mem.span(c.mk_record_info_get_stream(mp4_info)),
        std.mem.span(c.mk_record_info_get_folder(mp4_info)),
        std.mem.span(c.mk_record_info_get_file_name(mp4_info)),
        start_time,
        end_time,
        time_len,
        c.mk_record_info_get_file_size(mp4_info),
    });
}

/// shell登录鉴权事件
fn onShellLogin(user_name: [*c]const u8, passwd: [*c]const u8, invoker: c.mk_auth_invoker, sender: c.mk_sock_info) callconv(.C) void {
    var ip: [64]u8 = undefined;
    logPrint("[Shell登录] 用户名: {s}, 密码: {s}, 客户端: {s}:{d}", .{
        std.mem.span(user_name),
        std.mem.span(passwd),
        std.mem.span(c.mk_sock_info_peer_ip(sender, &ip)),
        c.mk_sock_info_peer_port(sender),
    });

    // 校验用户名密码
    if (std.mem.eql(u8, std.mem.span(user_name), "admin") and std.mem.eql(u8, std.mem.span(passwd), "123456")) {
        // 允许登录
        c.mk_auth_invoker_do(invoker, null);
    } else {
        // 不允许登录
        c.mk_auth_invoker_do(invoker, "用户名或密码错误");
    }
}

pub fn main() !void {
    // 打印版本信息 (省略，API版本宏未定义)
    std.debug.print("ZLMediaKit Zig示例服务器启动\n", .{});

    // 配置服务器
    const config = MediaKit.Config{
        .thread_num = 1,
        .log_level = MediaKit.LogLevel.debug,
        .log_mask = .{
            .console = true,
            .file = false,
            .callback = false,
        },
        .log_file_path = null,
        .log_file_days = 7,
        .ini_path = null,
        .ini_is_path = true,
        .ssl_path = null,
        .ssl_is_path = true,
        .ssl_pwd = null,
    };

    // 初始化环境
    MediaKit.init(config);

    // 启动各种服务器
    _ = try MediaKit.startHttpServer(80, false);
    _ = try MediaKit.startHttpServer(443, true);
    _ = try MediaKit.startRtspServer(554, false);
    _ = try MediaKit.startRtmpServer(1935, false);
    _ = try MediaKit.startShellServer(9000);
    _ = try MediaKit.startRtpServer(10000);
    // _ = try MediaKit.startRtcServer(8000); // enable when need compile webrtc
    _ = try MediaKit.startSrtServer(9000);

    // 注册事件回调
    var events = std.mem.zeroes(c.mk_events);
    events.on_mk_media_changed = onMediaChanged;
    events.on_mk_media_publish = onMediaPublish;
    events.on_mk_media_play = onMediaPlay;
    events.on_mk_media_not_found = onMediaNotFound;
    events.on_mk_media_no_reader = onMediaNoReader;
    events.on_mk_http_request = onHttpRequest;
    events.on_mk_http_access = onHttpAccess;
    events.on_mk_http_before_access = onHttpBeforeAccess;
    events.on_mk_rtsp_get_realm = onRtspGetRealm;
    events.on_mk_rtsp_auth = onRtspAuth;
    events.on_mk_record_mp4 = onRecordMp4;
    events.on_mk_shell_login = onShellLogin;
    events.on_mk_flow_report = onFlowReport;
    c.mk_events_listen(&events);

    // 打印启动成功信息
    std.debug.print("媒体服务器已启动!\n", .{});
    std.debug.print("按任意键退出...\n", .{});

    // 等待用户输入
    _ = try std.io.getStdIn().reader().readByte();

    // 停止所有服务器
    MediaKit.stopAllServer();
    std.debug.print("媒体服务器已停止!\n", .{});
}
