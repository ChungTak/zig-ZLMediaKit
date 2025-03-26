const std = @import("std");
const zlm = @import("zlmediakit");
const c = zlm.c;
const MediaKit = zlm.MediaKit;
const Player = zlm.Player;
const Media = zlm.Media;
const Pusher = zlm.Pusher;
const errors = zlm.errors;

/// 上下文结构，保存播放器、媒体和推流器
const Context = struct {
    /// 播放器实例
    player: ?Player = null,
    /// 媒体实例
    media: ?Media = null,
    /// 推流器实例
    pusher: ?Pusher = null,
    /// 推流地址
    push_url: [1024]u8 = [_]u8{0} ** 1024,
    /// 分配器
    allocator: std.mem.Allocator,

    /// 释放资源
    pub fn deinit(self: *Context) void {
        if (self.pusher) |*pusher| {
            pusher.release();
            self.pusher = null;
        }
        if (self.media) |*media| {
            media.release();
            self.media = null;
        }
        if (self.player) |*player| {
            player.release();
            self.player = null;
        }
    }
};

/// 播放器上下文
var global_ctx: ?Context = null;

/// 推流事件回调
fn onPushEvent(user_data: ?*anyopaque, event_type: u8, msg: ?[]const u8) void {
    const ctx = @as(*Context, @ptrCast(@alignCast(user_data orelse return)));
    const push_url = std.mem.sliceTo(&ctx.push_url, 0);

    if (event_type == Pusher.EventType.success) {
        std.debug.print("推流 {s} 成功!\n", .{push_url});
    } else {
        std.debug.print("推流 {s} 失败: {s}\n", .{ push_url, msg orelse "未知错误" });
        if (ctx.pusher) |*pusher| {
            pusher.release();
            ctx.pusher = null;
        }
    }
}

/// 媒体源注册事件回调
fn onMediaSourceRegist(user_data: ?*anyopaque, sender: *anyopaque, regist: bool) void {
    const ctx = @as(*Context, @ptrCast(@alignCast(user_data orelse return)));

    // 忽略 sender 参数，因为当前实现不需要使用它
    _ = sender;

    // 释放旧的推流器
    if (ctx.pusher) |*pusher| {
        pusher.release();
        ctx.pusher = null;
    }

    if (regist) {
        // 创建新的推流器
        const push_url = std.mem.sliceTo(&ctx.push_url, 0);

        // 使用合适的媒体源创建推流器
        ctx.pusher = Pusher.create("__defaultVhost__/live/test", .{
            .url = push_url,
            .timeout_ms = 10000,
            .retry_count = 3,
        }) catch {
            std.debug.print("创建推流器失败\n", .{});
            return;
        };

        // 设置推流器事件回调
        if (ctx.pusher) |*pusher| {
            pusher.setOnEvent(onPushEvent, user_data);
            _ = pusher.start() catch {
                std.debug.print("启动推流器失败\n", .{});
                return;
            };
        }
    } else {
        std.debug.print("推流停止!\n", .{});
    }
}

/// 轨道帧输出回调
fn onTrackFrameOut(user_data: ?*anyopaque, frame: *anyopaque) void {
    const ctx = @as(*Context, @ptrCast(@alignCast(user_data orelse return)));

    // 将帧数据输入到媒体源
    if (ctx.media) |*media| {
        // 将frame转换为zlmediakit的帧结构，并输入到媒体源
        media.inputFrame(frame) catch |err| {
            std.debug.print("输入帧数据失败: {any}\n", .{err});
        };
    }
}

/// 播放事件回调
fn onPlayEvent(user_data: ?*anyopaque, event_type: u8, msg: ?[]const u8, tracks: ?[*]c.mk_track, track_count: i32) void {
    const ctx = @as(*Context, @ptrCast(@alignCast(user_data orelse return)));

    // 释放旧的媒体源和推流器
    if (ctx.media) |*media| {
        media.release();
        ctx.media = null;
    }

    if (ctx.pusher) |*pusher| {
        pusher.release();
        ctx.pusher = null;
    }

    if (event_type == Player.EventType.ready) {
        std.debug.print("播放成功!\n", .{});

        // 创建媒体源
        ctx.media = Media.create(.{
            .vhost = "__defaultVhost__",
            .app = "live",
            .stream = "test",
            .duration = 0,
        }) catch {
            std.debug.print("创建媒体源失败\n", .{});
            return;
        };

        // 初始化轨道并设置代理
        if (tracks != null and track_count > 0) {
            var i: u32 = 0;
            while (i < track_count) : (i += 1) {
                const track = tracks.?[@intCast(i)];
                if (ctx.media) |*media| {
                    // 初始化媒体轨道
                    media.initTrack(track) catch {
                        std.debug.print("初始化轨道失败\n", .{});
                        continue;
                    };

                    // 设置轨道帧输出回调
                    _ = Player.trackAddDelegate(track, onTrackFrameOut, user_data);
                }
            }
        }

        if (ctx.media) |*media| {
            // 初始化完成
            media.initComplete();

            // 设置媒体源注册回调
            media.setOnRegist(onMediaSourceRegist, user_data);
        }
    } else {
        std.debug.print("播放失败: {s}\n", .{msg orelse "未知错误"});
    }
}

/// 开始播放和推流
fn contextStart(ctx: *Context, url_pull: []const u8, url_push: []const u8) !void {
    // 释放旧的播放器
    if (ctx.player) |*player| {
        player.release();
        ctx.player = null;
    }

    // 创建新的播放器
    ctx.player = try Player.create(.{
        .url = url_pull,
        .max_buffer_ms = 3000,
        .enable_audio = true,
        .enable_video = true,
    });

    if (ctx.player) |*player| {
        // 设置播放器事件回调
        player.setOnEvent(onPlayEvent, ctx);

        // 开始播放
        try player.play(url_pull);
    }

    // 保存推流地址
    const len = @min(url_push.len, ctx.push_url.len - 1);
    std.mem.copyForwards(u8, ctx.push_url[0..len], url_push[0..len]);
    ctx.push_url[len] = 0;
}

pub fn main() !void {
    // 命令行参数
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len != 3) {
        std.debug.print("用法: ./pusher pull_url push_url\n", .{});
        return error.InvalidArguments;
    }

    // 初始化ZLMediaKit环境
    MediaKit.init(.{
        .thread_num = 1,
        .log_level = MediaKit.LogLevel.debug,
        .log_mask = .{ .console = true },
    });

    // 启动服务器
    _ = try MediaKit.startRtspServer(8554, false);
    _ = try MediaKit.startRtmpServer(1935, false);

    // 创建上下文
    global_ctx = Context{
        .allocator = gpa,
    };

    if (global_ctx) |*ctx| {
        // 开始播放和推流
        try contextStart(ctx, args[1], args[2]);

        std.debug.print("按任意键退出...\n", .{});
        _ = try std.io.getStdIn().reader().readByte();

        // 清理资源
        ctx.deinit();
    }

    // 停止所有服务器
    MediaKit.stopAllServer();
}
