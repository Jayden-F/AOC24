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
            std.debug.print("char: {c}, code: {b:0>8}\n", .{ char, prefix });
        }
    }
};

fn lessThan(a: *HuffmanNode, b: *HuffmanNode) bool {
    return a.frequency < b.frequency;
}

const Queue = pqueue.PriorityQueue(*HuffmanNode, lessThan);

pub fn huffman_coding(freqs: *std.AutoHashMap(u8, usize), allocator: std.mem.Allocator) !*HuffmanNode {
    const n = freqs.count();
    const nodes: []*HuffmanNode = try allocator.alloc(*HuffmanNode, n);
    defer allocator.free(nodes);

    var iter = freqs.iterator();
    var i: usize = 0;
    while (iter.next()) |item| {
        nodes[i] = try allocator.create(HuffmanNode);
        nodes[i].* = HuffmanNode{ .character = item.key_ptr.*, .frequency = item.value_ptr.* };
        i += 1;
    }

    var queue = try Queue.build(allocator, nodes);
    defer queue.deinit();

    while (queue.len > 1) {
        const left = try queue.pop();
        const right = try queue.pop();

        // The additional internal nodes are owned by the caller.
        const new_node = try allocator.create(HuffmanNode);
        new_node.* = HuffmanNode{ .character = null, .frequency = (left.frequency + right.frequency), .left = left, .right = right };
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
    @memset(out_stream, 0);

    var byte_index: usize = 0;
    var bit_index: usize = 0;

    var buffer: u64 = 0;
    var buffer_offset: usize = 0;

    for (stream) |char| {
        const encoding: HuffmanEntry = table.get(char);
        const value: u64 = @intCast(encoding.value);
        const length: u64 = @intCast(encoding.len);

        const shift_left_amount: u6 = @intCast(64 - buffer_offset - length);
        const bits = value << shift_left_amount;
        buffer |= bits;

        bit_index += length;
        buffer_offset += length;

        while (buffer_offset >= 8) {
            out_stream[byte_index] = @intCast(buffer >> 56);
            buffer <<= 8;
            buffer_offset -= 8;
            byte_index += 1;
        }
    }

    if (buffer_offset > 0) {
        out_stream[byte_index] = @intCast(buffer >> 56);
        byte_index += 1;
    }

    if (allocator.resize(out_stream, byte_index)) {
        out_stream.len = byte_index;
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
            out_index += 1;
            curr = tree;
        }
    }

    return out_stream;
}

test "huffman_coding" {
    const allocator = std.testing.allocator;

    const input = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat";
    var freqs = std.AutoHashMap(u8, usize).init(allocator);
    defer freqs.deinit();

    for (input) |char| {
        if (!freqs.contains(char)) {
            try freqs.put(char, 0);
        }
        const count = freqs.getEntry(char);
        count.?.value_ptr.* += 1;
    }

    const tree: *HuffmanNode = try huffman_coding(&freqs, allocator);
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

    std.debug.print("input  : ", .{});
    for (input) |byte| {
        std.debug.print("{b:0>8} ", .{byte});
    }
    std.debug.print("\n", .{});

    const encoding = try huffman_encoding(input[0..], &table, allocator);
    defer allocator.free(encoding.payload);

    std.debug.print("encoded: ", .{});
    for (encoding.payload) |byte| {
        std.debug.print("{b:0>8} ", .{byte});
    }
    std.debug.print("\n", .{});

    const round_trip = try huffman_decoding(encoding, tree, allocator);
    defer allocator.free(round_trip);

    try std.testing.expectEqualSlices(u8, input, round_trip);

    std.debug.print("Original: {}, Encoded: {}\n", .{ input.len, @divFloor(encoding.len, 8) });
}
