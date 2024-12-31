const std = @import("std");

fn concat(a: u64, b: u64) u64 {
    const digits = if (b == 0) 1 else std.math.log10(b) + 1;
    const multiplier = std.math.pow(u64, 10, digits);
    return a * multiplier + b;
}

fn is_valid_helper(total: u64, numbers: []const u64, sum: u64) bool {
    if (sum > total) {
        return false;
    }
    if (numbers.len == 0) {
        return total == sum;
    }
    const number = numbers[0];
    const slice = numbers[1..];
    return is_valid_helper(total, slice, sum * number) or is_valid_helper(total, slice, sum + number) or is_valid_helper(total, slice, concat(sum, number));
}

pub fn is_valid(total: u64, numbers: []const u64) bool {
    return is_valid_helper(total, numbers[1..], numbers[0]);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const cwd = std.fs.cwd();
    const file = try cwd.openFile("./src/day_7.input", .{});

    const reader = file.reader();
    var buf: [1024]u8 = undefined;

    var count: u64 = 0;
    var numbers = std.ArrayList(u64).init(allocator);
    defer numbers.deinit();
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var split_line = std.mem.tokenizeAny(u8, line, ": ");
        const total = try std.fmt.parseInt(u64, split_line.next().?, 10);

        while (split_line.next()) |value| {
            try numbers.append(try std.fmt.parseInt(u64, value, 10));
        }

        if (is_valid(total, numbers.items)) {
            count += total;
        }

        numbers.clearRetainingCapacity();
    }

    std.debug.print("{}\n", .{count});
}

test "input 1" {
    const total: u64 = 190;
    const numbers = [_]u64{ 10, 19 };
    try std.testing.expect(is_valid(total, &numbers));
}

// test "input 2" {
//     const total: u64 = 3267;
//     const numbers = [_]u64{ 81, 40, 27 };
//     try std.testing.expect(is_valid(total, numbers[0..]));
// }

// test "input 3" {
//     const total: u64 = 83;
//     const numbers = [_]u64{ 17, 5 };
//     try std.testing.expect(!is_valid(total, numbers[0..]));
// }

// test "input 4" {
//     const total: u64 = 156;
//     const numbers = [_]u64{ 15, 6 };
//     try std.testing.expect(!is_valid(total, numbers[0..]));
// }

test "concat 1" {
    const a: u64 = 100;
    const b: u64 = 200;
    try std.testing.expectEqual(100200, concat(a, b));
}

// 156: 15 6
// 7290: 6 8 6 15
// 161011: 16 10 13
// 192: 17 8 14
// 21037: 9 7 18 13
// 292: 11 6 16 20
