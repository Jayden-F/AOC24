const std = @import("std");

pub fn is_sorted(comptime T: type, comptime less_than: fn (T, T) bool, elements: []T) bool {
    for (0..elements.len - 1) |i| {
        if (!less_than(elements[i], elements[i + 1])) {
            return false;
        }
    }
    return true;
}

pub fn swap(comptime T: type, a: *T, b: *T) void {
    const temp: T = a.*;
    a.* = b.*;
    b.* = temp;
}

pub fn selection_sort(comptime T: type, comptime less_than: fn (T, T) bool, numbers: []T) void {
    for (0..numbers.len) |i| {
        var min_index = i;
        for (i..numbers.len) |j| {
            if (less_than(numbers[j], numbers[min_index])) {
                min_index = j;
            }
        }
        swap(T, &numbers[i], &numbers[min_index]);
    }
}

pub fn insertion_sort(comptime T: type, comptime less_than: fn (T, T) bool, numbers: []T) void {
    for (1..numbers.len) |i| {
        const key = numbers[i];

        var j = i - 1;
        while (j < i and less_than(key, numbers[j])) : (j -%= 1) {
            numbers[j + 1] = numbers[j];
        }
        numbers[j +% 1] = key;
    }
}

pub fn bubble_sort(comptime T: type, comptime less_than: fn (T, T) bool, numbers: []T) void {
    const n = numbers.len;
    for (0..n) |i| {
        for (0..n - 1 - i) |j| {
            if (less_than(numbers[j + 1], numbers[j])) {
                swap(i64, &numbers[j], &numbers[j + 1]);
            }
        }
    }
}

fn quick_sort(comptime T: type, comptime less_than: fn (T, T) bool, numbers: []T) void {
    if (numbers.len <= 1) {
        return;
    }

    const pivot_index: usize = partition(T, less_than, numbers[0..]);
    quick_sort(T, less_than, numbers[0..pivot_index]);
    quick_sort(T, less_than, numbers[pivot_index + 1 ..]);
}

fn partition(comptime T: type, comptime less_than: fn (T, T) bool, numbers: []T) usize {
    const n = numbers.len - 1;
    const pivot = numbers[n];

    var idx: usize = 0;
    for (0..numbers.len) |i| {
        if (less_than(numbers[i], pivot)) {
            swap(T, &numbers[i], &numbers[idx]);
            idx += 1;
        }
    }

    numbers[n] = numbers[idx];
    numbers[idx] = pivot;
    return idx;
}

fn merge_sort(comptime T: type, comptime less_than: fn (T, T) bool, numbers: []T, allocator: std.mem.Allocator) !void {
    const n = numbers.len;
    if (numbers.len <= 1) {
        return;
    }

    const mid = @divFloor(n, 2);

    var left = try allocator.dupe(T, numbers[0..mid]);
    var right = try allocator.dupe(T, numbers[mid..]);

    defer allocator.free(left);
    defer allocator.free(right);

    try merge_sort(T, less_than, left[0..], allocator);
    try merge_sort(T, less_than, right[0..], allocator);

    merge(T, less_than, numbers, left[0..], right[0..]);
}

fn merge(comptime T: type, comptime less_than: fn (T, T) bool, result: []T, left: []const T, right: []const T) void {
    var result_index: usize = 0;
    var left_index: usize = 0;
    var right_index: usize = 0;

    while (left_index < left.len and right_index < right.len) : (result_index += 1) {
        if (less_than(left[left_index], right[right_index])) {
            result[result_index] = left[left_index];
            left_index += 1;
        } else {
            result[result_index] = right[right_index];
            right_index += 1;
        }
    }

    while (left_index < left.len) : (result_index += 1) {
        result[result_index] = left[left_index];
        left_index += 1;
    }

    while (right_index < right.len) : (result_index += 1) {
        result[result_index] = right[right_index];
        right_index += 1;
    }
}

pub fn bogosort(comptime T: type, comptime less_than: fn (T, T) bool, elements: []T) void {
    var prng = std.rand.DefaultPrng.init(42);
    while (!is_sorted(T, less_than, elements[0..])) {
        prng.random().shuffle(T, elements[0..]);
    }
    return;
}

fn less_than_i64(a: i64, b: i64) bool {
    return a < b;
}

test "bubble sort" {
    var numbers = [_]i64{ 54, 1, 3423, -20, 5, 100, 299, 1000, 420, 50, 180 };
    bubble_sort(i64, less_than_i64, numbers[0..]);
    for (0..numbers.len - 1) |i| {
        try std.testing.expect(numbers[i] <= numbers[i + 1]);
    }
}

test "selection sort" {
    var numbers = [_]i64{ 54, 1, 3423, -20, 5, 100, 299, 1000, 420, 50, 180 };
    selection_sort(i64, less_than_i64, numbers[0..]);
    for (0..numbers.len - 1) |i| {
        try std.testing.expect(numbers[i] < numbers[i + 1]);
    }
}

test "insertion sort" {
    var numbers = [_]i64{ 54, 1, 3423, -20, 5, 100, 299, 1000, 420, 50, 180 };
    insertion_sort(i64, less_than_i64, numbers[0..]);
    for (0..numbers.len - 1) |i| {
        try std.testing.expect(numbers[i] <= numbers[i + 1]);
    }
}

test "quick sort" {
    var numbers = [_]i64{ 54, 1, 3423, -20, 5, 100, 299, 1000, 420, 50, 180 };
    quick_sort(i64, less_than_i64, numbers[0..]);
    for (0..numbers.len - 1) |i| {
        try std.testing.expect(numbers[i] <= numbers[i + 1]);
    }
}

test "merge sort" {
    const allocator = std.testing.allocator;
    var numbers = [_]i64{ 54, 1, 3423, -20, 5, 100, 299, 1000, 420, 50, 180 };
    try merge_sort(i64, less_than_i64, numbers[0..], allocator);
    for (0..numbers.len - 1) |i| {
        try std.testing.expect(numbers[i] <= numbers[i + 1]);
    }
}

test "bogo sort" {
    var numbers = [_]i64{ 54, 1, 3423, -20, 5, 100, 299, 1000, 420, 50, 180 };
    bogosort(i64, less_than_i64, numbers[0..]);
    for (0..numbers.len - 1) |i| {
        try std.testing.expect(numbers[i] <= numbers[i + 1]);
    }
}
