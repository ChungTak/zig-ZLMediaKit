# ZLMediaKit Zig 示例

本目录包含使用Zig语言编写的ZLMediaKit示例代码。

## 示例列表

1. **server.zig** - 媒体服务器示例，展示如何启动各种媒体服务，并处理各种回调事件

## 编译运行

假设您已经安装了Zig编译器，可以使用以下命令编译并运行示例：

```bash
# 编译服务器示例
zig build --target=x86_64-linux-gnu
# 运行示例
sudo LD_LIBRARY_PATH=runtime/lib/x86_64-linux-gnu ./zig-out/bin/server 
```

确保ZLMediaKit的库和头文件路径正确，可能需要调整具体环境的路径。

## 服务器示例说明

服务器示例(`server.zig`)展示了如何：

1. 初始化ZLMediaKit环境
2. 配置和启动各种服务器（HTTP、RTSP、RTMP、SRT等）
3. 处理各种事件回调（流发布、播放、认证等）
4. 优雅地关闭服务

通过这个示例，您可以了解ZLMediaKit的Zig封装API的基本用法。

## 如何使用

启动服务器后，您可以：

1. 推流到服务器：
   - RTMP推流：`rtmp://ip:1935/live/stream_name`
   - RTSP推流：`rtsp://ip:554/live/stream_name`

2. 从服务器播放：
   - RTMP播放：`rtmp://ip:1935/live/stream_name`
   - RTSP播放：`rtsp://ip:554/live/stream_name`
   - HTTP-FLV播放：`http://ip:80/live/stream_name.flv`
   - HLS播放：`http://ip:80/live/stream_name/hls.m3u8`
   - WebRTC播放：通过信令交换

## 注意事项

- 默认开启80（HTTP）、554（RTSP）、1935（RTMP）等端口，可能需要管理员权限
- 如端口被占用，请修改代码中的端口号
- 生产环境中应该配置更安全的认证机制 