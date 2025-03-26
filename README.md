# Zig-ZLMediaKit

这是一个使用Zig语言对[ZLMediaKit](https://github.com/ZLMediaKit/ZLMediaKit)的封装库，提供了友好的Zig API接口和原始C绑定。

## 版本要求

- Zig版本: 0.14.0
- 依赖库: libmk_api.so

## 预编译库

项目已包含以下主流系统的预编译库:
- aarch64-linux-gnu
- x86_64-linux-gnu
- x86_64-windows-gnu

需要更多平台的库文件，请访问 [ZLMediaKit Releases](https://github.com/ChungTak/ZLMediaKit/releases) 下载。

## 安装

通过Zig包管理器安装:

```bash
# 添加依赖到你的项目
zig fetch --save git+https://github.com/ChungTak/zig-ZLMediaKit
```

或者在你的`build.zig.zon`中手动添加依赖:

```zig
.dependencies = .{
    .zig_ZLMediaKit = .{
        .url = "git+https://github.com/ChungTak/zig-ZLMediaKit",
        .hash = "...", // 使用zig fetch获取正确的hash
    },
},
```

## 编译

项目通过环境变量`ZLMEDIAKIT_LIBRARIES`指定libmk_api.so的路径:

```bash
# 示例: 指定自定义库路径
ZLMEDIAKIT_LIBRARIES=/path/to/your/libraries zig build
```

如果未设置环境变量，将使用项目内置的库(根据目标平台自动选择)。


### 指定平台和架构

在构建时，可以指定目标平台和架构：

```bash
# Linux + x86_64 (默认)
zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseSafe
# windows + x86_64 (mingw)
zig build -Dtarget=x86_64-windows-gnu
# Linux + aarch64
zig build -Dtarget=aarch64-linux-gnu
# Linux + armhf 32bit
zig build -Dtarget=arm-linux-gnueabihf
# Linux + riscv64-linux-gnu
zig build -Dtarget=riscv64-linux-gnu
# Android + arm64-v8a
zig build -Dtarget=aarch64-linux-android
# Android + armeabi-v7a 32bit
zig build -Dtarget=arm-linux-androi
# macos
zig build -Dtarget=x86_64-macos
zig build -Dtarget=aarch64-macos

```

## 使用方法

### Zig高级封装API

```zig
const std = @import("std");
const zlm = @import("zlmediakit");

pub fn main() !void {
    // 初始化ZLMediaKit环境
    zlm.MediaKit.init(.{
        .thread_num = 1,
        .log_level = zlm.MediaKit.LogLevel.debug,
        .log_mask = .{ .console = true },
    });

    // 启动RTSP服务器
    _ = try zlm.MediaKit.startRtspServer(554, false);

    // 创建播放器
    var player = try zlm.Player.create(.{
        .url = "rtsp://example.com/live/test",
        .enable_audio = true,
        .enable_video = true,
    });
    defer player.release();

    // 更多代码...
    
    // 停止所有服务器
    zlm.MediaKit.stopAllServer();
}
```

### 使用原始C绑定

```zig
const std = @import("std");
const c = @import("zlmediakit").c;

pub fn main() !void {
    // 初始化ZLMediaKit
    c.mk_env_init(1, 4);
    
    // 启动RTSP服务器
    c.mk_rtsp_server_start(554, false);
    
    // 更多底层C API调用...
    
    // 停止服务并清理资源
    c.mk_stop_all_server();
}
```

## 示例

项目包含多个功能示例，位于`src/examples`目录:

- **server.zig**: 完整的流媒体服务器示例
- **pusher.zig**: 推流示例

编译并运行示例:

```bash
# 编译server示例
zig build -Dtarget=x86_64-linux-gnu 

# 运行server示例
LD_LIBRARY_PATH=runtime/lib/x86_64-linux-gnu ./zig-out/bin/server
```

## 文档

更多详细API文档，请参考源代码中的注释和`src/examples`目录中的示例。

## 许可证

本项目遵循与ZLMediaKit相同的许可证。

## 贡献

欢迎提交问题报告和Pull Requests。 