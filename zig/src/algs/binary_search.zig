const std = @import("std");

const Ordering = enum { Equal, Lesser, Greater };

const BinarySearchResult = union(enum) {
    exists: usize,
    absent: usize,
};

pub fn binary_search(comptime T: type, comptime compare_fn: fn (T, T) Ordering, want: T, elements: []const T) BinarySearchResult {
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

// bit_width:
//         lzcnt   rax, rdi
//         neg     eax
//         and     eax, 63
//         ret
inline fn bit_width(comptime T: type, x: T) usize {
    return 1 + std.math.log2_int(usize, x);
}

// bit_floor:
//         lzcnt   rax, rdi
//         not     al
//         mov     ecx, 1
//         shlx    rax, rcx, rax
//         ret
inline fn bit_floor(comptime T: type, n: T) usize {
    const one: usize = 1;
    const shift: u6 = @truncate(bit_width(T, n) - 1);
    return one << shift;
}

// bit_floor_bit_twidling:
//         mov     rax, rdi
//         shr     rax
//         or      rax, rdi
//         mov     rcx, rax
//         shr     rcx, 2
//         or      rcx, rax
//         mov     rax, rcx
//         shr     rax, 4
//         or      rax, rcx
//         mov     rcx, rax
//         shr     rcx, 8
//         or      rcx, rax
//         mov     rdx, rcx
//         shr     rdx, 16
//         or      rdx, rcx
//         mov     rax, rdx
//         shr     rax, 32
//         or      rax, rdx
//         mov     rcx, rax
//         shr     rcx
//         sub     rax, rcx
//         ret

inline fn bit_floor_bit_twidling(comptime T: type, n: T) usize {
    const bits: usize = comptime @bitSizeOf(T);
    const lg2_bits: usize = comptime std.math.log2_int(usize, bits);

    var x = n;
    inline for (0..lg2_bits) |power| {
        x |= x >> (1 << power);
    }

    return x - (x >> 1);
}

pub fn binary_search_branchless(comptime T: type, comptime compare_fn: fn (T, T) bool, want: T, elements: []const T) T {
    var haystack = elements;
    const length = haystack.len;
    var step: usize = bit_floor_bit_twidling(usize, length) >> 1;

    // NB: need to throw this in godbolt to determine if compiles to conditional move
    while (step > 0) : (step >>= 1) {
        if (compare_fn(elements[step], want)) {
            haystack = haystack[step..];
        }
    }

    // Not convinced the casting is better
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
