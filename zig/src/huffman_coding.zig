const std = @import("std");
const pqueue = @import("pqueue.zig");
const trees = @import("trees.zig");

const HuffmanNode = struct {
    const Self = @This();

    frequency: u64,
    character: ?u8 = null,
    left: ?*const Self = null,
    right: ?*const Self = null,

    priority: ?usize = null,
    // Getter method for the priority field
    pub fn get_priority(self: *const Self) ?usize {
        return self.priority;
    }

    // Setter method for the priority field
    pub fn set_priority(self: *Self, value: usize) void {
        self.priority = value;
    }

    pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
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

fn equal(a: *const HuffmanNode, b: *const HuffmanNode) bool {
    return a.frequency == b.frequency and a.character == b.character;
}

const Queue = pqueue.PriorityQueue(*HuffmanNode, lessThan);

pub fn huffman_coding(freqs: *std.AutoHashMap(u8, usize), allocator: std.mem.Allocator) !*const HuffmanNode {
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
    len_bits: usize,
    decoded_len: usize,
    payload: []u8,
};

fn huffman_table_rec(node: *const HuffmanNode, table: *HuffmanTable, prefix: u8, depth: u8) !void {
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

pub fn huffman_table(root: *const HuffmanNode, allocator: std.mem.Allocator) !HuffmanTable {
    var result = HuffmanTable.init(allocator);
    try huffman_table_rec(root, &result, 0, 0);
    return result;
}

pub fn huffman_encoding(stream: []const u8, table: *const HuffmanTable, allocator: std.mem.Allocator) !HuffmanEncoding {
    const BufferT = u32;
    const buffer_num_bits: u32 = comptime @typeInfo(BufferT).Int.bits;
    const ShiftT: type = comptime std.meta.Int(.unsigned, std.math.log2(buffer_num_bits));

    var out_stream = try allocator.alloc(u8, stream.len);
    @memset(out_stream, 0);

    var buffer: BufferT = 0;
    var current_byte: u32 = 0; // in outstream
    var current_bit: u32 = 0; // in buffer

    for (stream) |char| {
        const encoding: HuffmanEntry = table.get(char);
        const value: BufferT = @intCast(encoding.value);
        const length: BufferT = @intCast(encoding.len);

        const shift_left_amount: ShiftT = @intCast(buffer_num_bits - current_bit - length);
        const shifted_value = value << shift_left_amount;

        buffer |= shifted_value;
        current_bit += length;

        // write to out_stream one byte at a time.
        while (current_bit >= 8) : (current_bit -= 8) {
            out_stream[current_byte] = @intCast(buffer >> (buffer_num_bits - 8));
            buffer <<= 8;
            current_byte += 1;
        }
    }

    //calculate the numbers of bits
    const total_num_bits = current_byte * 8 + current_bit;

    // flush last byte of buffer
    if (current_bit > 0) {
        out_stream[current_byte] = @intCast(buffer >> (buffer_num_bits - 8));
        current_byte += 1;
    }

    if (allocator.resize(out_stream, current_byte)) {
        out_stream.len = current_byte;
    }

    return HuffmanEncoding{ .len_bits = total_num_bits, .decoded_len = stream.len, .payload = out_stream };
}

pub fn huffman_decoding(encoding: HuffmanEncoding, tree: *const HuffmanNode, allocator: std.mem.Allocator) ![]u8 {
    var out_stream = try allocator.alloc(u8, encoding.decoded_len);

    var curr: ?*const HuffmanNode = tree;
    var out_index: usize = 0;
    var bit_index: usize = 0;

    // walk the encoding payload one bit at a time
    while (bit_index < encoding.len_bits) : (bit_index += 1) {
        const byte_index: usize = bit_index / 8;
        const bit_offset: u3 = @intCast(bit_index % 8);
        const bit: u8 = (encoding.payload[byte_index] >> (7 - bit_offset)) & 1;

        // walk the Huffman Encoding tree.
        switch (bit) {
            0 => curr = curr.?.left,
            1 => curr = curr.?.right,
            else => unreachable,
        }

        //  presence of char indicates we have reached a leaf node.
        if (curr.?.character) |char| {
            out_stream[out_index] = char;
            out_index += 1;
            curr = tree;
        }
    }

    return out_stream;
}

fn print_bits(elements: []const u8) void {
    for (elements) |byte| {
        std.debug.print("{b:0>8} ", .{byte});
    }
    std.debug.print("\n", .{});
}

test "huffman_coding" {
    const allocator = std.testing.allocator;

    var freqs = std.AutoHashMap(u8, usize).init(allocator);
    defer freqs.deinit();

    try freqs.put('a', 5);
    try freqs.put('b', 9);
    try freqs.put('c', 12);
    try freqs.put('d', 13);
    try freqs.put('e', 16);
    try freqs.put('f', 45);

    const a = HuffmanNode{ .character = 'a', .frequency = 5 };
    const b = HuffmanNode{ .character = 'b', .frequency = 9 };
    const c = HuffmanNode{ .character = 'c', .frequency = 12 };
    const d = HuffmanNode{ .character = 'd', .frequency = 13 };
    const e = HuffmanNode{ .character = 'e', .frequency = 16 };
    const f = HuffmanNode{ .character = 'f', .frequency = 45 };
    const ab = HuffmanNode{ .character = null, .frequency = 14, .left = &a, .right = &b };
    const cd = HuffmanNode{ .character = null, .frequency = 25, .left = &c, .right = &d };
    const abe = HuffmanNode{ .character = null, .frequency = 30, .left = &ab, .right = &e };
    const cdabe = HuffmanNode{ .character = null, .frequency = 55, .left = &cd, .right = &abe };
    const expected = HuffmanNode{ .character = null, .frequency = 100, .left = &f, .right = &cdabe };

    const tree: *const HuffmanNode = try huffman_coding(&freqs, allocator);
    defer tree.free(allocator);

    try std.testing.expect(trees.same_tree(HuffmanNode, equal, tree, &expected));
}

test "huffman_encode/decode" {
    const allocator = std.testing.allocator;

    const input =
        \\\The curious coder, aged 29, wrote a Huffman encoding test: \"Success is 100% effort, 0 regrets!\"
        \\\ can I change this string. that includes the new line character.
        \\\ What the hell
    ;

    var freqs = std.AutoHashMap(u8, usize).init(allocator);
    defer freqs.deinit();

    for (input) |char| {
        if (!freqs.contains(char)) {
            try freqs.put(char, 0);
        }
        const count = freqs.getEntry(char);
        count.?.value_ptr.* += 1;
    }

    var freq_iter = freqs.iterator();
    while (freq_iter.next()) |kv| {
        std.debug.print("{c}:{}\n", .{ kv.key_ptr.*, kv.value_ptr.* });
    }

    const tree: *const HuffmanNode = try huffman_coding(&freqs, allocator);
    defer tree.free(allocator);

    tree.print();

    var table: HuffmanTable = try huffman_table(tree, allocator);
    defer table.deinit();

    var iter = table.table.iterator();
    while (iter.next()) |kv| {
        std.debug.print("{c}: {}\n", .{ kv.key_ptr.*, kv.value_ptr.* });
    }

    std.debug.print("input: ", .{});
    print_bits(input);

    const encoding = try huffman_encoding(input[0..], &table, allocator);
    defer allocator.free(encoding.payload);

    std.debug.print("encoding: ", .{});
    print_bits(encoding.payload);

    const round_trip = try huffman_decoding(encoding, tree, allocator);
    defer allocator.free(round_trip);

    try std.testing.expectEqualSlices(u8, input, round_trip);

    std.debug.print("Original: {}, Encoded: {}\n", .{ input.len, @divFloor(encoding.len_bits, 8) });
}
