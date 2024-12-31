const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const std = @import("std");

fn less_than(context: void, a: i64, b: i64) std.math.Order {
    _ = context;
    return std.math.order(a, b);
}

const queue = std.PriorityQueue(i64, void, less_than);

pub fn main() !void {
    const cwd = std.fs.cwd();
    var file = try cwd.openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const reader = file.reader();
    var buf_reader = std.io.bufferedReader(reader);
    var in_stream = buf_reader.reader();

    var left = queue.init(allocator, {});
    defer left.deinit();
    var right = queue.init(allocator, {});
    defer right.deinit();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var nums = std.mem.tokenizeAny(u8, line, " ");

        const left_value = try std.fmt.parseInt(i64, nums.next().?, 10);
        const right_value = try std.fmt.parseInt(i64, nums.next().?, 10);
        try left.add(left_value);
        try right.add(right_value);
    }

    var sum: u64 = 0;
    while (left.count() != 0 and right.count() != 0) {
        const left_value = left.remove();
        const right_value = right.remove();
        sum += @abs(left_value - right_value);
    }

    std.debug.print("{}\n", .{sum});
}
