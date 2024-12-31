const std = @import("std");

pub fn bubble_sort(numbers: []i64) void {
    const n = numbers.len;
    for (0..n) |i| {
        for (0..n - 1 - i) |j| {
            if (numbers[j + 1] < numbers[j]) {
                const temp = numbers[j];
                numbers[j] = numbers[j + 1];
                numbers[j + 1] = temp;
            }
        }
    }
}

fn quick_sort(numbers: []i64) void {
    if (numbers.len <= 1) {
        return;
    }

    const pivot_index: usize = partition(numbers[0..]);
    quick_sort(numbers[0..pivot_index]);
    quick_sort(numbers[pivot_index + 1 ..]);
}

fn partition(numbers: []i64) usize {
    const n = numbers.len - 1;
    const pivot = numbers[n];

    var idx: usize = 0;
    for (0..numbers.len) |i| {
        if (numbers[i] < pivot) {
            const tmp = numbers[i];
            numbers[i] = numbers[idx];
            numbers[idx] = tmp;
            idx += 1;
        }
    }

    numbers[n] = numbers[idx];
    numbers[idx] = pivot;
    return idx;
}

fn merge_sort(numbers: []i64, allocator: std.mem.Allocator) !void {
    const n = numbers.len;
    if (numbers.len <= 1) {
        return;
    }

    const mid = @divFloor(n, 2);

    var left = try allocator.dupe(i64, numbers[0..mid]);
    var right = try allocator.dupe(i64, numbers[mid..]);

    defer allocator.free(left);
    defer allocator.free(right);

    try merge_sort(left[0..], allocator);
    try merge_sort(right[0..], allocator);

    merge(numbers, left[0..], right[0..]);
}

fn merge(result: []i64, left: []const i64, right: []const i64) void {
    var i: usize = 0;
    var l: usize = 0;
    var r: usize = 0;

    while (l < left.len and r < right.len) : (i += 1) {
        if (left[l] < right[r]) {
            result[i] = left[l];
            l += 1;
        } else {
            result[i] = right[r];
            r += 1;
        }
    }

    while (l < left.len) : (i += 1) {
        result[i] = left[l];
        l += 1;
    }

    while (r < right.len) : (i += 1) {
        result[i] = right[r];
        r += 1;
    }
}

test "bubble sort" {
    var numbers = [_]i64{ 54, 1, 3423, -20, 5 };
    bubble_sort(numbers[0..]);
    for (0..numbers.len - 1) |i| {
        try std.testing.expect(numbers[i] < numbers[i + 1]);
    }
}

test "quick sort" {
    var numbers = [_]i64{ 54, 1, 3423, -20, 5 };
    quick_sort(numbers[0..]);
    for (0..numbers.len - 1) |i| {
        try std.testing.expect(numbers[i] < numbers[i + 1]);
    }
}

test "merge sort" {
    const allocator = std.testing.allocator;
    var numbers = [_]i64{ 54, 1, 3423, -20, 5 };
    try merge_sort(numbers[0..], allocator);
    for (0..numbers.len - 1) |i| {
        try std.testing.expect(numbers[i] < numbers[i + 1]);
    }
}
