// 导出C绑定
pub const c = @import("c.zig").c;

// 导出高级API
pub const zlmediakit = @import("api.zig");

// re-export 主要的类型和常量
pub usingnamespace zlmediakit;
