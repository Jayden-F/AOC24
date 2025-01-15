const std = @import("std");

pub fn Node(T: type) type {
    return struct {
        const Self = @This();

        value: T,
        prev: ?*Self,
        next: ?*Self,
    };
}

pub fn de_linked(T: type) type {
    return struct {
        const Self = @This();
        allocator: std.heap.Allocator,
        head: ?Node(T),
        tail: ?Node(T),
        size: usize,

        pub fn init(allocator: std.heap.Allocator) Self {
            return .{ .allocator = allocator, .head = null, .tail = null, .size = 0 };
        }

        pub fn prepend(self: *Self, value: T) !void {
            var node: *Node(T) = try self.allocator.create(Node(T));
            self.size += 1;

            if (self.size == 0) {
                node.value = value;
                node.head = null;
                node.tail = null;

                self.head = node;
                self.tail = node;
                return;
            }

            node.next = self.head;
            self.head.prev = node;
            self.head = node;

            return;
        }
        pub fn append(self: *Self, value: T) !void {
            var node: *Node(T) = try self.allocator.create(Node(T));
            self.size += 1;

            if (self.size == 0) {
                node.value = value;
                node.head = null;
                node.tail = null;

                self.head = node;
                self.tail = node;
                return;
            }

            node.prev = self.tail;
            self.tail.next = node;

            self.tail = node;

            return;
        }
        pub fn insert(self: *Self, value: T, index: usize) !void {
            if (index == 0) {
                self.prepend(value);
            } else if (index == self.size) {
                self.append(value);
            } else {
                var current = self.head;
                for (0..index) |_| {
                    current = current.next;
                }

                var node: *Node(T) = try self.allocator.create(Node(T));
                self.size += 1;

                node.value = value;
                node.prev = current;
                node.next = current.next;

                current.next.prev = node;
                current.next = node;
            }
        }
        pub fn pop(self: *Self) ?T {
            if (self.size == 0) {
                return null;
            } else if (self.size == 1) {
                self.tail = null;
                self.head = null;
                self.size = 0;
            }

            const temp = self.tail;
            defer self.allocator.destroy(temp);

            self.tail = self.tail.prev;
            self.size -= 1;

            return temp.value;
        }
    };
}
