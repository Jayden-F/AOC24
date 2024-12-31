const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();
    var file = try cwd.openFile("src/input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const reader = file.reader();
    var buf_reader = std.io.bufferedReader(reader);
    var in_stream = buf_reader.reader();

    var lefts: std.ArrayList(i64) = std.ArrayList(i64).init(allocator);
    defer lefts.deinit();
    var rights: std.ArrayList(i64) = std.ArrayList(i64).init(allocator);
    defer rights.deinit();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var nums = std.mem.tokenizeAny(u8, line, " ");

        const left_value = try std.fmt.parseInt(i64, nums.next().?, 10);
        const right_value = try std.fmt.parseInt(i64, nums.next().?, 10);
        try lefts.append(left_value);
        try rights.append(right_value);
    }

    var total: i64 = 0;
    for (lefts.items) |left| {
        var count: i64 = 0;

        for (rights.items) |right| {
            if (left == right) {
                count += 1;
            }
        }
        total += left * count;
    }

    std.debug.print("{d}\n", .{total});
}
