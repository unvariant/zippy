const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const Allocator = mem.Allocator;

const Tmp = struct {
    now: Item,

    const Self = @This();
    const Item = usize;

    pub fn next (self: *Self) ?Item {
        const item = self.now;
        if (self.now <= 100) {
            self.now += 1;
            return item;
        }
        return null;
    }
};

pub fn main() !void {
    var now = Tmp {
        .now = 0,
    };
    var tmp = Iterator(Tmp) {
        .ctx = now,
    };

    var it = tmp
    .filter(struct {
        fn fun (item: usize) bool {
            return item % 2 == 0;
        }
    }.fun);

    debug.print("{any}\n", .{it.ctx.ctx.ctx.now});
    debug.print("{any}\n", .{it.ctx.ctx.ctx});
    debug.print("{any}\n", .{it.ctx.ctx});

    it.forEach(struct {
        fn fun (item: usize) void {
            debug.print("{d}\n", .{item});
        }
    }.fun);

    debug.print("{any}\n", .{it.ctx.ctx.ctx.now});
    debug.print("{any}\n", .{it.ctx.ctx.ctx});
    debug.print("{any}\n", .{it.ctx.ctx});
}

fn Iterator (comptime Ctx: type) type {
    return struct {
        ctx: Ctx,

        const Self = @This();
        const Item = Ctx.Item;

        pub fn next (self: Self) ?Item {
            return self.ctx.next();
        }

        pub fn filter (self: Self, comptime predicate: fn (Item) bool) Iterator(Filter(Self, predicate)) {
            return Iterator(Filter(Self, predicate)) {
                .ctx = Filter(Self, predicate) {
                    .ctx = self,
                },
            };
        }

        pub fn forEach (self: Self, comptime fun: fn (Item) void) void {
            while (self.next()) |item| {
                fun(item);
            }
        }
    };
}

fn Filter (comptime Ctx: type, comptime predicate: fn (Ctx.Item) bool) type {
    return struct {
        ctx: Ctx,

        const Self = @This();
        const Item = Ctx.Item;

        pub fn next (self: *Self) ?Item {
            while (self.ctx.next()) |item| {
                if (predicate(item)) {
                    return item;
                }
            }
            return null;
        }
    };
}