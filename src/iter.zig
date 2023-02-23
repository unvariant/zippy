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
        pub fn next(self: *Self) ?Item {
            var entry = self.nextFn();
            self.* = entry[1];
            return entry[0];
        }

        pub fn map(self: Self, comptime fun: anytype) Map(Self, fun) {
            return Map(Self, fun).init(deref(self));
        }

        pub fn filter(self: Self, comptime predicate: fn (Item) bool) Filter(Self, predicate) {
            return Filter(Self, predicate).init(deref(self));
        }

        pub fn take(self: Self, amount: usize) Take(Self) {
            return Take(Self).init(deref(self), amount);
        }

        pub fn skip(self: Self, amount: usize) Skip(Self) {
            return Skip(Self).init(deref(self), amount);
        }

        pub fn chain(self: Self, other: anytype) Chain(Self, @TypeOf(other)) {
            return Chain(Self, @TypeOf(other)).init(self, other);
        }

        pub fn enumerate(self: Self) Enumerate(Self) {
            return Enumerate(Self).init(self);
        }

        pub fn reduce(self: Self, init: anytype, comptime fun: fn(@TypeOf(init), Item)@TypeOf(init)) @TypeOf(init) {
            var acc = init;
            var iter = deref(self);
            var entry = iter.nextFn();
            while (entry[0]) |item| : ({ iter = entry[1]; entry = iter.nextFn(); }) {
                acc = fun(acc, item);
            }
            return acc;
        }

        pub fn fold(self: Self, comptime fun: fn(Item, Item)Item) ?Item {
            var iter = deref(self);
            var entry = iter.nextFn();
            if (entry[0]) |item| {
                return self.reduce(item, fun);
            }
            return null;
        }

        pub fn all(self: Self, comptime predicate: fn(Item)bool) bool {
            return self.reduce(true, struct {
                fn fun(acc: bool, item: Item) bool {
                    return acc and predicate(item);
                }
            }.fun);
        }

        pub fn any(self: *Self, comptime predicate: fn(Item)bool) bool {
            while (self.next()) |item| {
                if (predicate(item)) {
                    return true;
                }
            }
            return false;
        }

        pub fn forEach(self: Self, comptime fun: fn (Item) void) void {
            var iter = deref(self);
            var entry = iter.nextFn();
            while (entry[0]) |item| : ({
                iter = entry[1];
                entry = iter.nextFn();
            }) {
                fun(item);
            }
        }

        pub fn collect(self: Self, allocator: Allocator) !ArrayList(Item) {
            var list = ArrayList(Item).init(allocator);
            var iter = deref(self);
            var entry = iter.nextFn();
            while (entry[0]) |item| : ({ iter = entry[1]; entry = iter.nextFn(); }) {
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
            var entry = iter.nextFn();
            return entry[0];
        }

        pub fn nth(self: Self, amount: usize) ?Item {
            return self.skip(amount).first();
        }

        pub fn by_ref(self: *Self) Ref(Self) {
            return Ref(Self).init(self);
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

        pub fn init(iter: Iter) Self {
            return .{
                .iter = iter,
            };
        }

        pub fn nextFn(self: Self) Tuple(&.{ ?Item, Self }) {
            var iter = self.iter;
            var entry = iter.nextFn();
            if (entry[0]) |item| {
                return .{
                    fun(item),
                    .{
                        .iter = entry[1],
                    },
                };
            }
            return .{
                null,
                self,
            };
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

        pub fn init(iter: Iter, amount: usize) Self {
            return .{
                .iter = iter,
                .amount = amount,
            };
        }

        pub fn nextFn(self: Self) Tuple(&.{ ?Item, Self }) {
            if (self.amount != 0) {
                var iter = self.iter;
                var entry = iter.nextFn();
                return .{
                    entry[0],
                    .{
                        .iter = entry[1],
                        .amount = self.amount - 1,
                    },
                };
            }
            return .{
                null,
                self,
            };
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

        pub fn init(iter: Iter, amount: usize) Self {
            return .{
                .iter = iter,
                .amount = amount,
            };
        }

        pub fn nextFn(self: Self) Tuple(&.{ ?Item, Self }) {
            var iter = self.iter;
            var amount = self.amount;
            while (amount != 0) : (amount -= 1) {
                iter = iter.nextFn()[1];
            }
            var entry = iter.nextFn();
            return .{ entry[0], .{
                .iter = entry[1],
                .amount = 0,
            } };
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

        pub fn init(fst: Fst, snd: Snd) Self {
            return .{
                .fst = fst,
                .snd = snd,
            };
        }

        pub fn nextFn(self: Self) Tuple(&.{?Item, Self}) {
            var fst_iter = self.fst;
            var fst_entry = fst_iter.nextFn();
            if (fst_entry[0]) |item| {
                return .{
                    item,
                    .{
                        .fst = fst_entry[1],
                        .snd = self.snd,
                    },
                };
            }
            var snd_iter = self.snd;
            var snd_entry = snd_iter.nextFn();
            if (snd_entry[0]) |item| {
                return .{
                    item,
                    .{
                        .fst = self.fst,
                        .snd = snd_entry[1],
                    },
                };
            }
            return .{ null, self, };
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Filter(comptime Iter: type, comptime predicate: fn (Iter.Item) bool) type {
    return struct {
        iter: Iter,

        const Self = @This();
        const Item = Iter.Item;

        pub fn init(iter: Iter) Self {
            return .{
                .iter = iter,
            };
        }

        pub fn nextFn(self: Self) Tuple(&.{ ?Item, Self }) {
            var iter = self.iter;
            var entry = iter.nextFn();
            while (entry[0]) |item| : ({
                iter = entry[1];
                entry = iter.nextFn();
            }) {
                if (predicate(item)) {
                    return .{
                        item,
                        .{
                            .iter = entry[1],
                        },
                    };
                }
            }
            return .{
                null,
                self,
            };
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Ref(comptime Iter: type) type {
    return struct {
        iter: *Iter,

        const Self = @This();
        const Item = Deref(Iter).Item;

        pub fn init(iter: *Iter) Self {
            return .{
                .iter = iter,
            };
        }

        pub fn nextFn(self: *Self) Tuple(&.{ ?Item, Self }) {
            var entry = self.iter.nextFn();
            self.iter.* = entry[1];
            return .{
                entry[0],
                self.*,
            };
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

        pub fn init(iter: Iter) Self {
            return .{ .iter = iter, .index = 0, };
        }

        pub fn nextFn(self: Self) Tuple(&.{?Item, Self}) {
            var iter = self.iter;
            var entry = iter.nextFn();
            if (entry[0]) |item| {
                return .{
                    .{
                        self.index,
                        item,
                    },
                    .{
                        .iter = entry[1],
                        .index = self.index + 1,
                    },
                };
            }
            return .{ null, self, };
        }

        pub usingnamespace Iterator(Self);
    };
}