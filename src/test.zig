const std = @import("std");
const debug = std.debug;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqualSlices = testing.expectEqualSlices;
const expectEqual = testing.expectEqual;
const Tuple = std.meta.Tuple;

const utils = @import("utils.zig");
const Range = utils.Range;
const add = utils.add;
const add2 = utils.add2;
const isEven = utils.isEven;
const print = utils.print;

var GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = GeneralPurposeAllocator.allocator();

test "testing filter" {
    var even = try Range.init(0, 10).filter(isEven).collect(allocator);
    try expectEqualSlices(usize, even.items, &[_]usize{0, 2, 4, 6, 8});
    even.deinit();
    _ = GeneralPurposeAllocator.detectLeaks();
}

test "testing map" {
    var numbers = try Range.init(0, 5).map(add(1)).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{1, 2, 3, 4, 5});
    numbers.deinit();
    _ = GeneralPurposeAllocator.detectLeaks();
}

test "testing by_ref" {
    var it = Range.init(0, 5);
    var fst = try it.by_ref().collect(allocator);
    var snd = try it.collect(allocator);
    try expectEqualSlices(usize, fst.items, &[_]usize{0, 1, 2, 3, 4});
    try expectEqualSlices(usize, snd.items, &[_]usize{});
    fst.deinit();
    snd.deinit();
    _ = GeneralPurposeAllocator.detectLeaks();
}

test "testing take" {
    var numbers = try Range.init(0, 5).take(2).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{0, 1});
    numbers.deinit();
    _ = GeneralPurposeAllocator.detectLeaks();
}

test "testing skip" {
    var numbers = try Range.init(0, 5).skip(2).collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{2, 3, 4});
    numbers.deinit();
    _ = GeneralPurposeAllocator.detectLeaks();
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
    var pass = it.any(isEven);
    var rest = try it.collect(allocator);
    try expectEqual(pass, true);
    try expectEqualSlices(usize, rest.items, &[_]usize{1, 2, 3, 4});
    rest.deinit();
    _ = GeneralPurposeAllocator.detectLeaks();
}

test "testing chain" {
    var fst = Range.init(0, 2);
    var snd = Range.init(2, 5);
    var it = fst.chain(snd);
    var numbers = try it.collect(allocator);
    try expectEqualSlices(usize, numbers.items, &[_]usize{0, 1, 2, 3, 4});
    numbers.deinit();
    _ = GeneralPurposeAllocator.detectLeaks();
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
    _ = GeneralPurposeAllocator.detectLeaks();
}

test "testing last" {
    var last = Range.init(0, 5).last();
    try expectEqual(last, 4);
}