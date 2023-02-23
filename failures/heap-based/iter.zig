const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const trait = meta.trait;
const debug = std.debug;
const Allocator = mem.Allocator;

var GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};

const Range = struct {
    start: usize,
    end: usize,
    allocator: Allocator,

    const Self = @This();
    const Item = usize;

    pub fn next(self: *Self) ?Item {
        if (self.start < self.end) {
            defer self.start += 1;
            return self.start;
        }
        return null;
    }

    usingnamespace Iterator(Self, .{});
};

fn print(comptime T: type) fn (T) void {
    const Closure = struct {
        fn fun(item: T) void {
            debug.print("{any}\n", .{item});
        }
    };
    return Closure.fun;
}

fn double(comptime T: type) fn(T)T {
    const Closure = struct {
        fn fun (item: T) T {
            return item * 2;
        }
    };
    return Closure.fun;
}

fn add(comptime addend: anytype) fn(@TypeOf(addend))@TypeOf(addend) {
    const Closure = struct {
        fn fun (item: @TypeOf(addend)) @TypeOf(addend) {
            return item + addend;
        }
    };
    return Closure.fun;
}

pub fn main() void {
    var allocator = GeneralPurposeAllocator.allocator();

    var range = allocator.create(Range) catch unreachable;
    range.start = 0;
    range.end = 10;
    range.allocator = allocator;

    var it = range
        .take(3)
        .map(add(@as(usize, 2)))
        .cycle()
        .take(10)
        .map(double(usize))
        .cycle()
        .take(5);
    it.take(1).forEach(print(usize)).drop(null);
    it.map(add(@as(usize, 5))).forEach(print(usize)).drop(null);

    defer _ = GeneralPurposeAllocator.detectLeaks();
}

// fn InternalNext(comptime Self: type) type {
//     if (@hasDecl(Self, "next")) {
//         return struct {};
//     } else if (!@hasDecl(Self, "nextFn")) {
//         @compileError("did you forget to implement nextFn on type " ++ @typeName(Self));
//     } else {
//         return struct {
//             pub fn next(self: *Self) ?Self.Item {
//                 if (self.nextFn()) |item| {
//                     return item;
//                 }
//                 return null;
//             }
//         };
//     }
// }

fn InternalDrop(comptime Self: type, comptime fields: anytype) type {
    if (comptime trait.hasFn("drop")(Self)) {
        return struct {};
    } else {
        return struct {
            pub fn drop(self: *Self, level: ?usize) void {
                inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |struct_field| {
                    const field = @field(self, @ptrCast(struct_field.field_type, struct_field.default_value.?));
                    if (level) |n| {
                        if (n != 0) {
                            field.drop(n - 1);
                        }
                    } else {
                        field.drop(null);
                    }
                }
                self.allocator.destroy(self);
            }
        };
    }
}

fn InternalClone(comptime Self: type) type {
    if (comptime !trait.isContainer(Self)) {
        @compileError("cannot derive clone for non-container type " ++ @typeName(Self));
    }
    if (!@hasField(Self, "allocator")) {
        @compileError("cannot locate allocator field on type " ++ @typeName(Self));
    }

    return struct {
        pub fn clone(self: Self) *Self {
            var new = self.allocator.create(Self) catch unreachable;
            const tag = @typeInfo(Self);
            switch (tag) {
                .Struct => {
                    const info = tag.Struct;
                    inline for (info.fields) |field| {
                        const fname = field.name;
                        const ftype = field.field_type;
                        const cloneable = comptime trait.isSingleItemPtr(ftype) and trait.isContainer(@typeInfo(ftype).Pointer.child);
                        if (cloneable) {
                            @field(new, fname) = @field(self, fname).clone();
                        } else {
                            @field(new, fname) = @field(self, fname);
                        }
                    }
                },
                else => unreachable,
            }
            return new;
        }
    };
}

fn Iterator(comptime Self: type, comptime fields: anytype) type {
    return struct {
        //usingnamespace InternalNext(Self);
        usingnamespace InternalClone(Self);
        usingnamespace InternalDrop(Self, fields);

        pub fn cycle(self: *Self) *Cycle(Self) {
            var new = self.allocator.create(Cycle(Self)) catch unreachable;
            new.original = self;
            new.current = self.clone();
            new.allocator = self.allocator;
            return new;
        }

        pub fn take(self: *Self, amount: usize) *Take(Self) {
            var new = self.allocator.create(Take(Self)) catch unreachable;
            new.iter = self;
            new.amount = amount;
            new.allocator = self.allocator;
            return new;
        }

        pub fn map(self: *Self, comptime fun: anytype) *Map(Self, fun) {
            var new = self.allocator.create(Map(Self, fun)) catch unreachable;
            new.iter = self;
            new.allocator = self.allocator;
            return new;
        }

        pub fn forEach(self: *Self, comptime fun: fn (Self.Item) void) *Self {
            while (self.next()) |item| {
                fun(item);
            }
            return self;
        }
    };
}

fn Cycle(comptime Iter: type) type {
    return struct {
        original: *Iter,
        current: *Iter,
        allocator: Allocator,

        const Self = @This();
        const Item = Iter.Item;

        fn next(self: *Self) ?Item {
            if (self.current.next()) |item| {
                return item;
            }
            self.current.drop(null);
            self.current = self.original.clone();
            return self.current.next();
        }

        usingnamespace Iterator(Self, .{ "current", "original" });
    };
}

fn Take(comptime Iter: type) type {
    return struct {
        iter: *Iter,
        amount: usize,
        allocator: Allocator,

        const Self = @This();
        const Item = Iter.Item;

        fn next(self: *Self) ?Item {
            if (self.amount != 0) {
                self.amount -= 1;
                return self.iter.next();
            }
            return null;
        }

        usingnamespace Iterator(Self, .{"iter"});
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
        iter: *Iter,
        allocator: Allocator,

        const Self = @This();
        const Item = ReturnType;

        fn next(self: *Self) ?Item {
            if (self.iter.next()) |item| {
                return fun(item);
            }
            return null;
        }

        usingnamespace Iterator(Self, .{"iter"});
    };
}
