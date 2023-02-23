const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const debug = std.debug;
const assert = debug.assert;
const meta = std.meta;
const builtin = std.builtin;
const Type = builtin.Type;
const ArrayList = std.ArrayList;
const Tuple = meta.Tuple;
const Trait = meta.trait;

var GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};

fn Range() type {
    return struct {
        start: usize,
        end: usize,

        const Self = @This();
        const Item = usize;

        fn next(self: *Self) ?Item {
            if (self.start < self.end) {
                defer self.start += 1;
                return self.start;
            }
            return null;
        }

        pub fn clone(self: Self, allocator: Allocator) *Self {
            var new = allocator.create(Self);
            new.start = self.start;
            new.end = self.end;
            return new;
        }

        usingnamespace Iterator(Self);
    };
}

pub fn print(item: usize) void {
    debug.print("{any}\n", .{item});
}

pub fn main() void {
    var allocator = GeneralPurposeAllocator.allocator();

    var range = Range(){
        .start = 0,
        .end = 16,
    };

    var even = range
        .filter(struct {
        fn fun(item: usize) bool {
            return item % 2 == 0;
        }
    }.fun);

    var map = even.map(struct {
        fn fun (item: usize) usize {
            return item + 5;
        }
    }.fun);

    var fst = map.take(5);
    
    fst.forEach(print);
    var enumerate = map.enumerate();
    var leftover = enumerate.collect(allocator) catch unreachable;
    defer leftover.deinit();

    debug.print("{any}\n", .{leftover.items});
}

// fn InternalClone(comptime Self: type) type {
//     if (@hasDecl(Self, "clone")) {
//         return struct {};
//     } else {
//         return struct {
//             fn clone (self: Self) Self {
//                 const info = @typeInfo(Self);
//                 if (info != .Struct) {
//                     @compileError("Self must be a struct");
//                 }

//                 inline for (info.Struct.fields) |field| {
//                     _ = field.default_value orelse @compileError("structure field does not have a default value (did you forget to implement clone on your iterator?)");
//                 }

//                 var new: Self = .{};
//                 inline for (info.Struct.fields) |field| {
//                     const name = field.name;
//                     const finfo = @typeInfo(field.field_type);
//                     if (finfo == .Struct) {
//                         @field(new, name) = @field(self, name).clone();
//                     } else {
//                         @field(new, name) = @field(self, name);
//                     }
//                 }
//                 return new;
//             }
//         };
//     }
// }

fn Deref(comptime T: type) type {
    const info = @typeInfo(T);
    return switch (info) {
        .Pointer => info.Pointer.child,
        else => T,
    };
}

fn Iterator(comptime Self: type) type {
    return struct {
        // pub fn cycle(self: *Self) Cycle(Self) {
        //     return .{
        //         .original = self,
        //         .current = self.clone(),
        //     };
        // }

        pub fn filter(self: *Self, comptime predicate: fn (Self.Item) bool) Filter(Self, predicate) {
            return .{
                .it = self,
            };
        }

        pub fn map(self: *Self, comptime mapper: anytype) Map(Self, mapper) {
            return .{
                .it = self,
            };
        }

        pub fn take(self: *Self, n: usize) Take(Self) {
            return .{
                .it = self,
                .amount = n,
            };
        }

        pub fn drop(self: *Self, n: usize) Drop(Self) {
            return .{
                .it = self,
                .amount = n,
            };
        }

        pub fn enumerate(self: *Self) Enumerate(Self) {
            return .{
                .it = self,
                .index = 0,
            };
        }

        pub fn fold(self: *Self, init: anytype, comptime fun: fn (@TypeOf(init), Self.Item) @TypeOf(init)) @TypeOf(init) {
            var acc = init;
            while (self.next()) |item| {
                acc = fun(acc, item);
            }
            return acc;
        }

        pub fn reduce(self: *Self, comptime fun: fn (Self.Item, Self.Item) Self.Item) ?Self.Item {
            const init = self.next() orelse return null;
            return self.fold(init, fun);
        }

        pub fn collect(self: *Self, allocator: anytype) !ArrayList(Self.Item) {
            var list = ArrayList(Self.Item).init(allocator);
            while (self.next()) |item| {
                try list.append(item);
            }
            return list;
        }

        pub fn forEach(self: *Self, comptime fun: fn (Self.Item) void) void {
            while (self.next()) |item| {
                fun(item);
            }
        }

        //usingnamespace InternalClone(Self);
    };
}

fn Enumerate(comptime Iter: type) type {
    return struct {
        it: *Iter = undefined,
        index: usize = undefined,

        const Self = @This();
        const Item = Tuple(&.{ usize, Iter.Item });

        pub fn next(self: *Self) ?Item {
            if (self.it.next()) |item| {
                defer self.index += 1;
                return .{ self.index, item };
            }
            return null;
        }

        usingnamespace Iterator(Self);
    };
}

fn Take(comptime Iter: type) type {
    return struct {
        it: *Iter = undefined,
        amount: usize = undefined,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            if (self.amount != 0) {
                self.amount -= 1;
                return self.it.next();
            }
            return null;
        }

        usingnamespace Iterator(Self);
    };
}

fn Drop(comptime Iter: type) type {
    return struct {
        it: *Iter = undefined,
        amount: usize = undefined,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            while (self.amount != 0) : (self.amount -= 1) {
                _ = self.it.next();
            }
            return self.it.next();
        }

        usingnamespace Iterator(Self);
    };
}

fn Map(comptime Iter: type, comptime mapper: anytype) type {
    const mtype = @TypeOf(mapper);
    const info = @typeInfo(mtype);
    if (info != .Fn) {
        @compileError(@typeName(mtype) ++ " is not a function");
    }

    return struct {
        it: *Iter = undefined,

        const Self = @This();
        const Item = info.Fn.return_type.?;

        pub fn next(self: *Self) ?Item {
            if (self.it.next()) |item| {
                return mapper(item);
            }
            return null;
        }

        usingnamespace Iterator(Self);
    };
}

fn Filter(comptime Iter: type, comptime predicate: fn (Iter.Item) bool) type {
    return struct {
        it: *Iter = undefined,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            while (self.it.next()) |item| {
                if (predicate(item)) {
                    return item;
                }
            }
            return null;
        }

        usingnamespace Iterator(Self);
    };
}

fn Cycle(comptime Iter: type) type {
    return struct {
        original: *Iter = undefined,
        current: Iter = undefined,

        const Self = @This();
        const Item = Iter.Item;

        pub fn next(self: *Self) ?Item {
            if (self.current.next()) |item| {
                return item;
            }
            self.current = self.original.clone();
            if (self.current.next()) |item| {
                return item;
            }
            return null;
        }

        usingnamespace Iterator(Self);
    };
}
