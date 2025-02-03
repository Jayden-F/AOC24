pub fn same_tree(comptime T: type, comptime is_equal: fn (*const T, *const T) bool, a: ?*const T, b: ?*const T) bool {
    if (a == null and b == null) {
        return true;
    }

    if (a == null and b == null) {
        return false;
    }

    return is_equal(a.?, b.?) and same_tree(T, is_equal, a.?.left, b.?.left) and
        same_tree(T, is_equal, a.?.right, a.?.right);
}
