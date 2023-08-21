const std = @import("std");
const zls = @import("zls");

pub const std_options = struct {
    pub const log_level = .debug;

    pub fn logFn(
        comptime level: std.log.Level,
        comptime scope: @TypeOf(.EnumLiteral),
        comptime format: []const u8,
        args: anytype,
    ) void {
        if (comptime std.mem.startsWith(u8, @tagName(scope), "zls_")) return;
        std.log.defaultLog(level, scope, format, args);
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // We start by initing a config and zig version
    // wrapper which determines what features
    // zls can safely use
    var config = zls.Config{};
    var version: ?zls.ZigVersionWrapper = null;

    // Running configChanged on start is required
    // to populate the config options
    try zls.configuration.configChanged(&config, &version, allocator, null);

    // Create a server, then set its encoding
    // to utf-8 so we can use the same indices
    // as a normal zig []const u8
    var server = try zls.Server.create(allocator, &config, null);
    server.offset_encoding = .@"utf-8";
    defer server.destroy();

    // We open a BS document with an absolute path
    // which is currently required; the text is empty
    // as we're going to refresh it anyways
    const bs_uri = try allocator.dupe(u8, "file:///C:/Programming/Zig/zls-as-lib-demo/src/bs.zig");
    // NOTE: This function takes ownership of the input `text`
    _ = try server.document_store.openDocument(bs_uri, try allocator.dupeZ(u8, ""));

    try std.io.getStdOut().writer().writeAll("Enter an input for completion below: (Try `std.` and `zls.`)\n");

    var input_buf: [1024]u8 = undefined;
    while (true) {
        // Free the server arena if it's past
        // a certain threshold
        //defer server.maybeFreeArena();

        var stdio = std.io.getStdIn().reader();
        const input = stdio.readUntilDelimiterOrEof(&input_buf, '\n') catch |err| switch (err) {
            error.StreamTooLong => {
                std.debug.print("Input too long (max length is 1024 bytes)", .{});
                return err;
            },
            else => return err,
        } orelse return;

        // We replace the content of the document with our input in the right context
        // NOTE: This function takes ownership of the input `text`
        try server.document_store.refreshDocument(bs_uri, try std.fmt.allocPrintZ(allocator,
            \\const std = @import("std");
            \\const zls = @import("zls");
            \\
            \\pub fn neverGonnaGiveYouUpNeverGonnaLetYouDown() {{
            \\    {s}
            \\}}
        , .{input}));

        // We request completions from zls

        const emptyList: zls.Server.ResultType("textDocument/completion") = .{ .CompletionList = zls.types.CompletionList{ .isIncomplete = true, .items = &.{} } };
        const completions: []const zls.types.CompletionItem = (try server.completionHandler(allocator, .{
            .textDocument = .{
                .uri = "file:///C:/Programming/Zig/zls-as-lib-demo/src/bs.zig",
            },
            .position = .{
                .line = 4,
                .character = @intCast(4 + input.len),
            },
        }) orelse emptyList).?.CompletionList.items;

        // We print out the completions
        for (completions) |comp| {
            try std.io.getStdOut().writer().print("    {s}\n", .{comp.label});
        }
    }
}
