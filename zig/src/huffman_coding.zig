const std = @import("std");
const pqueue = @import("pqueue.zig");

const HuffmanNode = struct {
    const Self = @This();

    frequency: u64,
    character: ?u8 = null,
    left: ?*Self = null,
    right: ?*Self = null,

    priority: ?usize = null,
    // Getter method for the priority field
    pub fn get_priority(self: *const Self) ?usize {
        return self.priority;
    }

    // Setter method for the priority field
    pub fn set_priority(self: *Self, value: usize) void {
        self.priority = value;
    }

    pub fn free(self: *Self, allocator: std.mem.Allocator) void {
        if (self.left) |left| {
            left.free(allocator);
        }
        if (self.right) |right| {
            right.free(allocator);
        }
        allocator.destroy(self);
    }

    pub fn print(self: *const Self) void {
        self.print_nodes(0);
    }

    fn print_nodes(self: *const Self, prefix: u64) void {
        if (self.left) |left| {
            left.print_nodes((prefix << 1));
        }

        if (self.right) |right| {
            right.print_nodes((prefix << 1) | 1);
        }

        if (self.character) |char| {
            std.debug.print("char: {c}, code: {b}\n", .{ char, prefix });
        }
    }
};

fn lessThan(a: *HuffmanNode, b: *HuffmanNode) bool {
    return a.frequency < b.frequency;
}

const Queue = pqueue.PriorityQueue(*HuffmanNode, lessThan);

pub fn huffman_coding(chars: []const u8, freqs: []const u64, allocator: std.mem.Allocator) !*HuffmanNode {
    const n = chars.len;
    const nodes: []*HuffmanNode = try allocator.alloc(*HuffmanNode, n);
    defer allocator.free(nodes);

    for (chars, freqs, 0..) |char, freq, i| {
        nodes[i] = try allocator.create(HuffmanNode);
        nodes[i].* = HuffmanNode{ .character = char, .frequency = freq };
    }

    var queue = try Queue.build(allocator, nodes);
    defer queue.deinit();

    while (queue.len > 1) {
        const left = try queue.pop();
        const right = try queue.pop();

        // The additional internal nodes are owned by the caller.
        const new_node = try allocator.create(HuffmanNode);
        new_node.* = .{ .frequency = (left.frequency + right.frequency), .left = left, .right = right };
        try queue.push(new_node);
    }

    return try queue.pop();
}

const HuffmanEntry = struct {
    value: u8,
    len: u8,
};

const HuffmanTable = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    table: std.AutoHashMap(u8, HuffmanEntry),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator, .table = std.AutoHashMap(u8, HuffmanEntry).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.table.deinit();
    }

    pub fn get(self: *const Self, value: u8) HuffmanEntry {
        return self.table.get(value).?;
    }

    pub fn put(self: *Self, key: u8, value: HuffmanEntry) !void {
        try self.table.put(key, value);
    }
};

const HuffmanEncoding = struct {
    len: usize,
    decoded_len: usize,
    payload: []u8,
};

fn huffman_table_rec(node: *HuffmanNode, table: *HuffmanTable, prefix: u8, depth: u8) !void {
    if (node.left) |left| {
        try huffman_table_rec(left, table, prefix << 1, depth + 1);
    }
    if (node.right) |right| {
        try huffman_table_rec(right, table, (prefix << 1) | 1, depth + 1);
    }

    if (node.character) |char| {
        try table.put(char, .{ .value = prefix, .len = depth });
    }
}

pub fn huffman_table(root: *HuffmanNode, allocator: std.mem.Allocator) !HuffmanTable {
    var result = HuffmanTable.init(allocator);
    try huffman_table_rec(root, &result, 0, 0);
    return result;
}

pub fn huffman_encoding(stream: []const u8, table: *const HuffmanTable, allocator: std.mem.Allocator) !HuffmanEncoding {
    var out_stream = try allocator.alloc(u8, stream.len);
    for (0..out_stream.len) |i| {
        out_stream[i] = 0;
    }

    var bit_index: usize = 0;

    for (stream) |char| {
        const encoding: HuffmanEntry = table.get(char);
        var value = encoding.value;
        var length = encoding.len;

        while (length > 0) {
            const byte_index: usize = bit_index / 8;
            const bit_offset = bit_index % 8;

            const bits_to_write = @min(8 - bit_offset, length);
            const shift_left_amount: u3 = @intCast(8 - bit_offset - bits_to_write);
            const bits = value << shift_left_amount;

            out_stream[byte_index] |= bits;

            bit_index += bits_to_write;
            const shift_right_amount: u3 = @intCast(bits_to_write);
            value >>= shift_right_amount;
            length -= bits_to_write;
        }
    }

    const used_bytes = (bit_index + 7) / 8;
    if (allocator.resize(out_stream, used_bytes)) {
        out_stream.len = used_bytes;
    }

    return HuffmanEncoding{ .len = bit_index, .decoded_len = stream.len, .payload = out_stream };
}

pub fn huffman_decoding(encoding: HuffmanEncoding, tree: *HuffmanNode, allocator: std.mem.Allocator) ![]u8 {
    var out_stream = try allocator.alloc(u8, encoding.decoded_len);

    var curr: ?*HuffmanNode = tree;
    var out_index: usize = 0;
    var bit_index: usize = 0;

    while (bit_index < encoding.len) : (bit_index += 1) {
        const byte_index: usize = bit_index / 8;
        const bit_offset: u3 = @intCast(bit_index % 8);

        const bit: u8 = (encoding.payload[byte_index] >> (7 - bit_offset)) & 1;
        switch (bit) {
            0 => curr = curr.?.left,
            1 => curr = curr.?.right,
            else => unreachable,
        }

        if (curr.?.character) |char| {
            out_stream[out_index] = char;
            curr = tree;
            out_index += 1;
        }
    }

    return out_stream;
}

test "huffman_coding" {
    const allocator = std.testing.allocator;

    const chars = "abcdef";
    const freqs = [_]u64{ 5, 9, 12, 13, 16, 45 };

    const tree: *HuffmanNode = try huffman_coding(chars[0..], freqs[0..], allocator);
    defer tree.free(allocator);

    tree.print();

    var table: HuffmanTable = try huffman_table(tree, allocator);
    defer table.deinit();

    var iter = table.table.iterator();
    while (iter.next()) |kv| {
        const key = kv.key_ptr.*;
        const value = kv.value_ptr.*;
        std.debug.print("{c}: {}\n", .{ key, value });
    }

    const stream = "abcdef";
    const encoding = try huffman_encoding(stream[0..], &table, allocator);
    defer allocator.free(encoding.payload);

    for (stream) |byte| {
        std.debug.print("{b:0>8} ", .{byte});
    }

    std.debug.print("\n", .{});

    for (encoding.payload) |byte| {
        std.debug.print("{b:0>8} ", .{byte});
    }

    const round_trip = try huffman_decoding(encoding, tree, allocator);
    defer allocator.free(round_trip);

    std.debug.print("\n", .{});
    for (round_trip) |byte| {
        std.debug.print("{b:0>8} ", .{byte});
    }

    try std.testing.expectEqualSlices(u8, stream, round_trip);
}
