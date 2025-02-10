const std = @import("std");

const PriorityQueueError = error{
    QueueEmpty,
};

// Status describing whether the node is in the open or closed list
const Status = enum(u1) { Open, Closed };

pub fn Node(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        priority: ?usize = null,

        // Getter method for the priority field
        pub fn get_priority(self: *const Self) ?usize {
            return self.priority;
        }

        // Setter method for the priority field
        pub fn set_priority(self: *Self, value: usize) void {
            self.priority = value;
        }
    };
}

pub fn hasDeclaration(comptime T: type, comptime decl: []const u8) bool {
    const actualType = switch (@typeInfo(T)) {
        .Pointer => @typeInfo(T).Pointer.child,
        else => T,
    };
    return @hasDecl(actualType, decl);
}

pub fn PriorityQueue(comptime T: type, comptime compare_fn: fn (T, T) bool) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        elements: []T,
        capacity: usize,
        len: usize = 0,
        heap_ops: usize = 0,

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            std.debug.print("Initialising Queue Size: {d}\n", .{capacity});
            const elements: []T = try allocator.alloc(T, capacity);
            return Self{
                .allocator = allocator,
                .elements = elements,
                .capacity = capacity,
                .len = 0,
                .heap_ops = 0,
            };
        }

        pub fn build(allocator: std.mem.Allocator, from: []const T) !Self {
            const elements = try allocator.dupe(T, from);
            var self = Self{ .allocator = allocator, .elements = elements, .capacity = elements.len, .len = elements.len, .heap_ops = 0 };

            const n = self.len >> 1;
            var i = n;
            while (i <= n) : (i -%= 1) {
                self.sift_down(i);
            }

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.elements);
            self.capacity = 0;
            self.len = 0;
        }

        pub fn reset(self: *Self) void {
            self.len = 0;
            self.heap_ops = 0;
        }

        pub fn push(self: *Self, value: T) !void {
            if (self.contains(value)) {
                return;
            }
            const new_len = self.len + 1;
            if (new_len > self.capacity) {
                try self.grow(self.capacity * 2);
            }
            value.set_priority(self.len);
            self.elements[self.len] = value;
            self.sift_up(self.len);
            self.len = new_len;
        }

        pub fn pop(self: *Self) PriorityQueueError!T {
            switch (self.len) {
                0 => {
                    return PriorityQueueError.QueueEmpty;
                },
                else => {
                    self.len -= 1;
                    self.swap(0, self.len);
                    self.sift_down(0);
                    return self.elements[self.len];
                },
            }
        }

        pub fn peek(self: *Self) T {
            switch (self.len) {
                0 => return PriorityQueueError.QueueEmpty,
                else => return self.elements[0],
            }
        }

        pub fn decrease_key(self: *Self, value: T) void {
            if (self.contains(value)) {
                self.sift_up(value.get_priority());
            }
        }

        pub fn increase_key(self: *Self, value: T) void {
            if (self.contains(value)) {
                self.sift_down(value.get_priority());
            }
        }

        pub fn grow(self: *Self, new_capacity: usize) !void {
            std.debug.print("Growing Queue Size: {d}\n", .{new_capacity});
            if (new_capacity <= self.capacity) {
                return;
            }

            const new_elements: []T = try self.allocator.alloc(T, new_capacity);
            for (0..self.len) |i| {
                new_elements[i] = self.elements[i];
            }
            self.allocator.free(self.elements);
            self.elements = new_elements;
            self.capacity = new_capacity;
        }

        pub fn size(self: *Self) usize {
            return @sizeOf(Self) + self.capacity * @sizeOf(T);
        }

        pub inline fn contains(self: *const Self, value: T) bool {
            if (value.get_priority()) |priority| {
                if (priority < self.len) {
                    return std.meta.eql(value, self.elements[priority]);
                }
            }
            return false;
        }

        inline fn sift_up(self: *Self, index: usize) void {
            self.heap_ops += 1;
            var current = index;
            while (current > 0) {
                const parent = (current - 1) >> 1;
                if (compare_fn(self.elements[current], self.elements[parent])) {
                    self.swap(current, parent);
                    current = parent;
                } else {
                    break;
                }
            }
        }

        inline fn sift_down(self: *Self, index: usize) void {
            self.heap_ops += 1;
            var current = index;
            const first_leaf_index: usize = self.len >> 1;
            while (current < first_leaf_index) {
                const left = (current << 1) + 1;
                const right = left + 1;
                var which = left;

                if (right < self.len and compare_fn(self.elements[right], self.elements[left])) {
                    which = right;
                }

                if (compare_fn(self.elements[which], self.elements[current])) {
                    self.swap(which, current);
                    current = which;
                } else {
                    break;
                }
            }
        }

        inline fn swap(self: *Self, a: usize, b: usize) void {
            const temp = self.elements[b];
            self.elements[b] = self.elements[a];
            self.elements[a] = temp;
            self.elements[a].set_priority(a);
            self.elements[b].set_priority(b);
        }
    };
}

const Node_u64 = Node(u64);
fn lessThanPtr(a: *Node_u64, b: *Node_u64) bool {
    return a.value < b.value;
}

fn lessThan(a: Node_u64, b: Node_u64) bool {
    return a.value < b.value;
}

test "test priority queue" {
    std.debug.print("\n", .{});

    const allocator = std.testing.allocator;
    const Queue = PriorityQueue(*Node_u64, lessThanPtr);

    var queue = try Queue.init(allocator, 1);
    defer queue.deinit();

    var n: u64 = 1_000_000;
    var nodes = try allocator.alloc(Node_u64, n);
    defer allocator.free(nodes);
    while (n > 0) : (n -= 1) {
        nodes[n - 1].value = n;
        try queue.push(&nodes[n - 1]);
        std.debug.assert(queue.contains(&nodes[n - 1]));
    }

    while (queue.len > 0) {
        const node = try queue.pop();
        // std.debug.print("{}\n", .{node});
        std.debug.assert(!queue.contains(node));
    }

    std.debug.print("heap ops: {}\n", .{queue.heap_ops});
}

test "test build priority queue" {
    std.debug.print("\n", .{});

    const allocator = std.testing.allocator;
    const Queue = PriorityQueue(Node_u64, lessThan);

    var n: u64 = 1_000_000;
    var nodes = try allocator.alloc(Node_u64, n);
    defer allocator.free(nodes);

    while (n > 1) : (n -= 1) {
        nodes[n - 1].value = n;
    }

    var queue = try Queue.build(allocator, nodes);
    defer queue.deinit();
    std.debug.print("heap ops: {}\n", .{queue.heap_ops});

    while (queue.len > 0) {
        const node = try queue.pop();
        std.debug.print("{}\n", .{node});
        std.debug.assert(!queue.contains(node));
    }

    std.debug.print("heap ops: {}\n", .{queue.heap_ops});
}
