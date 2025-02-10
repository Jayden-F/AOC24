const std = @import("std");

const Ordering = enum { Equal, Lesser, Greater };

const BinarySearchResult = union(enum) {
    exists: usize,
    absent: usize,
};

pub fn binary_search(comptime T: type, comptime compare_fn: fn (T, T) Ordering, want: u32, elements: []const T) BinarySearchResult {
    var low: usize = 0;
    var high: usize = elements.len;

    while (low < high) {
        const mid: usize = low + (high - low) / 2;
        const value: T = elements[mid];

        const compare: Ordering = compare_fn(value, want);

        switch (compare) {
            Ordering.Lesser => low = mid + 1,
            Ordering.Greater => high = mid,
            Ordering.Equal => return .{ .exists = mid },
        }
    }
    return .{ .absent = low };
}

inline fn bit_width(comptime T: type, x: T) usize {
    return 1 + std.math.log2(x);
}

inline fn bit_floor(comptime T: type, x: T) usize {
    const one: usize = 1;
    const shift: u6 = @intCast(bit_width(T, x) - 1);
    return one << shift;
}

pub fn binary_search_branchless(comptime T: type, comptime compare_fn: fn (T, T) bool, want: u32, elements: []const T) T {
    var haystack = elements;
    const length = haystack.len;
    var step: usize = bit_floor(usize, length) >> 1;

    while (step > 0) : (step >>= 1) {
        if (compare_fn(elements[step], want)) {
            haystack = haystack[step..];
        }
    }

    const compare: usize = @intFromBool(compare_fn(haystack[0], want));
    return haystack[0 + compare];
}

fn compare_u32(what: u32, want: u32) Ordering {
    if (what < want) {
        return Ordering.Lesser;
    } else if (what > want) {
        return Ordering.Greater;
    } else {
        return Ordering.Equal;
    }
}

fn less_than_u32(what: u32, want: u32) bool {
    return what < want;
}

test "test binary_search exists" {
    const haystack = [_]u32{ 1, 2, 4, 8, 16, 32, 64, 128 };
    const value = binary_search(u32, compare_u32, 8, haystack[0..]);
    try std.testing.expectEqual(BinarySearchResult{ .exists = 3 }, value);
}

test "test binary_search absent" {
    const haystack = [_]u32{ 1, 2, 4, 8, 16, 32, 64, 128 };
    const value = binary_search(u32, compare_u32, 10, haystack[0..]);
    try std.testing.expectEqual(BinarySearchResult{ .absent = 4 }, value);
}

test "test binary_search_branchless exists" {
    const haystack = [_]u32{ 1, 2, 4, 8, 16, 32, 64, 128 };
    const value = binary_search_branchless(u32, less_than_u32, 8, haystack[0..]);
    try std.testing.expectEqual(8, value);
}

test "test binary_search_branchless absent" {
    const haystack = [_]u32{ 1, 2, 4, 8, 16, 32, 64, 128 };
    const value = binary_search_branchless(u32, less_than_u32, 10, haystack[0..]);
    try std.testing.expectEqual(16, value);
}
