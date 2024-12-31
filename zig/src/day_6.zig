const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("./src/day_6.input", .{});

    const reader = file.reader();

    var map: [131][132]u8 = undefined;

    var i: usize = 0;
    while (try reader.readby(131, &map[i])) |_| : (i += 1) {}

    for (map) |row| {
        for (row) |col| {
            std.debug.print("{c}", .{col});
        }
        std.debug.print("\n", .{});
    }
}
