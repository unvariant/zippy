const std = @import("std");
const debug = std.debug;
const Tuple = std.meta.Tuple;

const Iterator = @import("iter.zig").Iterator;

pub const Range = struct {
    start: usize,
    end: usize,

    const Self = @This();
    pub const Item = usize;

    pub fn init(start: usize, end: usize) Self {
        return .{ .start = start, .end = end, };
    }

    pub fn nextFn(self: Self) Tuple(&.{?Item, Self}) {
        if (self.start < self.end) {
            return .{
                self.start,
                .{
                    .start = self.start + 1,
                    .end = self.end,
                },
            };
        }
        return .{ null, self };
    }

    pub usingnamespace Iterator(Self);
};

pub fn print(comptime T: type) fn(T)void {
    const Closure = struct {
        fn fun(item: T) void {
            debug.print("{any}\n", .{item});
        }
    };
    return Closure.fun;
}

pub fn add2(a: usize, b: usize) usize {
    return a + b;
}

pub fn add(comptime n: usize) fn(usize)usize {
    const Closure = struct {
        fn fun(item: usize) usize {
            return item + n;
        }
    };
    return Closure.fun;
}

pub fn sub(comptime n: usize) fn(usize)usize {
    return add(-n);
}

pub fn isEven(item: usize) bool {
    return item % 2 == 0;
}