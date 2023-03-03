const std = @import("std");
const zls = @import("zls");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var config = zls.Config{};
    var version: ?zls.ZigVersionWrapper = null;

    try zls.configuration.configChanged(&config, &version, allocator, null);

    var server = try zls.Server.create(allocator, &config, null, false, false);
    server.offset_encoding = .@"utf-8";
    defer server.destroy();

    const bs_uri = try allocator.dupe(u8, "file:///C:/Programming/Zig/zls-as-lib-demo/src/bs.zig");
    _ = try server.document_store.openDocument(bs_uri,
        \\const std = @import("std");
        \\const zls = @import("zls");
        \\
        \\pub fn neverGonnaGiveYouUpNeverGonnaLetYouDown() {
        \\    zls.
        \\}
    );

    var inbuf: [1024]u8 = undefined;
    while (true) {
        var bruh = std.heap.ArenaAllocator.init(allocator);
        defer bruh.deinit();
        server.arena = &bruh;

        var stdio = std.io.getStdIn().reader();

        const input = try stdio.readUntilDelimiter(&inbuf, '\n');
        try server.document_store.refreshDocument(bs_uri, try std.fmt.allocPrintZ(allocator,
            \\const std = @import("std");
            \\const zls = @import("zls");
            \\
            \\pub fn neverGonnaGiveYouUpNeverGonnaLetYouDown() {{
            \\    {s}
            \\}}
        , .{input}));

        const completions: []const zls.types.CompletionItem = (try server.completionHandler(.{
            .textDocument = .{
                .uri = "file:///C:/Programming/Zig/zls-as-lib-demo/src/bs.zig",
            },
            .position = .{
                .line = 4,
                .character = @intCast(u32, 4 + input.len),
            },
        }) orelse zls.types.CompletionList{ .isIncomplete = true, .items = &.{} }).items;

        for (completions) |comp| {
            try std.io.getStdOut().writer().print("    {s}\n", .{comp.label});
        }
    }
}
