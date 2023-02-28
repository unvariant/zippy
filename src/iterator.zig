const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const meta = std.meta;
const trait = meta.trait;
const Tuple = meta.Tuple;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

fn Deref(comptime T: type) type {
    if (comptime trait.isSingleItemPtr(T)) {
        return @typeInfo(T).Pointer.child;
    } else {
        return T;
    }
}

fn deref(item: anytype) @TypeOf(item) {
    if (comptime trait.isSingleItemPtr(@TypeOf(item))) {
        return item.*;
    } else {
        return item;
    }
}

pub fn Iterator(comptime S: type) type {
    const Self = Deref(S);
    const Item = Self.Item;

    return struct {
        pub const Predicate = fn(Item)bool;

        pub fn map(self: Self, comptime fun: anytype) Map(Self, fun) {
            return .{ .iter = self, };
        }

        pub fn filter(self: Self, comptime predicate: Predicate) Filter(Self, predicate) {
            return .{ .iter = self, };
        }

        pub fn take(self: Self, amount: usize) Take(Self) {
            return .{ .iter = self, .amount = amount, };
        }

        pub fn skip(self: Self, amount: usize) Skip(Self) {
            return .{ .iter = self, .amount = amount, };
        }

        pub fn chain(self: Self, other: anytype) Chain(Self, @TypeOf(other)) {
            return .{ .fst = self, .snd = other, };
        }

        pub fn enumerate(self: Self) Enumerate(Self) {
            return .{ .iter = self, .index = 0, };
        }

        pub fn zip(self: Self, other: anytype) Zip(Self, @TypeOf(other)) {
            return .{ .fst = self, .snd = other, };
        }

        pub fn stepBy(self: Self, step: usize) StepBy(Self) {
            return .{ .iter = self, .step = step, };
        }

        pub fn filterMap(self: Self, predicate: anytype) FilterMap(Self, predicate) {
            return .{ .iter = self, };
        }

        pub fn takeWhile(self: Self, comptime predicate: Predicate) TakeWhile(Self, predicate) {
            return .{ .iter = self, .done = false, };
        }

        pub fn skipWhile(self: Self, comptime predicate: Predicate) SkipWhile(Self, predicate) {
            return .{ .iter = self, .done = false, };
        }

        pub fn reduce(self: Self, init: anytype, comptime fun: fn(@TypeOf(init), Item)@TypeOf(init)) @TypeOf(init) {
            var acc = init;
            var iter = deref(self);
            while (iter.next()) |item| {
                acc = fun(acc, item);
            }
            return acc;
        }

        pub fn fold(self: Self, comptime fun: fn(Item, Item)Item) ?Item {
            var iter = deref(self);
            if (iter.next()) |item| {
                return self.reduce(item, fun);
            }
            return null;
        }

        pub fn find(self: Self, comptime predicate: Predicate) ?Item {
            const Closure = struct {
                fn fun (item: Item) bool {
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
                fn fun (acc: usize, item: Item) usize {
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
            return .{ .iter = self, };
        }
    };
}

fn Map(comptime Iter: type, comptime fun: anytype) type {
    const ftype = @TypeOf(fun);
    const info = @typeInfo(ftype);
    if (info != .Fn) {
        @compileError(@typeName(ftype) ++ " is not a function");
    }
    const ReturnType = info.Fn.return_type.?;

    return struct {
        iter: Iter,

        const Self = @This();
        const Item = ReturnType;

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
        const Item = Tuple(&.{usize, Iter.Item});

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
        const Item = Tuple(&.{Fst.Item, Snd.Item});

        pub fn next(self: *Self) ?Item {
            if (self.fst.next()) |a| {
                if (self.snd.next()) |b| {
                    return .{ a, b, };
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
    const ftype = @TypeOf(predicate);
    const info = @typeInfo(ftype);
    if (info != .Fn) {
        @compileError(@typeName(ftype) ++ " is not a function");
    }
    const rtype = info.Fn.return_type.?;
    const rinfo = @typeInfo(rtype);
    if (rinfo != .Optional) {
        @compileError(@typeName(rtype) ++ "is not an optional value");
    }
    const ReturnType = rinfo.Optional.child;

    return struct {
        iter: Iter,

        const Self = @This();
        const Item = ReturnType;

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