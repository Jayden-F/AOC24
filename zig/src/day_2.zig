const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("src/day_2_input.txt", .{});
    defer file.close();

    const reader = file.reader();

    var count_safe: usize = 0;

    var buf: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var nums = std.mem.tokenizeAny(u8, line, " ");

        var current: i64 = try std.fmt.parseInt(i64, nums.next().?, 10);
        var previous_is_increasing: ?bool = null;
        var unsafe_count: u64 = 0;
        while (nums.next()) |next_str| {
            const next = try std.fmt.parseInt(i64, next_str, 10);
            const diff = current - next;
            const is_increasing = diff < 0;
            const abs_diff = @abs(diff);

            var unsafe = false;

            if (previous_is_increasing) |value| {
                if (value != is_increasing) {
                    unsafe = true;
                }
            }

            if (1 > abs_diff or abs_diff > 3) {
                unsafe = true;
            }
            if (unsafe) {
                unsafe_count += 1;
            } else {
                previous_is_increasing = is_increasing;
                current = next;
            }

            if (unsafe_count > 1) {
                break;
            }
        } else {
            count_safe += 1;
        }
    }
    std.debug.print("{d}\n", .{count_safe});
}
