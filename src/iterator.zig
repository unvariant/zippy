const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const meta = std.meta;
const trait = meta.trait;
const Tuple = meta.Tuple;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

fn ReturnType(comptime val: anytype) type {
    const vtype = @TypeOf(val);
    const vinfo = @typeInfo(vtype);
    if (vinfo != .Fn) {
        @compileError(@typeName(vtype) ++ " is not a function");
    }
    return vinfo.Fn.return_type orelse @compileError(@typeName(vtype) ++ " does not have a return value");
}

fn ParamTypes(comptime val: anytype) type {
    return @TypeOf(val);
}

fn Deref(comptime T: type) type {
    if (comptime trait.isSingleItemPtr(T)) {
        return @typeInfo(T).Pointer.child;
    } else {
        return T;
    }
}

fn deref(item: anytype) Deref(@TypeOf(item)) {
    if (comptime trait.isSingleItemPtr(@TypeOf(item))) {
        return item.*;
    } else {
        return item;
    }
}

/// This function is used to derive the Iterator trait on structs that implement the Iterator interface
/// ### Examples
/// ```
/// const Range = struct {
///     start: usize,
///     end: usize,
///
///     const Self = @This();
///     pub const Item = usize;
///
///     pub fn next (self: *Self) ?Item {
///         if (self.start < self.end) {
///             defer self.start += 1;
///             return self.start;
///         }
///         return null;
///     }
///
///     pub usingnamespace Iterator(Self);
/// };
/// ```
pub fn Iterator(comptime It: type) type {
    const Self = Deref(It);
    const Item = Self.Item;

    return struct {
        pub const Predicate: type = fn (Item) bool;

        /// Takes a closure and creates an iterator which calls that
        /// closure on each item.
        ///
        /// Transforms one iterator that returns items of type A into
        /// an iterator that returns items of type B.
        ///
        /// ### Examples
        /// Converting each item from **usize** to **f32** and doubling them:
        /// ```
        /// const a = [_]usize{ 0, 1, 2, };
        ///
        /// var it = iter(&a).map(struct {
        ///     fn fun (item: usize) f32 {
        ///         return @intToFloat(f32, item * 2);
        ///     }
        /// }.fun);
        ///
        /// expectEqual(it.next(), 0.0);
        /// expectEqual(it.next(), 2.0);
        /// expectEqual(it.next(), 4.0);
        /// ```
        pub fn map(self: Self, comptime fun: anytype) Map(Self, fun) {
            return .{
                .iter = self,
            };
        }

        /// Takes a predicate and produces an iterator that only
        /// returns items that satisfy the predicate.
        ///
        /// ### Examples
        /// Filtering for only odd items:
        /// ```
        /// const a = [_]usize{ 0, 1, 2, 3, 4, 5, };
        ///
        /// var it = iter(&a).filter(struct {
        ///     fn fun (item: usize) bool {
        ///         return item % 2 == 1;
        ///     }
        /// }.fun);
        ///
        /// expectEqual(it.next(), 1);
        /// expectEqual(it.next(), 3);
        /// expectEqual(it.next(), 5);
        /// ```
        pub fn filter(self: Self, comptime predicate: Predicate) Filter(Self, predicate) {
            return .{
                .iter = self,
            };
        }

        /// Creates an iterator that returns up to **amount** items.
        ///
        /// **take(amount)** will return items until **amount** items have
        /// been returned or the underlying iterator runs out of items.
        ///
        /// ### Examples
        /// Returning **amount** items:
        /// ```
        /// const a = [_]usize{ 0, 1, 2, 3, 4, 5, 6, };
        ///
        /// var it = iter(&a).take(3);
        ///
        /// expectEqual(it.next(), 0);
        /// expectEqual(it.next(), 1);
        /// expectEqual(it.next(), 2);
        /// expectEqual(it.next(), null);
        /// ```
        /// Number of items is less than **amount**:
        /// ```
        /// const a = [_]usize{ 0, 1, };
        ///
        /// var it = iter(&a).take(3);
        ///
        /// expectEqual(it.next(), 0);
        /// expectEqual(it.next(), 1);
        /// expectEqual(it.next(), null);
        /// ```
        pub fn take(self: Self, amount: usize) Take(Self) {
            return .{
                .iter = self,
                .amount = amount,
            };
        }

        /// Creates an iterator that skips the first **amount** items.
        ///
        /// If **amount** is greater than or equal to the number of items
        /// in the underlying iterator, it is equivalent to an empty iterator.
        ///
        /// ### Examples
        /// Skipping the first **amount** items:
        /// ```
        /// const a = [_]usize{ 0, 1, 2, 3, 4, };
        ///
        /// var it = iter(&a).skip(3);
        ///
        /// expectEqual(it.next(), 3);
        /// expectEqual(it.next(), 4);
        /// ```
        /// When **amount** is greater than or equal to the iterator length:
        /// ```
        /// const a = [_]usize{ 0, 1, };
        ///
        /// var it = iter(&a).skip(3);
        ///
        /// expectEqual(it.next(), null);
        /// ```
        pub fn skip(self: Self, amount: usize) Skip(Self) {
            return .{
                .iter = self,
                .amount = amount,
            };
        }

        /// Creates an iterator that returns the items of the first iterator,
        /// then the items of the second iterator.
        ///
        /// The both iterator's Item types must be the same, and is compile time
        /// checked for correctness.
        ///
        /// ### Examples
        /// Chaining two iterators together:
        /// ```
        /// const a = [_]usize{ 0, 1, };
        /// const b = [_]usize{ 1, 2, };
        ///
        /// var it = iter(&a).chain(iter(&b));
        ///
        /// expectEqual(it.next(), 0);
        /// expectEqual(it.next(), 1);
        /// expectEqual(it.next(), 1);
        /// expectEqual(it.next(), 2);
        /// ```
        pub fn chain(self: Self, other: anytype) Chain(Self, @TypeOf(other)) {
            return .{
                .fst = self,
                .snd = other,
            };
        }

        /// Creates an iterator that returns items along with their index in
        /// the iterator.
        ///
        /// The type returned is `std.meta.Tuple(&.{ usize, Item, })`.
        ///
        /// ### Examples
        /// ```
        /// const a = [_]usize{ 3, 4, 5, };
        ///
        /// var it = iter(&a).enumerate();
        ///
        /// expectEqual(it.next(), { 0, 3, });
        /// expectEqual(it.next(), { 1, 4, });
        /// expectEqual(it.next(), { 2, 5, });
        /// ```
        pub fn enumerate(self: Self) Enumerate(Self) {
            return .{
                .iter = self,
                .index = 0,
            };
        }

        /// Creates an iterator that returns tuples of values from each iterator.
        ///
        /// The Item types of each iterator can be distinct, and `zip` will stop returning
        /// items once either iterator returns `null`.
        ///
        /// ### Examples
        /// ```
        /// const a = [_]usize{ 0, 1, 2, };
        /// const b = [_]u8{ 'a', 'b', 'c', };
        ///
        /// var it = iter(&a).zip(iter(&b));
        ///
        /// expectEqual(it.next(), { 0, 'a', });
        /// expectEqual(it.next(), { 1, 'b', });
        /// expectEqual(it.next(), { 2, 'c', });
        /// ```
        pub fn zip(self: Self, other: anytype) Zip(Self, @TypeOf(other)) {
            return .{
                .fst = self,
                .snd = other,
            };
        }

        pub fn stepBy(self: Self, step: usize) StepBy(Self) {
            return .{
                .iter = self,
                .step = step,
            };
        }

        pub fn filterMap(self: Self, predicate: anytype) FilterMap(Self, predicate) {
            return .{
                .iter = self,
            };
        }

        pub fn takeWhile(self: Self, comptime predicate: Predicate) TakeWhile(Self, predicate) {
            return .{
                .iter = self,
                .done = false,
            };
        }

        pub fn skipWhile(self: Self, comptime predicate: Predicate) SkipWhile(Self, predicate) {
            return .{
                .iter = self,
                .done = false,
            };
        }

        pub fn cycle(self: Self) Cycle(Self) {
            return .{
                .original = self,
                .current = self,
            };
        }

        pub fn copied(self: Self) Copied(Self) {
            return .{
                .iter = self,
            };
        }

        pub fn reduce(self: Self, init: anytype, comptime fun: fn (@TypeOf(init), Item) @TypeOf(init)) @TypeOf(init) {
            var acc = init;
            var iter = deref(self);
            while (iter.next()) |item| {
                acc = fun(acc, item);
            }
            return acc;
        }

        pub fn fold(self: Self, comptime fun: fn (Item, Item) Item) ?Item {
            var iter = deref(self);
            if (iter.next()) |item| {
                return self.reduce(item, fun);
            }
            return null;
        }

        pub fn find(self: Self, comptime predicate: Predicate) ?Item {
            const Closure = struct {
                fn fun(item: Item) bool {
                    return !predicate(item);
                }
            };
            var iter = self.skipWhile(Closure.fun);
            return iter.next();
        }

        pub fn position(self: Self, comptime predicate: Predicate) ?usize {
            var iter = self;
            if (iter.next()) |fst| {
                if (predicate(fst)) {
                    return 0;
                }
                var idx: usize = 1;
                while (iter.next()) |item| : (idx += 1) {
                    if (predicate(item)) {
                        return idx;
                    }
                }
            }
            return null;
        }

        pub fn all(self: Self, comptime predicate: Predicate) bool {
            return self.reduce(true, struct {
                fn fun(acc: bool, item: Item) bool {
                    return acc and predicate(item);
                }
            }.fun);
        }

        pub fn any(self: Self, comptime predicate: Predicate) bool {
            var iter = self;
            while (iter.next()) |item| {
                if (predicate(item)) {
                    return true;
                }
            }
            return false;
        }

        pub fn forEach(self: Self, comptime fun: fn (Item) void) void {
            var iter = deref(self);
            while (iter.next()) |item| {
                fun(item);
            }
        }

        pub fn collect(self: Self, allocator: Allocator) !ArrayList(Item) {
            var list = ArrayList(Item).init(allocator);
            var iter = deref(self);
            while (iter.next()) |item| {
                try list.append(item);
            }
            return list;
        }

        pub fn count(self: Self) usize {
            return self.reduce(@as(usize, 0), struct {
                fn fun(acc: usize, item: Item) usize {
                    _ = item;
                    return acc + 1;
                }
            }.fun);
        }

        pub fn last(self: Self) ?Item {
            return self.fold(struct {
                fn fun(_: Item, item: Item) Item {
                    return item;
                }
            }.fun);
        }

        pub fn first(self: Self) ?Item {
            var iter = self;
            return iter.next();
        }

        pub fn nth(self: Self, amount: usize) ?Item {
            var iter = self.skip(amount);
            return iter.next();
        }

        pub fn byRef(self: *Self) Ref(Self) {
            return .{
                .iter = self,
            };
        }
    };
}

fn Map(comptime Iter: type, comptime fun: anytype) type {
    const T = ReturnType(fun);

    return struct {
        iter: Iter,

        const Self = @This();
        const Item = T;

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |item| {
                return fun(item);
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Take(comptime Iter: type) type {
    return struct {
        iter: Iter,
        amount: usize,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            if (self.amount != 0) {
                self.amount -= 1;
                return self.iter.next();
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Skip(comptime Iter: type) type {
    return struct {
        iter: Iter,
        amount: usize,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            while (self.amount != 0) : (self.amount -= 1) {
                _ = self.iter.next();
            }
            return self.iter.next();
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Chain(comptime Fst: type, comptime Snd: type) type {
    if (Fst.Item != Snd.Item) {
        @compileError(@typeName(Fst) ++ ".Item must equal " ++ @typeName(Snd) ++ ".Item");
    }

    return struct {
        fst: Fst,
        snd: Snd,

        const Self = @This();
        const Item = Fst.Item;

        pub fn next(self: *Self) ?Item {
            if (self.fst.next()) |item| {
                return item;
            }
            if (self.snd.next()) |item| {
                return item;
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Filter(comptime Iter: type, comptime predicate: Iter.Predicate) type {
    return struct {
        iter: Iter,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            while (self.iter.next()) |item| {
                if (predicate(item)) {
                    return item;
                }
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Ref(comptime Iter: type) type {
    return struct {
        iter: *Iter,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            return self.iter.next();
        }

        pub usingnamespace Iterator(*Self);
    };
}

fn Enumerate(comptime Iter: type) type {
    return struct {
        iter: Iter,
        index: usize,

        const Self = @This();
        const Item = Tuple(&.{ usize, Iter.Item });

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |item| {
                defer self.index += 1;
                return .{ self.index, item };
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Zip(comptime Fst: type, comptime Snd: type) type {
    return struct {
        fst: Fst,
        snd: Snd,

        const Self = @This();
        const Item = Tuple(&.{ Fst.Item, Snd.Item });

        pub fn next(self: *Self) ?Item {
            if (self.fst.next()) |a| {
                if (self.snd.next()) |b| {
                    return .{
                        a,
                        b,
                    };
                }
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn StepBy(comptime Iter: type) type {
    return struct {
        iter: Iter,
        step: usize,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            var item = self.iter.next();
            var step = self.step - 1;
            while (step != 0) : (step -= 1) {
                _ = self.iter.next();
            }
            return item;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn FilterMap(comptime Iter: type, comptime predicate: anytype) type {
    const rtype = ReturnType(predicate);
    const rinfo = @typeInfo(rtype);
    if (rinfo != .Optional) {
        @compileError(@typeName(rtype) ++ "is not an optional value");
    }
    const T = rinfo.Optional.child;

    return struct {
        iter: Iter,

        const Self = @This();
        const Item = T;

        pub fn next(self: *Self) ?Item {
            while (self.iter.next()) |item| {
                if (predicate(item)) |value| {
                    return value;
                }
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn TakeWhile(comptime Iter: type, comptime predicate: Iter.Predicate) type {
    return struct {
        iter: Iter,
        done: bool,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            if (!self.done) {
                if (self.iter.next()) |item| {
                    if (predicate(item)) {
                        return item;
                    }
                    self.done = true;
                }
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn SkipWhile(comptime Iter: type, comptime predicate: Iter.Predicate) type {
    return struct {
        iter: Iter,
        done: bool,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            if (!self.done) {
                while (self.iter.next()) |item| {
                    if (!predicate(item)) {
                        self.done = true;
                        return item;
                    }
                }
            }
            return self.iter.next();
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Cycle(comptime Iter: type) type {
    return struct {
        original: Iter,
        current: Iter,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            if (self.current.next()) |item| {
                return item;
            }
            self.current = self.original;
            if (self.current.next()) |item| {
                return item;
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Copied(comptime Iter: type) type {
    return struct {
        iter: Iter,

        const Self = @This();
        pub const Item = Deref(Iter.Item);

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |item| {
                return deref(item);
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}
