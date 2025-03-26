const std = @import("std");
const c = @import("c.zig").c;

/// ZLMediaKit错误类型
pub const MediaKitError = error{
    Failed,
    NoMem,
    Timeout,
    InvalidParam,
    InvalidState,
    NotFound,
    NotSupport,
    NotImplemented,
    OperationFailed,
    ServerError,
    NetworkError,
    FileError,
    DeviceError,
    ResourceNotFound,
    StreamNotFound,
    Unauthorized,
    MediaError,
    EncoderError,
    DecoderError,
    ConnectionError,
    InternalError,
    UnsupportedFormat,
    UnsupportedCodec,
    UnknownError,
};

/// 将C API错误码转换为Zig错误
pub fn mapMediaKitError(err_code: c_int) MediaKitError!void {
    if (err_code == 0) {
        return;
    }

    // ZLMediaKit大多数函数返回0表示成功，其他表示失败
    // 我们根据错误码返回对应的错误类型
    return switch (err_code) {
        -1 => MediaKitError.Failed,
        -2 => MediaKitError.NoMem,
        -3 => MediaKitError.Timeout,
        -4 => MediaKitError.InvalidParam,
        -5 => MediaKitError.InvalidState,
        -6 => MediaKitError.NotFound,
        -7 => MediaKitError.NotSupport,
        -8 => MediaKitError.NotImplemented,
        else => MediaKitError.UnknownError,
    };
}

/// 获取错误描述
pub fn getErrorDescription(err: MediaKitError) []const u8 {
    return switch (err) {
        MediaKitError.Failed => "操作失败",
        MediaKitError.NoMem => "内存不足",
        MediaKitError.Timeout => "操作超时",
        MediaKitError.InvalidParam => "参数无效",
        MediaKitError.InvalidState => "状态无效",
        MediaKitError.NotFound => "未找到",
        MediaKitError.NotSupport => "不支持",
        MediaKitError.NotImplemented => "功能未实现",
        MediaKitError.OperationFailed => "操作失败",
        MediaKitError.ServerError => "服务器错误",
        MediaKitError.NetworkError => "网络错误",
        MediaKitError.FileError => "文件错误",
        MediaKitError.DeviceError => "设备错误",
        MediaKitError.ResourceNotFound => "资源未找到",
        MediaKitError.StreamNotFound => "流未找到",
        MediaKitError.Unauthorized => "未授权",
        MediaKitError.MediaError => "媒体错误",
        MediaKitError.EncoderError => "编码器错误",
        MediaKitError.DecoderError => "解码器错误",
        MediaKitError.ConnectionError => "连接错误",
        MediaKitError.InternalError => "内部错误",
        MediaKitError.UnsupportedFormat => "不支持的格式",
        MediaKitError.UnsupportedCodec => "不支持的编解码器",
        MediaKitError.UnknownError => "未知错误",
    };
}
