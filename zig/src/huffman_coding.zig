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

    pub fn get(self: *Self, value: u8) *const HuffmanEntry {
        return &self.table.get(value).?;
    }

    pub fn put(self: *Self, key: u8, value: HuffmanEntry) !void {
        try self.table.put(key, value);
    }
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

// pub fn huffman_encoding(stream: []u8, root: *HuffmanNode, out: []u8) void {}

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
        std.debug.print("{c}:{}\n", .{ key, value });
    }
}
