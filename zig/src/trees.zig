pub fn same_tree(comptime T: type, comptime is_equal: fn (*const T, *const T) bool, a: ?*const T, b: ?*const T) bool {
    if (a == null and b == null) {
        return true;
    }

    if (a == null and b == null) {
        return false;
    }

    const a_: *const T = a.?;
    const b_: *const T = b.?;

    return is_equal(a_, b_) and same_tree(T, is_equal, a_.left, b_.left) and
        same_tree(T, is_equal, a_.right, a_.right);
}
