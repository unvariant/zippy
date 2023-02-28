const std = @import("std");
const debug = std.debug;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqualSlices = testing.expectEqualSlices;
const expectEqual = testing.expectEqual;
const Tuple = std.meta.Tuple;

const zippy = @import("zippy.zig");
const Iterator = zippy.Iterator;

var GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = GeneralPurposeAllocator.allocator();

test "testing filter" {
    var even = try Range.init(0, 10).filter(isEven).collect(allocator);
    try expectEqualSlices(usize, even.items, &[_]usize{0, 2, 4, 6, 8});
    even.deinit();
}

test "testing map" {
    var numbers = try Range.init(0, 5).map(add(1)).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{1, 2, 3, 4, 5});
    numbers.deinit();
}

test "testing byRef" {
    var it = Range.init(0, 5);
    var fst = try it.byRef().collect(allocator);
    var snd = try it.collect(allocator);
    try expectEqualSlices(usize, fst.items, &[_]usize{0, 1, 2, 3, 4});
    try expectEqualSlices(usize, snd.items, &[_]usize{});
    fst.deinit();
    snd.deinit();
}

test "testing take" {
    var numbers = try Range.init(0, 5).take(2).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{0, 1});
    numbers.deinit();
}

test "testing skip" {
    var numbers = try Range.init(0, 5).skip(2).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{2, 3, 4});
    numbers.deinit();
}

test "testing reduce" {
    var sum = Range.init(0, 5).reduce(@as(usize, 0), add2);
    try expectEqual(sum, 10);
}

test "testing fold" {
    var sum = Range.init(0, 5).fold(add2);
    try expectEqual(sum, 10);
}

test "testing all" {
    var pass = Range.init(0, 5).filter(isEven).all(isEven);
    try expectEqual(pass, true);
}

test "testing any" {
    var it = Range.init(0, 5);
    var pass = it.byRef().any(isEven);
    var rest = try it.collect(allocator);
    try expectEqual(pass, true);
    try expectEqualSlices(usize, rest.items, &[_]usize{1, 2, 3, 4});
    rest.deinit();
}

test "testing chain" {
    var fst = Range.init(0, 2);
    var snd = Range.init(2, 5);
    var it = fst.chain(snd);
    var numbers = try it.collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{0, 1, 2, 3, 4});
    numbers.deinit();
}

test "testing count" {
    var count = Range.init(0, 5).count();
    try expectEqual(count, 5);
}

test "testing enumerate" {
    const T = Tuple(&.{usize, usize});
    var numbers = try Range.init(0, 5).enumerate().collect(allocator);
    try expectEqualSlices(T, numbers.items, &[_]T{
        .{0, 0},
        .{1, 1},
        .{2, 2},
        .{3, 3},
        .{4, 4},
    });
    numbers.deinit();
}

test "testing last" {
    var last = Range.init(0, 5).last();
    try expectEqual(last, 4);
}

test "testing first" {
    var first = Range.init(0, 5).first();
    try expectEqual(first, 0);
}

test "testing nth" {
    var it = Range.init(0, 5);
    var a = it.byRef().nth(2);
    var b = it.nth(2);
    try expectEqual(a, 2);
    try expectEqual(b, null);
}

test "testing zip" {
    const T = Tuple(&.{usize, usize});
    var numbers = try Range.init(0, 5).zip(Range.init(0, 3)).collect(allocator);
    try expectEqualSlices(T, numbers.items, &[_]T{
        .{0, 0},
        .{1, 1},
        .{2, 2},
    });
    numbers.deinit();
}

test "testing stepBy" {
    var numbers = try Range.init(0, 10).stepBy(2).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{0, 2, 4, 6, 8});
    numbers.deinit();
}

test "testing filterMap" {
    var numbers = try Range.init(0, 10).filterMap(struct {
        fn fun(item: usize) ?usize {
            if (item % 2 == 0) {
                return null;
            } else {
                return item;
            }
        }
    }.fun).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{1, 3, 5, 7, 9});
    numbers.deinit();
}

test "testing takeWhile" {
    var numbers = try Range.init(0, 10).takeWhile(lt(5)).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{0, 1, 2, 3, 4});
    numbers.deinit();
}

test "testing skipWhile" {
    var numbers = try Range.init(0, 10).skipWhile(lt(5)).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{5, 6, 7, 8, 9});
    numbers.deinit();
}

test "testing find" {
    var a = Range.init(0, 10).find(gt(5));
    try expectEqual(a, 6);
}

test "testing position" {
    var a = Range.init(0, 10).position(gt(5));
    try expectEqual(a, 6);
}

test "testing empty" {
    try expectEqual(zippy.empty(usize).first(), null);
}

test "testing once" {
    try expectEqual(zippy.once(@as(usize, 5)).first(), 5);
}

test "testing repeat" {
    var numbers = try zippy.repeat(@as(usize, 2)).take(5).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{2, 2, 2, 2, 2});
    numbers.deinit();
}


/// UTILITY FUNCTIONS

pub const Range = struct {
    start: usize,
    end: usize,

    const Self = @This();
    pub const Item = usize;

    pub fn init(start: usize, end: usize) Self {
        return .{ .start = start, .end = end, };
    }

    pub fn next(self: *Self) ?Item {
        if (self.start < self.end) {
            defer self.start += 1;
            return self.start;
        }
        return null;
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

pub fn lt(comptime limit: usize) fn(usize)bool {
    const Closure = struct {
        fn fun(item: usize) bool {
            return item < limit;
        }
    };
    return Closure.fun;
}

pub fn gt(comptime limit: usize) fn(usize)bool {
    const Closure = struct {
        fn fun(item: usize) bool {
            return item > limit;
        }
    };
    return Closure.fun;
}