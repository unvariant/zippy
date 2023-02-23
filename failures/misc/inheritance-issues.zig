const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const assert = debug.assert;

fn Tmp() type {
    return struct {
        n: usize,

        const Self = @This();
        const Item = usize;

        pub fn init() Self {
            return Self{
                .n = 0,
            };
        }

        pub fn clone(self: Self) Self {
            return Self{
                .n = self.n,
            };
        }

        pub fn next(self: *Self) ?Item {
            if (self.n <= 100) {
                const item = self.n;
                self.n += 1;
                return item;
            }
            return null;
        }

        usingnamespace Iterator(Self);
        usingnamespace Clone(Self, &[_]type{}, .{});
    };
}

pub fn main() void {
    var tmp = Tmp().init();
    var it = tmp.clone()
        .take(10)
        .filter(struct {
        fn fun(item: usize) bool {
            return item % 2 == 0;
        }
    }.fun)
        .drop(1)
        .chain(tmp.clone())
        .map(f32, struct {
        fn fun(item: usize) f32 {
            return @intToFloat(f32, item);
        }
    }.fun);

    it.forEach(struct {
        fn fun(item: f32) void {
            debug.print("{any}\n", .{item});
        }
    }.fun);
}

fn hasFn (comptime T: type, name: []const u8) bool {
    const info = @typeInfo(T);
    if (info == .Struct) {
        const s = info.Struct;
        for (s.decls) |decl| {
            if (mem.eql(u8, name, decl.name)) {
                return true;
            }
        }
    }
    return false;
}

fn Clone(comptime Self: type, comptime fields: []const type, comptime impl: anytype) type {
    for (fields) |ftype| {
        if (!hasFn(ftype, "clone")) {
            @compileError("fields do not implement clone");
        }
    }

    if (hasFn(Self, "clone")) {
        return struct {};
    } else {
        assert(hasFn(impl, "clone"));
        return impl;
    }
}

fn Iterator(comptime Self: type) type {
    return struct {
        pub fn take(self: Self, n: usize) Take(Self) {
            return Take(Self).init(self, n);
        }

        pub fn drop(self: Self, n: usize) Drop(Self) {
            return Drop(Self).init(self, n);
        }

        pub fn filter(self: Self, comptime fun: fn (Self.Item) bool) Filter(Self, fun) {
            return Filter(Self, fun).init(self);
        }

        pub fn map(self: Self, comptime Other: type, comptime fun: fn (Self.Item) Other) Map(Self, Other, fun) {
            return Map(Self, Other, fun).init(self);
        }

        pub fn chain (self: Self, other: anytype) Chain(Self, @TypeOf(other)) {
            return Chain(Self, @TypeOf(other)).init(self, other);
        }

        pub fn forEach(self: *Self, comptime fun: fn (Self.Item) void) void {
            while (self.next()) |item| {
                fun(item);
            }
        }
    };
}

fn Chain(comptime Fst: type, comptime Snd: type) type {
    assert(Fst.Item == Snd.Item);
    return struct {
        fst: Fst,
        snd: Snd,

        const Self = @This();
        const Item = Fst.Item;

        pub fn init (ctx: Fst, other: Snd) Self {
            return .{
                .fst = ctx,
                .snd = other,
            };
        }

        pub fn next (self: *Self) ?Item {
            if (self.fst.next()) |item| {
                return item;
            }
            if (self.snd.next()) |item| {
                return item;
            }
            return null;
        }

        usingnamespace Iterator(Self);
    };
}

fn Map(comptime Ctx: type, comptime Other: type, comptime map: fn (Ctx.Item) Other) type {
    return struct {
        ctx: Ctx,

        const Self = @This();
        const Item = Other;

        pub fn init(ctx: Ctx) Self {
            return Self{
                .ctx = ctx,
            };
        }

        pub fn next(self: *Self) ?Item {
            if (self.ctx.next()) |item| {
                return map(item);
            }
            return null;
        }

        usingnamespace Iterator(Self);
    };
}

fn Filter(comptime Ctx: type, comptime pred: fn (Ctx.Item) bool) type {
    return struct {
        ctx: Ctx,

        const Self = @This();
        const Item = Ctx.Item;

        pub fn init(ctx: Ctx) Self {
            return Self{
                .ctx = ctx,
            };
        }

        pub fn next(self: *Self) ?Item {
            while (self.ctx.next()) |item| {
                if (pred(item)) {
                    return item;
                }
            }
            return null;
        }

        usingnamespace Iterator(Self);
    };
}

fn Take(comptime Ctx: type) type {
    return struct {
        ctx: Ctx,
        target: usize,

        const Self = @This();
        const Item = Ctx.Item;

        pub fn init(ctx: Ctx, n: usize) Self {
            return .{
                .ctx = ctx,
                .target = n,
            };
        }

        pub fn next(self: *Self) ?Item {
            if (self.target != 0) {
                self.target -= 1;
                return self.ctx.next();
            }
            return null;
        }

        usingnamespace Iterator(Self);
    };
}

fn Drop(comptime Ctx: type) type {
    return struct {
        ctx: Ctx,
        target: usize,

        const Self = @This();
        const Item = Ctx.Item;

        pub fn init (ctx: Ctx, n: usize) Self {
            return .{
                .ctx = ctx,
                .target = n,
            };
        }

        pub fn next (self: *Self) ?Item {
            while (self.target != 0) : (self.target -= 1) {
                _ = self.ctx.next();
            }
            return self.ctx.next();
        }

        usingnamespace Iterator(Self);
    };
}